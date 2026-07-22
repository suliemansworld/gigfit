import { spawn } from 'node:child_process';
import {
  cpSync,
  existsSync,
  mkdirSync,
  readFileSync,
  renameSync,
  rmSync,
  statSync,
  writeFileSync,
} from 'node:fs';
import { dirname, extname, join, relative, resolve, sep } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const output = join(root, 'www');
const audioCache = join(root, '.build', 'ios-audio');
const transcodeVoice = process.env.ECHO_TRANSCODE_AUDIO === '1';

function insideRoot(path) {
  const rel = relative(root, path);
  return rel && !rel.startsWith(`..${sep}`) && rel !== '..';
}

function sourcePath(relativePath) {
  const path = resolve(root, relativePath);
  if (!insideRoot(path)) throw new Error(`Refusing path outside repository: ${relativePath}`);
  if (!existsSync(path)) throw new Error(`Missing build input: ${relativePath}`);
  return path;
}

function copy(relativePath, destinationRelativePath = relativePath) {
  const from = sourcePath(relativePath);
  const to = join(output, destinationRelativePath);
  mkdirSync(dirname(to), { recursive: true });
  cpSync(from, to, { recursive: true });
}

async function transcode(input, destination) {
  mkdirSync(dirname(destination), { recursive: true });
  const temporary = `${destination}.tmp-${process.pid}`;
  if (existsSync(temporary)) rmSync(temporary);
  await new Promise((resolvePromise, rejectPromise) => {
    const child = spawn('/usr/bin/afconvert', [
      '-f', 'm4af', '-d', 'aac', '-b', '96000', input, temporary,
    ], { stdio: ['ignore', 'ignore', 'pipe'] });
    let error = '';
    child.stderr.on('data', chunk => { error += chunk.toString(); });
    child.on('error', rejectPromise);
    child.on('close', code => {
      if (code === 0) resolvePromise();
      else rejectPromise(new Error(`afconvert failed (${code}): ${error.trim()}`));
    });
  });
  if (existsSync(destination)) rmSync(destination);
  renameSync(temporary, destination);
}

async function runPool(tasks, concurrency = 4) {
  let next = 0;
  let completed = 0;
  async function worker() {
    while (next < tasks.length) {
      const task = tasks[next++];
      await task();
      completed += 1;
      if (completed % 50 === 0 || completed === tasks.length) {
        process.stdout.write(`Compressed ${completed}/${tasks.length} narration files\n`);
      }
    }
  }
  await Promise.all(Array.from({ length: Math.min(concurrency, tasks.length) }, worker));
}

rmSync(output, { recursive: true, force: true });
mkdirSync(output, { recursive: true });
copy('manifest.json');
copy('sw.js');
copy('icons');

const html = readFileSync(join(root, 'index.html'), 'utf8');
const vendorFiles = [
  ['node_modules/@capacitor/core/dist/capacitor.js', 'vendor/capacitor.js'],
  ['node_modules/@capacitor/app/dist/plugin.js', 'vendor/app.js'],
  ['node_modules/@capacitor/haptics/dist/plugin.js', 'vendor/haptics.js'],
  ['node_modules/@capacitor/preferences/dist/plugin.js', 'vendor/preferences.js'],
  ['node_modules/@capacitor/screen-reader/dist/plugin.js', 'vendor/screen-reader.js'],
  ['node_modules/@capacitor/share/dist/plugin.js', 'vendor/share.js'],
];
const nativeScripts = vendorFiles
  .map(([, destination]) => `<script src="${destination}"></script>`)
  .join('\n');
if (!html.includes('</head>')) throw new Error('index.html is missing </head>.');
writeFileSync(join(output, 'index.html'), html.replace('</head>', `${nativeScripts}\n</head>`));
for (const [source, destination] of vendorFiles) copy(source, destination);

const staticAudio = new Set(
  [...html.matchAll(/["'](audio\/[^"']+\.(?:mp3|wav))["']/g)].map(match => match[1]),
);
for (const relativePath of staticAudio) copy(relativePath);

const sourceManifest = JSON.parse(readFileSync(sourcePath('audio/voice/manifest.json'), 'utf8'));
const builtManifest = structuredClone(sourceManifest);
const conversions = new Map();

for (const entry of Object.values(builtManifest)) {
  const original = entry.wav;
  sourcePath(original);
  if (transcodeVoice && extname(original).toLowerCase() === '.wav') {
    const compressed = original.replace(/\.wav$/i, '.m4a');
    entry.wav = compressed;
    conversions.set(original, compressed);
  } else {
    copy(original);
  }
}

if (transcodeVoice) {
  if (!existsSync('/usr/bin/afconvert')) {
    throw new Error('The iOS audio build requires /usr/bin/afconvert on macOS.');
  }
  const tasks = [];
  for (const [original, compressed] of conversions) {
    const input = sourcePath(original);
    const cached = join(audioCache, compressed);
    const cacheFresh = existsSync(cached) && statSync(cached).mtimeMs >= statSync(input).mtimeMs;
    if (!cacheFresh) tasks.push(() => transcode(input, cached));
  }
  await runPool(tasks);
  for (const compressed of conversions.values()) {
    const cached = join(audioCache, compressed);
    if (!existsSync(cached)) throw new Error(`Missing compressed output: ${compressed}`);
    const destination = join(output, compressed);
    mkdirSync(dirname(destination), { recursive: true });
    cpSync(cached, destination);
  }
}

const manifestOutput = join(output, 'audio', 'voice', 'manifest.json');
mkdirSync(dirname(manifestOutput), { recursive: true });
writeFileSync(manifestOutput, `${JSON.stringify(builtManifest, null, 2)}\n`);
writeFileSync(join(output, 'build-info.json'), `${JSON.stringify({
  build: (html.match(/window\.ECHO_BUILD\s*=\s*'([^']+)'/) || [])[1] || 'unknown',
  narrationFiles: Object.keys(builtManifest).length,
  compressedNarration: transcodeVoice,
}, null, 2)}\n`);

process.stdout.write(
  `Built ${relative(root, output)} with ${Object.keys(builtManifest).length} narration entries`
  + `${transcodeVoice ? ' (AAC)' : ''}.\n`,
);

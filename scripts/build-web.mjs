import {
  cpSync,
  existsSync,
  mkdirSync,
  readdirSync,
  readFileSync,
  rmSync,
  writeFileSync,
} from 'node:fs';
import { dirname, join, relative, resolve, sep } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const output = join(root, 'www');

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

function filesUnder(directory) {
  const files = [];
  for (const entry of readdirSync(directory, { withFileTypes: true })) {
    const path = join(directory, entry.name);
    if (entry.isDirectory()) files.push(...filesUnder(path));
    else if (entry.isFile()) files.push(path);
  }
  return files;
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
for (const relativePath of staticAudio) sourcePath(relativePath);

const sourceManifest = JSON.parse(readFileSync(sourcePath('audio/voice/manifest.json'), 'utf8'));
for (const [stem, entry] of Object.entries(sourceManifest)) {
  if (!entry || typeof entry.text !== 'string' || !entry.text.trim()) {
    throw new Error(`Narration entry has no text: ${stem}`);
  }
  if (!entry.wav || !/^audio\/voice\/[^/]+\.(?:wav|mp3)$/i.test(entry.wav)) {
    throw new Error(`Narration entry has an invalid source path: ${stem}`);
  }
  sourcePath(entry.wav);
}

// Audio is gameplay, not an optional optimization. Preserve the owner's entire
// licensed source tree byte-for-byte so the native app receives the same WAV
// narration, footsteps, beds, friction, and landmark cues as the web game.
copy('audio');
const sourceAudioFiles = filesUnder(sourcePath('audio'));
const sourceWavFiles = sourceAudioFiles.filter(path => path.toLowerCase().endsWith('.wav'));
writeFileSync(join(output, 'build-info.json'), `${JSON.stringify({
  build: (html.match(/window\.ECHO_BUILD\s*=\s*'([^']+)'/) || [])[1] || 'unknown',
  narrationFiles: Object.keys(sourceManifest).length,
  sourceAudioFiles: sourceAudioFiles.length,
  sourceWavFiles: sourceWavFiles.length,
  preservedSourceAudio: true,
}, null, 2)}\n`);

process.stdout.write(
  `Built ${relative(root, output)} with ${Object.keys(sourceManifest).length} narration entries`
  + ` and ${sourceWavFiles.length} original WAV files.\n`,
);

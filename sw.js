// Echo Cave — Service Worker
// Build tag must match window.ECHO_BUILD in index.html.
// Changing BUILD invalidates the old cache and re-fetches everything on next visit.
const BUILD = '20260523a';
const CACHE = `echo-cave-${BUILD}`;

// Core assets pre-cached on install (~35 MB).
// Voice clips (audio/voice/*.wav) are runtime-cached as they're fetched during play —
// after one full playthrough the game is completely offline.
const PRECACHE = [
  'index.html',
  'manifest.json',
  'audio/voice/manifest.json',
  'audio/welcome-music.mp3',
  'audio/friction-stone.wav',
  'audio/friction-wet.wav',
  'audio/friction-sand.wav',
  'audio/friction-gravel.wav',
  'audio/step-stone.wav',
  'audio/step-wet.wav',
  'audio/step-sand.wav',
  'audio/step-gravel.wav',
  'audio/ambient-shallow.wav',
  'audio/ambient-deep.wav',
  'audio/drip-loop.wav',
  'audio/wind-loop.wav',
  'audio/hum-loop.wav',
  'audio/chime-loop.wav',
  'audio/echo-loop.wav',
  'audio/bed-base-classic.wav',
  'audio/bed-classic-shallow.wav',
  'audio/bed-classic-mid.wav',
  'audio/bed-classic-deep.wav',
  'audio/bed-base-grotto.wav',
  'audio/bed-grotto-shallow.wav',
  'audio/bed-grotto-mid.wav',
  'audio/bed-grotto-deep.wav',
  'icons/icon-192.png',
  'icons/icon-512.png',
  'icons/icon-180.png',
  'icons/icon-maskable-512.png',
];

self.addEventListener('install', event => {
  event.waitUntil(
    caches.open(CACHE)
      .then(cache => cache.addAll(PRECACHE))
      .then(() => self.skipWaiting())
  );
});

self.addEventListener('activate', event => {
  event.waitUntil(
    caches.keys()
      .then(keys => Promise.all(
        keys.filter(k => k !== CACHE).map(k => caches.delete(k))
      ))
      .then(() => self.clients.claim())
  );
});

self.addEventListener('fetch', event => {
  if (event.request.method !== 'GET') return;
  const url = new URL(event.request.url);
  if (url.origin !== self.location.origin) return;

  // Network-first for HTML / navigation so a stuck cached index.html can never
  // pin players to an old build. Falls back to cache when offline.
  const isHTML =
    event.request.mode === 'navigate' ||
    url.pathname === '/' ||
    url.pathname.endsWith('/') ||
    url.pathname.endsWith('.html');

  if (isHTML) {
    event.respondWith(
      fetch(event.request)
        .then(response => {
          if (response && response.ok) {
            const clone = response.clone();
            caches.open(CACHE).then(cache => cache.put(event.request, clone));
          }
          return response;
        })
        .catch(() => caches.match(event.request, { ignoreSearch: true }))
    );
    return;
  }

  event.respondWith(
    // ignoreSearch: true so ?v=BUILD cache-bust params don't cause cache misses
    caches.match(event.request, { ignoreSearch: true })
      .then(cached => {
        if (cached) return cached;

        return fetch(event.request).then(response => {
          if (!response.ok) return response;

          // Runtime-cache voice clips as they're fetched during gameplay
          if (url.pathname.includes('/audio/voice/')) {
            const clone = response.clone();
            caches.open(CACHE).then(cache => cache.put(event.request, clone));
          }
          return response;
        });
      })
  );
});

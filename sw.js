// 漫途記帳 · Service Worker
// 策略：static shell 走 cache-first（離線可開）、Supabase API 走 network-only

const SW_VERSION = 'v1';
const SHELL_CACHE = `venturo-money-shell-${SW_VERSION}`;

const SHELL_URLS = [
  '/',
  '/index.html',
  '/config.js',
  '/manifest.json',
  '/icons/icon-192.png',
  '/icons/icon-512.png',
];

self.addEventListener('install', (e) => {
  e.waitUntil(
    caches.open(SHELL_CACHE).then(cache => cache.addAll(SHELL_URLS).catch(() => null))
  );
  self.skipWaiting();
});

self.addEventListener('activate', (e) => {
  e.waitUntil(
    caches.keys().then(keys => Promise.all(
      keys.filter(k => k.startsWith('venturo-money-') && k !== SHELL_CACHE)
          .map(k => caches.delete(k))
    ))
  );
  self.clients.claim();
});

self.addEventListener('fetch', (e) => {
  const req = e.request;
  const url = new URL(req.url);

  // 跳過：非 GET / Supabase API / Google Fonts CDN（走 network、不要 cache 動態資料）
  if (req.method !== 'GET') return;
  if (url.hostname.endsWith('supabase.co')) return;
  if (url.hostname.includes('fonts.googleapis.com') || url.hostname.includes('fonts.gstatic.com')) return;
  if (url.hostname.includes('jsdelivr.net')) return;

  // 同源資源：cache-first、背景更新
  if (url.origin === self.location.origin) {
    e.respondWith(
      caches.match(req).then(cached => {
        const fetchAndCache = fetch(req).then(res => {
          if (res && res.status === 200 && res.type === 'basic') {
            const clone = res.clone();
            caches.open(SHELL_CACHE).then(cache => cache.put(req, clone));
          }
          return res;
        }).catch(() => cached);
        return cached || fetchAndCache;
      })
    );
  }
});

// 允許前端訊息觸發更新
self.addEventListener('message', (e) => {
  if (e.data && e.data.type === 'SKIP_WAITING') self.skipWaiting();
});

/* ALIN PWA updater — v4.2.2 */
(function(){
  'use strict';

  if (!('serviceWorker' in navigator)) return;
  if (!/^https?:$/.test(location.protocol)) return;

  const RELOAD_KEY = 'alin_pwa_reload_v4_2_2';

  window.addEventListener('load', async () => {
    try {
      navigator.serviceWorker.addEventListener('controllerchange', () => {
        if (sessionStorage.getItem(RELOAD_KEY) === '1') return;
        sessionStorage.setItem(RELOAD_KEY, '1');
        location.reload();
      });

      const registration = await navigator.serviceWorker.register(
        './service-worker.js?v=4.2.2',
        { scope: './', updateViaCache: 'none' }
      );

      if (registration.waiting) {
        registration.waiting.postMessage({ type: 'SKIP_WAITING' });
      }

      registration.addEventListener('updatefound', () => {
        const worker = registration.installing;
        if (!worker) return;

        worker.addEventListener('statechange', () => {
          if (worker.state === 'installed' && navigator.serviceWorker.controller) {
            worker.postMessage({ type: 'SKIP_WAITING' });
          }
        });
      });

      await registration.update();
    } catch (error) {
      console.warn('[ALIN PWA]', error);
    }
  }, { once: true });
})();

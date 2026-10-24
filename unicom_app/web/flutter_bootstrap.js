// Custom Flutter web loader for UniCom.
//
// Two changes over the generated default, both aimed at making the hosted
// build load fast through the (throttled) tunnel:
//   1. CanvasKit is fetched from the Google CDN (edge-cached, ~7 MB) instead of
//      being served from our own host — the self-hosted variant added 36 MB of
//      local transfer on the critical path.
//   2. The service worker is disabled — a stale cached service worker was a
//      common cause of the white-screen "won't load" reports after a redeploy.
//
// The engine revision below must match the Flutter SDK used for the build.
const UNICOM_CANVASKIT_BASE =
  'https://www.gstatic.com/flutter-canvaskit/deb287481e';

// Pull in the framework loader, then boot with our overrides.
const script = document.createElement('script');
script.src = 'flutter.js';
script.onload = () => {
  _flutter.loader.load({
    serviceWorkerSettings: null,
    config: {
      canvasKitBaseUrl: UNICOM_CANVASKIT_BASE,
    },
  });
};
document.head.appendChild(script);

// Pi Kiosk — smooth page refresh
// REFRESH_MS is replaced by pi-kiosk when generating the extension
(function() {
  var REFRESH_MS = __REFRESH_MS__;
  if (REFRESH_MS <= 0) return;

  // Don't run in sub-frames
  if (window !== window.top) return;

  setTimeout(function() {
    // Grab the page's background color for a seamless overlay
    var bg = getComputedStyle(document.body).backgroundColor;
    if (!bg || bg === 'rgba(0, 0, 0, 0)' || bg === 'transparent') {
      bg = getComputedStyle(document.documentElement).backgroundColor;
    }
    if (!bg || bg === 'rgba(0, 0, 0, 0)' || bg === 'transparent') {
      bg = '#ffffff';
    }

    // Create a full-screen overlay that fades in
    var overlay = document.createElement('div');
    overlay.style.cssText =
      'position:fixed;top:0;left:0;width:100vw;height:100vh;' +
      'z-index:2147483647;pointer-events:none;' +
      'opacity:0;transition:opacity 0.8s ease-in-out;' +
      'background:' + bg;
    document.body.appendChild(overlay);

    // Trigger fade
    requestAnimationFrame(function() {
      overlay.style.opacity = '1';

      // After overlay fully covers the page, reload
      setTimeout(function() {
        location.reload();
      }, 900);
    });
  }, REFRESH_MS);
})();

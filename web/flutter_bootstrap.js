{{flutter_js}}
{{flutter_build_config}}

// Load CanvasKit from this same site (not Google's CDN) so the offline cache can keep it,
// and skip Flutter's deprecated service worker: sw.js handles offline instead.
_flutter.loader.load({
  config: { canvasKitBaseUrl: 'canvaskit/' },
});

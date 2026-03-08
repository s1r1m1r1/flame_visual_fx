import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flame/components.dart';
import 'package:flame/rendering.dart';

/// A [Decorator] that applies a "Neon Glow" (Soft Aura) effect behind the component.
/// It uses standard Flutter `ImageFilter.blur` to expand the component's alpha channel
/// into a soft glowing shadow, tinted with a vibrant neon color.
/// For animations (pulsating glow), use [NeonGlowEffect].
class NeonGlowDecorator extends Decorator {
  NeonGlowDecorator({
    required this.component,
    this.color = const ui.Color.fromARGB(255, 0, 255, 255), // Cyberpunk Cyan
    this.radius = 8.0,
    this.isActive = true,
    this.cacheKey,
  });

  final PositionComponent component;
  ui.Color color;
  double radius;
  bool isActive;

  /// Optional key to cache the rendered glow globally as a GPU texture.
  /// Glows are cached per radius (discretized to nearest 0.5px).
  Object? cacheKey;

  static final Map<Object, ui.Image> _globalImageCache = {};
  static final Set<Object> _pendingBakes = {};

  /// Clears the global glow caches to free GPU memory.
  static void clearCache() {
    for (final img in _globalImageCache.values) {
      img.dispose();
    }
    _globalImageCache.clear();
    _pendingBakes.clear();
  }

  final ui.Paint _imagePaint = ui.Paint();

  @override
  void apply(void Function(ui.Canvas) draw, ui.Canvas canvas) {
    if (!isActive) {
      draw(canvas);
      return;
    }

    final size = component.size;
    if (size.x <= 0 || size.y <= 0) {
      draw(canvas);
      return;
    }

    final safeRadius = math.max(0.1, radius);

    // --- ULTRA FAST PATH: Global Bitmap (Image) Cache ---
    if (cacheKey != null) {
      // Discretize radius to 0.5 intervals to keep cache size sane
      // while maintaining smooth visuals.
      final double discRadius = (safeRadius * 2).roundToDouble() / 2.0;
      final Object effectiveKey =
          '${cacheKey}_${discRadius.toStringAsFixed(1)}';

      final cachedImage = _globalImageCache[effectiveKey];
      if (cachedImage != null) {
        // 1. Draw cached glow behind
        _imagePaint.colorFilter =
            ui.ColorFilter.mode(color, ui.BlendMode.srcIn);

        // Glow is baked with extra padding for the blur (radius * 3 for safety)
        final double pad = discRadius * 3.0;
        canvas.drawImage(cachedImage, ui.Offset(-pad, -pad), _imagePaint);

        // 2. Draw actual component on top
        draw(canvas);
        return;
      }

      // --- JANK SUPPRESSOR ---
      // If a bake is already pending, we skip the expensive saveLayer fallback
      // for 99.9% of the components. Only the first one to trigger it will
      // perform the bake, and while that's happening, everyone else renders
      // the base component at 60fps instead of 5fps.
      final bool isPending = _pendingBakes.contains(effectiveKey);
      if (isPending) {
        draw(canvas);
        return;
      }

      // If not cached, trigger background baking for this specific radius
      _bakeGlow(draw, cacheKey!, discRadius);
    }

    // --- FALLBACK PATH: saveLayer fallback ---
    final glowPaint = ui.Paint()
      ..colorFilter = ui.ColorFilter.mode(color, ui.BlendMode.srcIn)
      ..imageFilter =
          ui.ImageFilter.blur(sigmaX: safeRadius, sigmaY: safeRadius);

    canvas.saveLayer(null, glowPaint);
    draw(canvas);
    canvas.restore();

    draw(canvas);
  }

  /// Asynchronously bakes the glow silhouette into a GPU texture.
  void _bakeGlow(void Function(ui.Canvas) draw, Object key, double radius) {
    final Object effectiveKey = '${key}_${radius.toStringAsFixed(1)}';
    if (_pendingBakes.contains(effectiveKey)) return;
    _pendingBakes.add(effectiveKey);

    final double w = component.size.x;
    final double h = component.size.y;

    // Padding needs to accommodate the blur. 3x sigma is usually enough
    // to capture the significant parts of the Gaussian tail.
    final double pad = radius * 3.0;
    final int imgW = (w + pad * 2).ceil();
    final int imgH = (h + pad * 2).ceil();

    if (imgW <= 0 || imgH <= 0) {
      _pendingBakes.remove(effectiveKey);
      return;
    }

    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    canvas.translate(pad, pad);

    // We bake a WHITE blurred silhouette.
    final bakePaint = ui.Paint()
      ..colorFilter =
          const ui.ColorFilter.mode(ui.Color(0xFFFFFFFF), ui.BlendMode.srcIn)
      ..imageFilter = ui.ImageFilter.blur(sigmaX: radius, sigmaY: radius);

    canvas.saveLayer(null, bakePaint);
    draw(canvas);
    canvas.restore();

    final resultPicture = recorder.endRecording();

    resultPicture.toImage(imgW, imgH).then((image) {
      _globalImageCache[effectiveKey] = image;
      _pendingBakes.remove(effectiveKey);
      resultPicture.dispose();
    }).catchError((_) {
      _pendingBakes.remove(effectiveKey);
      resultPicture.dispose();
    });
  }
}

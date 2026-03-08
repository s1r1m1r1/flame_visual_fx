import 'dart:math';
import 'dart:ui' as ui;
import 'package:flame/components.dart';
import 'package:flame/rendering.dart';

/// A [Decorator] that applies an outline to the component using native saveLayer tinting.
/// This sidesteps all WebGL and Transform Matrix rounding errors, natively tracking camera
/// limits and asset bounds securely.
class OutlineDecorator extends Decorator {
  OutlineDecorator({
    required this.component,
    this.vertices,
    this.color = const ui.Color.fromARGB(255, 253, 6, 138),
    this.thickness = 2.0,
    this.margin = 0.0,
    this.isActive = true,
    this.cacheKey,
  });

  final PositionComponent component;
  List<Vector2>? vertices;
  ui.Color color;
  double thickness;
  double margin;
  bool isActive;

  /// Optional key to cache the rendered silhouette globally as a GPU texture.
  /// This provides near-zero overhead for repeated renders (e.g. 500 birds).
  Object? cacheKey;

  static final Map<Object, ui.Image> _globalImageCache = {};
  static final Set<Object> _pendingBakes = {};

  /// Clears the global silhouette caches to free GPU memory.
  static void clearCache() {
    for (final pic in _globalPictureCache.values) {
      pic.dispose();
    }
    _globalPictureCache.clear();
    for (final img in _globalImageCache.values) {
      img.dispose();
    }
    _globalImageCache.clear();
    _pendingBakes.clear();
  }

  static final Map<Object, ui.Picture> _globalPictureCache = {};

  List<Vector2>? _lastVertices;
  ui.Path? _cachedPath;
  ui.Paint? _cachedPaint;
  ui.Color? _lastColor;
  double? _lastThickness;

  final ui.Paint _imagePaint = ui.Paint();

  void update(double dt) {
    super.update(dt);
  }

  @override
  void apply(void Function(ui.Canvas) draw, ui.Canvas canvas) {
    if (!isActive) {
      draw(canvas);
      return;
    }

    // --- ULTRA FAST PATH: Global Bitmap (Image) Cache ---
    if (cacheKey != null) {
      // We append thickness to the key because a 2px outline and 5px outline
      // require different "baked" silhouettes.
      final Object effectiveKey = '${cacheKey}_$thickness';
      final cachedImage = _globalImageCache[effectiveKey];
      if (cachedImage != null) {
        _imagePaint.colorFilter =
            ui.ColorFilter.mode(color, ui.BlendMode.srcIn);

        // Draw the baked outline silhouette FIRST (behind)
        final double pad = thickness;
        canvas.drawImage(cachedImage, ui.Offset(-pad, -pad), _imagePaint);

        // Draw the component LAST (on top)
        draw(canvas);
        return;
      }
    }

    // --- FAST PATH: Polygon-based Outline ---
    // If vertices are provided, we use drawPath which is significantly faster.
    if (vertices != null && vertices!.length >= 2) {
      draw(canvas); // Draw the component first

      if (_cachedPaint == null ||
          _lastColor != color ||
          _lastThickness != thickness) {
        _cachedPaint = ui.Paint()
          ..color = color
          ..strokeWidth = thickness
          ..style = ui.PaintingStyle.stroke
          ..strokeCap = ui.StrokeCap.round
          ..strokeJoin = ui.StrokeJoin.round;
        _lastColor = color;
        _lastThickness = thickness;
      }

      // Check if we need to rebuild the path
      if (_cachedPath == null || _lastVertices != vertices) {
        final path = ui.Path();
        for (int i = 0; i < vertices!.length; i++) {
          final v = vertices![i];
          if (i == 0) {
            path.moveTo(v.x, v.y);
          } else {
            path.lineTo(v.x, v.y);
          }
        }
        path.close();
        _cachedPath = path;
        _lastVertices = vertices;
      }

      canvas.drawPath(_cachedPath!, _cachedPaint!);
      // Trigger async baking if we have a key
      if (cacheKey != null && !_pendingBakes.contains(cacheKey)) {
        _bakeSilhouette(draw, cacheKey!);
      }
      return;
    }

    // --- SLOW PATH: saveLayer fallback with Global Cache ---
    ui.Picture? picture;
    if (cacheKey != null) {
      picture = _globalPictureCache[cacheKey!];
    }

    if (picture == null) {
      // Capture the component's render into a Picture.
      final recorder = ui.PictureRecorder();
      final tempCanvas = ui.Canvas(recorder);
      draw(tempCanvas);
      picture = recorder.endRecording();

      // Update cache
      if (cacheKey != null) {
        _globalPictureCache[cacheKey!] = picture;
        // Trigger async baking for Ultra Fast Path
        _bakeSilhouette(draw, cacheKey!);
      }
    }

    try {
      final outlinePaint = ui.Paint()
        ..colorFilter = ui.ColorFilter.mode(color, ui.BlendMode.srcIn);

      canvas.saveLayer(null, outlinePaint);

      // Use a circular distribution (16 samples) to ensure a perfectly smooth
      // thick outline without gaps or "delamination".
      const int samples = 16;
      for (int i = 0; i < samples; i++) {
        final double angle = (i * 2 * pi) / samples;
        canvas.save();
        canvas.translate(cos(angle) * thickness, sin(angle) * thickness);
        canvas.drawPicture(picture);
        canvas.restore();
      }

      canvas.restore();

      canvas.drawPicture(picture);
    } finally {
      // If we are NOT caching, dispose immediately.
      if (cacheKey == null) {
        picture.dispose();
      }
    }
  }

  /// Asynchronously bakes the component's silhouette into a GPU texture.
  void _bakeSilhouette(void Function(ui.Canvas) draw, Object key) {
    // Append thickness to ensure we bake the correct stroke width
    final Object effectiveKey = '${key}_$thickness';
    if (_pendingBakes.contains(effectiveKey)) return;
    _pendingBakes.add(effectiveKey);

    // We need to know the size to capture.
    // PositionComponent doesn't strictly define draw bounds, but component.size
    // is usually the safest bet for sprites.
    final double w = component.size.x;
    final double h = component.size.y;

    // Add padding for thickness
    final double pad = thickness;
    final int imgW = (w + pad * 2).ceil();
    final int imgH = (h + pad * 2).ceil();

    if (imgW <= 0 || imgH <= 0) {
      _pendingBakes.remove(effectiveKey);
      return;
    }

    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);

    // Translate to center the capture
    canvas.translate(pad, pad);

    // We bake a WHITE silhouette. This allows us to tint it to ANY color
    // using ColorFilter.mode(color, BlendMode.srcIn) during drawImage.
    final bakePaint = ui.Paint()
      ..colorFilter =
          const ui.ColorFilter.mode(ui.Color(0xFFFFFFFF), ui.BlendMode.srcIn);

    canvas.saveLayer(null, bakePaint);

    // Use the 8-offset technique to create the thick outline mask
    final recorderInner = ui.PictureRecorder();
    final canvasInner = ui.Canvas(recorderInner);
    draw(canvasInner);
    final ui.Picture pictureInner = recorderInner.endRecording();

    const int samples = 16;
    for (int i = 0; i < samples; i++) {
      final double angle = (i * 2 * pi) / samples;
      canvas.save();
      canvas.translate(cos(angle) * thickness, sin(angle) * thickness);
      canvas.drawPicture(pictureInner);
      canvas.restore();
    }

    canvas.restore(); // Restore saveLayer (tinting)
    pictureInner.dispose();

    final resultPicture = recorder.endRecording();

    // Async conversion to Image
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

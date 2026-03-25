import 'dart:ui' as ui;
import 'package:flame/components.dart';
import 'package:flame/rendering.dart';
import 'vfx_decorator.dart';

/// A [Decorator] that applies a shader-based outline to a component.
/// It uses a [ui.FragmentShader] to perform the outline expansion in a single GPU pass,
/// which is more efficient than the traditional multi-offset Canvas approach.
///
/// Use [ShaderOutlineDecorator] for high-performance outlines on complex components.
class ShaderOutlineDecorator extends VFXDecorator {
  ShaderOutlineDecorator({
    required this.shader,
    required this.component,
    this.color = const ui.Color(0xFFFD068A),
    this.thickness = 2.0,
    this.isActive = true,
    this.cacheKey,
  });

  /// Optional key to cache the rendered silhouette globally as a GPU texture.
  /// This provides near-zero overhead for repeated renders (e.g. 1000 birds).
  Object? cacheKey;

  static final Map<Object, ui.Image> _globalImageCache = {};
  static final Set<Object> _pendingBakes = {};

  /// Clears the global silhouette caches to free GPU memory.
  static void clearCache() {
    for (final img in _globalImageCache.values) {
      img.dispose();
    }
    _globalImageCache.clear();
    _pendingBakes.clear();
  }

  /// The fragment shader to use for the outline effect.
  final ui.FragmentShader shader;

  /// The component to which the outline is applied.
  final PositionComponent component;

  /// The color of the outline.
  ui.Color color;

  /// The thickness of the outline in logical pixels.
  double thickness;

  /// Whether the outline is currently active.
  bool isActive;

  ui.Image? _lastImage;
  ui.Picture? _lastPicture;

  // Cache the image to avoid re-baking every frame.
  // In a real game, you'd want to invalidate this if the component's appearance changes.
  bool _needsRebake = true;

  @override
  void apply(void Function(ui.Canvas) draw, ui.Canvas canvas) {
    if (!isActive) {
      draw(canvas);
      return;
    }

    final double w = component.size.x;
    final double h = component.size.y;

    if (w <= 0 || h <= 0) {
      draw(canvas);
      return;
    }

    // --- ULTRA FAST PATH: Global Bitmap (Image) Cache ---
    if (cacheKey != null) {
      final Object effectiveKey = '${cacheKey}_$thickness';
      final cachedImage = _globalImageCache[effectiveKey];
      if (cachedImage != null) {
        _drawWithShader(canvas, w, h, cachedImage);
        return;
      }

      // If already baking, just fallback to normal draw to avoid jank
      if (_pendingBakes.contains(effectiveKey)) {
        draw(canvas);
        return;
      }
    }

    // Since decorators work by wrapping a `draw` call, we MUST capture the component
    // into an Image to pass it to the fragment shader.
    if (_needsRebake || _lastImage == null) {
      _bake(draw);
      if (cacheKey == null) {
        _needsRebake = false;
      }
    }

    final effectiveImage = (cacheKey != null)
        ? _globalImageCache['${cacheKey}_$thickness']
        : _lastImage;

    if (effectiveImage != null) {
      _drawWithShader(canvas, w, h, effectiveImage);
    } else {
      // Fallback if image isn't ready yet
      draw(canvas);
    }
  }

  void _drawWithShader(ui.Canvas canvas, double w, double h, ui.Image image) {
    final double pad = thickness;

    // Update shader uniforms
    // 0, 1: uSize
    shader.setFloat(0, w + pad * 2);
    shader.setFloat(1, h + pad * 2);

    // 2, 3, 4, 5: uColor
    shader.setFloat(2, color.red / 255.0);
    shader.setFloat(3, color.green / 255.0);
    shader.setFloat(4, color.blue / 255.0);
    shader.setFloat(5, color.alpha / 255.0);

    // 6: uThickness
    shader.setFloat(6, thickness);

    // Sampler 0: uTexture
    shader.setImageSampler(0, image);

    final paint = ui.Paint()..shader = shader;

    // Draw the shader-processed result
    canvas.save();
    canvas.translate(-pad, -pad);
    canvas.drawRect(ui.Rect.fromLTWH(0, 0, w + pad * 2, h + pad * 2), paint);
    canvas.restore();
  }

  void _bake(void Function(ui.Canvas) draw) {
    final double w = component.size.x;
    final double h = component.size.y;
    final double pad = thickness;
    final Object? effectiveKey = cacheKey != null
        ? '${cacheKey}_$thickness'
        : null;

    if (effectiveKey != null) {
      if (_pendingBakes.contains(effectiveKey)) return;
      _pendingBakes.add(effectiveKey);
    }

    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);

    canvas.translate(pad, pad);
    draw(canvas);

    final picture = recorder.endRecording();

    // Convert to image. Note: this is typically an expensive operation!
    picture
        .toImage((w + pad * 2).ceil(), (h + pad * 2).ceil())
        .then((image) {
          if (effectiveKey != null) {
            _globalImageCache[effectiveKey] = image;
            _pendingBakes.remove(effectiveKey);
          } else {
            _lastImage?.dispose();
            _lastImage = image;
          }
          picture.dispose();
        })
        .catchError((_) {
          if (effectiveKey != null) {
            _pendingBakes.remove(effectiveKey);
          }
          picture.dispose();
        });
  }

  /// Forces the decorator to re-capture the component's silhouette.
  void invalidate() {
    _needsRebake = true;
  }

  @override
  void dispose() {
    _lastImage?.dispose();
    _lastPicture?.dispose();
  }
}

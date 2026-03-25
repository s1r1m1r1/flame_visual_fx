import 'dart:ui' as ui;
import 'package:flame/components.dart';
import 'package:flame/rendering.dart';
import 'vfx_decorator.dart';
import '../effects/dissolve_effect.dart';
import 'dissolve_mask.dart';

export 'dissolve_mask.dart';

/// A [Decorator] that organically dissolves (erases) the character.
/// It uses a pre-calculated noise pattern to create a "teleportation"
/// or "disintegration" effect. Animation is driven by the [progress] parameter.
class DissolveDecorator extends VFXDecorator implements DissolveProvider {
  DissolveDecorator({
    required this.component,
    required this.mask,
    this.isActive = true,
    this.showResidualEffect = false,
    double progress = 0.0,
    this.type = DissolveType.bottomUp,
    this.noiseWeight = 0.3,
    super.controller,
    super.onComplete,
    Vector2? visualOffset,
    Vector2? visualScale,
    Vector2? visualAnchor,
    this.renderSize,
  }) : visualOffset = visualOffset ?? Vector2.zero(),
       visualScale = visualScale ?? Vector2.all(1.0),
       visualAnchor = visualAnchor ?? Vector2.zero(),
       super(initialProgress: progress);

  @override
  double get dissolveThreshold => progress;

  @override
  set dissolveThreshold(double value) => progress = value;

  @override
  void update(double dt) {
    super.update(dt);
  }

  final PositionComponent component;
  
  /// The mask rendering strategy.
  DissolveMask mask;

  bool isActive;

  /// The pattern strategy to use for dissolution.
  DissolveType type;

  /// How much the noise influences the edge.
  /// 0.0 for a clean line, 1.0 for a very fuzzy/random edge.
  double noiseWeight;

  /// If true, a faint "residual" silhouette might remain after dissolution.
  /// If false (default), the component is completely hidden at the end of duration.
  bool showResidualEffect;

  /// Local offset of the visuals relative to the component origin.
  Vector2 visualOffset;

  /// Local scale of the visuals relative to the component origin.
  Vector2 visualScale;

  /// Local target-specific anchor offset (in logical pixels).
  Vector2 visualAnchor;

  /// Optional override for the size of the erasure area.
  /// If null, the component's logical size is used.
  Vector2? renderSize;

  @override
  void apply(void Function(ui.Canvas) draw, ui.Canvas canvas) {
    if (!isActive || progress <= 0) {
      draw(canvas);
      return;
    }

    if (progress >= 1.0) {
      if (showResidualEffect) {
        // Draw the ghostly remains
        final paint = ui.Paint()
          ..colorFilter = const ui.ColorFilter.matrix([
            0.2126, 0.7152, 0.0722, 0, 0,
            0.2126, 0.7152, 0.0722, 0, 0,
            0.2126, 0.7152, 0.0722, 0, 0,
            0,      0,      0,      0.3, 0,
          ]);
        canvas.saveLayer(null, paint);
        draw(canvas);
        canvas.restore();
      }
      return;
    }

    // --- Progressive Dissolve Logic ---
    final effectiveSize = renderSize ?? component.size;

    // 1. Save an isolated layer where we will draw the original FIRST
    canvas.saveLayer(null, ui.Paint());
    draw(canvas); // The intact component is now painted on this layer

    // 2. Erase blocks based on progress and noise
    final erasePaint = ui.Paint()..blendMode = ui.BlendMode.dstOut;

    canvas.save();
    canvas.translate(visualOffset.x, visualOffset.y);
    canvas.scale(visualScale.x, visualScale.y);
    canvas.translate(visualAnchor.x, visualAnchor.y);

    mask.renderMask(
      canvas,
      erasePaint,
      effectiveSize,
      progress,
      type,
      noiseWeight,
    );

    canvas.restore(); // Restore local transform
    canvas.restore(); // Restore layer
  }

  /// Utility to create a noise grid from a grayscale image.
  static Future<List<double>> computeNoiseFromImage(ui.Image image) async {
    final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (byteData == null) return [];

    final int width = image.width;
    final int height = image.height;
    final List<double> noise = List.filled(width * height, 0.0);

    for (int i = 0; i < width * height; i++) {
      final r = byteData.getUint8(i * 4);
      final g = byteData.getUint8(i * 4 + 1);
      final b = byteData.getUint8(i * 4 + 2);
      // Simple average for gray value
      noise[i] = (r + g + b) / (3.0 * 255.0);
    }
    return noise;
  }
}

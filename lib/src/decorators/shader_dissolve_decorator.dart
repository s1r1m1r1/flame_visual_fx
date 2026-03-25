import 'dart:ui' as ui;
import 'package:flame/components.dart';
import 'package:flame/rendering.dart';
import 'package:vector_math/vector_math.dart' as v64;
import 'vfx_decorator.dart';
import 'dissolve_mask.dart';

/// A [Decorator] that applies a dissolve shader effect to a component.
/// It uses a [ui.FragmentShader] to organically erase the component's pixels.
class ShaderDissolveDecorator extends VFXDecorator {
  final ui.FragmentShader shader;
  final PositionComponent component;

  /// The pattern strategy to use for dissolution.
  DissolveType type;

  /// How much the noise influences the edge.
  double noiseWeight;

  /// Local offset of the visuals relative to the component origin.
  Vector2 visualOffset;

  /// Local scale of the visuals relative to the component origin.
  Vector2 visualScale;

  /// Local target-specific anchor offset (in logical pixels).
  Vector2 visualAnchor;

  /// Optional override for the size of the erasure area.
  Vector2? renderSize;

  /// Optional callback to set additional uniforms for custom shaders.
  final void Function(ui.FragmentShader shader, double progress, double time)?
  onApply;

  /// Global accumulated time for periodic shader animations.
  double time = 0.0;

  bool isActive;
  bool autoAnimate;

  /// Manual calibration offset. Applied as a size adjustment in logical units.
  Vector2 calibrationOffset;

  ShaderDissolveDecorator({
    required this.shader,
    required this.component,
    this.type = DissolveType.bottomUp,
    this.noiseWeight = 0.3,
    this.isActive = true,
    this.autoAnimate = true,
    Vector2? calibrationOffset,
    super.controller,
    super.onComplete,
    double progress = 0.0,
    Vector2? visualOffset,
    Vector2? visualScale,
    Vector2? visualAnchor,
    this.renderSize,
    this.onApply,
  }) : visualOffset = visualOffset ?? Vector2.zero(),
       visualScale = visualScale ?? Vector2.all(1.0),
       visualAnchor = visualAnchor ?? Vector2.zero(),
       calibrationOffset = calibrationOffset ?? Vector2.zero(),
       super(initialProgress: progress);

  @override
  void update(double dt) {
    super.update(dt);
    if (isActive) {
      time += dt;
    }
  }

  @override
  void apply(void Function(ui.Canvas) draw, ui.Canvas canvas) {
    if (!isActive || progress <= 0.0) {
      draw(canvas);
      return;
    }

    if (progress >= 1.0) {
      return;
    }

    final effectiveSize = renderSize ?? component.size;

    final game = component.findGame();
    if (game == null || !game.isAttached) {
      draw(canvas);
      return;
    }

    try {
      if (!game.isLoaded) {
        draw(canvas);
        return;
      }

      if (effectiveSize.x <= 0 || effectiveSize.y <= 0) {
        draw(canvas);
        return;
      }

      // COORDINATE SYSTEM DISCOVERY (empirical, confirmed by 4 debug runs):
      // FlutterFragCoord() inside a saveLayer with a transformed canvas returns
      // component-LOCAL coordinates (0..size.x, 0..size.y), NOT screen-physical.
      // This occurs because Skia shaders use the local coordinate space before CTM.
      //
      // Therefore: UV = fragCoord / size — no camera-transform matrix needed.
      // The saveLayer + dstOut masking correctly clips to the component's pixels.

      final w = effectiveSize.x + calibrationOffset.x;
      final h = effectiveSize.y + calibrationOffset.y;

      // Scale(1/w, 1/h) diagonal matrix: maps local fragCoord (0..size) → UV (0..1).
      final mat = v64.Matrix4.identity()
        ..scale(1.0 / w, 1.0 / h, 1.0)
        ..translate(
          -visualOffset.x - visualAnchor.x,
          -visualOffset.y - visualAnchor.y,
          0.0,
        );

      // Matrix takes slots 0-15
      shader.setFloat(0, mat.storage[0]);
      shader.setFloat(1, mat.storage[1]);
      shader.setFloat(2, mat.storage[2]);
      shader.setFloat(3, mat.storage[3]);
      shader.setFloat(4, mat.storage[4]);
      shader.setFloat(5, mat.storage[5]);
      shader.setFloat(6, mat.storage[6]);
      shader.setFloat(7, mat.storage[7]);
      shader.setFloat(8, mat.storage[8]);
      shader.setFloat(9, mat.storage[9]);
      shader.setFloat(10, mat.storage[10]);
      shader.setFloat(11, mat.storage[11]);
      shader.setFloat(12, mat.storage[12]);
      shader.setFloat(13, mat.storage[13]);
      shader.setFloat(14, mat.storage[14]);
      shader.setFloat(15, mat.storage[15]);

      // uSize at 16, 17
      shader.setFloat(16, effectiveSize.x);
      shader.setFloat(17, effectiveSize.y);

      // Standard params at 18+
      shader.setFloat(18, progress);
      shader.setFloat(19, type.index.toDouble());
      shader.setFloat(20, noiseWeight);
      shader.setFloat(21, time);

      onApply?.call(shader, progress, time);

      final maskPaint = ui.Paint()
        ..shader = shader
        ..blendMode = ui.BlendMode.dstOut;

      // --- DEBUG VISUALIZER ---
      if (component.debugMode) {
        final debugPaint = ui.Paint()
          ..color = const ui.Color(0xFFFF0000)
          ..style = ui.PaintingStyle.stroke
          ..strokeWidth = 2.0;
        canvas.drawRect(
          ui.Rect.fromLTWH(
            visualOffset.x + visualAnchor.x,
            visualOffset.y + visualAnchor.y,
            effectiveSize.x,
            effectiveSize.y,
          ),
          debugPaint,
        );
      }
      // ------------------------

      // Capture the component's render in a layer, then apply the dissolve mask.
      // drawRect in component-local space ensures the shader covers exactly
      // the component's visual bounds (FragCoord is component-local in this context).
      canvas.saveLayer(null, ui.Paint());
      draw(canvas);
      canvas.drawRect(
        ui.Rect.fromLTWH(
          visualOffset.x + visualAnchor.x,
          visualOffset.y + visualAnchor.y,
          effectiveSize.x,
          effectiveSize.y,
        ),
        maskPaint,
      );
      canvas.restore();
    } catch (e) {
      draw(canvas);
    }
  }
}

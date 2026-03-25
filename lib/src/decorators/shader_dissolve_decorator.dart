import 'dart:ui' as ui;
import 'package:flame/components.dart';
import 'package:flame/rendering.dart';

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

      // COORDINATE SYSTEM:
      // FlutterFragCoord() inside a saveLayer with a transformed canvas returns
      // component-LOCAL coordinates (0..size.x, 0..size.y), NOT screen-physical.
      // Therefore, UV = FragCoord / Size works directly without Matrix4 inversion.

      final w = effectiveSize.x + calibrationOffset.x;
      final h = effectiveSize.y + calibrationOffset.y;

      // Uniforms: uSize (0,1), progress (2), type (3), noise (4), time (5)
      shader.setFloat(0, w);
      shader.setFloat(1, h);
      shader.setFloat(2, progress);
      shader.setFloat(3, type.index.toDouble());
      shader.setFloat(4, noiseWeight);
      shader.setFloat(5, time);

      onApply?.call(shader, progress, time);

      final maskPaint = ui.Paint()
        ..shader = shader
        ..blendMode = ui.BlendMode.dstOut;

      final rect = ui.Rect.fromLTWH(
        visualOffset.x + visualAnchor.x,
        visualOffset.y + visualAnchor.y,
        effectiveSize.x,
        effectiveSize.y,
      );

      // --- DEBUG VISUALIZER ---
      if (component.debugMode) {
        final debugPaint = ui.Paint()
          ..color = const ui.Color(0xFFFF0000)
          ..style = ui.PaintingStyle.stroke
          ..strokeWidth = 2.0;
        canvas.drawRect(rect, debugPaint);
      }
      // ------------------------

      // Capture the component's render in a layer, then apply the dissolve mask.
      // Using a bounded rect is faster than saveLayer(null).
      canvas.saveLayer(rect, ui.Paint());
      draw(canvas);
      canvas.drawRect(rect, maskPaint);
      canvas.restore();
    } catch (e) {
      draw(canvas);
    }
  }
}

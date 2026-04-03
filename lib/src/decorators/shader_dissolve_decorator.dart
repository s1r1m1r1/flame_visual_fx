import 'dart:ui' as ui;
import 'package:flame/components.dart';
import 'package:flame/rendering.dart';
import 'package:vector_math/vector_math_64.dart' as v64;
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

  /// Optional override for the size of the erasure area.
  Vector2? renderSize;

  /// Optional callback to set additional uniforms for custom shaders.
  void Function(ui.FragmentShader shader, double progress, double time)?
  onApply;

  /// Global accumulated time for periodic shader animations.
  double time = 0.0;

  /// The image of the sprite/animation to sample from directly.
  ui.Image image;

  /// The source rectangle within the image to sample from (for sprite sheets).
  ui.Rect sourceRect;

  bool isActive;
  bool autoAnimate;

  /// Manual calibration offset. Applied as a size adjustment in logical units.
  Vector2 calibrationOffset;
  @Deprecated('This is not working as expected')
  ShaderDissolveDecorator({
    required this.shader,
    required this.component,
    required this.image,
    required this.sourceRect,
    this.type = DissolveType.bottomUp,
    this.noiseWeight = 0.3,
    this.isActive = true,
    this.autoAnimate = true,
    Vector2? calibrationOffset,
    super.controller,
    super.onComplete,
    double progress = 0.0,

    this.renderSize,
    this.onApply,
  }) : calibrationOffset = calibrationOffset ?? Vector2.zero(),
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

    if (!game.isLoaded) {
      draw(canvas);
      return;
    }

    if (effectiveSize.x <= 0 || effectiveSize.y <= 0) {
      draw(canvas);
      return;
    }

    // UV TRANSFORM — no saveLayer needed.
    //
    // FlutterFragCoord() returns logical pixel coordinates in GAME CANVAS space
    // (from the top-left of the GameWidget, before any canvas transforms).
    //
    // Strategy: instead of inverting canvas.getTransform() (which is unreliable
    // on web/CanvasKit), we compute the component's screen top-left directly from
    // Flame's camera and build the UV matrix analytically.
    //
    //   uv.x = (fragX - screenTL.x) * scaleX + srcLeft/imgW
    //   scaleX = srcW / (imgW * screenW)   where screenW = w * zoom
    //
    // This is a pure scale+translate — no inversion, no precision loss.

    final w = effectiveSize.x + calibrationOffset.x;
    final h = effectiveSize.y + calibrationOffset.y;
    final imgW = image.width.toDouble();
    final imgH = image.height.toDouble();

    final zoom = game.camera.viewfinder.zoom;
    final camPos = game.camera.viewfinder.position;
    // Component top-left in world space (accounts for anchor)
    final anchorVec = component.anchor.toVector2();
    final worldTL =
        component.absolutePosition -
        Vector2(anchorVec.x * effectiveSize.x, anchorVec.y * effectiveSize.y);
    // World → game-canvas logical pixels.
    // viewport.position gives the canvas offset of the viewport top-left.
    final viewportTL = game.camera.viewport.position;
    final screenTLx =
        (worldTL.x - camPos.x) * zoom +
        game.camera.viewport.size.x * 0.5 +
        viewportTL.x;
    final screenTLy =
        (worldTL.y - camPos.y) * zoom +
        game.camera.viewport.size.y * 0.5 +
        viewportTL.y;

    // Screen width/height of the component (in logical pixels).
    final screenW = w * zoom;
    final screenH = h * zoom;

    // Affine matrix: fragCoord → image texcoord.
    //   col0=[scaleX,0,0,0], col1=[0,scaleY,0,0], col2=[0,0,1,0],
    //   col3=[transX,transY,0,1]  (column-major, matches GLSL mat4 layout)
    final scaleX = sourceRect.width / (imgW * screenW);
    final scaleY = sourceRect.height / (imgH * screenH);
    final transX = -screenTLx * scaleX + sourceRect.left / imgW;
    final transY = -screenTLy * scaleY + sourceRect.top / imgH;

    final mat = v64.Matrix4.zero();
    mat.setEntry(0, 0, scaleX);
    mat.setEntry(1, 1, scaleY);
    mat.setEntry(2, 2, 1.0);
    mat.setEntry(3, 3, 1.0);
    mat.setEntry(0, 3, transX);
    mat.setEntry(1, 3, transY);

    // Matrix takes slots 0-15
    for (var i = 0; i < 16; i++) {
      shader.setFloat(i, mat.storage[i]);
    }

    // uSize at 16, 17
    shader.setFloat(16, w);
    shader.setFloat(17, h);

    // params: progress(18), type(19), noise(20), time(21)
    shader.setFloat(18, progress);
    shader.setFloat(19, type.index.toDouble());
    shader.setFloat(20, noiseWeight);
    shader.setFloat(21, time);

    shader.setImageSampler(0, image);

    onApply?.call(shader, progress, time);

    final paint = ui.Paint()..shader = shader;

    // We draw the RECT that corresponds to the component's visual bounds.
    // Since we are NOT calling draw(canvas), this MUST be visually identical
    // to the sprite's content if progress were 0.
    canvas.drawRect(
      ui.Rect.fromLTWH(0, 0, effectiveSize.x, effectiveSize.y),
      paint,
    );
  }
}

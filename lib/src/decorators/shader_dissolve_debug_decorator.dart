import 'dart:ui' as ui;
import 'package:flame/components.dart';
import 'package:flame/rendering.dart';
import 'package:vector_math/vector_math_64.dart' as v64;
import 'vfx_decorator.dart';
import 'dissolve_mask.dart';

/// A [Decorator] that applies a dissolve shader effect to a component using a robust
/// coordinate mapping system. This version uses [canvas.getTransform()] to handle
/// complex camera and world transformations automatically.
class ShaderDissolveDebugDecorator extends VFXDecorator {
  final ui.FragmentShader shader;
  final PositionComponent component;

  /// The pattern strategy to use for dissolution.
  DissolveType type;

  /// How much the noise influences the edge.
  double noiseWeight;

  /// Optional override for the size of the erasure area.
  Vector2? renderSize;

  /// Manual override for the device pixel ratio.
  /// @deprecated No longer used - coordinate mapping is now automatic.
  @Deprecated('No longer used - coordinate mapping is now automatic')
  double devicePixelRatio;

  /// Optional calibration offset to nudge the coordinate mapping.
  /// @deprecated No longer used - coordinate mapping is now automatic.
  @Deprecated('No longer used - coordinate mapping is now automatic')
  ui.Offset calibrationOffset;

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

  ShaderDissolveDebugDecorator({
    required this.shader,
    required this.component,
    required this.image,
    required this.sourceRect,
    this.type = DissolveType.bottomUp,
    this.noiseWeight = 0.3,
    this.isActive = true,
    this.autoAnimate = true,
    super.controller,
    super.onComplete,
    double progress = 0.0,
    this.renderSize,
    this.onApply,
    this.calibrationOffset = ui.Offset.zero,
    this.devicePixelRatio = 1.0,
  }) : super(initialProgress: progress);

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

    if (effectiveSize.x <= 0 || effectiveSize.y <= 0) {
      draw(canvas);
      return;
    }

    // Dynamically fetch the current image and sourceRect from the component
    // if it's a SpriteAnimationComponent or SpriteComponent.
    // This ensures the shader always renders the correct animation frame.
    ui.Image currentImage = image;
    ui.Rect currentSourceRect = sourceRect;

    if (component is SpriteAnimationComponent) {
      final animComponent = component as SpriteAnimationComponent;
      final ticker = animComponent.animationTicker;
      if (ticker != null) {
        final sprite = ticker.getSprite();
        currentImage = sprite.image;
        currentSourceRect = sprite.src;
      }
    } else if (component is SpriteComponent) {
      final spriteComponent = component as SpriteComponent;
      if (spriteComponent.sprite != null) {
        currentImage = spriteComponent.sprite!.image;
        currentSourceRect = spriteComponent.sprite!.src;
      }
    }

    // 2. Build the UV transform: Local Space -> UV Space
    //
    // FlutterFragCoord() returns coordinates in the current canvas local space,
    // which means after all canvas transforms (including camera). When we draw at
    // Rect.fromLTWH(0, 0, effectiveSize.x, effectiveSize.y), the fragment
    // coordinates are already relative to the component's top-left corner.
    //
    // We only need to map:
    //   LOCAL (0, 0) -> UV (uvLeft, uvTop)
    //   LOCAL (effectiveSize.x, effectiveSize.y) -> UV (uvLeft + sourceRect.width/imgW, uvTop + sourceRect.height/imgH)

    final imgW = currentImage.width.toDouble();
    final imgH = currentImage.height.toDouble();

    // Scale from local space to UV space
    final scaleX = currentSourceRect.width / (imgW * effectiveSize.x);
    final scaleY = currentSourceRect.height / (imgH * effectiveSize.y);
    final uvLeft = currentSourceRect.left / imgW;
    final uvTop = currentSourceRect.top / imgH;

    // Build the Local -> UV transformation matrix
    final mLocalToUV = v64.Matrix4.identity();
    mLocalToUV.setEntry(0, 0, scaleX);
    mLocalToUV.setEntry(1, 1, scaleY);
    mLocalToUV.setEntry(0, 3, uvLeft);
    mLocalToUV.setEntry(1, 3, uvTop);

    // 3. Pass the matrix to the shader (slots 0-15)
    // The shader uses this to transform FlutterFragCoord() to UV coordinates
    for (var i = 0; i < 16; i++) {
      shader.setFloat(i, mLocalToUV.storage[i]);
    }

    shader.setFloat(16, effectiveSize.x);
    shader.setFloat(17, effectiveSize.y);
    shader.setFloat(18, progress);
    shader.setFloat(19, type.index.toDouble());
    shader.setFloat(20, noiseWeight);
    shader.setFloat(21, time);
    shader.setImageSampler(0, currentImage);

    onApply?.call(shader, progress, time);

    final paint = ui.Paint()..shader = shader;

    // Draw in local space - the canvas already has all transforms applied
    canvas.drawRect(
      ui.Rect.fromLTWH(0, 0, effectiveSize.x, effectiveSize.y),
      paint,
    );
  }
}

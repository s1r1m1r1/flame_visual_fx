import 'dart:ui' as ui;
import 'package:flame/rendering.dart';
import 'package:composite_atlas/composite_atlas.dart';
import 'package:flame/extensions.dart';

/// A decorator that applies a "Ghost Trail" shader effect (afterimages).
/// Designed for use with [CompositeAtlas] baking to pre-render motion blur effects
/// into static textures, saving runtime GPU costs.
class ShaderGhostTrailDecorator extends Decorator implements AtlasDecorator {
  final ui.FragmentShader shader;

  /// The main color of the ghost trail.
  ui.Color color;

  /// The direction vector of the trail (should be normalized for stability).
  Vector2 direction;

  /// The length/strength of the trail (0.0 to 1.0).
  double strength;

  /// How much to tint the trail images with the specified [color] (0.0 to 1.0).
  double tintFactor;

  /// Transient time state used for looping animations during baking.
  double _time = 0.0;

  // Atlas context data from CompositeAtlas
  ui.Image? _atlasImage;
  ui.Rect? _srcRect;
  ui.Size? _atlasSize;
  ui.Size? _localSize;

  ShaderGhostTrailDecorator({
    required this.shader,
    this.color = const ui.Color.fromARGB(255, 114, 0, 255), // Purple ghost
    Vector2? direction,
    this.strength = 0.5,
    this.tintFactor = 0.5,
    this.includeBase = true,
  }) : direction = direction ?? Vector2(0, 1.0); // Default downward trail

  /// If true, the base sprite will be drawn after the ghost trail.
  /// Set to false when layering multiple decorators to avoid duplicates.
  bool includeBase;

  @override
  void updateAtlasContext(AtlasContext context) {
    _atlasImage = context.atlasImage;
    _srcRect = context.srcRect;
    _atlasSize = context.atlasSize;
    _localSize = context.localSize;

    // Use normalized time (0.0 to 1.0) based on frame index to ensure perfect looping
    final index = context.itemIndex ?? 0;
    final count = context.itemCount ?? 1;
    _time = count > 0 ? index / count : 0.0;
  }

  /// Loader method to handle shader loading from the visual_fx package.
  /// This should be called before start of the baking process.
  static Future<ShaderGhostTrailDecorator> load({
    ui.Color color = const ui.Color.fromARGB(255, 114, 0, 255),
    Vector2? direction,
    double strength = 0.2,
    double tintFactor = 0.5,
  }) async {
    final program = await ui.FragmentProgram.fromAsset(
      'packages/flame_visual_fx/lib/src/shaders/ghost_trail.frag',
    );
    return ShaderGhostTrailDecorator(
      shader: program.fragmentShader(),
      color: color,
      direction: direction,
      strength: strength,
      tintFactor: tintFactor,
    );
  }

  @override
  void apply(void Function(ui.Canvas) draw, ui.Canvas canvas) {
    if (_atlasImage == null || _srcRect == null || _atlasSize == null) {
      // Fallback if context is missing (drawing normally)
      draw(canvas);
      return;
    }

    final localSize = _localSize ?? const ui.Size(0, 0);
    // Standard margin used in CompositeAtlasImpl.analyze()
    const double margin = 10.0;

    // 1. Set Uniforms
    // uSize (location 0)
    shader.setFloat(0, localSize.width);
    shader.setFloat(1, localSize.height);

    // uSrcRect (location 1)
    shader.setFloat(2, _srcRect!.left);
    shader.setFloat(3, _srcRect!.top);
    shader.setFloat(4, _srcRect!.width);
    shader.setFloat(5, _srcRect!.height);

    // uAtlasSize (location 2)
    shader.setFloat(6, _atlasSize!.width);
    shader.setFloat(7, _atlasSize!.height);

    // uOffset (location 3)
    shader.setFloat(8, margin);
    shader.setFloat(9, margin);

    // uTime (location 4)
    shader.setFloat(10, _time);

    // uDirection (location 5)
    shader.setFloat(11, direction.x);
    shader.setFloat(12, direction.y);

    // uStrength (location 6)
    shader.setFloat(13, strength);

    // uTrailColor (location 7 - RGBA)
    shader.setFloat(14, color.r);
    shader.setFloat(15, color.g);
    shader.setFloat(16, color.b);
    shader.setFloat(17, tintFactor);

    // uTexture (location 8 / Sampler 0)
    shader.setImageSampler(0, _atlasImage!);

    final paint = ui.Paint()..shader = shader;

    // During baking, drawRect should match the area occupied by the sprite
    // including the margin. Note: We use a larger draw area to allow the trail
    // to extend beyond the original sprite bounds!
    final drawRect = ui.Rect.fromLTWH(
      0,
      0,
      _srcRect!.width + margin * 2,
      _srcRect!.height + margin * 2,
    );
    // 1. Draw the ghost trail images
    canvas.drawRect(drawRect, paint);

    // 2. Draw the original sprite (or the next decorator in the GroupDecorator list)
    if (includeBase) {
      draw(canvas);
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ShaderGhostTrailDecorator &&
          runtimeType == other.runtimeType &&
          color == other.color &&
          direction == other.direction &&
          strength == other.strength &&
          tintFactor == other.tintFactor;

  @override
  int get hashCode =>
      color.hashCode ^
      direction.hashCode ^
      strength.hashCode ^
      tintFactor.hashCode;
}

import 'dart:ui' as ui;
import 'package:flame/rendering.dart';
import 'package:composite_atlas/composite_atlas.dart';

/// A decorator that applies a holographic shader effect.
/// Designed for use with [CompositeAtlas] baking to pre-render shader effects
/// into static textures, saving runtime GPU costs.
class ShaderHologramDecorator extends Decorator implements AtlasDecorator {
  final ui.FragmentShader shader;
  double time;

  // Atlas context data from CompositeAtlas
  ui.Image? _atlasImage;
  ui.Rect? _srcRect;
  ui.Size? _atlasSize;
  ui.Size? _localSize;

  ShaderHologramDecorator({required this.shader, this.time = 0.0});

  @override
  void updateAtlasContext(AtlasContext context) {
    _atlasImage = context.atlasImage;
    _srcRect = context.srcRect;
    _atlasSize = context.atlasSize;
    _localSize = context.localSize;
  }

  /// Loader method to handle shader loading from the visual_fx package.
  /// This should be called before start of the baking process.
  static Future<ShaderHologramDecorator> load({double time = 0.0}) async {
    final program = await ui.FragmentProgram.fromAsset(
      'packages/flame_visual_fx/lib/src/shaders/hologram.frag',
    );
    return ShaderHologramDecorator(
      shader: program.fragmentShader(),
      time: time,
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
    shader.setFloat(10, time);

    // uTexture (location 5 / Sampler 0)
    shader.setImageSampler(0, _atlasImage!);

    final paint = ui.Paint()..shader = shader;

    // During baking, drawRect should match the area occupied by the sprite
    // including the margin.
    final drawRect = ui.Rect.fromLTWH(
      margin,
      margin,
      _srcRect!.width,
      _srcRect!.height,
    );

    canvas.drawRect(drawRect, paint);
  }
}

import 'dart:ui' as ui;
import 'package:flutter/painting.dart';
import 'package:flame/rendering.dart';
import 'package:composite_atlas/composite_atlas.dart';

/// A decorator that applies a glitch shader effect (RGB split, jitter).
/// Designed for use with [CompositeAtlas] baking to pre-render glitch effects
/// into static textures, saving runtime GPU costs.
class GlitchDecorator extends Decorator implements AtlasDecorator, BakePadding {
  final ui.FragmentShader shader;
  double time;
  final double margin;

  // Atlas context data from CompositeAtlas
  ui.Image? _atlasImage;
  ui.Rect? _srcRect;
  ui.Size? _atlasSize;
  ui.Size? _localSize;
  EdgeInsets? _currentPadding;

  GlitchDecorator({
    required this.shader,
    this.time = 0.0,
    this.margin = 10.0,
  });

  @override
  EdgeInsets get padding => EdgeInsets.all(margin);

  @override
  void updateAtlasContext(AtlasContext context) {
    _atlasImage = context.atlasImage;
    _srcRect = context.srcRect;
    _atlasSize = context.atlasSize;
    _localSize = context.localSize;
    _currentPadding = context.padding;

    // Use normalized time (0.0 to 1.0) based on frame index to ensure perfect looping
    final index = context.itemIndex ?? 0;
    final count = context.itemCount ?? 1;
    time = count > 0 ? index / count : 0.0;
  }

  /// Loader method to handle shader loading from the visual_fx package.
  /// This should be called before start of the baking process.
  static Future<GlitchDecorator> load({
    double time = 0.0,
    double margin = 10.0,
  }) async {
    final program = await ui.FragmentProgram.fromAsset(
      'packages/flame_visual_fx/lib/src/shaders/glitch.frag',
    );
    return GlitchDecorator(
      shader: program.fragmentShader(),
      time: time,
      margin: margin,
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
    final p = _currentPadding ?? EdgeInsets.all(margin);

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
    shader.setFloat(8, p.left);
    shader.setFloat(9, p.top);

    // uTime (location 4)
    shader.setFloat(10, time);

    // uTexture (location 5 / Sampler 0)
    shader.setImageSampler(0, _atlasImage!);

    final paint = ui.Paint()..shader = shader;

    // During baking, drawRect should match the area occupied by the sprite
    // including the padding.
    final drawRect = ui.Rect.fromLTWH(
      0,
      0,
      _srcRect!.width + p.horizontal,
      _srcRect!.height + p.vertical,
    );

    canvas.drawRect(drawRect, paint);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GlitchDecorator && runtimeType == other.runtimeType;

  @override
  int get hashCode => runtimeType.hashCode;
}

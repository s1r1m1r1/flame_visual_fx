import 'dart:ui' as ui;
import 'package:flame/rendering.dart';
import 'package:composite_atlas/composite_atlas.dart';

/// A decorator that applies an outline shader effect.
/// Highly optimized for [CompositeAtlas] baking.
/// Can optionally sync its displacement with [GlitchDecorator].
class ShaderOutlineDecorator extends Decorator implements AtlasDecorator {
  final ui.FragmentShader shader;

  /// The outline color.
  ui.Color color;

  /// The thickness of the outline in pixels.
  double thickness;

  /// If true, the outline will jitter and jump in sync with [GlitchDecorator].
  bool useGlitch;

  /// Transient time state used for looping animations during baking.
  double _time = 0.0;

  // Atlas context data from CompositeAtlas
  ui.Image? _atlasImage;
  ui.Rect? _srcRect;
  ui.Size? _atlasSize;
  ui.Size? _localSize;

  ShaderOutlineDecorator({
    required this.shader,
    this.color = const ui.Color.fromARGB(255, 253, 6, 138),
    this.thickness = 1.0,
    this.useGlitch = false,
    this.includeBase = true,
  });

  /// If true, the base sprite will be drawn after the outline.
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
  static Future<ShaderOutlineDecorator> load({
    ui.Color color = const ui.Color.fromARGB(255, 253, 6, 138),
    double thickness = 1.0,
    bool useGlitch = false,
  }) async {
    final program = await ui.FragmentProgram.fromAsset(
      'packages/flame_visual_fx/lib/src/shaders/outline.frag',
    );
    return ShaderOutlineDecorator(
      shader: program.fragmentShader(),
      color: color,
      thickness: thickness,
      useGlitch: useGlitch,
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

    // uThickness (location 5)
    shader.setFloat(11, thickness);

    // uOutlineColor (location 6 - RGBA)
    shader.setFloat(12, color.r);
    shader.setFloat(13, color.g);
    shader.setFloat(14, color.b);
    shader.setFloat(15, color.a);

    // uUseGlitch (location 7)
    shader.setFloat(16, useGlitch ? 1.0 : 0.0);

    // uTexture (location 8 / Sampler 0)
    shader.setImageSampler(0, _atlasImage!);

    final paint = ui.Paint()..shader = shader;

    // Draw the outline using the shader
    final drawRect = ui.Rect.fromLTWH(
      0,
      0,
      _srcRect!.width + margin * 2,
      _srcRect!.height + margin * 2,
    );
    canvas.drawRect(drawRect, paint);

    // 2. Draw the original sprite (or the next effect)
    if (includeBase) {
      draw(canvas);
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ShaderOutlineDecorator &&
          runtimeType == other.runtimeType &&
          color == other.color &&
          thickness == other.thickness &&
          useGlitch == other.useGlitch;

  @override
  int get hashCode => color.hashCode ^ thickness.hashCode ^ useGlitch.hashCode;
}

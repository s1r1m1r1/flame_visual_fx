import 'dart:ui' as ui;
import 'package:flame/components.dart';
import 'package:flame/rendering.dart';
import 'package:composite_atlas/composite_atlas.dart';
import 'vfx_decorator.dart';
import 'dissolve_mask.dart';

/// A [Decorator] focused on baking high-quality dissolve animations.
/// It implements [AtlasDecorator] for CompositeAtlas and inherits from
/// [VFXDecorator] for runtime compatibility (e.g. in TinyUnit).
class DissolveDecorator extends VFXDecorator implements AtlasDecorator {
  final ui.FragmentShader? shader;

  /// Quantization scale for pixel art.
  double pixelSize;

  /// Type of geometric dissolve (Random, TopDown, etc.)
  DissolveType type;

  /// Weight of the procedural noise vs geometry.
  double noiseWeight;

  /// The glowing "burn" color at the edge.
  ui.Color edgeColor;

  /// Thickness of the burn edge.
  double edgeDepth;

  // --- COMPATIBILITY PROPERTIES (Required by legacy code) ---
  PositionComponent? component;
  DissolveMask? mask;

  Vector2 visualOffset = Vector2.zero();
  Vector2 visualScale = Vector2.all(1.0);
  Vector2 visualAnchor = Vector2.zero();
  Vector2? renderSize;
  bool showResidualEffect = false;
  // -------------------------------------------------------------

  ui.Rect? _srcRect;
  ui.Image? _atlasImage;
  ui.Size? _atlasSize;

  DissolveDecorator({
    this.shader,
    super.controller,
    super.onComplete,
    double progress = 0.0,
    this.pixelSize = 1.0,
    this.type = DissolveType.bottomUp,
    this.noiseWeight = 0.8,
    this.edgeColor = const ui.Color(0x00000000),
    this.edgeDepth = 0.0,
    // Stubs
    this.component,
    this.mask,
    this.renderSize,
  }) : super(initialProgress: progress);

  /// Static utility to generate a sequence for baking from a single sprite.
  static Future<List<SpriteBakeRequest>> generateBakeSequence(
    Sprite sprite, {
    int frames = 12,
    String name = 'dissolve',
    DissolveType type = DissolveType.bottomUp,
    double noiseWeight = 0.8,
    double pixelSize = 1.0,
    ui.Color edgeColor = const ui.Color(0x00000000),
    double edgeDepth = 0.0,
  }) async {
    final program = await ui.FragmentProgram.fromAsset(
      'packages/flame_visual_fx/lib/src/shaders/pixel_dissolve.frag',
    );

    return List.generate(frames, (i) {
      final p = i / (frames - 1);
      return SpriteBakeRequest(
        sprite,
        name: '${name}_$i',
        decorator: DissolveDecorator(
          shader: program.fragmentShader(),
          progress: p,
          type: type,
          noiseWeight: noiseWeight,
          pixelSize: pixelSize,
          edgeColor: edgeColor,
          edgeDepth: edgeDepth,
        ),
      );
    });
  }

  @override
  void updateAtlasContext(AtlasContext context) {
    _srcRect = context.srcRect;
    _atlasImage = context.atlasImage;
    _atlasSize = context.atlasSize;
  }

  @override
  void apply(void Function(ui.Canvas) draw, ui.Canvas canvas) {
    if (shader == null || progress >= 1.0) {
      return; // Fully dissolved or no shader
    }

    if (progress <= 0.0) {
      draw(canvas);
      return;
    }

    // Determine bounds for the layer.
    // If baking, use the full srcRect size to capture the whole texture area.
    // If runtime, use the component dimensions.
    final ui.Rect bounds;
    if (_srcRect != null) {
      bounds = ui.Rect.fromLTWH(0, 0, _srcRect!.width, _srcRect!.height);
    } else {
      bounds = renderSize != null
          ? ui.Rect.fromLTWH(0, 0, renderSize!.x, renderSize!.y)
          : ui.Rect.fromLTWH(0, 0, 100, 100); // Fail-safe
    }

    // Unified approach using DstIn blend mode.
    // This is 100% position-accurate because draw(canvas) correctly handles
    // the sprite placement (including the 10px margin during atlas baking),
    // and the shader then masks it in-place.

    // 1. Setup Shader
    shader!.setFloat(0, bounds.width); // uSize.x
    shader!.setFloat(1, bounds.height); // uSize.y
    shader!.setFloat(2, progress); // uProgress
    shader!.setFloat(3, type.index.toDouble()); // uType
    shader!.setFloat(4, noiseWeight); // uNoiseWeight
    shader!.setFloat(5, pixelSize); // uPixelSize
    shader!.setFloat(6, edgeColor.r);
    shader!.setFloat(7, edgeColor.g);
    shader!.setFloat(8, edgeColor.b);
    shader!.setFloat(9, edgeColor.a);
    shader!.setFloat(10, edgeDepth);

    if (_atlasImage != null && _srcRect != null && _atlasSize != null) {
      // ATLAS BAKE MODE: Direct Sampling
      // Thanks to the 'CompositeAtlas' translation fix, we can now safely
      // use the 'bounds' at (0, 0) and the shader will align perfectly.
      shader!.setImageSampler(0, _atlasImage!);
      shader!.setFloat(11, _srcRect!.left);
      shader!.setFloat(12, _srcRect!.top);
      shader!.setFloat(13, _srcRect!.width);
      shader!.setFloat(14, _srcRect!.height);
      shader!.setFloat(15, _atlasSize!.width);
      shader!.setFloat(16, _atlasSize!.height);

      final paint = ui.Paint()..shader = shader;
      canvas.drawRect(bounds, paint);
    } else {
      // RUNTIME MODE: Masking Fallback
      canvas.saveLayer(null, ui.Paint());
      draw(canvas);

      final paint = ui.Paint()
        ..blendMode = ui.BlendMode.dstIn
        ..shader = shader;
      canvas.drawRect(bounds, paint);
      canvas.restore();
    }
  }
}

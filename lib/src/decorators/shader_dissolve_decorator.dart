import 'dart:ui' as ui;
import 'package:flame/components.dart';
import 'package:flame/rendering.dart';

/// A [Decorator] that applies a dissolve shader effect to a component.
/// It uses a [ui.FragmentShader] to organicallly erase the component's pixels.
class ShaderDissolveDecorator extends Decorator {
  final ui.FragmentShader shader;
  final PositionComponent component;
  double threshold;
  Vector2 uOffset = Vector2.zero();
  Vector2 uSize = Vector2.zero();

  ShaderDissolveDecorator({
    required this.shader,
    required this.component,
    this.threshold = 0.0,
  });

  @override
  void apply(void Function(ui.Canvas) draw, ui.Canvas canvas) {
    if (threshold <= 0.0) {
      draw(canvas);
      return;
    }

    if (threshold >= 1.0) {
      return;
    }

    shader.setFloat(0, uSize.x);
    shader.setFloat(1, uSize.y);
    shader.setFloat(2, uOffset.x);
    shader.setFloat(3, uOffset.y);
    shader.setFloat(4, threshold);

    final paint = ui.Paint()
      ..shader = shader
      ..blendMode = ui.BlendMode.dstOut;

    // 1. Create isolated layer - Use null rect to avoid clipping issues
    // when the component's transform is applied inside.
    canvas.saveLayer(null, ui.Paint());

    // 2. Draw the component (rock)
    draw(canvas);

    // 3. Apply the mask shader to erase pixels
    // We draw a large enough rect to cover any possible component bounds.
    // Since we're in a saveLayer, it will only affect the current layer contents.
    canvas.drawRect(ui.Offset.zero & (uSize * 2.0).toSize(), paint);

    // 4. Composite back
    canvas.restore();
  }
}

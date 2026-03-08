import 'dart:ui';
import 'package:flame/components.dart';
import 'package:flame/rendering.dart';

/// A [Decorator] that applies an outline to the component using native saveLayer tinting.
/// This sidesteps all WebGL and Transform Matrix rounding errors, natively tracking camera
/// limits and asset bounds securely.
class OutlineDecorator extends Decorator {
  OutlineDecorator({
    required this.component,
    this.color = const Color.fromARGB(255, 253, 6, 138),
    this.thickness = 2.0,
    this.margin = 0.0,
    this.isActive = true,
  });

  final PositionComponent component;
  Color color;
  double thickness;
  double margin;
  bool isActive;

  @override
  void apply(void Function(Canvas) draw, Canvas canvas) {
    if (!isActive) {
      draw(canvas);
      return;
    }

    final size = component.size;
    if (size.x <= 0 || size.y <= 0) {
      draw(canvas);
      return;
    }

    // 2. Setup the tinting color filter
    // BlendMode.srcIn keeps the alpha of the drawn layer, but replaces all RGB with `color`.
    final outlinePaint = Paint()
      ..colorFilter = ColorFilter.mode(color, BlendMode.srcIn);

    // Start isolated pass
    canvas.saveLayer(null, outlinePaint);

    // 8-way offset positions for a perfectly solid outline
    final offsets = [
      Offset(-thickness, 0),
      Offset(thickness, 0),
      Offset(0, -thickness),
      Offset(0, thickness),
      Offset(-thickness, -thickness),
      Offset(thickness, -thickness),
      Offset(-thickness, thickness),
      Offset(thickness, thickness),
    ];

    // Draw the component repeatedly at each offset
    for (final offset in offsets) {
      canvas.save();
      canvas.translate(offset.dx, offset.dy);
      draw(canvas);
      canvas.restore();
    }

    // Resolve isolated pass (this executes the srcIn tint onto the main canvas)
    canvas.restore();

    // 3. Draw the actual unit right inside the newly created outline!
    draw(canvas);
  }
}

import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flame/components.dart';
import 'package:flame/rendering.dart';

/// A [Decorator] that applies an outline to the component using native saveLayer tinting.
/// Designed for animation via thickness property.
class PulseOutlineDecorator extends Decorator {
  PulseOutlineDecorator({
    required this.component,
    this.color = const ui.Color.fromARGB(255, 253, 6, 138),
    this.thickness = 2.0,
    this.isActive = true,
  });

  final PositionComponent component;
  ui.Color color;
  double thickness;
  bool isActive;

  @override
  void apply(void Function(ui.Canvas) draw, ui.Canvas canvas) {
    if (!isActive) {
      draw(canvas);
      return;
    }

    final size = this.component.size;
    if (size.x <= 0 || size.y <= 0) {
      draw(canvas);
      return;
    }

    // 2. Setup the tinting color filter
    final outlinePaint = ui.Paint()
      ..colorFilter = ui.ColorFilter.mode(color, ui.BlendMode.srcIn);

    // Start isolated pass
    canvas.saveLayer(null, outlinePaint);

    final int steps = math.max(8, (thickness * math.pi).ceil());
    final double stepAngle = (2 * math.pi) / steps;

    // Draw the component repeatedly in a perfect circle contour
    for (int i = 0; i < steps; i++) {
      final angle = i * stepAngle;
      final offset = ui.Offset(
        math.cos(angle) * thickness,
        math.sin(angle) * thickness,
      );

      canvas.save();
      canvas.translate(offset.dx, offset.dy);
      draw(canvas);
      canvas.restore();
    }

    // Resolve isolated pass
    canvas.restore();

    // 3. Draw the actual unit right inside the newly created outline!
    draw(canvas);
  }
}

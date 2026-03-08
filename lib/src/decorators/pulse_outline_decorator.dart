import 'dart:math' as math;
import 'dart:ui';
import 'package:flame/components.dart';
import 'package:flame/rendering.dart';

/// A [Decorator] that applies a pulsating outline to the component using native saveLayer tinting.
class PulseOutlineDecorator extends Decorator {
  PulseOutlineDecorator({
    required this.component,
    this.color = const Color.fromARGB(255, 253, 6, 138),
    this.thickness = 2.0,
    this.isActive = true,
  });

  final PositionComponent component;
  Color color;
  double thickness;
  bool isActive;

  void update(double dt) {
    super.update(dt);
  }

  @override
  void apply(void Function(Canvas) draw, Canvas canvas) {
    if (!isActive) {
      draw(canvas);
      return;
    }

    // Use the static thickness
    final currentThickness = thickness;

    final size = component.size;
    if (size.x <= 0 || size.y <= 0) {
      draw(canvas);
      return;
    }

    // 2. Setup the tinting color filter
    final outlinePaint = Paint()
      ..colorFilter = ColorFilter.mode(color, BlendMode.srcIn);

    // Start isolated pass
    canvas.saveLayer(null, outlinePaint);

    final int steps = math.max(8, (currentThickness * math.pi).ceil());
    final double stepAngle = (2 * math.pi) / steps;

    // Draw the component repeatedly in a perfect circle contour
    for (int i = 0; i < steps; i++) {
      final angle = i * stepAngle;
      final offset = Offset(
        math.cos(angle) * currentThickness,
        math.sin(angle) * currentThickness,
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

import 'dart:math' as math;
import 'dart:ui';
import 'package:flame/components.dart';
import 'package:flame/rendering.dart';

/// A [Decorator] that applies a pulsating outline to the component using native saveLayer tinting.
class PulseOutlineDecorator extends Decorator {
  PulseOutlineDecorator({
    required this.component,
    this.color = const Color.fromARGB(255, 253, 6, 138),
    this.baseThickness = 2.0,
    this.pulseAmplitude = 1.0,
    this.pulseSpeed = 5.0,
    this.margin = 0.0,
    this.isActive = true,
  });

  final PositionComponent component;
  Color color;
  double baseThickness;
  double pulseAmplitude;
  double pulseSpeed;
  double margin;
  bool isActive;

  double _time = 0.0;

  void update(double dt) {
    if (!isActive) return;
    _time += dt;
  }

  @override
  void apply(void Function(Canvas) draw, Canvas canvas) {
    if (!isActive) {
      draw(canvas);
      return;
    }

    // Calculate current pulsating thickness
    final currentThickness =
        baseThickness + math.sin(_time * pulseSpeed) * pulseAmplitude;

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

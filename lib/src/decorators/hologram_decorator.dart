import 'dart:ui';
import 'package:flame/components.dart';
import 'package:flame/rendering.dart';

/// A [Decorator] that applies a "Hologram" (Chromatic Aberration / Glitch) effect.
/// It splits the character into Cyan and Magenta channels, shifts them horizontally
/// based on time, and introduces random vertical jitter to simulate a faulty hologram.
class HologramDecorator extends Decorator {
  HologramDecorator({
    required this.component,
    this.intensity = 3.0,
    this.splitOffset = 0.0,
    this.jitterY = 0.0,
    this.isActive = true,
  });

  final PositionComponent component;
  double intensity;
  double splitOffset;
  double jitterY;
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

    final size = component.size;
    if (size.x <= 0 || size.y <= 0) {
      draw(canvas);
      return;
    }

    // Use static offsets
    final splitX = splitOffset;

    // 1. Draw CYAN channel shifted left
    final cyanPaint = Paint()
      ..colorFilter = const ColorFilter.mode(
        Color.fromARGB(200, 0, 255, 255),
        BlendMode.srcIn,
      );

    canvas.save();
    canvas.translate(-splitX, jitterY);
    canvas.saveLayer(null, cyanPaint);
    draw(canvas);
    canvas.restore(); // resolve saveLayer
    canvas.restore(); // resolve translation

    // 2. Draw MAGENTA channel shifted right
    final magentaPaint = Paint()
      ..colorFilter = const ColorFilter.mode(
        Color.fromARGB(200, 255, 0, 255),
        BlendMode.srcIn,
      );

    canvas.save();
    canvas.translate(splitX, -jitterY * 0.5); // counter jitter
    canvas.saveLayer(null, magentaPaint);
    draw(canvas);
    canvas.restore();
    canvas.restore();

    // 3. Draw the original component natively with semi-transparency in the middle
    // Using saveLayer here just to apply opacity to the whole component cleanly
    final basePaint = Paint()
      ..color = const Color.fromARGB(180, 255, 255, 255); // 70% opacity
    canvas.saveLayer(null, basePaint);
    draw(canvas);
    canvas.restore();
  }
}

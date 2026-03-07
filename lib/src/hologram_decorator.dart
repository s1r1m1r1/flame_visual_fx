import 'dart:math' as math;
import 'dart:ui';
import 'package:flame/components.dart';
import 'package:flame/rendering.dart';

/// A [Decorator] that applies a "Hologram" (Chromatic Aberration / Glitch) effect.
/// It splits the character into Cyan and Magenta channels, shifts them horizontally
/// based on time, and introduces random vertical jitter to simulate a faulty hologram.
class HologramDecorator extends Decorator {
  HologramDecorator({
    required this.component,
    this.glitchIntensity = 3.0,
    this.jitterFrequency =
        0.2, // Probability of a vertical glitch jump each frame
    this.isActive = true,
  });

  final PositionComponent component;
  double glitchIntensity;
  double jitterFrequency;
  bool isActive;

  double _time = 0.0;
  final math.Random _random = math.Random();
  double _currentJitterY = 0.0;

  void update(double dt) {
    if (!isActive) return;
    _time += dt;

    // Random vertical glitching (static jitter)
    if (_random.nextDouble() < jitterFrequency) {
      _currentJitterY = (_random.nextDouble() * 4.0) - 2.0; // -2 to +2 pixels
    } else {
      _currentJitterY = 0.0;
    }
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

    final bounds = Rect.fromLTWH(
      -glitchIntensity * 2,
      -glitchIntensity * 2,
      size.x + glitchIntensity * 4,
      size.y + glitchIntensity * 4,
    );

    // Calculate shifting x-offset based on time. We use a fast jagged sine wave to make it look "digital"
    final splitX =
        math.sin(_time * 15.0) * glitchIntensity +
        math.cos(_time * 25.0) * (glitchIntensity * 0.5);

    // 1. Draw CYAN channel shifted left
    final cyanPaint = Paint()
      ..colorFilter = const ColorFilter.mode(
        Color.fromARGB(200, 0, 255, 255),
        BlendMode.srcIn,
      );

    canvas.save();
    canvas.translate(-splitX, _currentJitterY);
    canvas.saveLayer(bounds, cyanPaint);
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
    canvas.translate(splitX, -_currentJitterY * 0.5); // counter jitter
    canvas.saveLayer(bounds, magentaPaint);
    draw(canvas);
    canvas.restore();
    canvas.restore();

    // 3. Draw the original component natively with semi-transparency in the middle
    // Using saveLayer here just to apply opacity to the whole component cleanly
    final basePaint = Paint()
      ..color = const Color.fromARGB(180, 255, 255, 255); // 70% opacity
    canvas.saveLayer(bounds, basePaint);
    draw(canvas);
    canvas.restore();
  }
}

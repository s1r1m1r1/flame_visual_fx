import 'dart:math' as math;
import 'dart:ui';
import 'package:flame/components.dart';
import 'package:flame/rendering.dart';

/// A [Decorator] that applies a pulsing "Neon Glow" (Soft Aura) effect behind the component.
/// It uses standard Flutter `MaskFilter.blur` to expand the component's alpha channel
/// into a soft glowing shadow, tinted with a vibrant neon color.
class NeonGlowDecorator extends Decorator {
  NeonGlowDecorator({
    required this.component,
    this.color = const Color.fromARGB(255, 0, 255, 255), // Cyberpunk Cyan
    this.baseGlowRadius = 8.0,
    this.pulseAmplitude = 4.0,
    this.pulseSpeed = 6.0,
    this.isActive = true,
  });

  final PositionComponent component;
  Color color;
  double baseGlowRadius;
  double pulseAmplitude;
  double pulseSpeed;
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

    final size = component.size;
    if (size.x <= 0 || size.y <= 0) {
      draw(canvas);
      return;
    }

    // Calculate dynamic pulsating radius
    final currentRadius =
        baseGlowRadius + math.sin(_time * pulseSpeed) * pulseAmplitude;
    // Prevent negative blur radius which causes rendering crashes
    final safeRadius = math.max(0.1, currentRadius);

    // 1. Setup the neon glow paint
    // We use ImageFilter.blur to soften the rendered pixels, and ColorFilter to make it solid neon!
    final glowPaint = Paint()
      ..colorFilter = ColorFilter.mode(color, BlendMode.srcIn)
      ..imageFilter = ImageFilter.blur(sigmaX: safeRadius, sigmaY: safeRadius);

    // Render the isolated glowing silhouette behind the character
    canvas.saveLayer(null, glowPaint);
    draw(canvas);
    canvas.restore();

    // 2. Draw the actual crisp, un-blurred component smoothly on top!
    draw(canvas);
  }
}

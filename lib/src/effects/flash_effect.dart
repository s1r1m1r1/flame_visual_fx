import 'dart:math' as math;
import 'dart:ui';
import 'package:flame/effects.dart';

/// An effect that flashes the component with a chosen color by modifying
/// the target's paint directly, avoiding the overhead of [saveLayer].
class FastFlashEffect extends Effect with EffectTarget<PaintProvider> {
  FastFlashEffect(
    this.color,
    EffectController controller, {
    super.key,
    super.onComplete,
  }) : super(controller);

  /// The color to flash the component with.
  final Color color;

  @override
  void apply(double progress) {
    // Sin curve for smooth flash in and out
    final alpha = (math.sin(progress * math.pi) * 255).clamp(0, 255).toInt();

    if (alpha <= 0) {
      target.paint.colorFilter = null;
    } else {
      target.paint.colorFilter = ColorFilter.mode(
        color.withValues(alpha: alpha / 255.0),
        BlendMode.srcATop,
      );
    }
  }

  @override
  void reset() {
    super.reset();
    target.paint.colorFilter = null;
  }
}

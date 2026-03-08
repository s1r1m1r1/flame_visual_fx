import 'dart:ui';
import 'package:flame/effects.dart';

/// An effect that applies a [ColorFilter] to a component by modifying
/// its paint directly, avoiding [saveLayer] overhead.
class FastColorFilterEffect extends Effect with EffectTarget<PaintProvider> {
  FastColorFilterEffect(
    this.colorFilter,
    EffectController controller, {
    super.key,
    super.onComplete,
  }) : super(controller);

  /// The color filter to apply.
  final ColorFilter colorFilter;

  @override
  void apply(double progress) {
    // Note: We apply the full filter during the effect.
    // Progress doesn't naturally lerp most filters easily,
    // but we can use it to determine if the filter is active.
    if (progress > 0) {
      target.paint.colorFilter = colorFilter;
    } else {
      target.paint.colorFilter = null;
    }
  }

  @override
  void reset() {
    super.reset();
    target.paint.colorFilter = null;
  }
}

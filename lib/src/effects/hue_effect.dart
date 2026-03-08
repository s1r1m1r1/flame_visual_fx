import 'dart:math' as math;
import 'dart:ui';
import 'package:flame/effects.dart';

/// An effect that shifts the hue of a component by modifying its paint's
/// color filter directly, avoiding [saveLayer] overhead.
class FastHueEffect extends Effect with EffectTarget<PaintProvider> {
  FastHueEffect(
    this.hue,
    EffectController controller, {
    super.key,
    super.onComplete,
  }) : super(controller);

  /// The target hue shift in radians.
  final double hue;

  @override
  void apply(double progress) {
    final currentHue = hue * progress;
    _applyHue(currentHue);
  }

  void _applyHue(double h) {
    if (h == 0.0) {
      target.paint.colorFilter = null;
      return;
    }

    final cosT = math.cos(h);
    final sinT = math.sin(h);

    final matrix = <double>[
      0.213 + 0.787 * cosT - 0.213 * sinT,
      0.715 - 0.715 * cosT - 0.715 * sinT,
      0.072 - 0.072 * cosT + 0.928 * sinT,
      0,
      0,
      0.213 - 0.213 * cosT + 0.143 * sinT,
      0.715 + 0.285 * cosT + 0.140 * sinT,
      0.072 - 0.072 * cosT - 0.283 * sinT,
      0,
      0,
      0.213 - 0.213 * cosT - 0.787 * sinT,
      0.715 - 0.715 * cosT + 0.715 * sinT,
      0.072 + 0.928 * cosT + 0.072 * sinT,
      0,
      0,
      0,
      0,
      0,
      1,
      0,
    ];

    target.paint.colorFilter = ColorFilter.matrix(matrix);
  }

  @override
  void reset() {
    super.reset();
    target.paint.colorFilter = null;
  }
}

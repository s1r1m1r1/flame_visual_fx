import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flame/rendering.dart';

/// A [Decorator] that shifts the hue of the component.
/// The [hue] value is in radians.
@Deprecated('Use HueEffect from Flame instead. Will be removed in version 2.0')
class HueDecorator extends Decorator {
  HueDecorator({
    required this.component,
    this.hue = 0.0,
    this.isActive = true,
  });

  /// The component to which this decorator is applied.
  final PositionComponent component;

  /// The hue shift in radians.
  /// Standard range is from -pi to pi, or 0 to 2*pi.
  double hue;

  bool isActive;

  void update(double dt) {
    super.update(dt);
  }

  @override
  void apply(void Function(ui.Canvas) draw, ui.Canvas canvas) {
    if (!isActive || hue == 0.0) {
      draw(canvas);
      return;
    }

    final cosT = math.cos(hue);
    final sinT = math.sin(hue);

    // Standard hue rotation matrix using NTSC luminance weights:
    // R: 0.213, G: 0.715, B: 0.072
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

    // Use null bounds to avoid clipping, as hue shift doesn't change geometry
    canvas.saveLayer(
      null,
      ui.Paint()..colorFilter = ui.ColorFilter.matrix(matrix),
    );

    draw(canvas);

    canvas.restore();
  }
}

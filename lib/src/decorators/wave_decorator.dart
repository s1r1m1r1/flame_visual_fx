import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/rendering.dart';
import 'package:meta/meta.dart';

/// The axis along which the wave displacement is applied.
enum WaveAxis {
  horizontal,
  vertical,
}

/// A [Decorator] that applies a sine-wave displacement to the component,
/// creating a "ripple" or "wave" effect.
///
/// This is achieved by slicing the component into thin strips and drawing
/// each strip with a calculated offset.
@experimental
class WaveDecorator extends Decorator {
  WaveDecorator({
    required this.component,
    this.amplitude = 5.0,
    this.frequency = 0.1,
    this.phase = 0.0,
    this.stripSize = 2.0,
    this.axis = WaveAxis.horizontal,
    this.isActive = true,
  });

  /// The component to which this decorator is applied.
  final PositionComponent component;

  /// The maximum displacement of the wave in pixels.
  double amplitude;

  /// The frequency of the wave (how many cycles across the component).
  double frequency;

  /// The phase of the wave in radians.
  double phase;

  /// The thickness of each slice in pixels. Smaller values are smoother but
  /// more expensive to render.
  double stripSize;

  /// The axis along which the displacement occurs.
  WaveAxis axis;

  /// Whether the effect is currently active.
  bool isActive;

  void update(double dt) {
    super.update(dt);
  }

  @override
  void apply(void Function(Canvas) draw, Canvas canvas) {
    if (!isActive || amplitude == 0) {
      draw(canvas);
      return;
    }

    final size = component.size;
    if (size.x <= 0 || size.y <= 0) {
      draw(canvas);
      return;
    }

    // Determine the number of strips based on the axis.
    // If axis is horizontal, we displacement X based on Y coordinate (vertical strips).
    // Wait, usually "wave" means if it's a vertical flag, it waves horizontally.
    // So if axis is horizontal, we move X. The wave phase depends on Y.
    // If axis is vertical, we move Y. The wave phase depends on X.

    final isHorizontal = axis == WaveAxis.horizontal;
    final totalDimension = isHorizontal ? size.y : size.x;
    final numStrips = (totalDimension / stripSize).ceil();

    for (var i = 0; i < numStrips; i++) {
      final start = i * stripSize;
      final end = math.min(start + stripSize, totalDimension);
      final mid = (start + end) / 2;

      // Calculate displacement for this strip
      final displacement = math.sin(phase + mid * frequency) * amplitude;

      canvas.save();

      // Clip to the current strip
      if (isHorizontal) {
        canvas.clipRect(Rect.fromLTRB(0, start, size.x, end));
        canvas.translate(displacement, 0);
      } else {
        canvas.clipRect(Rect.fromLTRB(start, 0, end, size.y));
        canvas.translate(0, displacement);
      }

      draw(canvas);
      canvas.restore();
    }
  }
}

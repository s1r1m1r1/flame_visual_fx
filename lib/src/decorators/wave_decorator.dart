import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flame/rendering.dart';
import 'package:meta/meta.dart';
import 'vfx_decorator.dart';

/// The axis along which the wave displacement is applied.
enum WaveAxis { horizontal, vertical }

/// A [Decorator] that applies a sine-wave displacement to the component,
/// creating a "ripple" or "wave" effect.
///
/// This is achieved by slicing the component into thin strips and drawing
/// each strip with a calculated offset.
@experimental
class WaveDecorator extends VFXDecorator {
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

  @override
  void apply(void Function(ui.Canvas) draw, ui.Canvas canvas) {
    if (!isActive || amplitude == 0) {
      draw(canvas);
      return;
    }

    final size = this.component.size;
    if (size.x <= 0 || size.y <= 0) {
      draw(canvas);
      return;
    }

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
        canvas.clipRect(ui.Rect.fromLTRB(0, start, size.x, end));
        canvas.translate(displacement, 0);
      } else {
        canvas.clipRect(ui.Rect.fromLTRB(start, 0, end, size.y));
        canvas.translate(0, displacement);
      }

      draw(canvas);
      canvas.restore();
    }
  }
}

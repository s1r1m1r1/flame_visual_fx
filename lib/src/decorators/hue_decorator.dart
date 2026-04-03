import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flame/rendering.dart';
import 'vfx_decorator.dart';

/// A [Decorator] that shifts the hue of the component.
/// The [hue] value is in radians.
@Deprecated('Use HueEffect from Flame instead. Will be removed in version 2.0')
class HueDecorator extends VFXDecorator {
  HueDecorator({
    required this.component,
    this.hue = 0.0,
    this.isActive = true,
    this.useSaveLayer = true,
  });

  /// The component to which this decorator is applied.
  final PositionComponent component;

  /// The hue shift in radians.
  /// Standard range is from -pi to pi, or 0 to 2*pi.
  double hue;

  bool isActive;

  /// Whether to use `canvas.saveLayer` to apply the hue shift.
  ///
  /// If set to `false`, the decorator will attempt to modify the `colorFilter`
  /// of the component's `Paint` directly. This is significantly faster but
  /// only works correctly for components that use a single paint to draw
  /// their content (like `SpriteComponent`).
  final bool useSaveLayer;

  @override
  void update(double dt) {
    super.update(dt);
  }

  @override
  void apply(
    void Function(ui.Canvas) draw,
    ui.Canvas canvas, [
    Component? component,
  ]) {
    if (!isActive || hue == 0.0) {
      draw(canvas);
      return;
    }

    final cosT = math.cos(hue);
    final sinT = math.sin(hue);

    // Standard hue rotation matrix using NTSC luminance weights:
    // R: 0.213, G: 0.715, B: 0.072
    final matrix = ui.ColorFilter.matrix(<double>[
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
    ]);

    final comp = component ?? this.component;
    if (!useSaveLayer && comp is HasPaint) {
      final oldFilter = comp.paint.colorFilter;
      comp.paint.colorFilter = matrix;
      draw(canvas);
      comp.paint.colorFilter = oldFilter;
    } else {
      // Use null bounds to avoid clipping, as hue shift doesn't change geometry
      canvas.saveLayer(null, ui.Paint()..colorFilter = matrix);

      draw(canvas);

      canvas.restore();
    }
  }
}

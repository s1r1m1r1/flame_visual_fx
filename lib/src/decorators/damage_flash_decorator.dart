import "package:flame/components.dart";
import 'dart:math' as math;

import 'package:flame/rendering.dart';
import 'package:flutter/material.dart';

/// A [Decorator] that flashes the component with a chosen color.
class DamageFlashDecorator extends Decorator {
  DamageFlashDecorator({
    this.color = const Color.fromARGB(255, 255, 0, 0),
    this.duration = 1.0, // seconds
    this.isActive = false,
    this.useSaveLayer = true,
  });

  Color color;
  double duration;
  bool isActive;

  /// Whether to use `canvas.saveLayer` to apply the flash effect.
  ///
  /// If set to `false`, the decorator will attempt to modify the `colorFilter`
  /// of the component's `Paint` directly. This is significantly faster but
  /// only works correctly for components that use a single paint to draw
  /// their content (like `SpriteComponent`).
  final bool useSaveLayer;

  double _timer = 0.0;
  bool _flashing = false;

  void flash() {
    isActive = true;
    _flashing = true;
    _timer = 0.0;
  }

  void update(double dt) {
    if (!_flashing) return;

    _timer += dt;
    if (_timer >= duration) {
      _flashing = false;
      isActive = false;
    }
  }

  @override
  void apply(void Function(Canvas) draw, Canvas canvas,
      [Component? component]) {
    if (!isActive || !_flashing) {
      draw(canvas);
      return;
    }

    // Ping-pong alpha between 0 and 1 over the duration
    final progress = _timer / duration;
    // Sin curve for smooth flash in and out
    final alpha = (math.sin(progress * math.pi) * 255).clamp(0, 255).toInt();

    final filter = ColorFilter.mode(color.withAlpha(alpha), BlendMode.srcATop);

    if (!useSaveLayer && component is HasPaint) {
      final oldFilter = component.paint.colorFilter;
      component.paint.colorFilter = filter;
      draw(canvas);
      component.paint.colorFilter = oldFilter;
    } else {
      canvas.saveLayer(
        null, // apply to all bounds drawn
        Paint()..colorFilter = filter,
      );

      draw(canvas);

      canvas.restore();
    }
  }
}

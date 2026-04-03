import 'dart:math' as math;
import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flame/rendering.dart';
import 'package:flutter/material.dart';
import 'vfx_decorator.dart';

/// A [Decorator] that flashes the component with a chosen color.
class DamageFlashDecorator extends VFXDecorator {
  DamageFlashDecorator({
    this.color = const Color.fromARGB(255, 255, 0, 0),
    double? duration,
    EffectController? controller,
    super.onComplete,
    this.isActive = true,
    this.useSaveLayer = true,
  }) : super(
         controller:
             controller ??
             (duration != null ? LinearEffectController(duration) : null),
       );

  Color color;
  bool isActive;

  /// Whether to use `canvas.saveLayer` to apply the flash effect.
  final bool useSaveLayer;

  /// Convenience method to start a flash animation.
  void flash({double duration = 0.5}) {
    controller = LinearEffectController(duration);
    resetVFX(); // Reset state to ensure it starts from beginning
    isActive = true;
  }

  @override
  void apply(
    void Function(Canvas) draw,
    Canvas canvas, [
    Component? component,
  ]) {
    if (!isActive || progress <= 0 || progress >= 1.0) {
      draw(canvas);
      return;
    }

    // Sin curve for smooth flash in and out
    final alpha = (math.sin(progress * math.pi) * 255).clamp(0, 255).toInt();

    final filter = ColorFilter.mode(color.withAlpha(alpha), BlendMode.srcATop);

    if (!useSaveLayer && component is HasPaint) {
      final oldFilter = component.paint.colorFilter;
      component.paint.colorFilter = filter;
      draw(canvas);
      component.paint.colorFilter = oldFilter;
    } else {
      canvas.saveLayer(null, Paint()..colorFilter = filter);

      draw(canvas);

      canvas.restore();
    }
  }
}

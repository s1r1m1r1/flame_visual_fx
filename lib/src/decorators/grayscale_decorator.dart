import 'dart:ui' as ui;
import 'package:flame/components.dart';
import 'package:flame/rendering.dart';
import 'vfx_decorator.dart';

/// A [Decorator] that converts the colors of the component to grayscale.
class GrayscaleDecorator extends VFXDecorator {
  GrayscaleDecorator({
    this.isActive = true,
    this.useSaveLayer = true,
  });

  bool isActive;

  /// Whether to use `canvas.saveLayer` to apply the grayscale effect.
  final bool useSaveLayer;

  static const _matrix = ui.ColorFilter.matrix(<double>[
    0.2126, 0.7152, 0.0722, 0, 0,
    0.2126, 0.7152, 0.0722, 0, 0,
    0.2126, 0.7152, 0.0722, 0, 0,
    0,      0,      0,      1, 0,
  ]);

  @override
  void apply(
    void Function(ui.Canvas) draw,
    ui.Canvas canvas, [
    Component? component,
  ]) {
    if (!isActive) {
      draw(canvas);
      return;
    }

    if (!useSaveLayer && component is HasPaint) {
      final oldFilter = component.paint.colorFilter;
      component.paint.colorFilter = _matrix;
      draw(canvas);
      component.paint.colorFilter = oldFilter;
    } else {
      canvas.saveLayer(
        null,
        ui.Paint()..colorFilter = _matrix,
      );

      draw(canvas);

      canvas.restore();
    }
  }
}

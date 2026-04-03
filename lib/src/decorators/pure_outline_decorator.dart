import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/painting.dart';
import 'package:flame/rendering.dart';
import 'package:composite_atlas/composite_atlas.dart';
import 'outline_decorator.dart'; // To reuse OutlinePattern

/// A lightweight, component-free decorator that applies an outline to drawing commands.
/// Unlike [OutlineDecorator], this does not require a [PositionComponent] and avoids
/// excessive performance or memory padding, making it ideal for texture atlas baking.
class PureOutlineDecorator extends Decorator implements BakePadding {
  PureOutlineDecorator({
    this.color = const ui.Color.fromARGB(255, 253, 6, 138),
    this.thickness = 1.0,
    this.isActive = true,
    this.pattern = OutlinePattern.fourDirection,
  });

  ui.Color color;
  double thickness;
  bool isActive;
  OutlinePattern pattern;

  @override
  EdgeInsets get padding =>
      isActive ? EdgeInsets.all(thickness) : EdgeInsets.zero;

  @override
  void apply(void Function(ui.Canvas) draw, ui.Canvas canvas) {
    if (!isActive) {
      draw(canvas);
      return;
    }

    final double effectiveThickness = thickness;
    if (effectiveThickness <= 0) {
      draw(canvas);
      return;
    }

    // Capture the content once into a Picture
    final recorder = ui.PictureRecorder();
    final tempCanvas = ui.Canvas(recorder);
    draw(tempCanvas);
    final picture = recorder.endRecording();

    try {
      // Create a silhouette paint
      final outlinePaint = ui.Paint()
        ..colorFilter = ui.ColorFilter.mode(color, ui.BlendMode.srcIn);

      // We use saveLayer to apply the tint to the offsets silhouette
      // Note: In a heavy baking scenario, we could optimize this further, 
      // but for atlas generation, this is perfect as it is bounded by the draw call.
      canvas.saveLayer(null, outlinePaint);

      if (pattern == OutlinePattern.fourDirection) {
        // Diamond pattern
        final List<ui.Offset> offsets = [
          ui.Offset(0, -effectiveThickness),
          ui.Offset(0, effectiveThickness),
          ui.Offset(-effectiveThickness, 0),
          ui.Offset(effectiveThickness, 0),
        ];
        for (final offset in offsets) {
          canvas.save();
          canvas.translate(offset.dx, offset.dy);
          canvas.drawPicture(picture);
          canvas.restore();
        }
      } else {
        // 8-direction or smooth circular pattern
        final int samples = max(8, (effectiveThickness * 2 * pi).ceil());
        for (int i = 0; i < samples; i++) {
          final double angle = (i * 2 * pi) / samples;
          canvas.save();
          canvas.translate(
            cos(angle) * effectiveThickness,
            sin(angle) * effectiveThickness,
          );
          canvas.drawPicture(picture);
          canvas.restore();
        }
      }

      canvas.restore(); // Restore saveLayer (tinting)

      // Finally, draw the original content on top
      canvas.drawPicture(picture);
    } finally {
      picture.dispose();
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PureOutlineDecorator &&
          runtimeType == other.runtimeType &&
          color == other.color &&
          thickness == other.thickness &&
          isActive == other.isActive &&
          pattern == other.pattern;

  @override
  int get hashCode =>
      color.hashCode ^
      thickness.hashCode ^
      isActive.hashCode ^
      pattern.hashCode;
}

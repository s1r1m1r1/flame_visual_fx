import 'dart:ui' as ui;
import 'package:flame/components.dart';
import 'package:flame/rendering.dart';
import 'vfx_decorator.dart';

/// A [Decorator] that applies a "Hologram" (Chromatic Aberration / Glitch) effect.
/// It splits the character into Cyan and Magenta channels, shifts them horizontally,
/// and introduces vertical jitter. Animation is driven by external parameters.
class HologramDecorator extends VFXDecorator {
  HologramDecorator({
    required this.component,
    this.intensity = 3.0,
    this.splitOffset = 0.0,
    this.jitterY = 0.0,
    this.isActive = true,
  });

  final PositionComponent component;
  double intensity;
  double splitOffset;
  double jitterY;
  bool isActive;

  @override
  void apply(void Function(ui.Canvas) draw, ui.Canvas canvas) {
    if (!isActive) {
      draw(canvas);
      return;
    }

    final size = this.component.size;
    if (size.x <= 0 || size.y <= 0) {
      draw(canvas);
      return;
    }

    // 1. Draw CYAN channel shifted left
    final cyanPaint = ui.Paint()
      ..colorFilter = const ui.ColorFilter.mode(
        ui.Color.fromARGB(200, 0, 255, 255),
        ui.BlendMode.srcIn,
      );

    canvas.save();
    canvas.translate(-splitOffset, jitterY);
    canvas.saveLayer(null, cyanPaint);
    draw(canvas);
    canvas.restore(); // resolve saveLayer
    canvas.restore(); // resolve translation

    // 2. Draw MAGENTA channel shifted right
    final magentaPaint = ui.Paint()
      ..colorFilter = const ui.ColorFilter.mode(
        ui.Color.fromARGB(200, 255, 0, 255),
        ui.BlendMode.srcIn,
      );

    canvas.save();
    canvas.translate(splitOffset, -jitterY * 0.5); // counter jitter
    canvas.saveLayer(null, magentaPaint);
    draw(canvas);
    canvas.restore();
    canvas.restore();

    // 3. Draw the original component natively with semi-transparency in the middle
    final basePaint = ui.Paint()
      ..color = const ui.Color.fromARGB(180, 255, 255, 255); // ~70% opacity
    canvas.saveLayer(null, basePaint);
    draw(canvas);
    canvas.restore();
  }
}

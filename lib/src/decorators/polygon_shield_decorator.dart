import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flame/rendering.dart';
import 'package:meta/meta.dart';
import 'vfx_decorator.dart';

/// A [Decorator] that draws a dashed, vibrating "force field" around a polygon silhouette.
@experimental
class PolygonShieldDecorator extends VFXDecorator {
  PolygonShieldDecorator({
    required this.vertices,
    this.color = const ui.Color(0xFF0099FF),
    this.thickness = 2.0,
    this.offset = 10.0,
    this.vibration = 2.0,
    this.dashLength = 10.0,
    this.dashGap = 5.0,
    this.progress = 0.0,
    this.isActive = true,
  });

  /// Current silhouette vertices.
  List<Vector2> vertices;

  /// Shield color.
  ui.Color color;

  /// Thickness of the shield line.
  double thickness;

  /// Base distance from the silhouette.
  double offset;

  /// Maximum vibration amplitude.
  double vibration;

  /// Length of each dash.
  double dashLength;

  /// Gap between dashes.
  double dashGap;

  /// Whether the effect is active.
  bool isActive;

  /// Animation progress (0.0 to 1.0).
  double progress;

  @override
  void apply(
    void Function(ui.Canvas) draw,
    ui.Canvas canvas, [
    Component? component,
  ]) {
    // 1. Draw the component first
    draw(canvas);

    if (!isActive || vertices.isEmpty) return;

    final currentVibration = (math.sin(progress * 20) + 1.0) * 0.5 * vibration;
    final scale = 1.0 + ((offset + currentVibration) * 0.01);

    // Create the silhouette path
    final path = ui.Path();
    for (int i = 0; i < vertices.length; i++) {
      if (i == 0) {
        path.moveTo(vertices[i].x, vertices[i].y);
      } else {
        path.lineTo(vertices[i].x, vertices[i].y);
      }
    }
    path.close();

    final paint = ui.Paint()
      ..color = color
      ..style = ui.PaintingStyle.stroke
      ..strokeWidth = thickness
      ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 1.0);

    // Apply dash effect
    final metrics = path.computeMetrics().toList();
    if (metrics.isEmpty) return;

    final metric = metrics.first;
    final totalLength = metric.length;

    final center =
        vertices.reduce((a, b) => a + b) / vertices.length.toDouble();

    canvas.save();
    canvas.translate(center.x, center.y);
    canvas.scale(scale);
    canvas.rotate(math.sin(progress * 2) * 0.05); // Subtle slow rotation
    canvas.translate(-center.x, -center.y);

    final dashPath = ui.Path();
    double currentDist = (progress * 20) % (dashLength + dashGap);

    while (currentDist < totalLength) {
      final sub = metric.extractPath(
        currentDist,
        math.min(currentDist + dashLength, totalLength),
      );
      dashPath.addPath(sub, ui.Offset.zero);
      currentDist += dashLength + dashGap;
    }

    canvas.drawPath(dashPath, paint);
    canvas.restore();
  }
}

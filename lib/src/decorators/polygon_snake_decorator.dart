import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flame/rendering.dart';
import 'package:meta/meta.dart';

/// A [Decorator] that draws a traveling energy "snake" (a sub-segment of the
/// silhouette) that cycles around the polygon.
@experimental
class PolygonSnakeDecorator extends Decorator {
  PolygonSnakeDecorator({
    required this.vertices,
    this.color = const ui.Color(0xFF00FFCC),
    this.thickness = 3.0,
    this.lengthRatio = 0.2,
    this.progress = 0.0,
    this.blurSigma = 2.0,
    this.isActive = true,
  });

  /// The vertices defining the silhouette.
  List<Vector2> vertices;

  /// Color of the energy snake.
  ui.Color color;

  /// Thickness of the snake.
  double thickness;

  /// Length of the snake as a ratio of the total perimeter (0.0 to 1.0).
  double lengthRatio;

  /// Snake's position (0.0 to 1.0).
  double progress;

  /// Glow intensity.
  double blurSigma;

  /// Whether the effect is active.
  bool isActive;

  @override
  void apply(void Function(ui.Canvas) draw, ui.Canvas canvas, [Component? component]) {
    // 1. Draw the component first
    draw(canvas);

    if (!isActive || vertices.length < 2) return;

    final path = ui.Path();
    for (int i = 0; i < vertices.length; i++) {
      if (i == 0) {
        path.moveTo(vertices[i].x, vertices[i].y);
      } else {
        path.lineTo(vertices[i].x, vertices[i].y);
      }
    }
    path.close();

    final metrics = path.computeMetrics().toList();
    if (metrics.isEmpty) return;

    final metric = metrics.first;
    final totalLength = metric.length;
    final snakeLength = totalLength * lengthRatio;
    final startDist = totalLength * progress;

    // Extract the segment (handling wrap-around)
    final segmentPath = ui.Path();
    if (startDist + snakeLength <= totalLength) {
      segmentPath.addPath(
        metric.extractPath(startDist, startDist + snakeLength),
        ui.Offset.zero,
      );
    } else {
      // Wrap around the end back to the start
      segmentPath.addPath(
        metric.extractPath(startDist, totalLength),
        ui.Offset.zero,
      );
      segmentPath.addPath(
        metric.extractPath(0, (startDist + snakeLength) % totalLength),
        ui.Offset.zero,
      );
    }

    final paint = ui.Paint()
      ..color = color
      ..style = ui.PaintingStyle.stroke
      ..strokeWidth = thickness
      ..strokeCap = ui.StrokeCap.round
      ..maskFilter = ui.MaskFilter.blur(ui.BlurStyle.normal, blurSigma);

    canvas.drawPath(segmentPath, paint);

    // Optional: Draw a bright "head" point
    final headPoint = metric
        .getTangentForOffset((startDist + snakeLength) % totalLength)
        ?.position;
    if (headPoint != null) {
      final headPaint = ui.Paint()
        ..color = const ui.Color(0xFFFFFFFF)
        ..maskFilter = ui.MaskFilter.blur(ui.BlurStyle.normal, blurSigma * 2);
      canvas.drawCircle(headPoint, thickness * 0.8, headPaint);
    }
  }
}

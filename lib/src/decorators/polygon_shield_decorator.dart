import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/rendering.dart';
import 'package:meta/meta.dart';

/// A [Decorator] that draws a dashed, vibrating "force field" around a polygon silhouette.
@experimental
class PolygonShieldDecorator extends Decorator {
  PolygonShieldDecorator({
    required this.vertices,
    this.color = const Color(0xFF0099FF),
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
  Color color;

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

  void update(double dt) {
    super.update(dt);
  }

  @override
  void apply(void Function(Canvas) draw, Canvas canvas) {
    // 1. Draw the component first
    draw(canvas);

    if (!isActive || vertices.isEmpty) return;

    final currentVibration = (math.sin(progress * 20) + 1.0) * 0.5 * vibration;
    final scale = 1.0 + ((offset + currentVibration) * 0.01);

    // Create the silhouette path
    final path = Path();
    for (int i = 0; i < vertices.length; i++) {
      if (i == 0) {
        path.moveTo(vertices[i].x, vertices[i].y);
      } else {
        path.lineTo(vertices[i].x, vertices[i].y);
      }
    }
    path.close();

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = thickness
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.0);

    // Apply dash effect
    // Note: Manual dashing because PathMetric is easier for cross-platform consistency
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

    final dashPath = Path();
    double currentDist = (progress * 20) % (dashLength + dashGap);

    while (currentDist < totalLength) {
      final sub = metric.extractPath(
        currentDist,
        math.min(currentDist + dashLength, totalLength),
      );
      dashPath.addPath(sub, Offset.zero);
      currentDist += dashLength + dashGap;
    }

    canvas.drawPath(dashPath, paint);
    canvas.restore();
  }
}

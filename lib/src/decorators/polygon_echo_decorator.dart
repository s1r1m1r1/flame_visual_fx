import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flame/rendering.dart';
import 'package:meta/meta.dart';
import 'vfx_decorator.dart';

/// A [Decorator] that draws decaying "echoes" (ghost silhouettes) of the component.
/// It is a pure decorator that expects the [history] of vertices to be provided externally.
@experimental
class PolygonEchoDecorator extends VFXDecorator {
  PolygonEchoDecorator({
    required this.vertices,
    required this.history,
    this.color = const ui.Color(0x8800FFFF),
    this.decayScale = 1.1,
    this.isActive = true,
  });

  /// Current silhouette vertices.
  List<Vector2> vertices;

  /// Historical snapshots of vertices for echo rendering.
  List<List<Vector2>> history;

  /// Base color for the echoes.
  ui.Color color;

  /// How much each subsequent echo scales up (or down).
  double decayScale;

  /// Whether the effect is active.
  bool isActive;

  @override
  void apply(
    void Function(ui.Canvas) draw,
    ui.Canvas canvas, [
    Component? component,
  ]) {
    if (!isActive || vertices.isEmpty) {
      draw(canvas);
      return;
    }

    final maxEchoes = history.length;

    // 1. Draw echoes (from oldest to newest for correct layering)
    for (int i = maxEchoes - 1; i >= 0; i--) {
      final echoVertices = history[i];
      if (echoVertices.isEmpty) continue;

      final progress = 1.0 - (i / (maxEchoes > 0 ? maxEchoes : 1));
      final alpha = (0.5 * progress);
      final scale = 1.0 + (i * (decayScale - 1.0));

      final paint = ui.Paint()
        ..color = color.withValues(alpha: alpha)
        ..style = ui.PaintingStyle.stroke
        ..strokeWidth = 1.5;

      final path = ui.Path();
      for (int k = 0; k < echoVertices.length; k++) {
        if (k == 0) {
          path.moveTo(echoVertices[k].x, echoVertices[k].y);
        } else {
          path.lineTo(echoVertices[k].x, echoVertices[k].y);
        }
      }
      path.close();

      canvas.save();
      // Simple scaling from approx center
      if (decayScale != 1.0 && echoVertices.isNotEmpty) {
        final center =
            echoVertices.reduce((a, b) => a + b) /
            echoVertices.length.toDouble();
        canvas.translate(center.x, center.y);
        canvas.scale(scale);
        canvas.translate(-center.x, -center.y);
      }
      canvas.drawPath(path, paint);
      canvas.restore();
    }

    // 2. Draw the component itself
    draw(canvas);
  }
}

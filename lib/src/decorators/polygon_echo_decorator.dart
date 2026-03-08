import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/rendering.dart';
import 'package:meta/meta.dart';

/// A [Decorator] that draws decaying "echoes" (ghost silhouettes) of the component.
@experimental
class PolygonEchoDecorator extends Decorator {
  PolygonEchoDecorator({
    required this.vertices,
    this.color = const Color(0x8800FFFF),
    this.maxEchoes = 5,
    this.decayScale = 1.1,
    this.isActive = true,
  });

  /// Current silhouette vertices.
  List<Vector2> vertices;

  /// Base color for the echoes.
  Color color;

  /// Maximum number of ghost silhouettes to show.
  int maxEchoes;

  /// How much each subsequent echo scales up (or down).
  double decayScale;

  /// Whether the effect is active.
  bool isActive;

  final List<List<Vector2>> _history = [];

  void update(double dt) {
    super.update(dt);
    if (!isActive) return;

    // Capture current state (clone the list)
    _history.insert(0, List.from(vertices));
    if (_history.length > maxEchoes) {
      _history.removeLast();
    }
  }

  @override
  void apply(void Function(Canvas) draw, Canvas canvas) {
    if (!isActive || vertices.isEmpty) {
      draw(canvas);
      return;
    }

    // 1. Draw echoes (from oldest to newest for correct layering)
    for (int i = _history.length - 1; i >= 0; i--) {
      final echoVertices = _history[i];
      if (echoVertices.isEmpty) continue;

      final progress = 1.0 - (i / maxEchoes);
      final alpha = (0.5 * progress);
      final scale = 1.0 + (i * (decayScale - 1.0));

      final paint = Paint()
        ..color = color.withValues(alpha: alpha)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;

      final path = Path();
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
        final center = echoVertices.reduce((a, b) => a + b) /
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

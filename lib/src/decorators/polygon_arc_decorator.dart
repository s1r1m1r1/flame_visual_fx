import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flame/rendering.dart';
import 'package:meta/meta.dart';

/// A [Decorator] that draws electric arcs jumping between points on a polygon silhouette.
/// This is a pure decorator that expects [activeArcs] and [contactPoints] to be provided.
@experimental
class PolygonArcDecorator extends Decorator {
  PolygonArcDecorator({
    required this.vertices,
    required this.activeArcs,
    required this.contactPoints,
    this.color = const ui.Color(0xFFAAAAFF),
    this.isActive = true,
  });

  /// Current silhouette vertices.
  List<Vector2> vertices;

  /// Fractals defining the arcs to be drawn.
  List<List<ui.Offset>> activeArcs;

  /// Points where arcs touch the silhouette.
  List<ui.Offset> contactPoints;

  /// Color of the electric arcs.
  ui.Color color;

  /// Whether the effect is active.
  bool isActive;

  @override
  void apply(void Function(ui.Canvas) draw, ui.Canvas canvas, [Component? component]) {
    // 1. Draw the component first
    draw(canvas);

    if (!isActive || activeArcs.isEmpty) return;

    final paint = ui.Paint()
      ..color = color.withValues(alpha: 0.8)
      ..style = ui.PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 1.0);

    final glowPaint = ui.Paint()
      ..color = color.withValues(alpha: 0.4)
      ..style = ui.PaintingStyle.stroke
      ..strokeWidth = 4.0
      ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 3.0);

    final hotSpotPaint = ui.Paint()
      ..color = const ui.Color(0xFFFFFFFF).withValues(alpha: 0.9)
      ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 4.0);

    for (final arc in activeArcs) {
      if (arc.length < 2) continue;
      final path = ui.Path();
      path.moveTo(arc[0].dx, arc[0].dy);
      for (int i = 1; i < arc.length; i++) {
        path.lineTo(arc[i].dx, arc[i].dy);
      }

      canvas.drawPath(path, glowPaint);
      canvas.drawPath(path, paint);
    }

    // Draw hot spots at contact points
    for (final cp in contactPoints) {
      canvas.drawCircle(cp, 2.0, hotSpotPaint);
    }
  }
}

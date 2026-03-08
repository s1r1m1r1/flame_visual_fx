import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/rendering.dart';
import 'package:meta/meta.dart';

/// A [Decorator] that draws electric arcs jumping between points on a polygon silhouette.
@experimental
class PolygonArcDecorator extends Decorator {
  PolygonArcDecorator({
    required this.vertices,
    this.color = const Color(0xFFAAAAFF),
    this.arcCount = 3,
    this.arcFrequency = 0.5,
    this.maxFractalDepth = 4,
    this.isActive = true,
  });

  /// Current silhouette vertices.
  List<Vector2> vertices;

  /// Color of the electric arcs.
  Color color;

  /// Number of simultaneous arcs.
  int arcCount;

  /// How often arcs jump to new positions.
  double arcFrequency;

  /// Complexity of the fractal arc.
  int maxFractalDepth;

  /// Whether the effect is active.
  bool isActive;

  final math.Random _random = math.Random();
  double _jumpTimer = 0.0;
  final List<List<Offset>> _activeArcs = [];
  final List<Offset> _contactPoints = [];

  void update(double dt) {
    super.update(dt);
    if (!isActive) return;

    _jumpTimer += dt;
    if (_jumpTimer >= 0.08) {
      // Faster jumps for high activity
      _jumpTimer = 0;
      if (_random.nextDouble() < arcFrequency) {
        _generateArcs();
      }
    }
  }

  void _generateArcs() {
    _activeArcs.clear();
    _contactPoints.clear();
    if (vertices.length < 2) return;

    for (int i = 0; i < arcCount; i++) {
      final idx1 = _random.nextInt(vertices.length);
      var idx2 = _random.nextInt(vertices.length);
      while (idx1 == idx2) {
        idx2 = _random.nextInt(vertices.length);
      }

      final start = vertices[idx1].toOffset();
      final end = vertices[idx2].toOffset();

      _contactPoints.add(start);
      _contactPoints.add(end);

      final arcPoints = <Offset>[start];
      _createFractalArc(start, end, maxFractalDepth, arcPoints, true);
      arcPoints.add(end);
      _activeArcs.add(arcPoints);
    }
  }

  void _createFractalArc(Offset start, Offset end, int depth,
      List<Offset> points, bool canBranch) {
    if (depth <= 0) return;

    final mid = (start + end) / 2;
    final dx = end.dx - start.dx;
    final dy = end.dy - start.dy;
    final dist = math.sqrt(dx * dx + dy * dy);

    if (dist < 1.0) return;

    final nx = -dy / dist;
    final ny = dx / dist;

    final magnitude = (dist * 0.4) * (_random.nextDouble() - 0.5);
    final jitteredMid =
        Offset(mid.dx + nx * magnitude, mid.dy + ny * magnitude);

    // Branching chance
    if (canBranch && depth > 2 && _random.nextDouble() < 0.25) {
      final branchEnd = jitteredMid +
          Offset((_random.nextDouble() - 0.5) * dist,
              (_random.nextDouble() - 0.5) * dist);
      final branchPoints = <Offset>[jitteredMid];
      _createFractalArc(jitteredMid, branchEnd, depth - 1, branchPoints, false);
      _activeArcs.add(branchPoints);
    }

    _createFractalArc(start, jitteredMid, depth - 1, points, canBranch);
    points.add(jitteredMid);
    _createFractalArc(jitteredMid, end, depth - 1, points, canBranch);
  }

  @override
  void apply(void Function(Canvas) draw, Canvas canvas) {
    // 1. Draw the component first
    draw(canvas);

    if (!isActive || _activeArcs.isEmpty) return;

    final paint = Paint()
      ..color = color.withValues(alpha: 0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.0);

    final glowPaint = Paint()
      ..color = color.withValues(alpha: 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.0);

    final hotSpotPaint = Paint()
      ..color = const Color(0xFFFFFFFF).withValues(alpha: 0.9)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.0);

    for (final arc in _activeArcs) {
      if (arc.length < 2) continue;
      final path = Path();
      path.moveTo(arc[0].dx, arc[0].dy);
      for (int i = 1; i < arc.length; i++) {
        path.lineTo(arc[i].dx, arc[i].dy);
      }

      canvas.drawPath(path, glowPaint);
      canvas.drawPath(path, paint);
    }

    // Draw hot spots at contact points
    for (final cp in _contactPoints) {
      canvas.drawCircle(cp, 2.0, hotSpotPaint);
    }
  }
}

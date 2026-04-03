import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/rendering.dart';
import 'package:meta/meta.dart';
import 'vfx_decorator.dart';

/// The type of animation for the polygon outline.
enum PolygonOutlineMode {
  /// A smooth, sine-wave oscillation.
  wavy,

  /// A jagged, high-frequency random jitter.
  electric,

  /// A simple, static line.
  static,
}

/// A [Decorator] that draws an animated outline (wavy or electric) based on
/// a provided set of polygon vertices.
///
/// This is useful for highlighting components with custom shapes or adding
/// magical/electric energy effects.
@experimental
class PolygonOutlineDecorator extends VFXDecorator {
  PolygonOutlineDecorator({
    required this.vertices,
    this.color = const Color(0xFF00FFFF),
    this.thickness = 2.0,
    this.amplitude = 4.0,
    this.frequency = 1.0,
    this.phase = 0.0,
    this.mode = PolygonOutlineMode.wavy,
    this.isActive = true,
  });

  /// The vertices defining the base shape of the outline, relative to the
  /// component's top-left origin.
  List<Vector2> vertices;

  /// The color of the outline.
  Color color;

  /// The thickness of the line.
  double thickness;

  /// The maximum deviation from the base line.
  double amplitude;

  /// How many wave cycles occur along the entire perimeter (for wavy mode)
  /// or sample density (for electric mode).
  double frequency;

  /// The phase of the wavy oscillation.
  double phase;

  /// The style of animation.
  PolygonOutlineMode mode;

  /// Whether the effect is currently active.
  bool isActive;

  final math.Random _random = math.Random();

  List<Vector2>? _lastVertices;
  List<_PolygonSegment>? _segments;
  Path? _staticPath;
  Paint? _paint;

  @override
  void update(double dt) {
    super.update(dt);
  }

  @override
  void apply(
    void Function(Canvas) draw,
    Canvas canvas, [
    Component? component,
  ]) {
    // 1. Draw the component normally first
    draw(canvas);

    if (!isActive || vertices.length < 2) {
      return;
    }

    if (_paint == null ||
        _paint!.color != color ||
        _paint!.strokeWidth != thickness) {
      _paint = Paint()
        ..color = color
        ..strokeWidth = thickness
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
    }

    // Pre-calculate segments if vertices changed
    if (_lastVertices != vertices) {
      _lastVertices = vertices;
      _segments = [];
      _staticPath = Path();
      bool first = true;
      for (int i = 0; i < vertices.length; i++) {
        final p1 = vertices[i];
        final p2 = vertices[(i + 1) % vertices.length];

        if (first) {
          _staticPath!.moveTo(p1.x, p1.y);
          first = false;
        } else {
          _staticPath!.lineTo(p1.x, p1.y);
        }

        final segment = p2 - p1;
        final length = segment.length;
        if (length == 0) continue;

        final normal = Vector2(-segment.y, segment.x).normalized();
        _segments!.add(_PolygonSegment(p1, segment, length, normal));
      }
      _staticPath!.close();
    }

    if (mode == PolygonOutlineMode.static) {
      canvas.drawPath(_staticPath!, _paint!);
      return;
    }

    final path = Path();
    bool first = true;
    double cumulativeDistance = 0.0;

    for (final seg in _segments!) {
      // Density of segments: at least 1 per 5 pixels
      final int steps = (seg.length / 5.0).ceil();

      for (int step = 0; step <= steps; step++) {
        final double t = step / steps;
        final currentPoint = seg.p1 + (seg.direction * t);
        final double currentDist = cumulativeDistance + (seg.length * t);

        double displacement = 0.0;
        if (mode == PolygonOutlineMode.wavy) {
          displacement =
              math.sin(phase + currentDist * (frequency * 0.05)) * amplitude;
        } else if (mode == PolygonOutlineMode.electric) {
          if (_random.nextDouble() > 0.3) {
            displacement = (_random.nextDouble() * 2 - 1) * amplitude;
          }
        }

        final renderPoint = currentPoint + (seg.normal * displacement);

        if (first) {
          path.moveTo(renderPoint.x, renderPoint.y);
          first = false;
        } else {
          path.lineTo(renderPoint.x, renderPoint.y);
        }
      }
      cumulativeDistance += seg.length;
    }

    path.close();
    canvas.drawPath(path, _paint!);
  }
}

class _PolygonSegment {
  _PolygonSegment(this.p1, this.direction, this.length, this.normal);
  final Vector2 p1;
  final Vector2 direction;
  final double length;
  final Vector2 normal;
}

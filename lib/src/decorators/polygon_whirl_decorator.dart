import 'dart:ui' as ui;
import 'package:flame/components.dart';
import 'package:flame/rendering.dart';
import 'package:flutter/material.dart' show Colors;
import 'package:meta/meta.dart';
import 'vfx_decorator.dart';

class WhirlParticle {
  WhirlParticle({
    required this.position,
    required this.angle,
    required this.radius,
    required this.maxLifetime,
    this.lifetime = 0.0,
  });

  Vector2 position;
  double angle;
  double radius;
  double lifetime;
  double maxLifetime;

  double get progress => lifetime / maxLifetime;
}

/// A [Decorator] that draws orbiting ghost-like particles from a polygon silhouette.
/// This is a pure decorator that expects [particles] to be provided externally.
@experimental
class PolygonWhirlDecorator extends VFXDecorator {
  PolygonWhirlDecorator({
    required this.vertices,
    required this.particles,
    this.color = const ui.Color(0xFF00FFFF),
    this.isActive = true,
  });

  /// Current silhouette vertices.
  List<Vector2> vertices;

  /// External list of active whirl particles.
  List<WhirlParticle> particles;

  /// Base color of the souls.
  ui.Color color;

  /// Whether the effect is active.
  bool isActive;

  final ui.Paint _particlePaint = ui.Paint();
  final ui.Paint _glowPaint = ui.Paint();

  @override
  void apply(
    void Function(ui.Canvas) draw,
    ui.Canvas canvas, [
    Component? component,
  ]) {
    // 1. Draw the component first
    draw(canvas);

    if (!isActive || particles.isEmpty) return;

    canvas.save();

    for (final p in particles) {
      final double progress = p.progress;
      final double opacity = 0.6 * (1.0 - progress);
      final double size = 3.0 * (1.2 - progress);

      _particlePaint
        ..color = color.withValues(alpha: opacity)
        ..maskFilter = ui.MaskFilter.blur(ui.BlurStyle.normal, size * 0.8);

      // Draw a small "soul" with a trail-like feel
      canvas.drawCircle(p.position.toOffset(), size, _particlePaint);

      // Sub-glow
      _glowPaint
        ..color = Colors.white.withValues(alpha: opacity * 0.5)
        ..maskFilter = ui.MaskFilter.blur(ui.BlurStyle.normal, size * 0.4);
      canvas.drawCircle(p.position.toOffset(), size * 0.4, _glowPaint);
    }
    canvas.restore();
  }
}

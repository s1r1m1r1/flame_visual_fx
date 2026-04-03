import 'dart:ui' as ui;
import 'package:flame/components.dart';
import 'package:flame/rendering.dart';
import 'package:meta/meta.dart';
import 'vfx_decorator.dart';

class SimpleParticle {
  Vector2 position;
  Vector2 velocity;
  double life;
  double maxLife;

  SimpleParticle({
    required this.position,
    required this.velocity,
    required this.maxLife,
    double? life,
  }) : life = life ?? maxLife;

  double get progress => life / maxLife;
}

/// A [Decorator] that draws particles from the vertices of a polygon silhouette.
/// This is a pure decorator that expects [particles] to be provided externally.
@experimental
class PolygonParticleDecorator extends VFXDecorator {
  PolygonParticleDecorator({
    required this.vertices,
    required this.particles,
    this.color = const ui.Color(0xFFFFCC00),
    this.particleSize = 2.0,
    this.isActive = true,
  });

  /// Current silhouette vertices.
  List<Vector2> vertices;

  /// External list of active particles.
  List<SimpleParticle> particles;

  /// Color of the particles.
  ui.Color color;

  /// Size factor for particles.
  double particleSize;

  /// Whether the effect is active.
  bool isActive;

  @override
  void apply(
    void Function(ui.Canvas) draw,
    ui.Canvas canvas, [
    Component? component,
  ]) {
    // 1. Draw the component first
    draw(canvas);

    if (!isActive || particles.isEmpty) return;

    final paint = ui.Paint()
      ..color = color
      ..style = ui.PaintingStyle.fill;

    for (final p in particles) {
      final progress = p.progress;
      paint.color = color.withValues(alpha: progress);

      canvas.drawCircle(p.position.toOffset(), particleSize * progress, paint);
    }
  }
}

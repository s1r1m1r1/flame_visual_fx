import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/rendering.dart';
import 'package:meta/meta.dart';

class _SimpleParticle {
  Vector2 position;
  Vector2 velocity;
  double life;
  double maxLife;

  _SimpleParticle({
    required this.position,
    required this.velocity,
    required this.maxLife,
  }) : life = maxLife;
}

/// A [Decorator] that spawns particles from the vertices of a polygon silhouette.
@experimental
class PolygonParticleDecorator extends Decorator {
  PolygonParticleDecorator({
    required this.vertices,
    this.color = const Color(0xFFFFCC00),
    this.spawnRate = 100.0,
    this.particleLife = 1.0,
    this.particleSize = 2.0,
    this.isActive = true,
  });

  /// Current silhouette vertices.
  List<Vector2> vertices;

  /// Color of the particles.
  Color color;

  /// Particles per second.
  double spawnRate;

  /// Lifetime in seconds.
  double particleLife;

  /// Size of each particle.
  double particleSize;

  /// Whether the effect is active.
  bool isActive;

  final List<_SimpleParticle> _particles = [];
  final math.Random _random = math.Random();
  double _spawnAccumulator = 0.0;

  void update(double dt) {
    super.update(dt);
    if (!isActive) return;

    // 1. Update existing particles
    for (int i = _particles.length - 1; i >= 0; i--) {
      final p = _particles[i];
      p.life -= dt;
      if (p.life <= 0) {
        _particles.removeAt(i);
        continue;
      }
      p.position += p.velocity * dt;
    }

    // 2. Spawn new particles
    if (vertices.isNotEmpty) {
      _spawnAccumulator += dt * spawnRate;
      while (_spawnAccumulator >= 1.0) {
        _spawnAccumulator -= 1.0;

        // Pick a random vertex
        final index = _random.nextInt(vertices.length);
        final basePos = vertices[index];

        _particles.add(_SimpleParticle(
          position: basePos.clone(),
          velocity: Vector2(
            (_random.nextDouble() - 0.5) * 20,
            -_random.nextDouble() * 50, // Drift upwards
          ),
          maxLife: particleLife * (0.5 + _random.nextDouble() * 0.5),
        ));
      }
    }
  }

  @override
  void apply(void Function(Canvas) draw, Canvas canvas) {
    // 1. Draw the component first
    draw(canvas);

    if (!isActive || _particles.isEmpty) return;

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    for (final p in _particles) {
      final progress = p.life / p.maxLife;
      paint.color = color.withValues(alpha: progress);

      canvas.drawCircle(
        p.position.toOffset(),
        particleSize * progress,
        paint,
      );
    }
  }
}

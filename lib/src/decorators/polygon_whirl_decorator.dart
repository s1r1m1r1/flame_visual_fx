import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/rendering.dart';
import 'package:flutter/material.dart' show Colors;
import 'package:meta/meta.dart';

class _WhirlParticle {
  _WhirlParticle({
    required this.position,
    required this.angle,
    required this.radius,
    required this.maxLifetime,
  });

  Vector2 position;
  double angle;
  double radius;
  double lifetime = 0;
  double maxLifetime;

  double get progress => lifetime / maxLifetime;
}

/// A [Decorator] that spawns orbiting ghost-like particles from a polygon silhouette.
@experimental
class PolygonWhirlDecorator extends Decorator {
  PolygonWhirlDecorator({
    required this.vertices,
    this.color = const Color(0xFF00FFFF),
    this.spawnRate = 30.0,
    this.isActive = true,
  });

  /// Current silhouette vertices.
  List<Vector2> vertices;

  /// Base color of the souls.
  Color color;

  /// Particles spawned per second.
  double spawnRate;

  /// Whether the effect is active.
  bool isActive;

  final math.Random _random = math.Random();
  final List<_WhirlParticle> _particles = [];
  double _spawnTimer = 0;

  List<Vector2>? _lastVertices;
  Vector2? _cachedCenter;
  final Paint _particlePaint = Paint();
  final Paint _glowPaint = Paint();

  void update(double dt) {
    super.update(dt);
    if (isActive) {
      if (_lastVertices != vertices) {
        _lastVertices = vertices;
        _cachedCenter =
            vertices.reduce((a, b) => a + b) / vertices.length.toDouble();
      }
    }

    // Fallback if update is called before apply/vertices
    if (_cachedCenter == null && vertices.isNotEmpty) {
      _cachedCenter =
          vertices.reduce((a, b) => a + b) / vertices.length.toDouble();
    }
    if (_cachedCenter == null) return;

    final center = _cachedCenter!;

    // Update existing particles
    for (int i = _particles.length - 1; i >= 0; i--) {
      final p = _particles[i];
      p.lifetime += dt;
      if (p.lifetime >= p.maxLifetime) {
        _particles.removeAt(i);
        continue;
      }

      // Small constant rotation in the simulation
      p.angle += 2.0 * dt;

      // Spiral inward slightly
      p.radius *= (1.0 - 0.4 * dt);

      p.position = Vector2(
        center.x + math.cos(p.angle) * p.radius,
        center.y + math.sin(p.angle) * p.radius,
      );
    }

    // Spawn new particles
    _spawnTimer += dt;
    final spawnInterval = 1.0 / spawnRate;
    while (_spawnTimer >= spawnInterval) {
      _spawnTimer -= spawnInterval;
      _spawnParticle(center);
    }
  }

  void _spawnParticle(Vector2 center) {
    final startPos = vertices[_random.nextInt(vertices.length)];
    final diff = startPos - center;
    final radius = diff.length;
    final angle = math.atan2(diff.y, diff.x);

    _particles.add(_WhirlParticle(
      position: startPos.clone(),
      angle: angle,
      radius: radius,
      maxLifetime: 1.0 + _random.nextDouble(),
    ));
  }

  @override
  void apply(void Function(Canvas) draw, Canvas canvas) {
    // 1. Draw the component first
    draw(canvas);

    if (!isActive || _particles.isEmpty) return;

    canvas.save();

    for (final p in _particles) {
      final double progress = p.progress;
      final double opacity = 0.6 * (1.0 - progress);
      final double size = 3.0 * (1.2 - progress);

      _particlePaint
        ..color = color.withValues(alpha: opacity)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, size * 0.8);

      // Draw a small "soul" with a trail-like feel (stretching based on speed)
      canvas.drawCircle(p.position.toOffset(), size, _particlePaint);

      // Sub-glow
      _glowPaint
        ..color = Colors.white.withValues(alpha: opacity * 0.5)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, size * 0.4);
      canvas.drawCircle(p.position.toOffset(), size * 0.4, _glowPaint);
    }
    canvas.restore();
  }
}

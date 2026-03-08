import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/rendering.dart';
import 'package:meta/meta.dart';

class _FireParticle {
  _FireParticle({
    required this.position,
    required this.velocity,
    required this.maxLifetime,
  });

  Vector2 position;
  Vector2 velocity;
  double lifetime = 0;
  double maxLifetime;

  double get progress => lifetime / maxLifetime;
}

/// A [Decorator] that spawns glowing fire particles from a polygon silhouette.
@experimental
class PolygonFireDecorator extends Decorator {
  PolygonFireDecorator({
    required this.vertices,
    this.spawnRate = 50.0,
    this.particleSpeed = 40.0,
    this.isActive = true,
  });

  /// Current silhouette vertices.
  List<Vector2> vertices;

  /// Particles spawned per second.
  double spawnRate;

  /// Average speed of particles.
  double particleSpeed;

  /// Whether the effect is active.
  bool isActive;

  /// Overall intensity of the fire (0.0 to 1.0).
  /// Drives spawn rate and particle brightness.
  double intensity = 1.0;

  final math.Random _random = math.Random();
  final List<_FireParticle> _particles = [];
  double _spawnTimer = 0;

  List<Vector2>? _lastVertices;
  double _minY = 0;
  double _maxY = 0;
  List<Vector2>? _bottomVertices;
  final Paint _particlePaint = Paint()..blendMode = BlendMode.plus;

  // Cache MaskFilters by size (quantized) to avoid massive allocations
  static final Map<int, MaskFilter> _blurCache = {};

  void update(double dt) {
    super.update(dt);
    if (!isActive) return;

    // Update existing particles
    for (int i = _particles.length - 1; i >= 0; i--) {
      final p = _particles[i];
      p.lifetime += dt;
      if (p.lifetime >= p.maxLifetime) {
        _particles.removeAt(i);
        continue;
      }
      // Move upwards with slight side-to-side drift
      p.position += p.velocity * dt;
      p.velocity.x += (_random.nextDouble() - 0.5) * 10;
    }

    // Spawn new particles
    if (vertices.length >= 2 && intensity > 0.01) {
      _spawnTimer += dt;
      final spawnInterval = 1.0 / (spawnRate * intensity);
      while (_spawnTimer >= spawnInterval) {
        _spawnTimer -= spawnInterval;
        _spawnParticle();
      }
    }
  }

  void _spawnParticle() {
    if (_lastVertices != vertices) {
      _lastVertices = vertices;
      _maxY = double.negativeInfinity;
      _minY = double.infinity;
      for (final v in vertices) {
        if (v.y > _maxY) _maxY = v.y;
        if (v.y < _minY) _minY = v.y;
      }
      final height = _maxY - _minY;
      _bottomVertices =
          vertices.where((v) => v.y > _maxY - (height * 0.3)).toList();
    }

    // Pick a vertex with weighted probability
    Vector2 spawnPos;
    if (_random.nextDouble() < 0.7 && _bottomVertices!.isNotEmpty) {
      spawnPos =
          _bottomVertices![_random.nextInt(_bottomVertices!.length)].clone();
    } else {
      spawnPos = vertices[_random.nextInt(vertices.length)].clone();
    }

    _particles.add(_FireParticle(
      position: spawnPos,
      velocity: Vector2((_random.nextDouble() - 0.5) * 10,
          -particleSpeed * (0.8 + _random.nextDouble() * 0.4)),
      maxLifetime: 0.5 + _random.nextDouble() * 0.5,
    ));
  }

  @override
  void apply(void Function(Canvas) draw, Canvas canvas) {
    // 1. Draw the component first
    draw(canvas);

    if (!isActive || _particles.isEmpty) return;

    if (!isActive || _particles.isEmpty) return;

    for (final p in _particles) {
      final double progress = p.progress;
      final double size = 6.0 * (1.0 - progress);

      // Color transition: Yellow -> Orange -> Red -> Transparent
      Color color;
      if (progress < 0.3) {
        color = Color.lerp(
            const Color(0xFFFFFF00), const Color(0xFFFF9900), progress / 0.3)!;
      } else if (progress < 0.7) {
        color = Color.lerp(const Color(0xFFFF9900), const Color(0xFFFF0000),
            (progress - 0.3) / 0.4)!;
      } else {
        color = const Color(0xFFFF0000)
            .withValues(alpha: (1.0 - (progress - 0.7) / 0.3).clamp(0.0, 1.0));
      }

      color = color.withValues(alpha: color.a * intensity);

      // Quantize size to 10 steps for caching (0.6px increments)
      final quantizedSizeKey = (size * 1.66).round(); // 10 steps max
      final blur = _blurCache.putIfAbsent(
        quantizedSizeKey,
        () => MaskFilter.blur(BlurStyle.normal, quantizedSizeKey / 1.66 * 0.5),
      );

      _particlePaint
        ..color = color
        ..maskFilter = blur;

      canvas.drawCircle(p.position.toOffset(), size, _particlePaint);
    }
  }
}

import 'dart:ui' as ui;
import 'package:flame/components.dart';
import 'package:flame/rendering.dart';
import 'package:meta/meta.dart';
import 'vfx_decorator.dart';

class FireParticle {
  FireParticle({
    required this.position,
    required this.velocity,
    required this.maxLifetime,
    this.lifetime = 0.0,
  });

  Vector2 position;
  Vector2 velocity;
  double lifetime;
  double maxLifetime;

  double get progress => lifetime / maxLifetime;
}

/// A [Decorator] that draws glowing fire particles from a polygon silhouette.
/// This is a pure decorator that expects [particles] to be provided externally.
@experimental
class PolygonFireDecorator extends VFXDecorator {
  PolygonFireDecorator({
    required this.vertices,
    required this.particles,
    this.isActive = true,
    this.intensity = 1.0,
  });

  /// Current silhouette vertices.
  List<Vector2> vertices;

  /// External list of active fire particles.
  List<FireParticle> particles;

  /// Whether the effect is active.
  bool isActive;

  /// Overall intensity of the fire (0.0 to 1.0).
  /// Drives particle brightness.
  double intensity;

  final ui.Paint _particlePaint = ui.Paint()..blendMode = ui.BlendMode.plus;
  static final Map<int, ui.MaskFilter> _blurCache = {};

  @override
  void apply(
    void Function(ui.Canvas) draw,
    ui.Canvas canvas, [
    Component? component,
  ]) {
    // 1. Draw the component first
    draw(canvas);

    if (!isActive || particles.isEmpty) return;

    for (final p in particles) {
      final double progress = p.progress;
      final double size = 6.0 * (1.0 - progress);

      // Color transition: Yellow -> Orange -> Red -> Transparent
      ui.Color color;
      if (progress < 0.3) {
        color = ui.Color.lerp(
          const ui.Color(0xFFFFFF00),
          const ui.Color(0xFFFF9900),
          progress / 0.3,
        )!;
      } else if (progress < 0.7) {
        color = ui.Color.lerp(
          const ui.Color(0xFFFF9900),
          const ui.Color(0xFFFF0000),
          (progress - 0.3) / 0.4,
        )!;
      } else {
        color = const ui.Color(
          0xFFFF0000,
        ).withValues(alpha: (1.0 - (progress - 0.7) / 0.3).clamp(0.0, 1.0));
      }

      color = color.withValues(alpha: color.a * intensity);

      // Quantize size to 10 steps for caching (0.6px increments)
      final quantizedSizeKey = (size * 1.66).round(); // 10 steps max
      final blur = _blurCache.putIfAbsent(
        quantizedSizeKey,
        () => ui.MaskFilter.blur(
          ui.BlurStyle.normal,
          quantizedSizeKey / 1.66 * 0.5,
        ),
      );

      _particlePaint
        ..color = color
        ..maskFilter = blur;

      canvas.drawCircle(p.position.toOffset(), size, _particlePaint);
    }
  }
}

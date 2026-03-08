import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/rendering.dart';
import 'package:meta/meta.dart';

/// A [Decorator] that draws a layered, glowing aura around a polygon silhouette.
@experimental
class PolygonAuraDecorator extends Decorator {
  PolygonAuraDecorator({
    required this.vertices,
    this.color = const Color(0xFFFF00FF),
    this.baseAmplitude = 5.0,
    this.pulse = 0.5,
    this.blurSigma = 4.0,
    this.layers = 3,
    this.isActive = true,
  });

  /// The vertices defining the silhouette.
  List<Vector2> vertices;

  /// Base color of the aura.
  Color color;

  /// How far the aura expands from the silhouette.
  double baseAmplitude;

  /// Breathing progress (0.0 to 1.0).
  double pulse;

  /// Softness of the aura.
  double blurSigma;

  /// Number of glowing layers.
  int layers;

  /// Whether the effect is active.
  bool isActive;

  List<Vector2>? _lastVertices;
  Path? _cachedPath;
  Vector2? _cachedCenter;
  final Paint _auraPaint = Paint();
  static final Map<int, MaskFilter> _blurCache = {};

  void update(double dt) {
    super.update(dt);
  }

  @override
  void apply(void Function(Canvas) draw, Canvas canvas) {
    // 1. Draw the component first
    draw(canvas);

    if (!isActive || vertices.length < 2) return;

    final currentAmplitude = baseAmplitude * (0.8 + pulse * 0.4);

    if (_lastVertices != vertices) {
      _lastVertices = vertices;
      _cachedPath = Path();
      for (int i = 0; i < vertices.length; i++) {
        if (i == 0) {
          _cachedPath!.moveTo(vertices[i].x, vertices[i].y);
        } else {
          _cachedPath!.lineTo(vertices[i].x, vertices[i].y);
        }
      }
      _cachedPath!.close();
      _cachedCenter =
          vertices.reduce((a, b) => a + b) / vertices.length.toDouble();
    }

    for (int i = 1; i <= layers; i++) {
      final layerScale = 1.0 + (i * currentAmplitude * 0.002);
      final layerAlpha = (0.6 / i) * (0.7 + pulse * 0.3);

      // Cache MaskFilters by sigma (quantized)
      final double sigma = blurSigma * i * 0.5;
      final int quantizedSigmaKey = (sigma * 10).round();
      final blur = _blurCache.putIfAbsent(
        quantizedSigmaKey,
        () => MaskFilter.blur(BlurStyle.normal, quantizedSigmaKey / 10.0),
      );

      _auraPaint
        ..color = color.withValues(alpha: layerAlpha)
        ..style = PaintingStyle.stroke
        ..strokeWidth = i * 2.0
        ..maskFilter = blur;

      canvas.save();
      canvas.translate(_cachedCenter!.x, _cachedCenter!.y);
      canvas.scale(layerScale);
      canvas.translate(-_cachedCenter!.x, -_cachedCenter!.y);

      canvas.drawPath(_cachedPath!, _auraPaint);
      canvas.restore();
    }
  }
}

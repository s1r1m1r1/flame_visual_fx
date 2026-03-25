import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flame/rendering.dart';
import 'package:meta/meta.dart';
import 'vfx_decorator.dart';

/// A [Decorator] that draws a horizontal scanline clipped to a polygon silhouette.
@experimental
class PolygonScanDecorator extends VFXDecorator {
  PolygonScanDecorator({
    required this.vertices,
    this.color = const ui.Color.fromARGB(255, 255, 0, 0),
    this.lineHeight = 2.0,
    this.progress = 0.0,
    this.glowAlpha = 0.3,
    this.isActive = true,
  });

  /// Current silhouette vertices.
  List<Vector2> vertices;

  /// Color of the scanline.
  ui.Color color;

  /// Height of the scanning line.
  double lineHeight;

  /// Scanning progress (0.0 to 1.0).
  double progress;

  /// Alpha multiplier for the glow trail.
  double glowAlpha;

  /// Whether the effect is active.
  bool isActive;

  List<Vector2>? _lastVertices;
  ui.Path? _cachedPath;
  double _minY = 0.0;
  double _maxY = 0.0;
  ui.Paint? _linePaint;
  ui.Paint? _glowPaint;

  @override
  void apply(void Function(ui.Canvas) draw, ui.Canvas canvas, [Component? component]) {
    // 1. Draw the component first
    draw(canvas);

    if (!isActive || vertices.isEmpty) return;

    if (_lastVertices != vertices) {
      _lastVertices = vertices;
      _cachedPath = ui.Path();
      double localMinY = double.infinity;
      double localMaxY = double.negativeInfinity;
      for (int i = 0; i < vertices.length; i++) {
        final v = vertices[i];
        if (v.y < localMinY) localMinY = v.y;
        if (v.y > localMaxY) localMaxY = v.y;

        if (i == 0) {
          _cachedPath!.moveTo(v.x, v.y);
        } else {
          _cachedPath!.lineTo(v.x, v.y);
        }
      }
      _cachedPath!.close();
      _minY = localMinY;
      _maxY = localMaxY;
    }

    final height = _maxY - _minY;
    final currentY = _minY + (height * progress);

    canvas.save();
    canvas.clipPath(_cachedPath!);

    if (_linePaint == null || _linePaint!.color != color) {
      _linePaint = ui.Paint()
        ..color = color
        ..style = ui.PaintingStyle.fill;
    }

    // Main line
    canvas.drawRect(
      ui.Rect.fromLTWH(-1000, currentY - lineHeight / 2, 4000, lineHeight),
      _linePaint!,
    );

    if (_glowPaint == null ||
        _glowPaint!.color.withValues(alpha: 1.0) !=
            color.withValues(alpha: 1.0)) {
      _glowPaint = ui.Paint()
        ..color = color.withValues(alpha: glowAlpha)
        ..style = ui.PaintingStyle.fill
        ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 2.0);
    }

    canvas.drawRect(
      ui.Rect.fromLTWH(-1000, currentY - lineHeight * 2, 4000, lineHeight * 4),
      _glowPaint!,
    );

    canvas.restore();
  }
}

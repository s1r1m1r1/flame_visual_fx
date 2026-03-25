import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flame/components.dart';

enum DissolveType { random, topDown, bottomUp, leftRight, rightLeft, radial }

abstract class DissolveMask {
  /// User-provided noise grid. If null, a procedural grid is generated.
  List<double>? customNoise;

  /// Global accumulated time or phase for animations independent of progress.
  double time = 0.0;

  DissolveMask({this.customNoise});

  /// Render the dissolve mask over the [canvas] with the specified [erasePaint].
  void renderMask(
    ui.Canvas canvas,
    ui.Paint erasePaint,
    Vector2 effectiveSize,
    double progress,
    DissolveType type,
    double noiseWeight,
  );

  /// Helper to calculate the final threshold to dissolve a block.
  double getThreshold(
    double patternValue,
    double noiseValue,
    double noiseWeight,
  ) {
    final edgeWeight = 1.0 - noiseWeight;
    return (patternValue * edgeWeight) + (noiseValue * noiseWeight);
  }

  /// Helper to get pattern value based on [nx] and [ny] ranging [0..1].
  double getPatternValue(DissolveType type, double nx, double ny) {
    return switch (type) {
      DissolveType.random => 0.0,
      DissolveType.topDown => ny,
      DissolveType.bottomUp => 1.0 - ny,
      DissolveType.leftRight => nx,
      DissolveType.rightLeft => 1.0 - nx,
      DissolveType.radial =>
        math.sqrt(math.pow(nx - 0.5, 2) + math.pow(ny - 0.5, 2)) * 1.414,
    };
  }
}

class GridDissolveMask extends DissolveMask {
  int gridSize;
  List<double>? _generatedGrid;

  GridDissolveMask({this.gridSize = 25, super.customNoise});

  List<double> _getOrGenerateGrid() {
    if (customNoise != null) return customNoise!;
    final expectedLength = gridSize * gridSize;
    if (_generatedGrid == null || _generatedGrid!.length != expectedLength) {
      _generatedGrid = List.generate(
        expectedLength,
        (_) => math.Random().nextDouble(),
      );
    }
    return _generatedGrid!;
  }

  @override
  void renderMask(
    ui.Canvas canvas,
    ui.Paint erasePaint,
    Vector2 effectiveSize,
    double progress,
    DissolveType type,
    double noiseWeight,
  ) {
    final grid = _getOrGenerateGrid();
    final double blockW = effectiveSize.x / gridSize;
    final double blockH = effectiveSize.y / gridSize;

    for (int y = 0; y < gridSize; y++) {
      for (int x = 0; x < gridSize; x++) {
        final nx = (x + 0.5) / gridSize;
        final ny = (y + 0.5) / gridSize;

        final patternValue = getPatternValue(type, nx, ny);
        final noiseIndex = y * gridSize + x;
        final maxNoiseIndex = grid.isNotEmpty ? grid.length - 1 : 0;
        final noiseValue = grid.isNotEmpty
            ? grid[math.min(noiseIndex, maxNoiseIndex)]
            : 0.0;

        final threshold = getThreshold(patternValue, noiseValue, noiseWeight);

        if (progress >= threshold) {
          canvas.drawRect(
            ui.Rect.fromLTWH(
              x * blockW,
              y * blockH,
              blockW + 0.5,
              blockH + 0.5,
            ),
            erasePaint,
          );
        }
      }
    }
  }
}

enum SliceDirection { horizontal, vertical }

enum SliceAnimation { none, startToEnd, endToStart }

class SliceDissolveMask extends DissolveMask {
  int slicesCount;
  SliceDirection direction;
  SliceAnimation animation;
  double animationDuration;
  List<double>? _generatedGrid;

  SliceDissolveMask({
    this.slicesCount = 5,
    this.direction = SliceDirection.horizontal,
    this.animation = SliceAnimation.startToEnd,
    this.animationDuration = 0.2,
    super.customNoise,
  });

  List<double> _getOrGenerateGrid() {
    if (customNoise != null) return customNoise!;
    if (_generatedGrid == null || _generatedGrid!.length != slicesCount) {
      _generatedGrid = List.generate(
        slicesCount,
        (_) => math.Random().nextDouble(),
      );
    }
    return _generatedGrid!;
  }

  @override
  void renderMask(
    ui.Canvas canvas,
    ui.Paint erasePaint,
    Vector2 effectiveSize,
    double progress,
    DissolveType type,
    double noiseWeight,
  ) {
    final grid = _getOrGenerateGrid();
    final cellsX = direction == SliceDirection.horizontal ? 1 : slicesCount;
    final cellsY = direction == SliceDirection.vertical ? 1 : slicesCount;

    final double blockW = effectiveSize.x / cellsX;
    final double blockH = effectiveSize.y / cellsY;

    for (int y = 0; y < cellsY; y++) {
      for (int x = 0; x < cellsX; x++) {
        final nx = cellsX > 1 ? (x + 0.5) / cellsX : 0.5;
        final ny = cellsY > 1 ? (y + 0.5) / cellsY : 0.5;

        final patternValue = getPatternValue(type, nx, ny);
        final noiseIndex = direction == SliceDirection.horizontal ? y : x;

        final maxNoiseIndex = grid.isNotEmpty ? grid.length - 1 : 0;
        final noiseValue = grid.isNotEmpty
            ? grid[math.min(noiseIndex, maxNoiseIndex)]
            : 0.0;

        final threshold = getThreshold(patternValue, noiseValue, noiseWeight);

        if (animation == SliceAnimation.none) {
          if (progress >= threshold) {
            canvas.drawRect(
              ui.Rect.fromLTWH(
                x * blockW,
                y * blockH,
                blockW + 0.5,
                blockH + 0.5,
              ),
              erasePaint,
            );
          }
        } else {
          double localProgress =
              (progress - (threshold - animationDuration)) / animationDuration;
          localProgress = localProgress.clamp(0.0, 1.0);

          if (localProgress > 0.0) {
            double eraseX = x * blockW;
            double eraseY = y * blockH;
            double eraseW = blockW;
            double eraseH = blockH;

            if (direction == SliceDirection.horizontal) {
              if (animation == SliceAnimation.startToEnd) {
                eraseW = blockW * localProgress;
              } else if (animation == SliceAnimation.endToStart) {
                eraseX = eraseX + (blockW * (1.0 - localProgress));
                eraseW = blockW * localProgress;
              }
            } else {
              if (animation == SliceAnimation.startToEnd) {
                eraseH = blockH * localProgress;
              } else if (animation == SliceAnimation.endToStart) {
                eraseY = eraseY + (blockH * (1.0 - localProgress));
                eraseH = blockH * localProgress;
              }
            }

            canvas.drawRect(
              ui.Rect.fromLTWH(eraseX, eraseY, eraseW + 0.5, eraseH + 0.5),
              erasePaint,
            );
          }
        }
      }
    }
  }
}

class ShatterDissolveMask extends DissolveMask {
  int gridSize;
  double shatterOffset;
  double animationDuration;

  List<ui.Path>? _shards;
  List<double>? _generatedGrid;
  Vector2? _lastSize;

  ShatterDissolveMask({
    this.gridSize = 10,
    this.shatterOffset = 0.8,
    this.animationDuration = 0.3,
    super.customNoise,
  });

  List<double> _getOrGenerateGrid(int expectedLength) {
    if (customNoise != null) return customNoise!;
    if (_generatedGrid == null || _generatedGrid!.length != expectedLength) {
      _generatedGrid = List.generate(
        expectedLength,
        (_) => math.Random().nextDouble(),
      );
    }
    return _generatedGrid!;
  }

  void _addShard(Vector2 a, Vector2 b, Vector2 c) {
    final path = ui.Path()
      ..moveTo(a.x, a.y)
      ..lineTo(b.x, b.y)
      ..lineTo(c.x, c.y)
      ..close();
    _shards!.add(path);
  }

  void _buildShards(Vector2 size) {
    if (_shards != null && _lastSize == size) return;
    _lastSize = size;
    _shards = [];

    // 1. Generate perturbed points
    final int pointsX = gridSize + 1;
    final int pointsY = gridSize + 1;

    final blockW = size.x / gridSize;
    final blockH = size.y / gridSize;

    // We use a fixed seed for the shatter geometry so it doesn't jiggle if resized slightly
    final rng = math.Random(1337);

    final points = List.generate(pointsY, (y) {
      return List.generate(pointsX, (x) {
        if (x == 0 || x == gridSize || y == 0 || y == gridSize) {
          return Vector2(x * blockW, y * blockH);
        }

        final offsetX = (rng.nextDouble() - 0.5) * blockW * shatterOffset;
        final offsetY = (rng.nextDouble() - 0.5) * blockH * shatterOffset;

        return Vector2(x * blockW + offsetX, y * blockH + offsetY);
      });
    });

    // 2. Build 2 triangles (shards) per cell
    for (int y = 0; y < gridSize; y++) {
      for (int x = 0; x < gridSize; x++) {
        final p00 = points[y][x];
        final p10 = points[y][x + 1];
        final p01 = points[y + 1][x];
        final p11 = points[y + 1][x + 1];

        if (rng.nextBool()) {
          _addShard(p00, p10, p11);
          _addShard(p00, p11, p01);
        } else {
          _addShard(p00, p10, p01);
          _addShard(p10, p11, p01);
        }
      }
    }
  }

  @override
  void renderMask(
    ui.Canvas canvas,
    ui.Paint erasePaint,
    Vector2 effectiveSize,
    double progress,
    DissolveType type,
    double noiseWeight,
  ) {
    _buildShards(effectiveSize);
    final shardsCount = _shards!.length;
    final grid = _getOrGenerateGrid(shardsCount);

    final blockW = effectiveSize.x / gridSize;
    final blockH = effectiveSize.y / gridSize;

    for (int i = 0; i < shardsCount; i++) {
      final cellIndex = i ~/ 2;
      final cx = cellIndex % gridSize;
      final cy = cellIndex ~/ gridSize;

      final nx = (cx + 0.5) / gridSize;
      final ny = (cy + 0.5) / gridSize;

      final patternValue = getPatternValue(type, nx, ny);
      final noiseValue = grid.isNotEmpty
          ? grid[math.min(i, grid.length - 1)]
          : 0.0;

      final threshold = getThreshold(patternValue, noiseValue, noiseWeight);

      double localProgress =
          (progress - (threshold - animationDuration)) / animationDuration;
      localProgress = localProgress.clamp(0.0, 1.0);

      if (localProgress >= 1.0) {
        // Fully erased
        canvas.drawPath(_shards![i], erasePaint);
      } else if (localProgress > 0.0) {
        // Erase dynamically from the edges inward by using a growing stroke!
        // This gives the visual of the glass shard shrinking to its center.
        final maxSize = math.max(blockW, blockH) * 1.5;
        final currentStroke = maxSize * localProgress;

        final dynamicErase = ui.Paint()
          ..blendMode = ui.BlendMode.dstOut
          ..style = ui.PaintingStyle.stroke
          ..strokeJoin = ui.StrokeJoin.round
          ..strokeWidth = currentStroke;

        canvas.drawPath(_shards![i], dynamicErase);
      }
    }
  }
}

class WaveDissolveMask extends DissolveMask {
  double amplitude;
  double frequency;
  double speed;

  WaveDissolveMask({
    this.amplitude = 12.0,
    this.frequency = 3.0,
    this.speed = 1.0,
    super.customNoise,
  });

  @override
  void renderMask(
    ui.Canvas canvas,
    ui.Paint erasePaint,
    Vector2 effectiveSize,
    double progress,
    DissolveType type,
    double noiseWeight,
  ) {
    if (progress <= 0.0) return;
    if (progress >= 1.0) {
      canvas.drawRect(
        ui.Rect.fromLTWH(0, 0, effectiveSize.x, effectiveSize.y),
        erasePaint,
      );
      return;
    }

    final path = ui.Path();
    final phase = time * speed * math.pi * 2;
    final step = 5.0;

    switch (type) {
      case DissolveType.topDown:
      case DissolveType.bottomUp:
        final bool isTopDown = type == DissolveType.topDown;
        final startY = isTopDown ? 0.0 : effectiveSize.y;
        final baseline = isTopDown
            ? -amplitude + (effectiveSize.y + amplitude * 2) * progress
            : (effectiveSize.y + amplitude) -
                  (effectiveSize.y + amplitude * 2) * progress;

        path.moveTo(0, startY);
        List<ui.Offset> wavePoints = [];
        for (double x = 0; x < effectiveSize.x; x += step) {
          wavePoints.add(ui.Offset(x, 0));
        }
        wavePoints.add(ui.Offset(effectiveSize.x, 0));

        for (int i = 0; i < wavePoints.length; i++) {
          final x = wavePoints[i].dx;
          final nx = x / effectiveSize.x;
          final waveOffset =
              math.sin(nx * frequency * math.pi * 2 + phase) * amplitude;
          final currentNoise = noiseWeight > 0.0
              ? (math.Random().nextDouble() - 0.5) * amplitude * 2 * noiseWeight
              : 0.0;
          final y =
              baseline + (isTopDown ? waveOffset : -waveOffset) + currentNoise;

          path.lineTo(x, y);
        }
        path.lineTo(effectiveSize.x, startY);
        path.close();
        break;

      case DissolveType.leftRight:
      case DissolveType.rightLeft:
        final bool isLeftRight = type == DissolveType.leftRight;
        final startX = isLeftRight ? 0.0 : effectiveSize.x;
        final baseline = isLeftRight
            ? -amplitude + (effectiveSize.x + amplitude * 2) * progress
            : (effectiveSize.x + amplitude) -
                  (effectiveSize.x + amplitude * 2) * progress;

        path.moveTo(startX, 0);
        List<ui.Offset> wavePoints = [];
        for (double y = 0; y < effectiveSize.y; y += step) {
          wavePoints.add(ui.Offset(0, y));
        }
        wavePoints.add(ui.Offset(0, effectiveSize.y));

        for (int i = 0; i < wavePoints.length; i++) {
          final y = wavePoints[i].dy;
          final ny = y / effectiveSize.y;
          final waveOffset =
              math.sin(ny * frequency * math.pi * 2 + phase) * amplitude;
          final currentNoise = noiseWeight > 0.0
              ? (math.Random().nextDouble() - 0.5) * amplitude * 2 * noiseWeight
              : 0.0;
          final x =
              baseline +
              (isLeftRight ? waveOffset : -waveOffset) +
              currentNoise;

          path.lineTo(x, y);
        }
        path.lineTo(startX, effectiveSize.y);
        path.close();
        break;

      case DissolveType.radial:
      case DissolveType.random:
        final center = ui.Offset(effectiveSize.x / 2, effectiveSize.y / 2);
        final maxRadius = math.sqrt(
          math.pow(effectiveSize.x / 2, 2) + math.pow(effectiveSize.y / 2, 2),
        );
        final baseRadius = (maxRadius + amplitude) * progress;

        final lobes = math.max(1, (frequency * 2).round());
        final segments = 60;
        for (int i = 0; i <= segments; i++) {
          final angle = (i / segments) * math.pi * 2;
          final waveOffset = math.sin(angle * lobes + phase) * amplitude;
          final currentNoise = noiseWeight > 0.0
              ? (math.Random().nextDouble() - 0.5) * amplitude * 2 * noiseWeight
              : 0.0;

          final r = math.max(0.0, baseRadius + waveOffset + currentNoise);
          final x = center.dx + math.cos(angle) * r;
          final y = center.dy + math.sin(angle) * r;

          if (i == 0) {
            path.moveTo(x, y);
          } else {
            path.lineTo(x, y);
          }
        }
        path.close();
        break;
    }

    canvas.drawPath(path, erasePaint);
  }
}

class ClipDissolveMask extends DissolveMask {
  final bool clipTop;
  final bool clipBottom;
  final bool clipLeft;
  final bool clipRight;

  ClipDissolveMask({
    this.clipTop = false,
    this.clipBottom = false,
    this.clipLeft = false,
    this.clipRight = false,
  });

  @override
  void renderMask(
    ui.Canvas canvas,
    ui.Paint erasePaint,
    Vector2 effectiveSize,
    double progress,
    DissolveType type,
    double noiseWeight,
  ) {
    if (progress <= 0.0) return;
    if (progress >= 1.0) {
      canvas.drawRect(
        ui.Rect.fromLTWH(0, 0, effectiveSize.x, effectiveSize.y),
        erasePaint,
      );
      return;
    }

    // If both opposing sides are clipping, they should meet in the middle at progress = 1.0
    // so their speed is halved.
    final hSpeed = (clipTop && clipBottom) ? 0.5 : 1.0;
    final vSpeed = (clipLeft && clipRight) ? 0.5 : 1.0;

    final hEdge = effectiveSize.y * progress * hSpeed;
    final vEdge = effectiveSize.x * progress * vSpeed;

    if (clipTop) {
      canvas.drawRect(
        ui.Rect.fromLTWH(0, 0, effectiveSize.x, hEdge + 0.5),
        erasePaint,
      );
    }

    if (clipBottom) {
      canvas.drawRect(
        ui.Rect.fromLTWH(
          0,
          effectiveSize.y - hEdge,
          effectiveSize.x,
          hEdge + 0.5,
        ),
        erasePaint,
      );
    }

    if (clipLeft) {
      canvas.drawRect(
        ui.Rect.fromLTWH(0, 0, vEdge + 0.5, effectiveSize.y),
        erasePaint,
      );
    }

    if (clipRight) {
      canvas.drawRect(
        ui.Rect.fromLTWH(
          effectiveSize.x - vEdge,
          0,
          vEdge + 0.5,
          effectiveSize.y,
        ),
        erasePaint,
      );
    }
  }
}

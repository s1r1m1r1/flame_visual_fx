import 'dart:math' as math;
import 'dart:ui';
import 'package:flame/components.dart';
import 'package:flame/rendering.dart';

/// A [Decorator] that organically dissolves (erases) the character from bottom to top
/// or top to bottom over time, using a mathematical wave/noise pattern to create
/// a "teleportation" or "disintegration" effect!
class DissolveDecorator extends Decorator {
  DissolveDecorator({
    required this.component,
    this.duration = 2.0, // Seconds to fully dissolve
    this.isActive = true,
    this.gridSize = 25,
    this.loop = true,
  });

  final PositionComponent component;
  double duration;
  bool isActive;
  int gridSize;
  bool loop;

  double _time = 0.0;
  final math.Random _random = math.Random();

  // A pre-calculated grid of random noise values to act as our "mask texture"
  List<double>? _noiseGrid;
  int? _lastGridSize;

  void _initNoise() {
    if (_noiseGrid != null && _lastGridSize == gridSize) return;
    _noiseGrid = List.generate(
      gridSize * gridSize,
      (_) => _random.nextDouble(),
    );
    _lastGridSize = gridSize;
  }

  /// Resets the dissolve effect to the beginning
  void reset() {
    _time = 0.0;
  }

  void update(double dt) {
    if (!isActive) return;

    _initNoise();

    _time += dt;

    // Optional: Stop at end of duration if not looping
    if (!loop && _time >= duration) {
      _time = duration;
    } else if (loop && _time > duration + 0.5) {
      _time = 0.0; // Reset after a small pause
    }
  }

  @override
  void apply(void Function(Canvas) draw, Canvas canvas) {
    if (!isActive) {
      draw(canvas);
      return;
    }

    _initNoise();

    final size = component.size;
    if (size.x <= 0 || size.y <= 0) {
      draw(canvas);
      return;
    }

    // Calculate how far the dissolve has progressed (0.0 to 1.0)
    final progress = (_time / duration).clamp(0.0, 1.0);

    // 1. Save an isolated layer where we will draw the original character FIRST
    canvas.saveLayer(null, Paint());
    draw(canvas); // The intact character is now painted on this layer

    // 2. We now create an "Erasing" brush using BlendMode.dstOut!
    final eraserPaint = Paint()
      ..color = const Color(0xFF000000)
      ..blendMode = BlendMode.dstOut;

    // 3. Draw a procedural noise pattern over the character to erase them chunk by chunk
    final cellWidth = size.x / gridSize;
    final cellHeight = size.y / gridSize;

    // IMPORTANT: Flame's Decorator canvas is already translated to the component's top-left
    // (due to anchor translation being part of the component's transform).
    // So the sprite is drawn from (0,0) to (size.x, size.y).
    for (int y = 0; y < gridSize; y++) {
      for (int x = 0; x < gridSize; x++) {
        // Position of this cell relative to the top of the sprite
        final normalizedY = y / gridSize;

        // Fetch pre-calculated noise for this block
        final noiseValue = _noiseGrid![y * gridSize + x];

        // Logic: if progress >= the threshold, erase this cell.
        if (progress >= (normalizedY * 0.7 + noiseValue * 0.3)) {
          canvas.drawRect(
            Rect.fromLTWH(
              x * cellWidth,
              y * cellHeight,
              cellWidth,
              cellHeight,
            ),
            eraserPaint,
          );
        }
      }
    }

    // 4. Flatten the layer back to the main canvas.
    canvas.restore();
  }
}

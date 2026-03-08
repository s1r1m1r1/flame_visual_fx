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
    this.isActive = true,
    this.gridSize = 25,
    this.showResidualEffect = false,
    this.progress = 0.0,
  });

  final PositionComponent component;
  bool isActive;
  int gridSize;

  /// If true, a faint "residual" silhouette might remain after dissolution.
  /// If false (default), the component is completely hidden at the end of duration.
  bool showResidualEffect;

  /// Current progress of the dissolve effect (0.0 to 1.0).
  double progress;

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
    progress = 0.0;
  }

  void update(double dt) {
    super.update(dt);
    if (!isActive) return;
    _initNoise();
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
    final currentProgress = progress.clamp(0.0, 1.0);

    // If we want a clean finish and we've reached the end, just stop drawing
    if (currentProgress >= 1.0 && !showResidualEffect) {
      return;
    }

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
        if (currentProgress >= (normalizedY * 0.7 + noiseValue * 0.3)) {
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

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
  });

  final PositionComponent component;
  double duration;
  bool isActive;

  double _time = 0.0;
  final math.Random _random = math.Random();

  // A pre-calculated grid of random noise values to act as our "mask texture"
  late final List<double> _noiseGrid;
  final int _gridSize = 25;

  bool _isInit = false;

  void _initNoise() {
    if (_isInit) return;
    _noiseGrid = List.generate(
      _gridSize * _gridSize,
      (_) => _random.nextDouble(),
    );
    _isInit = true;
  }

  void update(double dt) {
    if (!isActive) return;

    _initNoise();

    _time += dt;

    // Loop the animation
    if (_time > duration + 0.5) {
      _time = 0.0; // Reset after a small pause
    }
  }

  @override
  void apply(void Function(Canvas) draw, Canvas canvas) {
    if (!isActive) {
      draw(canvas);
      return;
    }

    _initNoise(); // Ensure noise generation is safely bootstrapped even if apply() runs before update()

    final size = component.size;
    if (size.x <= 0 || size.y <= 0) {
      draw(canvas);
      return;
    }

    final bounds = Rect.fromLTWH(0, 0, size.x, size.y);

    // Calculate how far the dissolve has progressed (0.0 to 1.0)
    final progress = (_time / duration).clamp(0.0, 1.0);

    // 1. Save an isolated layer where we will draw the original character FIRST
    canvas.saveLayer(bounds, Paint());
    draw(canvas); // The intact character is now painted on this layer

    // 2. We now create an "Erasing" brush using BlendMode.dstOut!
    // Anything drawn with dstOut will PUNCH A HOLE right through the layer we just saved.
    final eraserPaint = Paint()
      ..color = const Color(0xFF000000)
      ..blendMode = BlendMode.dstOut;

    // 3. Draw a procedural noise pattern over the character to erase them chunk by chunk
    final cellWidth = size.x / _gridSize;
    final cellHeight = size.y / _gridSize;

    for (int y = 0; y < _gridSize; y++) {
      for (int x = 0; x < _gridSize; x++) {
        // We make the dissolve happen from Top to Bottom
        // by weighting the progress against the Y coordinate
        final normalizedY = y / _gridSize;

        // This math equation combines the noise, the Y position, and time progressing.
        final noiseValue = _noiseGrid[y * _gridSize + x];

        // If the dissolve progress wave has reached this pixel block, erase it!
        // The noiseValue makes it jagged and random like disintegration!
        if (progress > normalizedY * 0.5 + noiseValue * 0.5) {
          canvas.drawRect(
            Rect.fromLTWH(x * cellWidth, y * cellHeight, cellWidth, cellHeight),
            eraserPaint,
          );
        }
      }
    }

    // 4. Flatten the layer back to the main canvas.
    // All the chunks we punched out will be completely transparent!
    canvas.restore();
  }
}

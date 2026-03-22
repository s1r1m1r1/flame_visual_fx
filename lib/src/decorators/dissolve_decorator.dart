import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flame/components.dart';
import 'package:flame/rendering.dart';

enum DissolveType { random, topDown, bottomUp, leftRight, rightLeft, radial }

/// A [Decorator] that organically dissolves (erases) the character.
/// It uses a pre-calculated noise pattern to create a "teleportation"
/// or "disintegration" effect. Animation is driven by the [progress] parameter.
class DissolveDecorator extends Decorator {
  DissolveDecorator({
    required this.component,
    this.isActive = true,
    int gridSize = 25,
    this.showResidualEffect = false,
    this.progress = 0.0,
    this.noiseGrid,
    this.type = DissolveType.radial,
    this.noiseWeight = 0.3,
    Vector2? visualOffset,
    Vector2? visualScale,
    Vector2? visualAnchor,
    this.renderSize,
  }) : _gridSize = gridSize,
       visualOffset = visualOffset ?? Vector2.zero(),
       visualScale = visualScale ?? Vector2.all(1.0),
       visualAnchor = visualAnchor ?? Vector2.zero();

  @override
  void update(double dt) {
    super.update(dt);
  }

  final PositionComponent component;
  bool isActive;

  int get gridSize => _gridSize;
  set gridSize(int value) {
    if (_gridSize != value) {
      _gridSize = value;
      _generatedGrid = null; // Invalidate cache!
    }
  }

  int _gridSize;

  /// The pattern strategy to use for dissolution.
  DissolveType type;

  /// How much the noise influences the edge.
  /// 0.0 for a clean line, 1.0 for a very fuzzy/random edge.
  double noiseWeight;

  /// If true, a faint "residual" silhouette might remain after dissolution.
  /// If false (default), the component is completely hidden at the end of duration.
  bool showResidualEffect;

  /// Current progress of the dissolve effect (0.0 to 1.0).
  double progress;

  /// A pre-calculated grid of random noise values to act as our "mask texture".
  /// If null, a default static grid will be used (though it won't be dynamic).
  List<double>? noiseGrid;

  /// Local offset of the visuals relative to the component origin.
  Vector2 visualOffset;

  /// Local scale of the visuals relative to the component origin.
  Vector2 visualScale;

  /// Local target-specific anchor offset (in logical pixels).
  Vector2 visualAnchor;

  /// Optional override for the size of the erasure area.
  /// If null, the component's logical size is used.
  Vector2? renderSize;

  @override
  void apply(void Function(ui.Canvas) draw, ui.Canvas canvas) {
    if (!isActive || progress <= 0) {
      draw(canvas);
      return;
    }

    if (progress >= 1.0) {
      if (showResidualEffect) {
        // Draw the ghostly remains
        final paint = ui.Paint()
          ..colorFilter = const ui.ColorFilter.matrix([
            0.2126,
            0.7152,
            0.0722,
            0,
            0,
            0.2126,
            0.7152,
            0.0722,
            0,
            0,
            0.2126,
            0.7152,
            0.0722,
            0,
            0,
            0,
            0,
            0,
            0.3,
            0,
          ]);
        canvas.saveLayer(null, paint);
        draw(canvas);
        canvas.restore();
      }
      return;
    }

    // --- Progressive Dissolve Logic ---
    final grid = _getOrGenerateGrid();
    final currentGridSize = _gridSize;

    // Use current component size for block calculation.
    // Decorators are relative to the component bounds.
    final effectiveSize = renderSize ?? component.size;
    final double blockW = effectiveSize.x / currentGridSize;
    final double blockH = effectiveSize.y / currentGridSize;

    // 1. Save an isolated layer where we will draw the original FIRST
    canvas.saveLayer(null, ui.Paint());
    draw(canvas); // The intact component is now painted on this layer

    // 2. Erase blocks based on progress and noise
    final erasePaint = ui.Paint()..blendMode = ui.BlendMode.dstOut;
    final edgeWeight = 1.0 - noiseWeight;

    canvas.save();
    canvas.translate(visualOffset.x, visualOffset.y);
    canvas.scale(visualScale.x, visualScale.y);
    canvas.translate(visualAnchor.x, visualAnchor.y);

    for (int y = 0; y < currentGridSize; y++) {
      for (int x = 0; x < currentGridSize; x++) {
        final nx = (x + 0.5) / currentGridSize;
        final ny = (y + 0.5) / currentGridSize;

        // Pattern logic
        final double patternValue = switch (type) {
          DissolveType.random => 0.0,
          DissolveType.topDown => ny,
          DissolveType.bottomUp => 1.0 - ny,
          DissolveType.leftRight => nx,
          DissolveType.rightLeft => 1.0 - nx,
          DissolveType.radial =>
            math.sqrt(math.pow(nx - 0.5, 2) + math.pow(ny - 0.5, 2)) * 1.414,
        };

        // Fetch pre-calculated noise for this block
        final noiseValue = grid[y * currentGridSize + x];

        // Logic: mix the pattern and noise
        final threshold =
            (patternValue * edgeWeight) + (noiseValue * noiseWeight);

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

    canvas.restore(); // Restore local transform
    canvas.restore(); // Restore layer
  }

  /// Internal helper to get either the user-provided noise grid or the cached procedural one.
  List<double> _getOrGenerateGrid() {
    if (noiseGrid != null) return noiseGrid!;
    if (_generatedGrid == null ||
        _generatedGrid!.length != _gridSize * _gridSize) {
      _generatedGrid = List.generate(
        _gridSize * _gridSize,
        (_) => math.Random().nextDouble(),
      );
    }
    return _generatedGrid!;
  }

  /// Internal cache for the generated noise grid.
  List<double>? _generatedGrid;

  /// Utility to create a noise grid from a grayscale image.
  static Future<List<double>> computeNoiseFromImage(ui.Image image) async {
    final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (byteData == null) return [];

    final int width = image.width;
    final int height = image.height;
    final List<double> noise = List.filled(width * height, 0.0);

    for (int i = 0; i < width * height; i++) {
      final r = byteData.getUint8(i * 4);
      final g = byteData.getUint8(i * 4 + 1);
      final b = byteData.getUint8(i * 4 + 2);
      // Simple average for gray value
      noise[i] = (r + g + b) / (3.0 * 255.0);
    }
    return noise;
  }
}

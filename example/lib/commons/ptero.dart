import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flame_visual_fx/flame_visual_fx.dart';

class Ptero<T extends FlameGame> extends SpriteAnimationComponent
    with HasGameReference<T> {
  static final Map<String, Future<List<List<Vector2>>>> _contourCache = {};

  Ptero({super.position, Vector2? size, super.priority, super.key})
      : super(
          size: size ?? Vector2(150, 100),
          anchor: Anchor.center,
        );

  List<List<Vector2>>? _allContours;
  int _lastFrameIndex = -1;

  /// Returns the contour for the current frame if available.
  List<Vector2>? get currentContour {
    final cur = animationTicker?.currentIndex;
    if (cur == null || _allContours == null) return null;
    return _allContours![cur % _allContours!.length];
  }

  /// Compatibility getter for existing decorators that expect a single list
  List<Vector2>? get contourVertices => currentContour;

  @override
  Future<void> onLoad() async {
    final spriteAnimation = await game.loadSpriteAnimation(
      'animations/bomb_ptero.png',
      SpriteAnimationData.sequenced(
        amount: 4,
        textureSize: Vector2(48, 32),
        stepTime: 0.15,
      ),
    );
    animation = spriteAnimation;

    final cacheKey = 'bomb_ptero_${size.x.toInt()}_${size.y.toInt()}';

    // Use Future-based cache to avoid redundant processing
    _allContours = await _contourCache.putIfAbsent(cacheKey, () async {
      final List<List<Vector2>> contours = [];
      for (final frame in spriteAnimation.frames) {
        final sprite = frame.sprite;
        final rawVertices = await ContourFinder.findContour(
          sprite.image,
          detail: 2,
          source: sprite.src,
        );

        final scaleX = size.x / sprite.src.width;
        final scaleY = size.y / sprite.src.height;
        final scaled = rawVertices
            .map((v) => Vector2(v.x * scaleX, v.y * scaleY))
            .toList();
        contours.add(scaled);
      }
      return contours;
    });

    _syncDecorator();
  }

  @override
  void update(double dt) {
    super.update(dt);

    decorator.update(dt);

    final currentIndex = animationTicker?.currentIndex ?? 0;
    if (currentIndex != _lastFrameIndex) {
      _lastFrameIndex = currentIndex;
      _syncDecorator();
    }
  }

  void _syncDecorator() {
    final vertices = currentContour;
    if (vertices == null) return;

    final dec = decorator;
    final outline = dec.find<OutlineDecorator>();
    if (outline != null) {
      outline.vertices = vertices;
      final currentIndex = animationTicker?.currentIndex;
      if (currentIndex != null) {
        outline.cacheKey = 'ptero_outline_${size.x}_${size.y}_$currentIndex';
      }
    }
    dec.find<PolygonOutlineDecorator>()?.vertices = vertices;
    dec.find<PolygonAuraDecorator>()?.vertices = vertices;
    dec.find<PolygonSnakeDecorator>()?.vertices = vertices;
    dec.find<PolygonEchoDecorator>()?.vertices = vertices;
    dec.find<PolygonScanDecorator>()?.vertices = vertices;
    dec.find<PolygonParticleDecorator>()?.vertices = vertices;
    dec.find<PolygonShieldDecorator>()?.vertices = vertices;
    dec.find<PolygonArcDecorator>()?.vertices = vertices;
    dec.find<PolygonFireDecorator>()?.vertices = vertices;
    dec.find<PolygonWhirlDecorator>()?.vertices = vertices;
  }
}

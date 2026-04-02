import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flame_visual_fx/flame_visual_fx.dart';
import 'package:flame_unified_real_time/flame_unified_real_time.dart';

class Ptero<T extends FlameGame> extends SpriteAnimationComponent
    with HasGameReference<T> {
  static final Map<String, Future<List<List<Vector2>>>> _contourCache = {};

  Ptero({super.position, Vector2? size, super.priority, super.key})
    : super(size: size ?? Vector2(150, 100), anchor: Anchor.center);

  List<List<Vector2>>? _allContours;
  int _lastFrameIndex = -1;

  // --- STATE FOR PURE DECORATORS (SSA) ---
  final List<List<Vector2>> _echoHistory = [];
  final List<FireParticle> _fireParticles = [];
  final List<WhirlParticle> _whirlParticles = [];
  final List<SimpleParticle> _simpleParticles = [];
  final List<List<ui.Offset>> _activeArcs = [];
  final List<ui.Offset> _contactPoints = [];
  List<double>? _dissolveNoise;
  double _arcJumpTimer = 0;
  double _particleSpawnAccumulator = 0;
  final math.Random _random = math.Random();

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

    _updatePureDecoratorState(dt);
    _syncPureParameters();
  }

  void _updatePureDecoratorState(double dt) {
    final gameTime = game.currentTime();
    final vertices = currentContour;
    if (vertices == null) return;

    // 1. Echo History
    if (gameTime % 0.05 < dt) {
      // Capture snapshot every 50ms
      _echoHistory.insert(0, List.from(vertices));
      if (_echoHistory.length > 10) _echoHistory.removeLast();
    }

    // 2. Fire Particles
    for (int i = _fireParticles.length - 1; i >= 0; i--) {
      final p = _fireParticles[i];
      p.lifetime += dt;
      if (p.lifetime >= p.maxLifetime) {
        _fireParticles.removeAt(i);
        continue;
      }
      p.position += p.velocity * dt;
      p.velocity.x += (_random.nextDouble() - 0.5) * 10;
    }

    // 3. Whirl Particles
    final center =
        vertices.reduce((a, b) => a + b) / vertices.length.toDouble();
    for (int i = _whirlParticles.length - 1; i >= 0; i--) {
      final p = _whirlParticles[i];
      p.lifetime += dt;
      if (p.lifetime >= p.maxLifetime) {
        _whirlParticles.removeAt(i);
        continue;
      }
      p.angle += 2.0 * dt;
      p.radius *= (1.0 - 0.4 * dt);
      p.position = Vector2(
        center.x + math.cos(p.angle) * p.radius,
        center.y + math.sin(p.angle) * p.radius,
      );
    }

    // 4. Simple Particles
    for (int i = _simpleParticles.length - 1; i >= 0; i--) {
      final p = _simpleParticles[i];
      p.life -= dt;
      if (p.life <= 0) {
        _simpleParticles.removeAt(i);
        continue;
      }
      p.position += p.velocity * dt;
    }

    // 5. Arcs (Jumping)
    _arcJumpTimer += dt;
    if (_arcJumpTimer >= 0.1) {
      _arcJumpTimer = 0;
      _activeArcs.clear();
      _contactPoints.clear();
      if (vertices.length >= 2) {
        for (int i = 0; i < 3; i++) {
          final idx1 = _random.nextInt(vertices.length);
          final idx2 = _random.nextInt(vertices.length);
          final start = vertices[idx1].toOffset();
          final end = vertices[idx2].toOffset();
          _contactPoints.add(start);
          _activeArcs.add([
            start,
            (start + end) / 2 + const ui.Offset(0, -20),
            end,
          ]);
        }
      }
    }

    // 6. Spawn Particles (Rate limited)
    _particleSpawnAccumulator += dt * 50;
    while (_particleSpawnAccumulator >= 1.0) {
      _particleSpawnAccumulator -= 1.0;
      final v = vertices[_random.nextInt(vertices.length)];
      _fireParticles.add(
        FireParticle(
          position: v.clone(),
          velocity: Vector2((_random.nextDouble() - 0.5) * 10, -40),
          maxLifetime: 0.8,
        ),
      );
      _simpleParticles.add(
        SimpleParticle(
          position: v.clone(),
          velocity: Vector2(0, -20),
          maxLife: 1.0,
        ),
      );
    }
  }

  void _syncPureParameters() {
    final dec = decorator;
    final gameTime = game.currentTime();

    // Pulse
    final pulse = (math.sin(gameTime * 6) + 1) / 2;
    dec.find<PulseOutlineDecorator>()?.thickness = 2.0 + pulse * 4.0;
    dec.find<WaveDecorator>()?.phase = gameTime * 4.0;

    // Hologram
    final holo = dec.find<HologramDecorator>();
    if (holo != null) {
      holo.splitOffset = 2.0 + math.sin(gameTime * 15).abs() * 3.0;
      holo.jitterY = _random.nextDouble() * 2.0;
    }

    // Dissolve
    final diss = dec.find<DissolveDecorator>();
    if (diss != null) {
      diss.progress = (gameTime * 0.5) % 1.2;
      diss.mask.customNoise ??= List.generate(
        25 * 25,
        (_) => _random.nextDouble(),
      );
    }

    // Shader Dissolve
    final shaderDiss = dec.find<ShaderDissolveDecorator>();
    if (shaderDiss != null) {
      final sprite = animationTicker!.getSprite();
      shaderDiss.image = sprite.image;
      shaderDiss.sourceRect = sprite.src;

      if (shaderDiss.autoAnimate) {
        // ONLY animate if autoAnimate is true in the DECORATOR itself.
        shaderDiss.progress = (gameTime * 0.25) % 1.2;
      }
    }

    // Polygon Parameters
    dec.find<PolygonAuraDecorator>()?.pulse = pulse;
    dec.find<PolygonScanDecorator>()?.progress = (gameTime * 0.8) % 1.0;
    dec.find<PolygonSnakeDecorator>()?.progress = (gameTime * 1.2) % 1.0;
    dec.find<PolygonShieldDecorator>()?.progress = gameTime;

    // Stateful Polygon Injectors
    final echo = dec.find<PolygonEchoDecorator>();
    if (echo != null) echo.history = _echoHistory;

    final arc = dec.find<PolygonArcDecorator>();
    if (arc != null) {
      arc.activeArcs = _activeArcs;
      arc.contactPoints = _contactPoints;
    }

    final fire = dec.find<PolygonFireDecorator>();
    if (fire != null) fire.particles = _fireParticles;

    final whirl = dec.find<PolygonWhirlDecorator>();
    if (whirl != null) whirl.particles = _whirlParticles;

    final part = dec.find<PolygonParticleDecorator>();
    if (part != null) part.particles = _simpleParticles;
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

    dec.find<ShaderOutlineDecorator>()
      ?..cacheKey = (animationTicker?.currentIndex != null)
          ? 'ptero_outline_${size.x}_${size.y}_${animationTicker!.currentIndex}'
          : null
      ..invalidate();

    final neon = dec.find<NeonGlowDecorator>();
    if (neon != null) {
      final gameTime = game.currentTime();
      // Synchronized pulse across all Pteros for massive cache hits
      const double baseRadius = 8.0;
      const double amplitude = 4.0;
      const double speed = 6.0;
      neon.radius = baseRadius + math.sin(gameTime * speed) * amplitude;

      final currentIndex = animationTicker?.currentIndex;
      if (currentIndex != null) {
        neon.cacheKey = 'ptero_neon_${size.x}_${size.y}_$currentIndex';
      }
    }

    final hueDec = dec.find<HueDecorator>();
    if (hueDec != null) {
      hueDec.hue = (game.currentTime() * 2) % (2 * math.pi);
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

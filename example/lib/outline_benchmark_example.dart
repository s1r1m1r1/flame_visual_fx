import 'dart:math';
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flame_visual_fx/flame_visual_fx.dart';
import 'package:composite_atlas/composite_atlas.dart';
import 'package:flutter/material.dart' hide Image;
import 'commons/ptero.dart';

void main() {
  runApp(
    const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: OutlineBenchmarkScreen(),
    ),
  );
}

class OutlineBenchmark extends FlameGame {
  OutlineBenchmark() : super(world: BenchmarkWorld());

  final pteroSize = Vector2.all(64);
  late final TextComponent counter;
  final Random random = Random();

  int _currentEffectIndex = 0;
  SpriteAnimation? _bakedAnimation;
  SpriteAnimation? _defaultAnimation;

  final List<MapEntry<String, void Function(Ptero)?>> effects = [];

  String get currentEffectName =>
      effects.isEmpty ? 'Loading...' : effects[_currentEffectIndex].key;
  void Function(Ptero)? get effectApplier =>
      effects.isEmpty ? null : effects[_currentEffectIndex].value;

  @override
  Future<void> onLoad() async {
    effects.addAll([
      const MapEntry('None (Original)', null),
      MapEntry(
        'Outline Decorator (CPU)',
        (Ptero p) => p.decorator.addLast(
          OutlineDecorator(
            component: p,
            vertices: p.contourVertices,
            thickness: 3,
          ),
        ),
      ),
      MapEntry(
        'Pure Outline Decorator (Canvas)',
        (Ptero p) => p.decorator.addLast(
          PureOutlineDecorator(thickness: 3, color: Colors.pink),
        ),
      ),
      MapEntry(
        'Polygon Outline (Vertices)',
        (Ptero p) => p.decorator.addLast(
          PolygonOutlineDecorator(
            vertices: p.contourVertices ?? [],
            thickness: 3,
          ),
        ),
      ),
      MapEntry('Baked Shader Outline (Atlas)', (Ptero p) {
        if (_bakedAnimation != null) {
          p.animation = _bakedAnimation;
        }
      }),
    ]);

    await _initBakedAtlas();

    camera.viewfinder.anchor = Anchor.center;

    await camera.viewport.addAll([
      FpsTextComponent(position: Vector2(10, 10), anchor: Anchor.topLeft),
      counter = TextComponent(
        position: Vector2(10, 40),
        anchor: Anchor.topLeft,
        priority: 1,
      ),
    ]);
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (effects.isEmpty) return;

    counter.text =
        'Sprites: ${world.children.query<Ptero>().length}\nEffect: $currentEffectName';
  }

  void nextEffect() {
    if (effects.isEmpty) return;
    _currentEffectIndex = (_currentEffectIndex + 1) % effects.length;
    _applyCurrentEffect();
  }

  void prevEffect() {
    if (effects.isEmpty) return;
    _currentEffectIndex =
        (_currentEffectIndex - 1 + effects.length) % effects.length;
    _applyCurrentEffect();
  }

  void _applyCurrentEffect() {
    world.removeAll(world.children.query<Ptero>());
    OutlineDecorator.clearCache();
  }

  Future<void> _initBakedAtlas() async {
    // 1. Load the original animation to use its sprites
    _defaultAnimation = await loadSpriteAnimation(
      'animations/bomb_ptero.png',
      SpriteAnimationData.sequenced(
        amount: 4,
        textureSize: Vector2(48, 32),
        stepTime: 0.15,
      ),
    );

    // 2. Prepare the shader outline
    final outline = await ShaderOutlineDecorator.load(
      color: Colors.red,
      thickness: 3.0,
    );

    // 3. Bake into a CompositeAtlas
    final atlas = await CompositeAtlas.bake([
      // We can't pass the animation directly to bake,
      // but we can pass SpriteBakeRequest for each frame!
      ..._defaultAnimation!.frames.asMap().entries.map((e) {
        return SpriteBakeRequest(
          e.value.sprite,
          name: 'ptero_${e.key}',
          decorator: outline,
        );
      }),
    ]);

    // 4. Extract the baked animation
    _bakedAnimation = SpriteAnimation.spriteList(
      List.generate(4, (i) => atlas.findSpriteByName('ptero_$i')!),
      stepTime: 0.15,
    );
  }

  void addSprites(int count) {
    if (effects.isEmpty) return;

    const width = 800.0;
    const height = 800.0;

    world.addAll(
      List.generate(count, (_) {
        final isBaked = currentEffectName == 'Baked Shader Outline (Atlas)';
        final ptero = Ptero(
          size: pteroSize,
          position: Vector2(
            (random.nextDouble() - 0.5) * width,
            (random.nextDouble() - 0.5) * height,
          ),
          animation: isBaked ? _bakedAnimation : _defaultAnimation,
        );

        effectApplier?.call(ptero);
        return ptero;
      }),
    );
  }
}

class BenchmarkWorld extends World with HasGameReference<OutlineBenchmark> {}

class OutlineBenchmarkScreen extends StatefulWidget {
  const OutlineBenchmarkScreen({super.key});

  @override
  State<OutlineBenchmarkScreen> createState() => _OutlineBenchmarkScreenState();
}

class _OutlineBenchmarkScreenState extends State<OutlineBenchmarkScreen> {
  late final OutlineBenchmark game;

  @override
  void initState() {
    super.initState();
    game = OutlineBenchmark();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          GameWidget(game: game),
          Positioned(
            bottom: 20,
            left: 20,
            right: 20,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildAddButton(1),
                    const SizedBox(width: 10),
                    _buildAddButton(50),
                    const SizedBox(width: 10),
                    _buildAddButton(100),
                    const SizedBox(width: 10),
                    _buildAddButton(500, color: Colors.orange.shade800),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton.filled(
                      onPressed: () => setState(() => game.prevEffect()),
                      icon: const Icon(Icons.arrow_back_ios_new),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: Text(
                        game.currentEffectName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton.filled(
                      onPressed: () => setState(() => game.nextEffect()),
                      icon: const Icon(Icons.arrow_forward_ios),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Back to Gallery'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddButton(int count, {Color? color}) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: color ?? Colors.blueGrey.shade800,
        foregroundColor: Colors.white,
      ),
      onPressed: () => setState(() => game.addSprites(count)),
      child: Text('Add $count'),
    );
  }
}

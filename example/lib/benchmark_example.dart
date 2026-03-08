import 'dart:math';

import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flame/game.dart';
import 'package:flame_visual_fx/flame_visual_fx.dart';
import 'package:flutter/material.dart' hide Image;
import 'commons/ptero.dart';

void main() {
  runApp(
    const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: BenchmarkScreen(),
    ),
  );
}

class VisualFXBenchmark extends FlameGame {
  VisualFXBenchmark() : super(world: BenchmarkWorld());

  final pteroSize = Vector2.all(40);
  late final TextComponent counter;
  final Random random = Random();

  int _currentEffectIndex = 0;

  final List<MapEntry<String, void Function(Ptero)?>> effects = [
    MapEntry(
        'FastHueEffect (Paint)',
        (Ptero p) => p.add(FastHueEffect(
              2 * pi,
              InfiniteEffectController(LinearEffectController(3)),
            ))),
    MapEntry(
        'FastFlashEffect (Paint)',
        (Ptero p) => p.add(FastFlashEffect(
              Colors.white,
              InfiniteEffectController(LinearEffectController(1.0)),
            ))),
    MapEntry('None', null),
    MapEntry(
        'Outline Decorator',
        (Ptero p) => p.decorator.addLast(OutlineDecorator(
            component: p, vertices: p.contourVertices, thickness: 3))),
    MapEntry(
        'Polygon Outline Decorator',
        (Ptero p) => p.decorator.addLast(PolygonOutlineDecorator(
            vertices: p.contourVertices ?? [], thickness: 3))),
    MapEntry(
        'Aura Decorator',
        (Ptero p) => p.decorator
            .addLast(PolygonAuraDecorator(vertices: p.contourVertices ?? []))),
    MapEntry(
        'Scanline Decorator',
        (Ptero p) => p.decorator
            .addLast(PolygonScanDecorator(vertices: p.contourVertices ?? []))),
    MapEntry(
        'Fire Decorator',
        (Ptero p) => p.decorator
            .addLast(PolygonFireDecorator(vertices: p.contourVertices ?? []))),
    MapEntry(
        'Whirl Decorator',
        (Ptero p) => p.decorator
            .addLast(PolygonWhirlDecorator(vertices: p.contourVertices ?? []))),
    MapEntry(
        'Hue Decorator',
        (Ptero p) => p.decorator.addLast(HueDecorator(
              component: p,
            ))),
    MapEntry(
        'Flash Decorator',
        (Ptero p) => p.decorator.addLast(DamageFlashDecorator(
              color: Colors.white,
              duration: 1.0,
              isActive: true,
            )..flash())),
    MapEntry(
        'Neon Glow Decorator',
        (Ptero p) => p.decorator.addLast(NeonGlowDecorator(
              component: p,
              radius: 8,
            ))),
  ];

  String get currentEffectName => effects[_currentEffectIndex].key;
  void Function(Ptero)? get effectApplier => effects[_currentEffectIndex].value;

  @override
  Future<void> onLoad() async {
    camera.viewfinder.anchor = Anchor.center;

    await camera.viewport.addAll([
      FpsTextComponent(
        position: Vector2(10, 10),
        anchor: Anchor.topLeft,
      ),
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
    counter.text =
        'Sprites: ${world.children.query<Ptero>().length}\nEffect: $currentEffectName';
  }

  void nextEffect() {
    _currentEffectIndex = (_currentEffectIndex + 1) % effects.length;
    _applyCurrentEffect();
  }

  void prevEffect() {
    _currentEffectIndex =
        (_currentEffectIndex - 1 + effects.length) % effects.length;
    _applyCurrentEffect();
  }

  void _applyCurrentEffect() {
    world.removeAll(world.children.query<Ptero>());
  }

  void addSprites(int count) {
    const width = 800.0;
    const height = 800.0;

    world.addAll(
      List.generate(
        count,
        (_) {
          final ptero = Ptero(
            size: pteroSize,
            position: Vector2(
              (random.nextDouble() - 0.5) * width,
              (random.nextDouble() - 0.5) * height,
            ),
          );
          effectApplier?.call(ptero);
          return ptero;
        },
      ),
    );
  }
}

class BenchmarkWorld extends World with HasGameReference<VisualFXBenchmark> {}

class BenchmarkScreen extends StatefulWidget {
  const BenchmarkScreen({super.key});

  @override
  State<BenchmarkScreen> createState() => _BenchmarkScreenState();
}

class _BenchmarkScreenState extends State<BenchmarkScreen> {
  late final VisualFXBenchmark game;

  @override
  void initState() {
    super.initState();
    game = VisualFXBenchmark();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          GameWidget(game: game),
          // Bottom Controls
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
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blueGrey.shade800,
                          foregroundColor: Colors.white),
                      onPressed: () => setState(() => game.addSprites(1)),
                      child: const Text('Add 1'),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blueGrey.shade800,
                          foregroundColor: Colors.white),
                      onPressed: () => setState(() => game.addSprites(50)),
                      child: const Text('Add 50'),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blueGrey.shade800,
                          foregroundColor: Colors.white),
                      onPressed: () => setState(() => game.addSprites(100)),
                      child: const Text('Add 100'),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange.shade800,
                          foregroundColor: Colors.white),
                      onPressed: () => setState(() => game.addSprites(500)),
                      child: const Text('Add 500'),
                    ),
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
                          horizontal: 20, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: Text(
                        game.currentEffectName,
                        style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold),
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
}

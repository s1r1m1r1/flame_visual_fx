import 'dart:math' as math;
import 'package:flame/game.dart';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/rendering.dart';
import 'package:flame_visual_fx/flame_visual_fx.dart';
import 'package:flutter/material.dart';

import 'commons/ptero.dart';

void main() {
  runApp(
    GameWidget(
      game: DecoratorExample(),
    ),
  );
}

class DecoratorExample extends FlameGame {
  @override
  Color backgroundColor() => const Color(0xFF1A1A1A);

  @override
  Future<void> onLoad() async {
    final cellWidth = size.x / 3;
    final cellHeight = size.y / 3;

    final decoratorData = [
      (name: 'Original', factory: (Ptero e) => null, onTap: null),
      (
        name: 'Pulse Outline',
        factory: (Ptero e) => PulseOutlineDecorator(
            component: e,
            baseThickness: 2.0,
            pulseAmplitude: 4.0,
            pulseSpeed: 5.0,
            margin: 0.0,
            isActive: true),
        onTap: null
      ),
      (
        name: 'Outline',
        factory: (Ptero e) => OutlineDecorator(component: e),
        onTap: null
      ),
      (
        name: 'Neon Glow',
        factory: (Ptero e) => NeonGlowDecorator(component: e),
        onTap: null
      ),
      (
        name: 'Hologram',
        factory: (Ptero e) => HologramDecorator(component: e),
        onTap: null
      ),
      (
        name: 'Dissolve\n(Tap to cycle grid)',
        factory: (Ptero e) => DissolveDecorator(component: e)..loop = false,
        onTap: (dec) {
          if (dec is DissolveDecorator) {
            // Cycle grid size: 10 -> 25 -> 50 -> 100 -> 10
            if (dec.gridSize == 10) {
              dec.gridSize = 25;
            } else if (dec.gridSize == 25) {
              dec.gridSize = 50;
            } else if (dec.gridSize == 50) {
              dec.gridSize = 100;
            } else {
              dec.gridSize = 10;
            }
            dec.reset();
          }
        }
      ),
      (
        name: 'Damage Flash\n(Tap to Flash)',
        factory: (Ptero e) => DamageFlashDecorator(),
        onTap: (dec) {
          if (dec is DamageFlashDecorator) {
            dec.flash();
          }
        }
      ),
      (
        name: 'Ghost Trail\n(Tap to rotate angle)',
        factory: (Ptero e) => GhostTrailDecorator(
              component: e,
              speed: 300,
              angle: -math.pi / 2, // Upward by default
            ),
        onTap: (dec) {
          if (dec is GhostTrailDecorator) {
            dec.angle = (dec.angle + math.pi / 4) % (math.pi * 2);
          }
        }
      ),
      (
        name: 'Hue Shift\n(Tap to Cycle)',
        factory: (Ptero e) => HueDecorator(component: e, hue: math.pi / 2),
        onTap: (dec) {
          if (dec is HueDecorator) {
            dec.hue = (dec.hue + math.pi / 4) % (math.pi * 2);
          }
        }
      ),
    ];

    for (var i = 0; i < decoratorData.length; i++) {
      final col = i % 3;
      final row = i ~/ 3;
      final cellPos = Vector2(col * cellWidth, row * cellHeight);

      final data = decoratorData[i];
      add(
        DecoratorCell(
          name: data.name,
          position: cellPos,
          size: Vector2(cellWidth, cellHeight),
          decoratorFactory: data.factory,
          onTap: data.onTap,
        ),
      );
    }
  }
}

class DecoratorCell extends PositionComponent with TapCallbacks {
  DecoratorCell({
    required this.name,
    required super.position,
    required super.size,
    required this.decoratorFactory,
    this.onTap,
  }) : super(anchor: Anchor.topLeft);

  final String name;
  final Decorator? Function(Ptero) decoratorFactory;
  final void Function(Decorator)? onTap;

  late final Ptero ember;
  Decorator? fxDecorator;

  @override
  Future<void> onLoad() async {
    final emberHeight = math.min(size.x / 1.5, size.y) * 0.5;
    final emberWidth = emberHeight * 1.5;

    ember = Ptero(
      position: size / 2, // Centered in cell using Anchor.center
      size: Vector2(emberWidth, emberHeight),
    );
    add(ember);

    fxDecorator = decoratorFactory(ember);
    if (fxDecorator != null) {
      ember.decorator = fxDecorator!;
    }

    add(
      TextComponent(
        text: name,
        position: Vector2(size.x / 2, size.y * 0.85),
        anchor: Anchor.center,
        textRenderer: TextPaint(
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  @override
  void update(double dt) {
    super.update(dt);
    final dec = fxDecorator;
    if (dec != null) {
      if (dec is GhostTrailDecorator) dec.update(dt);
      if (dec is HologramDecorator) dec.update(dt);
      if (dec is DissolveDecorator) dec.update(dt);
      if (dec is PulseOutlineDecorator) dec.update(dt);
      if (dec is DamageFlashDecorator) dec.update(dt);
      if (dec is NeonGlowDecorator) dec.update(dt);
    }
  }

  @override
  void onTapDown(TapDownEvent event) {
    final dec = fxDecorator;
    if (dec != null) {
      onTap?.call(dec);
    }
  }
}

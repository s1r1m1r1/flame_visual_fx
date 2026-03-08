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
    const margin = 64.0;
    final availableSize = size - Vector2.all(margin * 2);
    final cellWidth = availableSize.x / 3;
    final cellHeight = availableSize.y / 3;

    final decoratorData = [
      (name: 'Original', factory: (Ptero e) => null, onTap: null),
      (
        name: 'Pulse Outline',
        factory: (Ptero e) => PulseOutlineDecorator(component: e),
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
        name: 'Dissolve\n(Tap: Grid & Residual)',
        factory: (Ptero e) => DissolveDecorator(component: e)..loop = false,
        onTap: (dec) {
          if (dec is DissolveDecorator) {
            if (dec.gridSize == 10) {
              dec.gridSize = 25;
              dec.showResidualEffect = false;
            } else if (dec.gridSize == 25 && !dec.showResidualEffect) {
              dec.showResidualEffect = true;
            } else if (dec.gridSize == 25 && dec.showResidualEffect) {
              dec.gridSize = 50;
              dec.showResidualEffect = false;
            } else if (dec.gridSize == 50) {
              dec.gridSize = 100;
            } else {
              dec.gridSize = 10;
              dec.showResidualEffect = false;
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

      // Calculate cell position with 64px margin
      final cellPos = Vector2(
        margin + col * cellWidth,
        margin + row * cellHeight,
      );

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

  late final Ptero ptero;
  Decorator? fxDecorator;

  @override
  Future<void> onLoad() async {
    final emberHeight = math.min(size.x / 1.5, size.y) * 0.5;
    final emberWidth = emberHeight * 1.5;
    final pteroPos = Vector2(size.x - emberWidth, size.y - emberHeight) / 2;

    ptero = Ptero(
      position: pteroPos..translate(0, -64),
      size: Vector2(emberWidth, emberHeight),
    );
    add(ptero);

    fxDecorator = decoratorFactory(ptero);
    if (fxDecorator != null) {
      ptero.decorator = fxDecorator!;
    }

    add(
      TextComponent(
        text: name,
        position: Vector2(size.x * 0.2, size.y * 0.85),
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

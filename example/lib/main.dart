import 'dart:math' as math;
import 'package:flame/game.dart';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/rendering.dart' hide HueDecorator;
import 'package:flame_visual_fx/flame_visual_fx.dart';
import 'package:flutter/material.dart';
import 'dart:ui' as ui;

import 'commons/ptero.dart';

void main() {
  runApp(GameWidget(game: DecoratorExample()));
}

class DecoratorExample extends FlameGame {
  late ui.FragmentProgram dissolveProgram;
  late ui.FragmentProgram dissolveGridProgram;
  late ui.FragmentProgram dissolveSliceProgram;
  late ui.FragmentProgram dissolveWaveProgram;
  late ui.FragmentProgram dissolveShatterProgram;
  late ui.FragmentProgram dissolveClipProgram;

  @override
  Color backgroundColor() => const Color(0xFF1A1A1A);

  @override
  Future<void> onLoad() async {
    dissolveProgram = await ui.FragmentProgram.fromAsset(
      'assets/shaders/dissolve.frag',
    );
    dissolveGridProgram = await ui.FragmentProgram.fromAsset(
      'assets/shaders/dissolve_grid.frag',
    );
    dissolveSliceProgram = await ui.FragmentProgram.fromAsset(
      'assets/shaders/dissolve_slice.frag',
    );
    dissolveWaveProgram = await ui.FragmentProgram.fromAsset(
      'assets/shaders/dissolve_wave.frag',
    );
    dissolveShatterProgram = await ui.FragmentProgram.fromAsset(
      'assets/shaders/dissolve_shatter.frag',
    );
    dissolveClipProgram = await ui.FragmentProgram.fromAsset(
      'assets/shaders/dissolve_clip.frag',
    );

    const margin = 64.0;
    final availableSize = size - Vector2.all(margin * 2);
    final decoratorData = [
      (name: 'Original', factory: (Ptero e) => null, onTap: null),
      (
        name: 'Pulse Outline',
        factory: (Ptero e) => PulseOutlineDecorator(component: e),
        onTap: null,
      ),
      (
        name: 'Outline',
        factory: (Ptero e) => OutlineDecorator(component: e),
        onTap: null,
      ),
      (
        name: 'Neon Glow',
        factory: (Ptero e) => NeonGlowDecorator(component: e),
        onTap: null,
      ),
      (
        name: 'Pure Outline\n(Fast Canvas)',
        factory: (Ptero e) => PureOutlineDecorator(
          thickness: 4.0,
          color: const Color(0xFF00FFCC),
        ),
        onTap: (dec) {
          if (dec is PureOutlineDecorator) {
            dec.thickness = dec.thickness == 4.0 ? 8.0 : 4.0;
          }
        },
      ),
      (
        name: 'Hologram',
        factory: (Ptero e) => HologramDecorator(component: e),
        onTap: null,
      ),
      (
        name: 'Dissolve\n(Tap: Grid & Residual)',
        factory: (Ptero e) =>
            DissolveDecorator(component: e, mask: GridDissolveMask()),
        onTap: (dec) {
          if (dec is DissolveDecorator) {
            final mask = dec.mask;
            if (mask is GridDissolveMask) {
              if (mask.gridSize == 10) {
                mask.gridSize = 25;
                dec.showResidualEffect = false;
              } else if (mask.gridSize == 25 && !dec.showResidualEffect) {
                dec.showResidualEffect = true;
              } else if (mask.gridSize == 25 && dec.showResidualEffect) {
                mask.gridSize = 50;
                dec.showResidualEffect = false;
              } else if (mask.gridSize == 50) {
                mask.gridSize = 100;
              } else {
                mask.gridSize = 10;
                dec.showResidualEffect = false;
              }
              dec.progress = 0.0;
            }
          }
        },
      ),
      (
        name: 'Shader Dissolve\n(GPU Fast)',
        factory: (Ptero e) => ShaderDissolveDecorator(
          shader: dissolveProgram.fragmentShader(),
          component: e,
          image: e.animationTicker!.getSprite().image,
          sourceRect: e.animationTicker!.getSprite().src,
          noiseWeight: 1.0,
          progress: 0.5,
        ),
        onTap: (dec) {
          if (dec is ShaderDissolveDecorator) {
            // Cycle through types
            final nextType = DissolveType
                .values[(dec.type.index + 1) % DissolveType.values.length];
            dec.type = nextType;
            dec.progress = 0.5;
          }
        },
      ),
      (
        name: 'Shader Grid\n(GPU Fast)',
        factory: (Ptero e) => ShaderDissolveDecorator(
          shader: dissolveGridProgram.fragmentShader(),
          component: e,
          image: e.animationTicker!.getSprite().image,
          sourceRect: e.animationTicker!.getSprite().src,
          progress: 0.5,
          onApply: (s, p, t) =>
              s.setFloat(22, 4.0), // grid size shift to 22 (after 16+2+4)
        ),
        onTap: (dec) {
          if (dec is ShaderDissolveDecorator) {
            final nextType = DissolveType
                .values[(dec.type.index + 1) % DissolveType.values.length];
            dec.type = nextType;
            dec.progress = 0.5;
          }
        },
      ),
      (
        name: 'Shader Slice\n(GPU Fast)',
        factory: (Ptero e) => ShaderDissolveDecorator(
          shader: dissolveSliceProgram.fragmentShader(),
          component: e,
          image: e.animationTicker!.getSprite().image,
          sourceRect: e.animationTicker!.getSprite().src,
          onApply: (s, p, t) {
            s.setFloat(22, 8.0); // 8 slices instead of 10
            s.setFloat(23, 0.0); // uDirection (horizontal)
          },
        ),
        onTap: (dec) {
          if (dec is ShaderDissolveDecorator) {
            final nextType = DissolveType
                .values[(dec.type.index + 1) % DissolveType.values.length];
            dec.type = nextType;
          }
        },
      ),
      (
        name: 'Shader Wave\n(GPU Fast)',
        factory: (Ptero e) => ShaderDissolveDecorator(
          shader: dissolveWaveProgram.fragmentShader(),
          component: e,
          image: e.animationTicker!.getSprite().image,
          sourceRect: e.animationTicker!.getSprite().src,
          onApply: (s, p, t) {
            s.setFloat(22, 8.0); // uAmplitude
            s.setFloat(23, 3.0); // uFrequency
          },
        ),
        onTap: (dec) {
          if (dec is ShaderDissolveDecorator) {
            final nextType = DissolveType
                .values[(dec.type.index + 1) % DissolveType.values.length];
            dec.type = nextType;
          }
        },
      ),
      (
        name: 'Shader Shatter\n(GPU Voronoi)',
        factory: (Ptero e) => ShaderDissolveDecorator(
          shader: dissolveShatterProgram.fragmentShader(),
          component: e,
          image: e.animationTicker!.getSprite().image,
          sourceRect: e.animationTicker!.getSprite().src,
          onApply: (s, p, t) {
            s.setFloat(22, 10.0); // uGridSize shift to 22
          },
        ),
        onTap: (dec) {
          if (dec is ShaderDissolveDecorator) {
            final nextType = DissolveType
                .values[(dec.type.index + 1) % DissolveType.values.length];
            dec.type = nextType;
          }
        },
      ),
      (
        name: 'Shader Clip\n(GPU Logic)',
        factory: (Ptero e) => ShaderDissolveDecorator(
          shader: dissolveClipProgram.fragmentShader(),
          component: e,
          image: e.animationTicker!.getSprite().image,
          sourceRect: e.animationTicker!.getSprite().src,
          onApply: (s, p, t) => s.setFloat(22, 15.0), // uClipEdges shift to 22
        ),
        onTap: null,
      ),
      (
        name: 'Damage Flash\n(Tap to Flash)',
        factory: (Ptero e) => DamageFlashDecorator(),
        onTap: (dec) {
          if (dec is DamageFlashDecorator) {
            dec.flash();
          }
        },
      ),
      (
        name: 'Ghost Trail\n(Tap to rotate angle)',
        factory: (Ptero e) => GhostTrailDecorator(component: e),
        onTap: null,
      ),
      (
        name: 'Hue Shift\n(Tap to Cycle)',
        factory: (Ptero e) => HueDecorator(component: e, hue: math.pi / 2),
        onTap: (dec) {
          if (dec is HueDecorator) {
            dec.hue = (dec.hue + math.pi / 4) % (math.pi * 2);
          }
        },
      ),
      (
        name: 'Waves\n(Tap to switch Axis)',
        factory: (Ptero e) =>
            WaveDecorator(component: e, amplitude: 8.0, frequency: 0.1),
        onTap: (dec) {
          if (dec is WaveDecorator) {
            dec.axis = dec.axis == WaveAxis.horizontal
                ? WaveAxis.vertical
                : WaveAxis.horizontal;
          }
        },
      ),
      (
        name: 'Silhouette (Wavy)\n(Tap: Mode)',
        factory: (Ptero e) {
          final s = e.size;
          // Use auto-detected vertices if available, fallback to circle
          final vertices =
              e.contourVertices ??
              List.generate(16, (i) {
                final angle = (i / 16) * math.pi * 2;
                final rx = s.x * 0.7;
                final ry = s.y * 0.7;
                return Vector2(
                  s.x * 0.5 + math.cos(angle) * rx,
                  s.y * 0.5 + math.sin(angle) * ry,
                );
              });

          return PolygonOutlineDecorator(
            vertices: e.contourVertices ?? vertices,
            color: const Color(0xFF00FFCC),
            thickness: 2.0,
            amplitude: 3.0,
          );
        },
        onTap: (dec) {
          if (dec is PolygonOutlineDecorator) {
            if (dec.mode == PolygonOutlineMode.wavy) {
              dec.mode = PolygonOutlineMode.electric;
              dec.color = const Color(0xFFFFFF00); // Yellow for electric
            } else {
              dec.mode = PolygonOutlineMode.wavy;
              dec.color = const Color(0xFF00FFCC); // Cyan for wavy
            }
          }
        },
      ),
      (
        name: 'Aura (Breathing)',
        factory: (Ptero e) {
          return PolygonAuraDecorator(
            vertices: e.contourVertices ?? [],
            color: const Color(0xFFFF00FF), // Magenta
            baseAmplitude: 8.0,
            layers: 3,
          );
        },
        onTap: null,
      ),
      (
        name: 'Snake (Energy)',
        factory: (Ptero e) {
          return PolygonSnakeDecorator(
            vertices: e.contourVertices ?? [],
            color: const Color(0xFF00FFCC), // Cyan
            thickness: 4.0,
            lengthRatio: 0.25,
          );
        },
        onTap: null,
      ),
      (
        name: 'Echo (Ghosts)\n(Trailing)',
        factory: (Ptero e) {
          return PolygonEchoDecorator(
            vertices: e.contourVertices ?? [],
            history: [], // Managed by Ptero
            color: const Color(0x6600FFFF),
            decayScale: 1.15,
          );
        },
        onTap: null,
      ),
      (
        name: 'Scan (Laser)\n(Clipped)',
        factory: (Ptero e) {
          return PolygonScanDecorator(
            vertices: e.contourVertices ?? [],
            color: const Color(0xFF00FF00),
            lineHeight: 3.0,
          );
        },
        onTap: null,
      ),
      (
        name: 'Fire (Ambient)\n(Inferno Pulse)',
        factory: (Ptero e) {
          return PolygonFireDecorator(
            vertices: e.contourVertices ?? [],
            particles: [], // Managed by Ptero
          );
        },
        onTap: null,
      ),
      (
        name: 'Soul Whirl\n(Spirit Orbit)',
        factory: (Ptero e) {
          return PolygonWhirlDecorator(
            vertices: e.contourVertices ?? [],
            particles: [], // Managed by Ptero
            color: const Color(0xFF00FFCC),
          );
        },
        onTap: null,
      ),
    ];

    const columns = 4;
    final rows = (decoratorData.length / columns).ceil();
    final cellWidth = availableSize.x / columns;
    final cellHeight = availableSize.y / rows;

    for (var i = 0; i < decoratorData.length; i++) {
      final col = i % columns;
      final row = i ~/ columns;

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
    )..debugMode = true;
    await add(
      ptero,
    ); // Ensure Ptero's onLoad (and contour detection) is complete

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
    fxDecorator?.update(dt);
  }

  @override
  void onTapDown(TapDownEvent event) {
    final dec = fxDecorator;
    if (dec != null) {
      onTap?.call(dec);
    }
  }
}

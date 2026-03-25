import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flame/game.dart';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/input.dart';
import 'package:flame_visual_fx/flame_visual_fx.dart';
import 'package:flutter/material.dart';

import 'commons/ptero.dart';

void main() {
  runApp(const MaterialApp(home: DissolveGridSandbox()));
}

class DissolveGridSandbox extends StatefulWidget {
  const DissolveGridSandbox({super.key});

  @override
  State<DissolveGridSandbox> createState() => _DissolveGridSandboxState();
}

class _DissolveGridSandboxState extends State<DissolveGridSandbox> {
  double threshold = 0.5;
  double noiseWeight = 0.3;
  double gridSize = 15.0;
  int typeIndex = 1; // Default to TopDown
  bool showDebug = true;
  double calibrateX = 0;
  double calibrateY = 0;

  late DissolveGridGame game;

  @override
  void initState() {
    super.initState();
    game = DissolveGridGame(
      threshold: threshold,
      noiseWeight: noiseWeight,
      gridSize: gridSize,
      typeIndex: typeIndex,
      showDebug: showDebug,
      calibrateX: calibrateX,
      calibrateY: calibrateY,
    );
  }

  void _updateGame() {
    game.updateParams(
      threshold: threshold,
      noiseWeight: noiseWeight,
      gridSize: gridSize,
      typeIndex: typeIndex,
      showDebug: showDebug,
      calibrateX: calibrateX,
      calibrateY: calibrateY,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Dissolve Grid Sandbox (Scrolling + Calibration)'),
        backgroundColor: Colors.grey[900],
      ),
      body: Column(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(64 * 3, 64, 8, 8),
              child: GameWidget(game: game),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey[900],
            child: SingleChildScrollView(
              child: Column(
                children: [
                  _buildSlider('Threshold', threshold, 0, 1, (v) {
                    setState(() => threshold = v);
                    _updateGame();
                  }),
                  _buildSlider('Noise Weight', noiseWeight, 0, 1, (v) {
                    setState(() => noiseWeight = v);
                    _updateGame();
                  }),
                  _buildSlider('Grid Size', gridSize, 1, 100, (v) {
                    setState(() => gridSize = v);
                    _updateGame();
                  }),
                  _buildSlider('Calibrate X', calibrateX, -500, 500, (v) {
                    setState(() => calibrateX = v);
                    _updateGame();
                  }),
                  _buildSlider('Calibrate Y', calibrateY, -500, 500, (v) {
                    setState(() => calibrateY = v);
                    _updateGame();
                  }),
                  Row(
                    children: [
                      const Text(
                        'Type: ',
                        style: TextStyle(color: Colors.white),
                      ),
                      Expanded(
                        child: DropdownButton<int>(
                          value: typeIndex,
                          dropdownColor: Colors.grey[800],
                          style: const TextStyle(color: Colors.white),
                          items: List.generate(DissolveType.values.length, (i) {
                            return DropdownMenuItem(
                              value: i,
                              child: Text(DissolveType.values[i].name),
                            );
                          }),
                          onChanged: (v) {
                            if (v != null) {
                              setState(() => typeIndex = v);
                              _updateGame();
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 20),
                      const Text(
                        'Debug: ',
                        style: TextStyle(color: Colors.white),
                      ),
                      Switch(
                        value: showDebug,
                        onChanged: (v) {
                          setState(() => showDebug = v);
                          _updateGame();
                        },
                      ),
                    ],
                  ),
                  const Text(
                    'Drag mouse/pan to scroll the world',
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSlider(
    String label,
    double value,
    double min,
    double max,
    ValueChanged<double> onChanged,
  ) {
    return Row(
      children: [
        SizedBox(
          width: 100,
          child: Text(label, style: const TextStyle(color: Colors.white)),
        ),
        Expanded(
          child: Slider(value: value, min: min, max: max, onChanged: onChanged),
        ),
        SizedBox(
          width: 60,
          child: Text(
            value.toStringAsFixed(1),
            style: const TextStyle(color: Colors.white),
          ),
        ),
      ],
    );
  }
}

class DissolveGridGame extends FlameGame with PanDetector {
  double threshold;
  double noiseWeight;
  int typeIndex;
  double gridSize;
  bool showDebug;
  double calibrateX;
  double calibrateY;

  late Ptero ptero, ptero2;
  ShaderDissolveDecorator? decorator;

  DissolveGridGame({
    required this.threshold,
    required this.noiseWeight,
    required this.typeIndex,
    required this.gridSize,
    required this.showDebug,
    required this.calibrateX,
    required this.calibrateY,
  });

  @override
  Future<void> onLoad() async {
    // Add a simple grid to the world to see movement
    await world.add(WorldGrid());

    ptero = Ptero(
      position: Vector2(0, 0),
      size: Vector2(200, 150),
      priority: 10,
    );
    ptero2 = Ptero(
      position: Vector2(50, 50),
      size: Vector2(200, 150),
      priority: 5,
    );
    ptero.debugMode = showDebug;
    await world.add(ptero);
    await world.add(ptero2);

    final program = await ui.FragmentProgram.fromAsset(
      'assets/shaders/dissolve_grid.frag',
    );

    decorator = ShaderDissolveDecorator(
      shader: program.fragmentShader(),
      component: ptero,
      progress: threshold,
      noiseWeight: noiseWeight,
      type: DissolveType.values[typeIndex],
      autoAnimate: false, // We control it from the slider/Ptero
      calibrationOffset: Vector2(calibrateX, calibrateY),
      onApply: (s, p, t) {
        s.setFloat(22, gridSize);
      },
    );
    ptero.decorator.addLast(decorator!);

    camera.viewfinder.position = Vector2.zero();
    camera.viewfinder.zoom = 1.0;
  }

  void updateParams({
    required double threshold,
    required double noiseWeight,
    required double gridSize,
    required int typeIndex,
    required bool showDebug,
    required double calibrateX,
    required double calibrateY,
  }) {
    this.threshold = threshold;
    this.noiseWeight = noiseWeight;
    this.gridSize = gridSize;
    this.typeIndex = typeIndex;
    this.showDebug = showDebug;
    this.calibrateX = calibrateX;
    this.calibrateY = calibrateY;

    if (decorator != null) {
      decorator!.progress = threshold;
      decorator!.noiseWeight = noiseWeight;
      decorator!.type = DissolveType.values[typeIndex];
      decorator!.calibrationOffset = Vector2(calibrateX, calibrateY);
      ptero.debugMode = showDebug;
    }
  }

  @override
  void onPanUpdate(DragUpdateInfo info) {
    camera.viewfinder.position -= info.delta.global;
  }
}

class WorldGrid extends Component {
  @override
  void render(ui.Canvas canvas) {
    final paint = ui.Paint()
      ..color = const ui.Color(0x33FFFFFF)
      ..style = ui.PaintingStyle.stroke
      ..strokeWidth = 1.0;

    const step = 64.0;
    const count = 50;
    for (int i = -count; i <= count; i++) {
      canvas.drawLine(
        ui.Offset(i.toDouble() * step, -count.toDouble() * step),
        ui.Offset(i.toDouble() * step, count.toDouble() * step),
        paint,
      );
      canvas.drawLine(
        ui.Offset(-count.toDouble() * step, i.toDouble() * step),
        ui.Offset(count.toDouble() * step, i.toDouble() * step),
        paint,
      );
    }
  }
}

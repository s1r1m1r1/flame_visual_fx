# flame_visual_fx

A powerful, high-performance visual effects package for the **Flame** game engine.

Instead of fighting with complex WebGL Fragment Shaders that break on edge cases, fail to scale with Device Pixel Ratios, or ignore TexturePacker rotations, `flame_visual_fx` provides native `saveLayer` Canvas Decorators. These decorators wrap any `PositionComponent` seamlessly with zero matrix math overhead.

## Features

- **`OutlineDecorator`**: Solid, strictly bound 8-way silhouette outline for pixel-perfect selections.
- **`PulseOutlineDecorator`**: A thick, smoothly pulsating outline that dynamically generates structural copies to eliminate tracing gaps.
- **`NeonGlowDecorator`**: A soft, cyber-punk glowing aura shadow utilizing dynamic `MaskFilter.blur` expanding rings.
- **`GhostTrailDecorator`**: Renders trailing, fading afterimages following your component to simulate teleportation or supersonic movement.
- **`HologramDecorator`**: Chromatic Aberration RGB-splitting offset glitch filter with randomized vertical jump jitter.
- **`DissolveDecorator`**: A teleportation/disintegration wave that mathematically erases the character using procedural noise grids and `BlendMode.dstOut`.

## Getting Started

In your `pubspec.yaml`:

```yaml
dependencies:
  flame_visual_fx: ^1.0.0
```

## Usage

Simply attach any decorator into your component's `decorator` queue!

```dart
import 'package:flame_visual_fx/flame_visual_fx.dart';

class MyPlayer extends SpriteAnimationComponent {
  late NeonGlowDecorator neonGlow;

  @override
  Future<void> onLoad() async {
    super.onLoad();
    
    neonGlow = NeonGlowDecorator(
      component: this,
      color: const Color.fromARGB(255, 0, 255, 255),
      baseGlowRadius: 6.0,
      pulseAmplitude: 4.0,
      isActive: true, // Toggle this to turn the effect on/off
    );
    
    // Attach it to the rendering pipeline
    decorator.addLast(neonGlow);
  }

  @override
  void update(double dt) {
    super.update(dt);
    // Remember to propagate the update loop for animated effects like Pulse, Ghost, and Dissolve!
    neonGlow.update(dt);
  }
}
```

## License

MIT License

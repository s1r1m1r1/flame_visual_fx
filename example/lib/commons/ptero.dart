import 'package:flame/components.dart';
import 'package:flame/game.dart';

class Ptero<T extends FlameGame> extends SpriteAnimationComponent
    with HasGameReference<T> {
  Ptero({super.position, Vector2? size, super.priority, super.key})
      : super(
          size: size ?? Vector2(150, 100),
          anchor: Anchor.center,
        );

  @override
  Future<void> onLoad() async {
    animation = await game.loadSpriteAnimation(
      'animations/bomb_ptero.png',
      SpriteAnimationData.sequenced(
        amount: 4,
        textureSize: Vector2(48, 32),
        stepTime: 0.15,
      ),
    );
  }
}

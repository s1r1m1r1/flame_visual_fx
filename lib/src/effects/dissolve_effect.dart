import 'package:flame/effects.dart';

/// An interface for components that support a dissolve effect.
abstract interface class DissolveProvider {
  double get dissolveThreshold;
  set dissolveThreshold(double value);
}

/// An effect that smoothly changes the [dissolveThreshold] of a [DissolveProvider].
class DissolveEffect extends Effect with EffectTarget<DissolveProvider> {
  DissolveEffect(EffectController controller, {super.key, super.onComplete})
    : super(controller);

  @override
  void apply(double progress) {
    target.dissolveThreshold = progress;
  }

  @override
  void reset() {
    super.reset();
    target.dissolveThreshold = 0.0;
  }
}

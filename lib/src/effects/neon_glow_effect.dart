// import 'dart:math' as math;
// import 'package:flame/components.dart';
// import 'package:flame/effects.dart';
// import 'package:flame_unified_real_time/flame_unified_real_time.dart';
// import '../decorators/neon_glow_decorator.dart';

// /// An effect that animates the [radius] of a [NeonGlowDecorator].
// /// This allows for easy pulsating or expanding neon glow effects.
// class NeonGlowPulseEffect extends Effect with EffectTarget<PositionComponent> {
//   NeonGlowPulseEffect(
//     this.amplitude,
//     this.speed,
//     EffectController controller, {
//     this.baseRadius = 8.0,
//     super.key,
//     super.onComplete,
//   }) : super(controller);

//   final double baseRadius;
//   final double amplitude;
//   final double speed;
//   double _time = 0.0;

//   @override
//   void update(double dt) {
//     super.update(dt);
//     _time += dt;
//   }

//   @override
//   void apply(double progress) {
//     final decorator = target.decorator.find<NeonGlowDecorator>();
//     if (decorator != null) {
//       // We ignore effect progress and use internal oscillation for continuous pulsing
//       // OR we could use progress to drive a single pulse.
//       // Given the name "PulseEffect", let's use the oscillation.
//       decorator.radius = baseRadius + math.sin(_time * speed) * amplitude;
//     }
//   }

//   @override
//   void onRemove() {
//     super.onRemove();
//     // Optional: reset decorator radius
//   }
// }

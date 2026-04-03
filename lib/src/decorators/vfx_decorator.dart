import 'dart:async';
import 'package:flame/effects.dart';
import 'package:flame/rendering.dart';

/// A mixin that provides lifecycle hooks and progress tracking for visual effects.
/// It uses an [EffectController] to organically drive the progress over time.
mixin VisualFX {
  /// Optional controller to organically drive the progress over time.
  /// For this to work, [updateVFX] must be called every tick.
  EffectController? controller;

  /// The current progress of the animation (0.0 to 1.0 depending on the controller).
  double progress = 0.0;

  /// Whether the animation should be paused.
  bool isPaused = false;

  /// Callback function to be invoked once the animation completes.
  void Function()? onComplete;

  bool _vfxStarted = false;
  bool _vfxFinished = false;
  Completer<void>? _vfxCompleter;

  /// A future that completes when the animation is finished.
  Future<void> get completed {
    if (_vfxFinished || (controller?.completed ?? false)) {
      return Future.value();
    }
    return (_vfxCompleter ??= Completer<void>()).future;
  }

  /// Updates the VFX state based on the provided delta time.
  /// This should be called every tick by the owner.
  void updateVFX(double dt) {
    if (controller == null || isPaused || _vfxFinished) return;

    if (!_vfxStarted && controller!.started) {
      _vfxStarted = true;
      onStart();
    }

    controller!.advance(dt);
    progress = controller!.progress;

    if (!_vfxFinished && controller!.completed) {
      _vfxFinished = true;
      onFinish();
    }
  }

  /// Called once when the animation starts.
  void onStart() {}

  /// Called once when the animation completes.
  void onFinish() {
    onComplete?.call();
    _vfxCompleter?.complete();
    _vfxCompleter = null;
  }

  /// Restores the VFX to its original state.
  void resetVFX() {
    controller?.setToStart();
    progress = 0;
    _vfxStarted = false;
    _vfxFinished = false;
    isPaused = false;
  }

  /// Disposes any resources held by this effect.
  void dispose() {}
}

/// A [Decorator] that implements [VisualFX].
/// It provides lifecyle hooks and completion signaling similar to Flame Effects.
abstract class VFXDecorator extends Decorator with VisualFX {
  VFXDecorator({
    EffectController? controller,
    void Function()? onComplete,
    double initialProgress = 0.0,
    bool isPaused = false,
  }) {
    this.controller = controller;
    this.onComplete = onComplete;
    this.progress = initialProgress;
    this.isPaused = isPaused;
  }

  @override
  void update(double dt) {
    super.update(dt);
    updateVFX(dt);
  }
}

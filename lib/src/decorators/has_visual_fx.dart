import 'dart:ui';
import 'package:flame/components.dart';
import 'package:flame/rendering.dart';
import 'vfx_decorator.dart';

/// A mixin that allows a [PositionComponent] to manage multiple [VFXDecorator]s
/// concurrently. It handles layering, updates, and automatic removal of
/// finished effects.
mixin HasVisualFX on PositionComponent {
  final List<VisualFX> _vfxList = [];

  /// Adds a new [VisualFX] to the component.
  /// If it's a [VFXDecorator], it will be automatically layered.
  T addVFX<T extends VisualFX>(T vfx) {
    _vfxList.add(vfx);
    _updateDecoratorChain();
    return vfx;
  }

  /// Removes an [VisualFX] from the component.
  void removeVFX(VisualFX vfx) {
    if (_vfxList.remove(vfx)) {
      vfx.dispose();
      _updateDecoratorChain();
    }
  }

  /// Finds the first [VisualFX] of type [T] managed by this component.
  T? findVFX<T extends VisualFX>() {
    for (final vfx in _vfxList) {
      if (vfx is T) return vfx;
    }
    return null;
  }

  /// Returns all [VisualFX] of type [T] managed by this component.
  Iterable<T> getVFX<T extends VisualFX>() {
    return _vfxList.whereType<T>();
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (_vfxList.isEmpty) return;

    bool changed = false;
    // Iterate backwards to allow safe removal
    for (int i = _vfxList.length - 1; i >= 0; i--) {
      final vfx = _vfxList[i];
      vfx.updateVFX(dt);

      // Automatic removal if a controller is finished
      if (vfx.controller?.completed ?? false) {
        final removed = _vfxList.removeAt(i);
        removed.dispose();
        changed = true;
      }
    }

    if (changed) {
      _updateDecoratorChain();
    }
  }

  @override
  void onRemove() {
    for (final vfx in _vfxList) {
      vfx.dispose();
    }
    _vfxList.clear();
    super.onRemove();
  }

  void _updateDecoratorChain() {
    if (_vfxList.isEmpty) {
      if (decorator is _MultipleFXDecorator) {
        decorator = (decorator as _MultipleFXDecorator).base;
      }
    } else {
      final baseDecorator = decorator is _MultipleFXDecorator
          ? (decorator as _MultipleFXDecorator).base
          : decorator;

      final effects = _vfxList.whereType<VFXDecorator>().toList();

      if (effects.isEmpty) {
        decorator = baseDecorator;
      } else {
        decorator = _MultipleFXDecorator(base: baseDecorator, effects: effects);
      }
    }
  }
}

/// A decorator that chains multiple VFX decorators on top of a base decorator.
class _MultipleFXDecorator extends Decorator {
  _MultipleFXDecorator({required this.base, required this.effects});

  final Decorator base;
  final List<VFXDecorator> effects;

  @override
  void apply(void Function(Canvas) draw, Canvas canvas) {
    // We wrap the draw call in a chain
    void Function(Canvas) currentDraw = draw;

    for (final vfx in effects) {
      final nextDraw = currentDraw;
      currentDraw = (c) => vfx.apply(nextDraw, c);
    }

    base.apply(currentDraw, canvas);
  }
}

/// Extension to help finding specific decorators in a chain.
extension DecoratorExtension on Decorator {
  /// Finds the first decorator of type [T] in the chain.
  /// It also searches inside [_MultipleFXDecorator.effects] if found.
  T? find<T extends Decorator>() {
    Decorator? current = this;
    while (current != null) {
      if (current is T) {
        return current;
      }

      if (current is _MultipleFXDecorator) {
        for (final fx in current.effects) {
          if (fx is T) return fx as T;
        }
      }

      current = current.next;
    }
    return null;
  }
}

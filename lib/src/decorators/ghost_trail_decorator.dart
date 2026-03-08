import 'dart:collection';
import 'dart:ui';
import 'package:flame/components.dart';
import 'package:flame/rendering.dart';

/// A [Decorator] that creates a "Ghost Trail" / "Afterimage" effect.
/// It records the past positions of the component and renders faded,
/// color-tinted silhouettes trailing behind the moving character!
class GhostTrailDecorator extends Decorator {
  GhostTrailDecorator({
    required this.component,
    this.color = const Color.fromARGB(255, 114, 0, 255), // Purple ghost
    this.trailLength = 5,
    this.isActive = true,
  });

  final PositionComponent component;
  Color color;
  int trailLength;
  bool isActive;

  final Queue<_GhostSnapshot> _ghosts = Queue();

  // We need to track where the component was relative to the canvas origin.
  // The simplest way without un-projecting Flame matrices is to track its local logical position!
  Vector2 _lastKnownPosition = Vector2.zero();

  void update(double dt) {
    super.update(dt);
    if (!isActive) {
      _ghosts.clear();
      return;
    }

    final currentPosition = component.absolutePosition;

    if (currentPosition != _lastKnownPosition) {
      _ghosts.addFirst(_GhostSnapshot(position: currentPosition.clone()));
      _lastKnownPosition.setFrom(currentPosition);

      if (_ghosts.length > trailLength) {
        _ghosts.removeLast();
      }
    }
  }

  @override
  void apply(void Function(Canvas) draw, Canvas canvas) {
    if (!isActive || _ghosts.isEmpty) {
      draw(canvas);
      return;
    }

    final size = component.size;
    if (size.x <= 0 || size.y <= 0) {
      draw(canvas);
      return;
    }

    int index = 0;
    for (final ghost in _ghosts) {
      // The older the ghost, the more transparent it becomes
      final opacity = 1.0 - (index / trailLength);

      final ghostPaint = Paint()
        ..colorFilter = ColorFilter.mode(
          color.withValues(alpha: opacity * 0.5), // Max 50% opacity
          BlendMode.srcIn,
        );

      canvas.save();
      // Calculate relative translation: Current position -> Past Ghost Position
      final dx = ghost.position.x - component.absolutePosition.x;
      final dy = ghost.position.y - component.absolutePosition.y;

      canvas.translate(dx, dy);
      canvas.saveLayer(null, ghostPaint);
      draw(canvas);
      canvas.restore();
      canvas.restore();

      index++;
    }

    // Draw the actual component on top of its ghosts
    draw(canvas);
  }
}

class _GhostSnapshot {
  _GhostSnapshot({required this.position});
  final Vector2 position;
}

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
    this.trailDelay = 0.05, // Record a ghost every 0.05 seconds
    this.isActive = true,
  });

  final PositionComponent component;
  Color color;
  int trailLength;
  double trailDelay;
  bool isActive;

  final Queue<_GhostSnapshot> _ghosts = Queue();
  double _timeSinceLastSnapshot = 0.0;

  // We need to track where the component was relative to the canvas origin.
  // The simplest way without un-projecting Flame matrices is to track its local logical position!
  Vector2 _lastKnownPosition = Vector2.zero();

  void update(double dt) {
    if (!isActive) {
      _ghosts.clear();
      return;
    }

    _lastKnownPosition.setFrom(component.absolutePosition);
    _timeSinceLastSnapshot += dt;

    if (_timeSinceLastSnapshot >= trailDelay) {
      _timeSinceLastSnapshot = 0.0;

      _ghosts.addFirst(_GhostSnapshot(position: _lastKnownPosition.clone()));

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

    // Capture the current un-decorated frame of the component using saveLayer
    // By drawing the component off-screen with srcIn, we can grab its silhouette shape
    final bounds = Rect.fromLTWH(0, 0, size.x, size.y);

    int index = 0;
    for (final ghost in _ghosts) {
      // The older the ghost, the more transparent it becomes
      final opacity = 1.0 - (index / trailLength);

      final ghostPaint = Paint()
        ..colorFilter = ColorFilter.mode(
          color.withOpacity(opacity * 0.5), // Max 50% opacity
          BlendMode.srcIn,
        );

      canvas.save();
      // Calculate relative translation: Current position -> Past Ghost Position
      final dx = ghost.position.x - component.absolutePosition.x;
      final dy = ghost.position.y - component.absolutePosition.y;

      canvas.translate(dx, dy);
      canvas.saveLayer(bounds, ghostPaint);
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

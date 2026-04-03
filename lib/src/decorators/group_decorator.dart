import 'dart:ui' as ui;
import 'package:flutter/painting.dart';
import 'package:collection/collection.dart';
import 'package:flame/rendering.dart';
import 'package:composite_atlas/composite_atlas.dart';

/// A decorator that combines multiple [Decorator]s into a single effect.
/// Decorators are applied in the order they appear in the list (index 0 is first).
///
/// Designed to work with [CompositeAtlas] by forwarding [AtlasContext]
/// to any children that implement [AtlasDecorator].
class GroupDecorator extends Decorator implements AtlasDecorator, BakePadding {
  /// The list of decorators to apply in sequence.
  final List<Decorator> decorators;

  GroupDecorator(this.decorators);

  @override
  EdgeInsets get padding {
    EdgeInsets total = EdgeInsets.zero;
    for (final delegate in decorators) {
      if (delegate is BakePadding) {
        total += (delegate as BakePadding).padding;
      }
    }
    return total;
  }

  @override
  void updateAtlasContext(AtlasContext context) {
    for (final decorator in decorators) {
      if (decorator is AtlasDecorator) {
        (decorator as AtlasDecorator).updateAtlasContext(context);
      }
    }
  }

  @override
  void apply(void Function(ui.Canvas) draw, ui.Canvas canvas) {
    // We need to apply decorators in sequence.
    // The outermost decorator is applied last in terms of visual layering, 
    // or we can think of it as a recursive wrapping!
    
    void applyRecursive(int index, void Function(ui.Canvas) currentDraw) {
      if (index >= decorators.length) {
        currentDraw(canvas);
        return;
      }
      
      final decorator = decorators[index];
      decorator.apply((c) => applyRecursive(index + 1, currentDraw), canvas);
    }

    applyRecursive(0, draw);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GroupDecorator &&
          const ListEquality().equals(decorators, other.decorators);

  @override
  int get hashCode => const ListEquality().hash(decorators);
}

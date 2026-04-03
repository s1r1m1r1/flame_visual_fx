import 'dart:ui';
import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flame/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flame_visual_fx/src/decorators/vfx_decorator.dart';
import 'package:flame_visual_fx/src/decorators/has_visual_fx.dart';

class TestDecorator extends VFXDecorator {
  TestDecorator({super.controller, super.onComplete});

  @override
  void apply(void Function(Canvas) draw, Canvas canvas) {
    draw(canvas);
  }
}

class TestComponent extends PositionComponent with HasVisualFX {}

void main() {
  group('HasVisualFX', () {
    test('can add and update a VFX', () {
      final component = TestComponent();
      final controller = LinearEffectController(1.0);
      final decorator = TestDecorator(controller: controller);

      final baseDecorator = component.decorator;
      component.addVFX(decorator);

      // It should be wrapped
      expect(component.decorator, isA<Decorator>());
      expect(component.decorator, isNot(equals(decorator)));
      expect(decorator.progress, 0.0);

      component.update(0.5);
      expect(decorator.progress, 0.5);

      component.update(0.5);
      expect(decorator.progress, 1.0);
      // It should be restored to base in the next update or during this one
      expect(component.decorator, equals(baseDecorator));
    });

    test('can manage multiple VFX in a chain', () {
      final component = TestComponent();
      final vfx1 = TestDecorator(controller: LinearEffectController(1.0));
      final vfx2 = TestDecorator(controller: LinearEffectController(2.0));

      final baseDecorator = component.decorator;
      component.addVFX(vfx1);
      component.addVFX(vfx2);

      // Should be using MultipleDecorator (internal)
      expect(component.decorator, isNot(equals(vfx1)));
      expect(component.decorator, isNot(equals(vfx2)));

      component.update(1.0);
      // vfx1 should be finished and removed.
      // Since only vfx2 remains, it's still wrapped in _MultipleFXDecorator to keep base.
      expect(component.decorator, isA<Decorator>());
      expect(component.decorator, isNot(equals(baseDecorator)));

      component.update(1.0);
      // vfx2 should be finished and removed
      expect(component.decorator, equals(baseDecorator));
    });

    test('onComplete callback is triggered', () {
      bool completed = false;
      final component = TestComponent();
      component.addVFX(
        TestDecorator(
          controller: LinearEffectController(1.0),
          onComplete: () => completed = true,
        ),
      );

      component.update(1.0);
      expect(completed, isTrue);
    });

    test('completed future resolves', () async {
      final component = TestComponent();
      final vfx = component.addVFX(
        TestDecorator(controller: LinearEffectController(1.0)),
      );

      final future = vfx.completed;
      component.update(1.0);

      await expectLater(future, completes);
    });

    test('can add and update a pure VisualFX (non-decorator)', () {
      final component = TestComponent();
      final baseDecorator = component.decorator;

      final vfx = TestPureFX();
      vfx.controller = LinearEffectController(1.0);

      component.addVFX(vfx);

      // Should NOT change the decorator chain if it's just a logic FX
      expect(component.decorator, equals(baseDecorator));

      component.update(0.5);
      expect(vfx.progress, 0.5);

      component.update(0.5);
      expect(vfx.progress, 1.0);

      // Should be removed after completion
      component.update(0.0);
      // We can't easily check internal _vfxList, but we can check if it stop updating
      vfx.progress = 0;
      component.update(0.1);
      expect(vfx.progress, 0.0); // It was removed, so it didn't update to 0.1
    });
  });
}

class TestPureFX with VisualFX {}

// import 'dart:ui';

// import 'package:flame/rendering.dart';

// class PaintDecorator extends Decorator {
//   PaintDecorator.blur(double amount, [double? amountY]) {
//     addBlur(amount, amountY ?? amount);
//   }

//   PaintDecorator.tint(Color color) {
//     _paint.colorFilter = ColorFilter.mode(color, BlendMode.srcATop);
//   }

//   PaintDecorator.grayscale({double opacity = 1.0}) {
//     _paint.color = Color.fromARGB((255 * opacity).toInt(), 0, 0, 0);
//     _paint.blendMode = BlendMode.luminosity;
//   }

//   final _paint = Paint();

//   void addBlur(double amount, [double? amountY]) {
//     _paint.imageFilter = ImageFilter.blur(
//       sigmaX: amount,
//       sigmaY: amountY ?? amount,
//     );
//   }

//   @override
//   void apply(void Function(Canvas) draw, Canvas canvas) {
//     canvas.saveLayer(null, _paint);
//     draw(canvas);
//     canvas.restore();
//   }
// }

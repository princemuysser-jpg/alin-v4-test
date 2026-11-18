import 'package:flutter/material.dart';

/// Dedicated ALIN Business monogram, separate from the student storefront logo.
class BusinessAppMark extends StatelessWidget {
  final double size;
  const BusinessAppMark({super.key, this.size = 64});

  @override
  Widget build(BuildContext context) => SizedBox(
    width: size,
    height: size,
    child: CustomPaint(painter: _BusinessAppMarkPainter()),
  );
}

class _BusinessAppMarkPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 512, size.height / 512);

    final base = RRect.fromRectAndRadius(
      const Rect.fromLTWH(0, 0, 512, 512),
      const Radius.circular(111),
    );
    canvas.drawRRect(
      base,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF102B4E), Color(0xFF083B72)],
        ).createShader(const Rect.fromLTWH(0, 0, 512, 512)),
    );

    Path polygon(List<Offset> vertices) {
      final path = Path()..moveTo(vertices.first.dx, vertices.first.dy);
      for (final v in vertices.skip(1)) {
        path.lineTo(v.dx, v.dy);
      }
      return path..close();
    }

    canvas.drawPath(
      polygon(const [
        Offset(85, 405), Offset(225, 105), Offset(250, 88),
        Offset(274, 100), Offset(151, 405),
      ]),
      Paint()..color = const Color(0xFFF8FAFF),
    );
    canvas.drawPath(
      polygon(const [
        Offset(269, 104), Offset(422, 405),
        Offset(330, 405), Offset(224, 194),
      ]),
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFF37F0D6), Color(0xFF13A6AE)],
        ).createShader(const Rect.fromLTWH(224, 100, 200, 305)),
    );
    final arc = Path()
      ..moveTo(95, 405)
      ..cubicTo(175, 286, 300, 232, 420, 258)
      ..cubicTo(291, 254, 186, 315, 95, 405)
      ..close();
    canvas.drawPath(
      arc,
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFFFFE6A0), Color(0xFFD5AE65), Color(0xFFFFF1B9)],
        ).createShader(const Rect.fromLTWH(95, 240, 325, 165)),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

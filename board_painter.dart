import 'package:flutter/material.dart';

class BoardWidget extends StatelessWidget {
  const BoardWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: BoardPainter(),
      size: const Size(double.infinity, double.infinity),
    );
  }
}

class BoardPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    double gap = size.width / 4;

    // Draw outer border only (no fill)
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      linePaint,
    );

    // Vertical lines
    for (int i = 1; i < 4; i++) {
      double x = gap * i;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), linePaint);
    }

    // Horizontal lines
    for (int i = 1; i < 4; i++) {
      double y = gap * i;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);
    }

    // Main diagonals (X)
    canvas.drawLine(const Offset(0, 0), Offset(size.width, size.height), linePaint);
    canvas.drawLine(Offset(size.width, 0), Offset(0, size.height), linePaint);

    // ✅ Diamond shape (midpoints of edges)
    final midTop = Offset(size.width / 2, 0);
    final midRight = Offset(size.width, size.height / 2);
    final midBottom = Offset(size.width / 2, size.height);
    final midLeft = Offset(0, size.height / 2);

    canvas.drawLine(midTop, midRight, linePaint);
    canvas.drawLine(midRight, midBottom, linePaint);
    canvas.drawLine(midBottom, midLeft, linePaint);
    canvas.drawLine(midLeft, midTop, linePaint);

    // Draw nodes (dots)
    final dotPaint = Paint()..color = Colors.black;
    for (int i = 0; i < 5; i++) {
      for (int j = 0; j < 5; j++) {
        Offset pos = Offset(i * gap, j * gap);
        canvas.drawCircle(pos, 5, dotPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

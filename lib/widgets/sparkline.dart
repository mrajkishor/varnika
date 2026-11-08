import 'dart:math';

import 'package:flutter/material.dart';

/// Two overlaid area lines (download & upload) for the last minute of traffic.
class Sparkline extends StatelessWidget {
  const Sparkline({
    super.key,
    required this.a,
    required this.b,
    required this.colorA,
    required this.colorB,
    this.height = 72,
    this.capacity = 60,
  });

  final List<double> a;
  final List<double> b;
  final Color colorA;
  final Color colorB;
  final double height;
  final int capacity;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: height,
    width: double.infinity,
    child: CustomPaint(
      painter: _SparkPainter(
        a,
        b,
        colorA,
        colorB,
        capacity,
        Theme.of(context).colorScheme.outlineVariant,
      ),
    ),
  );
}

class _SparkPainter extends CustomPainter {
  _SparkPainter(this.a, this.b, this.ca, this.cb, this.capacity, this.grid);

  final List<double> a, b;
  final Color ca, cb, grid;
  final int capacity;

  @override
  void paint(Canvas canvas, Size size) {
    final gp = Paint()
      ..color = grid.withValues(alpha: 0.5)
      ..strokeWidth = 1;
    for (var i = 1; i < 3; i++) {
      final y = size.height * i / 3;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gp);
    }
    final peak = [...a, ...b, 1.0].reduce(max);
    _series(canvas, size, a, ca, peak);
    _series(canvas, size, b, cb, peak);
  }

  void _series(
    Canvas canvas,
    Size size,
    List<double> v,
    Color color,
    double peak,
  ) {
    if (v.length < 2) return;
    final dx = size.width / (capacity - 1);
    final start = size.width - (v.length - 1) * dx;
    final path = Path();
    for (var i = 0; i < v.length; i++) {
      final x = start + i * dx;
      final y = size.height - (v[i] / peak) * (size.height - 4) - 2;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        final px = start + (i - 1) * dx;
        final py = size.height - (v[i - 1] / peak) * (size.height - 4) - 2;
        final mx = (px + x) / 2;
        path.cubicTo(mx, py, mx, y, x, y);
      }
    }
    final fill = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(start, size.height)
      ..close();
    canvas.drawPath(
      fill,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color.withValues(alpha: 0.28), color.withValues(alpha: 0.0)],
        ).createShader(Offset.zero & size),
    );
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(_SparkPainter old) => true;
}

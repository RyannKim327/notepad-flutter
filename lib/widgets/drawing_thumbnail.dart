import 'dart:math' as math;

import 'package:flutter/material.dart';

// Small preview of a handwritten note shown in the notes list.
class DrawingThumbnailPainter extends CustomPainter {
  final List<List<Offset>> strokes;

  const DrawingThumbnailPainter({required this.strokes});

  @override
  void paint(Canvas canvas, Size size) {
    if (strokes.isEmpty) return;

    var minX = double.infinity;
    var minY = double.infinity;
    var maxX = -double.infinity;
    var maxY = -double.infinity;

    for (final stroke in strokes) {
      for (final point in stroke) {
        minX = math.min(minX, point.dx);
        minY = math.min(minY, point.dy);
        maxX = math.max(maxX, point.dx);
        maxY = math.max(maxY, point.dy);
      }
    }

    if (!minX.isFinite || !minY.isFinite) return;

    final width = math.max(maxX - minX, 1);
    final height = math.max(maxY - minY, 1);

    final scale = math.min(
      (size.width - 4) / width,
      (size.height - 4) / height,
    );

    canvas.translate(
      (size.width - width * scale) / 2 - minX * scale,
      (size.height - height * scale) / 2 - minY * scale,
    );
    canvas.scale(scale);

    final paint = Paint()
      ..color = const Color(0xFF3E2723)
      ..strokeWidth = 1.5 / scale
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    for (final stroke in strokes) {
      if (stroke.isEmpty) continue;

      if (stroke.length == 1) {
        canvas.drawCircle(
          stroke.first,
          1.5 / scale,
          Paint()..color = const Color(0xFF3E2723),
        );
        continue;
      }

      final path = Path()..moveTo(stroke.first.dx, stroke.first.dy);

      for (var i = 1; i < stroke.length; i++) {
        path.lineTo(stroke[i].dx, stroke[i].dy);
      }

      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant DrawingThumbnailPainter oldDelegate) {
    return oldDelegate.strokes != strokes;
  }
}

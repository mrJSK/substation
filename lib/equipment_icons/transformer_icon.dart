// lib/equipment_icons/transformer_icon.dart

import 'package:flutter/material.dart';
import 'dart:math';

// Abstract base class for all equipment painters
abstract class EquipmentPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  // symbolSize represents the conceptual width/height of the *symbol itself*
  // not necessarily the CustomPaint widget's bounding box.
  // The actual drawing will be scaled to the 'size' argument of the paint method.
  final Size
  equipmentSize; // Renamed from symbolSize to equipmentSize for clarity

  EquipmentPainter({
    required this.color,
    this.strokeWidth = 2.5,
    required this.equipmentSize,
  });
}

class TransformerIconPainter extends EquipmentPainter {
  TransformerIconPainter({
    required super.color,
    super.strokeWidth,
    required super.equipmentSize,
    required Size symbolSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 'size' here is the actual rendering area
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    // We draw relative to the 'size' of the CustomPaint widget.
    // The equipmentSize is used to influence internal proportions if needed,
    // but the symbol itself should stretch to fill 'size' where appropriate.
    final double centerX = size.width / 2;
    final double centerY = size.height / 2;
    final double radius = min(size.width, size.height) / 3;

    // Three overlapping circles for 3-phase transformer
    canvas.drawCircle(Offset(centerX - radius / 2, centerY), radius, paint);
    canvas.drawCircle(Offset(centerX + radius / 2, centerY), radius, paint);
    canvas.drawCircle(
      Offset(centerX, centerY - radius * sqrt(3) / 2),
      radius,
      paint,
    );

    // // Input/Output lines (extend to the edges of the drawing area)
    // canvas.drawLine(
    //   Offset(centerX - radius / 2, centerY - radius),
    //   Offset(centerX - radius / 2, 0),
    //   paint,
    // );
    // canvas.drawLine(
    //   Offset(centerX + radius / 2, centerY - radius),
    //   Offset(centerX + radius + 10, 0),
    //   paint,
    // ); // Slight offset for visual distinctness
    canvas.drawLine(
      Offset(centerX, centerY + radius),
      Offset(centerX, size.height),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant TransformerIconPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.strokeWidth != strokeWidth ||
      oldDelegate.equipmentSize != equipmentSize;
}

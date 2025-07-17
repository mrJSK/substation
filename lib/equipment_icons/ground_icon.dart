// lib/equipment_icons/ground_icon.dart

import 'package:flutter/material.dart';
import 'package:substation_manager/equipment_icons/transformer_icon.dart'; // Import base EquipmentPainter

class GroundIconPainter extends EquipmentPainter {
  GroundIconPainter({
    required super.color,
    super.strokeWidth,
    required super.equipmentSize,
    required Size symbolSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final center = Offset(size.width / 2, size.height / 2);
    // Vertical line connecting to the symbol area
    canvas.drawLine(
      center.translate(0, -size.height * 0.4),
      center.translate(0, 0),
      paint,
    );
    // Ground lines (horizontal dashes, decreasing in length)
    canvas.drawLine(
      center.translate(-size.width * 0.3, 0),
      center.translate(size.width * 0.3, 0),
      paint,
    );
    canvas.drawLine(
      center.translate(-size.width * 0.2, size.height * 0.15),
      center.translate(size.width * 0.2, size.height * 0.15),
      paint,
    );
    canvas.drawLine(
      center.translate(-size.width * 0.1, size.height * 0.3),
      center.translate(size.width * 0.1, size.height * 0.3),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant GroundIconPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.strokeWidth != strokeWidth ||
      oldDelegate.equipmentSize != equipmentSize;
}

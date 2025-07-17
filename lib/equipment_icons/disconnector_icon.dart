// lib/equipment_icons/disconnector_icon.dart

import 'package:flutter/material.dart';
import 'package:substation_manager/equipment_icons/transformer_icon.dart'; // Import base EquipmentPainter

class DisconnectorIconPainter extends EquipmentPainter {
  DisconnectorIconPainter({
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

    final dotPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final double centerX = size.width / 2;
    final double centerY = size.height / 2;

    // Fixed connection points (top and bottom of the component's symbol area)
    // Lines extending from top/bottom to the blade pivot/contact area
    canvas.drawLine(
      Offset(centerX, 0),
      Offset(centerX, size.height * 0.2),
      paint,
    ); // Top connection line
    canvas.drawLine(
      Offset(centerX, size.height),
      Offset(centerX, size.height * 0.8),
      paint,
    ); // Bottom connection line

    // Draw the hinge (small circle at the top-left of the blade)
    final Offset hingePoint = Offset(
      centerX - size.width * 0.3,
      size.height * 0.2,
    ); // Adjust position
    canvas.drawCircle(hingePoint, 3, dotPaint);

    // Draw the blade (diagonal line from hinge to contact)
    final Offset bladeEndPoint = Offset(
      centerX + size.width * 0.3,
      size.height * 0.6,
    ); // Open position
    canvas.drawLine(hingePoint, bladeEndPoint, paint);

    // Draw the contact point (small square/line at the bottom-right of the blade)
    final double contactSize = 4;
    canvas.drawRect(
      Rect.fromLTWH(
        bladeEndPoint.dx - contactSize / 2,
        bladeEndPoint.dy - contactSize / 2,
        contactSize,
        contactSize,
      ),
      dotPaint,
    );
  }

  @override
  bool shouldRepaint(covariant DisconnectorIconPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.strokeWidth != strokeWidth ||
      oldDelegate.equipmentSize != equipmentSize;
}

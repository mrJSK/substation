// lib/equipment_icons/isolator_icon.dart

import 'package:flutter/material.dart';
import 'package:substation_manager/equipment_icons/transformer_icon.dart'; // Import base EquipmentPainter

class IsolatorIconPainter extends EquipmentPainter {
  IsolatorIconPainter({
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

    // Define points for the diagonal line representing the isolator
    final Offset startPoint = Offset(
      centerX - size.width * 0.4,
      size.height * 0.2,
    ); // Start near top-left
    final Offset endPoint = Offset(
      centerX + size.width * 0.4,
      size.height * 0.8,
    ); // End near bottom-right

    // Draw the diagonal line
    canvas.drawLine(startPoint, endPoint, paint);

    // Draw connection lines to the outside of the symbol area
    canvas.drawLine(
      Offset(centerX, 0),
      Offset(centerX, startPoint.dy),
      paint,
    ); // Line from top of CustomPaint to symbol start
    canvas.drawLine(
      Offset(centerX, size.height),
      Offset(centerX, endPoint.dy),
      paint,
    ); // Line from bottom of CustomPaint to symbol end

    // Optional: add a small square or dash at the top/bottom end of the line
    // to represent the fixed contact point.
    final double contactSize = 4;
    canvas.drawRect(
      Rect.fromLTWH(
        startPoint.dx - contactSize / 2,
        startPoint.dy - contactSize / 2,
        contactSize,
        contactSize,
      ),
      dotPaint,
    ); // Top contact
    canvas.drawRect(
      Rect.fromLTWH(
        endPoint.dx - contactSize / 2,
        endPoint.dy - contactSize / 2,
        contactSize,
        contactSize,
      ),
      dotPaint,
    ); // Bottom contact
  }

  @override
  bool shouldRepaint(covariant IsolatorIconPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.strokeWidth != strokeWidth ||
      oldDelegate.equipmentSize != equipmentSize;
}

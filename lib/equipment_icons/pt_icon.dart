// lib/equipment_icons/pt_icon.dart

import 'package:flutter/material.dart';
import 'package:substation_manager/equipment_icons/transformer_icon.dart';
import 'dart:math';

class PotentialTransformerIconPainter extends EquipmentPainter {
  PotentialTransformerIconPainter({
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

    final centerX = size.width / 2;
    final centerY = size.height / 2;
    final coilRadius = min(size.width, size.height) * 0.2;

    // Simple coil shape (two overlapping circles)
    canvas.drawCircle(
      Offset(centerX, centerY - coilRadius / 2),
      coilRadius,
      paint,
    );
    canvas.drawCircle(
      Offset(centerX, centerY + coilRadius / 2),
      coilRadius,
      paint,
    );

    // Primary lines (extend to the top/bottom of the CustomPaint widget)
    canvas.drawLine(
      Offset(centerX, 0),
      Offset(centerX, centerY - coilRadius),
      paint,
    );
    canvas.drawLine(
      Offset(centerX, size.height),
      Offset(centerX, centerY + coilRadius),
      paint,
    );

    // Draw "PT" text
    final textSpan = TextSpan(
      text: 'PT',
      style: TextStyle(
        color: color,
        fontSize: size.width * 0.25,
        fontWeight: FontWeight.bold,
      ),
    );
    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(centerX + coilRadius + 5, centerY - textPainter.height / 2),
    );
  }

  @override
  bool shouldRepaint(covariant PotentialTransformerIconPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.strokeWidth != strokeWidth ||
      oldDelegate.equipmentSize != equipmentSize;
}

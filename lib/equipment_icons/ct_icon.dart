// lib/equipment_icons/ct_icon.dart

import 'package:flutter/material.dart';
import 'package:substation_manager/equipment_icons/transformer_icon.dart';

class CurrentTransformerIconPainter extends EquipmentPainter {
  CurrentTransformerIconPainter({
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
    final coilWidth = size.width * 0.4;
    final coilHeight = size.height * 0.4;

    // "U" shape of the coil (simplified)
    final path = Path()
      ..moveTo(centerX - coilWidth / 2, centerY - coilHeight / 2)
      ..lineTo(centerX - coilWidth / 2, centerY + coilHeight / 2)
      ..lineTo(centerX + coilWidth / 2, centerY + coilHeight / 2)
      ..lineTo(centerX + coilWidth / 2, centerY - coilHeight / 2);
    canvas.drawPath(path, paint);

    // Primary lines (extend to the top/bottom of the CustomPaint widget)
    canvas.drawLine(
      Offset(centerX, 0),
      Offset(centerX, centerY - coilHeight / 2),
      paint,
    );
    canvas.drawLine(
      Offset(centerX, size.height),
      Offset(centerX, centerY + coilHeight / 2),
      paint,
    );

    // Draw "CT" text
    final textSpan = TextSpan(
      text: 'CT',
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
      Offset(centerX + coilWidth / 2 + 5, centerY - textPainter.height / 2),
    );
  }

  @override
  bool shouldRepaint(covariant CurrentTransformerIconPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.strokeWidth != strokeWidth ||
      oldDelegate.equipmentSize != equipmentSize;
}

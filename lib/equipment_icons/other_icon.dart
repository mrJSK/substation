// lib/equipment_icons/other_icon.dart

import 'package:flutter/material.dart';
import 'package:substation_manager/equipment_icons/transformer_icon.dart';

class OtherIconPainter extends EquipmentPainter {
  OtherIconPainter({
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
    final radius = size.width * 0.3;

    // Draw diamond shape (no fill for cleanliness)
    final path = Path();
    path.moveTo(centerX, centerY - radius);
    path.lineTo(centerX + radius, centerY);
    path.lineTo(centerX, centerY + radius);
    path.lineTo(centerX - radius, centerY);
    path.close();
    canvas.drawPath(path, paint);

    // Draw question mark inside (subtle)
    final textSpan = TextSpan(
      text: '?',
      style: TextStyle(
        color: color.withOpacity(0.7), // More subtle
        fontSize: size.width * 0.4,
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
      Offset(centerX - textPainter.width / 2, centerY - textPainter.height / 2),
    );

    // Connection lines (no shade)
    canvas.drawLine(
      Offset(centerX, 0),
      Offset(centerX, centerY - radius),
      paint,
    );
    canvas.drawLine(
      Offset(centerX, size.height),
      Offset(centerX, centerY + radius),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant OtherIconPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.strokeWidth != strokeWidth ||
      oldDelegate.equipmentSize != equipmentSize;
}

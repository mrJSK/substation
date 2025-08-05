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
    final colors =
        EquipmentPainter.equipmentColorScheme['Current Transformer']!;
    final strokePaint = createGradientPaint(size, colors, isFill: false);
    final shadowPaint = createShadowPaint();

    final centerX = size.width / 2;
    final centerY = size.height / 2;
    final coilWidth = size.width * 0.4;
    final coilHeight = size.height * 0.4;

    // Draw shadow for the coil
    final shadowPath = Path()
      ..moveTo(centerX - coilWidth / 2 + 2, centerY - coilHeight / 2 + 2)
      ..lineTo(centerX - coilWidth / 2 + 2, centerY + coilHeight / 2 + 2)
      ..lineTo(centerX + coilWidth / 2 + 2, centerY + coilHeight / 2 + 2)
      ..lineTo(centerX + coilWidth / 2 + 2, centerY - coilHeight / 2 + 2);
    canvas.drawPath(shadowPath, shadowPaint);

    // "U" shape of the coil with rounded corners
    final path = Path()
      ..moveTo(centerX - coilWidth / 2, centerY - coilHeight / 2)
      ..lineTo(centerX - coilWidth / 2, centerY + coilHeight / 2)
      ..quadraticBezierTo(
        centerX,
        centerY + coilHeight / 2 + coilWidth * 0.2,
        centerX + coilWidth / 2,
        centerY + coilHeight / 2,
      )
      ..lineTo(centerX + coilWidth / 2, centerY - coilHeight / 2);

    canvas.drawPath(path, strokePaint);

    // Primary lines with gradient
    canvas.drawLine(
      Offset(centerX, 0),
      Offset(centerX, centerY - coilHeight / 2),
      strokePaint,
    );
    canvas.drawLine(
      Offset(centerX, size.height),
      Offset(centerX, centerY + coilHeight / 2),
      strokePaint,
    );

    // Add core representation
    final corePaint = Paint()
      ..color = colors[1].withOpacity(0.3)
      ..style = PaintingStyle.fill;

    canvas.drawRect(
      Rect.fromCenter(
        center: Offset(centerX - coilWidth * 0.1, centerY),
        width: coilWidth * 0.2,
        height: coilHeight * 0.8,
      ),
      corePaint,
    );

    // Draw "CT" text with professional styling
    drawStyledText(
      canvas,
      'CT',
      Offset(centerX + coilWidth / 2 + 5, centerY - size.width * 0.125),
      colors[0],
      size.width * 0.25,
    );
  }

  @override
  bool shouldRepaint(covariant CurrentTransformerIconPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.strokeWidth != strokeWidth ||
      oldDelegate.equipmentSize != equipmentSize;
}

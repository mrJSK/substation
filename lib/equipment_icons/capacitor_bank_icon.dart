// lib/equipment_icons/capacitor_bank_icon.dart

import 'package:flutter/material.dart';
import 'package:substation_manager/equipment_icons/transformer_icon.dart';

class CapacitorBankIconPainter extends EquipmentPainter {
  CapacitorBankIconPainter({
    required super.color,
    super.strokeWidth,
    required super.equipmentSize,
    required Size symbolSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final colors = EquipmentPainter.equipmentColorScheme['Capacitor Bank']!;
    final strokePaint = createGradientPaint(size, colors, isFill: false);
    final shadowPaint = createShadowPaint();

    final centerX = size.width / 2;
    final centerY = size.height / 2;
    final plateLength = size.height * 0.4;
    final plateSpacing = size.width * 0.1;

    // Enhanced stroke paint with rounded caps
    strokePaint.strokeCap = StrokeCap.round;

    // Draw shadows for plates
    canvas.drawLine(
      Offset(centerX - plateSpacing / 2 + 1, centerY - plateLength / 2 + 1),
      Offset(centerX - plateSpacing / 2 + 1, centerY + plateLength / 2 + 1),
      shadowPaint..strokeWidth = strokeWidth,
    );
    canvas.drawLine(
      Offset(centerX + plateSpacing / 2 + 1, centerY - plateLength / 2 + 1),
      Offset(centerX + plateSpacing / 2 + 1, centerY + plateLength / 2 + 1),
      shadowPaint..strokeWidth = strokeWidth,
    );

    // Draw capacitor plates with gradient effect
    final platePaint = Paint()
      ..shader =
          LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: colors,
          ).createShader(
            Rect.fromLTWH(
              centerX - plateSpacing / 2 - strokeWidth,
              centerY - plateLength / 2,
              plateSpacing + strokeWidth * 2,
              plateLength,
            ),
          )
      ..strokeWidth = strokeWidth * 1.2
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    canvas.drawLine(
      Offset(centerX - plateSpacing / 2, centerY - plateLength / 2),
      Offset(centerX - plateSpacing / 2, centerY + plateLength / 2),
      platePaint,
    );
    canvas.drawLine(
      Offset(centerX + plateSpacing / 2, centerY - plateLength / 2),
      Offset(centerX + plateSpacing / 2, centerY + plateLength / 2),
      platePaint,
    );

    // Connection lines with enhanced styling
    canvas.drawLine(
      Offset(centerX, 0),
      Offset(centerX - plateSpacing / 2, centerY - plateLength / 2),
      strokePaint,
    );
    canvas.drawLine(
      Offset(centerX, size.height),
      Offset(centerX + plateSpacing / 2, centerY + plateLength / 2),
      strokePaint,
    );

    // Add dielectric representation (subtle line between plates)
    final dielectricPaint = Paint()
      ..color = colors[1].withOpacity(0.3)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    canvas.drawLine(
      Offset(centerX, centerY - plateLength / 2),
      Offset(centerX, centerY + plateLength / 2),
      dielectricPaint,
    );

    // Draw "C" text with enhanced styling
    drawStyledText(
      canvas,
      'C',
      Offset(centerX + plateSpacing / 2 + 8, centerY - size.width * 0.15),
      colors[0],
      size.width * 0.3,
    );
  }

  @override
  bool shouldRepaint(covariant CapacitorBankIconPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.strokeWidth != strokeWidth ||
      oldDelegate.equipmentSize != equipmentSize;
}

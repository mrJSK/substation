// lib/equipment_icons/relay_icon.dart

import 'package:flutter/material.dart';
import 'package:substation_manager/old_app/equipment_icons/transformer_icon.dart';

class RelayIconPainter extends EquipmentPainter {
  RelayIconPainter({
    required super.color,
    super.strokeWidth,
    required super.equipmentSize,
    required Size symbolSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final colors = EquipmentPainter.equipmentColorScheme['Relay']!;
    final strokePaint = createGradientPaint(size, colors, isFill: false);
    final fillPaint = createGradientPaint(size, colors, isFill: true);
    final shadowPaint = createShadowPaint();

    final centerX = size.width / 2;
    final centerY = size.height / 2;
    final rectWidth = size.width * 0.6;
    final rectHeight = size.height * 0.6;

    // Draw shadow
    final shadowRect = Rect.fromCenter(
      center: Offset(centerX + 2, centerY + 2),
      width: rectWidth,
      height: rectHeight,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(shadowRect, const Radius.circular(4)),
      shadowPaint,
    );

    // Draw rectangular relay body with rounded corners
    final rect = Rect.fromCenter(
      center: Offset(centerX, centerY),
      width: rectWidth,
      height: rectHeight,
    );
    final roundedRect = RRect.fromRectAndRadius(rect, const Radius.circular(4));

    canvas.drawRRect(
      roundedRect,
      fillPaint..color = colors[1].withOpacity(0.3),
    );
    canvas.drawRRect(roundedRect, strokePaint);

    // Draw relay contacts with enhanced styling
    final contactPaint = createGradientPaint(size, [
      colors[1],
      colors[0],
    ], isFill: true);
    final contactSize = size.width * 0.08;

    // Left contact
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(centerX - rectWidth * 0.2, centerY),
          width: contactSize,
          height: contactSize,
        ),
        const Radius.circular(2),
      ),
      contactPaint,
    );

    // Right contact
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(centerX + rectWidth * 0.2, centerY),
          width: contactSize,
          height: contactSize,
        ),
        const Radius.circular(2),
      ),
      contactPaint,
    );

    // Connection lines
    canvas.drawLine(
      Offset(centerX, 0),
      Offset(centerX, centerY - rectHeight / 2),
      strokePaint,
    );
    canvas.drawLine(
      Offset(centerX, size.height),
      Offset(centerX, centerY + rectHeight / 2),
      strokePaint,
    );

    // Add "R" label
    drawStyledText(
      canvas,
      'R',
      Offset(centerX - 6, centerY - 8),
      colors[0],
      size.width * 0.25,
    );
  }

  @override
  bool shouldRepaint(covariant RelayIconPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.strokeWidth != strokeWidth ||
      oldDelegate.equipmentSize != equipmentSize;
}

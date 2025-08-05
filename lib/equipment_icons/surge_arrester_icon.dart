// lib/equipment_icons/surge_arrester_icon.dart

import 'package:flutter/material.dart';
import 'package:substation_manager/equipment_icons/transformer_icon.dart';

class SurgeArresterIconPainter extends EquipmentPainter {
  SurgeArresterIconPainter({
    required super.color,
    super.strokeWidth,
    required super.equipmentSize,
    required Size symbolSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final colors = EquipmentPainter.equipmentColorScheme['Surge Arrester']!;
    final strokePaint = createGradientPaint(size, colors, isFill: false);
    final fillPaint = createGradientPaint(size, colors, isFill: true);
    final shadowPaint = createShadowPaint();

    final centerX = size.width / 2;
    final centerY = size.height / 2;
    final rectWidth = size.width * 0.4;
    final rectHeight = size.height * 0.5;

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

    // Draw main body with gradient fill
    final rect = Rect.fromCenter(
      center: Offset(centerX, centerY),
      width: rectWidth,
      height: rectHeight,
    );
    final roundedRect = RRect.fromRectAndRadius(rect, const Radius.circular(4));

    canvas.drawRRect(
      roundedRect,
      fillPaint..color = colors[1].withOpacity(0.2),
    );
    canvas.drawRRect(roundedRect, strokePaint);

    // Enhanced zigzag lightning pattern
    final zigzagPath = Path();
    final startY = centerY - rectHeight * 0.3;
    final endY = centerY + rectHeight * 0.3;
    final leftX = centerX - rectWidth * 0.15;
    final rightX = centerX + rectWidth * 0.15;
    final midY1 = startY + (endY - startY) * 0.25;
    final midY2 = startY + (endY - startY) * 0.5;
    final midY3 = startY + (endY - startY) * 0.75;

    zigzagPath.moveTo(leftX, startY);
    zigzagPath.lineTo(rightX, midY1);
    zigzagPath.lineTo(leftX, midY2);
    zigzagPath.lineTo(rightX, midY3);
    zigzagPath.lineTo(leftX, endY);

    // Lightning shadow
    final zigzagShadowPath = Path();
    zigzagShadowPath.moveTo(leftX + 1, startY + 1);
    zigzagShadowPath.lineTo(rightX + 1, midY1 + 1);
    zigzagShadowPath.lineTo(leftX + 1, midY2 + 1);
    zigzagShadowPath.lineTo(rightX + 1, midY3 + 1);
    zigzagShadowPath.lineTo(leftX + 1, endY + 1);

    canvas.drawPath(
      zigzagShadowPath,
      shadowPaint..strokeWidth = strokeWidth * 0.8,
    );

    // Lightning with gradient
    final lightningPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [colors[1], colors[0]],
      ).createShader(Rect.fromLTRB(leftX, startY, rightX, endY))
      ..strokeWidth = strokeWidth * 0.8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    canvas.drawPath(zigzagPath, lightningPaint);

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

    // Add terminal caps
    final capPaint = createGradientPaint(size, colors, isFill: true);

    // Top cap
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(centerX, centerY - rectHeight / 2),
          width: rectWidth * 0.8,
          height: strokeWidth * 2,
        ),
        const Radius.circular(2),
      ),
      capPaint,
    );

    // Bottom cap
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(centerX, centerY + rectHeight / 2),
          width: rectWidth * 0.8,
          height: strokeWidth * 2,
        ),
        const Radius.circular(2),
      ),
      capPaint,
    );
  }

  @override
  bool shouldRepaint(covariant SurgeArresterIconPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.strokeWidth != strokeWidth ||
      oldDelegate.equipmentSize != equipmentSize;
}

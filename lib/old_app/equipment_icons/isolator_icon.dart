// lib/equipment_icons/isolator_icon.dart

import 'package:flutter/material.dart';
import 'package:substation_manager/old_app/equipment_icons/transformer_icon.dart';

class IsolatorIconPainter extends EquipmentPainter {
  IsolatorIconPainter({
    required super.color,
    super.strokeWidth,
    required super.equipmentSize,
    required Size symbolSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final colors = EquipmentPainter.equipmentColorScheme['Isolator']!;
    final strokePaint = createGradientPaint(size, colors, isFill: false);
    final shadowPaint = createShadowPaint();

    final double centerX = size.width / 2;

    // Enhanced stroke paint
    strokePaint.strokeCap = StrokeCap.round;

    // Define points for the diagonal line
    final Offset startPoint = Offset(
      centerX - size.width * 0.4,
      size.height * 0.2,
    );
    final Offset endPoint = Offset(
      centerX + size.width * 0.4,
      size.height * 0.8,
    );

    // Connection lines with shadows (subtle)
    canvas.drawLine(
      Offset(centerX + 1, 1),
      Offset(centerX + 1, startPoint.dy + 1),
      shadowPaint..strokeWidth = strokeWidth * 0.5, // Lighter shadow
    );
    canvas.drawLine(
      Offset(centerX + 1, size.height + 1),
      Offset(centerX + 1, endPoint.dy + 1),
      shadowPaint..strokeWidth = strokeWidth * 0.5,
    );

    // Connection lines
    canvas.drawLine(
      Offset(centerX, 0),
      Offset(centerX, startPoint.dy),
      strokePaint,
    );
    canvas.drawLine(
      Offset(centerX, size.height),
      Offset(centerX, endPoint.dy),
      strokePaint,
    );

    // Diagonal line shadow (subtle)
    canvas.drawLine(
      Offset(startPoint.dx + 1, startPoint.dy + 1),
      Offset(endPoint.dx + 1, endPoint.dy + 1),
      shadowPaint..strokeWidth = strokeWidth * 0.8,
    );

    // Diagonal line with gradient
    final bladePaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: colors,
      ).createShader(Rect.fromPoints(startPoint, endPoint))
      ..strokeWidth = strokeWidth * 1.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    canvas.drawLine(startPoint, endPoint, bladePaint);

    // Contact points with enhanced styling (no background fill)
    final double contactSize = 5;

    // Top contact shadow (subtle)
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(startPoint.dx + 1, startPoint.dy + 1),
          width: contactSize,
          height: contactSize,
        ),
        const Radius.circular(2),
      ),
      shadowPaint..color = shadowPaint.color.withOpacity(0.1), // More subtle
    );

    // Bottom contact shadow (subtle)
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(endPoint.dx + 1, endPoint.dy + 1),
          width: contactSize,
          height: contactSize,
        ),
        const Radius.circular(2),
      ),
      shadowPaint..color = shadowPaint.color.withOpacity(0.1),
    );

    // Top contact (no fill, just stroke)
    final topContactRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: startPoint,
        width: contactSize,
        height: contactSize,
      ),
      const Radius.circular(2),
    );
    canvas.drawRRect(topContactRect, strokePaint..style = PaintingStyle.stroke);

    // Bottom contact (no fill, just stroke)
    final bottomContactRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: endPoint,
        width: contactSize,
        height: contactSize,
      ),
      const Radius.circular(2),
    );
    canvas.drawRRect(
      bottomContactRect,
      strokePaint..style = PaintingStyle.stroke,
    );

    // Removed insulator body representation for cleanliness
  }

  @override
  bool shouldRepaint(covariant IsolatorIconPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.strokeWidth != strokeWidth ||
      oldDelegate.equipmentSize != equipmentSize;
}

// lib/equipment_icons/ground_icon.dart

import 'package:flutter/material.dart';
import 'package:substation_manager/old_app/equipment_icons/transformer_icon.dart';

class GroundIconPainter extends EquipmentPainter {
  GroundIconPainter({
    required super.color,
    super.strokeWidth,
    required super.equipmentSize,
    required Size symbolSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final colors = EquipmentPainter.equipmentColorScheme['Ground']!;
    final strokePaint = createGradientPaint(size, colors, isFill: false);
    final shadowPaint = createShadowPaint();

    final center = Offset(size.width / 2, size.height / 2);

    // Enhanced stroke paint
    strokePaint.strokeCap = StrokeCap.round;

    // Vertical line with shadow
    canvas.drawLine(
      center.translate(1, -size.height * 0.4 + 1),
      center.translate(1, 1),
      shadowPaint..strokeWidth = strokeWidth,
    );

    // Vertical line
    canvas.drawLine(
      center.translate(0, -size.height * 0.4),
      center.translate(0, 0),
      strokePaint,
    );

    // Ground lines with enhanced styling and gradients
    final groundLines = [
      {
        'width': size.width * 0.6,
        'offset': 0.0,
        'thickness': strokeWidth * 1.2,
      },
      {
        'width': size.width * 0.4,
        'offset': size.height * 0.15,
        'thickness': strokeWidth,
      },
      {
        'width': size.width * 0.2,
        'offset': size.height * 0.3,
        'thickness': strokeWidth * 0.8,
      },
    ];

    for (var line in groundLines) {
      final width = line['width'] as double;
      final offset = line['offset'] as double;
      final thickness = line['thickness'] as double;

      // Shadow for ground line
      canvas.drawLine(
        center.translate(-width / 2 + 1, offset + 1),
        center.translate(width / 2 + 1, offset + 1),
        shadowPaint..strokeWidth = thickness,
      );

      // Ground line with gradient
      final groundPaint = Paint()
        ..shader =
            LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: colors,
            ).createShader(
              Rect.fromCenter(
                center: center.translate(0, offset),
                width: width,
                height: thickness,
              ),
            )
        ..strokeWidth = thickness
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;

      canvas.drawLine(
        center.translate(-width / 2, offset),
        center.translate(width / 2, offset),
        groundPaint,
      );
    }

    // Add ground symbol enhancement (small triangles)
    final trianglePaint = Paint()
      ..color = colors[1].withOpacity(0.3)
      ..style = PaintingStyle.fill;

    for (int i = 0; i < 3; i++) {
      final triangleOffset = size.height * 0.45 + (i * size.height * 0.08);
      final triangleSize = 3.0 - (i * 0.5);

      final trianglePath = Path()
        ..moveTo(center.dx, center.dy + triangleOffset)
        ..lineTo(
          center.dx - triangleSize,
          center.dy + triangleOffset + triangleSize,
        )
        ..lineTo(
          center.dx + triangleSize,
          center.dy + triangleOffset + triangleSize,
        )
        ..close();

      canvas.drawPath(trianglePath, trianglePaint);
    }
  }

  @override
  bool shouldRepaint(covariant GroundIconPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.strokeWidth != strokeWidth ||
      oldDelegate.equipmentSize != equipmentSize;
}

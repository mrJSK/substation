import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:ui' as ui;
import '../painters/single_line_diagram_painter.dart';
import '../controllers/sld_controller.dart';
import '../models/bay_model.dart';
import '../utils/snackbar_utils.dart';
import '../enums/movement_mode.dart';

class SldViewWidget extends StatelessWidget {
  final bool isEnergySld;
  final bool isCapturingPdf;
  final Function(Bay, Offset)? onBayTapped;

  const SldViewWidget({
    super.key,
    this.isEnergySld = false,
    this.isCapturingPdf = false,
    this.onBayTapped,
  });

  static const double _contentPadding = 120.0;
  static const double _topPadding = 100.0;

  @override
  Widget build(BuildContext context) {
    final sldController = Provider.of<SldController>(context);
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    if (sldController.bayRenderDataList.isEmpty) {
      return Container(
        width: double.infinity,
        height: double.infinity,
        color: Colors.white,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.electrical_services,
                size: 64,
                color: Colors.grey.shade400,
              ),
              const SizedBox(height: 16),
              Text(
                'No SLD Data Available',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final contentBounds = _calculateContentBounds(sldController);

    final double canvasWidth = max(contentBounds.width, 800);
    final double canvasHeight = max(contentBounds.height, 600);

    if (isCapturingPdf) {
      return Container(
        width: canvasWidth,
        height: canvasHeight,
        decoration: const BoxDecoration(color: Colors.white),
        child: CustomPaint(
          size: Size(canvasWidth, canvasHeight),
          painter: _createPainter(
            sldController,
            colorScheme,
            isPdfMode: true,
            contentBounds: contentBounds,
          ),
        ),
      );
    }

    return Container(
      width: canvasWidth,
      height: canvasHeight,
      color: Colors.white,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapUp: onBayTapped != null
            ? (details) => _handleTapUp(context, details, sldController)
            : null,
        onLongPressStart: onBayTapped != null
            ? (details) => _handleLongPress(context, details, sldController)
            : null,
        child: CustomPaint(
          size: Size(canvasWidth, canvasHeight),
          painter: _createPainter(
            sldController,
            colorScheme,
            isPdfMode: false,
            contentBounds: contentBounds,
          ),
        ),
      ),
    );
  }

  ContentBounds _calculateContentBounds(SldController sldController) {
    double minX = double.infinity;
    double minY = double.infinity;
    double maxX = double.negativeInfinity;
    double maxY = double.negativeInfinity;

    for (var renderData in sldController.bayRenderDataList) {
      final rect = renderData.rect;
      minX = min(minX, rect.left);
      minY = min(minY, rect.top);
      maxX = max(maxX, rect.right);
      maxY = max(maxY, rect.bottom);

      final textBounds = _calculateTextBounds(renderData);
      minX = min(minX, textBounds.left);
      minY = min(minY, textBounds.top);
      maxX = max(maxX, textBounds.right);
      maxY = max(maxY, textBounds.bottom);

      if (isEnergySld &&
          sldController.showEnergyReadings &&
          sldController.bayEnergyData.containsKey(renderData.bay.id)) {
        final energyBounds = _calculateEnergyReadingBounds(renderData);
        minX = min(minX, energyBounds.left);
        minY = min(minY, energyBounds.top);
        maxX = max(maxX, energyBounds.right);
        maxY = max(maxY, energyBounds.bottom);
      }
    }

    if (!minX.isFinite ||
        !minY.isFinite ||
        !maxX.isFinite ||
        !maxY.isFinite ||
        (maxX - minX) <= 0 ||
        (maxY - minY) <= 0) {
      return ContentBounds(
        minX: 0,
        minY: 0,
        maxX: 800,
        maxY: 600,
        width: 800 + 2 * _contentPadding,
        height: 600 + 2 * _contentPadding,
        originOffset: Offset(_contentPadding, _contentPadding),
      );
    }

    final width = (maxX - minX) + 2 * _contentPadding;
    final height = (maxY - minY) + 2 * _contentPadding;
    final originOffset = Offset(
      -minX + _contentPadding,
      -minY + _contentPadding,
    );

    return ContentBounds(
      minX: minX,
      minY: minY,
      maxX: maxX,
      maxY: maxY,
      width: width,
      height: height,
      originOffset: originOffset,
    );
  }

  Rect _calculateTextBounds(dynamic renderData) {
    final TextPainter textPainter = TextPainter(
      text: TextSpan(
        text: _getBayDisplayText(renderData),
        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
      ),
      textDirection: ui.TextDirection.ltr,
    )..layout();

    Offset textPosition;
    switch (renderData.bay.bayType) {
      case 'Busbar':
        textPosition = renderData.rect.centerLeft + renderData.textOffset;
        textPosition = Offset(
          textPosition.dx - textPainter.width,
          textPosition.dy - textPainter.height / 2,
        );
        break;
      case 'Transformer':
        textPosition = renderData.rect.centerLeft + renderData.textOffset;
        textPosition = Offset(
          textPosition.dx - 150,
          textPosition.dy - textPainter.height / 2 - 20,
        );
        break;
      case 'Line':
        textPosition = renderData.rect.topCenter + renderData.textOffset;
        textPosition = Offset(
          textPosition.dx - textPainter.width / 2,
          textPosition.dy - 12,
        );
        break;
      case 'Feeder':
        textPosition = renderData.rect.bottomCenter + renderData.textOffset;
        textPosition = Offset(
          textPosition.dx - textPainter.width / 2,
          textPosition.dy + 4,
        );
        break;
      default:
        textPosition = renderData.rect.center + renderData.textOffset;
        textPosition = Offset(
          textPosition.dx - textPainter.width / 2,
          textPosition.dy - textPainter.height / 2,
        );
    }

    return Rect.fromLTWH(
      textPosition.dx,
      textPosition.dy,
      textPainter.width,
      textPainter.height,
    );
  }

  Rect _calculateEnergyReadingBounds(dynamic renderData) {
    const double estimatedMaxEnergyTextWidth = 120.0;
    const double estimatedTotalEnergyTextHeight = 12 * 8;

    Offset energyTextBasePosition;
    switch (renderData.bay.bayType) {
      case 'Busbar':
        energyTextBasePosition = Offset(
          renderData.rect.right - 80,
          renderData.rect.center.dy - (estimatedTotalEnergyTextHeight / 2),
        );
        break;
      case 'Transformer':
        energyTextBasePosition = Offset(
          renderData.rect.centerLeft.dx - 70,
          renderData.rect.center.dy - 10,
        );
        break;
      case 'Line':
        energyTextBasePosition = Offset(
          renderData.rect.center.dx - 75,
          renderData.rect.top + 10,
        );
        break;
      case 'Feeder':
        energyTextBasePosition = Offset(
          renderData.rect.center.dx - 70,
          renderData.rect.bottom - 40,
        );
        break;
      default:
        energyTextBasePosition = Offset(
          renderData.rect.right + 15,
          renderData.rect.center.dy - 20,
        );
    }

    energyTextBasePosition =
        energyTextBasePosition +
        (renderData.energyReadingOffset ?? Offset.zero);

    return Rect.fromLTWH(
      energyTextBasePosition.dx,
      energyTextBasePosition.dy,
      estimatedMaxEnergyTextWidth,
      estimatedTotalEnergyTextHeight,
    );
  }

  String _getBayDisplayText(dynamic renderData) {
    switch (renderData.bay.bayType) {
      case 'Busbar':
        return '${renderData.voltageLevel} ${renderData.bayName}';
      case 'Transformer':
        return '${renderData.bayName} T/F\n${renderData.bay.make ?? ''}';
      case 'Line':
        return '${renderData.voltageLevel} ${renderData.bayName} Line';
      case 'Feeder':
        return renderData.bayName;
      default:
        return renderData.bayName;
    }
  }

  SingleLineDiagramPainter _createPainter(
    SldController sldController,
    ColorScheme colorScheme, {
    required bool isPdfMode,
    ContentBounds? contentBounds,
  }) {
    return SingleLineDiagramPainter(
      showEnergyReadings: sldController.showEnergyReadings,
      bayRenderDataList: sldController.bayRenderDataList,
      bayConnections: sldController.allConnections,
      baysMap: sldController.baysMap,
      createDummyBayRenderData: sldController.createDummyBayRenderData,
      busbarRects: sldController.busbarRects,
      busbarConnectionPoints: sldController.busbarConnectionPoints,
      debugDrawHitboxes: !isPdfMode,
      selectedBayForMovementId: isPdfMode
          ? null
          : sldController.selectedBayForMovementId,
      bayEnergyData: sldController.bayEnergyData,
      busEnergySummary: sldController.busEnergySummary,
      contentBounds: isPdfMode && contentBounds != null
          ? Size(
              contentBounds.maxX - contentBounds.minX,
              contentBounds.maxY - contentBounds.minY,
            )
          : null,
      originOffsetForPdf: isPdfMode && contentBounds != null
          ? contentBounds.originOffset
          : null,
      defaultBayColor: colorScheme.onSurface,
      defaultLineFeederColor: colorScheme.onSurface,
      transformerColor: colorScheme.primary,
      connectionLineColor: colorScheme.onSurface,
    );
  }

  void _handleTapUp(
    BuildContext context,
    TapUpDetails details,
    SldController sldController,
  ) {
    try {
      final RenderBox? renderBox = context.findRenderObject() as RenderBox?;
      if (renderBox == null) return;

      final Offset localPosition = renderBox.globalToLocal(
        details.globalPosition,
      );
      final Bay? tappedBay = _findBayAtPosition(localPosition, sldController);

      if (tappedBay != null && tappedBay.id != 'dummy' && onBayTapped != null) {
        onBayTapped!(tappedBay, details.globalPosition);
      }
    } catch (e) {
      print('DEBUG: Error handling tap: $e');
    }
  }

  void _handleLongPress(
    BuildContext context,
    LongPressStartDetails details,
    SldController sldController,
  ) {
    try {
      final RenderBox? renderBox = context.findRenderObject() as RenderBox?;
      if (renderBox == null) return;

      final Offset localPosition = renderBox.globalToLocal(
        details.globalPosition,
      );
      final Bay? tappedBay = _findBayAtPosition(localPosition, sldController);

      if (tappedBay != null && tappedBay.id != 'dummy' && onBayTapped != null) {
        onBayTapped!(tappedBay, details.globalPosition);
      }
    } catch (e) {
      print('DEBUG: Error handling long press: $e');
    }
  }

  Bay? _findBayAtPosition(Offset position, SldController sldController) {
    for (var renderData in sldController.bayRenderDataList) {
      if (renderData.rect.contains(position)) {
        return renderData.bay;
      }
    }
    return null;
  }
}

class ContentBounds {
  final double minX;
  final double minY;
  final double maxX;
  final double maxY;
  final double width;
  final double height;
  final Offset originOffset;

  ContentBounds({
    required this.minX,
    required this.minY,
    required this.maxX,
    required this.maxY,
    required this.width,
    required this.height,
    required this.originOffset,
  });
}

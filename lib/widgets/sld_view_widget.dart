import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:ui'
    as ui; // Alias to avoid conflict with flutter/material.dart's TextDirection

import '../painters/single_line_diagram_painter.dart';
import '../controllers/sld_controller.dart';
import '../models/bay_model.dart';
import '../utils/snackbar_utils.dart'; // For SnackBarUtils
import '../enums/movement_mode.dart';

class SldViewWidget extends StatelessWidget {
  final bool
  isEnergySld; // To differentiate between normal SLD and energy SLD views
  final Function(Bay, Offset)? onBayTapped; // Callback for bay interactions

  const SldViewWidget({super.key, this.isEnergySld = false, this.onBayTapped});

  @override
  Widget build(BuildContext context) {
    // Watch the SldController for changes
    final sldController = Provider.of<SldController>(context);
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    // Calculate content bounds for canvas size
    double minXForContent = double.infinity;
    double minYForContent = double.infinity;
    double maxXForContent = double.negativeInfinity;
    double maxYForContent = double.negativeInfinity;

    if (sldController.bayRenderDataList.isNotEmpty) {
      for (var renderData in sldController.bayRenderDataList) {
        minXForContent = min(minXForContent, renderData.rect.left);
        minYForContent = min(minYForContent, renderData.rect.top);
        maxXForContent = max(maxXForContent, renderData.rect.right);
        maxYForContent = max(maxYForContent, renderData.rect.bottom);

        // Account for text bounds (simplified for brevity, actual measurement might be needed)
        final TextPainter textPainter = TextPainter(
          text: TextSpan(
            text: renderData.bay.name,
            style: const TextStyle(fontSize: 10),
          ),
          textDirection: ui.TextDirection.ltr,
        )..layout();

        Offset potentialTextTopLeft = Offset.zero;
        if (renderData.bay.bayType == 'Busbar') {
          potentialTextTopLeft =
              renderData.rect.centerLeft + renderData.textOffset;
          // Approximate adjustment for right-aligned busbar text
          potentialTextTopLeft = Offset(
            potentialTextTopLeft.dx - textPainter.width,
            potentialTextTopLeft.dy,
          );
        } else if (renderData.bay.bayType == 'Transformer') {
          potentialTextTopLeft =
              renderData.rect.centerLeft + renderData.textOffset;
          // Adjusted for multi-line transformer text (assuming default width for multi-line is 150)
          potentialTextTopLeft = Offset(
            potentialTextTopLeft.dx - 150,
            potentialTextTopLeft.dy - textPainter.height / 2 - 20,
          );
        } else {
          potentialTextTopLeft = renderData.rect.center + renderData.textOffset;
          potentialTextTopLeft = Offset(
            potentialTextTopLeft.dx - textPainter.width / 2,
            potentialTextTopLeft.dy - textPainter.height / 2,
          );
        }
        minXForContent = min(minXForContent, potentialTextTopLeft.dx);
        minYForContent = min(minYForContent, potentialTextTopLeft.dy);
        maxXForContent = max(
          maxXForContent,
          potentialTextTopLeft.dx + textPainter.width,
        );
        maxYForContent = max(
          maxYForContent,
          potentialTextTopLeft.dy + textPainter.height,
        );

        // Account for energy reading text bounds if in energy mode
        if (isEnergySld) {
          if (sldController.bayEnergyData.containsKey(renderData.bay.id)) {
            final Offset readingOffset = renderData.energyReadingOffset;
            const double estimatedMaxEnergyTextWidth = 100;
            const double estimatedTotalEnergyTextHeight =
                12 * 7; // Approx. lines * height

            Offset energyTextBasePosition;
            if (renderData.bay.bayType == 'Busbar') {
              energyTextBasePosition = Offset(
                renderData.rect.right - estimatedMaxEnergyTextWidth - 10,
                renderData.rect.center.dy -
                    (estimatedTotalEnergyTextHeight / 2),
              );
            } else if (renderData.bay.bayType == 'Transformer') {
              energyTextBasePosition = Offset(
                renderData.rect.centerLeft.dx -
                    estimatedMaxEnergyTextWidth -
                    10,
                renderData.rect.center.dy -
                    (estimatedTotalEnergyTextHeight / 2),
              );
            } else {
              energyTextBasePosition = Offset(
                renderData.rect.right + 15,
                renderData.rect.center.dy -
                    (estimatedTotalEnergyTextHeight / 2),
              );
            }
            energyTextBasePosition = energyTextBasePosition + readingOffset;

            minXForContent = min(minXForContent, energyTextBasePosition.dx);
            minYForContent = min(minYForContent, energyTextBasePosition.dy);
            maxXForContent = max(
              maxXForContent,
              energyTextBasePosition.dx + estimatedMaxEnergyTextWidth,
            );
            maxYForContent = max(
              maxYForContent,
              energyTextBasePosition.dy + estimatedTotalEnergyTextHeight,
            );
          }
        }
      }
    }

    if (!minXForContent.isFinite ||
        !minYForContent.isFinite ||
        !maxXForContent.isFinite ||
        !maxYForContent.isFinite ||
        (maxXForContent - minXForContent) <= 0 ||
        (maxYForContent - minYForContent) <= 0) {
      minXForContent = 0;
      minYForContent = 0;
      maxXForContent = 400;
      maxYForContent = 300;
    }

    const double contentPaddingForCanvas = 50.0;
    final double effectiveContentWidth =
        (maxXForContent - minXForContent) + 2 * contentPaddingForCanvas;
    final double effectiveContentHeight =
        (maxYForContent - minYForContent) + 2 * contentPaddingForCanvas;
    final Offset originOffsetForPainter = Offset(
      -minXForContent + contentPaddingForCanvas,
      -minYForContent + contentPaddingForCanvas,
    );

    final double canvasWidth = max(
      MediaQuery.of(context).size.width,
      effectiveContentWidth,
    );
    final double canvasHeight = max(
      MediaQuery.of(context).size.height,
      effectiveContentHeight,
    );

    return InteractiveViewer(
      transformationController: sldController.transformationController,
      boundaryMargin: const EdgeInsets.all(double.infinity),
      minScale: 0.1,
      maxScale: 4.0,
      constrained: false,
      child: GestureDetector(
        onTapUp: (details) {
          final RenderBox renderBox = context.findRenderObject() as RenderBox;
          final Offset localPosition = renderBox.globalToLocal(
            details.globalPosition,
          );
          final scenePosition = sldController.transformationController.toScene(
            localPosition,
          );

          final tappedBay = sldController.bayRenderDataList.firstWhere(
            (data) => data.rect.contains(scenePosition),
            orElse: sldController.createDummyBayRenderData,
          );

          if (tappedBay.bay.id != 'dummy' && onBayTapped != null) {
            onBayTapped!(tappedBay.bay, details.globalPosition);
          }
        },
        onLongPressStart: (details) {
          final RenderBox renderBox = context.findRenderObject() as RenderBox;
          final Offset localPosition = renderBox.globalToLocal(
            details.globalPosition,
          );
          final scenePosition = sldController.transformationController.toScene(
            localPosition,
          );

          final tappedBay = sldController.bayRenderDataList.firstWhere(
            (data) => data.rect.contains(scenePosition),
            orElse: sldController.createDummyBayRenderData,
          );
          if (tappedBay.bay.id != 'dummy' && onBayTapped != null) {
            onBayTapped!(tappedBay.bay, details.globalPosition);
          }
        },
        child: CustomPaint(
          size: Size(canvasWidth, canvasHeight),
          painter: SingleLineDiagramPainter(
            bayRenderDataList: sldController.bayRenderDataList,
            bayConnections: sldController.allConnections,
            baysMap: sldController.baysMap,
            createDummyBayRenderData: sldController.createDummyBayRenderData,
            busbarRects: sldController.busbarRects,
            busbarConnectionPoints: sldController.busbarConnectionPoints,
            debugDrawHitboxes: true, // Can be toggled for debug
            selectedBayForMovementId: sldController.selectedBayForMovementId,
            bayEnergyData: sldController.bayEnergyData, // Pass the energy data
            busEnergySummary:
                sldController.busEnergySummary, // Pass the bus energy summary
            contentBounds: null, // For interactive viewer, this should be null
            originOffsetForPdf:
                null, // For interactive viewer, this should be null
            defaultBayColor: colorScheme.onSurface,
            defaultLineFeederColor: colorScheme.onSurface,
            transformerColor: colorScheme.primary,
            connectionLineColor: colorScheme.onSurface,
          ),
        ),
      ),
    );
  }
}

// lib/widgets/sld_view_widget.dart
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
  final bool isCapturingPdf; // NEW: Added to handle PDF capture mode
  final Function(Bay, Offset)? onBayTapped; // Callback for bay interactions

  const SldViewWidget({
    super.key,
    this.isEnergySld = false,
    this.isCapturingPdf = false, // NEW: Default to false
    this.onBayTapped,
  });

  @override
  Widget build(BuildContext context) {
    // Watch the SldController for changes
    final sldController = Provider.of<SldController>(context);
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    // Early return if no data available
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

    // Calculate content bounds for canvas size
    double minXForContent = double.infinity;
    double minYForContent = double.infinity;
    double maxXForContent = double.negativeInfinity;
    double maxYForContent = double.negativeInfinity;

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

      // UPDATED: Account for energy reading text bounds if in energy mode and readings are visible
      if (isEnergySld && sldController.showEnergyReadings) {
        if (sldController.bayEnergyData.containsKey(renderData.bay.id)) {
          final Offset readingOffset = renderData.energyReadingOffset;
          const double estimatedMaxEnergyTextWidth = 100;
          const double estimatedTotalEnergyTextHeight =
              12 * 7; // Approx. lines * height

          Offset energyTextBasePosition;
          if (renderData.bay.bayType == 'Busbar') {
            energyTextBasePosition = Offset(
              renderData.rect.right - estimatedMaxEnergyTextWidth - 10,
              renderData.rect.center.dy - (estimatedTotalEnergyTextHeight / 2),
            );
          } else if (renderData.bay.bayType == 'Transformer') {
            energyTextBasePosition = Offset(
              renderData.rect.centerLeft.dx - estimatedMaxEnergyTextWidth - 10,
              renderData.rect.center.dy - (estimatedTotalEnergyTextHeight / 2),
            );
          } else {
            energyTextBasePosition = Offset(
              renderData.rect.right + 15,
              renderData.rect.center.dy - (estimatedTotalEnergyTextHeight / 2),
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

    // Fallback bounds if calculations fail
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

    // UPDATED: Conditional InteractiveViewer - disabled during PDF capture
    if (isCapturingPdf) {
      // For PDF capture, return the CustomPaint directly without InteractiveViewer
      return Container(
        width: canvasWidth,
        height: canvasHeight,
        color: Colors.white,
        child: CustomPaint(
          size: Size(canvasWidth, canvasHeight),
          painter: SingleLineDiagramPainter(
            showEnergyReadings: sldController.showEnergyReadings,
            bayRenderDataList: sldController.bayRenderDataList,
            bayConnections: sldController.allConnections,
            baysMap: sldController.baysMap,
            createDummyBayRenderData: sldController.createDummyBayRenderData,
            busbarRects: sldController.busbarRects,
            busbarConnectionPoints: sldController.busbarConnectionPoints,
            debugDrawHitboxes: false, // Disable debug for PDF
            selectedBayForMovementId: null, // No selection during PDF capture
            bayEnergyData: sldController.bayEnergyData,
            busEnergySummary: sldController.busEnergySummary,
            contentBounds: Size(
              maxXForContent - minXForContent,
              maxYForContent - minYForContent,
            ),
            originOffsetForPdf: originOffsetForPainter,
            defaultBayColor: colorScheme.onSurface,
            defaultLineFeederColor: colorScheme.onSurface,
            transformerColor: colorScheme.primary,
            connectionLineColor: colorScheme.onSurface,
          ),
        ),
      );
    }

    // UPDATED: Normal interactive view with gesture handling
    return InteractiveViewer(
      // REMOVED: transformationController - handled by parent screen
      boundaryMargin: const EdgeInsets.all(double.infinity),
      minScale: 0.1,
      maxScale: 4.0,
      constrained: false,
      child: GestureDetector(
        onTapUp: onBayTapped != null
            ? (details) => _handleTapUp(context, details, sldController)
            : null,
        onLongPressStart: onBayTapped != null
            ? (details) => _handleLongPress(context, details, sldController)
            : null,
        child: Container(
          width: canvasWidth,
          height: canvasHeight,
          color: Colors.white,
          child: CustomPaint(
            size: Size(canvasWidth, canvasHeight),
            painter: SingleLineDiagramPainter(
              showEnergyReadings: sldController.showEnergyReadings,
              bayRenderDataList: sldController.bayRenderDataList,
              bayConnections: sldController.allConnections,
              baysMap: sldController.baysMap,
              createDummyBayRenderData: sldController.createDummyBayRenderData,
              busbarRects: sldController.busbarRects,
              busbarConnectionPoints: sldController.busbarConnectionPoints,
              debugDrawHitboxes:
                  !isCapturingPdf, // Show hitboxes in normal mode
              selectedBayForMovementId: sldController.selectedBayForMovementId,
              bayEnergyData: sldController.bayEnergyData,
              busEnergySummary: sldController.busEnergySummary,
              contentBounds:
                  null, // For interactive viewer, this should be null
              originOffsetForPdf:
                  null, // For interactive viewer, this should be null
              defaultBayColor: colorScheme.onSurface,
              defaultLineFeederColor: colorScheme.onSurface,
              transformerColor: colorScheme.primary,
              connectionLineColor: colorScheme.onSurface,
            ),
          ),
        ),
      ),
    );
  }

  // UPDATED: Improved tap handling with proper coordinate transformation
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

      // For SldViewWidget without its own transformation controller,
      // we use the local position directly
      final Offset scenePosition = localPosition;

      final tappedBay = sldController.bayRenderDataList.firstWhere((data) {
        // Adjust the rect position based on the origin offset
        final adjustedRect = data.rect.translate(
          50.0,
          50.0,
        ); // Account for padding
        return adjustedRect.contains(scenePosition);
      }, orElse: sldController.createDummyBayRenderData);

      if (tappedBay.bay.id != 'dummy' && onBayTapped != null) {
        onBayTapped!(tappedBay.bay, details.globalPosition);
      }
    } catch (e) {
      print('DEBUG: Error handling tap: $e');
    }
  }

  // UPDATED: Improved long press handling
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

      // For SldViewWidget without its own transformation controller,
      // we use the local position directly
      final Offset scenePosition = localPosition;

      final tappedBay = sldController.bayRenderDataList.firstWhere((data) {
        // Adjust the rect position based on the origin offset
        final adjustedRect = data.rect.translate(
          50.0,
          50.0,
        ); // Account for padding
        return adjustedRect.contains(scenePosition);
      }, orElse: sldController.createDummyBayRenderData);

      if (tappedBay.bay.id != 'dummy' && onBayTapped != null) {
        onBayTapped!(tappedBay.bay, details.globalPosition);
      }
    } catch (e) {
      print('DEBUG: Error handling long press: $e');
    }
  }
}

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

class SldViewWidget extends StatefulWidget {
  final bool
  isEnergySld; // To differentiate between normal SLD and energy SLD views
  final bool isCapturingPdf; // New parameter for PDF capture mode
  final Function(Bay, Offset)? onBayTapped; // Callback for bay interactions

  const SldViewWidget({
    super.key,
    this.isEnergySld = false,
    this.isCapturingPdf = false,
    this.onBayTapped,
  });

  @override
  State<SldViewWidget> createState() => _SldViewWidgetState();
}

class _SldViewWidgetState extends State<SldViewWidget> {
  late TransformationController _transformationController;
  String? _selectedBayId;

  @override
  void initState() {
    super.initState();
    _transformationController = TransformationController();
    // Set initial scale to fit content after widget is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fitContentToView();
    });
  }

  void _fitContentToView() {
    if (!mounted) return;

    final RenderBox? renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final size = renderBox.size;
    if (size.width <= 0 || size.height <= 0) return;

    final sldController = Provider.of<SldController>(context, listen: false);

    // Calculate content bounds
    final contentBounds = _calculateContentBounds(sldController);
    if (contentBounds.width <= 0 || contentBounds.height <= 0) return;

    // Calculate scale to fit with padding
    const padding = 100.0;
    final scaleX = (size.width - padding) / contentBounds.width;
    final scaleY = (size.height - padding) / contentBounds.height;
    final scale = min(scaleX, scaleY).clamp(0.1, 2.0);

    // Calculate translation to center content
    final scaledContentWidth = contentBounds.width * scale;
    final scaledContentHeight = contentBounds.height * scale;
    final translateX =
        (size.width - scaledContentWidth) / 2 - contentBounds.left * scale;
    final translateY =
        (size.height - scaledContentHeight) / 2 - contentBounds.top * scale;

    _transformationController.value = Matrix4.identity()
      ..translate(translateX, translateY)
      ..scale(scale);
  }

  Rect _calculateContentBounds(SldController sldController) {
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

        // Account for text bounds
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
          potentialTextTopLeft = Offset(
            potentialTextTopLeft.dx - textPainter.width,
            potentialTextTopLeft.dy,
          );
        } else if (renderData.bay.bayType == 'Transformer') {
          potentialTextTopLeft =
              renderData.rect.centerLeft + renderData.textOffset;
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
        if (widget.isEnergySld) {
          if (sldController.bayEnergyData.containsKey(renderData.bay.id)) {
            final Offset readingOffset = renderData.energyReadingOffset;
            const double estimatedMaxEnergyTextWidth = 100;
            const double estimatedTotalEnergyTextHeight = 12 * 7;

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

    // Fallback bounds if calculations fail
    if (!minXForContent.isFinite ||
        !minYForContent.isFinite ||
        !maxXForContent.isFinite ||
        !maxYForContent.isFinite ||
        (maxXForContent - minXForContent) <= 0 ||
        (maxYForContent - minYForContent) <= 0) {
      return const Rect.fromLTWH(0, 0, 800, 600);
    }

    return Rect.fromLTRB(
      minXForContent,
      minYForContent,
      maxXForContent,
      maxYForContent,
    );
  }

  void _handleBayTap(Bay bay, Offset globalPosition) {
    if (widget.isCapturingPdf) return; // Disable interactions during capture

    setState(() {
      _selectedBayId = _selectedBayId == bay.id ? null : bay.id;
    });

    if (widget.onBayTapped != null) {
      widget.onBayTapped!(bay, globalPosition);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sldController = Provider.of<SldController>(context);
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    // Calculate content bounds for canvas size
    final contentBounds = _calculateContentBounds(sldController);

    const double contentPaddingForCanvas = 50.0;
    final double effectiveContentWidth =
        contentBounds.width + 2 * contentPaddingForCanvas;
    final double effectiveContentHeight =
        contentBounds.height + 2 * contentPaddingForCanvas;

    final Offset originOffsetForPainter = Offset(
      -contentBounds.left + contentPaddingForCanvas,
      -contentBounds.top + contentPaddingForCanvas,
    );

    // For capture mode, use exact content dimensions
    if (widget.isCapturingPdf) {
      return Container(
        width: effectiveContentWidth,
        height: effectiveContentHeight,
        color: Colors.white,
        child: CustomPaint(
          size: Size(effectiveContentWidth, effectiveContentHeight),
          painter: SingleLineDiagramPainter(
            bayRenderDataList: sldController.bayRenderDataList,
            bayConnections: sldController.allConnections,
            baysMap: sldController.baysMap,
            createDummyBayRenderData: sldController.createDummyBayRenderData,
            busbarRects: sldController.busbarRects,
            busbarConnectionPoints: sldController.busbarConnectionPoints,
            debugDrawHitboxes: false, // Disable debug mode for capture
            selectedBayForMovementId: null, // No selection during capture
            bayEnergyData: sldController.bayEnergyData,
            busEnergySummary: sldController.busEnergySummary,
            contentBounds: Size(contentBounds.width, contentBounds.height),
            originOffsetForPdf: originOffsetForPainter,
            defaultBayColor: colorScheme.onSurface,
            defaultLineFeederColor: colorScheme.onSurface,
            transformerColor: colorScheme.primary,
            connectionLineColor: colorScheme.onSurface,
            isCapturing: true, // New parameter for capture mode
          ),
        ),
      );
    }

    // Interactive mode - use screen dimensions with InteractiveViewer
    final double canvasWidth = max(
      MediaQuery.of(context).size.width,
      effectiveContentWidth,
    );
    final double canvasHeight = max(
      MediaQuery.of(context).size.height,
      effectiveContentHeight,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        return InteractiveViewer(
          transformationController: widget.isCapturingPdf
              ? TransformationController() // Reset transformation for capture
              : (sldController.transformationController ??
                    _transformationController),
          boundaryMargin: const EdgeInsets.all(50.0),
          minScale: 0.1,
          maxScale: 5.0,
          constrained: false,
          child: GestureDetector(
            onTapUp: widget.isCapturingPdf
                ? null
                : (details) {
                    final RenderBox renderBox =
                        context.findRenderObject() as RenderBox;
                    final Offset localPosition = renderBox.globalToLocal(
                      details.globalPosition,
                    );
                    final transformationController =
                        sldController.transformationController ??
                        _transformationController;
                    final scenePosition = transformationController.toScene(
                      localPosition,
                    );

                    final tappedBay = sldController.bayRenderDataList
                        .firstWhere(
                          (data) => data.rect.contains(scenePosition),
                          orElse: sldController.createDummyBayRenderData,
                        );

                    if (tappedBay.bay.id != 'dummy') {
                      _handleBayTap(tappedBay.bay, details.globalPosition);
                    }
                  },
            onLongPressStart: widget.isCapturingPdf
                ? null
                : (details) {
                    final RenderBox renderBox =
                        context.findRenderObject() as RenderBox;
                    final Offset localPosition = renderBox.globalToLocal(
                      details.globalPosition,
                    );
                    final transformationController =
                        sldController.transformationController ??
                        _transformationController;
                    final scenePosition = transformationController.toScene(
                      localPosition,
                    );

                    final tappedBay = sldController.bayRenderDataList
                        .firstWhere(
                          (data) => data.rect.contains(scenePosition),
                          orElse: sldController.createDummyBayRenderData,
                        );

                    if (tappedBay.bay.id != 'dummy') {
                      _handleBayTap(tappedBay.bay, details.globalPosition);
                    }
                  },
            child: Container(
              width: canvasWidth,
              height: canvasHeight,
              child: CustomPaint(
                size: Size(canvasWidth, canvasHeight),
                painter: SingleLineDiagramPainter(
                  bayRenderDataList: sldController.bayRenderDataList,
                  bayConnections: sldController.allConnections,
                  baysMap: sldController.baysMap,
                  createDummyBayRenderData:
                      sldController.createDummyBayRenderData,
                  busbarRects: sldController.busbarRects,
                  busbarConnectionPoints: sldController.busbarConnectionPoints,
                  debugDrawHitboxes: false, // Set to false for production
                  selectedBayForMovementId: widget.isCapturingPdf
                      ? null
                      : sldController.selectedBayForMovementId,
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
                  isCapturing: false,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }
}

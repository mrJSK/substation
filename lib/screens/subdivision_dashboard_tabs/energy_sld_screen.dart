import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'dart:math' as math;

import '../../controllers/sld_controller.dart';
import '../../models/energy_readings_data.dart';
import '../../models/saved_sld_model.dart';
import '../../models/user_model.dart';
import '../../services/energy_data_service.dart';
import '../../utils/energy_sld_utils.dart';
import '../../utils/pdf_generator.dart';
import '../../utils/snackbar_utils.dart';
import '../../widgets/energy_movement_controls_widget.dart';
import '../../widgets/energy_speed_dial_widget.dart';
import '../../widgets/energy_tables_widget.dart';
import '../../widgets/sld_view_widget.dart';

class EnergySldScreen extends StatefulWidget {
  final String substationId;
  final String substationName;
  final AppUser currentUser;
  final SavedSld? savedSld;

  const EnergySldScreen({
    super.key,
    required this.substationId,
    required this.substationName,
    required this.currentUser,
    this.savedSld,
  });

  /// Add this getter to indicate this is always an energy SLD
  bool get isEnergySld => true;

  @override
  State<EnergySldScreen> createState() => _EnergySldScreenState();
}

class _EnergySldScreenState extends State<EnergySldScreen> {
  bool _isLoading = true;
  bool _isCapturingPdf = false;
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 1));
  DateTime _endDate = DateTime.now();
  bool _showTables = true;
  bool _isViewingSavedSld = false;
  late final EnergyDataService _energyDataService;

  final GlobalKey _sldRepaintBoundaryKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _energyDataService = EnergyDataService(
      substationId: widget.substationId,
      currentUser: widget.currentUser,
    );
    _isViewingSavedSld = widget.savedSld != null;

    if (_isViewingSavedSld) {
      _initializeFromSavedSld();
    } else {
      _loadEnergyData();
    }
  }

  void _initializeFromSavedSld() {
    _startDate = widget.savedSld!.startDate.toDate();
    _endDate = widget.savedSld!.endDate.toDate();
    _loadEnergyData(fromSaved: true);
  }

  Future<void> _loadEnergyData({bool fromSaved = false}) async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final sldController = Provider.of<SldController>(context, listen: false);

      if (fromSaved && widget.savedSld != null) {
        await _energyDataService.loadFromSavedSld(
          widget.savedSld!,
          sldController,
        );
      } else {
        await _energyDataService.loadLiveEnergyData(
          _startDate,
          _endDate,
          sldController,
        );
      }

      // Debug the loaded data
      print('DEBUG: SLD Controller after data load:');
      print('DEBUG: Bay count: ${sldController.allBays.length}');
      print(
        'DEBUG: Bay energy data count: ${sldController.bayEnergyData.length}',
      );
      print(
        'DEBUG: Bus energy summary count: ${sldController.busEnergySummary.length}',
      );

      // Wait for widget tree to settle after data load
      await Future.delayed(const Duration(milliseconds: 300));
    } catch (e) {
      if (mounted) {
        SnackBarUtils.showSnackBar(
          context,
          'Failed to load energy data: $e',
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Enhanced SLD image capture with detailed debugging
  Future<Uint8List?> captureSldAsImage() async {
    try {
      print('DEBUG: Starting SLD image capture...');
      print(
        'DEBUG: Checking RepaintBoundary key: ${_sldRepaintBoundaryKey.toString()}',
      );

      // Ensure we're not already capturing
      if (_isCapturingPdf) {
        print('DEBUG: Already capturing, returning null');
        return null;
      }

      // Check if the key has a current context
      if (_sldRepaintBoundaryKey.currentContext == null) {
        print('DEBUG ERROR: RepaintBoundary key has no current context');
        print(
          'DEBUG: This means the RepaintBoundary widget is not in the widget tree',
        );
        return null;
      }

      print('DEBUG: RepaintBoundary context found, getting RenderObject...');

      // Get the RenderObject
      final RenderObject? renderObject = _sldRepaintBoundaryKey.currentContext!
          .findRenderObject();

      if (renderObject == null) {
        print('DEBUG ERROR: RenderObject is null');
        return null;
      }

      if (renderObject is! RenderRepaintBoundary) {
        print('DEBUG ERROR: RenderObject is not a RenderRepaintBoundary');
        print('DEBUG: Actual type: ${renderObject.runtimeType}');
        return null;
      }

      final RenderRepaintBoundary boundary = renderObject;
      print('DEBUG: RenderRepaintBoundary found successfully');

      // Check if boundary needs painting
      if (boundary.debugNeedsPaint) {
        print('DEBUG: Boundary needs paint, waiting...');
        await Future.delayed(const Duration(milliseconds: 200));
        await WidgetsBinding.instance.endOfFrame;
      }

      // Set capture state
      if (mounted) {
        setState(() {
          _isCapturingPdf = true;
        });

        // Wait for UI to update
        await WidgetsBinding.instance.endOfFrame;
        await Future.delayed(const Duration(milliseconds: 100));
      }

      // Calculate content bounds for optimal pixel ratio
      final contentBounds = _calculateContentBounds();
      final pixelRatio = _calculateOptimalPixelRatio(contentBounds);

      print('DEBUG: Capturing with pixel ratio: $pixelRatio');
      print('DEBUG: Content bounds: $contentBounds');

      // Capture the image
      final image = await boundary.toImage(pixelRatio: pixelRatio);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);

      // Reset capture state
      if (mounted) {
        setState(() {
          _isCapturingPdf = false;
        });
      }

      if (byteData != null) {
        final bytes = byteData.buffer.asUint8List();
        print('DEBUG: Successfully captured SLD image: ${bytes.length} bytes');

        // Validate the captured image
        try {
          final codec = await ui.instantiateImageCodec(bytes);
          final frame = await codec.getNextFrame();
          print(
            'DEBUG: Image validation successful - dimensions: ${frame.image.width} x ${frame.image.height}',
          );
        } catch (e) {
          print('DEBUG WARNING: Could not validate captured image: $e');
        }

        return bytes;
      }

      print('DEBUG ERROR: ByteData is null after image capture');
      return null;
    } catch (e, stackTrace) {
      print('DEBUG ERROR: Exception in captureSldAsImage: $e');
      print('DEBUG ERROR: Stack trace: $stackTrace');

      if (mounted) {
        setState(() {
          _isCapturingPdf = false;
        });
      }
      return null;
    }
  }

  /// Calculate optimal pixel ratio to balance quality vs memory
  double _calculateOptimalPixelRatio(Rect contentBounds) {
    const double maxDimension = 4000.0;
    final double maxContentDimension = math.max(
      contentBounds.width,
      contentBounds.height,
    );

    if (maxContentDimension <= 0) return 2.0;

    final double optimalRatio = maxDimension / maxContentDimension;
    final double finalRatio = math.min(
      optimalRatio,
      6.0,
    ); // Cap at 6.0 for memory

    print(
      'DEBUG: Calculated pixel ratio: $finalRatio for content dimension: $maxContentDimension',
    );
    return finalRatio;
  }

  /// Calculate content bounds for proper capture sizing
  Rect _calculateContentBounds() {
    try {
      final sldController = Provider.of<SldController>(context, listen: false);

      if (sldController.bayRenderDataList.isEmpty) {
        return const Rect.fromLTWH(0, 0, 800, 600);
      }

      double minX = double.infinity;
      double minY = double.infinity;
      double maxX = double.negativeInfinity;
      double maxY = double.negativeInfinity;

      bool hasValidPositions = false;

      // Calculate bounds based on bay render data
      for (final renderData in sldController.bayRenderDataList) {
        hasValidPositions = true;

        // Account for bay rectangle
        minX = math.min(minX, renderData.rect.left);
        minY = math.min(minY, renderData.rect.top);
        maxX = math.max(maxX, renderData.rect.right);
        maxY = math.max(maxY, renderData.rect.bottom);

        // Account for text bounds
        final textBounds = _calculateTextBounds(renderData);
        minX = math.min(minX, textBounds.left);
        minY = math.min(minY, textBounds.top);
        maxX = math.max(maxX, textBounds.right);
        maxY = math.max(maxY, textBounds.bottom);

        // Account for energy reading bounds if applicable
        if (widget.isEnergySld &&
            sldController.bayEnergyData.containsKey(renderData.bay.id)) {
          final energyBounds = _calculateEnergyTextBounds(renderData);
          minX = math.min(minX, energyBounds.left);
          minY = math.min(minY, energyBounds.top);
          maxX = math.max(maxX, energyBounds.right);
          maxY = math.max(maxY, energyBounds.bottom);
        }
      }

      // If no valid positions found, use default bounds
      if (!hasValidPositions ||
          !minX.isFinite ||
          !minY.isFinite ||
          !maxX.isFinite ||
          !maxY.isFinite) {
        return const Rect.fromLTWH(0, 0, 800, 600);
      }

      // Add padding for labels and connections
      const padding = 150.0;
      final bounds = Rect.fromLTRB(
        minX - padding,
        minY - padding,
        maxX + padding,
        maxY + padding,
      );

      // Ensure minimum size
      const minWidth = 800.0;
      const minHeight = 600.0;

      if (bounds.width < minWidth || bounds.height < minHeight) {
        final center = bounds.center;
        final width = math.max(bounds.width, minWidth);
        final height = math.max(bounds.height, minHeight);

        return Rect.fromCenter(center: center, width: width, height: height);
      }

      return bounds;
    } catch (e) {
      print('DEBUG ERROR: Error calculating content bounds: $e');
      return const Rect.fromLTWH(0, 0, 800, 600);
    }
  }

  Rect _calculateTextBounds(dynamic renderData) {
    try {
      final TextPainter textPainter = TextPainter(
        text: TextSpan(
          text: renderData.bay.name,
          style: const TextStyle(fontSize: 10),
        ),
        textDirection: ui.TextDirection.ltr,
      )..layout();

      Offset textTopLeft = Offset.zero;
      if (renderData.bay.bayType == 'Busbar') {
        textTopLeft = renderData.rect.centerLeft + renderData.textOffset;
        textTopLeft = Offset(
          textTopLeft.dx - textPainter.width,
          textTopLeft.dy - textPainter.height / 2,
        );
      } else if (renderData.bay.bayType == 'Transformer') {
        textTopLeft = renderData.rect.centerLeft + renderData.textOffset;
        textTopLeft = Offset(
          textTopLeft.dx - 150,
          textTopLeft.dy - textPainter.height / 2 - 20,
        );
      } else {
        textTopLeft = renderData.rect.center + renderData.textOffset;
        textTopLeft = Offset(
          textTopLeft.dx - textPainter.width / 2,
          textTopLeft.dy - textPainter.height / 2,
        );
      }

      return Rect.fromLTWH(
        textTopLeft.dx,
        textTopLeft.dy,
        textPainter.width,
        textPainter.height,
      );
    } catch (e) {
      return renderData.rect;
    }
  }

  Rect _calculateEnergyTextBounds(dynamic renderData) {
    try {
      const double estimatedMaxEnergyTextWidth = 120;
      const double estimatedTotalEnergyTextHeight = 12 * 8;

      Offset energyTextPosition;
      if (renderData.bay.bayType == 'Busbar') {
        energyTextPosition = Offset(
          renderData.rect.right - estimatedMaxEnergyTextWidth - 10,
          renderData.rect.center.dy - (estimatedTotalEnergyTextHeight / 2),
        );
      } else if (renderData.bay.bayType == 'Transformer') {
        energyTextPosition = Offset(
          renderData.rect.centerLeft.dx - estimatedMaxEnergyTextWidth - 10,
          renderData.rect.center.dy - (estimatedTotalEnergyTextHeight / 2),
        );
      } else {
        energyTextPosition = Offset(
          renderData.rect.right + 15,
          renderData.rect.center.dy - (estimatedTotalEnergyTextHeight / 2),
        );
      }

      energyTextPosition = energyTextPosition + renderData.energyReadingOffset;

      return Rect.fromLTWH(
        energyTextPosition.dx,
        energyTextPosition.dy,
        estimatedMaxEnergyTextWidth,
        estimatedTotalEnergyTextHeight,
      );
    } catch (e) {
      return renderData.rect;
    }
  }

  /// Direct PDF generation method with proper image data flow
  Future<void> generateAndSharePdf() async {
    print('DEBUG: Starting generateAndSharePdf method...');

    if (_isLoading) {
      print('DEBUG: Cannot generate PDF - still loading SLD data');
      SnackBarUtils.showSnackBar(
        context,
        'Please wait for SLD to load completely',
        isError: true,
      );
      return;
    }

    if (_isCapturingPdf) {
      print('DEBUG: Cannot generate PDF - already capturing PDF in progress');
      SnackBarUtils.showSnackBar(
        context,
        'PDF generation already in progress',
        isError: true,
      );
      return;
    }

    try {
      print('DEBUG: All checks passed, starting PDF generation process');

      // Show progress indicator
      print('DEBUG: Showing progress snackbar to user');
      SnackBarUtils.showSnackBar(context, 'Generating PDF...');

      print('DEBUG: Accessing SldController via Provider');
      final sldController = Provider.of<SldController>(context, listen: false);
      print('DEBUG: SldController accessed successfully');
      print('DEBUG: SldController bay count: ${sldController.allBays.length}');
      print(
        'DEBUG: SldController has energy data: ${sldController.bayEnergyData.isNotEmpty}',
      );

      print('DEBUG: Starting SLD image capture...');
      final sldImageBytes = await captureSldAsImage();

      if (sldImageBytes == null) {
        print('DEBUG ERROR: captureSldAsImage returned null');
        throw Exception(
          'Failed to capture SLD image - captureSldAsImage returned null',
        );
      }

      if (sldImageBytes.isEmpty) {
        print('DEBUG ERROR: captureSldAsImage returned empty bytes array');
        throw Exception('Failed to capture SLD image - empty bytes array');
      }

      print('DEBUG: SLD image captured successfully');
      print('DEBUG: Captured image size: ${sldImageBytes.length} bytes');
      print(
        'DEBUG: First 20 bytes: ${sldImageBytes.take(20).toList()}',
      ); // Extra validation

      // Validate image bytes
      try {
        final codec = await ui.instantiateImageCodec(sldImageBytes);
        final frame = await codec.getNextFrame();
        print(
          'DEBUG: Image validation successful - dimensions: ${frame.image.width}x${frame.image.height}',
        );
      } catch (e) {
        print('DEBUG WARNING: Could not validate captured image: $e');
      }

      print('DEBUG: Creating PdfGeneratorData with captured image bytes');

      // CRITICAL: Build the PDF data properly
      final pdfData = PdfGeneratorData(
        substationName: widget.substationName,
        dateRange:
            '${DateFormat('dd-MMM-yyyy').format(_startDate)} to ${DateFormat('dd-MMM-yyyy').format(_endDate)}',
        sldImageBytes: sldImageBytes, // ENSURE THIS IS PASSED
        abstractEnergyData: _buildAbstractEnergyData(sldController),
        busEnergySummaryData: _buildBusEnergySummaryData(sldController),
        aggregatedFeederData: _buildAggregatedFeederData(sldController),
        assessmentsForPdf: _buildAssessmentsForPdf(sldController),
        uniqueBusVoltages: _getUniqueBusVoltages(sldController),
        allBaysInSubstation: sldController.allBays,
        baysMap: sldController.baysMap,
        uniqueDistributionSubdivisionNames: [], // Add if needed
      );

      print(
        'DEBUG: PdfGeneratorData created with image bytes: ${pdfData.sldImageBytes.length}',
      );
      print('DEBUG: Calling PdfGenerator.generateEnergyReportPdf directly');

      final pdfBytes = await PdfGenerator.generateEnergyReportPdf(pdfData);

      print(
        'DEBUG: PDF generated successfully, size: ${pdfBytes.length} bytes',
      );

      // Share PDF
      final timestamp = DateFormat('yyyy-MM-dd_HH-mm').format(DateTime.now());
      final filename =
          'Energy_SLD_${widget.substationName.replaceAll(' ', '_')}_$timestamp.pdf';

      print('DEBUG: Sharing PDF with filename: $filename');
      await PdfGenerator.sharePdf(
        pdfBytes,
        filename,
        'Energy SLD Report - ${widget.substationName}',
      );

      print('DEBUG: PDF shared successfully');

      if (mounted) {
        print('DEBUG: Widget still mounted, updating UI');
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        SnackBarUtils.showSnackBar(context, 'PDF generated successfully!');
      }
    } catch (e, stackTrace) {
      print('DEBUG ERROR: Exception caught in generateAndSharePdf');
      print('DEBUG ERROR: Exception type: ${e.runtimeType}');
      print('DEBUG ERROR: Exception message: $e');
      print('DEBUG ERROR: Stack trace: $stackTrace');

      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();

        String errorMessage = 'Error generating PDF';
        if (e.toString().contains('TooManyPagesException')) {
          errorMessage = 'PDF content too large - please try with less data';
        } else if (e.toString().contains('Memory')) {
          errorMessage =
              'Not enough memory to generate PDF - try reducing image size';
        }

        SnackBarUtils.showSnackBar(context, errorMessage, isError: true);
      }
    }
  }

  // Helper methods to build PDF data
  Map<String, dynamic> _buildAbstractEnergyData(SldController sldController) {
    return sldController.abstractEnergyData.isNotEmpty
        ? sldController.abstractEnergyData
        : {
            'totalImp': 100.0,
            'totalExp': -50.0,
            'difference': 150.0,
            'lossPercentage': 150.0,
          };
  }

  Map<String, Map<String, double>> _buildBusEnergySummaryData(
    SldController sldController,
  ) {
    if (sldController.busEnergySummary.isNotEmpty) {
      return sldController.busEnergySummary;
    }

    // Fallback data if empty
    Map<String, Map<String, double>> fallback = {};
    for (var bay in sldController.allBays.where((b) => b.bayType == 'Busbar')) {
      fallback[bay.id] = {'totalImp': 0.0, 'totalExp': 0.0, 'difference': 0.0};
    }
    return fallback;
  }

  List<AggregatedFeederEnergyData> _buildAggregatedFeederData(
    SldController sldController,
  ) {
    final data = sldController.aggregatedFeederEnergyData;

    print('DEBUG: Aggregated feeder data type: ${data.runtimeType}');
    print('DEBUG: Aggregated feeder data length: ${data?.length ?? 0}');

    if (data == null || data.isEmpty) {
      print('DEBUG: No aggregated feeder data available');
      return [];
    }

    // Debug first item to understand the actual type
    if (data.isNotEmpty) {
      print('DEBUG: First item type: ${data.first.runtimeType}');
      print('DEBUG: First item content: ${data.first}');
    }

    try {
      // Handle different possible types
      List<AggregatedFeederEnergyData> result = [];

      for (var item in data) {
        if (item is AggregatedFeederEnergyData) {
          result.add(item);
        } else if (item is Map<String, dynamic>) {
          try {
            result.add(
              AggregatedFeederEnergyData.fromMap(item as Map<String, dynamic>),
            );
          } catch (e) {
            print(
              'DEBUG ERROR: Failed to create AggregatedFeederEnergyData from map: $e',
            );
          }
        } else {
          print(
            'DEBUG WARNING: Skipping item of unexpected type: ${item.runtimeType}',
          );
        }
      }

      print(
        'DEBUG: Successfully converted ${result.length} aggregated feeder data items',
      );
      return result;
    } catch (e) {
      print('DEBUG ERROR: Failed to build aggregated feeder data: $e');
      return [];
    }
  }

  List<Map<String, dynamic>> _buildAssessmentsForPdf(
    SldController sldController,
  ) {
    return _energyDataService.allAssessmentsForDisplay.map((assessment) {
      Map<String, dynamic> assessmentMap = assessment.toFirestore();
      assessmentMap['bayName'] =
          sldController.baysMap[assessment.bayId]?.name ?? 'Unknown';
      return assessmentMap;
    }).toList();
  }

  List<String> _getUniqueBusVoltages(SldController sldController) {
    List<String> voltages = sldController.allBays
        .where((bay) => bay.bayType == 'Busbar')
        .map((bay) => bay.voltageLevel)
        .toSet()
        .toList();

    voltages.sort((a, b) {
      double getVoltage(String v) {
        final regex = RegExp(r'(\d+(\.\d+)?)');
        final match = regex.firstMatch(v);
        return match != null ? double.tryParse(match.group(1)!) ?? 0.0 : 0.0;
      }

      return getVoltage(b).compareTo(getVoltage(a));
    });

    return voltages.isNotEmpty ? voltages : ['132kV', '33kV'];
  }

  Future<void> _selectDate(BuildContext context) async {
    if (_isViewingSavedSld) return;

    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
    );

    if (picked != null &&
        (picked.start != _startDate || picked.end != _endDate)) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
      await _loadEnergyData();
    }
  }

  Future<void> _handleBackPress() async {
    final sldController = Provider.of<SldController>(context, listen: false);

    if (sldController.hasUnsavedChanges()) {
      final result = await showDialog<String>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          // Remove the default title and create custom header with X button
          title: null,
          titlePadding: EdgeInsets.zero,
          contentPadding: EdgeInsets.zero,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Custom header with title and X button
              Container(
                padding: const EdgeInsets.fromLTRB(24, 24, 16, 16),
                child: Row(
                  children: [
                    Icon(
                      Icons.save_outlined,
                      color: Theme.of(context).colorScheme.primary,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Save Changes?',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    // X button in top-right corner
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: () => Navigator.of(context).pop('cancel'),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          child: Icon(
                            Icons.close,
                            color: Colors.grey.shade600,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Content section
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'You have unsaved layout changes. What would you like to do?',
                      style: TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: Colors.blue.shade700,
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Saving will update the layout for all users',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.blue.shade700,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          // Updated actions without Cancel button
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop('discard'),
              child: Text(
                'Discard Changes',
                style: TextStyle(
                  color: Colors.red.shade600,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop('save'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
              child: const Text('Save & Exit'),
            ),
          ],
          actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        ),
      );

      // Rest of the method remains the same
      if (result == 'save') {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => Dialog(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(
                    strokeWidth: 3,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 20),
                  const Text('Saving changes...'),
                ],
              ),
            ),
          ),
        );

        try {
          final success = await sldController.saveAllPendingChanges();

          if (mounted) {
            Navigator.of(context).pop();

            if (success) {
              SnackBarUtils.showSnackBar(
                context,
                'Layout changes saved successfully!',
              );
              Navigator.of(context).pop();
            } else {
              SnackBarUtils.showSnackBar(
                context,
                'Failed to save changes. Please try again.',
                isError: true,
              );
            }
          }
        } catch (e) {
          if (mounted) {
            Navigator.of(context).pop();
            SnackBarUtils.showSnackBar(
              context,
              'Error saving changes: $e',
              isError: true,
            );
          }
        }
      } else if (result == 'discard') {
        sldController.cancelLayoutChanges();
        SnackBarUtils.showSnackBar(context, 'Changes discarded');
        if (mounted) Navigator.of(context).pop();
      }
    } else {
      Navigator.of(context).pop();
    }
  }

  String get _dateRangeText {
    if (_startDate.isAtSameMomentAs(_endDate)) {
      return DateFormat('dd-MMM-yyyy').format(_startDate);
    } else {
      return '${DateFormat('dd-MMM-yyyy').format(_startDate)} to ${DateFormat('dd-MMM-yyyy').format(_endDate)}';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.substationId.isEmpty) {
      return Scaffold(
        backgroundColor: const Color(0xFFFAFAFA),
        body: _buildEmptyState(),
      );
    }

    final sldController = Provider.of<SldController>(context);

    return PopScope(
      canPop: !sldController.hasUnsavedChanges(),
      onPopInvoked: (didPop) async {
        if (!didPop) {
          await _handleBackPress();
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFFAFAFA),
        appBar: _buildAppBar(sldController),
        body: _buildBodyWithRepaintBoundary(
          sldController,
        ), // NEW: Dedicated method
        bottomNavigationBar: _buildBottomNavigationBar(sldController),
      ),
    );
  }

  // NEW: Dedicated method to ensure RepaintBoundary is properly placed
  Widget _buildBodyWithRepaintBoundary(SldController sldController) {
    return Stack(
      children: [
        if (_isLoading)
          _buildLoadingState()
        else
          // CRITICAL: RepaintBoundary must wrap the actual SLD content
          RepaintBoundary(
            key: _sldRepaintBoundaryKey,
            child: Column(
              children: [
                Expanded(
                  child: Container(
                    width: double.infinity,
                    height: double.infinity,
                    color: Colors.white, // Ensure solid background for capture
                    child: SldViewWidget(
                      isEnergySld: true,
                      isCapturingPdf: _isCapturingPdf,
                      onBayTapped: _isCapturingPdf
                          ? null
                          : (bay, tapPosition) {
                              if (sldController.selectedBayForMovementId ==
                                  null) {
                                EnergySldUtils.showBayActions(
                                  context,
                                  bay,
                                  tapPosition,
                                  sldController,
                                  _isViewingSavedSld,
                                  _energyDataService,
                                );
                              }
                            },
                    ),
                  ),
                ),
                // Tables OUTSIDE RepaintBoundary to avoid capture issues
              ],
            ),
          ),

        // Tables as overlay when needed
        if (_showTables && !_isCapturingPdf && !_isLoading)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              height: 300,
              child: EnergyTablesWidget(
                isViewingSavedSld: _isViewingSavedSld,
                loadedAssessmentsSummary:
                    _energyDataService.loadedAssessmentsSummary,
                allAssessmentsForDisplay:
                    _energyDataService.allAssessmentsForDisplay,
              ),
            ),
          ),

        // FAB outside RepaintBoundary
        if (!_isCapturingPdf && !_isLoading)
          _buildFloatingActionButton(sldController),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(32),
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.electrical_services,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              'No Substation Selected',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Please select a substation to view energy SLD.',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            strokeWidth: 3,
            valueColor: AlwaysStoppedAnimation<Color>(
              Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Loading energy data...',
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Please wait while we fetch the latest information',
            style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(SldController sldController) {
    final hasUnsavedChanges = sldController.hasUnsavedChanges();

    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      leading: IconButton(
        icon: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: hasUnsavedChanges
                ? Colors.orange.withOpacity(0.1)
                : Theme.of(context).colorScheme.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            Icons.arrow_back_ios,
            color: hasUnsavedChanges
                ? Colors.orange.shade700
                : Theme.of(context).colorScheme.primary,
            size: 18,
          ),
        ),
        onPressed: _handleBackPress,
        tooltip: hasUnsavedChanges
            ? 'Back (Unsaved Changes)'
            : 'Back to Dashboard',
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Energy Account',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              if (hasUnsavedChanges) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'MODIFIED',
                    style: TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange.shade700,
                    ),
                  ),
                ),
              ],
            ],
          ),
          Text(
            '${widget.substationName} ($_dateRangeText)',
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _isViewingSavedSld
                  ? Colors.grey.withOpacity(0.1)
                  : Theme.of(context).colorScheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.calendar_today,
              color: _isViewingSavedSld
                  ? Colors.grey.shade600
                  : Theme.of(context).colorScheme.primary,
              size: 20,
            ),
          ),
          onPressed: _isViewingSavedSld ? null : () => _selectDate(context),
          tooltip: _isViewingSavedSld
              ? 'Date range cannot be changed for saved SLD'
              : 'Change Date Range',
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildFloatingActionButton(SldController sldController) {
    return EnergySpeedDialWidget(
      isViewingSavedSld: _isViewingSavedSld,
      showTables: _showTables,
      onToggleTables: () => setState(() => _showTables = !_showTables),
      onSaveSld: () => EnergySldUtils.saveSld(
        context,
        widget.substationId,
        widget.substationName,
        widget.currentUser,
        _startDate,
        _endDate,
        sldController,
        _energyDataService.allAssessmentsForDisplay,
      ),
      onSharePdf: generateAndSharePdf,
      onConfigureBusbar: () =>
          _energyDataService.showBusbarSelectionDialog(context, sldController),
      onAddAssessment: () => _energyDataService.showBaySelectionForAssessment(
        context,
        sldController,
      ),
    );
  }

  Widget? _buildBottomNavigationBar(SldController sldController) {
    if (sldController.selectedBayForMovementId == null || _isCapturingPdf) {
      return null;
    }

    return EnergyMovementControlsWidget(
      onSave: _loadEnergyData,
      isViewingSavedSld: _isViewingSavedSld,
    );
  }
}

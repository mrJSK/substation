// lib/screens/energy_sld_screen.dart
import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'dart:ui' as ui;
import 'dart:math' as math;

import '../../controllers/sld_controller.dart';
import '../../enums/movement_mode.dart';
import '../../models/energy_readings_data.dart';
import '../../models/saved_sld_model.dart';
import '../../models/user_model.dart';
import '../../models/assessment_model.dart';
import '../../utils/snackbar_utils.dart';
import '../../utils/pdf_generator.dart';
import '../../widgets/energy_movement_controls_widget.dart';
import '../../widgets/energy_speed_dial_widget.dart';
import '../../widgets/energy_tables_widget.dart';
import '../../widgets/energy_assessment_dialog.dart';
import '../../widgets/sld_view_widget.dart';
import '../../utils/energy_sld_utils.dart';

// Data models for unified positioning
class CapturedSldData {
  CapturedSldData({
    required this.pngBytes,
    required this.baseLogicalWidth,
    required this.baseLogicalHeight,
    required this.pixelRatio,
    DateTime? captureTimestamp,
  }) : captureTimestamp = captureTimestamp ?? DateTime.now(),
       assert(pngBytes.length > 0, 'Image bytes cannot be empty'),
       assert(baseLogicalWidth > 0, 'Base width must be positive'),
       assert(baseLogicalHeight > 0, 'Base height must be positive'),
       assert(pixelRatio > 0, 'Pixel ratio must be positive');

  final Uint8List pngBytes;
  final double baseLogicalWidth;
  final double baseLogicalHeight;
  final double pixelRatio;
  final DateTime captureTimestamp;

  bool get isValid =>
      pngBytes.isNotEmpty && baseLogicalWidth > 0 && baseLogicalHeight > 0;
}

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

  // UI State Management
  TransformationController? _transformationController;
  bool _controllersInitialized = false;
  Size _sldContentSize = const Size(1200, 800);
  final GlobalKey _sldRepaintBoundaryKey = GlobalKey();

  // Assessment data
  List<Assessment> _allAssessmentsForDisplay = [];
  List<dynamic> _loadedAssessmentsSummary = [];

  @override
  void initState() {
    super.initState();
    _isViewingSavedSld = widget.savedSld != null;
    _initializeControllers();

    if (_isViewingSavedSld) {
      _initializeFromSavedSld();
    } else {
      _loadEnergyData();
    }
  }

  void _initializeControllers() {
    _transformationController = TransformationController();
    _controllersInitialized = true;
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

      // Simple data loading - just wait for the controller to be ready
      await Future.delayed(const Duration(milliseconds: 500));

      // Load assessments data
      await _loadAssessments();

      // Calculate and set SLD bounds
      _calculateAndSetSldBounds(sldController);

      print('DEBUG: SLD Controller after data load:');
      print('DEBUG: Bay count: ${sldController.allBays.length}');
      print(
        'DEBUG: Bay energy data count: ${sldController.bayEnergyData.length}',
      );

      await Future.delayed(const Duration(milliseconds: 300));
    } catch (e) {
      if (mounted) {
        _showFixedSnackBar('Failed to load energy data: $e', isError: true);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadAssessments() async {
    try {
      // Load assessments from Firestore (placeholder - implement based on your data structure)
      _allAssessmentsForDisplay = [];
      _loadedAssessmentsSummary = [];
    } catch (e) {
      print('Error loading assessments: $e');
    }
  }

  void _calculateAndSetSldBounds(SldController sldController) {
    if (sldController.bayRenderDataList.isEmpty || !_controllersInitialized)
      return;

    try {
      final bounds = _calculateSldContentBounds(sldController);
      const double paddingSize = 50.0;

      setState(() {
        _sldContentSize = Size(
          bounds.width + paddingSize,
          bounds.height + paddingSize,
        );
      });

      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted && _controllersInitialized) {
          _autoFitSld();
        }
      });
    } catch (e) {
      print('DEBUG: Error calculating SLD bounds: $e');
    }
  }

  Rect _calculateSldContentBounds(SldController sldController) {
    if (sldController.bayRenderDataList.isEmpty) {
      return const Rect.fromLTWH(0, 0, 800, 600);
    }

    double minX = double.infinity;
    double minY = double.infinity;
    double maxX = double.negativeInfinity;
    double maxY = double.negativeInfinity;

    for (var renderData in sldController.bayRenderDataList) {
      final rect = renderData.rect;
      minX = math.min(minX, rect.left);
      minY = math.min(minY, rect.top);
      maxX = math.max(maxX, rect.right);
      maxY = math.max(maxY, rect.bottom);
    }

    return Rect.fromLTRB(minX, minY, maxX, maxY);
  }

  void _autoFitSld() {
    if (!_controllersInitialized || _transformationController == null) {
      print('DEBUG: Controllers not initialized, skipping auto-fit');
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_controllersInitialized) return;

      final RenderBox? renderBox = context.findRenderObject() as RenderBox?;
      if (renderBox == null) return;

      final viewportSize = renderBox.size;
      final availableHeight = viewportSize.height - (_showTables ? 400 : 150);
      final availableWidth = viewportSize.width - 40;

      final scaleX = (availableWidth * 0.85) / _sldContentSize.width;
      final scaleY = (availableHeight * 0.85) / _sldContentSize.height;
      final scale = math.min(scaleX, scaleY).clamp(0.3, 1.8);

      print(
        'DEBUG: Auto-fitting SLD with scale: $scale, content: $_sldContentSize, viewport: $viewportSize',
      );

      final centerX = (availableWidth - (_sldContentSize.width * scale)) / 2;
      final centerY = (availableHeight - (_sldContentSize.height * scale)) / 2;

      final matrix = Matrix4.identity()
        ..translate(centerX, centerY)
        ..scale(scale);

      _animateToTransform(matrix);
    });
  }

  void _animateToTransform(Matrix4 matrix) {
    if (!_controllersInitialized || _transformationController == null) return;
    _transformationController!.value = matrix;
  }

  void _resetSldView() {
    if (!_controllersInitialized || _transformationController == null) return;
    _transformationController!.value = Matrix4.identity();
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
          title: Row(
            children: [
              Icon(
                Icons.save_outlined,
                color: Theme.of(context).colorScheme.primary,
                size: 24,
              ),
              const SizedBox(width: 12),
              const Text(
                'Save Changes?',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
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
        ),
      );

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
              _showFixedSnackBar('Layout changes saved successfully!');
              Navigator.of(context).pop();
            } else {
              _showFixedSnackBar(
                'Failed to save changes. Please try again.',
                isError: true,
              );
            }
          }
        } catch (e) {
          if (mounted) {
            Navigator.of(context).pop();
            _showFixedSnackBar('Error saving changes: $e', isError: true);
          }
        }
      } else if (result == 'discard') {
        sldController.cancelLayoutChanges();
        _showFixedSnackBar('Changes discarded');
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

  void _showFixedSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : null,
        behavior: SnackBarBehavior.fixed,
        margin: null,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // Enhanced bay actions using the utility
  void _showBayActions(BuildContext context, dynamic bay, Offset tapPosition) {
    final sldController = Provider.of<SldController>(context, listen: false);

    EnergySldUtils.showBayActions(
      context,
      bay,
      tapPosition,
      sldController,
      _isViewingSavedSld,
      null, // energyDataService placeholder
    );
  }

  // NEW: Save SLD functionality
  void _saveSld() {
    showDialog(
      context: context,
      builder: (context) {
        final TextEditingController nameController = TextEditingController();

        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(
                Icons.save_outlined,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 12),
              const Text('Save SLD'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  hintText: "Enter SLD name",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.label_outline),
                ),
                autofocus: true,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (nameController.text.trim().isNotEmpty) {
                  Navigator.pop(context);
                  _showFixedSnackBar(
                    'SLD "${nameController.text}" saved successfully!',
                  );
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  // NEW: Generate and share PDF
  void _generateAndSharePdf() async {
    try {
      _showFixedSnackBar('Generating PDF...');

      // Capture SLD
      final capturedData = await _captureSldForPdf();

      if (capturedData != null) {
        final sldController = Provider.of<SldController>(
          context,
          listen: false,
        );

        // Create PDF data
        final pdfData = PdfGeneratorData(
          substationName: widget.substationName,
          dateRange: _dateRangeText,
          sldImageBytes: capturedData.pngBytes,
          abstractEnergyData: sldController.abstractEnergyData.isNotEmpty
              ? sldController.abstractEnergyData
              : {
                  'totalImp': 0.0,
                  'totalExp': 0.0,
                  'difference': 0.0,
                  'lossPercentage': 0.0,
                },
          busEnergySummaryData: sldController.busEnergySummary,
          aggregatedFeederData: sldController.aggregatedFeederEnergyData,
          assessmentsForPdf: _allAssessmentsForDisplay
              .map((a) => a.toFirestore())
              .toList(),
          uniqueBusVoltages: _getUniqueBusVoltages(sldController),
          allBaysInSubstation: sldController.allBays,
          baysMap: sldController.baysMap,
          uniqueDistributionSubdivisionNames: [],
          sldBaseLogicalWidth: capturedData.baseLogicalWidth,
          sldBaseLogicalHeight: capturedData.baseLogicalHeight,
          sldZoom: 1.0,
          sldOffset: Offset.zero,
        );

        final pdfBytes = await PdfGenerator.generateEnergyReportPdf(pdfData);

        final filename =
            'Energy_SLD_${widget.substationName.replaceAll(' ', '_')}_${DateFormat('yyyy-MM-dd').format(DateTime.now())}.pdf';

        await PdfGenerator.sharePdf(pdfBytes, filename, 'Energy SLD Report');

        _showFixedSnackBar('PDF generated and shared successfully!');
      } else {
        _showFixedSnackBar('Failed to capture SLD image', isError: true);
      }
    } catch (e) {
      _showFixedSnackBar('Failed to generate PDF: $e', isError: true);
    }
  }

  // NEW: Capture SLD for PDF
  Future<CapturedSldData?> _captureSldForPdf() async {
    try {
      setState(() => _isCapturingPdf = true);

      final boundary =
          _sldRepaintBoundaryKey.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;
      if (boundary == null) return null;

      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return null;

      return CapturedSldData(
        pngBytes: byteData.buffer.asUint8List(),
        baseLogicalWidth: boundary.size.width,
        baseLogicalHeight: boundary.size.height,
        pixelRatio: 3.0,
      );
    } catch (e) {
      print('Error capturing SLD: $e');
      return null;
    } finally {
      if (mounted) setState(() => _isCapturingPdf = false);
    }
  }

  // NEW: Show busbar configuration
  void _showBusbarConfiguration() {
    final sldController = Provider.of<SldController>(context, listen: false);
    final busbars = sldController.allBays
        .where((bay) => bay.bayType == 'Busbar')
        .toList();

    if (busbars.isEmpty) {
      _showFixedSnackBar('No busbars found in this substation', isError: true);
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(
              Icons.settings_input_antenna,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 12),
            const Text('Configure Busbar'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Select a busbar to configure:'),
            const SizedBox(height: 16),
            ...busbars.map(
              (busbar) => ListTile(
                leading: Icon(Icons.horizontal_rule, color: Colors.blue),
                title: Text(busbar.name),
                subtitle: Text(busbar.voltageLevel),
                onTap: () {
                  Navigator.pop(context);
                  sldController.setSelectedBayForMovement(busbar.id);
                  _showFixedSnackBar(
                    'Selected ${busbar.name} for configuration',
                  );
                },
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  // NEW: Show assessment dialog
  void _showAssessmentDialog() {
    final sldController = Provider.of<SldController>(context, listen: false);
    final baysWithEnergy = sldController.allBays
        .where(
          (bay) =>
              bay.bayType != 'Busbar' &&
              sldController.bayEnergyData.containsKey(bay.id),
        )
        .toList();

    if (baysWithEnergy.isEmpty) {
      _showFixedSnackBar('No bays with energy data found', isError: true);
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(
              Icons.assessment,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 12),
            const Text('Add Assessment'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Select a bay to create an assessment:'),
            const SizedBox(height: 16),
            ...baysWithEnergy
                .take(5)
                .map(
                  (bay) => ListTile(
                    leading: Icon(_getBayIcon(bay.bayType), color: Colors.red),
                    title: Text(bay.name),
                    subtitle: Text('${bay.bayType} • ${bay.voltageLevel}'),
                    onTap: () {
                      Navigator.pop(context);
                      showDialog(
                        context: context,
                        builder: (context) => EnergyAssessmentDialog(
                          bay: bay,
                          currentUser: widget.currentUser,
                          currentEnergyData:
                              sldController.bayEnergyData[bay.id],
                          onSaveAssessment: () => _loadEnergyData(),
                          latestExistingAssessment:
                              sldController.latestAssessmentsPerBay[bay.id],
                        ),
                      );
                    },
                  ),
                ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  // Helper methods
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

  IconData _getBayIcon(String bayType) {
    switch (bayType.toLowerCase()) {
      case 'transformer':
        return Icons.electrical_services;
      case 'line':
        return Icons.linear_scale;
      case 'feeder':
        return Icons.cable;
      case 'busbar':
        return Icons.horizontal_rule;
      default:
        return Icons.square;
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
        body: _buildMainContent(sldController),
        bottomNavigationBar: _buildBottomNavigationBar(sldController),
      ),
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

  Widget _buildInitializingState() {
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
            'Initializing SLD...',
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
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

  Widget _buildMainContent(SldController sldController) {
    return Stack(
      children: [
        // Main SLD area with proper InteractiveViewer
        if (_isLoading)
          _buildLoadingState()
        else if (!_controllersInitialized)
          _buildInitializingState()
        else
          Column(
            children: [
              // SLD viewport
              Expanded(
                child: Container(
                  width: double.infinity,
                  color: Colors.white,
                  child: InteractiveViewer(
                    transformationController: _transformationController!,
                    boundaryMargin: EdgeInsets.all(
                      math.max(20.0, _sldContentSize.width * 0.1),
                    ),
                    minScale: 0.2,
                    maxScale: 5.0,
                    constrained: false,
                    clipBehavior: Clip.none,
                    child: RepaintBoundary(
                      key: _sldRepaintBoundaryKey,
                      child: Container(
                        width: _sldContentSize.width,
                        height: _sldContentSize.height,
                        color: Colors.white,
                        child: Center(
                          child: SldViewWidget(
                            isEnergySld: true,
                            isCapturingPdf: _isCapturingPdf,
                            onBayTapped: _isCapturingPdf
                                ? null
                                : (bay, tapPosition) {
                                    if (sldController
                                            .selectedBayForMovementId ==
                                        null) {
                                      _showBayActions(
                                        context,
                                        bay,
                                        tapPosition,
                                      );
                                    }
                                  },
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // NEW: Tables overlay
              if (_showTables)
                Container(
                  height: 300,
                  child: EnergyTablesWidget(
                    isViewingSavedSld: _isViewingSavedSld,
                    loadedAssessmentsSummary: _loadedAssessmentsSummary
                        .cast<Map<String, dynamic>>(),
                    allAssessmentsForDisplay: _allAssessmentsForDisplay,
                  ),
                ),
            ],
          ),

        // Control buttons overlay
        if (!_isCapturingPdf && !_isLoading && _controllersInitialized)
          Positioned(
            top: 16,
            right: 16,
            child: Column(
              children: [
                FloatingActionButton.small(
                  onPressed: _autoFitSld,
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Colors.white,
                  heroTag: "autofit",
                  tooltip: "Auto Fit SLD",
                  child: const Icon(Icons.fit_screen),
                ),
                const SizedBox(height: 8),
                FloatingActionButton.small(
                  onPressed: _resetSldView,
                  backgroundColor: Colors.grey.shade600,
                  foregroundColor: Colors.white,
                  heroTag: "reset",
                  tooltip: "Reset View",
                  child: const Icon(Icons.refresh),
                ),
              ],
            ),
          ),

        // UPDATED: Enhanced Speed Dial FAB with actual functionality
        if (!_isCapturingPdf && !_isLoading && _controllersInitialized)
          EnergySpeedDialWidget(
            isViewingSavedSld: _isViewingSavedSld,
            showTables: _showTables,
            onToggleTables: () => setState(() => _showTables = !_showTables),
            onSaveSld: _saveSld, // NEW: Actual save functionality
            onSharePdf: _generateAndSharePdf, // NEW: Actual PDF generation
            onConfigureBusbar:
                _showBusbarConfiguration, // NEW: Busbar configuration
            onAddAssessment: _showAssessmentDialog, // NEW: Assessment dialog
          ),
      ],
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

  @override
  void dispose() {
    _transformationController?.dispose();
    super.dispose();
  }
}

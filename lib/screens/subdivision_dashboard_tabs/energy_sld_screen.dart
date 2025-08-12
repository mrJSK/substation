import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'dart:ui' as ui;
import 'dart:math' as math;

import '../../models/signature_models.dart';
import '../../controllers/sld_controller.dart';
import '../../models/saved_sld_model.dart';
import '../../models/user_model.dart';
import '../../models/assessment_model.dart';
import '../../services/energy_data_service.dart';
import '../../utils/pdf_generator.dart';
import '../../widgets/energy_movement_controls_widget.dart';
import '../../widgets/energy_speed_dial_widget.dart';
import '../../widgets/energy_tables_widget.dart';
import '../../widgets/sld_view_widget.dart';
import '../../widgets/signature_dialog.dart';
import '../../utils/energy_sld_utils.dart';

class CapturedSldData {
  CapturedSldData({
    required this.pngBytes,
    required this.baseLogicalWidth,
    required this.baseLogicalHeight,
    required this.pixelRatio,
    DateTime? captureTimestamp,
  }) : captureTimestamp = captureTimestamp ?? DateTime.now(),
       assert(pngBytes.isNotEmpty, 'Image bytes cannot be empty'),
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
  bool _showTables = false;
  bool _isViewingSavedSld = false;
  bool _showEnergyReadings = true;

  TransformationController? _transformationController;
  bool _controllersInitialized = false;
  Size _sldContentSize = const Size(1200, 800);
  final GlobalKey _sldRepaintBoundaryKey = GlobalKey();

  late EnergyDataService _energyDataService;

  // Signature-related fields
  List<SignatureData> _signatures = [];
  List<DistributionFeederData> _distributionFeederData = [];

  @override
  void initState() {
    super.initState();
    _isViewingSavedSld = widget.savedSld != null;

    _energyDataService = EnergyDataService(
      substationId: widget.substationId,
      currentUser: widget.currentUser,
    );

    _initializeControllers();

    if (_isViewingSavedSld) {
      _initializeFromSavedSld();
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _waitForControllerAndLoadData();
      });
    }
  }

  void _initializeControllers() {
    _transformationController = TransformationController();
    _controllersInitialized = true;
  }

  void _initializeFromSavedSld() {
    if (widget.savedSld == null) return;
    _startDate = widget.savedSld!.startDate.toDate();
    _endDate = widget.savedSld!.endDate.toDate();
    _loadEnergyData(fromSaved: true);
  }

  Future<void> _waitForControllerAndLoadData() async {
    if (!mounted) return;

    final sldController = Provider.of<SldController>(context, listen: false);
    int attempts = 0;
    const maxAttempts = 20;

    while (attempts < maxAttempts && mounted) {
      if (sldController.isInitialized && sldController.allBays.isNotEmpty) {
        print(
          'DEBUG: Controller ready with ${sldController.allBays.length} bays',
        );
        await _loadEnergyData();
        break;
      }

      attempts++;
      print('DEBUG: Waiting for controller... attempt $attempts/$maxAttempts');
      await Future.delayed(const Duration(milliseconds: 500));
    }

    if (attempts >= maxAttempts && mounted) {
      print('ERROR: Controller initialization timeout');
      setState(() => _isLoading = false);
      _showFixedSnackBar('Failed to initialize SLD data', isError: true);
    }
  }

  Future<void> _loadEnergyData({bool fromSaved = false}) async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final sldController = Provider.of<SldController>(context, listen: false);

      if (sldController.allBays.isEmpty) {
        print('ERROR: No bays available for energy data loading');
        if (mounted) {
          _showFixedSnackBar(
            'No bay data found for this substation',
            isError: true,
          );
        }
        return;
      }

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

      sldController.setShowEnergyReadings(_showEnergyReadings);
      _calculateAndSetSldBounds(sldController);

      print('DEBUG: Energy data loaded successfully');
      print('DEBUG: Bay count: ${sldController.allBays.length}');
      print(
        'DEBUG: Bay energy data count: ${sldController.bayEnergyData.length}',
      );

      await Future.delayed(const Duration(milliseconds: 300));
    } catch (e) {
      print('ERROR: Failed to load energy data: $e');
      if (mounted) {
        _showFixedSnackBar('Failed to load energy data: $e', isError: true);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
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
      return const Rect.fromLTWH(0, 0, 1200, 600);
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

  void _toggleEnergyReadings() {
    setState(() => _showEnergyReadings = !_showEnergyReadings);
    final sldController = Provider.of<SldController>(context, listen: false);
    sldController.setShowEnergyReadings(_showEnergyReadings);
    _showFixedSnackBar(
      _showEnergyReadings ? 'Energy readings shown' : 'Energy readings hidden',
    );
    print('DEBUG: Energy readings toggled to: $_showEnergyReadings');
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
          content: const Text(
            'You have unsaved layout changes. What would you like to do?',
            style: TextStyle(fontSize: 16),
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
              child: const Text('Save & Exit'),
            ),
          ],
        ),
      );

      if (result == 'save') {
        final success = await sldController.saveAllPendingChanges();
        if (mounted) {
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

  void _showFixedSnackBar(
    String message, {
    bool isError = false,
    Duration? duration,
  }) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : null,
        behavior: SnackBarBehavior.fixed,
        margin: null,
        duration: duration ?? Duration(seconds: isError ? 4 : 3),
      ),
    );
  }

  void _showBayActions(BuildContext context, dynamic bay, Offset tapPosition) {
    final sldController = Provider.of<SldController>(context, listen: false);
    EnergySldUtils.showBayActions(
      context,
      bay,
      tapPosition,
      sldController,
      _isViewingSavedSld,
      _energyDataService,
    );
  }

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

  // Signature dialog method
  void _showSignatureDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => SignatureDialog(
        existingSignatures: _signatures.isNotEmpty ? _signatures : null,
        onSignaturesAdded: (signatures) {
          setState(() {
            _signatures = signatures;
          });

          final count = signatures.length;
          _showFixedSnackBar(
            '$count signature${count != 1 ? 's' : ''} added successfully!',
            duration: const Duration(seconds: 3),
          );
        },
      ),
    );
  }

  // Prepare distribution feeder data
  void _prepareDistributionFeederData() {
    final sldController = Provider.of<SldController>(context, listen: false);
    _distributionFeederData.clear();

    final distributionFeeders = sldController.allBays
        .where(
          (bay) =>
              bay.bayType.toLowerCase() == 'feeder' &&
              (bay.name.contains('DIST') || bay.name.contains('Distribution')),
        )
        .toList();

    for (var feeder in distributionFeeders) {
      final energyData = sldController.bayEnergyData[feeder.id];
      if (energyData != null) {
        _distributionFeederData.add(
          DistributionFeederData(
            feederName: feeder.name,
            distributionZone: 'Zone 1',
            distributionCircle: 'Circle 1',
            distributionDivision: 'Division 1',
            distributionSubdivision: 'Subdivision 1',
            importEnergy: energyData.adjustedImportConsumed,
            exportEnergy: energyData.adjustedExportConsumed,
            feederType: feeder.feederType ?? 'Distribution',
          ),
        );
      }
    }
  }

  void _generateAndSharePdf() async {
    try {
      _showFixedSnackBar('Generating PDF...');

      // Prepare distribution feeder data
      _prepareDistributionFeederData();

      final matrix = _transformationController?.value ?? Matrix4.identity();
      final double sldScale = matrix.storage[0];
      final double sldDx = matrix.storage[12];
      final double sldDy = matrix.storage[13];
      final Offset sldOffsetFromController = Offset(sldDx, sldDy);

      final capturedData = await _captureSldForPdf();

      if (capturedData != null) {
        final sldController = Provider.of<SldController>(
          context,
          listen: false,
        );

        // Check what field actually exists in your SldController
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
          // Use the correct field name from your SldController
          aggregatedFeederData: sldController
              .aggregatedFeederEnergyData, // ✅ Use this if the field exists
          assessmentsForPdf: _energyDataService.allAssessmentsForDisplay
              .map((a) => a.toFirestore())
              .toList(),
          uniqueBusVoltages: _getUniqueBusVoltages(sldController),
          allBaysInSubstation: sldController.allBays,
          baysMap: sldController.baysMap,
          uniqueDistributionSubdivisionNames: [],
          sldBaseLogicalWidth: capturedData.baseLogicalWidth,
          sldBaseLogicalHeight: capturedData.baseLogicalHeight,
          sldZoom: sldScale,
          sldOffset: sldOffsetFromController,
          signatures: _signatures,
          distributionFeederData: _distributionFeederData,
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

  void _showBusbarConfiguration() {
    final sldController = Provider.of<SldController>(context, listen: false);
    _energyDataService.showBusbarSelectionDialog(context, sldController);
  }

  void _showAssessmentDialog() {
    final sldController = Provider.of<SldController>(context, listen: false);
    _energyDataService.showBaySelectionForAssessment(context, sldController);
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
        // Add signature count indicator
        if (_signatures.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(right: 8, top: 8, bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.teal.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.teal.withOpacity(0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.draw_outlined,
                  size: 14,
                  color: Colors.teal.shade700,
                ),
                const SizedBox(width: 4),
                Text(
                  '${_signatures.length}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.teal.shade700,
                  ),
                ),
              ],
            ),
          ),
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
        if (_isLoading)
          _buildLoadingState()
        else if (!_controllersInitialized)
          _buildInitializingState()
        else
          Column(
            children: [
              Expanded(
                child: Container(
                  margin: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                    border: Border.all(color: Colors.grey.shade300, width: 1),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(11),
                    child: InteractiveViewer(
                      transformationController: _transformationController!,
                      panEnabled: true,
                      scaleEnabled: true,
                      constrained: false,
                      boundaryMargin: EdgeInsets.all(double.infinity),
                      minScale: 0.2,
                      maxScale: 5.0,
                      clipBehavior: Clip.none,
                      child: RepaintBoundary(
                        key: _sldRepaintBoundaryKey,
                        child: Container(
                          width: math.max(800, _sldContentSize.width),
                          height: math.max(600, _sldContentSize.height),
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
              ),

              if (_showTables)
                Container(
                  height: 300,
                  child: EnergyTablesWidget(
                    isViewingSavedSld: _isViewingSavedSld,
                    loadedAssessmentsSummary: _energyDataService
                        .loadedAssessmentsSummary
                        .cast<Map<String, dynamic>>(),
                    allAssessmentsForDisplay: _energyDataService
                        .allAssessmentsForDisplay
                        .cast<Assessment>(),
                  ),
                ),
            ],
          ),

        // Fixed: Positioned widgets as direct children of Stack
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
                const SizedBox(height: 8),
                FloatingActionButton.small(
                  onPressed: _toggleEnergyReadings,
                  backgroundColor: _showEnergyReadings
                      ? Colors.green
                      : Colors.grey.shade600,
                  foregroundColor: Colors.white,
                  heroTag: "toggle_readings",
                  tooltip: _showEnergyReadings
                      ? "Hide Energy Readings"
                      : "Show Energy Readings",
                  child: Icon(
                    _showEnergyReadings
                        ? Icons.visibility
                        : Icons.visibility_off,
                  ),
                ),
              ],
            ),
          ),

        // Fixed: Speed dial as direct child of Stack
        if (!_isCapturingPdf && !_isLoading && _controllersInitialized)
          EnergySpeedDialWidget(
            isViewingSavedSld: _isViewingSavedSld,
            showTables: _showTables,
            onToggleTables: () => setState(() => _showTables = !_showTables),
            onSaveSld: _saveSld,
            onSharePdf: _generateAndSharePdf,
            onConfigureBusbar: _showBusbarConfiguration,
            onAddAssessment: _showAssessmentDialog,
            onAddSignatures: _showSignatureDialog,
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

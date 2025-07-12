// lib/screens/energy_sld_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math';
import 'package:collection/collection.dart';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';

// PDF & Capture related imports
import 'package:flutter/material.dart' show TextDirection;
import 'package:intl/intl.dart' show DateFormat;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';
import 'dart:ui';
import 'dart:typed_data';
import 'package:widgets_to_image/widgets_to_image.dart';

import '../models/bay_model.dart';
import '../models/equipment_model.dart';
import '../models/user_model.dart';
import '../models/reading_models.dart';
import '../models/logsheet_models.dart';
import '../models/bay_connection_model.dart';
import '../models/busbar_energy_map.dart';
import '../models/hierarchy_models.dart';
import '../models/assessment_model.dart';
import '../models/saved_sld_model.dart';
import '../models/substation_sld_layout_model.dart'; // NEW: Import the SLD layout model
import '../utils/snackbar_utils.dart';

import '../painters/single_line_diagram_painter.dart';
import '../widgets/energy_assessment_dialog.dart';

/// Data model for energy data associated with a bay
class BayEnergyData {
  final String bayName;
  final double? prevImp;
  final double? currImp;
  final double? prevExp;
  final double? currExp;
  final double? mf;
  final double? impConsumed;
  final double? expConsumed;
  final bool hasAssessment;

  BayEnergyData({
    required this.bayName,
    this.prevImp,
    this.currImp,
    this.currExp,
    this.mf,
    this.impConsumed,
    this.expConsumed,
    this.hasAssessment = false,
    this.prevExp,
  });

  BayEnergyData applyAssessment({
    double? importAdjustment,
    double? exportAdjustment,
  }) {
    double newImpConsumed = (impConsumed ?? 0.0) + (importAdjustment ?? 0.0);
    double newExpConsumed = (expConsumed ?? 0.0) + (exportAdjustment ?? 0.0);
    return BayEnergyData(
      bayName: bayName,
      prevImp: prevImp,
      currImp: currImp,
      prevExp: prevExp,
      currExp: currExp,
      mf: mf,
      impConsumed: newImpConsumed,
      expConsumed: newExpConsumed,
      hasAssessment: true,
    );
  }

  /// Convert to Map for serialization
  Map<String, dynamic> toMap() {
    return {
      'bayName': bayName,
      'prevImp': prevImp,
      'currImp': currImp,
      'prevExp': prevExp,
      'currExp': currExp,
      'mf': mf,
      'impConsumed': impConsumed,
      'expConsumed': expConsumed,
      'hasAssessment': hasAssessment,
    };
  }

  /// Create from Map for deserialization
  factory BayEnergyData.fromMap(Map<String, dynamic> map) {
    return BayEnergyData(
      bayName: map['bayName'],
      prevImp: (map['prevImp'] as num?)?.toDouble(),
      currImp: (map['currImp'] as num?)?.toDouble(),
      prevExp: (map['prevExp'] as num?)?.toDouble(),
      currExp: (map['currExp'] as num?)?.toDouble(),
      mf: (map['mf'] as num?)?.toDouble(),
      impConsumed: (map['impConsumed'] as num?)?.toDouble(),
      expConsumed: (map['expConsumed'] as num?)?.toDouble(),
      hasAssessment: map['hasAssessment'] ?? false,
    );
  }
}

/// Data model for Aggregated Feeder Energy Table
class AggregatedFeederEnergyData {
  final String zoneName;
  final String circleName;
  final String divisionName;
  final String distributionSubdivisionName;
  double importedEnergy;
  double exportedEnergy;

  AggregatedFeederEnergyData({
    required this.zoneName,
    required this.circleName,
    required this.divisionName,
    required this.distributionSubdivisionName,
    this.importedEnergy = 0.0,
    this.exportedEnergy = 0.0,
  });

  String get uniqueKey =>
      '$zoneName-$circleName-$divisionName-$distributionSubdivisionName';

  Map<String, dynamic> toMap() {
    return {
      'zoneName': zoneName,
      'circleName': circleName,
      'divisionName': divisionName,
      'distributionSubdivisionName': distributionSubdivisionName,
      'importedEnergy': importedEnergy,
      'exportedEnergy': exportedEnergy,
    };
  }

  factory AggregatedFeederEnergyData.fromMap(Map<String, dynamic> map) {
    return AggregatedFeederEnergyData(
      zoneName: map['zoneName'],
      circleName: map['circleName'],
      divisionName: map['divisionName'],
      distributionSubdivisionName: map['distributionSubdivisionName'],
      importedEnergy: (map['importedEnergy'] as num?)?.toDouble() ?? 0.0,
      exportedEnergy: (map['exportedEnergy'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

/// Data model for rendering the SLD with energy data
class SldRenderData {
  final List<BayRenderData> bayRenderDataList;
  final Map<String, Rect>
  finalBayRects; // Not serializable, handled dynamically
  final Map<String, Rect> busbarRects; // Not serializable, handled dynamically
  final Map<String, Map<String, Offset>>
  busbarConnectionPoints; // Not serializable, handled dynamically
  final Map<String, BayEnergyData> bayEnergyData;
  final Map<String, Map<String, double>> busEnergySummary;
  final Map<String, dynamic>
  abstractEnergyData; // NEW: Added abstract energy data
  final List<AggregatedFeederEnergyData>
  aggregatedFeederEnergyData; // NEW: Aggregated feeder data

  SldRenderData({
    required this.bayRenderDataList,
    required this.finalBayRects,
    required this.busbarRects,
    required this.busbarConnectionPoints,
    required this.bayEnergyData,
    required this.busEnergySummary,
    required this.abstractEnergyData, // NEW: Required in constructor
    required this.aggregatedFeederEnergyData, // NEW: Required in constructor
  });

  /// Convert to Map for serialization (excluding Rects and Offsets)
  Map<String, dynamic> toMap() {
    return {
      // bayRenderDataList contains Bay objects which are serializable through toFirestore()
      // For sldParameters, we only need the bay IDs and their coordinates
      'bayPositions': {
        for (var renderData in bayRenderDataList)
          renderData.bay.id: {
            // Note: Bay model no longer holds xPosition, yPosition, etc.
            // These values must come from the calculated layout in BayRenderData.
            'x': renderData.center.dx,
            'y': renderData.center.dy,
            'textOffsetDx': renderData.textOffset.dx,
            'textOffsetDy': renderData.textOffset.dy,
            'busbarLength': renderData.busbarLength,
          },
      },
      'bayEnergyData': {
        for (var entry in bayEnergyData.entries) entry.key: entry.value.toMap(),
      },
      'busEnergySummary': busEnergySummary,
      'abstractEnergyData':
          abstractEnergyData, // NEW: Include abstract energy data
      'aggregatedFeederEnergyData': aggregatedFeederEnergyData
          .map((e) => e.toMap())
          .toList(), // NEW: Include aggregated feeder data
    };
  }

  /// Create from Map for deserialization (re-generating Rects and Offsets will happen dynamically)
  factory SldRenderData.fromMap(
    Map<String, dynamic> map,
    Map<String, Bay> baysMap,
  ) {
    // This factory is primarily for loading saved SLD data, which includes raw bay data.
    // The actual rendering of BayRenderData happens dynamically in the painter.
    // For saved SLDs, we only need the bayLayoutParameters, not fully formed BayRenderData objects.
    // This part of SldRenderData is used for PDF export, not for live rendering.

    // This needs to be empty or handle basic Bay initialization without layout info
    // as the layout info is now in SubstationSldLayout.
    List<BayRenderData> deserializedBayRenderDataList = [];

    Map<String, Map<String, double>> deserializedBayEnergyData =
        (map['bayEnergyData'] as Map<String, dynamic>?)?.map(
          (key, value) => MapEntry(key, Map<String, double>.from(value)),
        ) ??
        {};

    Map<String, Map<String, double>> deserializedBusEnergySummary =
        (map['busEnergySummary'] as Map<String, dynamic>?)?.map(
          (key, value) => MapEntry(key, Map<String, double>.from(value)),
        ) ??
        {};

    Map<String, dynamic> deserializedAbstractEnergyData =
        Map<String, dynamic>.from(map['abstractEnergyData'] ?? {});

    List<AggregatedFeederEnergyData> deserializedAggregatedFeederEnergyData =
        (map['aggregatedFeederEnergyData'] as List<dynamic>?)
            ?.map(
              (e) => AggregatedFeederEnergyData.fromMap(
                e as Map<String, dynamic>? ?? {},
              ),
            )
            .toList() ??
        [];

    // When loading from a saved SLD, we don't directly recreate BayRenderData here with positions.
    // The layout parameters are part of the saved SLD and will be used by the painter.
    // So, bayRenderDataList can be empty here; it will be filled by the painter.
    return SldRenderData(
      bayRenderDataList: deserializedBayRenderDataList,
      finalBayRects: {}, // Not loaded directly, will be generated by painter
      busbarRects: {}, // Not loaded directly, will be generated by painter
      busbarConnectionPoints:
          {}, // Not loaded directly, will be generated by painter
      bayEnergyData: deserializedBayEnergyData.map(
        (key, value) => MapEntry(key, BayEnergyData.fromMap(value)),
      ),
      busEnergySummary: deserializedBusEnergySummary,
      abstractEnergyData: deserializedAbstractEnergyData,
      aggregatedFeederEnergyData: deserializedAggregatedFeederEnergyData,
    );
  }
}

/// GlobalKey for ScaffoldMessengerState to show SnackBars from anywhere
final GlobalKey<ScaffoldMessengerState> energySldScaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

class EnergySldScreen extends StatefulWidget {
  final String substationId;
  final String substationName;
  final AppUser currentUser;
  final SavedSld? savedSld; // Optional parameter for saved SLD

  const EnergySldScreen({
    super.key,
    required this.substationId,
    required this.substationName,
    required this.currentUser,
    this.savedSld, // Add to constructor
  });

  @override
  State<EnergySldScreen> createState() => _EnergySldScreenState();
}

enum MovementMode { bay, text }

class _EnergySldScreenState extends State<EnergySldScreen> {
  bool _isLoading = true;
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 1));
  DateTime _endDate = DateTime.now();
  bool _showTables = true;

  List<Bay> _allBaysInSubstation = [];
  Map<String, Bay> _baysMap = {};
  List<BayConnection> _allConnections = [];
  List<BayRenderData> _currentBayRenderDataList = [];

  Map<String, BayEnergyData> _bayEnergyData = {};
  Map<String, double> _abstractEnergyData = {};
  Map<String, Map<String, double>> _busEnergySummary = {};
  Map<String, BusbarEnergyMap> _busbarEnergyMaps = {};
  Map<String, Assessment> _latestAssessmentsPerBay = {};
  Map<String, List<EquipmentInstance>> _equipmentByBayId =
      {}; // Used by painter for equipment instances

  // Hierarchy maps for lookup (Transmission Hierarchy)
  Map<String, Zone> _zonesMap = {};
  Map<String, Circle> _circlesMap = {};
  Map<String, Division> _divisionsMap = {};
  Map<String, Subdivision> _subdivisionsMap = {};
  Map<String, Substation> _substationsMap =
      {}; // Corrected from hierarchy_models.dart assumption

  // Maps for Distribution Hierarchy lookup
  Map<String, DistributionZone> _distributionZonesMap = {};
  Map<String, DistributionCircle> _distributionCirclesMap = {};
  Map<String, DistributionDivision> _distributionDivisionsMap = {};
  Map<String, DistributionSubdivision> _distributionSubdivisionsMap = {};

  List<AggregatedFeederEnergyData> _aggregatedFeederEnergyData = [];
  List<Assessment> _allAssessmentsForDisplay = [];

  final TransformationController _transformationController =
      TransformationController();

  int _feederTablePageIndex = 0;

  bool _isViewingSavedSld = false;
  Map<String, dynamic>? _loadedSldParameters;
  List<Map<String, dynamic>> _loadedAssessmentsSummary = [];

  final WidgetsToImageController _widgetsToImageController =
      WidgetsToImageController();

  bool _isCapturingPdf = false;
  Matrix4? _originalTransformation;

  String? _selectedBayForMovementId;
  MovementMode _movementMode = MovementMode.bay;
  Map<String, Offset> _bayPositions =
      {}; // Stores live/temporary positions for drag
  Map<String, Offset> _textOffsets =
      {}; // Stores live/temporary text offsets for drag
  Map<String, double> _busbarLengths =
      {}; // Stores live/temporary busbar lengths for drag

  // These maps store the *calculated layout* from the painter for hit testing and PDF capture.
  Map<String, Rect> _renderedBayRects = {};
  Map<String, Map<String, Offset>> _renderedBusbarConnectionPoints = {};
  Map<String, Rect> _renderedBusbarDrawingRects = {};

  SubstationSldLayout?
  _substationSldLayout; // NEW: Store the fetched SLD layout

  static const double _movementStep = 10.0;
  static const double _busbarLengthStep = 20.0;
  static const double _capturePadding =
      50.0; // Defined at class level for re-use

  @override
  void initState() {
    super.initState();
    print(
      'DEBUG: EnergySldScreen initState - substationId: ${widget.substationId}',
    );

    _isViewingSavedSld = widget.savedSld != null;
    if (_isViewingSavedSld) {
      _startDate = widget.savedSld!.startDate.toDate();
      _endDate = widget.savedSld!.endDate.toDate();
      _loadedSldParameters = widget.savedSld!.sldParameters;
      _loadedAssessmentsSummary = widget.savedSld!.assessmentsSummary;
      _loadEnergyData(fromSaved: true); // Load from saved SLD
    } else {
      if (widget.substationId.isNotEmpty) {
        _loadEnergyData(); // Load live data
      } else {
        _isLoading = false;
      }
    }
  }

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  double _getVoltageLevelValue(String voltageLevel) {
    final regex = RegExp(r'(\d+(\.\d+)?)');
    final match = regex.firstMatch(voltageLevel);
    if (match != null) {
      return double.tryParse(match.group(1)!) ?? 0.0;
    }
    return 0.0;
  }

  Future<void> _loadEnergyData({bool fromSaved = false}) async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _bayEnergyData.clear();
      _abstractEnergyData.clear();
      _busEnergySummary.clear();
      _allBaysInSubstation.clear();
      _baysMap.clear();
      _allConnections.clear();
      _busbarEnergyMaps.clear();
      _latestAssessmentsPerBay.clear();
      _allAssessmentsForDisplay.clear();
      _aggregatedFeederEnergyData.clear();
      _feederTablePageIndex = 0;

      // Clear movement state for a fresh load
      _selectedBayForMovementId = null;
      _bayPositions.clear();
      _textOffsets.clear();
      _busbarLengths.clear();
    });

    try {
      await _fetchTransmissionHierarchyData();
      await _fetchDistributionHierarchyData();

      // Fetch Bays
      final baysSnapshot = await FirebaseFirestore.instance
          .collection('bays')
          .where('substationId', isEqualTo: widget.substationId)
          .orderBy('name')
          .get();
      _allBaysInSubstation = baysSnapshot.docs
          .map((doc) => Bay.fromFirestore(doc))
          .toList();

      _allBaysInSubstation.sort((a, b) {
        final double voltageA = _getVoltageLevelValue(a.voltageLevel);
        final double voltageB = _getVoltageLevelValue(b.voltageLevel);
        return voltageB.compareTo(voltageA);
      });

      _baysMap = {for (var bay in _allBaysInSubstation) bay.id: bay};

      // Fetch Connections
      final connectionsSnapshot = await FirebaseFirestore.instance
          .collection('bay_connections')
          .where('substationId', isEqualTo: widget.substationId)
          .get();
      _allConnections = connectionsSnapshot.docs
          .map((doc) => BayConnection.fromFirestore(doc))
          .toList();

      // Fetch Equipment Instances for drawing
      final equipmentSnapshot = await FirebaseFirestore.instance
          .collection('equipmentInstances')
          .where('substationId', isEqualTo: widget.substationId)
          .get();
      _allEquipmentInstances = equipmentSnapshot.docs
          .map((doc) => EquipmentInstance.fromFirestore(doc))
          .toList();
      _equipmentByBayId.clear();
      for (var eq in _allEquipmentInstances) {
        _equipmentByBayId.putIfAbsent(eq.bayId, () => []).add(eq);
      }

      // Fetch SLD Layout
      SubstationSldLayout? currentSldLayout;
      final sldLayoutDoc = await FirebaseFirestore.instance
          .collection('substationSldLayouts')
          .doc(widget.substationId)
          .get();
      if (sldLayoutDoc.exists) {
        currentSldLayout = SubstationSldLayout.fromFirestore(sldLayoutDoc);
      } else {
        // If no saved layout, create a dummy one. It will be saved on first 'Save SLD'.
        currentSldLayout = SubstationSldLayout(
          id: widget.substationId,
          substationId: widget.substationId,
          createdAt: Timestamp.now(),
          lastModifiedAt: Timestamp.now(),
          createdBy: widget.currentUser.uid,
          lastModifiedBy: widget.currentUser.uid,
          bayLayoutParameters: {},
        );
      }
      _substationSldLayout = currentSldLayout; // Assign to state variable

      if (fromSaved && _loadedSldParameters != null) {
        debugPrint('Loading energy data from SAVED SLD.');
        _bayEnergyData =
            (_loadedSldParameters!['bayEnergyData'] as Map<String, dynamic>?)
                ?.map<String, BayEnergyData>(
                  (key, value) => MapEntry(
                    key,
                    BayEnergyData.fromMap(value as Map<String, dynamic>),
                  ),
                ) ??
            {};
        _busEnergySummary = Map<String, Map<String, double>>.from(
          (_loadedSldParameters!['busEnergySummary'] as Map<String, dynamic>?)
                  ?.map(
                    (key, value) => MapEntry(
                      key,
                      Map<String, double>.from(
                        value as Map<String, dynamic>? ?? {},
                      ),
                    ),
                  ) ??
              {},
        );
        _abstractEnergyData = Map<String, double>.from(
          _loadedSldParameters!['abstractEnergyData']
                  as Map<String, dynamic>? ??
              {},
        );
        _aggregatedFeederEnergyData =
            (_loadedSldParameters!['aggregatedFeederEnergyData']
                    as List<dynamic>?)
                ?.map(
                  (e) => AggregatedFeederEnergyData.fromMap(
                    e as Map<String, dynamic>? ?? {},
                  ),
                )
                .toList() ??
            [];
        _allAssessmentsForDisplay = _loadedAssessmentsSummary
            .map((e) => Assessment.fromMap(e))
            .toList();

        // Populate layout positions from saved SLD parameters (for historical view)
        if (_loadedSldParameters!.containsKey('bayPositions')) {
          (_loadedSldParameters!['bayPositions'] as Map<String, dynamic>)
              .forEach((bayId, params) {
                _bayPositions[bayId] = Offset(
                  params['x'] ?? 0.0,
                  params['y'] ?? 0.0,
                );
                _textOffsets[bayId] = Offset(
                  params['textOffsetDx'] ?? 0.0,
                  params['textOffsetDy'] ?? 0.0,
                );
                if (params['busbarLength'] != null) {
                  _busbarLengths[bayId] = params['busbarLength']!;
                }
              });
        }
      } else {
        // Continue with live data fetching and calculation
        debugPrint('Loading LIVE energy data.');
        final busbarEnergyMapsSnapshot = await FirebaseFirestore.instance
            .collection('busbarEnergyMaps')
            .where('substationId', isEqualTo: widget.substationId)
            .get();
        _busbarEnergyMaps = {
          for (var doc in busbarEnergyMapsSnapshot.docs)
            '${doc['busbarId']}-${doc['connectedBayId']}':
                BusbarEnergyMap.fromFirestore(doc),
        };

        final startOfStartDate = DateTime(
          _startDate.year,
          _startDate.month,
          _startDate.day,
        );
        final endOfStartDate = DateTime(
          _startDate.year,
          _startDate.month,
          _startDate.day,
          23,
          59,
          59,
          999,
        );

        Map<String, LogsheetEntry> startDayReadings = {};
        Map<String, LogsheetEntry> endDayReadings = {};
        Map<String, LogsheetEntry> previousDayToStartDateReadings = {};

        final startDayLogsheetsSnapshot = await FirebaseFirestore.instance
            .collection('logsheetEntries')
            .where('substationId', isEqualTo: widget.substationId)
            .where('frequency', isEqualTo: 'daily')
            .where('readingTimestamp', isGreaterThanOrEqualTo: startOfStartDate)
            .where('readingTimestamp', isLessThanOrEqualTo: endOfEndDate)
            .get();
        startDayReadings = {
          for (var doc in startDayLogsheetsSnapshot.docs)
            (doc.data() as Map<String, dynamic>)['bayId']:
                LogsheetEntry.fromFirestore(doc),
        };

        if (!_startDate.isAtSameMomentAs(_endDate)) {
          final endDayLogsheetsSnapshot = await FirebaseFirestore.instance
              .collection('logsheetEntries')
              .where('substationId', isEqualTo: widget.substationId)
              .where('frequency', isEqualTo: 'daily')
              .where('readingTimestamp', isGreaterThanOrEqualTo: startOfEndDate)
              .where('readingTimestamp', isLessThanOrEqualTo: endOfEndDate)
              .get();
          endDayReadings = {
            for (var doc in endDayLogsheetsSnapshot.docs)
              (doc.data() as Map<String, dynamic>)['bayId']:
                  LogsheetEntry.fromFirestore(doc),
          };
        } else {
          endDayReadings = startDayReadings;
          final previousDay = _startDate.subtract(const Duration(days: 1));
          final startOfPreviousDay = DateTime(
            previousDay.year,
            previousDay.month,
            previousDay.day,
          );
          final endOfPreviousDay = DateTime(
            previousDay.year,
            previousDay.month,
            previousDay.day,
            23,
            59,
            59,
            999,
          );

          final previousDayToStartDateLogsheetsSnapshot =
              await FirebaseFirestore.instance
                  .collection('logsheetEntries')
                  .where('substationId', isEqualTo: widget.substationId)
                  .where('frequency', isEqualTo: 'daily')
                  .where(
                    'readingTimestamp',
                    isGreaterThanOrEqualTo: Timestamp.fromDate(
                      startOfPreviousDay,
                    ),
                  )
                  .where(
                    'readingTimestamp',
                    isLessThanOrEqualTo: Timestamp.fromDate(endOfPreviousDay),
                  )
                  .get();
          previousDayToStartDateReadings = {
            for (var doc in previousDayToStartDateLogsheetsSnapshot.docs)
              (doc.data() as Map<String, dynamic>)['bayId']:
                  LogsheetEntry.fromFirestore(doc),
          };
        }

        final assessmentsRawSnapshot = await FirebaseFirestore.instance
            .collection('assessments')
            .where('substationId', isEqualTo: widget.substationId)
            .where(
              'assessmentTimestamp',
              isGreaterThanOrEqualTo: Timestamp.fromDate(startOfStartDate),
            )
            .where(
              'assessmentTimestamp',
              isLessThanOrEqualTo: Timestamp.fromDate(endOfEndDate),
            )
            .orderBy('assessmentTimestamp', descending: true)
            .get();

        _allAssessmentsForDisplay = [];
        _latestAssessmentsPerBay.clear();

        for (var doc in assessmentsRawSnapshot.docs) {
          final assessment = Assessment.fromFirestore(doc);
          _allAssessmentsForDisplay.add(assessment);
          if (!_latestAssessmentsPerBay.containsKey(assessment.bayId)) {
            _latestAssessmentsPerBay[assessment.bayId] = assessment;
          }
        }
        _allAssessmentsForDisplay.sort(
          (a, b) => b.assessmentTimestamp.compareTo(a.assessmentTimestamp),
        );

        for (var bay in _allBaysInSubstation) {
          final double? mf = bay.multiplyingFactor;
          double calculatedImpConsumed = 0.0;
          double calculatedExpConsumed = 0.0;

          bool bayHasAssessmentForPeriod = _latestAssessmentsPerBay.containsKey(
            bay.id,
          );

          if (_startDate.isAtSameMomentAs(_endDate)) {
            final currentReadingLogsheet = endDayReadings[bay.id];
            final previousReadingLogsheetDocument =
                previousDayToStartDateReadings[bay.id];

            final double? currImpVal = double.tryParse(
              currentReadingLogsheet?.values['Current Day Reading (Import)']
                      ?.toString() ??
                  '',
            );
            final double? currExpVal = double.tryParse(
              currentReadingLogsheet?.values['Current Day Reading (Export)']
                      ?.toString() ??
                  '',
            );

            double? prevImpValForCalculation;
            double? prevExpValForCalculation;

            final double? prevImpValFromPreviousDocument = double.tryParse(
              previousReadingLogsheetDocument
                      ?.values['Current Day Reading (Import)']
                      ?.toString() ??
                  '',
            );
            final double? prevExpValFromPreviousDocument = double.tryParse(
              previousReadingLogsheetDocument
                      ?.values['Current Day Reading (Export)']
                      ?.toString() ??
                  '',
            );

            if (prevImpValFromPreviousDocument != null) {
              prevImpValForCalculation = prevImpValFromPreviousDocument;
            } else {
              prevImpValForCalculation = double.tryParse(
                currentReadingLogsheet?.values['Previous Day Reading (Import)']
                        ?.toString() ??
                    '',
              );
            }

            if (prevExpValFromPreviousDocument != null) {
              prevExpValForCalculation = prevExpValFromPreviousDocument;
            } else {
              prevExpValForCalculation = double.tryParse(
                currentReadingLogsheet?.values['Previous Day Reading (Export)']
                        ?.toString() ??
                    '',
              );
            }

            if (currImpVal != null &&
                prevImpValForCalculation != null &&
                mf != null) {
              calculatedImpConsumed = max(
                0.0,
                (currImpVal - prevImpValForCalculation) * mf,
              );
            }
            if (currExpVal != null &&
                prevExpValForCalculation != null &&
                mf != null) {
              calculatedExpConsumed = max(
                0.0,
                (currExpVal - prevExpValForCalculation) * mf,
              );
            }

            _bayEnergyData[bay.id] = BayEnergyData(
              bayName: bay.name,
              prevImp: prevImpValForCalculation,
              currImp: currImpVal,
              prevExp: prevExpValForCalculation,
              currExp: currExpVal,
              mf: mf,
              impConsumed: calculatedImpConsumed,
              expConsumed: calculatedExpConsumed,
              hasAssessment: bayHasAssessmentForPeriod,
            );
          } else {
            final startReading = startDayReadings[bay.id];
            final endReading = endDayReadings[bay.id];

            final double? startImpVal = double.tryParse(
              startReading?.values['Current Day Reading (Import)']
                      ?.toString() ??
                  '',
            );
            final double? startExpVal = double.tryParse(
              startReading?.values['Current Day Reading (Export)']
                      ?.toString() ??
                  '',
            );
            final double? endImpVal = double.tryParse(
              endReading?.values['Current Day Reading (Import)']?.toString() ??
                  '',
            );
            final double? endExpVal = double.tryParse(
              endReading?.values['Current Day Reading (Export)']?.toString() ??
                  '',
            );

            if (startImpVal != null && endImpVal != null && mf != null) {
              calculatedImpConsumed = max(0.0, (endImpVal - startImpVal) * mf);
            }
            if (startExpVal != null && endExpVal != null && mf != null) {
              calculatedExpConsumed = max(0.0, (endExpVal - startExpVal) * mf);
            }

            _bayEnergyData[bay.id] = BayEnergyData(
              bayName: bay.name,
              prevImp: startImpVal,
              currImp: endImpVal,
              prevExp: startExpVal,
              currExp: endExpVal,
              mf: mf,
              impConsumed: calculatedImpConsumed,
              expConsumed: calculatedExpConsumed,
              hasAssessment: bayHasAssessmentForPeriod,
            );
          }

          final latestAssessment = _latestAssessmentsPerBay[bay.id];
          if (latestAssessment != null) {
            _bayEnergyData[bay.id] = _bayEnergyData[bay.id]!.applyAssessment(
              importAdjustment: latestAssessment.importAdjustment,
              exportAdjustment: latestAssessment.exportAdjustment,
            );
            debugPrint('Applied assessment for ${bay.name}');
          }
        }

        Map<String, Map<String, double>> temporaryBusFlows = {};
        for (var busbar in _allBaysInSubstation.where(
          (b) => b.bayType == 'Busbar',
        )) {
          temporaryBusFlows[busbar.id] = {'import': 0.0, 'export': 0.0};
        }

        for (var entry in _busbarEnergyMaps.values) {
          final Bay? connectedBay = _baysMap[entry.connectedBayId];
          final BayEnergyData? connectedBayEnergy =
              _bayEnergyData[entry.connectedBayId];

          if (connectedBay != null &&
              connectedBayEnergy != null &&
              temporaryBusFlows.containsKey(entry.busbarId)) {
            if (entry.importContribution == EnergyContributionType.busImport) {
              temporaryBusFlows[entry.busbarId]!['import'] =
                  (temporaryBusFlows[entry.busbarId]!['import'] ?? 0.0) +
                  (connectedBayEnergy.impConsumed ?? 0.0);
            } else if (entry.importContribution ==
                EnergyContributionType.busExport) {
              temporaryBusFlows[entry.busbarId]!['export'] =
                  (temporaryBusFlows[entry.busbarId]!['export'] ?? 0.0) +
                  (connectedBayEnergy.impConsumed ?? 0.0);
            }

            if (entry.exportContribution == EnergyContributionType.busImport) {
              temporaryBusFlows[entry.busbarId]!['import'] =
                  (temporaryBusFlows[entry.busbarId]!['import'] ?? 0.0) +
                  (connectedBayEnergy.expConsumed ?? 0.0);
            } else if (entry.exportContribution ==
                EnergyContributionType.busExport) {
              temporaryBusFlows[entry.busbarId]!['export'] =
                  (temporaryBusFlows[entry.busbarId]!['export'] ?? 0.0) +
                  (connectedBayEnergy.expConsumed ?? 0.0);
            }
          }
        }

        for (var busbar in _allBaysInSubstation.where(
          (b) => b.bayType == 'Busbar',
        )) {
          double busTotalImp = temporaryBusFlows[busbar.id]?['import'] ?? 0.0;
          double busTotalExp = temporaryBusFlows[busbar.id]?['export'] ?? 0.0;

          double busDifference = busTotalImp - busTotalExp;
          double busLossPercentage = 0.0;
          if (busTotalImp > 0) {
            busLossPercentage = (busDifference / busTotalImp) * 100;
          }

          _busEnergySummary[busbar.id] = {
            'totalImp': busTotalImp,
            'totalExp': busTotalExp,
            'difference': busDifference,
            'lossPercentage': busLossPercentage,
          };
          print(
            'DEBUG: Bus Energy Summary for ${busbar.name}: Imp=${busTotalImp}, Exp=${busTotalExp}, Diff=${busDifference}, Loss=${busLossPercentage}%',
          );
        }

        final highestVoltageBus = _allBaysInSubstation.firstWhereOrNull(
          (b) => b.bayType == 'Busbar',
        );
        final lowestVoltageBus = _allBaysInSubstation.lastWhereOrNull(
          (b) => b.bayType == 'Busbar',
        );

        double currentAbstractSubstationTotalImp = 0;
        double currentAbstractSubstationTotalExp = 0;

        if (highestVoltageBus != null) {
          currentAbstractSubstationTotalImp =
              (_busEnergySummary[highestVoltageBus.id]?['totalImp']) ?? 0.0;
        }
        if (lowestVoltageBus != null) {
          currentAbstractSubstationTotalExp =
              (_busEnergySummary[lowestVoltageBus.id]?['totalExp']) ?? 0.0;
        }

        double overallDifference =
            currentAbstractSubstationTotalImp -
            currentAbstractSubstationTotalExp;
        double overallLossPercentage = 0;
        if (currentAbstractSubstationTotalImp > 0) {
          overallLossPercentage =
              (overallDifference / currentAbstractSubstationTotalImp) * 100;
        }

        _abstractEnergyData = {
          'totalImp': currentAbstractSubstationTotalImp,
          'totalExp': currentAbstractSubstationTotalExp,
          'difference': overallDifference,
          'lossPercentage': overallLossPercentage,
        };

        final Map<String, AggregatedFeederEnergyData> tempAggregatedData = {};

        for (var bay in _allBaysInSubstation) {
          if (bay.bayType == 'Feeder') {
            final energyData = _bayEnergyData[bay.id];
            if (energyData != null) {
              final DistributionSubdivision? distSubdivision =
                  _distributionSubdivisionsMap[bay.distributionSubdivisionId];
              final DistributionDivision? distDivision =
                  _distributionDivisionsMap[distSubdivision
                      ?.distributionDivisionId];
              final DistributionCircle? distCircle =
                  _distributionCirclesMap[distDivision?.distributionCircleId];
              final DistributionZone? distZone =
                  _distributionZonesMap[distCircle?.distributionZoneId];

              final String zoneName = distZone?.name ?? 'N/A';
              final String circleName = distCircle?.name ?? 'N/A';
              final String divisionName = distDivision?.name ?? 'N/A';
              final String distSubdivisionName = distSubdivision?.name ?? 'N/A';

              final String groupKey =
                  '$zoneName-$circleName-$divisionName-$distSubdivisionName';

              final aggregatedEntry = tempAggregatedData.putIfAbsent(
                groupKey,
                () => AggregatedFeederEnergyData(
                  zoneName: zoneName,
                  circleName: circleName,
                  divisionName: divisionName,
                  distributionSubdivisionName: distSubdivisionName,
                ),
              );

              aggregatedEntry.importedEnergy += (energyData.impConsumed ?? 0.0);
              aggregatedEntry.exportedEnergy += (energyData.expConsumed ?? 0.0);
            }
          }
        }

        _aggregatedFeederEnergyData = tempAggregatedData.values.toList();

        _aggregatedFeederEnergyData.sort((a, b) {
          int result = a.zoneName.compareTo(b.zoneName);
          if (result != 0) return result;

          result = a.circleName.compareTo(b.circleName);
          if (result != 0) return result;

          result = a.divisionName.compareTo(b.divisionName);
          if (result != 0) return result;

          return a.distributionSubdivisionName.compareTo(
            b.distributionSubdivisionName,
          );
        });

        // Initialize _bayPositions, _textOffsets, _busbarLengths from loaded SLD layout.
        // This ensures they reflect the saved layout when the screen loads or refreshes.
        // Only do this if we are not actively dragging (selectedBayForMovementId == null)
        // AND if the maps are currently empty (to avoid overwriting live changes or re-initializing unnecessarily)
        if (_selectedBayForMovementId == null &&
            _substationSldLayout != null &&
            _bayPositions.isEmpty) {
          _substationSldLayout!.bayLayoutParameters.forEach((bayId, params) {
            _bayPositions[bayId] = Offset(
              params['x'] ?? 0.0,
              params['y'] ?? 0.0,
            );
            _textOffsets[bayId] = Offset(
              params['textOffsetDx'] ?? 0.0,
              params['textOffsetDy'] ?? 0.0,
            );
            if (params['busbarLength'] != null) {
              _busbarLengths[bayId] = params['busbarLength']!;
            }
          });
        }
      }
    } catch (e) {
      print("Error loading energy data: $e");
      if (mounted) {
        SnackBarUtils.showSnackBar(
          context,
          'Failed to load energy data: $e',
          isError: true,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _fetchTransmissionHierarchyData() async {
    _zonesMap.clear();
    _circlesMap.clear();
    _divisionsMap.clear();
    _subdivisionsMap.clear();
    _substationsMap.clear();

    final zonesSnapshot = await FirebaseFirestore.instance
        .collection('zones')
        .get();
    _zonesMap = {
      for (var doc in zonesSnapshot.docs) doc.id: Zone.fromFirestore(doc),
    };

    final circlesSnapshot = await FirebaseFirestore.instance
        .collection('circles')
        .get();
    _circlesMap = {
      for (var doc in circlesSnapshot.docs) doc.id: Circle.fromFirestore(doc),
    };

    final divisionsSnapshot = await FirebaseFirestore.instance
        .collection('divisions')
        .get();
    _divisionsMap = {
      for (var doc in divisionsSnapshot.docs)
        doc.id: Division.fromFirestore(doc),
    };

    final subdivisionsSnapshot = await FirebaseFirestore.instance
        .collection('subdivisions')
        .get();
    _subdivisionsMap = {
      for (var doc in subdivisionsSnapshot.docs)
        doc.id: Subdivision.fromFirestore(doc),
    };

    final substationsSnapshot = await FirebaseFirestore.instance
        .collection('substations')
        .get();
    _substationsMap = {
      for (var doc in substationsSnapshot.docs)
        doc.id: Substation.fromFirestore(doc),
    };
  }

  Future<void> _fetchDistributionHierarchyData() async {
    _distributionZonesMap.clear();
    _distributionCirclesMap.clear();
    _distributionDivisionsMap.clear();
    _distributionSubdivisionsMap.clear();

    final zonesSnapshot = await FirebaseFirestore.instance
        .collection('distributionZones')
        .get();
    _distributionZonesMap = {
      for (var doc in zonesSnapshot.docs)
        doc.id: DistributionZone.fromFirestore(doc),
    };

    final circlesSnapshot = await FirebaseFirestore.instance
        .collection('distributionCircles')
        .get();
    _distributionCirclesMap = {
      for (var doc in circlesSnapshot.docs)
        doc.id: DistributionCircle.fromFirestore(doc),
    };

    final divisionsSnapshot = await FirebaseFirestore.instance
        .collection('distributionDivisions')
        .get();
    _distributionDivisionsMap = {
      for (var doc in divisionsSnapshot.docs)
        doc.id: DistributionDivision.fromFirestore(doc),
    };

    final subdivisionsSnapshot = await FirebaseFirestore.instance
        .collection('distributionSubdivisions')
        .get();
    _distributionSubdivisionsMap = {
      for (var doc in subdivisionsSnapshot.docs)
        doc.id: DistributionSubdivision.fromFirestore(doc),
    };
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

  Future<void> _saveBusbarEnergyMap(BusbarEnergyMap map) async {
    if (_isViewingSavedSld) return;

    try {
      if (map.id == null) {
        await FirebaseFirestore.instance
            .collection('busbarEnergyMaps')
            .add(map.toFirestore());
      } else {
        await FirebaseFirestore.instance
            .collection('busbarEnergyMaps')
            .doc(map.id)
            .update(map.toFirestore());
      }
      await _loadEnergyData();
    } catch (e) {
      print('Error saving BusbarEnergyMap: $e');
      if (mounted) {
        SnackBarUtils.showSnackBar(
          context,
          'Failed to save energy map: $e',
          isError: true,
        );
      }
    }
  }

  Future<void> _deleteBusbarEnergyMap(String mapId) async {
    if (_isViewingSavedSld) return;

    try {
      await FirebaseFirestore.instance
          .collection('busbarEnergyMaps')
          .doc(mapId)
          .delete();
      await _loadEnergyData();
    } catch (e) {
      print('Error deleting BusbarEnergyMap: $e');
      if (mounted) {
        SnackBarUtils.showSnackBar(
          context,
          'Failed to delete energy map: $e',
          isError: true,
        );
      }
    }
  }

  void _showBusbarSelectionDialog() {
    if (_isViewingSavedSld) return;

    final List<Bay> busbars = _allBaysInSubstation
        .where((bay) => bay.bayType == 'Busbar')
        .toList();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Select Busbar'),
          content: busbars.isEmpty
              ? const Text('No busbars found in this substation.')
              : SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: busbars.map((busbar) {
                      return ListTile(
                        title: Text('${busbar.voltageLevel} ${busbar.name}'),
                        onTap: () {
                          Navigator.pop(context);
                          _showBusbarEnergyAssignmentDialog(busbar);
                        },
                      );
                    }).toList(),
                  ),
                ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  void _showBusbarEnergyAssignmentDialog(Bay busbar) {
    if (_isViewingSavedSld) return;

    final List<Bay> connectedBays = _allConnections
        .where(
          (conn) =>
              conn.sourceBayId == busbar.id || conn.targetBayId == busbar.id,
        )
        .map((conn) {
          final String otherBayId = conn.sourceBayId == busbar.id
              ? conn.targetBayId
              : conn.sourceBayId;
          return _baysMap[otherBayId];
        })
        .whereType<Bay>()
        .where((bay) => bay.bayType != 'Busbar')
        .toList();

    final Map<String, BusbarEnergyMap> currentBusbarMaps = {};
    _busbarEnergyMaps.forEach((key, value) {
      if (value.busbarId == busbar.id) {
        currentBusbarMaps[value.connectedBayId] = value;
      }
    });

    showDialog(
      context: context,
      builder: (context) => _BusbarEnergyAssignmentDialog(
        busbar: busbar,
        connectedBays: connectedBays,
        currentUser: widget.currentUser,
        currentMaps: currentBusbarMaps,
        onSaveMap: _saveBusbarEnergyMap,
        onDeleteMap: _deleteBusbarEnergyMap,
      ),
    );
  }

  /// Method to show the energy assessment dialog for a specific bay
  /// This is called AFTER the bay selection dialog.
  void _showEnergyAssessmentDialog(Bay bay, BayEnergyData? energyData) {
    if (_isViewingSavedSld) return;

    showDialog(
      context: context,
      builder: (context) => EnergyAssessmentDialog(
        bay: bay,
        currentUser: widget.currentUser,
        currentEnergyData: energyData,
        onSaveAssessment: _loadEnergyData,
        latestExistingAssessment: _latestAssessmentsPerBay[bay.id],
      ),
    );
  }

  /// NEW: Method to show a dialog for selecting a bay for assessment
  void _showBaySelectionForAssessment() {
    if (_isViewingSavedSld) return;

    final List<Bay> assessableBays = _allBaysInSubstation
        .where((bay) => ['Feeder', 'Line', 'Transformer'].contains(bay.bayType))
        .toList();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Select Bay for Assessment'),
          content: assessableBays.isEmpty
              ? const Text('No assessable bays found in this substation.')
              : SizedBox(
                  width: MediaQuery.of(context).size.width * 0.7,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: assessableBays.map((bay) {
                        return ListTile(
                          title: Text('${bay.name} (${bay.bayType})'),
                          onTap: () {
                            Navigator.pop(context);
                            _showEnergyAssessmentDialog(
                              bay,
                              _bayEnergyData[bay.id],
                            );
                          },
                        );
                      }).toList(),
                    ),
                  ),
                ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  /// Helper to get BayRenderData (copied from SubstationDetailScreen)
  BayRenderData? _getBayRenderData(
    String bayId,
    List<BayRenderData> bayRenderDataList,
  ) {
    try {
      return bayRenderDataList.firstWhere((data) => data.bay.id == bayId);
    } catch (e) {
      return null;
    }
  }

  /// Function to save position/textOffset/busbarLength changes to Firestore
  Future<void> _saveChangesToFirestore() async {
    if (_selectedBayForMovementId == null) return;
    if (_isViewingSavedSld) {
      SnackBarUtils.showSnackBar(
        context,
        'Cannot save position changes to a historical SLD.',
        isError: true,
      );
      return;
    }

    final bayId = _selectedBayForMovementId!;
    try {
      // Prepare the bayLayoutParameters map to save
      final Map<String, Map<String, double>> updatedLayoutParameters = Map.from(
        _substationSldLayout?.bayLayoutParameters ?? {},
      );

      // Update the specific bay's parameters
      updatedLayoutParameters[bayId] = {
        'x': _bayPositions[bayId]!.dx,
        'y': _bayPositions[bayId]!.dy,
        'textOffsetDx': _textOffsets[bayId]!.dx,
        'textOffsetDy': _textOffsets[bayId]!.dy,
        'busbarLength': _busbarLengths[bayId] ?? 0.0,
      };

      // Create a new or update existing SubstationSldLayout
      if (_substationSldLayout == null) {
        _substationSldLayout = SubstationSldLayout(
          id: widget.substationId,
          substationId: widget.substationId,
          createdAt: Timestamp.now(),
          lastModifiedAt: Timestamp.now(),
          createdBy: widget.currentUser.uid,
          lastModifiedBy: widget.currentUser.uid,
          bayLayoutParameters: updatedLayoutParameters,
        );
        await FirebaseFirestore.instance
            .collection('substationSldLayouts')
            .doc(widget.substationId)
            .set(_substationSldLayout!.toFirestore());
      } else {
        _substationSldLayout = _substationSldLayout!.copyWith(
          bayLayoutParameters: updatedLayoutParameters,
          lastModifiedAt: Timestamp.now(),
          lastModifiedBy: widget.currentUser.uid,
        );
        await FirebaseFirestore.instance
            .collection('substationSldLayouts')
            .doc(widget.substationId)
            .update(_substationSldLayout!.toFirestore());
      }

      if (mounted) {
        SnackBarUtils.showSnackBar(
          context,
          'Position changes saved successfully!',
        );
      }
      if (!_isViewingSavedSld) {
        // Reload data to ensure the SLD reflects the saved changes accurately
        await _loadEnergyData();
      }
    } catch (e) {
      if (mounted) {
        SnackBarUtils.showSnackBar(
          context,
          'Failed to save position changes: $e',
          isError: true,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _selectedBayForMovementId = null;
          _bayPositions.clear();
          _textOffsets.clear();
          _busbarLengths.clear();
        });
      }
    }
  }

  /// Method to show context menu for bay symbol actions
  void _showBaySymbolActions(
    BuildContext context,
    Bay bay,
    Offset tapPosition,
  ) {
    if (_isViewingSavedSld) {
      SnackBarUtils.showSnackBar(
        context,
        'Cannot modify bays in a saved historical SLD.',
      );
      return;
    }

    final List<PopupMenuEntry<String>> menuItems = [
      const PopupMenuItem<String>(
        value: 'adjust',
        child: ListTile(
          leading: Icon(Icons.open_with),
          title: Text('Adjust Position/Size'),
        ),
      ),
      const PopupMenuItem<String>(
        value: 'move_text',
        child: ListTile(
          leading: Icon(Icons.text_fields),
          title: Text('Adjust Text Position'),
        ),
      ),
    ];

    showMenu(
      context: context,
      position: RelativeRect.fromLTRB(
        tapPosition.dx,
        tapPosition.dy,
        MediaQuery.of(context).size.width - tapPosition.dx,
        MediaQuery.of(context).size.height - tapPosition.dy,
      ),
      items: menuItems,
    ).then((value) {
      if (value == 'adjust') {
        setState(() {
          _selectedBayForMovementId = bay.id;
          // Initialize temporary positions/offsets/lengths from the loaded SLD layout
          final bayLayout = _substationSldLayout?.bayLayoutParameters[bay.id];
          _bayPositions[bay.id] = Offset(
            bayLayout?['x'] ?? 0,
            bayLayout?['y'] ?? 0,
          );
          _textOffsets[bay.id] = Offset(
            bayLayout?['textOffsetDx'] ?? 0,
            bayLayout?['textOffsetDy'] ?? 0,
          );
          if (bay.bayType == 'Busbar') {
            _busbarLengths[bay.id] = bayLayout?['busbarLength'] ?? 200.0;
          }
          _movementMode = MovementMode.bay;
        });
        SnackBarUtils.showSnackBar(
          context,
          'Selected "${bay.name}". Use controls below to adjust.',
        );
      } else if (value == 'move_text') {
        setState(() {
          _selectedBayForMovementId = bay.id;
          _movementMode = MovementMode.text;
          // Initialize temporary text offset from the loaded SLD layout
          final bayLayout = _substationSldLayout?.bayLayoutParameters[bay.id];
          _textOffsets[bay.id] = Offset(
            bayLayout?['textOffsetDx'] ?? 0,
            bayLayout?['textOffsetDy'] ?? 0,
          );
        });
        SnackBarUtils.showSnackBar(
          context,
          'Selected "${bay.name}" text. Use controls below to adjust.',
        );
      }
    });
  }

  /// Method to handle moving the selected item (bay or text)
  void _moveSelectedItem(double dx, double dy) {
    setState(() {
      if (_movementMode == MovementMode.bay) {
        final currentOffset =
            _bayPositions[_selectedBayForMovementId] ?? Offset.zero;
        _bayPositions[_selectedBayForMovementId!] = Offset(
          currentOffset.dx + dx,
          currentOffset.dy + dy,
        );

        // If the moved item is a busbar, adjust connected transformers, lines, and feeders
        final movedBay = _baysMap[_selectedBayForMovementId];
        if (movedBay != null && movedBay.bayType == 'Busbar') {
          for (var conn in _allConnections) {
            String otherBayId = '';
            if (conn.sourceBayId == movedBay.id) {
              otherBayId = conn.targetBayId;
            } else if (conn.targetBayId == movedBay.id) {
              otherBayId = conn.sourceBayId;
            } else {
              continue; // Not connected to the moved busbar
            }

            final otherBay = _baysMap[otherBayId];
            if (otherBay != null) {
              if (otherBay.bayType == 'Transformer') {
                final String hvBusId = otherBay.hvBusId!;
                final String lvBusId = otherBay.lvBusId!;

                // Get the current effective positions of the connected busbars
                final double hvBusY = _bayPositions[hvBusId]?.dy ?? 0.0;
                final double lvBusY = _bayPositions[lvBusId]?.dy ?? 0.0;

                // Update the transformer's Y position
                _bayPositions[otherBay.id] = Offset(
                  _bayPositions[otherBay.id]?.dx ?? 0.0, // Keep current X
                  (hvBusY + lvBusY) / 2, // New Y is midpoint
                );
              } else if (otherBay.bayType == 'Line' ||
                  otherBay.bayType == 'Feeder') {
                Offset currentOtherBayPos =
                    _bayPositions[otherBay.id] ?? Offset.zero;
                _bayPositions[otherBay.id] = Offset(
                  currentOtherBayPos.dx,
                  // Use the moved busbar's new Y position as reference
                  (_bayPositions[movedBay.id]?.dy ?? 0.0) +
                      (otherBay.bayType == 'Line' ? -70 - 10 : 10),
                );
              }
            }
          }
        }
      } else {
        final currentOffset =
            _textOffsets[_selectedBayForMovementId] ?? Offset.zero;
        _textOffsets[_selectedBayForMovementId!] = Offset(
          currentOffset.dx + dx,
          currentOffset.dy + dy,
        );
      }
    });
  }

  /// Method to adjust busbar length
  void _adjustBusbarLength(double change) {
    setState(() {
      final currentLength = _busbarLengths[_selectedBayForMovementId!] ?? 100.0;
      _busbarLengths[_selectedBayForMovementId!] = max(
        20.0,
        currentLength + change,
      );
    });
  }

  /// Widget for movement controls
  Widget _buildMovementControls() {
    final selectedBayRenderData = _currentBayRenderDataList.firstWhereOrNull(
      (data) => data.bay.id == _selectedBayForMovementId,
    );

    if (selectedBayRenderData == null) return const SizedBox.shrink();

    final selectedBay = selectedBayRenderData.bay;

    return Container(
      padding: const EdgeInsets.all(8.0),
      color: Colors.blueGrey.shade800,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Editing: ${selectedBay.name}',
            style: const TextStyle(color: Colors.white, fontSize: 16),
          ),
          const SizedBox(height: 10),
          SegmentedButton<MovementMode>(
            segments: const [
              ButtonSegment(value: MovementMode.bay, label: Text('Move Bay')),
              ButtonSegment(value: MovementMode.text, label: Text('Move Text')),
            ],
            selected: {_movementMode},
            onSelectionChanged: (newSelection) {
              setState(() {
                _movementMode = newSelection.first;
              });
            },
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back),
                color: Colors.white,
                onPressed: () => _moveSelectedItem(-_movementStep, 0),
              ),
              Column(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_upward),
                    color: Colors.white,
                    onPressed: () => _moveSelectedItem(0, -_movementStep),
                  ),
                  IconButton(
                    icon: const Icon(Icons.arrow_downward),
                    color: Colors.white,
                    onPressed: () => _moveSelectedItem(0, _movementStep),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.arrow_forward),
                color: Colors.white,
                onPressed: () => _moveSelectedItem(_movementStep, 0),
              ),
            ],
          ),
          if (selectedBay.bayType == 'Busbar') ...[
            const SizedBox(height: 10),
            const Text('Busbar Length', style: TextStyle(color: Colors.white)),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.remove),
                  color: Colors.white,
                  onPressed: () => _adjustBusbarLength(-_busbarLengthStep),
                ),
                Text(
                  _busbarLengths[selectedBay.id]?.toStringAsFixed(0) ?? 'Auto',
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                ),
                IconButton(
                  icon: const Icon(Icons.add),
                  color: Colors.white,
                  onPressed: () => _adjustBusbarLength(_busbarLengthStep),
                ),
              ],
            ),
          ],
          const SizedBox(height: 10),
          ElevatedButton(
            onPressed: () async {
              await _saveChangesToFirestore();
            },
            child: const Text('Done & Save'),
          ),
        ],
      ),
    );
  }

  void _showBaySymbolActions(
    BuildContext context,
    Bay bay,
    Offset tapPosition,
  ) {
    final List<PopupMenuEntry<String>> menuItems = [
      const PopupMenuItem<String>(
        value: 'edit',
        child: ListTile(
          leading: Icon(Icons.edit),
          title: Text('Edit Bay Details'),
        ),
      ),
      const PopupMenuItem<String>(
        value: 'adjust',
        child: ListTile(
          leading: Icon(Icons.open_with),
          title: Text('Adjust Position/Size'),
        ),
      ),
    ];

    if (bay.bayType != 'Busbar') {
      menuItems.add(
        const PopupMenuItem<String>(
          value: 'manage_equipment',
          child: ListTile(
            leading: Icon(Icons.settings),
            title: Text('Manage Equipment'),
          ),
        ),
      );
    }

    menuItems.add(
      const PopupMenuItem<String>(
        value: 'readings',
        child: ListTile(
          leading: Icon(Icons.menu_book),
          title: Text('Manage Reading Assignments'),
        ),
      ),
    );

    menuItems.add(
      PopupMenuItem<String>(
        value: 'delete',
        child: ListTile(
          leading: Icon(
            Icons.delete,
            color: Theme.of(context).colorScheme.error,
          ),
          title: Text(
            'Delete Bay',
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ),
      ),
    );

    showMenu(
      context: context,
      position: RelativeRect.fromLTRB(
        tapPosition.dx,
        tapPosition.dy,
        MediaQuery.of(context).size.width - tapPosition.dx,
        MediaQuery.of(context).size.height - tapPosition.dy,
      ),
      items: menuItems,
    ).then((value) {
      if (value == 'edit') {
        _setViewMode(BayDetailViewMode.edit, bay: bay);
      } else if (value == 'adjust') {
        setState(() {
          _selectedBayForMovementId = bay.id;
          // Initialize temporary positions/offsets/lengths from the loaded SLD layout
          final bayLayout = _substationSldLayout?.bayLayoutParameters[bay.id];
          _bayPositions[bay.id] = Offset(
            bayLayout?['x'] ?? 0,
            bayLayout?['y'] ?? 0,
          );
          _textOffsets[bay.id] = Offset(
            bayLayout?['textOffsetDx'] ?? 0,
            bayLayout?['textOffsetDy'] ?? 0,
          );
          if (bay.bayType == 'Busbar') {
            _busbarLengths[bay.id] = bayLayout?['busbarLength'] ?? 200.0;
          }
          _movementMode = MovementMode.bay;
        });
        SnackBarUtils.showSnackBar(
          context,
          'Selected "${bay.name}". Use controls below to adjust.',
        );
      } else if (value == 'manage_equipment') {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => BayEquipmentManagementScreen(
              bayId: bay.id,
              bayName: bay.name,
              substationId: widget.substationId,
              currentUser: widget.currentUser,
            ),
          ),
        );
      } else if (value == 'readings') {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => BayReadingAssignmentScreen(
              bayId: bay.id,
              bayName: bay.name,
              currentUser: widget.currentUser,
            ),
          ),
        );
      } else if (value == 'delete') {
        _confirmDeleteBay(context, bay);
      }
    });
  }

  BayRenderData? _getBayRenderData(
    String bayId,
    List<BayRenderData> bayRenderDataList,
  ) {
    try {
      return bayRenderDataList.firstWhere((data) => data.bay.id == bayId);
    } catch (e) {
      return null;
    }
  }

  Future<void> _saveChangesToFirestore() async {
    if (_selectedBayForMovementId == null) return;

    final bayId = _selectedBayForMovementId!;
    try {
      // Prepare the bayLayoutParameters map to save
      final Map<String, Map<String, double>> updatedLayoutParameters = Map.from(
        _substationSldLayout?.bayLayoutParameters ?? {},
      );

      // Update the specific bay's parameters
      updatedLayoutParameters[bayId] = {
        'x': _bayPositions[bayId]!.dx,
        'y': _bayPositions[bayId]!.dy,
        'textOffsetDx': _textOffsets[bayId]!.dx,
        'textOffsetDy': _textOffsets[bayId]!.dy,
        'busbarLength': _busbarLengths[bayId] ?? 0.0,
      };

      // Create a new or update existing SubstationSldLayout
      if (_substationSldLayout == null) {
        _substationSldLayout = SubstationSldLayout(
          id: widget.substationId,
          substationId: widget.substationId,
          createdAt: Timestamp.now(),
          lastModifiedAt: Timestamp.now(),
          createdBy: widget.currentUser.uid,
          lastModifiedBy: widget.currentUser.uid,
          bayLayoutParameters: updatedLayoutParameters,
        );
        await FirebaseFirestore.instance
            .collection('substationSldLayouts')
            .doc(widget.substationId)
            .set(_substationSldLayout!.toFirestore());
      } else {
        _substationSldLayout = _substationSldLayout!.copyWith(
          bayLayoutParameters: updatedLayoutParameters,
          lastModifiedAt: Timestamp.now(),
          lastModifiedBy: widget.currentUser.uid,
        );
        await FirebaseFirestore.instance
            .collection('substationSldLayouts')
            .doc(widget.substationId)
            .update(_substationSldLayout!.toFirestore());
      }

      if (mounted) {
        SnackBarUtils.showSnackBar(context, 'Changes saved successfully!');
      }
    } catch (e) {
      if (mounted) {
        SnackBarUtils.showSnackBar(
          context,
          'Failed to save changes: $e',
          isError: true,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _selectedBayForMovementId = null;
          // Clear temporary positions after saving, so next render pulls from Firestore via _onPainterLayoutCalculated
          _bayPositions.clear();
          _textOffsets.clear();
          _busbarLengths.clear();
        });
      }
    }
  }

  Future<void> _confirmDeleteBay(BuildContext context, Bay bay) async {
    final bool confirm =
        await showDialog(
          context: context,
          builder: (BuildContext context) => AlertDialog(
            title: const Text('Confirm Deletion'),
            content: Text(
              'Are you sure you want to delete bay "${bay.name}"? This will also remove all associated equipment and connections. This action cannot be undone.',
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text('Delete'),
              ),
            ],
          ),
        ) ??
        false;
    if (confirm) {
      try {
        debugPrint('Attempting to delete bay: ${bay.id}');
        await FirebaseFirestore.instance
            .collection('bays')
            .doc(bay.id)
            .delete();
        debugPrint('Bay deleted: ${bay.id}. Now deleting connections...');
        final batch = FirebaseFirestore.instance.batch();
        final connectionsSnapshot = await FirebaseFirestore.instance
            .collection('bay_connections')
            .where('substationId', isEqualTo: widget.substationId)
            .where(
              Filter.or(
                Filter('sourceBayId', isEqualTo: bay.id),
                Filter('targetBayId', isEqualTo: bay.id),
              ),
            )
            .get();
        for (var doc in connectionsSnapshot.docs) {
          batch.delete(doc.reference);
        }
        await batch.commit();
        debugPrint('Connections deleted for bay: ${bay.id}');
        if (mounted) {
          SnackBarUtils.showSnackBar(
            context,
            'Bay "${bay.name}" deleted successfully!',
          );
          // After deleting a bay, re-fetch the SLD layout to ensure any auto-layout
          // adjustments for remaining bays are considered.
          _fetchSubstationSldLayout();
        }
      } catch (e) {
        debugPrint('Error deleting bay: $e');
        if (mounted) {
          SnackBarUtils.showSnackBar(
            context,
            'Failed to delete bay: $e',
            isError: true,
          );
        }
      }
    }
  }

  Widget _buildSLDView() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('bays')
          .where('substationId', isEqualTo: widget.substationId)
          .snapshots(),
      builder: (context, baysSnapshot) {
        if (baysSnapshot.hasError) {
          return Center(child: Text('Error: ${baysSnapshot.error}'));
        }
        if (baysSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!baysSnapshot.hasData || baysSnapshot.data!.docs.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: Text('No bays found. Click "+" to add one.'),
            ),
          );
        }

        // Update class-level _allBays and _baysMap
        _allBays = baysSnapshot.data!.docs
            .map((doc) => Bay.fromFirestore(doc))
            .toList();
        _baysMap = {for (var bay in _allBays) bay.id: bay};

        // If layout not loaded yet, show loading. This handles the initial fetch.
        // Or if bays are loaded but layout is not.
        if (_substationSldLayout == null) {
          return const Center(child: CircularProgressIndicator());
        }

        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('bay_connections')
              .where('substationId', isEqualTo: widget.substationId)
              .snapshots(),
          builder: (context, connectionsSnapshot) {
            if (connectionsSnapshot.hasError) {
              return Center(child: Text('Error: ${connectionsSnapshot.error}'));
            }
            if (connectionsSnapshot.connectionState ==
                ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            // Update class-level _allConnections
            _allConnections =
                connectionsSnapshot.data?.docs
                    .map((doc) => BayConnection.fromFirestore(doc))
                    .toList() ??
                [];

            return StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('equipmentInstances')
                  .where('substationId', isEqualTo: widget.substationId)
                  .snapshots(),
              builder: (context, equipmentSnapshot) {
                if (equipmentSnapshot.hasError) {
                  return Center(
                    child: Text('Error: ${equipmentSnapshot.error}'),
                  );
                }
                if (equipmentSnapshot.connectionState ==
                    ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                // Update class-level _allEquipmentInstances and _equipmentByBayId
                _allEquipmentInstances =
                    equipmentSnapshot.data?.docs
                        .map((doc) => EquipmentInstance.fromFirestore(doc))
                        .toList() ??
                    [];

                _equipmentByBayId.clear();
                for (var eq in _allEquipmentInstances) {
                  _equipmentByBayId.putIfAbsent(eq.bayId, () => []).add(eq);
                }

                return LayoutBuilder(
                  builder: (context, constraints) {
                    // Max size for the painter's canvas, allowing InteractiveViewer to handle scaling
                    final painterCanvasSize = Size(
                      constraints.maxWidth * 2,
                      constraints.maxHeight * 2,
                    );

                    return InteractiveViewer(
                      transformationController: _transformationController,
                      boundaryMargin: const EdgeInsets.all(double.infinity),
                      minScale: 0.1,
                      maxScale: 4.0,
                      constrained: false, // Important for custom painter size
                      child: GestureDetector(
                        // GestureDetector wraps CustomPaint
                        behavior: HitTestBehavior
                            .opaque, // Ensures gestures are captured over transparent areas
                        onTapUp: (details) {
                          // Transform local position to painter's coordinate system
                          final RenderBox renderBox =
                              context.findRenderObject() as RenderBox;
                          final Offset localPosition = renderBox.globalToLocal(
                            details.globalPosition,
                          );
                          final scenePosition = _transformationController
                              .toScene(localPosition);

                          // Use the _currentBayRenderDataList populated by the painter for hit testing
                          final tappedBay = _currentBayRenderDataList
                              .firstWhere(
                                (data) => data.rect.contains(scenePosition),
                                orElse: _createDummyBayRenderData,
                              );

                          if (tappedBay.bay.id != 'dummy') {
                            if (_selectedBayForMovementId == null) {
                              _showBaySymbolActions(
                                context,
                                tappedBay.bay,
                                details.globalPosition,
                              );
                            }
                          }
                        },
                        onLongPressStart: (details) {
                          // Transform local position to painter's coordinate system
                          final RenderBox renderBox =
                              context.findRenderObject() as RenderBox;
                          final Offset localPosition = renderBox.globalToLocal(
                            details.globalPosition,
                          );
                          final scenePosition = _transformationController
                              .toScene(localPosition);

                          // Use the _currentBayRenderDataList populated by the painter for hit testing
                          final tappedBay = _currentBayRenderDataList
                              .firstWhere(
                                (data) => data.rect.contains(scenePosition),
                                orElse: _createDummyBayRenderData,
                              );
                          if (tappedBay.bay.id != 'dummy') {
                            _showBaySymbolActions(
                              context,
                              tappedBay.bay,
                              details.globalPosition,
                            );
                          }
                        },
                        child: CustomPaint(
                          size: painterCanvasSize,
                          painter: SingleLineDiagramPainter(
                            allBays: _allBays, // Pass class-level variable
                            bayConnections:
                                _allConnections, // Pass class-level variable
                            baysMap: _baysMap, // Pass class-level variable
                            createDummyBayRenderData: _createDummyBayRenderData,
                            debugDrawHitboxes: true, // Keep for debugging
                            selectedBayForMovementId: _selectedBayForMovementId,
                            currentBayPositions:
                                _bayPositions, // Pass screen's live editing state
                            currentTextOffsets:
                                _textOffsets, // Pass screen's live editing state
                            currentBusbarLengths:
                                _busbarLengths, // Pass screen's live editing state
                            bayEnergyData:
                                const {}, // No energy data on this screen
                            busEnergySummary:
                                const {}, // No energy data on this screen
                            savedBayLayoutParameters:
                                _substationSldLayout?.bayLayoutParameters ??
                                {}, // Pass the fetched saved layout
                            onLayoutCalculated:
                                _onPainterLayoutCalculated, // Receive layout data from painter
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  double _getVoltageLevelValue(String voltageLevel) {
    final regex = RegExp(r'(\d+(\.\d+)?)');
    final match = regex.firstMatch(voltageLevel);
    if (match != null) {
      return double.tryParse(match.group(1)!) ?? 0.0;
    }
    return 0.0;
  }
}

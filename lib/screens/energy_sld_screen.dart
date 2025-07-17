// lib/screens/energy_sld_screen.dart
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math';
import 'package:collection/collection.dart';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';
import 'dart:ui' as ui;
import 'package:intl/intl.dart';
import 'package:widgets_to_image/widgets_to_image.dart';
import 'package:provider/provider.dart';

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
import '../utils/snackbar_utils.dart';
import '../utils/pdf_generator.dart'; //

import '../painters/single_line_diagram_painter.dart';
import '../widgets/energy_assessment_dialog.dart';
import '../widgets/sld_view_widget.dart'; // Import the new SLD view widget
import '../controllers/sld_controller.dart'; // Import the new controller
import '../enums/movement_mode.dart';

/// Data model for energy data associated with a bay (remains the same)
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

/// Data model for Aggregated Feeder Energy Table (remains the same)
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

/// Data model for rendering the SLD with energy data (adjusted slightly)
class SldRenderData {
  final List<BayRenderData> bayRenderDataList;
  final Map<String, Rect> finalBayRects;
  final Map<String, Rect> busbarRects;
  final Map<String, Map<String, Offset>> busbarConnectionPoints;
  final Map<String, BayEnergyData>
  bayEnergyData; // Now directly holds BayEnergyData
  final Map<String, Map<String, double>> busEnergySummary;
  final Map<String, dynamic> abstractEnergyData;
  final List<AggregatedFeederEnergyData> aggregatedFeederEnergyData;

  SldRenderData({
    required this.bayRenderDataList,
    required this.finalBayRects,
    required this.busbarRects,
    required this.busbarConnectionPoints,
    required this.bayEnergyData,
    required this.busEnergySummary,
    required this.abstractEnergyData,
    required this.aggregatedFeederEnergyData,
  });

  Map<String, dynamic> toMap() {
    return {
      'bayPositions': {
        for (var renderData in bayRenderDataList)
          renderData.bay.id: {
            'x': renderData.bay.xPosition,
            'y': renderData.bay.yPosition,
            'textOffsetDx': renderData.bay.textOffset?.dx,
            'textOffsetDy': renderData.bay.textOffset?.dy,
            'busbarLength': renderData.bay.busbarLength,
            'energyReadingOffsetDx': renderData.bay.energyReadingOffset?.dx,
            'energyReadingOffsetDy': renderData.bay.energyReadingOffset?.dy,
            'energyReadingFontSize': renderData.bay.energyReadingFontSize,
            'energyReadingIsBold': renderData.bay.energyReadingIsBold,
          },
      },
      'bayEnergyData': {
        for (var entry in bayEnergyData.entries) entry.key: entry.value.toMap(),
      },
      'busEnergySummary': busEnergySummary,
      'abstractEnergyData': abstractEnergyData,
      'aggregatedFeederEnergyData': aggregatedFeederEnergyData
          .map((e) => e.toMap())
          .toList(),
    };
  }

  factory SldRenderData.fromMap(
    Map<String, dynamic> map,
    Map<String, Bay> baysMap,
  ) {
    Map<String, BayEnergyData> deserializedBayEnergyData =
        (map['bayEnergyData'] as Map<String, dynamic>?)?.map(
          (key, value) => MapEntry(
            key,
            BayEnergyData.fromMap(value as Map<String, dynamic>),
          ),
        ) ??
        {};

    Map<String, Map<String, double>> deserializedBusEnergySummary =
        (map['busEnergySummary'] as Map<String, dynamic>?)?.map(
          (key, value) => MapEntry(
            key,
            Map<String, double>.from(value as Map<String, dynamic>? ?? {}),
          ),
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

    List<BayRenderData> deserializedBayRenderDataList = [];
    if (map['bayPositions'] != null) {
      (map['bayPositions'] as Map<String, dynamic>).forEach((
        bayId,
        positionData,
      ) {
        final Bay? originalBay = baysMap[bayId];
        if (originalBay != null) {
          final double? x = (positionData['x'] as num?)?.toDouble();
          final double? y = (positionData['y'] as num?)?.toDouble();
          final double? textOffsetDx = (positionData['textOffsetDx'] as num?)
              ?.toDouble();
          final double? textOffsetDy = (positionData['textOffsetDy'] as num?)
              ?.toDouble();
          final double? busbarLength = (positionData['busbarLength'] as num?)
              ?.toDouble();
          final double? energyReadingOffsetDx =
              (positionData['energyReadingOffsetDx'] as num?)?.toDouble();
          final double? energyReadingOffsetDy =
              (positionData['energyReadingOffsetDy'] as num?)?.toDouble();
          final double? energyReadingFontSize =
              (positionData['energyReadingFontSize'] as num?)?.toDouble();
          final bool? energyReadingIsBold =
              (positionData['energyReadingIsBold'] as bool?);

          final Bay bayWithPosition = originalBay.copyWith(
            xPosition: x,
            yPosition: y,
            textOffset: (textOffsetDx != null && textOffsetDy != null)
                ? Offset(textOffsetDx, textOffsetDy)
                : null,
            busbarLength: busbarLength,
            energyReadingOffset:
                (energyReadingOffsetDx != null && energyReadingOffsetDy != null)
                ? Offset(energyReadingOffsetDx, energyReadingOffsetDy)
                : null,
            energyReadingFontSize: energyReadingFontSize,
            energyReadingIsBold: energyReadingIsBold,
          );

          deserializedBayRenderDataList.add(
            BayRenderData(
              bay: bayWithPosition,
              rect: Rect.zero,
              center: Offset(x ?? 0, y ?? 0),
              topCenter: Offset(x ?? 0, y ?? 0),
              bottomCenter: Offset(x ?? 0, y ?? 0),
              leftCenter: Offset(x ?? 0, y ?? 0),
              rightCenter: Offset(x ?? 0, y ?? 0),
              equipmentInstances: const [],
              textOffset: (textOffsetDx != null && textOffsetDy != null)
                  ? Offset(textOffsetDx, textOffsetDy)
                  : Offset.zero,
              busbarLength: busbarLength ?? 0.0,
              energyReadingOffset:
                  (energyReadingOffsetDx != null &&
                      energyReadingOffsetDy != null)
                  ? Offset(energyReadingOffsetDx, energyReadingOffsetDy)
                  : Offset.zero,
              energyReadingFontSize: energyReadingFontSize ?? 9.0,
              energyReadingIsBold: energyReadingIsBold ?? false,
            ),
          );
        }
      });
    }

    return SldRenderData(
      bayRenderDataList: deserializedBayRenderDataList,
      finalBayRects: {}, // Will be dynamically generated
      busbarRects: {}, // Will be dynamically generated
      busbarConnectionPoints: {}, // Will be dynamically generated
      bayEnergyData:
          deserializedBayEnergyData, // Now using the deserialized map
      busEnergySummary: deserializedBusEnergySummary,
      abstractEnergyData: deserializedAbstractEnergyData,
      aggregatedFeederEnergyData: deserializedAggregatedFeederEnergyData,
    );
  }
}

final GlobalKey<ScaffoldMessengerState> energySldScaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

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

  @override
  State<EnergySldScreen> createState() => _EnergySldScreenState();
}

class _EnergySldScreenState extends State<EnergySldScreen> {
  bool _isLoading = true;
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 1));
  DateTime _endDate = DateTime.now();
  bool _showTables = true;

  // No longer directly storing _allBaysInSubstation, _baysMap, _allConnections
  // These will come from SldController
  Map<String, BusbarEnergyMap> _busbarEnergyMaps = {};
  List<Assessment> _allAssessmentsForDisplay = [];

  bool _isViewingSavedSld = false;
  Map<String, dynamic>? _loadedSldParameters;
  List<Map<String, dynamic>> _loadedAssessmentsSummary = [];

  final WidgetsToImageController _widgetsToImageController =
      WidgetsToImageController();
  bool _isCapturingPdf = false;
  Matrix4? _originalTransformation;

  // SldController will manage selectedBayForMovementId and movementMode, etc.
  // We will interact with it via Provider.

  // Hierarchy maps for lookup (Transmission Hierarchy)
  Map<String, Zone> _zonesMap = {};
  Map<String, Circle> _circlesMap = {};
  Map<String, Division> _divisionsMap = {};
  Map<String, Subdivision> _subdivisionsMap = {};
  Map<String, Substation> _substationsMap = {};

  // Maps for Distribution Hierarchy lookup
  Map<String, DistributionZone> _distributionZonesMap = {};
  Map<String, DistributionCircle> _distributionCirclesMap = {};
  Map<String, DistributionDivision> _distributionDivisionsMap = {};
  Map<String, DistributionSubdivision> _distributionSubdivisionsMap = {};

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
      _loadEnergyData(fromSaved: true);
    } else {
      if (widget.substationId.isNotEmpty) {
        _loadEnergyData();
      } else {
        _isLoading = false;
      }
    }
  }

  @override
  void dispose() {
    // No need to dispose transformationController here, it's managed by SldController
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
      _busbarEnergyMaps.clear();
      // sldController.latestAssessmentsPerBay.clear(); // This is in the controller now
      _allAssessmentsForDisplay.clear();
    });

    final sldController = Provider.of<SldController>(context, listen: false);

    try {
      await _fetchTransmissionHierarchyData();
      await _fetchDistributionHierarchyData();

      if (fromSaved && _loadedSldParameters != null) {
        debugPrint('Loading energy data from SAVED SLD.');
        final savedSldData = SldRenderData.fromMap(
          _loadedSldParameters!,
          sldController.baysMap,
        );

        // Update sldController's internal bay properties with loaded positions/offsets
        for (var renderData in savedSldData.bayRenderDataList) {
          final Bay originalBay = sldController.baysMap[renderData.bay.id]!;
          final int index = sldController.allBays.indexWhere(
            (b) => b.id == renderData.bay.id,
          );
          if (index != -1) {
            sldController.allBays[index] =
                renderData.bay; // Update with saved position/offsets
            sldController.baysMap[renderData.bay.id] =
                renderData.bay; // Update the map too
          }
        }
        // Force SldController to rebuild its render data based on the updated `_allBays`
        sldController.updateEnergyData(
          bayEnergyData: savedSldData.bayEnergyData,
          busEnergySummary: savedSldData.busEnergySummary,
          abstractEnergyData: savedSldData.abstractEnergyData,
          aggregatedFeederEnergyData: savedSldData.aggregatedFeederEnergyData,
          latestAssessmentsPerBay:
              {}, // Assessments will be loaded separately, so clear this for saved load
        );
        sldController
            .notifyListeners(); // Ensure SLD redraws with saved positions

        _allAssessmentsForDisplay = _loadedAssessmentsSummary
            .map((e) => Assessment.fromMap(e))
            .toList();
      } else {
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

        final startOfEndDate = DateTime(
          _endDate.year,
          _endDate.month,
          _endDate.day,
        );
        final endOfEndDate = DateTime(
          _endDate.year,
          _endDate.month,
          _endDate.day,
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
            .where(
              'readingTimestamp',
              isGreaterThanOrEqualTo: Timestamp.fromDate(startOfStartDate),
            )
            .where(
              'readingTimestamp',
              isLessThanOrEqualTo: Timestamp.fromDate(endOfEndDate),
            )
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
              .where(
                'readingTimestamp',
                isGreaterThanOrEqualTo: Timestamp.fromDate(startOfEndDate),
              )
              .where(
                'readingTimestamp',
                isLessThanOrEqualTo: Timestamp.fromDate(endOfEndDate),
              )
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
        sldController.latestAssessmentsPerBay.clear(); // Clear controller's map

        for (var doc in assessmentsRawSnapshot.docs) {
          final assessment = Assessment.fromFirestore(doc);
          _allAssessmentsForDisplay.add(assessment);
          if (!sldController.latestAssessmentsPerBay.containsKey(
            assessment.bayId,
          )) {
            sldController.latestAssessmentsPerBay[assessment.bayId] =
                assessment;
          }
        }
        _allAssessmentsForDisplay.sort(
          (a, b) => b.assessmentTimestamp.compareTo(a.assessmentTimestamp),
        );

        Map<String, BayEnergyData> calculatedBayEnergyData = {};
        for (var bay in sldController.allBays) {
          // Use bays from controller
          final double? mf = bay.multiplyingFactor;
          double calculatedImpConsumed = 0.0;
          double calculatedExpConsumed = 0.0;

          bool bayHasAssessmentForPeriod = sldController.latestAssessmentsPerBay
              .containsKey(bay.id);

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

            calculatedBayEnergyData[bay.id] = BayEnergyData(
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

            calculatedBayEnergyData[bay.id] = BayEnergyData(
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

          final latestAssessment =
              sldController.latestAssessmentsPerBay[bay.id];
          if (latestAssessment != null) {
            calculatedBayEnergyData[bay.id] = calculatedBayEnergyData[bay.id]!
                .applyAssessment(
                  importAdjustment: latestAssessment.importAdjustment,
                  exportAdjustment: latestAssessment.exportAdjustment,
                );
            debugPrint('Applied assessment for ${bay.name}');
          }
        }

        Map<String, Map<String, double>> temporaryBusFlows = {};
        for (var busbar in sldController.allBays.where(
          (b) => b.bayType == 'Busbar',
        )) {
          temporaryBusFlows[busbar.id] = {'import': 0.0, 'export': 0.0};
        }

        for (var entry in _busbarEnergyMaps.values) {
          final Bay? connectedBay = sldController.baysMap[entry.connectedBayId];
          final BayEnergyData? connectedBayEnergy =
              calculatedBayEnergyData[entry.connectedBayId];

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

        Map<String, Map<String, double>> calculatedBusEnergySummary = {};
        for (var busbar in sldController.allBays.where(
          (b) => b.bayType == 'Busbar',
        )) {
          double busTotalImp = temporaryBusFlows[busbar.id]?['import'] ?? 0.0;
          double busTotalExp = temporaryBusFlows[busbar.id]?['export'] ?? 0.0;

          double busDifference = busTotalImp - busTotalExp;
          double busLossPercentage = 0.0;
          if (busTotalImp > 0) {
            busLossPercentage = (busDifference / busTotalImp) * 100;
          }

          calculatedBusEnergySummary[busbar.id] = {
            'totalImp': busTotalImp,
            'totalExp': busTotalExp,
            'difference': busDifference,
            'lossPercentage': busLossPercentage,
          };
          print(
            'DEBUG: Bus Energy Summary for ${busbar.name}: Imp=${busTotalImp}, Exp=${busTotalExp}, Diff=${busDifference}, Loss=${busLossPercentage}%',
          );
        }

        final highestVoltageBus = sldController.allBays.firstWhereOrNull(
          (b) => b.bayType == 'Busbar',
        );
        final lowestVoltageBus = sldController.allBays.lastWhereOrNull(
          (b) => b.bayType == 'Busbar',
        );

        double currentAbstractSubstationTotalImp = 0;
        double currentAbstractSubstationTotalExp = 0;

        if (highestVoltageBus != null) {
          currentAbstractSubstationTotalImp =
              (calculatedBusEnergySummary[highestVoltageBus.id]?['totalImp']) ??
              0.0;
        }
        if (lowestVoltageBus != null) {
          currentAbstractSubstationTotalExp =
              (calculatedBusEnergySummary[lowestVoltageBus.id]?['totalExp']) ??
              0.0;
        }

        double overallDifference =
            currentAbstractSubstationTotalImp -
            currentAbstractSubstationTotalExp;
        double overallLossPercentage = 0;
        if (currentAbstractSubstationTotalImp > 0) {
          overallLossPercentage =
              (overallDifference / currentAbstractSubstationTotalImp) * 100;
        }

        Map<String, dynamic> calculatedAbstractEnergyData = {
          'totalImp': currentAbstractSubstationTotalImp,
          'totalExp': currentAbstractSubstationTotalExp,
          'difference': overallDifference,
          'lossPercentage': overallLossPercentage,
        };

        final Map<String, AggregatedFeederEnergyData> tempAggregatedData = {};

        for (var bay in sldController.allBays) {
          // Use bays from controller
          if (bay.bayType == 'Feeder') {
            final energyData = calculatedBayEnergyData[bay.id];
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

        List<AggregatedFeederEnergyData> calculatedAggregatedFeederEnergyData =
            tempAggregatedData.values.toList();
        calculatedAggregatedFeederEnergyData.sort((a, b) {
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

        // Update the SldController with the calculated energy data
        sldController.updateEnergyData(
          bayEnergyData: calculatedBayEnergyData,
          busEnergySummary: calculatedBusEnergySummary,
          abstractEnergyData: calculatedAbstractEnergyData,
          aggregatedFeederEnergyData: calculatedAggregatedFeederEnergyData,
          latestAssessmentsPerBay: sldController
              .latestAssessmentsPerBay, // Pass the same map to the controller
        );
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
    final sldController = Provider.of<SldController>(context, listen: false);

    final List<Bay> busbars = sldController.allBays
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
                          _showBusbarEnergyAssignmentDialog(
                            busbar,
                            sldController,
                          );
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

  void _showBusbarEnergyAssignmentDialog(
    Bay busbar,
    SldController sldController,
  ) {
    if (_isViewingSavedSld) return;

    final List<Bay> connectedBays = sldController.allConnections
        .where(
          (conn) =>
              conn.sourceBayId == busbar.id || conn.targetBayId == busbar.id,
        )
        .map((conn) {
          final String otherBayId = conn.sourceBayId == busbar.id
              ? conn.targetBayId
              : conn.sourceBayId;
          return sldController.baysMap[otherBayId];
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

  void _showEnergyAssessmentDialog(Bay bay, BayEnergyData? energyData) {
    if (_isViewingSavedSld) return;
    final sldController = Provider.of<SldController>(context, listen: false);

    showDialog(
      context: context,
      builder: (context) => EnergyAssessmentDialog(
        bay: bay,
        currentUser: widget.currentUser,
        currentEnergyData: energyData,
        onSaveAssessment: _loadEnergyData,
        latestExistingAssessment: sldController
            .latestAssessmentsPerBay[bay.id], // Use controller's map
      ),
    );
  }

  void _showBaySelectionForAssessment() {
    if (_isViewingSavedSld) return;
    final sldController = Provider.of<SldController>(context, listen: false);

    final List<Bay> assessableBays = sldController.allBays
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
                              sldController.bayEnergyData[bay
                                  .id], // Use controller's map
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

  Future<void> _saveSld() async {
    if (_isViewingSavedSld) {
      SnackBarUtils.showSnackBar(
        context,
        'Cannot re-save a loaded historical SLD. Please go to a live SLD to save.',
        isError: true,
      );
      return;
    }

    TextEditingController sldNameController = TextEditingController();
    final String? sldName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Save SLD As...'),
        content: TextField(
          controller: sldNameController,
          decoration: const InputDecoration(hintText: "Enter SLD name"),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (sldNameController.text.trim().isEmpty) {
                SnackBarUtils.showSnackBar(
                  context,
                  'SLD name cannot be empty!',
                  isError: true,
                );
              } else {
                Navigator.pop(context, sldNameController.text.trim());
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (sldName == null || sldName.isEmpty) return;

    setState(() {
      _isLoading = true;
    });

    final sldController = Provider.of<SldController>(context, listen: false);

    try {
      final Map<String, dynamic> currentSldParameters = {
        'bayPositions': {
          for (var renderData
              in sldController
                  .bayRenderDataList) // Use rendered data for current positions
            renderData.bay.id: {
              'x': renderData.rect.center.dx, // Use current rendered X
              'y': renderData.rect.center.dy, // Use current rendered Y
              'textOffsetDx': renderData.textOffset.dx,
              'textOffsetDy': renderData.textOffset.dy,
              'busbarLength': renderData.busbarLength,
              'energyReadingOffsetDx': renderData.energyReadingOffset.dx,
              'energyReadingOffsetDy': renderData.energyReadingOffset.dy,
              'energyReadingFontSize': renderData.energyReadingFontSize,
              'energyReadingIsBold': renderData.energyReadingIsBold,
            },
        },
        'bayEnergyData': {
          for (var entry in sldController.bayEnergyData.entries)
            entry.key: entry.value.toMap(),
        },
        'busEnergySummary': sldController.busEnergySummary,
        'abstractEnergyData': sldController.abstractEnergyData,
        'aggregatedFeederEnergyData': sldController.aggregatedFeederEnergyData
            .map((e) => e.toMap())
            .toList(),
        'bayNamesLookup': {
          for (var bay in sldController.allBays)
            bay.id: bay.name, // Use controller's bays
        },
      };

      final List<Map<String, dynamic>> currentAssessmentsSummary =
          _allAssessmentsForDisplay
              .map(
                (assessment) => {
                  ...assessment.toFirestore(),
                  'bayName':
                      sldController.baysMap[assessment.bayId]?.name ??
                      'N/A', // Use controller's map
                },
              )
              .toList();

      final newSavedSld = SavedSld(
        name: sldName,
        substationId: widget.substationId,
        substationName: widget.substationName,
        startDate: Timestamp.fromDate(_startDate),
        endDate: Timestamp.fromDate(_endDate),
        createdBy: widget.currentUser.uid,
        createdAt: Timestamp.now(),
        sldParameters: currentSldParameters,
        assessmentsSummary: currentAssessmentsSummary,
      );

      await FirebaseFirestore.instance
          .collection('savedSlds')
          .add(newSavedSld.toFirestore());

      if (mounted) {
        SnackBarUtils.showSnackBar(
          context,
          'SLD "${sldName}" saved successfully!',
        );
      }
    } catch (e) {
      print('Error saving SLD: $e');
      if (mounted) {
        SnackBarUtils.showSnackBar(
          context,
          'Failed to save SLD: $e',
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

  void _showEnergySldBayActions(
    BuildContext context,
    Bay bay,
    Offset tapPosition,
    SldController sldController, // Add sldController parameter
  ) {
    if (_isViewingSavedSld) {
      SnackBarUtils.showSnackBar(
        context,
        'Cannot adjust SLD layout or energy readings in a saved historical view.',
        isError: true,
      );
      return;
    }

    final List<PopupMenuEntry<String>> menuItems = [
      const PopupMenuItem<String>(
        value: 'adjust_layout',
        child: ListTile(
          leading: Icon(Icons.open_with),
          title: Text('Adjust Bay/Text Layout'),
        ),
      ),
      const PopupMenuItem<String>(
        value: 'adjust_energy_readings',
        child: ListTile(
          leading: Icon(Icons.text_fields),
          title: Text('Adjust Readings Layout'),
        ),
      ),
      const PopupMenuItem<String>(
        value: 'add_assessment',
        child: ListTile(
          leading: Icon(Icons.assessment),
          title: Text('Add Energy Assessment'),
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
      if (value == 'adjust_layout') {
        sldController.setSelectedBayForMovement(
          bay.id,
          mode: MovementMode.bay,
        ); // Use sldController
        SnackBarUtils.showSnackBar(
          context,
          'Selected "${bay.name}" for layout adjustment. Use controls below.',
        );
      } else if (value == 'adjust_energy_readings') {
        sldController.setSelectedBayForMovement(
          bay.id,
          mode: MovementMode.energyText,
        ); // Use sldController
        SnackBarUtils.showSnackBar(
          context,
          'Selected "${bay.name}" energy readings for adjustment. Use controls below.',
        );
      } else if (value == 'add_assessment') {
        _showEnergyAssessmentDialog(bay, sldController.bayEnergyData[bay.id]);
      }
    });
  }

  Widget _buildEnergyMovementControls(SldController sldController) {
    final selectedBayId = sldController.selectedBayForMovementId;
    if (selectedBayId == null) return const SizedBox.shrink();

    final selectedBay = sldController.baysMap[selectedBayId];
    if (selectedBay == null) return const SizedBox.shrink();

    // Get current render data for the selected bay to display adjusted values
    final BayRenderData? selectedBayRenderData = sldController.bayRenderDataList
        .firstWhereOrNull((data) => data.bay.id == selectedBayId);
    if (selectedBayRenderData == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(8.0),
      color: Colors.blueGrey.shade800,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Adjusting: ${selectedBay.name}',
            style: const TextStyle(color: Colors.white, fontSize: 16),
          ),
          const SizedBox(height: 10),
          SegmentedButton<MovementMode>(
            segments: const [
              ButtonSegment(value: MovementMode.bay, label: Text('Move Bay')),
              ButtonSegment(value: MovementMode.text, label: Text('Move Name')),
              ButtonSegment(
                value: MovementMode.energyText,
                label: Text('Move Readings'),
              ),
            ],
            selected: {sldController.movementMode},
            onSelectionChanged: (newSelection) {
              sldController.setMovementMode(newSelection.first);
            },
            style: ButtonStyle(
              foregroundColor: MaterialStateProperty.resolveWith<Color>((
                Set<MaterialState> states,
              ) {
                if (states.contains(MaterialState.selected)) {
                  return Colors.blue.shade100;
                }
                return Colors.blue.shade100;
              }),
              backgroundColor: MaterialStateProperty.resolveWith<Color>((
                Set<MaterialState> states,
              ) {
                if (states.contains(MaterialState.selected)) {
                  return Theme.of(context).colorScheme.secondary;
                }
                return Colors.blue.shade700;
              }),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back),
                color: Colors.white,
                onPressed: () => sldController.moveSelectedItem(-5.0, 0),
              ),
              Column(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_upward),
                    color: Colors.white,
                    onPressed: () => sldController.moveSelectedItem(0, -5.0),
                  ),
                  IconButton(
                    icon: const Icon(Icons.arrow_downward),
                    color: Colors.white,
                    onPressed: () => sldController.moveSelectedItem(0, 5.0),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.arrow_forward),
                color: Colors.white,
                onPressed: () => sldController.moveSelectedItem(5.0, 0),
              ),
            ],
          ),
          if (sldController.movementMode == MovementMode.energyText) ...[
            const SizedBox(height: 10),
            const Text(
              'Energy Reading Font Size',
              style: TextStyle(color: Colors.white),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.remove),
                  color: Colors.white,
                  onPressed: () =>
                      sldController.adjustEnergyReadingFontSize(-0.5),
                ),
                Text(
                  selectedBayRenderData.energyReadingFontSize.toStringAsFixed(
                    1,
                  ),
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                ),
                IconButton(
                  icon: const Icon(Icons.add),
                  color: Colors.white,
                  onPressed: () =>
                      sldController.adjustEnergyReadingFontSize(0.5),
                ),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'Energy Reading Bold',
                  style: TextStyle(color: Colors.white),
                ),
                Switch(
                  value: selectedBayRenderData.energyReadingIsBold,
                  onChanged: (bool value) {
                    sldController.toggleEnergyReadingBold();
                  },
                  activeColor: Colors.white,
                  inactiveThumbColor: Colors.grey.shade400,
                  inactiveTrackColor: Colors.grey.shade700,
                ),
              ],
            ),
          ],
          const SizedBox(height: 10),
          ElevatedButton(
            onPressed: () async {
              final bool success = await sldController
                  .saveSelectedBayLayoutChanges(); // [Fix 2] Handle returned Future<bool>
              if (mounted) {
                if (success) {
                  SnackBarUtils.showSnackBar(
                    context,
                    'Energy display settings saved successfully!',
                  );
                  _loadEnergyData(); // Reload energy data to ensure it picks up from saved positions for summary tables
                } else {
                  SnackBarUtils.showSnackBar(
                    context,
                    'Failed to save energy display settings.',
                    isError: true,
                  );
                }
              }
            },
            child: const Text('Save'),
          ),
          const SizedBox(height: 10),
          ElevatedButton(
            onPressed: () {
              sldController.cancelLayoutChanges();
              SnackBarUtils.showSnackBar(
                context,
                'Movement cancelled. Position not saved.',
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade700,
            ),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Future<void> _shareCurrentSldAsPdf() async {
    try {
      SnackBarUtils.showSnackBar(context, 'Generating PDF...');
      final sldController = Provider.of<SldController>(context, listen: false);

      // Save current transformation state and reset for clean capture
      setState(() {
        _isCapturingPdf = true;
        _originalTransformation = Matrix4.copy(
          sldController.transformationController.value,
        );
        sldController.transformationController.value = Matrix4.identity();
      });
      await WidgetsBinding.instance.endOfFrame; // Wait for UI to rebuild

      // Calculate content bounds for PDF export again, now that it's flattened
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
            potentialTextTopLeft =
                renderData.rect.center + renderData.textOffset;
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

      debugPrint(
        'DEBUG PDF Capture: minX=$minXForContent, minY=$minYForContent, maxX=$maxXForContent, maxY=$maxYForContent',
      );
      debugPrint(
        'DEBUG PDF Capture: Effective Content Size: ${effectiveContentWidth.toStringAsFixed(2)}x${effectiveContentHeight.toStringAsFixed(2)}',
      );

      final Uint8List? sldImageBytes = await _widgetsToImageController
          .capturePng(pixelRatio: 10.0); // Capture with high pixel ratio

      // Restore original transformation state
      setState(() {
        _isCapturingPdf = false;
        if (_originalTransformation != null) {
          sldController.transformationController.value =
              _originalTransformation!;
        }
      });

      if (sldImageBytes == null) {
        if (mounted) {
          SnackBarUtils.showSnackBar(
            context,
            'Failed to capture SLD image for PDF.',
            isError: true,
          );
        }
        return;
      }

      debugPrint(
        'DEBUG PDF Capture: Captured Image Bytes Length: ${sldImageBytes.length}',
      );
      ui.Image image = await decodeImageFromList(sldImageBytes);
      debugPrint(
        'DEBUG PDF Capture: Captured Image Dimensions: ${image.width}x${image.height}',
      );

      final Map<String, dynamic> currentAbstractEnergyData =
          sldController.abstractEnergyData;
      final Map<String, Map<String, double>> currentBusEnergySummaryData =
          sldController.busEnergySummary;
      final List<AggregatedFeederEnergyData> currentAggregatedFeederData =
          sldController.aggregatedFeederEnergyData;

      // Extract unique distribution subdivision names for PDF table header customization
      final List<String> uniqueDistributionSubdivisionNames =
          currentAggregatedFeederData
              .map((data) => data.distributionSubdivisionName)
              .toSet()
              .toList()
            ..sort();

      final List<Map<String, dynamic>> assessmentsForPdf = _isViewingSavedSld
          ? _loadedAssessmentsSummary
          : _allAssessmentsForDisplay
                .map(
                  (e) => {
                    ...e.toFirestore(),
                    'bayName': sldController.baysMap[e.bayId]?.name ?? 'N/A',
                  },
                )
                .toList();

      final List<String> uniqueBusVoltages =
          sldController.allBays
              .where((bay) => bay.bayType == 'Busbar')
              .map((bay) => bay.voltageLevel)
              .toSet()
              .toList()
            ..sort(
              (a, b) =>
                  _getVoltageLevelValue(b).compareTo(_getVoltageLevelValue(a)),
            );

      final String dateRange = _startDate.isAtSameMomentAs(_endDate)
          ? DateFormat('dd-MMM-yyyy').format(_startDate)
          : '${DateFormat('dd-MMM-yyyy').format(_startDate)} to ${DateFormat('dd-MMM-yyyy').format(_endDate)}';

      final PdfGeneratorData pdfData = PdfGeneratorData(
        substationName: widget.substationName,
        dateRange: dateRange,
        sldImageBytes: sldImageBytes,
        abstractEnergyData: currentAbstractEnergyData,
        busEnergySummaryData: currentBusEnergySummaryData,
        aggregatedFeederData: currentAggregatedFeederData,
        assessmentsForPdf: assessmentsForPdf,
        uniqueBusVoltages: uniqueBusVoltages,
        allBaysInSubstation: sldController.allBays,
        baysMap: sldController.baysMap,
        uniqueDistributionSubdivisionNames:
            uniqueDistributionSubdivisionNames, // PASS NEW DATA
      );

      final pdfBytes = await PdfGenerator.generateEnergyReportPdf(pdfData);

      await PdfGenerator.sharePdf(
        pdfBytes,
        '${widget.substationName.replaceAll(RegExp(r'[^\w\s.-]'), '_')}_energy_report_${DateFormat('yyyyMMdd').format(_endDate)}.pdf',
        'Energy SLD Report: ${widget.substationName}',
      );

      if (mounted) {
        SnackBarUtils.showSnackBar(
          context,
          'PDF generated and shared successfully!',
        );
      }
    } catch (e) {
      print("Error generating/sharing PDF: $e");
      if (mounted) {
        SnackBarUtils.showSnackBar(
          context,
          'Failed to generate/share PDF: $e',
          isError: true,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    String dateRangeText;
    if (_startDate.isAtSameMomentAs(_endDate)) {
      dateRangeText = DateFormat('dd-MMM-yyyy').format(_startDate);
    } else {
      dateRangeText =
          '${DateFormat('dd-MMM-yyyy').format(_startDate)} to ${DateFormat('dd-MMM-yyyy').format(_endDate)}';
    }

    if (widget.substationId.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Text(
            'Please select a substation to view energy SLD.',
            textAlign: TextAlign.center,
            style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey),
          ),
        ),
      );
    }

    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final sldController = Provider.of<SldController>(
      context,
    ); // Access the controller

    // Recalculate these here to be used for the SizedBox when _isCapturingPdf is true
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

        if (sldController.bayEnergyData.containsKey(renderData.bay.id)) {
          final Offset readingOffset = renderData.energyReadingOffset;
          const double estimatedMaxEnergyTextWidth = 100;
          const double estimatedTotalEnergyTextHeight = 12 * 7;

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

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Energy Account: ${widget.substationName} ($dateRangeText)',
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today),
            onPressed: _isViewingSavedSld ? null : () => _selectDate(context),
            tooltip: _isViewingSavedSld
                ? 'Date range cannot be changed for saved SLD'
                : 'Change Date Range',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: Stack(
                    children: [
                      WidgetsToImage(
                        controller: _widgetsToImageController,
                        child: _isCapturingPdf
                            ? SizedBox(
                                width: effectiveContentWidth,
                                height: effectiveContentHeight,
                                child: CustomPaint(
                                  size: Size(
                                    effectiveContentWidth,
                                    effectiveContentHeight,
                                  ),
                                  painter: SingleLineDiagramPainter(
                                    bayRenderDataList:
                                        sldController.bayRenderDataList,
                                    bayConnections:
                                        sldController.allConnections,
                                    baysMap: sldController.baysMap,
                                    createDummyBayRenderData:
                                        sldController.createDummyBayRenderData,
                                    busbarRects: sldController.busbarRects,
                                    busbarConnectionPoints:
                                        sldController.busbarConnectionPoints,
                                    debugDrawHitboxes: false,
                                    selectedBayForMovementId: null,
                                    bayEnergyData: sldController.bayEnergyData,
                                    busEnergySummary:
                                        sldController.busEnergySummary,
                                    contentBounds: Size(
                                      effectiveContentWidth,
                                      effectiveContentHeight,
                                    ),
                                    originOffsetForPdf: originOffsetForPainter,
                                    defaultBayColor: colorScheme.onSurface,
                                    defaultLineFeederColor:
                                        colorScheme.onSurface,
                                    transformerColor: colorScheme.primary,
                                    connectionLineColor: colorScheme.onSurface,
                                  ),
                                ),
                              )
                            : SldViewWidget(
                                isEnergySld: true,
                                onBayTapped: (bay, tapPosition) {
                                  if (sldController.selectedBayForMovementId ==
                                      null) {
                                    _showEnergySldBayActions(
                                      context,
                                      bay,
                                      tapPosition,
                                      sldController,
                                    );
                                  }
                                },
                              ),
                      ),
                    ],
                  ),
                ),
                Visibility(
                  visible: _showTables,
                  child: Column(
                    children: [
                      Container(
                        height: 250, // Consolidated table height
                        padding: const EdgeInsets.all(8.0),
                        child: Column(
                          children: [
                            Text(
                              'Consolidated Energy Abstract',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const Divider(),
                            Expanded(
                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: DataTable(
                                  columns: _buildAbstractTableHeaders(
                                    sldController,
                                  ),
                                  rows: _buildConsolidatedEnergyTableRows(
                                    sldController,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (_isViewingSavedSld &&
                          _loadedAssessmentsSummary.isNotEmpty)
                        Container(
                          height: 250,
                          padding: const EdgeInsets.all(8.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Assessments for this Period:',
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              const Divider(),
                              Expanded(
                                child: SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: DataTable(
                                    columns: const [
                                      DataColumn(label: Text('Bay Name')),
                                      DataColumn(label: Text('Import Adj.')),
                                      DataColumn(label: Text('Export Adj.')),
                                      DataColumn(label: Text('Reason')),
                                      DataColumn(label: Text('Timestamp')),
                                    ],
                                    rows: _loadedAssessmentsSummary.map((
                                      assessmentMap,
                                    ) {
                                      final Assessment assessment =
                                          Assessment.fromMap(assessmentMap);
                                      final String assessedBayName =
                                          assessmentMap['bayName'] ?? 'N/A';
                                      return DataRow(
                                        cells: [
                                          DataCell(Text(assessedBayName)),
                                          DataCell(
                                            Text(
                                              assessment.importAdjustment !=
                                                      null
                                                  ? assessment.importAdjustment!
                                                        .toStringAsFixed(2)
                                                  : 'N/A',
                                            ),
                                          ),
                                          DataCell(
                                            Text(
                                              assessment.exportAdjustment !=
                                                      null
                                                  ? assessment.exportAdjustment!
                                                        .toStringAsFixed(2)
                                                  : 'N/A',
                                            ),
                                          ),
                                          DataCell(Text(assessment.reason)),
                                          DataCell(
                                            Text(
                                              DateFormat(
                                                'dd-MMM-yyyy HH:mm',
                                              ).format(
                                                assessment.assessmentTimestamp
                                                    .toDate(),
                                              ),
                                            ),
                                          ),
                                        ],
                                      );
                                    }).toList(),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                      else if (_isViewingSavedSld &&
                          _loadedAssessmentsSummary.isEmpty)
                        Container(
                          height: 250,
                          alignment: Alignment.center,
                          child: Text(
                            'No assessments were made for this period in the saved SLD.',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(fontStyle: FontStyle.italic),
                            textAlign: TextAlign.center,
                          ),
                        )
                      else if (!_isViewingSavedSld &&
                          _allAssessmentsForDisplay.isNotEmpty)
                        Container(
                          height: 150,
                          padding: const EdgeInsets.all(8.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Recent Assessment Notes:',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const Divider(),
                              Expanded(
                                child: ListView.builder(
                                  itemCount: _allAssessmentsForDisplay.length,
                                  itemBuilder: (context, index) {
                                    final assessment =
                                        _allAssessmentsForDisplay[index];
                                    final Bay? assessedBay =
                                        sldController.baysMap[assessment
                                            .bayId]; // Use controller's map
                                    return Padding(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 4.0,
                                      ),
                                      child: Text(
                                        '• ${assessedBay?.name ?? 'Unknown Bay'} on ${DateFormat('dd-MMM-yyyy HH:mm').format(assessment.assessmentTimestamp.toDate())}: ${assessment.reason}',
                                        style: Theme.of(
                                          context,
                                        ).textTheme.bodySmall,
                                      ),
                                    );
                                  },
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
      floatingActionButton: SpeedDial(
        icon: Icons.menu,
        activeIcon: Icons.close,
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        overlayColor: Colors.black,
        overlayOpacity: 0.5,
        spacing: 12,
        spaceBetweenChildren: 12,
        children: [
          SpeedDialChild(
            child: const Icon(Icons.save),
            backgroundColor: _isViewingSavedSld ? Colors.grey : Colors.green,
            label: 'Save SLD',
            onTap: _isViewingSavedSld ? null : _saveSld,
          ),
          SpeedDialChild(
            child: const Icon(Icons.print),
            backgroundColor: Colors.blue,
            label: 'Print/Share SLD',
            onTap: _shareCurrentSldAsPdf,
          ),
          SpeedDialChild(
            child: Icon(_showTables ? Icons.visibility_off : Icons.visibility),
            backgroundColor: Colors.orange,
            label: _showTables ? 'Hide Tables' : 'Show Tables',
            onTap: () {
              setState(() {
                _showTables = !_showTables;
              });
            },
          ),
          SpeedDialChild(
            child: const Icon(Icons.settings_input_antenna),
            backgroundColor: Colors.purple,
            label: 'Configure Busbar Energy',
            onTap: _isViewingSavedSld
                ? null
                : () => _showBusbarSelectionDialog(),
          ),
          SpeedDialChild(
            child: const Icon(Icons.assessment),
            backgroundColor: Colors.red,
            label: 'Add Energy Assessment',
            onTap: _isViewingSavedSld
                ? null
                : () => _showBaySelectionForAssessment(),
          ),
        ],
      ),
      bottomNavigationBar: sldController.selectedBayForMovementId != null
          ? _buildEnergyMovementControls(sldController)
          : null,
    );
  }

  // New helper methods for building data tables, using sldController data
  List<DataColumn> _buildAbstractTableHeaders(SldController sldController) {
    List<String> abstractTableHeaders = [''];
    final List<String> uniqueBusVoltages =
        sldController.allBays
            .where((bay) => bay.bayType == 'Busbar')
            .map((bay) => bay.voltageLevel)
            .toSet()
            .toList()
          ..sort(
            (a, b) =>
                _getVoltageLevelValue(b).compareTo(_getVoltageLevelValue(a)),
          );

    for (String voltage in uniqueBusVoltages) {
      abstractTableHeaders.add('$voltage BUS');
    }
    abstractTableHeaders.add('ABSTRACT OF S/S');
    abstractTableHeaders.add('TOTAL');

    return abstractTableHeaders
        .map(
          (header) => DataColumn(
            label: Text(
              header,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        )
        .toList();
  }

  List<DataRow> _buildConsolidatedEnergyTableRows(SldController sldController) {
    List<DataRow> consolidatedEnergyTableRows = [];
    final List<String> rowLabels = [
      'Import (MWH)',
      'Export (MWH)',
      'Difference (MWH)',
      'Loss (%)',
    ];

    final List<String> uniqueBusVoltages =
        sldController.allBays
            .where((bay) => bay.bayType == 'Busbar')
            .map((bay) => bay.voltageLevel)
            .toSet()
            .toList()
          ..sort(
            (a, b) =>
                _getVoltageLevelValue(b).compareTo(_getVoltageLevelValue(a)),
          );

    for (int i = 0; i < rowLabels.length; i++) {
      List<DataCell> rowCells = [DataCell(Text(rowLabels[i]))];
      double rowTotalSummable = 0.0;
      double rowTotalImportForLossCalc = 0.0;
      double rowTotalDifferenceForLossCalc = 0.0;

      for (String voltage in uniqueBusVoltages) {
        final busbarsOfThisVoltage = sldController.allBays.where(
          (bay) => bay.bayType == 'Busbar' && bay.voltageLevel == voltage,
        );
        double totalForThisBusVoltageImp = 0.0;
        double totalForThisBusVoltageExp = 0.0;
        double totalForThisBusVoltageDiff = 0.0;

        for (var busbar in busbarsOfThisVoltage) {
          final busSummary = sldController.busEnergySummary[busbar.id];
          if (busSummary != null) {
            totalForThisBusVoltageImp += busSummary['totalImp'] ?? 0.0;
            totalForThisBusVoltageExp += busSummary['totalExp'] ?? 0.0;
            totalForThisBusVoltageDiff += busSummary['difference'] ?? 0.0;
          }
        }

        if (rowLabels[i].contains('Import')) {
          rowCells.add(
            DataCell(Text(totalForThisBusVoltageImp.toStringAsFixed(2))),
          );
          rowTotalSummable += totalForThisBusVoltageImp;
          rowTotalImportForLossCalc += totalForThisBusVoltageImp;
        } else if (rowLabels[i].contains('Export')) {
          rowCells.add(
            DataCell(Text(totalForThisBusVoltageExp.toStringAsFixed(2))),
          );
          rowTotalSummable += totalForThisBusVoltageExp;
        } else if (rowLabels[i].contains('Difference')) {
          rowCells.add(
            DataCell(Text(totalForThisBusVoltageDiff.toStringAsFixed(2))),
          );
          rowTotalSummable += totalForThisBusVoltageDiff;
          rowTotalDifferenceForLossCalc += totalForThisBusVoltageDiff;
        } else if (rowLabels[i].contains('Loss')) {
          String lossValue = 'N/A';
          if (totalForThisBusVoltageImp > 0) {
            lossValue =
                ((totalForThisBusVoltageDiff / totalForThisBusVoltageImp) * 100)
                    .toStringAsFixed(2);
          }
          rowCells.add(DataCell(Text(lossValue)));
        }
      }

      // Add Abstract of S/S data
      if (rowLabels[i].contains('Import')) {
        rowCells.add(
          DataCell(
            Text(
              (sldController.abstractEnergyData['totalImp'] ?? 0.0)
                  .toStringAsFixed(2),
            ),
          ),
        );
        rowTotalSummable +=
            (sldController.abstractEnergyData['totalImp'] ?? 0.0);
        rowTotalImportForLossCalc +=
            (sldController.abstractEnergyData['totalImp'] ?? 0.0);
      } else if (rowLabels[i].contains('Export')) {
        rowCells.add(
          DataCell(
            Text(
              (sldController.abstractEnergyData['totalExp'] ?? 0.0)
                  .toStringAsFixed(2),
            ),
          ),
        );
        rowTotalSummable +=
            (sldController.abstractEnergyData['totalExp'] ?? 0.0);
      } else if (rowLabels[i].contains('Difference')) {
        rowCells.add(
          DataCell(
            Text(
              (sldController.abstractEnergyData['difference'] ?? 0.0)
                  .toStringAsFixed(2),
            ),
          ),
        );
        rowTotalSummable +=
            (sldController.abstractEnergyData['difference'] ?? 0.0);
        rowTotalDifferenceForLossCalc +=
            (sldController.abstractEnergyData['difference'] ?? 0.0);
      } else if (rowLabels[i].contains('Loss')) {
        rowCells.add(
          DataCell(
            Text(
              (sldController.abstractEnergyData['lossPercentage'] ?? 0.0)
                  .toStringAsFixed(2),
            ),
          ),
        );
      }

      // Add TOTAL column
      if (rowLabels[i].contains('Loss')) {
        String overallTotalLossPercentage = 'N/A';
        if (rowTotalImportForLossCalc > 0) {
          overallTotalLossPercentage =
              ((rowTotalDifferenceForLossCalc / rowTotalImportForLossCalc) *
                      100)
                  .toStringAsFixed(2);
        }
        rowCells.add(DataCell(Text(overallTotalLossPercentage)));
      } else {
        rowCells.add(DataCell(Text(rowTotalSummable.toStringAsFixed(2))));
      }

      consolidatedEnergyTableRows.add(DataRow(cells: rowCells));
    }
    return consolidatedEnergyTableRows;
  }
}

// _BusbarEnergyAssignmentDialog remains the same
class _BusbarEnergyAssignmentDialog extends StatefulWidget {
  final Bay busbar;
  final List<Bay> connectedBays;
  final AppUser currentUser;
  final Map<String, BusbarEnergyMap> currentMaps;
  final Function(BusbarEnergyMap) onSaveMap;
  final Function(String) onDeleteMap;

  const _BusbarEnergyAssignmentDialog({
    required this.busbar,
    required this.connectedBays,
    required this.currentUser,
    required this.currentMaps,
    required this.onSaveMap,
    required this.onDeleteMap,
  });

  @override
  __BusbarEnergyAssignmentDialogState createState() =>
      __BusbarEnergyAssignmentDialogState();
}

class __BusbarEnergyAssignmentDialogState
    extends State<_BusbarEnergyAssignmentDialog> {
  final Map<String, Map<String, dynamic>> _bayContributionSelections = {};
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    for (var bay in widget.connectedBays) {
      final existingMap = widget.currentMaps[bay.id];
      _bayContributionSelections[bay.id] = {
        'import':
            existingMap?.importContribution ?? EnergyContributionType.none,
        'export':
            existingMap?.exportContribution ?? EnergyContributionType.none,
        'originalMapId': existingMap?.id,
      };
    }
  }

  Future<void> _saveAllContributions() async {
    setState(() => _isSaving = true);
    try {
      for (var bayId in _bayContributionSelections.keys) {
        final selection = _bayContributionSelections[bayId]!;
        final originalMapId = selection['originalMapId'] as String?;
        final importContrib = selection['import'] as EnergyContributionType;
        final exportContrib = selection['export'] as EnergyContributionType;

        if (importContrib == EnergyContributionType.none &&
            exportContrib == EnergyContributionType.none) {
          if (originalMapId != null) {
            widget.onDeleteMap(originalMapId);
          }
        } else {
          final newMap = BusbarEnergyMap(
            id: originalMapId,
            substationId: widget.busbar.substationId,
            busbarId: widget.busbar.id,
            connectedBayId: bayId,
            importContribution: importContrib,
            exportContribution: exportContrib,
            createdBy: originalMapId != null
                ? widget.currentUser.uid
                : widget.currentUser.uid,
            createdAt: originalMapId != null
                ? Timestamp.now()
                : Timestamp.now(),
            lastModifiedAt: Timestamp.now(),
          );
          widget.onSaveMap(newMap);
        }
      }
      if (mounted) {
        SnackBarUtils.showSnackBar(context, 'Busbar energy assignments saved!');
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        SnackBarUtils.showSnackBar(
          context,
          'Failed to save assignments: $e',
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        'Assign Energy Flow for ${widget.busbar.voltageLevel} ${widget.busbar.name}',
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Configure how energy from connected bays contributes to this busbar\'s import/export.',
            ),
            const SizedBox(height: 16),
            if (widget.connectedBays.isEmpty)
              const Text('No bays connected to this busbar.'),
            ...widget.connectedBays.map((bay) {
              final currentSelection = _bayContributionSelections[bay.id]!;
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 8),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${bay.name} (${bay.bayType})',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<EnergyContributionType>(
                        decoration: const InputDecoration(
                          labelText: 'Bay Import contributes to Busbar:',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        value: currentSelection['import'],
                        items: EnergyContributionType.values.map((type) {
                          return DropdownMenuItem(
                            value: type,
                            child: Text(
                              type
                                  .toString()
                                  .split('.')
                                  .last
                                  .replaceAll('bus', 'Bus '),
                            ),
                          );
                        }).toList(),
                        onChanged: (newValue) {
                          setState(() {
                            currentSelection['import'] = newValue;
                          });
                        },
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<EnergyContributionType>(
                        decoration: const InputDecoration(
                          labelText: 'Bay Export contributes to Busbar:',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        value: currentSelection['export'],
                        items: EnergyContributionType.values.map((type) {
                          return DropdownMenuItem(
                            value: type,
                            child: Text(
                              type
                                  .toString()
                                  .split('.')
                                  .last
                                  .replaceAll('bus', 'Bus '),
                            ),
                          );
                        }).toList(),
                        onChanged: (newValue) {
                          setState(() {
                            currentSelection['export'] = newValue;
                          });
                        },
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isSaving ? null : _saveAllContributions,
          child: _isSaving
              ? const CircularProgressIndicator(strokeWidth: 2)
              : const Text('Save Assignments'),
        ),
      ],
    );
  }
}

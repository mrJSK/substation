// // lib/screens/energy_sld_screen.dart

// import 'package:flutter/material.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:intl/intl.dart';
// import 'dart:math';
// import 'package:collection/collection.dart';
// import 'package:flutter_speed_dial/flutter_speed_dial.dart';

// // PDF & Capture related imports
// import 'package:pdf/pdf.dart';
// import 'package:pdf/widgets.dart' as pw;
// import 'package:printing/printing.dart';
// import 'package:path_provider/path_provider.dart';
// import 'package:share_plus/share_plus.dart';
// import 'dart:io';
// import 'dart:typed_data';
// import 'package:widgets_to_image/widgets_to_image.dart';

// import '../models/bay_model.dart';
// import '../models/equipment_model.dart';
// import '../models/user_model.dart';
// import '../models/reading_models.dart';
// import '../models/logsheet_models.dart';
// import '../models/bay_connection_model.dart';
// import '../models/busbar_energy_map.dart';
// import '../models/hierarchy_models.dart';
// import '../models/assessment_model.dart';
// import '../models/saved_sld_model.dart';
// import '../utils/snackbar_utils.dart';

// import '../painters/single_line_diagram_painter.dart';
// import '../widgets/energy_assessment_dialog.dart';

// /// Data model for energy data associated with a bay
// class BayEnergyData {
//   final String bayName;
//   final double? prevImp;
//   final double? currImp;
//   final double? prevExp;
//   final double? currExp;
//   final double? mf;
//   final double? impConsumed;
//   final double? expConsumed;
//   final bool hasAssessment;

//   BayEnergyData({
//     required this.bayName,
//     this.prevImp,
//     this.currImp,
//     this.currExp,
//     this.mf,
//     this.impConsumed,
//     this.expConsumed,
//     this.hasAssessment = false,
//     this.prevExp,
//   });

//   BayEnergyData applyAssessment({
//     double? importAdjustment,
//     double? exportAdjustment,
//   }) {
//     double newImpConsumed = (impConsumed ?? 0.0) + (importAdjustment ?? 0.0);
//     double newExpConsumed = (expConsumed ?? 0.0) + (exportAdjustment ?? 0.0);
//     return BayEnergyData(
//       bayName: bayName,
//       prevImp: prevImp,
//       currImp: currImp,
//       prevExp: prevExp,
//       currExp: currExp,
//       mf: mf,
//       impConsumed: newImpConsumed,
//       expConsumed: newExpConsumed,
//       hasAssessment: true,
//     );
//   }

//   /// Convert to Map for serialization
//   Map<String, dynamic> toMap() {
//     return {
//       'bayName': bayName,
//       'prevImp': prevImp,
//       'currImp': currImp,
//       'prevExp': prevExp,
//       'currExp': currExp,
//       'mf': mf,
//       'impConsumed': impConsumed,
//       'expConsumed': expConsumed,
//       'hasAssessment': hasAssessment,
//     };
//   }

//   /// Create from Map for deserialization
//   factory BayEnergyData.fromMap(Map<String, dynamic> map) {
//     return BayEnergyData(
//       bayName: map['bayName'],
//       prevImp: (map['prevImp'] as num?)?.toDouble(),
//       currImp: (map['currImp'] as num?)?.toDouble(),
//       prevExp: (map['prevExp'] as num?)?.toDouble(),
//       currExp: (map['currExp'] as num?)?.toDouble(),
//       mf: (map['mf'] as num?)?.toDouble(),
//       impConsumed: (map['impConsumed'] as num?)?.toDouble(),
//       expConsumed: (map['expConsumed'] as num?)?.toDouble(),
//       hasAssessment: map['hasAssessment'] ?? false,
//     );
//   }
// }

// /// Data model for Aggregated Feeder Energy Table
// class AggregatedFeederEnergyData {
//   final String zoneName;
//   final String circleName;
//   final String divisionName;
//   final String distributionSubdivisionName;
//   double importedEnergy;
//   double exportedEnergy;

//   AggregatedFeederEnergyData({
//     required this.zoneName,
//     required this.circleName,
//     required this.divisionName,
//     required this.distributionSubdivisionName,
//     this.importedEnergy = 0.0,
//     this.exportedEnergy = 0.0,
//   });

//   String get uniqueKey =>
//       '$zoneName-$circleName-$divisionName-$distributionSubdivisionName';

//   Map<String, dynamic> toMap() {
//     return {
//       'zoneName': zoneName,
//       'circleName': circleName,
//       'divisionName': divisionName,
//       'distributionSubdivisionName': distributionSubdivisionName,
//       'importedEnergy': importedEnergy,
//       'exportedEnergy': exportedEnergy,
//     };
//   }

//   factory AggregatedFeederEnergyData.fromMap(Map<String, dynamic> map) {
//     return AggregatedFeederEnergyData(
//       zoneName: map['zoneName'],
//       circleName: map['circleName'],
//       divisionName: map['divisionName'],
//       distributionSubdivisionName: map['distributionSubdivisionName'],
//       importedEnergy: (map['importedEnergy'] as num?)?.toDouble() ?? 0.0,
//       exportedEnergy: (map['exportedEnergy'] as num?)?.toDouble() ?? 0.0,
//     );
//   }
// }

// /// Data model for rendering the SLD with energy data
// class SldRenderData {
//   final List<BayRenderData> bayRenderDataList;
//   final Map<String, Rect>
//   finalBayRects; // Not serializable, handled dynamically
//   final Map<String, Rect> busbarRects; // Not serializable, handled dynamically
//   final Map<String, Map<String, Offset>>
//   busbarConnectionPoints; // Not serializable, handled dynamically
//   final Map<String, BayEnergyData> bayEnergyData;
//   final Map<String, Map<String, double>> busEnergySummary;
//   final Map<String, dynamic>
//   abstractEnergyData; // NEW: Added abstract energy data
//   final List<AggregatedFeederEnergyData>
//   aggregatedFeederEnergyData; // NEW: Aggregated feeder data

//   SldRenderData({
//     required this.bayRenderDataList,
//     required this.finalBayRects,
//     required this.busbarRects,
//     required this.busbarConnectionPoints,
//     required this.bayEnergyData,
//     required this.busEnergySummary,
//     required this.abstractEnergyData, // NEW: Required in constructor
//     required this.aggregatedFeederEnergyData, // NEW: Required in constructor
//   });

//   /// Convert to Map for serialization (excluding Rects and Offsets)
//   Map<String, dynamic> toMap() {
//     return {
//       // bayRenderDataList contains Bay objects which are serializable through toFirestore()
//       // For sldParameters, we only need the bay IDs and their coordinates
//       'bayPositions': {
//         for (var renderData in bayRenderDataList)
//           renderData.bay.id: {
//             'x': renderData.bay.xPosition,
//             'y': renderData.bay.yPosition,
//             'textOffsetDx':
//                 renderData.bay.textOffset?.dx, // Include textOffset.dx
//             'textOffsetDy':
//                 renderData.bay.textOffset?.dy, // Include textOffset.dy
//             'busbarLength': renderData.bay.busbarLength, // Include busbarLength
//           },
//       },
//       'bayEnergyData': {
//         for (var entry in bayEnergyData.entries) entry.key: entry.value.toMap(),
//       },
//       'busEnergySummary': busEnergySummary,
//       'abstractEnergyData':
//           abstractEnergyData, // NEW: Include abstract energy data
//       'aggregatedFeederEnergyData': aggregatedFeederEnergyData
//           .map((e) => e.toMap())
//           .toList(), // NEW: Include aggregated feeder data
//     };
//   }

//   /// Create from Map for deserialization (re-generating Rects and Offsets will happen dynamically)
//   factory SldRenderData.fromMap(
//     Map<String, dynamic> map,
//     Map<String, Bay> baysMap,
//   ) {
//     Map<String, Map<String, double>> deserializedBayEnergyData =
//         (map['bayEnergyData'] as Map<String, dynamic>?)?.map(
//           (key, value) => MapEntry(key, Map<String, double>.from(value)),
//         ) ??
//         {};

//     Map<String, Map<String, double>> deserializedBusEnergySummary =
//         (map['busEnergySummary'] as Map<String, dynamic>?)?.map(
//           (key, value) => MapEntry(key, Map<String, double>.from(value)),
//         ) ??
//         {};

//     Map<String, dynamic> deserializedAbstractEnergyData =
//         Map<String, dynamic>.from(map['abstractEnergyData'] ?? {});

//     List<AggregatedFeederEnergyData> deserializedAggregatedFeederEnergyData =
//         (map['aggregatedFeederEnergyData'] as List<dynamic>?)
//             ?.map(
//               (e) => AggregatedFeederEnergyData.fromMap(
//                 e as Map<String, dynamic>? ?? {},
//               ),
//             ) // ADDED: null check for e
//             .toList() ??
//         [];

//     // Reconstruct bayRenderDataList with positions
//     List<BayRenderData> deserializedBayRenderDataList = [];
//     if (map['bayPositions'] != null) {
//       (map['bayPositions'] as Map<String, dynamic>).forEach((
//         bayId,
//         positionData,
//       ) {
//         final Bay? originalBay = baysMap[bayId];
//         if (originalBay != null) {
//           final double? x = (positionData['x'] as num?)?.toDouble();
//           final double? y = (positionData['y'] as num?)?.toDouble();
//           final double? textOffsetDx = (positionData['textOffsetDx'] as num?)
//               ?.toDouble();
//           final double? textOffsetDy = (positionData['textOffsetDy'] as num?)
//               ?.toDouble();
//           final double? busbarLength = (positionData['busbarLength'] as num?)
//               ?.toDouble();

//           // Create a new Bay object with the saved position
//           final Bay bayWithPosition = originalBay.copyWith(
//             xPosition: x,
//             yPosition: y,
//             textOffset: (textOffsetDx != null && textOffsetDy != null)
//                 ? Offset(textOffsetDx, textOffsetDy)
//                 : null,
//             busbarLength: busbarLength,
//           );

//           // Dummy rects for now, they will be recalculated by _buildBayRenderDataList
//           deserializedBayRenderDataList.add(
//             BayRenderData(
//               bay: bayWithPosition,
//               rect: Rect.zero,
//               center: Offset(x ?? 0, y ?? 0),
//               topCenter: Offset(x ?? 0, y ?? 0),
//               bottomCenter: Offset(x ?? 0, y ?? 0),
//               leftCenter: Offset(x ?? 0, y ?? 0),
//               rightCenter: Offset(x ?? 0, y ?? 0),
//               textOffset: (textOffsetDx != null && textOffsetDy != null)
//                   ? Offset(textOffsetDx, textOffsetDy)
//                   : Offset.zero,
//               busbarLength: busbarLength ?? 0.0,
//             ),
//           );
//         }
//       });
//     }

//     return SldRenderData(
//       bayRenderDataList: deserializedBayRenderDataList,
//       finalBayRects: {}, // Will be dynamically generated
//       busbarRects: {}, // Will be dynamically generated
//       busbarConnectionPoints: {}, // Will be dynamically generated
//       bayEnergyData: {},
//       busEnergySummary: deserializedBusEnergySummary,
//       abstractEnergyData: deserializedAbstractEnergyData, // NEW
//       aggregatedFeederEnergyData: deserializedAggregatedFeederEnergyData, // NEW
//     );
//   }
// }

// /// GlobalKey for ScaffoldMessengerState to show SnackBars from anywhere
// final GlobalKey<ScaffoldMessengerState> energySldScaffoldMessengerKey =
//     GlobalKey<ScaffoldMessengerState>();

// class EnergySldScreen extends StatefulWidget {
//   final String substationId;
//   final String substationName;
//   final AppUser currentUser;
//   final SavedSld? savedSld; // NEW: Optional parameter for saved SLD

//   const EnergySldScreen({
//     super.key,
//     required this.substationId,
//     required this.substationName,
//     required this.currentUser,
//     this.savedSld, // NEW: Add to constructor
//   });

//   @override
//   State<EnergySldScreen> createState() => _EnergySldScreenState();
// }

// enum MovementMode { bay, text } // Reintroduce MovementMode enum

// class _EnergySldScreenState extends State<EnergySldScreen> {
//   bool _isLoading = true;
//   DateTime _startDate = DateTime.now().subtract(const Duration(days: 1));
//   DateTime _endDate = DateTime.now();
//   bool _showTables = true; // NEW: State for table visibility

//   List<Bay> _allBaysInSubstation = [];
//   Map<String, Bay> _baysMap = {};
//   List<BayConnection> _allConnections = [];
//   List<BayRenderData> _currentBayRenderDataList = [];

//   Map<String, BayEnergyData> _bayEnergyData = {};
//   Map<String, double> _abstractEnergyData = {};
//   Map<String, Map<String, double>> _busEnergySummary = {};
//   Map<String, BusbarEnergyMap> _busbarEnergyMaps = {};
//   Map<String, Assessment> _latestAssessmentsPerBay =
//       {}; // Stores only the latest assessment per bay
//   Map<String, List<EquipmentInstance>> _equipmentByBayId = {};

//   // Hierarchy maps for lookup (Transmission Hierarchy)
//   Map<String, Zone> _zonesMap = {};
//   Map<String, Circle> _circlesMap = {};
//   Map<String, Division> _divisionsMap = {};
//   Map<String, Subdivision> _subdivisionsMap = {};
//   Map<String, Substation> _substationsMap = {};

//   // Maps for Distribution Hierarchy lookup
//   Map<String, DistributionZone> _distributionZonesMap = {};
//   Map<String, DistributionCircle> _distributionCirclesMap = {};
//   Map<String, DistributionDivision> _distributionDivisionsMap = {};
//   Map<String, DistributionSubdivision> _distributionSubdivisionsMap = {};

//   List<AggregatedFeederEnergyData> _aggregatedFeederEnergyData = [];
//   List<Assessment> _allAssessmentsForDisplay =
//       []; // For displaying all assessment notes

//   final TransformationController _transformationController =
//       TransformationController();

//   int _currentPageIndex = 0;
//   int _feederTablePageIndex = 0;

//   // NEW: Flag to indicate if we are viewing a saved SLD
//   bool _isViewingSavedSld = false;
//   // NEW: Data loaded from a saved SLD
//   Map<String, dynamic>? _loadedSldParameters;
//   List<Map<String, dynamic>> _loadedAssessmentsSummary = [];

//   // WidgetsToImageController for capturing the SLD widget
//   final WidgetsToImageController _widgetsToImageController =
//       WidgetsToImageController(); // NEW: Controller for WidgetsToImage

//   // NEW: State to control rendering size for PDF capture
//   bool _isCapturingPdf = false;
//   Matrix4? _originalTransformation; // To store and restore transformation

//   // --- Start of additions for text movement ---
//   String? _selectedBayForMovementId;
//   MovementMode _movementMode = MovementMode.bay; // Default to bay movement
//   Map<String, Offset> _bayPositions = {}; // To store temporary bay positions
//   Map<String, Offset> _textOffsets = {}; // To store temporary text offsets
//   Map<String, double> _busbarLengths = {}; // To store temporary busbar lengths

//   static const double _movementStep = 10.0;
//   static const double _busbarLengthStep = 20.0;

//   // --- End of additions for text movement ---

//   @override
//   void initState() {
//     super.initState();
//     print(
//       'DEBUG: EnergySldScreen initState - substationId: ${widget.substationId}',
//     );

//     _isViewingSavedSld = widget.savedSld != null;
//     if (_isViewingSavedSld) {
//       _startDate = widget.savedSld!.startDate.toDate();
//       _endDate = widget.savedSld!.endDate.toDate();
//       _loadedSldParameters = widget.savedSld!.sldParameters;
//       _loadedAssessmentsSummary = widget.savedSld!.assessmentsSummary;
//       _loadEnergyData(fromSaved: true); // Load from saved SLD
//     } else {
//       if (widget.substationId.isNotEmpty) {
//         _loadEnergyData(); // Load live data
//       } else {
//         _isLoading = false;
//       }
//     }
//   }

//   @override
//   void dispose() {
//     _transformationController.dispose();
//     super.dispose();
//   }

//   double _getVoltageLevelValue(String voltageLevel) {
//     final regex = RegExp(r'(\d+(\.\d+)?)');
//     final match = regex.firstMatch(voltageLevel);
//     if (match != null) {
//       return double.tryParse(match.group(1)!) ?? 0.0;
//     }
//     return 0.0;
//   }

//   Future<void> _loadEnergyData({bool fromSaved = false}) async {
//     if (!mounted) return;
//     setState(() {
//       _isLoading = true;
//       _bayEnergyData.clear();
//       _abstractEnergyData.clear();
//       _busEnergySummary.clear();
//       _allBaysInSubstation.clear();
//       _baysMap.clear();
//       _allConnections.clear();
//       _busbarEnergyMaps.clear();
//       _latestAssessmentsPerBay.clear(); // Clear latest assessments map
//       _allAssessmentsForDisplay.clear(); // Clear all assessments for notes
//       _aggregatedFeederEnergyData.clear();
//       _currentPageIndex = 0;
//       _feederTablePageIndex = 0;

//       // Clear movement state
//       _selectedBayForMovementId = null;
//       _bayPositions.clear();
//       _textOffsets.clear();
//       _busbarLengths.clear();
//     });

//     try {
//       await _fetchTransmissionHierarchyData();
//       await _fetchDistributionHierarchyData();

//       final baysSnapshot = await FirebaseFirestore.instance
//           .collection('bays')
//           .where('substationId', isEqualTo: widget.substationId)
//           .orderBy('name')
//           .get();
//       _allBaysInSubstation = baysSnapshot.docs
//           .map((doc) => Bay.fromFirestore(doc))
//           .toList();

//       _allBaysInSubstation.sort((a, b) {
//         final double voltageA = _getVoltageLevelValue(a.voltageLevel);
//         final double voltageB = _getVoltageLevelValue(b.voltageLevel);
//         return voltageB.compareTo(voltageA);
//       });

//       _baysMap = {for (var bay in _allBaysInSubstation) bay.id: bay};

//       final connectionsSnapshot = await FirebaseFirestore.instance
//           .collection('bay_connections')
//           .where('substationId', isEqualTo: widget.substationId)
//           .get();
//       _allConnections = connectionsSnapshot.docs
//           .map((doc) => BayConnection.fromFirestore(doc))
//           .toList();

//       if (fromSaved && _loadedSldParameters != null) {
//         // NEW: Load data from saved SLD parameters
//         debugPrint('Loading energy data from SAVED SLD.');
//         _bayEnergyData =
//             (_loadedSldParameters!['bayEnergyData'] as Map<String, dynamic>?)
//                 ?.map<String, BayEnergyData>(
//                   (key, value) => MapEntry(
//                     key,
//                     BayEnergyData.fromMap(value as Map<String, dynamic>),
//                   ),
//                 ) ??
//             {};
//         _busEnergySummary = Map<String, Map<String, double>>.from(
//           (_loadedSldParameters!['busEnergySummary']
//                       as Map<String, dynamic>?) // Removed '!'
//                   ?.map(
//                     (key, value) => MapEntry(
//                       key,
//                       Map<String, double>.from(
//                         value as Map<String, dynamic>? ?? {},
//                       ), // Added null check for 'value' here
//                     ),
//                   ) ??
//               {},
//         );
//         _abstractEnergyData = Map<String, double>.from(
//           _loadedSldParameters!['abstractEnergyData'] // Removed '!'
//                   as Map<String, dynamic>? ??
//               {},
//         );
//         _aggregatedFeederEnergyData =
//             (_loadedSldParameters!['aggregatedFeederEnergyData'] // Removed '!'
//                     as List<dynamic>?)
//                 ?.map(
//                   (e) => AggregatedFeederEnergyData.fromMap(
//                     e as Map<String, dynamic>? ?? {},
//                   ),
//                 ) // Added null check for 'e' here
//                 .toList() ??
//             [];
//         _allAssessmentsForDisplay = _loadedAssessmentsSummary
//             .map((e) => Assessment.fromMap(e))
//             .toList(); // Deserialize summary for display
//       } else {
//         // Continue with live data fetching and calculation
//         debugPrint('Loading LIVE energy data.');
//         final busbarEnergyMapsSnapshot = await FirebaseFirestore.instance
//             .collection('busbarEnergyMaps')
//             .where('substationId', isEqualTo: widget.substationId)
//             .get();
//         _busbarEnergyMaps = {
//           for (var doc in busbarEnergyMapsSnapshot.docs)
//             '${doc['busbarId']}-${doc['connectedBayId']}':
//                 BusbarEnergyMap.fromFirestore(doc),
//         };

//         final startOfStartDate = DateTime(
//           _startDate.year,
//           _startDate.month,
//           _startDate.day,
//         );
//         final endOfStartDate = DateTime(
//           _startDate.year,
//           _startDate.month,
//           _startDate.day,
//           23,
//           59,
//           59,
//           999,
//         );

//         final startOfEndDate = DateTime(
//           _endDate.year,
//           _endDate.month,
//           _endDate.day,
//         );
//         final endOfEndDate = DateTime(
//           _endDate.year,
//           _endDate.month,
//           _endDate.day,
//           23,
//           59,
//           59,
//           999,
//         );

//         Map<String, LogsheetEntry> startDayReadings = {};
//         Map<String, LogsheetEntry> endDayReadings = {};
//         Map<String, LogsheetEntry> previousDayToStartDateReadings = {};

//         final startDayLogsheetsSnapshot = await FirebaseFirestore.instance
//             .collection('logsheetEntries')
//             .where('substationId', isEqualTo: widget.substationId)
//             .where('frequency', isEqualTo: 'daily')
//             .where('readingTimestamp', isGreaterThanOrEqualTo: startOfStartDate)
//             .where(
//               'readingTimestamp',
//               isLessThanOrEqualTo: endOfEndDate,
//             ) // Changed to endOfEndDate to cover the range
//             .get();
//         startDayReadings = {
//           for (var doc in startDayLogsheetsSnapshot.docs)
//             (doc.data() as Map<String, dynamic>)['bayId']:
//                 LogsheetEntry.fromFirestore(doc),
//         };

//         // If start and end dates are different, fetch end day readings specifically
//         if (!_startDate.isAtSameMomentAs(_endDate)) {
//           final endDayLogsheetsSnapshot = await FirebaseFirestore.instance
//               .collection('logsheetEntries')
//               .where('substationId', isEqualTo: widget.substationId)
//               .where('frequency', isEqualTo: 'daily')
//               .where('readingTimestamp', isGreaterThanOrEqualTo: startOfEndDate)
//               .where('readingTimestamp', isLessThanOrEqualTo: endOfEndDate)
//               .get();
//           endDayReadings = {
//             for (var doc in endDayLogsheetsSnapshot.docs)
//               (doc.data() as Map<String, dynamic>)['bayId']:
//                   LogsheetEntry.fromFirestore(doc),
//           };
//         } else {
//           // If start and end dates are the same, endDayReadings is startDayReadings
//           // And we need to fetch readings for the previous day to calculate consumption for that single day
//           endDayReadings = startDayReadings;
//           final previousDay = _startDate.subtract(const Duration(days: 1));
//           final startOfPreviousDay = DateTime(
//             previousDay.year,
//             previousDay.month,
//             previousDay.day,
//           );
//           final endOfPreviousDay = DateTime(
//             previousDay.year,
//             previousDay.month,
//             previousDay.day,
//             23,
//             59,
//             59,
//             999,
//           );

//           final previousDayToStartDateLogsheetsSnapshot =
//               await FirebaseFirestore.instance
//                   .collection('logsheetEntries')
//                   .where('substationId', isEqualTo: widget.substationId)
//                   .where('frequency', isEqualTo: 'daily')
//                   .where(
//                     'readingTimestamp',
//                     isGreaterThanOrEqualTo: Timestamp.fromDate(
//                       startOfPreviousDay,
//                     ),
//                   )
//                   .where(
//                     'readingTimestamp',
//                     isLessThanOrEqualTo: Timestamp.fromDate(endOfPreviousDay),
//                   )
//                   .get();
//           previousDayToStartDateReadings = {
//             for (var doc in previousDayToStartDateLogsheetsSnapshot.docs)
//               (doc.data() as Map<String, dynamic>)['bayId']:
//                   LogsheetEntry.fromFirestore(doc),
//           };
//         }

//         // Fetch all assessments for the substation within the date range, ordered by timestamp
//         final assessmentsRawSnapshot = await FirebaseFirestore.instance
//             .collection('assessments')
//             .where('substationId', isEqualTo: widget.substationId)
//             .where(
//               'assessmentTimestamp',
//               isGreaterThanOrEqualTo: Timestamp.fromDate(startOfStartDate),
//             )
//             .where(
//               'assessmentTimestamp',
//               isLessThanOrEqualTo: Timestamp.fromDate(endOfEndDate),
//             )
//             .orderBy(
//               'assessmentTimestamp',
//               descending: true,
//             ) // Get most recent first
//             .get();

//         _allAssessmentsForDisplay = []; // Reset for notes section
//         _latestAssessmentsPerBay.clear(); // Reset for applying adjustments

//         for (var doc in assessmentsRawSnapshot.docs) {
//           final assessment = Assessment.fromFirestore(doc);
//           _allAssessmentsForDisplay.add(
//             assessment,
//           ); // Add all for notes display

//           // Store only the latest assessment per bay (due to orderBy descending, the first one encountered is the latest)
//           if (!_latestAssessmentsPerBay.containsKey(assessment.bayId)) {
//             _latestAssessmentsPerBay[assessment.bayId] = assessment;
//           }
//         }
//         // Sort assessments for display by most recent first
//         _allAssessmentsForDisplay.sort(
//           (a, b) => b.assessmentTimestamp.compareTo(a.assessmentTimestamp),
//         );

//         // Calculate energy for each bay
//         for (var bay in _allBaysInSubstation) {
//           final double? mf = bay.multiplyingFactor;
//           double calculatedImpConsumed = 0.0;
//           double calculatedExpConsumed = 0.0;

//           bool bayHasAssessmentForPeriod = _latestAssessmentsPerBay.containsKey(
//             bay.id,
//           );

//           if (_startDate.isAtSameMomentAs(_endDate)) {
//             final currentReadingLogsheet = endDayReadings[bay.id];
//             final previousReadingLogsheetDocument =
//                 previousDayToStartDateReadings[bay.id];

//             final double? currImpVal = double.tryParse(
//               currentReadingLogsheet?.values['Current Day Reading (Import)']
//                       ?.toString() ??
//                   '',
//             );
//             final double? currExpVal = double.tryParse(
//               currentReadingLogsheet?.values['Current Day Reading (Export)']
//                       ?.toString() ??
//                   '',
//             );

//             double? prevImpValForCalculation;
//             double? prevExpValForCalculation;

//             final double? prevImpValFromPreviousDocument = double.tryParse(
//               previousReadingLogsheetDocument
//                       ?.values['Current Day Reading (Import)']
//                       ?.toString() ??
//                   '',
//             );
//             final double? prevExpValFromPreviousDocument = double.tryParse(
//               previousReadingLogsheetDocument
//                       ?.values['Current Day Reading (Export)']
//                       ?.toString() ??
//                   '',
//             );

//             if (prevImpValFromPreviousDocument != null) {
//               prevImpValForCalculation = prevImpValFromPreviousDocument;
//             } else {
//               prevImpValForCalculation = double.tryParse(
//                 currentReadingLogsheet?.values['Previous Day Reading (Import)']
//                         ?.toString() ??
//                     '',
//               );
//             }

//             if (prevExpValFromPreviousDocument != null) {
//               prevExpValForCalculation = prevExpValFromPreviousDocument;
//             } else {
//               prevExpValForCalculation = double.tryParse(
//                 currentReadingLogsheet?.values['Previous Day Reading (Export)']
//                         ?.toString() ??
//                     '',
//               );
//             }

//             if (currImpVal != null &&
//                 prevImpValForCalculation != null &&
//                 mf != null) {
//               calculatedImpConsumed = max(
//                 0.0,
//                 (currImpVal - prevImpValForCalculation) * mf,
//               );
//             }
//             if (currExpVal != null &&
//                 prevExpValForCalculation != null &&
//                 mf != null) {
//               calculatedExpConsumed = max(
//                 0.0,
//                 (currExpVal - prevExpValForCalculation) * mf,
//               );
//             }

//             _bayEnergyData[bay.id] = BayEnergyData(
//               bayName: bay.name,
//               prevImp: prevImpValForCalculation,
//               currImp: currImpVal,
//               prevExp: prevExpValForCalculation,
//               currExp: currExpVal,
//               mf: mf,
//               impConsumed: calculatedImpConsumed,
//               expConsumed: calculatedExpConsumed,
//               hasAssessment: bayHasAssessmentForPeriod,
//             );
//           } else {
//             final startReading = startDayReadings[bay.id];
//             final endReading = endDayReadings[bay.id];

//             final double? startImpVal = double.tryParse(
//               startReading?.values['Current Day Reading (Import)']
//                       ?.toString() ??
//                   '',
//             );
//             final double? startExpVal = double.tryParse(
//               startReading?.values['Current Day Reading (Export)']
//                       ?.toString() ??
//                   '',
//             );
//             final double? endImpVal = double.tryParse(
//               endReading?.values['Current Day Reading (Import)']?.toString() ??
//                   '',
//             );
//             final double? endExpVal = double.tryParse(
//               endReading?.values['Current Day Reading (Export)']?.toString() ??
//                   '',
//             );

//             if (startImpVal != null && endImpVal != null && mf != null) {
//               calculatedImpConsumed = max(0.0, (endImpVal - startImpVal) * mf);
//             }
//             if (startExpVal != null && endExpVal != null && mf != null) {
//               calculatedExpConsumed = max(0.0, (endExpVal - startExpVal) * mf);
//             }

//             _bayEnergyData[bay.id] = BayEnergyData(
//               bayName: bay.name,
//               prevImp: startImpVal,
//               currImp: endImpVal,
//               prevExp: startExpVal,
//               currExp: endExpVal,
//               mf: mf,
//               impConsumed: calculatedImpConsumed,
//               expConsumed: calculatedExpConsumed,
//               hasAssessment: bayHasAssessmentForPeriod,
//             );
//           }

//           // Apply latest assessment if available for this bay (only one per bay from _latestAssessmentsPerBay)
//           final latestAssessment = _latestAssessmentsPerBay[bay.id];
//           if (latestAssessment != null) {
//             _bayEnergyData[bay.id] = _bayEnergyData[bay.id]!.applyAssessment(
//               importAdjustment: latestAssessment.importAdjustment,
//               exportAdjustment: latestAssessment.exportAdjustment,
//             );
//             debugPrint('Applied assessment for ${bay.name}');
//           }
//         }

//         Map<String, Map<String, double>> temporaryBusFlows = {};
//         for (var busbar in _allBaysInSubstation.where(
//           (b) => b.bayType == 'Busbar',
//         )) {
//           temporaryBusFlows[busbar.id] = {'import': 0.0, 'export': 0.0};
//         }

//         for (var entry in _busbarEnergyMaps.values) {
//           final Bay? connectedBay = _baysMap[entry.connectedBayId];
//           final BayEnergyData? connectedBayEnergy =
//               _bayEnergyData[entry.connectedBayId];

//           if (connectedBay != null &&
//               connectedBayEnergy != null &&
//               temporaryBusFlows.containsKey(entry.busbarId)) {
//             if (entry.importContribution == EnergyContributionType.busImport) {
//               temporaryBusFlows[entry.busbarId]!['import'] =
//                   (temporaryBusFlows[entry.busbarId]!['import'] ?? 0.0) +
//                   (connectedBayEnergy.impConsumed ?? 0.0);
//             } else if (entry.importContribution ==
//                 EnergyContributionType.busExport) {
//               temporaryBusFlows[entry.busbarId]!['export'] =
//                   (temporaryBusFlows[entry.busbarId]!['export'] ?? 0.0) +
//                   (connectedBayEnergy.impConsumed ?? 0.0);
//             }

//             if (entry.exportContribution == EnergyContributionType.busImport) {
//               temporaryBusFlows[entry.busbarId]!['import'] =
//                   (temporaryBusFlows[entry.busbarId]!['import'] ?? 0.0) +
//                   (connectedBayEnergy.expConsumed ?? 0.0);
//             } else if (entry.exportContribution ==
//                 EnergyContributionType.busExport) {
//               temporaryBusFlows[entry.busbarId]!['export'] =
//                   (temporaryBusFlows[entry.busbarId]!['export'] ?? 0.0) +
//                   (connectedBayEnergy.expConsumed ?? 0.0);
//             }
//           }
//         }

//         for (var busbar in _allBaysInSubstation.where(
//           (b) => b.bayType == 'Busbar',
//         )) {
//           double busTotalImp = temporaryBusFlows[busbar.id]?['import'] ?? 0.0;
//           double busTotalExp = temporaryBusFlows[busbar.id]?['export'] ?? 0.0;

//           double busDifference = busTotalImp - busTotalExp;
//           double busLossPercentage = 0.0;
//           if (busTotalImp > 0) {
//             busLossPercentage = (busDifference / busTotalImp) * 100;
//           }

//           _busEnergySummary[busbar.id] = {
//             'totalImp': busTotalImp,
//             'totalExp': busTotalExp,
//             'difference': busDifference,
//             'lossPercentage': busLossPercentage,
//           };
//           print(
//             'DEBUG: Bus Energy Summary for ${busbar.name}: Imp=${busTotalImp}, Exp=${busTotalExp}, Diff=${busDifference}, Loss=${busLossPercentage}%',
//           );
//         }

//         final highestVoltageBus = _allBaysInSubstation.firstWhereOrNull(
//           (b) => b.bayType == 'Busbar',
//         );
//         final lowestVoltageBus = _allBaysInSubstation.lastWhereOrNull(
//           (b) => b.bayType == 'Busbar',
//         );

//         double currentAbstractSubstationTotalImp = 0;
//         double currentAbstractSubstationTotalExp = 0;

//         if (highestVoltageBus != null) {
//           currentAbstractSubstationTotalImp =
//               (_busEnergySummary[highestVoltageBus.id]?['totalImp']) ?? 0.0;
//         }
//         if (lowestVoltageBus != null) {
//           currentAbstractSubstationTotalExp =
//               (_busEnergySummary[lowestVoltageBus.id]?['totalExp']) ?? 0.0;
//         }

//         double overallDifference =
//             currentAbstractSubstationTotalImp -
//             currentAbstractSubstationTotalExp;
//         double overallLossPercentage = 0;
//         if (currentAbstractSubstationTotalImp > 0) {
//           overallLossPercentage =
//               (overallDifference / currentAbstractSubstationTotalImp) * 100;
//         }

//         _abstractEnergyData = {
//           'totalImp': currentAbstractSubstationTotalImp,
//           'totalExp': currentAbstractSubstationTotalExp,
//           'difference': overallDifference,
//           'lossPercentage': overallLossPercentage,
//         };

//         final Map<String, AggregatedFeederEnergyData> tempAggregatedData = {};

//         for (var bay in _allBaysInSubstation) {
//           if (bay.bayType == 'Feeder') {
//             final energyData = _bayEnergyData[bay.id];
//             if (energyData != null) {
//               final DistributionSubdivision? distSubdivision =
//                   _distributionSubdivisionsMap[bay.distributionSubdivisionId];
//               final DistributionDivision? distDivision =
//                   _distributionDivisionsMap[distSubdivision
//                       ?.distributionDivisionId];
//               final DistributionCircle? distCircle =
//                   _distributionCirclesMap[distDivision?.distributionCircleId];
//               final DistributionZone? distZone =
//                   _distributionZonesMap[distCircle?.distributionZoneId];

//               final String zoneName = distZone?.name ?? 'N/A';
//               final String circleName = distCircle?.name ?? 'N/A';
//               final String divisionName = distDivision?.name ?? 'N/A';
//               final String distSubdivisionName = distSubdivision?.name ?? 'N/A';

//               final String groupKey =
//                   '$zoneName-$circleName-$divisionName-$distSubdivisionName';

//               final aggregatedEntry = tempAggregatedData.putIfAbsent(
//                 groupKey,
//                 () => AggregatedFeederEnergyData(
//                   zoneName: zoneName,
//                   circleName: circleName,
//                   divisionName: divisionName,
//                   distributionSubdivisionName: distSubdivisionName,
//                 ),
//               );

//               aggregatedEntry.importedEnergy += (energyData.impConsumed ?? 0.0);
//               aggregatedEntry.exportedEnergy += (energyData.expConsumed ?? 0.0);
//             }
//           }
//         }

//         _aggregatedFeederEnergyData = tempAggregatedData.values.toList();

//         _aggregatedFeederEnergyData.sort((a, b) {
//           int result = a.zoneName.compareTo(b.zoneName);
//           if (result != 0) return result;

//           result = a.circleName.compareTo(b.circleName);
//           if (result != 0) return result;

//           result = a.divisionName.compareTo(b.divisionName);
//           if (result != 0) return result;

//           return a.distributionSubdivisionName.compareTo(
//             b.distributionSubdivisionName,
//           );
//         });
//       }
//     } catch (e) {
//       print("Error loading energy data: $e");
//       if (mounted) {
//         SnackBarUtils.showSnackBar(
//           context,
//           'Failed to load energy data: $e',
//           isError: true,
//         );
//       }
//     } finally {
//       if (mounted) {
//         setState(() {
//           _isLoading = false;
//         });
//       }
//     }
//   }

//   Future<void> _fetchTransmissionHierarchyData() async {
//     _zonesMap.clear();
//     _circlesMap.clear();
//     _divisionsMap.clear();
//     _subdivisionsMap.clear();
//     _substationsMap.clear();

//     final zonesSnapshot = await FirebaseFirestore.instance
//         .collection('zones')
//         .get();
//     _zonesMap = {
//       for (var doc in zonesSnapshot.docs) doc.id: Zone.fromFirestore(doc),
//     };

//     final circlesSnapshot = await FirebaseFirestore.instance
//         .collection('circles')
//         .get();
//     _circlesMap = {
//       for (var doc in circlesSnapshot.docs) doc.id: Circle.fromFirestore(doc),
//     };

//     final divisionsSnapshot = await FirebaseFirestore.instance
//         .collection('divisions')
//         .get();
//     _divisionsMap = {
//       for (var doc in divisionsSnapshot.docs)
//         doc.id: Division.fromFirestore(doc),
//     };

//     final subdivisionsSnapshot = await FirebaseFirestore.instance
//         .collection('subdivisions')
//         .get();
//     _subdivisionsMap = {
//       for (var doc in subdivisionsSnapshot.docs)
//         doc.id: Subdivision.fromFirestore(doc),
//     };

//     final substationsSnapshot = await FirebaseFirestore.instance
//         .collection('substations')
//         .get();
//     _substationsMap = {
//       for (var doc in substationsSnapshot.docs)
//         doc.id: Substation.fromFirestore(doc),
//     };
//   }

//   Future<void> _fetchDistributionHierarchyData() async {
//     _distributionZonesMap.clear();
//     _distributionCirclesMap.clear();
//     _distributionDivisionsMap.clear();
//     _distributionSubdivisionsMap.clear();

//     final zonesSnapshot = await FirebaseFirestore.instance
//         .collection('distributionZones')
//         .get();
//     _distributionZonesMap = {
//       for (var doc in zonesSnapshot.docs)
//         doc.id: DistributionZone.fromFirestore(doc),
//     };

//     final circlesSnapshot = await FirebaseFirestore.instance
//         .collection('distributionCircles')
//         .get();
//     _distributionCirclesMap = {
//       for (var doc in circlesSnapshot.docs)
//         doc.id: DistributionCircle.fromFirestore(doc),
//     };

//     final divisionsSnapshot = await FirebaseFirestore.instance
//         .collection('distributionDivisions')
//         .get();
//     _distributionDivisionsMap = {
//       for (var doc in divisionsSnapshot.docs)
//         doc.id: DistributionDivision.fromFirestore(doc),
//     };

//     final subdivisionsSnapshot = await FirebaseFirestore.instance
//         .collection('distributionSubdivisions')
//         .get();
//     _distributionSubdivisionsMap = {
//       for (var doc in subdivisionsSnapshot.docs)
//         doc.id: DistributionSubdivision.fromFirestore(doc),
//     };
//   }

//   Future<void> _selectDate(BuildContext context) async {
//     if (_isViewingSavedSld) return; // Cannot change date range for saved SLD

//     final DateTimeRange? picked = await showDateRangePicker(
//       context: context,
//       firstDate: DateTime(2000),
//       lastDate: DateTime.now(),
//       initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
//     );

//     if (picked != null &&
//         (picked.start != _startDate || picked.end != _endDate)) {
//       setState(() {
//         _startDate = picked.start;
//         _endDate = picked.end;
//       });
//       await _loadEnergyData();
//     }
//   }

//   Future<void> _saveBusbarEnergyMap(BusbarEnergyMap map) async {
//     if (_isViewingSavedSld) return; // Cannot modify for saved SLD

//     try {
//       if (map.id == null) {
//         await FirebaseFirestore.instance
//             .collection('busbarEnergyMaps')
//             .add(map.toFirestore());
//       } else {
//         await FirebaseFirestore.instance
//             .collection('busbarEnergyMaps')
//             .doc(map.id)
//             .update(map.toFirestore());
//       }
//       await _loadEnergyData();
//     } catch (e) {
//       print('Error saving BusbarEnergyMap: $e');
//       if (mounted) {
//         SnackBarUtils.showSnackBar(
//           context,
//           'Failed to save energy map: $e',
//           isError: true,
//         );
//       }
//     }
//   }

//   Future<void> _deleteBusbarEnergyMap(String mapId) async {
//     if (_isViewingSavedSld) return; // Cannot modify for saved SLD

//     try {
//       await FirebaseFirestore.instance
//           .collection('busbarEnergyMaps')
//           .doc(mapId)
//           .delete();
//       await _loadEnergyData();
//     } catch (e) {
//       print('Error deleting BusbarEnergyMap: $e');
//       if (mounted) {
//         SnackBarUtils.showSnackBar(
//           context,
//           'Failed to delete energy map: $e',
//           isError: true,
//         );
//       }
//     }
//   }

//   void _showBusbarSelectionDialog() {
//     if (_isViewingSavedSld) return; // Cannot modify for saved SLD

//     final List<Bay> busbars = _allBaysInSubstation
//         .where((bay) => bay.bayType == 'Busbar')
//         .toList();

//     showDialog(
//       context: context,
//       builder: (BuildContext context) {
//         return AlertDialog(
//           title: const Text('Select Busbar'),
//           content: busbars.isEmpty
//               ? const Text('No busbars found in this substation.')
//               : SingleChildScrollView(
//                   child: Column(
//                     mainAxisSize: MainAxisSize.min,
//                     children: busbars.map((busbar) {
//                       return ListTile(
//                         title: Text('${busbar.voltageLevel} ${busbar.name}'),
//                         onTap: () {
//                           Navigator.pop(context);
//                           _showBusbarEnergyAssignmentDialog(busbar);
//                         },
//                       );
//                     }).toList(),
//                   ),
//                 ),
//           actions: [
//             TextButton(
//               onPressed: () => Navigator.pop(context),
//               child: const Text('Cancel'),
//             ),
//           ],
//         );
//       },
//     );
//   }

//   void _showBusbarEnergyAssignmentDialog(Bay busbar) {
//     if (_isViewingSavedSld) return; // Cannot modify for saved SLD

//     final List<Bay> connectedBays = _allConnections
//         .where(
//           (conn) =>
//               conn.sourceBayId == busbar.id || conn.targetBayId == busbar.id,
//         )
//         .map((conn) {
//           final String otherBayId = conn.sourceBayId == busbar.id
//               ? conn.targetBayId
//               : conn.sourceBayId;
//           return _baysMap[otherBayId];
//         })
//         .whereType<Bay>()
//         .where((bay) => bay.bayType != 'Busbar')
//         .toList();

//     final Map<String, BusbarEnergyMap> currentBusbarMaps = {};
//     _busbarEnergyMaps.forEach((key, value) {
//       if (value.busbarId == busbar.id) {
//         currentBusbarMaps[value.connectedBayId] = value;
//       }
//     });

//     showDialog(
//       context: context,
//       builder: (context) => _BusbarEnergyAssignmentDialog(
//         busbar: busbar,
//         connectedBays: connectedBays,
//         currentUser: widget.currentUser,
//         currentMaps: currentBusbarMaps,
//         onSaveMap: _saveBusbarEnergyMap,
//         onDeleteMap: _deleteBusbarEnergyMap,
//       ),
//     );
//   }

//   /// Method to show the energy assessment dialog for a specific bay
//   /// This is called AFTER the bay selection dialog.
//   void _showEnergyAssessmentDialog(Bay bay, BayEnergyData? energyData) {
//     if (_isViewingSavedSld) return; // Cannot add assessments to saved SLD

//     showDialog(
//       context: context,
//       builder: (context) => EnergyAssessmentDialog(
//         bay: bay,
//         currentUser: widget.currentUser,
//         currentEnergyData: energyData
//         onSaveAssessment: _loadEnergyData,
//         latestExistingAssessment:
//             _latestAssessmentsPerBay[bay.id], // Pass the latest assessment if found
//       ),
//     );
//   }

//   /// NEW: Method to show a dialog for selecting a bay for assessment
//   void _showBaySelectionForAssessment() {
//     if (_isViewingSavedSld) return; // Cannot add assessments to saved SLD

//     final List<Bay> assessableBays = _allBaysInSubstation
//         .where((bay) => ['Feeder', 'Line', 'Transformer'].contains(bay.bayType))
//         .toList();

//     showDialog(
//       context: context,
//       builder: (BuildContext context) {
//         return AlertDialog(
//           title: const Text('Select Bay for Assessment'),
//           content: assessableBays.isEmpty
//               ? const Text('No assessable bays found in this substation.')
//               : SizedBox(
//                   // Added SizedBox for width constraint
//                   width:
//                       MediaQuery.of(context).size.width *
//                       0.7, // Adjust width as needed
//                   child: SingleChildScrollView(
//                     child: Column(
//                       mainAxisSize: MainAxisSize.min,
//                       children: assessableBays.map((bay) {
//                         return ListTile(
//                           title: Text('${bay.name} (${bay.bayType})'),
//                           onTap: () {
//                             Navigator.pop(context); // Close selection dialog
//                             _showEnergyAssessmentDialog(
//                               bay,
//                               _bayEnergyData[bay
//                                   .id], // Pass current energy data
//                             );
//                           },
//                         );
//                       }).toList(),
//                     ),
//                   ),
//                 ),
//           actions: [
//             TextButton(
//               onPressed: () => Navigator.pop(context),
//               child: const Text('Cancel'),
//             ),
//           ],
//         );
//       },
//     );
//   }

//   // --- Start of methods for text movement functionality ---

//   /// Helper to get BayRenderData (copied from SubstationDetailScreen)
//   BayRenderData? _getBayRenderData(
//     String bayId,
//     List<BayRenderData> bayRenderDataList,
//   ) {
//     try {
//       return bayRenderDataList.firstWhere((data) => data.bay.id == bayId);
//     } catch (e) {
//       return null;
//     }
//   }

//   /// Function to save position/textOffset/busbarLength changes to Firestore
//   Future<void> _saveChangesToFirestore() async {
//     if (_selectedBayForMovementId == null) return;
//     if (_isViewingSavedSld) {
//       SnackBarUtils.showSnackBar(
//         context,
//         'Cannot save position changes to a historical SLD.',
//         isError: true,
//       );
//       return;
//     }

//     final bayId = _selectedBayForMovementId!;
//     try {
//       final updateData = <String, dynamic>{};

//       if (_bayPositions.containsKey(bayId)) {
//         updateData['xPosition'] = _bayPositions[bayId]!.dx;
//         updateData['yPosition'] = _bayPositions[bayId]!.dy;
//       }
//       if (_textOffsets.containsKey(bayId)) {
//         // Save textOffset as a map with 'dx' and 'dy'
//         updateData['textOffset'] = {
//           'dx': _textOffsets[bayId]!.dx,
//           'dy': _textOffsets[bayId]!.dy,
//         };
//       }
//       if (_busbarLengths.containsKey(bayId)) {
//         updateData['busbarLength'] = _busbarLengths[bayId];
//       }

//       if (updateData.isNotEmpty) {
//         await FirebaseFirestore.instance
//             .collection('bays')
//             .doc(bayId)
//             .update(updateData);
//         if (mounted) {
//           SnackBarUtils.showSnackBar(
//             context,
//             'Position changes saved successfully!',
//           );
//         }
//         // Reload data to reflect saved changes, if this is a live SLD view
//         if (!_isViewingSavedSld) {
//           await _loadEnergyData();
//         }
//       }
//     } catch (e) {
//       if (mounted) {
//         SnackBarUtils.showSnackBar(
//           context,
//           'Failed to save position changes: $e',
//           isError: true,
//         );
//       }
//     } finally {
//       setState(() {
//         _selectedBayForMovementId = null; // Exit movement mode
//         _bayPositions.clear();
//         _textOffsets.clear();
//         _busbarLengths.clear();
//       });
//     }
//   }

//   /// Method to show context menu for bay symbol actions
//   void _showBaySymbolActions(
//     BuildContext context,
//     Bay bay,
//     Offset tapPosition,
//   ) {
//     // Only allow editing/moving if not viewing a saved SLD
//     if (_isViewingSavedSld) {
//       SnackBarUtils.showSnackBar(
//         context,
//         'Cannot modify bays in a saved historical SLD.',
//       );
//       return;
//     }

//     final List<PopupMenuEntry<String>> menuItems = [
//       const PopupMenuItem<String>(
//         value: 'adjust',
//         child: ListTile(
//           leading: Icon(Icons.open_with),
//           title: Text('Adjust Position/Size'),
//         ),
//       ),
//       const PopupMenuItem<String>(
//         // NEW OPTION
//         value: 'move_text',
//         child: ListTile(
//           leading: Icon(Icons.text_fields),
//           title: Text('Adjust Text Position'),
//         ),
//       ),
//     ];

//     showMenu(
//       context: context,
//       position: RelativeRect.fromLTRB(
//         tapPosition.dx,
//         tapPosition.dy,
//         MediaQuery.of(context).size.width - tapPosition.dx,
//         MediaQuery.of(context).size.height - tapPosition.dy,
//       ),
//       items: menuItems,
//     ).then((value) {
//       if (value == 'adjust') {
//         setState(() {
//           _selectedBayForMovementId = bay.id;
//           // Initialize local state with current saved values from bay model
//           _bayPositions[bay.id] = Offset(
//             bay.xPosition ?? 0,
//             bay.yPosition ?? 0,
//           );
//           _textOffsets[bay.id] = bay.textOffset ?? Offset.zero;
//           if (bay.bayType == 'Busbar') {
//             _busbarLengths[bay.id] = bay.busbarLength ?? 200.0;
//           }
//           _movementMode = MovementMode.bay; // Set mode to bay movement
//         });
//         SnackBarUtils.showSnackBar(
//           context,
//           'Selected "${bay.name}". Use controls below to adjust.',
//         );
//       } else if (value == 'move_text') {
//         setState(() {
//           _selectedBayForMovementId = bay.id;
//           _movementMode = MovementMode.text; // Set mode to text movement
//           // Initialize text offset from the bay's current textOffset or Offset.zero
//           _textOffsets[bay.id] = bay.textOffset ?? Offset.zero;
//         });
//         SnackBarUtils.showSnackBar(
//           context,
//           'Selected "${bay.name}" text. Use controls below to adjust.',
//         );
//       }
//     });
//   }

//   /// Method to handle moving the selected item (bay or text)
//   void _moveSelectedItem(double dx, double dy) {
//     setState(() {
//       if (_movementMode == MovementMode.bay) {
//         final currentOffset =
//             _bayPositions[_selectedBayForMovementId] ?? Offset.zero;
//         _bayPositions[_selectedBayForMovementId!] = Offset(
//           currentOffset.dx + dx,
//           currentOffset.dy + dy,
//         );
//       } else {
//         // MovementMode.text
//         final currentOffset =
//             _textOffsets[_selectedBayForMovementId] ?? Offset.zero;
//         _textOffsets[_selectedBayForMovementId!] = Offset(
//           currentOffset.dx + dx,
//           currentOffset.dy + dy,
//         );
//       }
//     });
//   }

//   /// Method to adjust busbar length
//   void _adjustBusbarLength(double change) {
//     setState(() {
//       final currentLength = _busbarLengths[_selectedBayForMovementId!] ?? 100.0;
//       _busbarLengths[_selectedBayForMovementId!] = max(
//         20.0,
//         currentLength + change,
//       );
//     });
//   }

//   /// Widget for movement controls (copied and adapted from SubstationDetailScreen)
//   Widget _buildMovementControls() {
//     final selectedBay = _getBayRenderData(
//       _selectedBayForMovementId!,
//       _allBaysInSubstation
//           .map(
//             (bay) => BayRenderData(
//               bay: bay,
//               rect: Rect.zero, // Dummy rect, not used here
//               center: Offset.zero,
//               topCenter: Offset.zero,
//               bottomCenter: Offset.zero,
//               leftCenter: Offset.zero,
//               rightCenter: Offset.zero,
//               textOffset:
//                   bay.textOffset ??
//                   Offset.zero, // Use actual textOffset from bay
//               busbarLength: bay.busbarLength ?? 0.0,
//             ),
//           )
//           .toList(),
//     )?.bay;

//     if (selectedBay == null) return const SizedBox.shrink();

//     return Container(
//       padding: const EdgeInsets.all(8.0),
//       color: Colors.blueGrey.shade800,
//       child: Column(
//         mainAxisSize: MainAxisSize.min,
//         children: [
//           Text(
//             'Editing: ${selectedBay.name}',
//             style: const TextStyle(color: Colors.white, fontSize: 16),
//           ),
//           const SizedBox(height: 10),
//           SegmentedButton<MovementMode>(
//             segments: const [
//               ButtonSegment(value: MovementMode.bay, label: Text('Move Bay')),
//               ButtonSegment(value: MovementMode.text, label: Text('Move Text')),
//             ],
//             selected: {_movementMode},
//             onSelectionChanged: (newSelection) {
//               setState(() {
//                 _movementMode = newSelection.first;
//               });
//             },
//           ),
//           const SizedBox(height: 10),
//           Row(
//             mainAxisAlignment: MainAxisAlignment.center,
//             children: [
//               IconButton(
//                 icon: const Icon(Icons.arrow_back),
//                 color: Colors.white,
//                 onPressed: () => _moveSelectedItem(-_movementStep, 0),
//               ),
//               Column(
//                 children: [
//                   IconButton(
//                     icon: const Icon(Icons.arrow_upward),
//                     color: Colors.white,
//                     onPressed: () => _moveSelectedItem(0, -_movementStep),
//                   ),
//                   IconButton(
//                     icon: const Icon(Icons.arrow_downward),
//                     color: Colors.white,
//                     onPressed: () => _moveSelectedItem(0, _movementStep),
//                   ),
//                 ],
//               ),
//               IconButton(
//                 icon: const Icon(Icons.arrow_forward),
//                 color: Colors.white,
//                 onPressed: () => _moveSelectedItem(_movementStep, 0),
//               ),
//             ],
//           ),
//           if (selectedBay.bayType == 'Busbar') ...[
//             const SizedBox(height: 10),
//             const Text('Busbar Length', style: TextStyle(color: Colors.white)),
//             Row(
//               mainAxisAlignment: MainAxisAlignment.center,
//               children: [
//                 IconButton(
//                   icon: const Icon(Icons.remove),
//                   color: Colors.white,
//                   onPressed: () => _adjustBusbarLength(-_busbarLengthStep),
//                 ),
//                 Text(
//                   _busbarLengths[selectedBay.id]?.toStringAsFixed(0) ?? 'Auto',
//                   style: const TextStyle(color: Colors.white, fontSize: 16),
//                 ),
//                 IconButton(
//                   icon: const Icon(Icons.add),
//                   color: Colors.white,
//                   onPressed: () => _adjustBusbarLength(_busbarLengthStep),
//                 ),
//               ],
//             ),
//           ],
//           const SizedBox(height: 10),
//           ElevatedButton(
//             onPressed: _saveChangesToFirestore, // Call the save function
//             child: const Text('Done & Save'),
//           ),
//         ],
//       ),
//     );
//   }

//   // --- End of methods for text movement functionality ---

//   /// NEW: Method to save the current SLD state
//   Future<void> _saveSld() async {
//     if (_isViewingSavedSld) {
//       SnackBarUtils.showSnackBar(
//         context,
//         'Cannot re-save a loaded historical SLD. Please go to a live SLD to save.',
//         isError: true,
//       );
//       return;
//     }

//     // Ensure any active movement mode is saved/cancelled before saving the SLD.
//     if (_selectedBayForMovementId != null) {
//       SnackBarUtils.showSnackBar(
//         context,
//         'Please save or cancel current position adjustments first.',
//         isError: true,
//       );
//       return;
//     }

//     TextEditingController sldNameController = TextEditingController();
//     final String? sldName = await showDialog<String>(
//       context: context,
//       builder: (context) => AlertDialog(
//         title: const Text('Save SLD As...'),
//         content: TextField(
//           controller: sldNameController,
//           decoration: const InputDecoration(hintText: "Enter SLD name"),
//           autofocus: true,
//         ),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.pop(context),
//             child: const Text('Cancel'),
//           ),
//           ElevatedButton(
//             onPressed: () {
//               if (sldNameController.text.trim().isEmpty) {
//                 SnackBarUtils.showSnackBar(
//                   context,
//                   'SLD name cannot be empty!',
//                   isError: true,
//                 );
//               } else {
//                 Navigator.pop(context, sldNameController.text.trim());
//               }
//             },
//             child: const Text('Save'),
//           ),
//         ],
//       ),
//     );

//     if (sldName == null || sldName.isEmpty) return;

//     setState(() {
//       _isLoading = true; // Show loading indicator during saving
//     });

//     try {
//       // Refresh current bay data to ensure latest positions are included
//       // This is crucial because _allBaysInSubstation might not have the *very* latest unsaved changes if any.
//       // However, if you allow live adjustments, you'll need to query Firestore again or rely on a stream.
//       // For simplicity, we assume _allBaysInSubstation is reasonably up-to-date from the last _loadEnergyData call.

//       // Serialize current state for sldParameters
//       final Map<String, dynamic> currentSldParameters = {
//         'bayPositions': {
//           for (var bay in _allBaysInSubstation) // Use the latest state of bays
//             bay.id: {
//               'x': bay.xPosition,
//               'y': bay.yPosition,
//               'textOffsetDx': bay.textOffset?.dx,
//               'yPosition': bay.yPosition, // Corrected to use yPosition
//               'textOffsetDy': bay.textOffset?.dy,
//               'busbarLength': bay.busbarLength,
//             },
//         },
//         'bayEnergyData': {
//           for (var entry in _bayEnergyData.entries)
//             entry.key: entry.value.toMap(),
//         },
//         'busEnergySummary': _busEnergySummary,
//         'abstractEnergyData': _abstractEnergyData,
//         'aggregatedFeederEnergyData': _aggregatedFeederEnergyData
//             .map((e) => e.toMap())
//             .toList(),
//         // NEW: Add a map for bayId to bayName lookup for all bays
//         'bayNamesLookup': {
//           for (var bay in _allBaysInSubstation) bay.id: bay.name,
//         },
//       };

//       // Serialize current assessments for assessmentsSummary
//       final List<Map<String, dynamic>> currentAssessmentsSummary =
//           _allAssessmentsForDisplay
//               .map(
//                 (assessment) => {
//                   ...assessment.toFirestore(),
//                   // Add bayName to the summary for easier PDF generation
//                   'bayName': _baysMap[assessment.bayId]?.name ?? 'N/A',
//                 },
//               )
//               .toList();

//       final newSavedSld = SavedSld(
//         name: sldName,
//         substationId: widget.substationId,
//         substationName: widget.substationName,
//         startDate: Timestamp.fromDate(_startDate),
//         endDate: Timestamp.fromDate(_endDate),
//         createdBy: widget.currentUser.uid,
//         createdAt: Timestamp.now(),
//         sldParameters: currentSldParameters,
//         assessmentsSummary: currentAssessmentsSummary,
//       );

//       await FirebaseFirestore.instance
//           .collection('savedSlds')
//           .add(newSavedSld.toFirestore());

//       if (mounted) {
//         SnackBarUtils.showSnackBar(
//           context,
//           'SLD "${sldName}" saved successfully!',
//         );
//       }
//     } catch (e) {
//       print('Error saving SLD: $e');
//       if (mounted) {
//         SnackBarUtils.showSnackBar(
//           context,
//           'Failed to save SLD: $e',
//           isError: true,
//         );
//       }
//     } finally {
//       if (mounted) {
//         setState(() {
//           _isLoading = false;
//         });
//       }
//     }
//   }

//   /// Function to generate PDF content from the current SLD state
//   Future<Uint8List> _generatePdfFromCurrentSld() async {
//     final pdf = pw.Document();

//     // 1. Save current transformation and reset for capture
//     _originalTransformation = Matrix4.copy(_transformationController.value);

//     // Calculate fitting transformation for the capture size (210x297)
//     const double captureWidth = 300; // A4 size in mm
//     const double captureHeight = 500; // A4 size in mm

//     // Calculate the diagram's actual content size
//     final SldRenderData currentSldRenderData = _buildBayRenderDataList(
//       _allBaysInSubstation,
//       _baysMap,
//       _allConnections,
//       _bayEnergyData,
//       _busEnergySummary,
//     );
//     final double diagramContentWidth = max(
//       1.0, // Ensure it's not zero to prevent division by zero
//       (currentSldRenderData.bayRenderDataList.isNotEmpty
//               ? currentSldRenderData.bayRenderDataList
//                     .map((e) => e.rect.right + 100)
//                     .reduce(max)
//               : 0) +
//           50,
//     );
//     final double diagramContentHeight = max(
//       1.0, // Ensure it's not zero
//       (currentSldRenderData.bayRenderDataList.isNotEmpty
//               ? currentSldRenderData.bayRenderDataList
//                     .map((e) => e.rect.bottom + 100)
//                     .reduce(max)
//               : 0) +
//           50,
//     );

//     // Determine scale to fit entire diagram into capture box
//     final double scaleX = captureWidth / diagramContentWidth;
//     final double scaleY = captureHeight / diagramContentHeight;
//     final double fitScale = min(
//       scaleX,
//       scaleY,
//     ); // Use smaller scale to ensure everything fits

//     // Calculate translation to center the scaled diagram
//     final double scaledDiagramWidth = diagramContentWidth * fitScale;
//     final double scaledDiagramHeight = diagramContentHeight * fitScale;

//     final double translateX = (captureWidth - scaledDiagramWidth) / 2;
//     final double translateY = (captureHeight - scaledDiagramHeight) / 2;

//     // Apply the fitting transformation
//     _transformationController.value = Matrix4.identity()
//       ..translate(translateX, translateY)
//       ..scale(fitScale);

//     // Set flag to indicate PDF capture mode
//     setState(() {
//       _isCapturingPdf = true;
//     });

//     // Allow the UI to rebuild with the constrained size and new transformation
//     await WidgetsBinding
//         .instance
//         .endOfFrame; // Await end of the current frame rendering

//     final Uint8List? sldImageBytes = await _widgetsToImageController.capturePng(
//       pixelRatio: 10.0, // High quality capture
//     );

//     // Reset flag after capture is complete
//     setState(() {
//       _isCapturingPdf = false;
//     });

//     // 2. Restore original transformation
//     _transformationController.value = _originalTransformation!;

//     pw.MemoryImage? sldPdfImage;
//     if (sldImageBytes != null) {
//       sldPdfImage = pw.MemoryImage(sldImageBytes);
//     }

//     // Prepare data for PDF
//     final Map<String, dynamic> currentAbstractEnergyData = _abstractEnergyData;
//     final Map<String, Map<String, double>> currentBusEnergySummaryData =
//         _busEnergySummary;
//     final List<AggregatedFeederEnergyData> currentAggregatedFeederData =
//         _aggregatedFeederEnergyData;
//     // For live view, use _allAssessmentsForDisplay. For saved view, _loadedAssessmentsSummary
//     final List<Map<String, dynamic>> assessmentsForPdf = _isViewingSavedSld
//         ? _loadedAssessmentsSummary
//         : _allAssessmentsForDisplay
//               .map(
//                 (e) => {
//                   ...e.toFirestore(),
//                   // Add bayName to the summary for easier PDF generation
//                   'bayName': _baysMap[e.bayId]?.name ?? 'N/A',
//                 },
//               )
//               .toList();

//     // Use a unified map for bay names, prioritizing the loaded one if available, otherwise live
//     final Map<String, String> currentBayNamesLookup;
//     if (_isViewingSavedSld &&
//         _loadedSldParameters != null &&
//         _loadedSldParameters!.containsKey('bayNamesLookup')) {
//       currentBayNamesLookup = Map<String, String>.from(
//         _loadedSldParameters!['bayNamesLookup'],
//       );
//     } else {
//       currentBayNamesLookup = {
//         for (var bay in _allBaysInSubstation) bay.id: bay.name,
//       };
//     }

//     // NEW: Prepare data for the Abstract Energy Table (based on screenshot)
//     // Identify unique bus voltage levels in the substation
//     final List<String> uniqueBusVoltages =
//         _allBaysInSubstation
//             .where((bay) => bay.bayType == 'Busbar')
//             .map((bay) => bay.voltageLevel)
//             .toSet()
//             .toList()
//           ..sort(
//             (a, b) =>
//                 _getVoltageLevelValue(b).compareTo(_getVoltageLevelValue(a)),
//           ); // Sort descending

//     // Collect all unique distribution subdivision names from the aggregated feeder data
//     final List<String> uniqueDistributionSubdivisionNames =
//         currentAggregatedFeederData
//             .map((data) => data.distributionSubdivisionName)
//             .toSet()
//             .toList()
//           ..sort(); // Sort alphabetically for consistent order

//     // Construct the headers for the new abstract table
//     List<String> abstractTableHeaders = [
//       '',
//     ]; // Empty top-left cell for Imp./Exp./Diff./%Loss
//     for (String voltage in uniqueBusVoltages) {
//       abstractTableHeaders.add('$voltage BUS');
//     }
//     abstractTableHeaders.add('ABSTRACT OF S/S');

//     // Dynamically add columns for each unique distribution subdivision found in the data
//     for (String subDivisionName in uniqueDistributionSubdivisionNames) {
//       abstractTableHeaders.add(subDivisionName);
//     }
//     abstractTableHeaders.add('TOTAL'); // Overall total column

//     List<List<String>> abstractTableData = [];

//     // Rows for Imp., Exp., Diff., % Loss
//     final List<String> rowLabels = ['Imp.', 'Exp.', 'Diff.', '% Loss'];

//     for (int i = 0; i < rowLabels.length; i++) {
//       List<String> row = [rowLabels[i]];
//       double rowTotalSummable =
//           0.0; // Sum of values that can be directly added for 'TOTAL' column

//       // Process Bus Voltage Columns
//       for (String voltage in uniqueBusVoltages) {
//         final busbarsOfThisVoltage = _allBaysInSubstation.where(
//           (bay) => bay.bayType == 'Busbar' && bay.voltageLevel == voltage,
//         );
//         double totalForThisBusVoltageImp = 0.0;
//         double totalForThisBusVoltageExp = 0.0;
//         double totalForThisBusVoltageDiff = 0.0;

//         for (var busbar in busbarsOfThisVoltage) {
//           final busSummary = currentBusEnergySummaryData[busbar.id];
//           if (busSummary != null) {
//             totalForThisBusVoltageImp += busSummary['totalImp'] ?? 0.0;
//             totalForThisBusVoltageExp += busSummary['totalExp'] ?? 0.0;
//             totalForThisBusVoltageDiff += busSummary['difference'] ?? 0.0;
//           }
//         }

//         // Add to row based on label
//         if (rowLabels[i] == 'Imp.') {
//           row.add(totalForThisBusVoltageImp.toStringAsFixed(2));
//           rowTotalSummable += totalForThisBusVoltageImp;
//         } else if (rowLabels[i] == 'Exp.') {
//           row.add(totalForThisBusVoltageExp.toStringAsFixed(2));
//           rowTotalSummable += totalForThisBusVoltageExp;
//         } else if (rowLabels[i] == 'Diff.') {
//           row.add(totalForThisBusVoltageDiff.toStringAsFixed(2));
//           rowTotalSummable += totalForThisBusVoltageDiff;
//         } else if (rowLabels[i] == '% Loss') {
//           String lossValue = 'N/A';
//           if (totalForThisBusVoltageImp > 0) {
//             lossValue =
//                 ((totalForThisBusVoltageDiff / totalForThisBusVoltageImp) * 100)
//                     .toStringAsFixed(2);
//           }
//           row.add(lossValue);
//         }
//       }

//       // Add Abstract of S/S data
//       if (rowLabels[i] == 'Imp.') {
//         row.add(
//           (currentAbstractEnergyData['totalImp'] ?? 0.0).toStringAsFixed(2),
//         );
//         rowTotalSummable += (currentAbstractEnergyData['totalImp'] ?? 0.0);
//       } else if (rowLabels[i] == 'Exp.') {
//         row.add(
//           (currentAbstractEnergyData['totalExp'] ?? 0.0).toStringAsFixed(2),
//         );
//         rowTotalSummable += (currentAbstractEnergyData['totalExp'] ?? 0.0);
//       } else if (rowLabels[i] == 'Diff.') {
//         row.add(
//           (currentAbstractEnergyData['difference'] ?? 0.0).toStringAsFixed(2),
//         );
//         rowTotalSummable += (currentAbstractEnergyData['difference'] ?? 0.0);
//       } else if (rowLabels[i] == '% Loss') {
//         row.add(
//           (currentAbstractEnergyData['lossPercentage'] ?? 0.0).toStringAsFixed(
//             2,
//           ),
//         );
//       }

//       // Process dynamically generated feeder columns (e.g., 'Akbapur Subdivision', 'Ghaziabad Division')
//       for (String subDivisionName in uniqueDistributionSubdivisionNames) {
//         double currentFeederImp = 0.0;
//         double currentFeederExp = 0.0;
//         double currentFeederDiff = 0.0;

//         // Sum up energy for all entries that belong to this specific subdivision name
//         for (var feederData in currentAggregatedFeederData.where(
//           (data) => data.distributionSubdivisionName == subDivisionName,
//         )) {
//           currentFeederImp += feederData.importedEnergy;
//           currentFeederExp += feederData.exportedEnergy;
//           currentFeederDiff +=
//               (feederData.importedEnergy - feederData.exportedEnergy);
//         }

//         if (rowLabels[i] == 'Imp.') {
//           row.add(currentFeederImp.toStringAsFixed(2));
//           rowTotalSummable += currentFeederImp;
//         } else if (rowLabels[i] == 'Exp.') {
//           row.add(currentFeederExp.toStringAsFixed(2));
//           rowTotalSummable += currentFeederExp;
//         } else if (rowLabels[i] == 'Diff.') {
//           row.add(currentFeederDiff.toStringAsFixed(2));
//           rowTotalSummable += currentFeederDiff;
//         } else if (rowLabels[i] == '% Loss') {
//           String lossValue = 'N/A';
//           if (currentFeederImp > 0) {
//             lossValue = ((currentFeederDiff / currentFeederImp) * 100)
//                 .toStringAsFixed(2);
//           }
//           row.add(lossValue);
//         }
//       }

//       // Calculate and add the 'TOTAL' column for the row
//       if (rowLabels[i] == '% Loss') {
//         double overallTotalImp = 0.0;
//         double overallTotalDiff = 0.0;

//         // Add from Abstract of S/S
//         overallTotalImp += (currentAbstractEnergyData['totalImp'] ?? 0.0);
//         overallTotalDiff += (currentAbstractEnergyData['difference'] ?? 0.0);

//         // Add from Bus Voltages
//         for (String voltage in uniqueBusVoltages) {
//           final busbarsOfThisVoltage = _allBaysInSubstation.where(
//             (bay) => bay.bayType == 'Busbar' && bay.voltageLevel == voltage,
//           );
//           for (var busbar in busbarsOfThisVoltage) {
//             final busSummary = currentBusEnergySummaryData[busbar.id];
//             if (busSummary != null) {
//               overallTotalImp += busSummary['totalImp'] ?? 0.0;
//               overallTotalDiff += busSummary['difference'] ?? 0.0;
//             }
//           }
//         }

//         // Add from all unique distribution subdivisions
//         for (var feederData in currentAggregatedFeederData) {
//           // Iterate through all original aggregated data
//           overallTotalImp += feederData.importedEnergy;
//           overallTotalDiff +=
//               (feederData.importedEnergy - feederData.exportedEnergy);
//         }

//         String overallLossPercentage = 'N/A';
//         if (overallTotalImp > 0) {
//           overallLossPercentage = ((overallTotalDiff / overallTotalImp) * 100)
//               .toStringAsFixed(2);
//         }
//         row.add(overallLossPercentage);
//       } else {
//         row.add(rowTotalSummable.toStringAsFixed(2));
//       }

//       abstractTableData.add(row);
//     }

//     pdf.addPage(
//       pw.MultiPage(
//         pageFormat: PdfPageFormat.a4.copyWith(
//           marginBottom: 1.5 * PdfPageFormat.cm,
//           marginTop: 1.5 * PdfPageFormat.cm,
//           marginLeft: 1.5 * PdfPageFormat.cm,
//           marginRight: 1.5 * PdfPageFormat.cm,
//         ),
//         header: (pw.Context context) {
//           return pw.Column(
//             crossAxisAlignment: pw.CrossAxisAlignment.start,
//             children: [
//               pw.Text(
//                 'Substation Energy Account Report',
//                 style: pw.TextStyle(
//                   fontSize: 18,
//                   fontWeight: pw.FontWeight.bold,
//                 ),
//               ),
//               pw.Text(widget.substationName, style: pw.TextStyle(fontSize: 14)),
//               pw.Text(
//                 'Period: ${DateFormat('dd-MMM-yyyy').format(_startDate)} to ${DateFormat('dd-MMM-yyyy').format(_endDate)}',
//                 style: pw.TextStyle(fontSize: 12),
//               ),
//               pw.Divider(),
//             ],
//           );
//         },
//         build: (pw.Context context) {
//           return [
//             // MODIFIED: SLD Drawing section moved to the top
//             if (sldPdfImage != null)
//               pw.Center(
//                 child: pw.Column(
//                   children: [
//                     pw.Text(
//                       'Single Line Diagram',
//                       style: pw.TextStyle(
//                         fontSize: 14,
//                         fontWeight: pw.FontWeight.bold,
//                       ),
//                     ),
//                     pw.SizedBox(height: 10),
//                     pw.Image(
//                       sldPdfImage,
//                       fit: pw.BoxFit.contain,
//                       width: PdfPageFormat.a4.width - (3 * PdfPageFormat.cm),
//                     ),
//                     pw.SizedBox(height: 30),
//                   ],
//                 ),
//               )
//             else
//               pw.Text(
//                 'SLD Diagram could not be captured.',
//                 style: pw.TextStyle(color: PdfColors.red),
//               ),

//             // NEW SECTION: Consolidated Energy Abstract (now comes after SLD)
//             pw.Header(
//               level: 0,
//               text: 'Consolidated Energy Abstract',
//               decoration: pw.BoxDecoration(
//                 border: pw.Border(bottom: pw.BorderSide()),
//               ),
//             ),
//             pw.Table.fromTextArray(
//               context: context,
//               headers: abstractTableHeaders,
//               data: abstractTableData,
//               border: pw.TableBorder.all(width: 0.5),
//               headerStyle: pw.TextStyle(
//                 fontWeight: pw.FontWeight.bold,
//                 fontSize: 8,
//               ),
//               cellAlignment: pw.Alignment.center,
//               cellPadding: const pw.EdgeInsets.all(3),
//               columnWidths: {
//                 0: const pw.FlexColumnWidth(1.2), // For Imp, Exp, etc.
//                 for (int i = 0; i < uniqueBusVoltages.length; i++)
//                   i + 1: const pw.FlexColumnWidth(1.0), // For each bus voltage
//                 uniqueBusVoltages.length + 1: const pw.FlexColumnWidth(
//                   1.2,
//                 ), // Abstract of S/S
//                 // Dynamically added feeder columns - these indices will depend on uniqueDistributionSubdivisionNames.length
//                 for (
//                   int i = 0;
//                   i < uniqueDistributionSubdivisionNames.length;
//                   i++
//                 )
//                   (uniqueBusVoltages.length + 2 + i): const pw.FlexColumnWidth(
//                     1.0,
//                   ),
//                 (uniqueBusVoltages.length +
//                         2 +
//                         uniqueDistributionSubdivisionNames.length):
//                     const pw.FlexColumnWidth(1.2), // TOTAL
//               },
//             ),
//             pw.SizedBox(height: 20),

//             // Section: Feeder Energy Supplied by Distribution Hierarchy (remains after abstract table)
//             pw.Header(
//               level: 0,
//               text: 'Feeder Energy Supplied by Distribution Hierarchy',
//               decoration: pw.BoxDecoration(
//                 border: pw.Border(bottom: pw.BorderSide()),
//               ),
//             ),
//             if (currentAggregatedFeederData.isNotEmpty)
//               pw.Table.fromTextArray(
//                 context: context,
//                 headers: <String>[
//                   'D-Zone',
//                   'D-Circle',
//                   'D-Division',
//                   'D-Subdivision',
//                   'Import (MWH)',
//                   'Export (MWH)',
//                 ],
//                 data: currentAggregatedFeederData.map((data) {
//                   return <String>[
//                     data.zoneName,
//                     data.circleName,
//                     data.divisionName,
//                     data.distributionSubdivisionName,
//                     data.importedEnergy.toStringAsFixed(2),
//                     data.exportedEnergy.toStringAsFixed(2),
//                   ];
//                 }).toList(),
//                 border: pw.TableBorder.all(width: 0.5),
//                 headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
//                 cellAlignment: pw.Alignment.centerLeft,
//                 cellPadding: const pw.EdgeInsets.all(4),
//               )
//             else
//               pw.Text('No aggregated feeder energy data available.'),
//             pw.SizedBox(height: 20),

//             // Section: Assessments (remains at the end)
//             pw.Header(
//               level: 0,
//               text: 'Assessments for this Period',
//               decoration: pw.BoxDecoration(
//                 border: pw.Border(bottom: pw.BorderSide()),
//               ),
//             ),
//             if (assessmentsForPdf.isNotEmpty)
//               pw.Table.fromTextArray(
//                 context: context,
//                 headers: <String>[
//                   'Bay Name',
//                   'Import Adj.',
//                   'Export Adj.',
//                   'Reason',
//                   'Timestamp',
//                 ],
//                 data: assessmentsForPdf.map((assessmentMap) {
//                   final Assessment assessment = Assessment.fromMap(
//                     assessmentMap,
//                   );
//                   return <String>[
//                     assessmentMap['bayName'] ?? 'N/A', // Use stored bayName
//                     assessment.importAdjustment?.toStringAsFixed(2) ?? 'N/A',
//                     assessment.exportAdjustment?.toStringAsFixed(2) ?? 'N/A',
//                     assessment.reason,
//                     DateFormat(
//                       'dd-MMM-yyyy HH:mm',
//                     ).format(assessment.assessmentTimestamp.toDate()),
//                   ];
//                 }).toList(),
//                 border: pw.TableBorder.all(width: 0.5),
//                 headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
//                 cellAlignment: pw.Alignment.centerLeft,
//                 cellPadding: const pw.EdgeInsets.all(4),
//                 columnWidths: {
//                   0: const pw.FlexColumnWidth(2),
//                   1: const pw.FlexColumnWidth(1.2),
//                   2: const pw.FlexColumnWidth(1.2),
//                   3: const pw.FlexColumnWidth(3),
//                   4: const pw.FlexColumnWidth(2),
//                 },
//               )
//             else
//               pw.Text('No assessments were made for this period.'),
//           ];
//         },
//       ),
//     );

//     return await pdf.save();
//   }

//   /// Helper for building energy rows in PDF
//   pw.Widget _buildPdfEnergyRow(String label, dynamic value, String unit) {
//     return pw.Padding(
//       padding: const pw.EdgeInsets.symmetric(vertical: 2.0),
//       child: pw.Row(
//         mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
//         children: [
//           pw.Text('$label:', style: const pw.TextStyle(fontSize: 10)),
//           pw.Text(
//             value != null ? '${value.toStringAsFixed(2)} $unit' : 'N/A',
//             style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
//           ),
//         ],
//       ),
//     );
//   }

//   /// Function to handle PDF generation and sharing for the currently displayed SLD
//   Future<void> _shareCurrentSldAsPdf() async {
//     try {
//       SnackBarUtils.showSnackBar(context, 'Generating PDF...');
//       final Uint8List pdfBytes = await _generatePdfFromCurrentSld();

//       final output = await getTemporaryDirectory();
//       final String filename =
//           '${widget.substationName.replaceAll(RegExp(r'[^\w\s.-]'), '_')}_energy_report_${DateFormat('yyyyMMdd').format(_endDate)}.pdf';
//       final file = File('${output.path}/$filename');
//       await file.writeAsBytes(pdfBytes);

//       await Share.shareXFiles([
//         XFile(file.path),
//       ], subject: 'Energy SLD Report: ${widget.substationName}');

//       if (mounted) {
//         SnackBarUtils.showSnackBar(
//           context,
//           'PDF generated and shared successfully!',
//         );
//       }
//     } catch (e) {
//       print("Error generating/sharing PDF: $e");
//       if (mounted) {
//         SnackBarUtils.showSnackBar(
//           context,
//           'Failed to generate/share PDF: $e',
//           isError: true,
//         );
//       }
//     }
//   }

//   SldRenderData _buildBayRenderDataList(
//     List<Bay> allBays,
//     Map<String, Bay> baysMap,
//     List<BayConnection> allConnections,
//     Map<String, BayEnergyData> bayEnergyData,
//     Map<String, Map<String, double>> busEnergySummary,
//   ) {
//     final List<BayRenderData> bayRenderDataList = [];
//     final Map<String, Rect> finalBayRects = {};
//     final Map<String, Rect> busbarRects = {};
//     final Map<String, Map<String, Offset>> busbarConnectionPoints = {};

//     const double symbolWidth = 60;
//     const double symbolHeight = 60;
//     const double horizontalSpacing = 100;
//     const double verticalBusbarSpacing = 200;
//     const double topPadding = 80;
//     const double sidePadding = 100;
//     const double busbarHitboxHeight = 50.0;
//     const double lineFeederHeight = 70.0;

//     final List<Bay> busbars = allBays
//         .where((b) => b.bayType == 'Busbar')
//         .toList();
//     busbars.sort((a, b) {
//       double getV(String v) =>
//           double.tryParse(v.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0;
//       return getV(b.voltageLevel).compareTo(getV(a.voltageLevel));
//     });

//     final Map<String, double> busYPositions = {};
//     for (int i = 0; i < busbars.length; i++) {
//       busYPositions[busbars[i].id] = topPadding + i * verticalBusbarSpacing;
//     }

//     final Map<String, List<Bay>> busbarToConnectedBaysAbove = {};
//     final Map<String, List<Bay>> busbarToConnectedBaysBelow = {};
//     final Map<String, Map<String, List<Bay>>> transformersByBusPair = {};

//     for (var bay in allBays) {
//       if (!['Busbar', 'Transformer', 'Line', 'Feeder'].contains(bay.bayType)) {
//         continue;
//       }

//       // Initialize bay position and text offset for all relevant bay types
//       // This is the crucial part that was missing for feeders and lines
//       if (!_bayPositions.containsKey(bay.id)) {
//         if (bay.xPosition != null && bay.yPosition != null) {
//           _bayPositions[bay.id] = Offset(bay.xPosition!, bay.yPosition!);
//         } else {
//           // Provide a default if not already set, will be updated during layout
//           // For initial placement, setting to (0,0) is fine as the CustomPainter will
//           // give it a calculated position, which will then be stored in _bayPositions
//           // if the user interacts with it.
//           _bayPositions[bay.id] = Offset.zero;
//         }
//       }
//       if (!_textOffsets.containsKey(bay.id)) {
//         _textOffsets[bay.id] = bay.textOffset ?? Offset.zero;
//       }
//       if (bay.bayType == 'Busbar' && !_busbarLengths.containsKey(bay.id)) {
//         _busbarLengths[bay.id] =
//             bay.busbarLength ?? 200.0; // Default busbar length
//       }

//       if (bay.bayType == 'Transformer') {
//         if (bay.hvBusId != null && bay.lvBusId != null) {
//           final hvBus = baysMap[bay.hvBusId];
//           final lvBus = baysMap[bay.lvBusId];
//           if (hvBus != null &&
//               lvBus != null &&
//               hvBus.bayType == 'Busbar' &&
//               lvBus.bayType == 'Busbar') {
//             final double hvVoltage = _getVoltageLevelValue(hvBus.voltageLevel);
//             final double lvVoltage = _getVoltageLevelValue(lvBus.voltageLevel);

//             String key = "";
//             if (hvVoltage > lvVoltage) {
//               key = "${hvBus.id}-${lvBus.id}";
//             } else {
//               key = "${lvBus.id}-${hvBus.id}";
//             }
//             transformersByBusPair
//                 .putIfAbsent(key, () => {})
//                 .putIfAbsent(hvBus.id, () => [])
//                 .add(bay);
//           } else {
//             debugPrint(
//               'Transformer ${bay.name} (${bay.id}) linked to non-busbar or missing bus: HV=${bay.hvBusId}, LV=${bay.lvBusId}',
//             );
//           }
//         }
//       } else if (bay.bayType != 'Busbar') {
//         final connectionToBus = allConnections.firstWhereOrNull((c) {
//           final bool sourceIsBay = c.sourceBayId == bay.id;
//           final bool targetIsBay = c.targetBayId == bay.id;
//           final bool sourceIsBus = baysMap[c.sourceBayId]?.bayType == 'Busbar';
//           final bool targetIsBus = baysMap[c.targetBayId]?.bayType == 'Busbar';
//           return (sourceIsBay && targetIsBus) || (targetIsBay && sourceIsBus);
//         });

//         if (connectionToBus != null) {
//           final String connectedBusId =
//               baysMap[connectionToBus.sourceBayId]?.bayType == 'Busbar'
//               ? connectionToBus.sourceBayId
//               : connectionToBus.targetBayId;

//           if (bay.bayType == 'Line') {
//             busbarToConnectedBaysAbove
//                 .putIfAbsent(connectedBusId, () => [])
//                 .add(bay);
//           } else {
//             busbarToConnectedBaysBelow
//                 .putIfAbsent(connectedBusId, () => [])
//                 .add(bay);
//           }
//         }
//       }
//     }

//     busbarToConnectedBaysAbove.forEach(
//       (key, value) => value.sort((a, b) => a.name.compareTo(b.name)),
//     );
//     busbarToConnectedBaysBelow.forEach(
//       (key, value) => value.sort((a, b) => a.name.compareTo(b.name)),
//     );
//     transformersByBusPair.forEach((pairKey, transformersMap) {
//       transformersMap.forEach((busId, transformers) {
//         transformers.sort((a, b) => a.name.compareTo(b.name));
//       });
//     });

//     double maxOverallXForCanvas = sidePadding;
//     double nextTransformerX = sidePadding;
//     final List<Bay> placedTransformers = [];

//     for (var busPairEntry in transformersByBusPair.entries) {
//       final String pairKey = busPairEntry.key;
//       final Map<String, List<Bay>> transformersForPair = busPairEntry.value;

//       List<String> busIdsInPair = pairKey.split('-');
//       String hvBusId = busIdsInPair[0];
//       String lvBusId = busIdsInPair[1];

//       // NEW: Add null check for busYPositions
//       if (!busYPositions.containsKey(hvBusId) ||
//           !busYPositions.containsKey(lvBusId)) {
//         debugPrint(
//           'Skipping transformer group for pair $pairKey: One or both bus IDs not found in busYPositions. This should ideally not happen if data is clean.',
//         );
//         continue; // Skip this transformer group if bus position is unknown
//       }

//       final Bay? currentHvBus = baysMap[hvBusId];
//       final Bay? currentLvBus = baysMap[lvBusId];

//       if (currentHvBus == null || currentLvBus == null) {
//         debugPrint(
//           'Skipping transformer group for pair $pairKey: One or both bus objects not found in baysMap. This should ideally not happen if data is clean.',
//         );
//         continue; // Should ideally not happen if busYPositions check passes, but extra safety
//       }

//       final double hvVoltageValue = _getVoltageLevelValue(
//         currentHvBus.voltageLevel,
//       );
//       final double lvVoltageValue = _getVoltageLevelValue(
//         currentLvBus.voltageLevel,
//       );

//       if (hvVoltageValue < lvVoltageValue) {
//         String temp = hvBusId;
//         hvBusId = lvBusId;
//         lvBusId = temp;
//       }

//       final double hvBusY = busYPositions[hvBusId]!; // Now safe due to check
//       final double lvBusY = busYPositions[lvBusId]!; // Now safe due to check

//       final List<Bay> transformers =
//           transformersForPair[hvBusId] ?? transformersForPair[lvBusId] ?? [];
//       for (var tf in transformers) {
//         if (!placedTransformers.contains(tf)) {
//           // Determine final position based on local state, saved position, or calculated default
//           Offset finalOffset;
//           if (_selectedBayForMovementId == tf.id &&
//               _bayPositions.containsKey(tf.id)) {
//             finalOffset = _bayPositions[tf.id]!;
//           } else if (tf.xPosition != null && tf.yPosition != null) {
//             finalOffset = Offset(tf.xPosition!, tf.yPosition!);
//           } else {
//             finalOffset = Offset(
//               nextTransformerX + symbolWidth / 2,
//               (hvBusY + lvBusY) / 2,
//             );
//             // This is handled by the earlier general initialization for all bays
//             // if (!_bayPositions.containsKey(tf.id)) {
//             //   _bayPositions[tf.id] =
//             //       finalOffset; // Initialize for potential future edits
//             // }
//           }

//           final tfRect = Rect.fromCenter(
//             center: finalOffset,
//             width: symbolWidth,
//             height: symbolHeight,
//           );
//           finalBayRects[tf.id] = tfRect;
//           nextTransformerX += horizontalSpacing;
//           placedTransformers.add(tf);
//           maxOverallXForCanvas = max(maxOverallXForCanvas, tfRect.right);
//         }
//       }
//     }

//     double currentLaneXForOtherBays = nextTransformerX;

//     for (var busbar in busbars) {
//       final double busY = busYPositions[busbar.id]!;

//       final List<Bay> baysAbove = List.from(
//         busbarToConnectedBaysAbove[busbar.id] ?? [],
//       );
//       double currentX = currentLaneXForOtherBays;
//       for (var bay in baysAbove) {
//         // Determine final position based on local state, saved position, or calculated default
//         Offset finalOffset;
//         if (_selectedBayForMovementId == bay.id &&
//             _bayPositions.containsKey(bay.id)) {
//           finalOffset = _bayPositions[bay.id]!;
//         } else if (bay.xPosition != null && bay.yPosition != null) {
//           finalOffset = Offset(bay.xPosition!, bay.yPosition!);
//         } else {
//           finalOffset = Offset(currentX, busY - lineFeederHeight - 10);
//           // This is handled by the earlier general initialization for all bays
//           // if (!_bayPositions.containsKey(bay.id)) {
//           //   _bayPositions[bay.id] =
//           //       finalOffset; // Initialize for potential future edits
//           // }
//         }

//         final bayRect = Rect.fromLTWH(
//           finalOffset.dx,
//           finalOffset.dy,
//           symbolWidth,
//           lineFeederHeight,
//         );
//         finalBayRects[bay.id] = bayRect;
//         currentX += horizontalSpacing;
//       }
//       maxOverallXForCanvas = max(maxOverallXForCanvas, currentX);

//       final List<Bay> baysBelow = List.from(
//         busbarToConnectedBaysBelow[busbar.id] ?? [],
//       );
//       currentX = currentLaneXForOtherBays;
//       for (var bay in baysBelow) {
//         // Determine final position based on local state, saved position, or calculated default
//         Offset finalOffset;
//         if (_selectedBayForMovementId == bay.id &&
//             _bayPositions.containsKey(bay.id)) {
//           finalOffset = _bayPositions[bay.id]!;
//         } else if (bay.xPosition != null && bay.yPosition != null) {
//           finalOffset = Offset(bay.xPosition!, bay.yPosition!);
//         } else {
//           finalOffset = Offset(currentX, busY + 10);
//           // This is handled by the earlier general initialization for all bays
//           // if (!_bayPositions.containsKey(bay.id)) {
//           //   _bayPositions[bay.id] =
//           //       finalOffset; // Initialize for potential future edits
//           // }
//         }

//         final bayRect = Rect.fromLTWH(
//           finalOffset.dx,
//           finalOffset
//               .dy, // CORRECTED: Changed from finalBayRects[bay.id]!.top to finalOffset.dy
//           symbolWidth,
//           lineFeederHeight,
//         );
//         finalBayRects[bay.id] = bayRect;
//         currentX += horizontalSpacing;
//       }
//       maxOverallXForCanvas = max(maxOverallXForCanvas, currentX);
//     }

//     for (var busbar in busbars) {
//       final double busY = busYPositions[busbar.id]!;
//       double maxConnectedBayX = sidePadding;

//       allBays.where((b) => b.bayType != 'Busbar').forEach((bay) {
//         if (bay.bayType == 'Transformer') {
//           if ((bay.hvBusId == busbar.id || bay.lvBusId == busbar.id) &&
//               finalBayRects.containsKey(bay.id)) {
//             maxConnectedBayX = max(
//               maxConnectedBayX,
//               finalBayRects[bay.id]!.right,
//             );
//           }
//         } else {
//           final connectionToBus = allConnections.firstWhereOrNull((c) {
//             return (c.sourceBayId == bay.id && c.targetBayId == busbar.id) ||
//                 (c.targetBayId == bay.id && c.sourceBayId == busbar.id);
//           });
//           if (connectionToBus != null && finalBayRects.containsKey(bay.id)) {
//             maxConnectedBayX = max(
//               maxConnectedBayX,
//               finalBayRects[bay.id]!.right,
//             );
//           }
//         }
//       });

//       final double effectiveBusWidth = max(
//         maxConnectedBayX - sidePadding + horizontalSpacing,
//         symbolWidth * 2,
//       ).toDouble();

//       // Determine busbar width based on local state, saved length, or calculated default
//       final double busbarWidth;
//       if (_selectedBayForMovementId == busbar.id &&
//           _busbarLengths.containsKey(busbar.id)) {
//         busbarWidth = _busbarLengths[busbar.id]!;
//       } else if (busbar.busbarLength != null) {
//         busbarWidth = busbar.busbarLength!;
//       } else {
//         busbarWidth = effectiveBusWidth;
//         // This is handled by the earlier general initialization for all bays
//         // if (!_busbarLengths.containsKey(busbar.id)) {
//         //   _busbarLengths[busbar.id] =
//         //       busbarWidth; // Initialize for potential future edits
//         // }
//       }

//       final Rect drawingRect = Rect.fromLTWH(sidePadding, busY, busbarWidth, 0);
//       busbarRects[busbar.id] = drawingRect;

//       final Rect tappableRect = Rect.fromCenter(
//         center: Offset(sidePadding + busbarWidth / 2, busY),
//         width: busbarWidth,
//         height: busbarHitboxHeight,
//       );
//       finalBayRects[busbar.id] = tappableRect;
//     }

//     final List<String> allowedVisualBayTypes = [
//       'Busbar',
//       'Transformer',
//       'Line',
//       'Feeder',
//     ];

//     for (var bay in allBays) {
//       if (!allowedVisualBayTypes.contains(bay.bayType)) {
//         continue;
//       }
//       // Ensure the bay's position in _bayPositions is used for rect calculation
//       final Offset bayPosition = _bayPositions[bay.id] ?? Offset.zero;

//       Rect rect;
//       if (bay.bayType == 'Busbar') {
//         final double busbarLength = _busbarLengths[bay.id] ?? 200.0;
//         rect = Rect.fromCenter(
//           center: Offset(bayPosition.dx, bayPosition.dy),
//           width: busbarLength,
//           height: busbarHitboxHeight,
//         );
//         busbarRects[bay.id] = Rect.fromLTWH(
//           bayPosition.dx - busbarLength / 2,
//           bayPosition.dy,
//           busbarLength,
//           0,
//         );
//       } else {
//         rect = Rect.fromLTWH(
//           bayPosition.dx,
//           bayPosition.dy,
//           symbolWidth,
//           lineFeederHeight,
//         );
//       }

//       finalBayRects[bay.id] = rect;

//       // Determine text offset: local override > saved in Firestore > default (Offset.zero)
//       Offset currentTextOffset = _textOffsets[bay.id] ?? Offset.zero;

//       bayRenderDataList.add(
//         BayRenderData(
//           bay: bay,
//           rect: rect,
//           center: rect.center,
//           topCenter: rect.topCenter,
//           bottomCenter: rect.bottomCenter,
//           leftCenter: rect.centerLeft,
//           rightCenter: rect.centerRight,
//           equipmentInstances: _equipmentByBayId[bay.id] ?? [],
//           textOffset: currentTextOffset, // Pass the effective text offset
//           busbarLength: _busbarLengths[bay.id] ?? 0.0,
//         ),
//       );
//     }

//     // Set _currentBayRenderDataList so _buildMovementControls can access it
//     _currentBayRenderDataList = bayRenderDataList;

//     for (var connection in allConnections) {
//       final sourceBay = baysMap[connection.sourceBayId];
//       final targetBay = baysMap[connection.targetBayId];
//       if (sourceBay == null || targetBay == null) continue;

//       if (!allowedVisualBayTypes.contains(sourceBay.bayType) ||
//           !allowedVisualBayTypes.contains(targetBay.bayType)) {
//         continue;
//       }

//       // Use the *actual* calculated or user-adjusted position for connections
//       final Rect? sourceRect = finalBayRects[sourceBay.id];
//       final Rect? targetRect = finalBayRects[targetBay.id];
//       final double? sourceBusY =
//           busYPositions[sourceBay.id]; // Only for busbars
//       final double? targetBusY =
//           busYPositions[targetBay.id]; // Only for busbars

//       if (sourceBay.bayType == 'Busbar' && targetBay.bayType == 'Transformer') {
//         if (targetRect != null && sourceBusY != null) {
//           busbarConnectionPoints.putIfAbsent(
//             sourceBay.id,
//             () => {},
//           )[targetBay.id] = Offset(
//             targetRect.center.dx,
//             sourceBusY,
//           );
//         }
//       } else if (targetBay.bayType == 'Busbar' &&
//           sourceBay.bayType == 'Transformer') {
//         if (sourceRect != null && targetBusY != null) {
//           busbarConnectionPoints.putIfAbsent(
//             targetBay.id,
//             () => {},
//           )[sourceBay.id] = Offset(
//             sourceRect.center.dx,
//             targetBusY,
//           );
//         }
//       } else if (sourceBay.bayType == 'Busbar' &&
//           targetBay.bayType != 'Busbar') {
//         if (targetRect != null && sourceBusY != null) {
//           busbarConnectionPoints.putIfAbsent(
//             sourceBay.id,
//             () => {},
//           )[targetBay.id] = Offset(
//             targetRect.center.dx,
//             sourceBusY,
//           );
//         }
//       } else if (targetBay.bayType == 'Busbar' &&
//           sourceBay.bayType != 'Busbar') {
//         if (sourceRect != null && targetBusY != null) {
//           busbarConnectionPoints.putIfAbsent(
//             targetBay.id,
//             () => {},
//           )[sourceBay.id] = Offset(
//             sourceRect.center.dx,
//             targetBusY,
//           );
//         }
//       }
//     }
//     return SldRenderData(
//       bayRenderDataList: bayRenderDataList,
//       finalBayRects: finalBayRects,
//       busbarRects: busbarRects,
//       busbarConnectionPoints: busbarConnectionPoints,
//       bayEnergyData: bayEnergyData,
//       busEnergySummary: busEnergySummary,
//       abstractEnergyData: _abstractEnergyData, // Pass abstract data
//       aggregatedFeederEnergyData:
//           _aggregatedFeederEnergyData, // Pass aggregated feeder data
//     );
//   }

//   BayRenderData _createDummyBayRenderData() {
//     return BayRenderData(
//       bay: Bay(
//         id: 'dummy',
//         name: '',
//         substationId: '',
//         voltageLevel: '',
//         bayType: '',
//         createdBy: '',
//         createdAt: Timestamp.now(),
//       ),
//       rect: Rect.zero,
//       center: Offset.zero,
//       topCenter: Offset.zero,
//       bottomCenter: Offset.zero,
//       leftCenter: Offset.zero,
//       rightCenter: Offset.zero,
//       textOffset: Offset.zero,
//       busbarLength: 0.0,
//     );
//   }

//   Widget _buildPageIndicator(int pageCount, int currentPage) {
//     List<Widget> indicators = [];
//     final actualPageCount = pageCount > 0 ? pageCount : 1;
//     for (int i = 0; i < actualPageCount; i++) {
//       indicators.add(
//         Container(
//           width: 8.0,
//           height: 8.0,
//           margin: const EdgeInsets.symmetric(horizontal: 4.0),
//           decoration: BoxDecoration(
//             shape: BoxShape.circle,
//             color: currentPage == i ? Colors.blue : Colors.grey,
//           ),
//         ),
//       );
//     }
//     return Row(
//       mainAxisAlignment: MainAxisAlignment.center,
//       children: indicators,
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     String dateRangeText;
//     if (_startDate.isAtSameMomentAs(_endDate)) {
//       dateRangeText = DateFormat('dd-MMM-yyyy').format(_startDate);
//     } else {
//       dateRangeText =
//           '${DateFormat('dd-MMM-yyyy').format(_startDate)} to ${DateFormat('dd-MMM-yyyy').format(_endDate)}';
//     }

//     if (widget.substationId.isEmpty) {
//       return const Center(
//         child: Padding(
//           padding: EdgeInsets.all(16.0),
//           child: Text(
//             'Please select a substation to view energy SLD.',
//             textAlign: TextAlign.center,
//             style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey),
//           ),
//         ),
//       );
//     }

//     final SldRenderData sldRenderData = _buildBayRenderDataList(
//       _allBaysInSubstation,
//       _baysMap,
//       _allConnections,
//       _bayEnergyData,
//       _busEnergySummary,
//     );

//     final double canvasWidth = max(
//       MediaQuery.of(context).size.width,
//       (sldRenderData.bayRenderDataList.isNotEmpty
//               ? sldRenderData.bayRenderDataList
//                     .map((e) => e.rect.right + 100)
//                     .reduce(max)
//               : 0) +
//           50,
//     );
//     final double canvasHeight = max(
//       MediaQuery.of(context).size.height,
//       (sldRenderData.bayRenderDataList.isNotEmpty
//               ? sldRenderData.bayRenderDataList
//                     .map((e) => e.rect.bottom + 100)
//                     .reduce(max)
//               : 0) +
//           50,
//     );

//     const double abstractCardWidth = 400;
//     const double abstractCardHeight = 200; // Adjusted for better fit in UI
//     const double feederTableHeight = 300;
//     const double assessmentTableHeight = 250;

//     final List<Bay> busbarsWithData = _allBaysInSubstation
//         .where(
//           (bay) =>
//               bay.bayType == 'Busbar' && _busEnergySummary.containsKey(bay.id),
//         )
//         .toList();

//     return Scaffold(
//       appBar: AppBar(
//         title: Text(
//           'Energy Account: ${widget.substationName} ($dateRangeText)',
//         ),
//         actions: [
//           IconButton(
//             icon: const Icon(Icons.calendar_today),
//             onPressed: _isViewingSavedSld ? null : () => _selectDate(context),
//             tooltip: _isViewingSavedSld
//                 ? 'Date range cannot be changed for saved SLD'
//                 : 'Change Date Range',
//           ),
//           // Add button to toggle movement controls if not viewing saved SLD
//           if (!_isViewingSavedSld && _selectedBayForMovementId == null)
//             IconButton(
//               icon: const Icon(Icons.move_up), // Or another appropriate icon
//               tooltip: 'Adjust SLD Layout',
//               onPressed: () {
//                 SnackBarUtils.showSnackBar(
//                   context,
//                   'Tap and hold a bay to adjust its position/size.',
//                 );
//               },
//             ),
//           if (_selectedBayForMovementId != null)
//             IconButton(
//               icon: const Icon(Icons.cancel),
//               tooltip: 'Cancel Adjustments',
//               onPressed: () {
//                 setState(() {
//                   _selectedBayForMovementId = null;
//                   _bayPositions.clear();
//                   _textOffsets.clear();
//                   _busbarLengths.clear();
//                 });
//                 SnackBarUtils.showSnackBar(
//                   context,
//                   'Adjustments cancelled. Position not saved.',
//                 );
//               },
//             ),
//         ],
//       ),
//       body: _isLoading
//           ? const Center(child: CircularProgressIndicator())
//           : Column(
//               children: [
//                 Expanded(
//                   child: Stack(
//                     children: [
//                       WidgetsToImage(
//                         controller: _widgetsToImageController,
//                         child:
//                             _isCapturingPdf // <--- NEW CONDITIONAL LOGIC
//                             ? SizedBox(
//                                 // Fixed size for PDF capture
//                                 width: 1200, // Reasonable width for PDF output
//                                 height: 800, // Reasonable height for PDF output
//                                 child: InteractiveViewer(
//                                   // For PDF capture, make the viewer constrained
//                                   transformationController:
//                                       _transformationController,
//                                   boundaryMargin: EdgeInsets
//                                       .zero, // No infinite margin during capture
//                                   minScale:
//                                       1.0, // Scale will be set by transformationController.value
//                                   maxScale: 1.0,
//                                   constrained:
//                                       true, // Crucial: force child to fit parent bounds
//                                   child: CustomPaint(
//                                     // The size here will be the fixed capture size
//                                     size: const Size(
//                                       1200,
//                                       800,
//                                     ), // IMPORTANT: Use fixed size here
//                                     painter: SingleLineDiagramPainter(
//                                       bayRenderDataList:
//                                           sldRenderData.bayRenderDataList,
//                                       bayConnections: _allConnections,
//                                       baysMap: _baysMap,
//                                       createDummyBayRenderData:
//                                           _createDummyBayRenderData,
//                                       busbarRects: sldRenderData.busbarRects,
//                                       busbarConnectionPoints:
//                                           sldRenderData.busbarConnectionPoints,
//                                       debugDrawHitboxes: true,
//                                       selectedBayForMovementId: null,
//                                       bayEnergyData:
//                                           sldRenderData.bayEnergyData,
//                                       busEnergySummary:
//                                           sldRenderData.busEnergySummary,
//                                     ),
//                                   ),
//                                 ),
//                               )
//                             : InteractiveViewer(
//                                 // Original, unconstrained InteractiveViewer for normal display
//                                 transformationController:
//                                     _transformationController,
//                                 boundaryMargin: const EdgeInsets.all(
//                                   double.infinity,
//                                 ), // Allow free movement
//                                 minScale: 0.1,
//                                 maxScale: 4.0,
//                                 constrained:
//                                     false, // Not constrained for interactive use
//                                 child: Listener(
//                                   behavior: HitTestBehavior.opaque,
//                                   onPointerDown: (details) {
//                                     if (_isViewingSavedSld) return;

//                                     final RenderBox renderBox =
//                                         context.findRenderObject() as RenderBox;
//                                     final Offset localPosition = renderBox
//                                         .globalToLocal(details.position);
//                                     final scenePosition =
//                                         _transformationController.toScene(
//                                           localPosition,
//                                         );

//                                     // Find all tapped bays and prioritize
//                                     final List<BayRenderData> tappedBays =
//                                         sldRenderData.bayRenderDataList
//                                             .where(
//                                               (data) => data.rect.contains(
//                                                 scenePosition,
//                                               ),
//                                             )
//                                             .toList();

//                                     BayRenderData? selectedTappedBay;
//                                     if (tappedBays.isNotEmpty) {
//                                       tappedBays.sort((a, b) {
//                                         // Prioritize non-busbars
//                                         final bool aIsBusbar =
//                                             a.bay.bayType == 'Busbar';
//                                         final bool bIsBusbar =
//                                             b.bay.bayType == 'Busbar';
//                                         if (!aIsBusbar && bIsBusbar) return -1;
//                                         if (aIsBusbar && !bIsBusbar) return 1;

//                                         // Then sort by smallest area (most precise hit)
//                                         return (a.rect.width * a.rect.height)
//                                             .compareTo(
//                                               b.rect.width * b.rect.height,
//                                             );
//                                       });
//                                       selectedTappedBay = tappedBays.first;
//                                     }

//                                     if (selectedTappedBay != null) {
//                                       _showBaySymbolActions(
//                                         context,
//                                         selectedTappedBay.bay,
//                                         details.position,
//                                       );
//                                     }
//                                   },
//                                   child: CustomPaint(
//                                     size: Size(
//                                       canvasWidth,
//                                       canvasHeight,
//                                     ), // Uses calculated content size
//                                     painter: SingleLineDiagramPainter(
//                                       bayRenderDataList:
//                                           sldRenderData.bayRenderDataList,
//                                       bayConnections: _allConnections,
//                                       baysMap: _baysMap,
//                                       createDummyBayRenderData:
//                                           _createDummyBayRenderData,
//                                       busbarRects: sldRenderData.busbarRects,
//                                       busbarConnectionPoints:
//                                           sldRenderData.busbarConnectionPoints,
//                                       debugDrawHitboxes: true,
//                                       selectedBayForMovementId:
//                                           _selectedBayForMovementId, // Pass selected ID
//                                       bayEnergyData:
//                                           sldRenderData.bayEnergyData,
//                                       busEnergySummary:
//                                           sldRenderData.busEnergySummary,
//                                     ),
//                                   ),
//                                 ),
//                               ),
//                       ),
//                       Align(
//                         alignment: Alignment.bottomRight,
//                         child: Padding(
//                           padding: const EdgeInsets.all(16.0),
//                           child: SizedBox(
//                             width: abstractCardWidth,
//                             height: abstractCardHeight,
//                             child: Card(
//                               elevation: 4,
//                               child: Padding(
//                                 padding: const EdgeInsets.all(12.0),
//                                 child: Column(
//                                   crossAxisAlignment: CrossAxisAlignment.start,
//                                   children: [
//                                     Expanded(
//                                       child: PageView.builder(
//                                         itemCount: busbarsWithData.length + 1,
//                                         onPageChanged: (index) {
//                                           setState(() {
//                                             _currentPageIndex = index;
//                                           });
//                                         },
//                                         itemBuilder: (context, index) {
//                                           if (index == busbarsWithData.length) {
//                                             return Column(
//                                               mainAxisSize: MainAxisSize.min,
//                                               crossAxisAlignment:
//                                                   CrossAxisAlignment.start,
//                                               children: [
//                                                 Text(
//                                                   'Abstract of Substation',
//                                                   style: Theme.of(
//                                                     context,
//                                                   ).textTheme.titleSmall,
//                                                 ),
//                                                 const Divider(),
//                                                 _buildEnergyRow(
//                                                   'Total Import',
//                                                   _abstractEnergyData['totalImp'],
//                                                   'MWH',
//                                                   isAbstract: true,
//                                                 ),
//                                                 _buildEnergyRow(
//                                                   'Total Export',
//                                                   _abstractEnergyData['totalExp'],
//                                                   'MWH',
//                                                   isAbstract: true,
//                                                 ),
//                                                 _buildEnergyRow(
//                                                   'Difference',
//                                                   _abstractEnergyData['difference'],
//                                                   'MWH',
//                                                   isAbstract: true,
//                                                 ),
//                                                 _buildEnergyRow(
//                                                   'Loss Percentage',
//                                                   _abstractEnergyData['lossPercentage'],
//                                                   '%',
//                                                   isAbstract: true,
//                                                 ),
//                                               ],
//                                             );
//                                           } else {
//                                             final busbar =
//                                                 busbarsWithData[index];
//                                             final busSummary =
//                                                 _busEnergySummary[busbar.id];
//                                             return Column(
//                                               crossAxisAlignment:
//                                                   CrossAxisAlignment.start,
//                                               children: [
//                                                 Text(
//                                                   'Abstract of Busbar:',
//                                                   style: Theme.of(
//                                                     context,
//                                                   ).textTheme.titleSmall,
//                                                 ),
//                                                 Text(
//                                                   '${busbar.voltageLevel} ${busbar.name}',
//                                                   style: Theme.of(context)
//                                                       .textTheme
//                                                       .bodyMedium
//                                                       ?.copyWith(
//                                                         fontWeight:
//                                                             FontWeight.bold,
//                                                       ),
//                                                 ),
//                                                 const Divider(),
//                                                 _buildEnergyRow(
//                                                   'Import',
//                                                   busSummary?['totalImp'],
//                                                   'MWH',
//                                                 ),
//                                                 _buildEnergyRow(
//                                                   'Export',
//                                                   busSummary?['totalExp'],
//                                                   'MWH',
//                                                 ),
//                                                 _buildEnergyRow(
//                                                   'Difference',
//                                                   busSummary?['difference'],
//                                                   'MWH',
//                                                 ),
//                                                 _buildEnergyRow(
//                                                   'Loss',
//                                                   busSummary?['lossPercentage'],
//                                                   '%',
//                                                 ),
//                                               ],
//                                             );
//                                           }
//                                         },
//                                       ),
//                                     ),
//                                     _buildPageIndicator(
//                                       busbarsWithData.length + 1,
//                                       _currentPageIndex,
//                                     ),
//                                   ],
//                                 ),
//                               ),
//                             ),
//                           ),
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),
//                 // Movement controls at the bottom
//                 if (_selectedBayForMovementId != null) _buildMovementControls(),
//                 // THIS IS THE CORRECTED SECTION
//                 Visibility(
//                   visible: _showTables,
//                   child: Column(
//                     children: [
//                       // Feeder Energy Table
//                       Container(
//                         height: feederTableHeight,
//                         padding: const EdgeInsets.all(8.0),
//                         child: Column(
//                           children: [
//                             Text(
//                               'Feeder Energy Supplied by Distribution Hierarchy',
//                               style: Theme.of(context).textTheme.titleLarge,
//                             ),
//                             const Divider(),
//                             Expanded(
//                               child: PageView.builder(
//                                 itemCount:
//                                     (_aggregatedFeederEnergyData.length / 5)
//                                         .ceil()
//                                         .toInt() +
//                                     (_aggregatedFeederEnergyData.isEmpty
//                                         ? 1
//                                         : 0),
//                                 onPageChanged: (index) {
//                                   setState(() {
//                                     _feederTablePageIndex = index;
//                                   });
//                                 },
//                                 itemBuilder: (context, pageIndex) {
//                                   if (_aggregatedFeederEnergyData.isEmpty) {
//                                     return const Center(
//                                       child: Text(
//                                         'No aggregated feeder energy data available for this date range.',
//                                       ),
//                                     );
//                                   }
//                                   final int startIndex = pageIndex * 5;
//                                   final int endIndex = (startIndex + 5).clamp(
//                                     0,
//                                     _aggregatedFeederEnergyData.length,
//                                   );
//                                   final List<AggregatedFeederEnergyData>
//                                   currentPageData = _aggregatedFeederEnergyData
//                                       .sublist(startIndex, endIndex);
//                                   return SingleChildScrollView(
//                                     scrollDirection: Axis.horizontal,
//                                     child: DataTable(
//                                       columns: const [
//                                         DataColumn(label: Text('D-Zone')),
//                                         DataColumn(label: Text('D-Circle')),
//                                         DataColumn(label: Text('D-Division')),
//                                         DataColumn(
//                                           label: Text('D-Subdivision'),
//                                         ),
//                                         DataColumn(label: Text('Import (MWH)')),
//                                         DataColumn(label: Text('Export (MWH)')),
//                                       ],
//                                       rows: currentPageData.mapIndexed((
//                                         index,
//                                         data,
//                                       ) {
//                                         final AggregatedFeederEnergyData?
//                                         prevDataOverall =
//                                             (startIndex + index > 0)
//                                             ? _aggregatedFeederEnergyData[startIndex +
//                                                   index -
//                                                   1]
//                                             : null;
//                                         final bool mergeZone =
//                                             (prevDataOverall != null) &&
//                                             data.zoneName ==
//                                                 prevDataOverall.zoneName;
//                                         final bool mergeCircle =
//                                             mergeZone &&
//                                             data.circleName ==
//                                                 prevDataOverall.circleName;
//                                         final bool mergeDivision =
//                                             mergeCircle &&
//                                             data.divisionName ==
//                                                 prevDataOverall.divisionName;
//                                         final bool mergeSubdivision =
//                                             mergeDivision &&
//                                             data.distributionSubdivisionName ==
//                                                 prevDataOverall
//                                                     .distributionSubdivisionName;
//                                         return DataRow(
//                                           cells: [
//                                             DataCell(
//                                               Text(
//                                                 mergeZone ? '' : data.zoneName,
//                                               ),
//                                             ),
//                                             DataCell(
//                                               Text(
//                                                 mergeCircle
//                                                     ? ''
//                                                     : data.circleName,
//                                               ),
//                                             ),
//                                             DataCell(
//                                               Text(
//                                                 mergeDivision
//                                                     ? ''
//                                                     : data.divisionName,
//                                               ),
//                                             ),
//                                             DataCell(
//                                               Text(
//                                                 mergeSubdivision
//                                                     ? ''
//                                                     : data.distributionSubdivisionName,
//                                               ),
//                                             ),
//                                             DataCell(
//                                               Text(
//                                                 data.importedEnergy
//                                                     .toStringAsFixed(2),
//                                               ),
//                                             ),
//                                             DataCell(
//                                               Text(
//                                                 data.exportedEnergy
//                                                     .toStringAsFixed(2),
//                                               ),
//                                             ),
//                                           ],
//                                         );
//                                       }).toList(),
//                                     ),
//                                   );
//                                 },
//                               ),
//                             ),
//                             if (_aggregatedFeederEnergyData.isNotEmpty)
//                               _buildPageIndicator(
//                                 (_aggregatedFeederEnergyData.length / 5)
//                                     .ceil()
//                                     .toInt(),
//                                 _feederTablePageIndex,
//                               ),
//                           ],
//                         ),
//                       ),
//                       // Assessment Table using collection-if
//                       if (_isViewingSavedSld &&
//                           _loadedAssessmentsSummary.isNotEmpty)
//                         Container(
//                           height: assessmentTableHeight,
//                           padding: const EdgeInsets.all(8.0),
//                           child: Column(
//                             crossAxisAlignment: CrossAxisAlignment.start,
//                             children: [
//                               Text(
//                                 'Assessments for this Period:',
//                                 style: Theme.of(context).textTheme.titleLarge,
//                               ),
//                               const Divider(),
//                               Expanded(
//                                 child: SingleChildScrollView(
//                                   scrollDirection: Axis.horizontal,
//                                   child: DataTable(
//                                     columns: const [
//                                       DataColumn(label: Text('Bay Name')),
//                                       DataColumn(label: Text('Import Adj.')),
//                                       DataColumn(label: Text('Export Adj.')),
//                                       DataColumn(label: Text('Reason')),
//                                       DataColumn(label: Text('Timestamp')),
//                                     ],
//                                     rows: _loadedAssessmentsSummary.map((
//                                       assessmentMap,
//                                     ) {
//                                       final Assessment assessment =
//                                           Assessment.fromMap(assessmentMap);
//                                       final String assessedBayName =
//                                           assessmentMap['bayName'] ?? 'N/A';
//                                       return DataRow(
//                                         cells: [
//                                           DataCell(Text(assessedBayName)),
//                                           DataCell(
//                                             Text(
//                                               assessment.importAdjustment !=
//                                                       null
//                                                   ? assessment.importAdjustment!
//                                                         .toStringAsFixed(2)
//                                                   : 'N/A',
//                                             ),
//                                           ),
//                                           DataCell(
//                                             Text(
//                                               assessment.exportAdjustment !=
//                                                       null
//                                                   ? assessment.exportAdjustment!
//                                                         .toStringAsFixed(2)
//                                                   : 'N/A',
//                                             ),
//                                           ),
//                                           DataCell(Text(assessment.reason)),
//                                           DataCell(
//                                             Text(
//                                               DateFormat(
//                                                 'dd-MMM-yyyy HH:mm',
//                                               ).format(
//                                                 assessment.assessmentTimestamp
//                                                     .toDate(),
//                                               ),
//                                             ),
//                                           ),
//                                         ],
//                                       );
//                                     }).toList(),
//                                   ),
//                                 ),
//                               ),
//                             ],
//                           ),
//                         )
//                       else if (_isViewingSavedSld &&
//                           _loadedAssessmentsSummary.isEmpty)
//                         Container(
//                           height: assessmentTableHeight,
//                           alignment: Alignment.center,
//                           child: Text(
//                             'No assessments were made for this period in the saved SLD.',
//                             style: Theme.of(context).textTheme.bodyMedium
//                                 ?.copyWith(fontStyle: FontStyle.italic),
//                             textAlign: TextAlign.center,
//                           ),
//                         )
//                       else if (!_isViewingSavedSld &&
//                           _allAssessmentsForDisplay.isNotEmpty)
//                         Container(
//                           height: 150,
//                           padding: const EdgeInsets.all(8.0),
//                           child: Column(
//                             crossAxisAlignment: CrossAxisAlignment.start,
//                             children: [
//                               Text(
//                                 'Recent Assessment Notes:',
//                                 style: Theme.of(context).textTheme.titleMedium,
//                               ),
//                               const Divider(),
//                               Expanded(
//                                 child: ListView.builder(
//                                   itemCount: _allAssessmentsForDisplay.length,
//                                   itemBuilder: (context, index) {
//                                     final assessment =
//                                         _allAssessmentsForDisplay[index];
//                                     final Bay? assessedBay =
//                                         _baysMap[assessment.bayId];
//                                     return Padding(
//                                       padding: const EdgeInsets.symmetric(
//                                         vertical: 4.0,
//                                       ),
//                                       child: Text(
//                                         '• ${assessedBay?.name ?? 'Unknown Bay'} on ${DateFormat('dd-MMM-yyyy HH:mm').format(assessment.assessmentTimestamp.toDate())}: ${assessment.reason}',
//                                         style: Theme.of(
//                                           context,
//                                         ).textTheme.bodySmall,
//                                       ),
//                                     );
//                                   },
//                                 ),
//                               ),
//                             ],
//                           ),
//                         ),
//                     ],
//                   ),
//                 ),
//               ],
//             ),
//       floatingActionButton: SpeedDial(
//         icon: Icons.menu,
//         activeIcon: Icons.close,
//         backgroundColor: Colors.blue,
//         foregroundColor: Colors.white,
//         overlayColor: Colors.black,
//         overlayOpacity: 0.5,
//         spacing: 12,
//         spaceBetweenChildren: 12,
//         children: [
//           SpeedDialChild(
//             child: const Icon(Icons.save),
//             backgroundColor:
//                 _isViewingSavedSld || _selectedBayForMovementId != null
//                 ? Colors.grey
//                 : Colors.green,
//             label: 'Save SLD',
//             onTap: _isViewingSavedSld || _selectedBayForMovementId != null
//                 ? null
//                 : _saveSld,
//           ),
//           SpeedDialChild(
//             child: const Icon(Icons.print),
//             backgroundColor: Colors.blue,
//             label: 'Print/Share SLD',
//             onTap: _shareCurrentSldAsPdf,
//           ),
//           SpeedDialChild(
//             child: Icon(_showTables ? Icons.visibility_off : Icons.visibility),
//             backgroundColor: Colors.orange,
//             label: _showTables ? 'Hide Tables' : 'Show Tables',
//             onTap: () {
//               setState(() {
//                 _showTables = !_showTables;
//               });
//             },
//           ),
//           SpeedDialChild(
//             child: const Icon(Icons.settings_input_antenna),
//             backgroundColor: Colors.purple,
//             label: 'Configure Busbar Energy',
//             onTap: _isViewingSavedSld || _selectedBayForMovementId != null
//                 ? null
//                 : () => _showBusbarSelectionDialog(),
//           ),
//           SpeedDialChild(
//             child: const Icon(Icons.assessment),
//             backgroundColor: Colors.red,
//             label: 'Add Energy Assessment',
//             onTap: _isViewingSavedSld || _selectedBayForMovementId != null
//                 ? null
//                 : () => _showBaySelectionForAssessment(),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildEnergyRow(
//     String label,
//     double? value,
//     String unit, {
//     bool isAbstract = false,
//   }) {
//     return Padding(
//       padding: const EdgeInsets.symmetric(vertical: 4.0),
//       child: Row(
//         mainAxisAlignment: MainAxisAlignment.spaceBetween,
//         children: [
//           Text(
//             label + ':',
//             style: isAbstract
//                 ? Theme.of(context).textTheme.titleSmall
//                 : Theme.of(context).textTheme.bodySmall,
//           ),
//           Text(
//             value != null ? '${value.toStringAsFixed(2)} $unit' : 'N/A',
//             style: isAbstract
//                 ? Theme.of(
//                     context,
//                   ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)
//                 : Theme.of(
//                     context,
//                   ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold),
//           ),
//         ],
//       ),
//     );
//   }
// }

// /// Dialog for configuring busbar energy contributions (remains unchanged)
// class _BusbarEnergyAssignmentDialog extends StatefulWidget {
//   final Bay busbar;
//   final List<Bay> connectedBays;
//   final AppUser currentUser;
//   final Map<String, BusbarEnergyMap> currentMaps;
//   final Function(BusbarEnergyMap) onSaveMap;
//   final Function(String) onDeleteMap;

//   const _BusbarEnergyAssignmentDialog({
//     required this.busbar,
//     required this.connectedBays,
//     required this.currentUser,
//     required this.currentMaps,
//     required this.onSaveMap,
//     required this.onDeleteMap,
//   });

//   @override
//   __BusbarEnergyAssignmentDialogState createState() =>
//       __BusbarEnergyAssignmentDialogState();
// }

// class __BusbarEnergyAssignmentDialogState
//     extends State<_BusbarEnergyAssignmentDialog> {
//   final Map<String, Map<String, dynamic>> _bayContributionSelections = {};
//   bool _isSaving = false;

//   @override
//   void initState() {
//     super.initState();
//     for (var bay in widget.connectedBays) {
//       final existingMap = widget.currentMaps[bay.id];
//       _bayContributionSelections[bay.id] = {
//         'import':
//             existingMap?.importContribution ?? EnergyContributionType.none,
//         'export':
//             existingMap?.exportContribution ?? EnergyContributionType.none,
//         'originalMapId': existingMap?.id,
//       };
//     }
//   }

//   Future<void> _saveAllContributions() async {
//     setState(() => _isSaving = true);
//     try {
//       for (var bayId in _bayContributionSelections.keys) {
//         final selection = _bayContributionSelections[bayId]!;
//         final originalMapId = selection['originalMapId'] as String?;
//         final importContrib = selection['import'] as EnergyContributionType;
//         final exportContrib = selection['export'] as EnergyContributionType;

//         if (importContrib == EnergyContributionType.none &&
//             exportContrib == EnergyContributionType.none) {
//           if (originalMapId != null) {
//             widget.onDeleteMap(originalMapId);
//           }
//         } else {
//           final newMap = BusbarEnergyMap(
//             id: originalMapId,
//             substationId: widget.busbar.substationId,
//             busbarId: widget.busbar.id,
//             connectedBayId: bayId,
//             importContribution: importContrib,
//             exportContribution: exportContrib,
//             createdBy: originalMapId != null
//                 ? widget.currentUser.uid
//                 : widget.currentUser.uid,
//             createdAt: originalMapId != null
//                 ? Timestamp.now()
//                 : Timestamp.now(),
//             lastModifiedAt: Timestamp.now(),
//           );
//           widget.onSaveMap(newMap);
//         }
//       }
//       if (mounted) {
//         SnackBarUtils.showSnackBar(context, 'Busbar energy assignments saved!');
//         Navigator.of(context).pop();
//       }
//     } catch (e) {
//       if (mounted) {
//         SnackBarUtils.showSnackBar(
//           context,
//           'Failed to save assignments: $e',
//           isError: true,
//         );
//       }
//     } finally {
//       if (mounted) setState(() => _isSaving = false);
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return AlertDialog(
//       title: Text('Assign Energy Flow for ${widget.busbar.name}'),
//       content: SingleChildScrollView(
//         child: Column(
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             Text(
//               'Configure how energy from connected bays contributes to this busbar\'s import/export.',
//             ),
//             const SizedBox(height: 16),
//             if (widget.connectedBays.isEmpty)
//               const Text('No bays connected to this busbar.'),
//             ...widget.connectedBays.map((bay) {
//               final currentSelection = _bayContributionSelections[bay.id]!;
//               return Card(
//                 margin: const EdgeInsets.symmetric(vertical: 8),
//                 child: Padding(
//                   padding: const EdgeInsets.all(12.0),
//                   child: Column(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     children: [
//                       Text(
//                         '${bay.name} (${bay.bayType})',
//                         style: Theme.of(context).textTheme.titleSmall,
//                       ),
//                       const SizedBox(height: 8),
//                       // Import Contribution
//                       DropdownButtonFormField<EnergyContributionType>(
//                         decoration: const InputDecoration(
//                           labelText: 'Bay Import contributes to Busbar:',
//                           border: OutlineInputBorder(),
//                           isDense: true,
//                         ),
//                         value: currentSelection['import'],
//                         items: EnergyContributionType.values.map((type) {
//                           return DropdownMenuItem(
//                             value: type,
//                             child: Text(
//                               type
//                                   .toString()
//                                   .split('.')
//                                   .last
//                                   .replaceAll('bus', 'Bus '),
//                             ),
//                           );
//                         }).toList(),
//                         onChanged: (newValue) {
//                           setState(() {
//                             currentSelection['import'] = newValue;
//                           });
//                         },
//                       ),
//                       const SizedBox(height: 8),
//                       // Export Contribution
//                       DropdownButtonFormField<EnergyContributionType>(
//                         decoration: const InputDecoration(
//                           labelText: 'Bay Export contributes to Busbar:',
//                           border: OutlineInputBorder(),
//                           isDense: true,
//                         ),
//                         value: currentSelection['export'],
//                         items: EnergyContributionType.values.map((type) {
//                           return DropdownMenuItem(
//                             value: type,
//                             child: Text(
//                               type
//                                   .toString()
//                                   .split('.')
//                                   .last
//                                   .replaceAll('bus', 'Bus '),
//                             ),
//                           );
//                         }).toList(),
//                         onChanged: (newValue) {
//                           setState(() {
//                             currentSelection['export'] = newValue;
//                           });
//                         },
//                       ),
//                     ],
//                   ),
//                 ),
//               );
//             }).toList(),
//           ],
//         ),
//       ),
//       actions: [
//         TextButton(
//           onPressed: () => Navigator.of(context).pop(),
//           child: const Text('Cancel'),
//         ),
//         ElevatedButton(
//           onPressed: _isSaving ? null : _saveAllContributions,
//           child: _isSaving
//               ? const CircularProgressIndicator(strokeWidth: 2)
//               : const Text('Save Assignments'),
//         ),
//       ],
//     );
//   }
// }

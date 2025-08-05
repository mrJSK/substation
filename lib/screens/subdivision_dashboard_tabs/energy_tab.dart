// lib/screens/subdivision_dashboard_tabs/energy_tab.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:math'; // For min/max
import 'package:collection/collection.dart'; // For firstWhereOrNull

import '../../models/logsheet_models.dart';
import '../../models/user_model.dart';
import '../../models/bay_model.dart';
import '../../models/hierarchy_models.dart'; // For Substation model and HierarchyItem
import '../../models/user_readings_config_model.dart'; // Not directly used for dates now, but kept
import '../../utils/snackbar_utils.dart';
import '../../models/app_state_data.dart';
import '../../models/energy_readings_data.dart'; // For BayEnergyData and AggregatedFeederEnergyData
import '../../models/busbar_energy_map.dart'; // For BusbarEnergyMap
import '../../models/assessment_model.dart'; // For Assessment
import '../../models/substation_sld_layout_model.dart'; // NEW: Import SubstationSldLayout

// Transformer Readings Chart Widget (unchanged from previous version)
class TransformerReadingsChart extends StatelessWidget {
  final List<LogsheetEntry> readings;
  final String fieldName;
  final String unit;

  const TransformerReadingsChart({
    Key? key,
    required this.readings,
    required this.fieldName,
    required this.unit,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    List<FlSpot> spots = [];
    Map<double, DateTime> timeMap = {};

    for (var entry in readings) {
      final value = entry.values[fieldName];
      if (value != null && double.tryParse(value.toString()) != null) {
        final timestamp = entry.readingTimestamp.toDate();
        final timeInMilliseconds = timestamp.millisecondsSinceEpoch.toDouble();
        spots.add(FlSpot(timeInMilliseconds, double.parse(value.toString())));
        timeMap[timeInMilliseconds] = timestamp;
      }
    }

    if (spots.isEmpty) {
      return Center(
        child: Text('No $fieldName data available for the selected period.'),
      );
    }

    spots.sort((a, b) => a.x.compareTo(b.x));

    double minX = spots.first.x;
    double maxX = spots.last.x;
    double minY = spots.map((spot) => spot.y).reduce(min);
    double maxY = spots.map((spot) => spot.y).reduce(max);

    minY = minY * 0.9;
    maxY = maxY * 1.1;

    return Container(
      height: 250,
      padding: const EdgeInsets.all(16.0),
      child: LineChart(
        LineChartData(
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: Theme.of(context).colorScheme.primary,
              dotData: FlDotData(show: true),
              belowBarData: BarAreaData(
                show: true,
                color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
              ),
            ),
          ],
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  final date = timeMap[value];
                  if (date == null) return const Text('');
                  return Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      DateFormat('HH:mm').format(date),
                      style: const TextStyle(fontSize: 10),
                    ),
                  );
                },
                interval: (maxX - minX) / 4,
                reservedSize: 30,
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                getTitlesWidget: (value, meta) {
                  return Text(
                    '${value.toStringAsFixed(0)} $unit',
                    style: const TextStyle(fontSize: 10),
                  );
                },
              ),
            ),
            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          minX: minX,
          maxX: maxX,
          minY: minY,
          maxY: maxY,
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipItems: (touchedSpots) {
                return touchedSpots.map((spot) {
                  final date = timeMap[spot.x];
                  return LineTooltipItem(
                    '${fieldName}: ${spot.y.toStringAsFixed(2)} $unit\n${date != null ? DateFormat('yyyy-MM-dd HH:mm').format(date) : ''}',
                    const TextStyle(color: Colors.white),
                  );
                }).toList();
              },
            ),
            handleBuiltInTouches: true,
          ),
          borderData: FlBorderData(show: true),
        ),
      ),
    );
  }
}

class EnergyTab extends StatefulWidget {
  final AppUser currentUser;
  final String? initialSelectedSubstationId;

  const EnergyTab({
    Key? key,
    required this.currentUser,
    this.initialSelectedSubstationId,
    required DateTime startDate,
    required DateTime endDate,
    required String substationId,
  }) : super(key: key);

  @override
  _EnergyTabState createState() => _EnergyTabState();
}

class _EnergyTabState extends State<EnergyTab> {
  bool _isLoading = true;
  String? _errorMessage;

  Substation? _selectedSubstation; // Substation selected via dropdown
  List<Substation> _allSubstations = []; // To populate substation dropdown

  List<LogsheetEntry> _allLogsheetEntries = []; // All fetched logsheet entries
  List<BayEnergyData> _computedBayEnergyData =
      []; // List to store computed data for table
  Map<String, Bay> _baysMap = {}; // Map of all bays in selected substation

  DateTime _startDate = DateTime.now().subtract(const Duration(days: 7));
  DateTime _endDate = DateTime.now();

  // Energy Calculation Results (populated by _fetchEnergyData)
  Map<String, Map<String, double>> _busEnergySummary = {};
  Map<String, dynamic> _abstractEnergyData = {};

  // Hierarchy maps for lookup - needed for abstract table
  Map<String, Zone> _zonesMap = {};
  Map<String, Circle> _circlesMap = {};
  Map<String, Division> _divisionsMap = {};
  Map<String, Subdivision> _subdivisionsMap = {};
  Map<String, Substation> _substationsMap = {};
  Map<String, DistributionZone> _distributionZonesMap = {};
  Map<String, DistributionCircle> _distributionCirclesMap = {};
  Map<String, DistributionDivision> _distributionDivisionsMap = {};
  Map<String, DistributionSubdivision> _distributionSubdivisionsMap = {};
  Map<String, BusbarEnergyMap> _busbarEnergyMaps = {};
  Map<String, Assessment> _latestAssessmentsPerBay = {};

  // NEW: State to check SLD configuration completeness
  bool _isSldCreated = false;

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  // Helper to parse voltage level values for sorting (e.g., "132kV" -> 132)
  int _parseVoltageLevel(String? voltageLevel) {
    if (voltageLevel == null || voltageLevel.isEmpty) return 0;
    final regex = RegExp(r'(\d+)kV'); // Assumes format like "132kV"
    final match = regex.firstMatch(voltageLevel);
    if (match != null && match.groupCount > 0) {
      return int.tryParse(match.group(1)!) ?? 0;
    }
    return 0;
  }

  Future<void> _initializeData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    print('DEBUG: _initializeData called.'); // Debug log
    try {
      final appState = Provider.of<AppStateData>(context, listen: false);
      final subdivisionId =
          appState.currentUser?.assignedLevels?['subdivisionId'];
      print('DEBUG: Current User Subdivision ID: $subdivisionId'); // Debug log

      if (subdivisionId == null) {
        print(
          'DEBUG: Subdivision ID is null, throwing exception.',
        ); // Debug log
        throw Exception('Subdivision ID not found for current user.');
      }

      final substationsSnapshot = await FirebaseFirestore.instance
          .collection('substations')
          .where('subdivisionId', isEqualTo: subdivisionId)
          .orderBy('name')
          .get();

      _allSubstations = substationsSnapshot.docs
          .map((doc) => Substation.fromFirestore(doc))
          .toList();
      print(
        'DEBUG: Fetched ${_allSubstations.length} substations.',
      ); // Debug log

      if (widget.initialSelectedSubstationId != null &&
          _allSubstations.any(
            (s) => s.id == widget.initialSelectedSubstationId,
          )) {
        _selectedSubstation = _allSubstations.firstWhere(
          (s) => s.id == widget.initialSelectedSubstationId,
        );
        print(
          'DEBUG: Initial selected substation: ${_selectedSubstation?.name} (${_selectedSubstation?.id})',
        ); // Debug log
      } else if (_allSubstations.isNotEmpty) {
        _selectedSubstation = _allSubstations.first;
        print(
          'DEBUG: No initial substation, selected first: ${_selectedSubstation?.name} (${_selectedSubstation?.id})',
        ); // Debug log
      } else {
        print(
          'DEBUG: No substations found for current subdivision.',
        ); // Debug log
      }

      // Fetch all necessary hierarchy data for the abstract table
      await _fetchTransmissionHierarchyData();
      await _fetchDistributionHierarchyData();

      // NEW: Check SLD existence and fetch energy data conditionally
      await _checkSldExistenceAndFetchEnergyData();
    } catch (e) {
      print('Error initializing energy tab data: $e');
      if (mounted) {
        SnackBarUtils.showSnackBar(
          context,
          'Error initializing energy data: $e',
          isError: true,
        );
        setState(() => _isLoading = false);
      }
    }
  }

  // NEW: Method to check SLD existence and then fetch energy data
  Future<void> _checkSldExistenceAndFetchEnergyData() async {
    print('DEBUG: _checkSldExistenceAndFetchEnergyData called.'); // Debug log
    if (_selectedSubstation == null) {
      print(
        'DEBUG: _selectedSubstation is null. Setting _isSldCreated to false.',
      ); // Debug log
      setState(() {
        _isSldCreated = false; // No substation selected, so no SLD
        _isLoading = false; // Stop loading for initial state
      });
      return;
    }

    print(
      'DEBUG: Checking SLD for substation ID: ${_selectedSubstation!.id}',
    ); // Debug log
    final sldLayoutDoc = await FirebaseFirestore.instance
        .collection(
          'substationSldLayouts',
        ) // Assuming this collection stores SLD layouts
        .doc(_selectedSubstation!.id)
        .get();
    print('DEBUG: sldLayoutDoc exists: ${sldLayoutDoc.exists}'); // Debug log

    final busbarEnergyMapsSnapshot = await FirebaseFirestore.instance
        .collection('busbarEnergyMaps')
        .where('substationId', isEqualTo: _selectedSubstation!.id)
        .limit(1) // Just check if any exist
        .get();
    print(
      'DEBUG: busbarEnergyMapsSnapshot is not empty: ${busbarEnergyMapsSnapshot.docs.isNotEmpty}',
    ); // Debug log
    print(
      'DEBUG: Number of busbar energy map docs found (first 1 checked): ${busbarEnergyMapsSnapshot.docs.length}',
    ); // Debug log

    setState(() {
      // SLD is considered "complete" if the layout document exists AND at least one busbar energy map exists
      _isSldCreated =
          sldLayoutDoc.exists && busbarEnergyMapsSnapshot.docs.isNotEmpty;
      print('DEBUG: Final _isSldCreated status: $_isSldCreated'); // Debug log
    });

    if (_isSldCreated) {
      print('DEBUG: SLD is created. Calling _fetchEnergyData.'); // Debug log
      await _fetchEnergyData(); // Only fetch detailed data if SLD is configured
    } else {
      print(
        'DEBUG: SLD is NOT created or busbar energy maps missing. Clearing energy data.',
      ); // Debug log
      // If SLD is not configured/complete, clear all energy data and stop loading
      setState(() {
        _isLoading = false;
        _errorMessage = null; // Clear any previous error messages
        _allLogsheetEntries.clear();
        _baysMap.clear();
        _computedBayEnergyData.clear();
        _busEnergySummary.clear();
        _abstractEnergyData.clear();
        _busbarEnergyMaps.clear();
        _latestAssessmentsPerBay.clear();
      });
    }
  }

  Future<void> _fetchTransmissionHierarchyData() async {
    print('DEBUG: _fetchTransmissionHierarchyData called.'); // Debug log
    if (_zonesMap.isEmpty) {
      final zonesSnapshot = await FirebaseFirestore.instance
          .collection('zones')
          .get();
      _zonesMap = {
        for (var doc in zonesSnapshot.docs) doc.id: Zone.fromFirestore(doc),
      };
      print('DEBUG: Fetched ${zonesSnapshot.docs.length} zones.'); // Debug log
    }
    if (_circlesMap.isEmpty) {
      final circlesSnapshot = await FirebaseFirestore.instance
          .collection('circles')
          .get();
      _circlesMap = {
        for (var doc in circlesSnapshot.docs) doc.id: Circle.fromFirestore(doc),
      };
      print(
        'DEBUG: Fetched ${circlesSnapshot.docs.length} circles.',
      ); // Debug log
    }
    if (_divisionsMap.isEmpty) {
      final divisionsSnapshot = await FirebaseFirestore.instance
          .collection('divisions')
          .get();
      _divisionsMap = {
        for (var doc in divisionsSnapshot.docs)
          doc.id: Division.fromFirestore(doc),
      };
      print(
        'DEBUG: Fetched ${divisionsSnapshot.docs.length} divisions.',
      ); // Debug log
    }
    if (_subdivisionsMap.isEmpty) {
      final subdivisionsSnapshot = await FirebaseFirestore.instance
          .collection('subdivisions')
          .get();
      _subdivisionsMap = {
        for (var doc in subdivisionsSnapshot.docs)
          doc.id: Subdivision.fromFirestore(doc),
      };
      print(
        'DEBUG: Fetched ${subdivisionsSnapshot.docs.length} subdivisions.',
      ); // Debug log
    }
    _substationsMap = {for (var s in _allSubstations) s.id: s};
    print(
      'DEBUG: Populated _substationsMap with ${_substationsMap.length} entries.',
    ); // Debug log
  }

  Future<void> _fetchDistributionHierarchyData() async {
    print('DEBUG: _fetchDistributionHierarchyData called.'); // Debug log
    if (_distributionZonesMap.isEmpty) {
      final zonesSnapshot = await FirebaseFirestore.instance
          .collection('distributionZones')
          .get();
      _distributionZonesMap = {
        for (var doc in zonesSnapshot.docs)
          doc.id: DistributionZone.fromFirestore(doc),
      };
      print(
        'DEBUG: Fetched ${zonesSnapshot.docs.length} distribution zones.',
      ); // Debug log
    }
    if (_distributionCirclesMap.isEmpty) {
      final circlesSnapshot = await FirebaseFirestore.instance
          .collection('distributionCircles')
          .get();
      _distributionCirclesMap = {
        for (var doc in circlesSnapshot.docs)
          doc.id: DistributionCircle.fromFirestore(doc),
      };
      print(
        'DEBUG: Fetched ${circlesSnapshot.docs.length} distribution circles.',
      ); // Debug log
    }
    if (_distributionDivisionsMap.isEmpty) {
      final divisionsSnapshot = await FirebaseFirestore.instance
          .collection('distributionDivisions')
          .get();
      _distributionDivisionsMap = {
        for (var doc in divisionsSnapshot.docs)
          doc.id: DistributionDivision.fromFirestore(doc),
      };
      print(
        'DEBUG: Fetched ${divisionsSnapshot.docs.length} distribution divisions.',
      ); // Debug log
    }
    if (_distributionSubdivisionsMap.isEmpty) {
      final subdivisionsSnapshot = await FirebaseFirestore.instance
          .collection('distributionSubdivisions')
          .get();
      _distributionSubdivisionsMap = {
        for (var doc in subdivisionsSnapshot.docs)
          doc.id: DistributionSubdivision.fromFirestore(doc),
      };
      print(
        'DEBUG: Fetched ${subdivisionsSnapshot.docs.length} distribution subdivisions.',
      ); // Debug log
    }
  }

  Future<void> _fetchEnergyData() async {
    if (!mounted) return;
    setState(() {
      _isLoading =
          true; // Set loading to true while fetching data after SLD check
      _errorMessage = null;
      _allLogsheetEntries.clear();
      _baysMap.clear();
      _computedBayEnergyData.clear();
      _busEnergySummary.clear();
      _abstractEnergyData.clear();
      _busbarEnergyMaps.clear();
      _latestAssessmentsPerBay.clear();
    });
    print(
      'DEBUG: _fetchEnergyData called for substation ID: ${_selectedSubstation?.id}',
    ); // Debug log

    try {
      // This check is already done by _checkSldExistenceAndFetchEnergyData.
      // If we reach here, it means _selectedSubstation is not null and SLD is created.

      // 1. Fetch all bays for the selected substation
      List<Bay> fetchedBays = [];
      final baysSnapshot = await FirebaseFirestore.instance
          .collection('bays')
          .where('substationId', isEqualTo: _selectedSubstation!.id)
          .get();
      fetchedBays.addAll(
        baysSnapshot.docs.map((doc) => Bay.fromFirestore(doc)).toList(),
      );
      print(
        'DEBUG: Fetched ${fetchedBays.length} bays for substation.',
      ); // Debug log

      // Separate busbars for summary calculations and sort non-busbars for main table
      final List<Bay> nonBusbarBays = fetchedBays
          .where((bay) => bay.bayType != 'Busbar')
          .toList();
      final List<Bay> busbarBays = fetchedBays
          .where((bay) => bay.bayType == 'Busbar')
          .toList();
      print(
        'DEBUG: Found ${nonBusbarBays.length} non-busbar bays and ${busbarBays.length} busbar bays.',
      ); // Debug log

      // Sort non-busbar bays by voltage level (highest to lowest) then by name
      nonBusbarBays.sort((a, b) {
        final voltageA = _parseVoltageLevel(a.voltageLevel);
        final voltageB = _parseVoltageLevel(b.voltageLevel);
        if (voltageA != voltageB) {
          return voltageB.compareTo(voltageA); // Descending voltage
        }
        return a.name.compareTo(b.name); // Ascending name
      });
      // Sort busbar bays by voltage as well for abstract table headers
      busbarBays.sort((a, b) {
        final voltageA = _parseVoltageLevel(a.voltageLevel);
        final voltageB = _parseVoltageLevel(b.voltageLevel);
        return voltageB.compareTo(voltageA);
      });

      _baysMap = {
        for (var bay in fetchedBays) bay.id: bay,
      }; // Map includes all bays (busbars too)

      final List<String> allBayIds = fetchedBays
          .map((bay) => bay.id)
          .toList(); // Use all bays for logsheet fetching
      print(
        'DEBUG: Total bay IDs for logsheet fetching: ${allBayIds.length}',
      ); // Debug log

      if (allBayIds.isNotEmpty) {
        final queryStartTime = Timestamp.fromDate(_startDate);
        final queryEndTime = Timestamp.fromDate(
          _endDate
              .add(const Duration(days: 1))
              .subtract(const Duration(seconds: 1)),
        );
        print(
          'DEBUG: Fetching logsheet entries from $_startDate to $_endDate.',
        ); // Debug log

        // Fetch Logsheet Entries
        List<LogsheetEntry> fetchedLogsheetEntries = [];
        for (int i = 0; i < allBayIds.length; i += 10) {
          final chunk = allBayIds.sublist(
            i,
            i + 10 > allBayIds.length ? allBayIds.length : i + 10,
          );
          if (chunk.isEmpty) continue;

          final readingsSnapshot = await FirebaseFirestore.instance
              .collection('logsheetEntries')
              .where('bayId', whereIn: chunk)
              .where(
                'frequency',
                isEqualTo: 'hourly',
              ) // Assuming hourly entries for charts/table
              .where('readingTimestamp', isGreaterThanOrEqualTo: queryStartTime)
              .where('readingTimestamp', isLessThanOrEqualTo: queryEndTime)
              .get();
          fetchedLogsheetEntries.addAll(
            readingsSnapshot.docs
                .map((doc) => LogsheetEntry.fromFirestore(doc))
                .toList(),
          );
        }
        _allLogsheetEntries = fetchedLogsheetEntries; // Store all raw entries
        print(
          'DEBUG: Fetched ${_allLogsheetEntries.length} logsheet entries.',
        ); // Debug log

        // Fetch Busbar Energy Maps (for abstract table calculation)
        final fullBusbarEnergyMapsSnapshot = await FirebaseFirestore.instance
            .collection('busbarEnergyMaps')
            .where('substationId', isEqualTo: _selectedSubstation!.id)
            .get();
        _busbarEnergyMaps = {
          for (var doc in fullBusbarEnergyMapsSnapshot.docs)
            '${doc['busbarId']}-${doc['connectedBayId']}': // Compound key if needed, or just doc.id
            BusbarEnergyMap.fromFirestore(
              doc,
            ),
        };
        print(
          'DEBUG: Fetched ${_busbarEnergyMaps.length} busbar energy maps.',
        ); // Debug log

        // Fetch Assessments (for abstract table calculation)
        final assessmentsRawSnapshot = await FirebaseFirestore.instance
            .collection('assessments')
            .where('substationId', isEqualTo: _selectedSubstation!.id)
            .where(
              'assessmentTimestamp',
              isGreaterThanOrEqualTo: Timestamp.fromDate(_startDate),
            )
            .where(
              'assessmentTimestamp',
              isLessThanOrEqualTo: Timestamp.fromDate(_endDate),
            )
            .orderBy('assessmentTimestamp', descending: true)
            .get();

        _latestAssessmentsPerBay.clear();
        for (var doc in assessmentsRawSnapshot.docs) {
          final assessment = Assessment.fromFirestore(doc);
          if (!_latestAssessmentsPerBay.containsKey(assessment.bayId)) {
            _latestAssessmentsPerBay[assessment.bayId] =
                assessment; // Only keep the latest
          }
        }
        print(
          'DEBUG: Fetched ${_latestAssessmentsPerBay.length} latest assessments per bay.',
        ); // Debug log

        // --- Compute Bay Energy Data for the main table ---
        print(
          'DEBUG: Computing Bay Energy Data for ${nonBusbarBays.length} non-busbar bays.',
        ); // Debug log
        _computeBayEnergyData(nonBusbarBays); // Pass only non-busbar bays
        print(
          'DEBUG: Computed Bay Energy Data for ${_computedBayEnergyData.length} entries.',
        ); // Debug log

        // --- Compute Abstract Data (Busbar Summary and Substation Abstract) ---
        print(
          'DEBUG: Computing Abstract Energy Data for ${busbarBays.length} busbar bays.',
        ); // Debug log
        _computeAbstractEnergyData(busbarBays); // Pass busbar bays for summary
        print('DEBUG: Bus Energy Summary: $_busEnergySummary'); // Debug log
        print('DEBUG: Abstract Energy Data: $_abstractEnergyData'); // Debug log
      } else {
        print(
          'DEBUG: No bays found for selected substation, skipping logsheet fetching and energy computation.',
        ); // Debug log
      }

      if (!mounted) return;
      setState(() => _isLoading = false);
      print(
        'DEBUG: _fetchEnergyData completed. _isLoading set to false.',
      ); // Debug log
    } catch (e) {
      print('Error loading energy data: $e');
      if (mounted) {
        SnackBarUtils.showSnackBar(
          context,
          'Error loading energy data: $e',
          isError: true,
        );
      }
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // NEW: Method to compute energy data for each bay to be displayed in the main table
  void _computeBayEnergyData(List<Bay> baysToCompute) {
    _computedBayEnergyData.clear();
    print(
      'DEBUG: _computeBayEnergyData started. Bays to compute: ${baysToCompute.length}',
    ); // Debug log

    for (var bay in baysToCompute) {
      final bayEntries = _allLogsheetEntries
          .where((entry) => entry.bayId == bay.id)
          .toList();
      print(
        'DEBUG: Bay: ${bay.name} (${bay.id}), found ${bayEntries.length} logsheet entries.',
      ); // Debug log

      // Sort entries for this bay to easily find first and last readings
      bayEntries.sort(
        (a, b) => a.readingTimestamp.compareTo(b.readingTimestamp),
      );

      // Find the earliest valid reading for "Previous Reading IMP/EXP"
      final LogsheetEntry? firstEntry = bayEntries.firstWhereOrNull(
        (entry) =>
            entry.values.containsKey('Energy_Import_Present') ||
            entry.values.containsKey('Energy_Export_Present'),
      );
      // Find the latest valid reading for "Present Reading IMP/EXP"
      final LogsheetEntry? lastEntry = bayEntries.lastWhereOrNull(
        (entry) =>
            entry.values.containsKey('Energy_Import_Present') ||
            entry.values.containsKey('Energy_Export_Present'),
      );
      print(
        'DEBUG: Bay ${bay.name}: First entry timestamp: ${firstEntry?.readingTimestamp.toDate()}, Last entry timestamp: ${lastEntry?.readingTimestamp.toDate()}',
      ); // Debug log

      double? currentImp = double.tryParse(
        lastEntry?.values['Energy_Import_Present']?.toString() ?? '',
      );
      double? previousImp = double.tryParse(
        firstEntry?.values['Energy_Import_Present']?.toString() ?? '',
      );
      double? currentExp = double.tryParse(
        lastEntry?.values['Energy_Export_Present']?.toString() ?? '',
      );
      double? previousExp = double.tryParse(
        firstEntry?.values['Energy_Export_Present']?.toString() ?? '',
      );
      double? mfEnergy =
          bay.multiplyingFactor; // Multiplying Factor from Bay model
      print(
        'DEBUG: Bay ${bay.name}: currImp=$currentImp, prevImp=$previousImp, currExp=$currentExp, prevExp=$previousExp, MF=$mfEnergy',
      ); // Debug log

      double? computedImport;
      if (currentImp != null && previousImp != null && mfEnergy != null) {
        computedImport = max(0.0, (currentImp - previousImp) * mfEnergy);
      }

      double? computedExport;
      if (currentExp != null && previousExp != null && mfEnergy != null) {
        computedExport = max(0.0, (currentExp - previousExp) * mfEnergy);
      }
      print(
        'DEBUG: Bay ${bay.name}: Computed IMP=$computedImport, Computed EXP=$computedExport',
      ); // Debug log

      // Check for assessment
      final latestAssessment = _latestAssessmentsPerBay[bay.id];
      bool hasAssessment = latestAssessment != null;
      print(
        'DEBUG: Bay ${bay.name}: Has assessment: $hasAssessment',
      ); // Debug log

      BayEnergyData bayEnergy = BayEnergyData(
        bayName: bay.name,
        bayId: bay.id, // Pass bayId
        prevImp: previousImp,
        currImp: currentImp,
        prevExp: previousExp,
        currExp: currentExp,
        mf: mfEnergy,
        impConsumed: computedImport,
        expConsumed: computedExport,
        hasAssessment: hasAssessment,
        bay: bay, // Pass the full Bay object
      );

      // Apply assessment if available
      if (latestAssessment != null) {
        print(
          'DEBUG: Bay ${bay.name}: Applying assessment: impAdj=${latestAssessment.importAdjustment}, expAdj=${latestAssessment.exportAdjustment}',
        ); // Debug log
        bayEnergy = bayEnergy.applyAssessment(
          importAdjustment: latestAssessment.importAdjustment,
          exportAdjustment: latestAssessment.exportAdjustment,
        );
        print(
          'DEBUG: Bay ${bay.name}: Energy after assessment: impConsumed=${bayEnergy.impConsumed}, expConsumed=${bayEnergy.expConsumed}',
        ); // Debug log
      }

      _computedBayEnergyData.add(bayEnergy);
    }
    print('DEBUG: _computeBayEnergyData completed.'); // Debug log
  }

  // NEW: Method to compute the abstract energy data (Busbar Summary and Substation Abstract)
  void _computeAbstractEnergyData(List<Bay> busbarBays) {
    _busEnergySummary.clear();
    _abstractEnergyData.clear();
    print(
      'DEBUG: _computeAbstractEnergyData started. Busbar bays to process: ${busbarBays.length}',
    ); // Debug log

    Map<String, Map<String, double>> temporaryBusFlows = {};
    for (var busbar in busbarBays) {
      temporaryBusFlows[busbar.id] = {'import': 0.0, 'export': 0.0};
      print(
        'DEBUG: Initializing temporaryBusFlows for busbar: ${busbar.name} (${busbar.id})',
      ); // Debug log
    }

    // Iterate through busbar energy maps to consolidate flows
    for (var entry in _busbarEnergyMaps.values) {
      final Bay? connectedBay =
          _baysMap[entry.connectedBayId]; // Use _baysMap that contains all bays
      final BayEnergyData? connectedBayEnergy = _computedBayEnergyData
          .firstWhereOrNull((data) => data.bay == entry.connectedBayId);

      print(
        'DEBUG: Processing BusbarEnergyMap entry: busbarId=${entry.busbarId}, connectedBayId=${entry.connectedBayId}',
      ); // Debug log
      print(
        'DEBUG: connectedBay found: ${connectedBay != null}, connectedBayEnergy found: ${connectedBayEnergy != null}',
      ); // Debug log

      if (connectedBay != null &&
          connectedBayEnergy != null &&
          temporaryBusFlows.containsKey(entry.busbarId)) {
        if (entry.importContribution == EnergyContributionType.busImport) {
          temporaryBusFlows[entry.busbarId]!['import'] =
              (temporaryBusFlows[entry.busbarId]!['import'] ?? 0.0) +
              (connectedBayEnergy.impConsumed ?? 0.0);
          print(
            'DEBUG: Added ${connectedBayEnergy.impConsumed ?? 0.0} to ${entry.busbarId} import (via impConsumed)',
          ); // Debug log
        } else if (entry.importContribution ==
            EnergyContributionType.busExport) {
          temporaryBusFlows[entry.busbarId]!['export'] =
              (temporaryBusFlows[entry.busbarId]!['export'] ?? 0.0) +
              (connectedBayEnergy.impConsumed ?? 0.0);
          print(
            'DEBUG: Added ${connectedBayEnergy.impConsumed ?? 0.0} to ${entry.busbarId} export (via impConsumed)',
          ); // Debug log
        }

        if (entry.exportContribution == EnergyContributionType.busImport) {
          temporaryBusFlows[entry.busbarId]!['import'] =
              (temporaryBusFlows[entry.busbarId]!['import'] ?? 0.0) +
              (connectedBayEnergy.expConsumed ?? 0.0);
          print(
            'DEBUG: Added ${connectedBayEnergy.expConsumed ?? 0.0} to ${entry.busbarId} import (via expConsumed)',
          ); // Debug log
        } else if (entry.exportContribution ==
            EnergyContributionType.busExport) {
          temporaryBusFlows[entry.busbarId]!['export'] =
              (temporaryBusFlows[entry.busbarId]!['export'] ?? 0.0) +
              (connectedBayEnergy.expConsumed ?? 0.0);
          print(
            'DEBUG: Added ${connectedBayEnergy.expConsumed ?? 0.0} to ${entry.busbarId} export (via expConsumed)',
          ); // Debug log
        }
      }
    }
    print('DEBUG: Temporary bus flows: $temporaryBusFlows'); // Debug log

    Map<String, Map<String, double>> calculatedBusEnergySummary = {};
    for (var busbar in busbarBays) {
      // Iterate only through busbar bays
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
        'DEBUG: Busbar Summary for ${busbar.name} (${busbar.id}): $calculatedBusEnergySummary',
      ); // Debug log
    }
    _busEnergySummary = calculatedBusEnergySummary;

    // Calculate overall substation abstract
    double currentAbstractSubstationTotalImp = 0;
    double currentAbstractSubstationTotalExp = 0;

    // Find the highest and lowest voltage busbars for abstract calculation
    final List<Bay> sortedBusbarsByVoltage = busbarBays
      ..sort(
        (a, b) => _parseVoltageLevel(
          b.voltageLevel,
        ).compareTo(_parseVoltageLevel(a.voltageLevel)),
      );

    print(
      'DEBUG: Sorted Busbars by Voltage: ${sortedBusbarsByVoltage.map((b) => b.name).toList()}',
    ); // Debug log

    final Bay? highestVoltageBus = sortedBusbarsByVoltage.firstWhereOrNull(
      (b) => true,
    );
    final Bay? lowestVoltageBus = sortedBusbarsByVoltage.lastWhereOrNull(
      (b) => true,
    );
    print(
      'DEBUG: Highest Voltage Bus: ${highestVoltageBus?.name} (${highestVoltageBus?.id})',
    ); // Debug log
    print(
      'DEBUG: Lowest Voltage Bus: ${lowestVoltageBus?.name} (${lowestVoltageBus?.id})',
    ); // Debug log

    if (highestVoltageBus != null) {
      currentAbstractSubstationTotalImp =
          (calculatedBusEnergySummary[highestVoltageBus.id]?['totalImp']) ??
          0.0;
    }
    if (lowestVoltageBus != null) {
      currentAbstractSubstationTotalExp =
          (calculatedBusEnergySummary[lowestVoltageBus.id]?['totalExp']) ?? 0.0;
    }
    print(
      'DEBUG: Substation Abstract: Total Import from Highest Voltage Bus: $currentAbstractSubstationTotalImp',
    ); // Debug log
    print(
      'DEBUG: Substation Abstract: Total Export from Lowest Voltage Bus: $currentAbstractSubstationTotalExp',
    ); // Debug log

    double overallDifference =
        currentAbstractSubstationTotalImp - currentAbstractSubstationTotalExp;
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
    print(
      'DEBUG: Final _abstractEnergyData: $_abstractEnergyData',
    ); // Debug log
    print('DEBUG: _computeAbstractEnergyData completed.'); // Debug log
  }

  // Date picker method
  Future<void> _selectDate(BuildContext context, bool isStartDate) async {
    print('DEBUG: _selectDate called. isStartDate: $isStartDate'); // Debug log
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isStartDate ? _startDate : _endDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      if (!mounted) return;
      setState(() {
        if (isStartDate) {
          _startDate = picked;
          if (_startDate.isAfter(_endDate)) {
            _endDate = _startDate; // Ensure end date is not before start date
          }
          print('DEBUG: Start date updated to: $_startDate'); // Debug log
        } else {
          _endDate = picked;
          if (_endDate.isBefore(_startDate)) {
            _startDate = _endDate; // Ensure start date is not after end date
          }
          print('DEBUG: End date updated to: $_endDate'); // Debug log
        }
      });
      _fetchEnergyData(); // Re-fetch data with new date range
      print(
        'DEBUG: Re-fetching energy data after date selection.',
      ); // Debug log
    }
  }

  @override
  Widget build(BuildContext context) {
    print(
      'DEBUG: EnergyTab build method called. _isLoading: $_isLoading, _isSldCreated: $_isSldCreated',
    ); // Debug log
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_selectedSubstation == null) {
      print(
        'DEBUG: _selectedSubstation is null in build. Displaying "Select Substation" message.',
      ); // Debug log
      return const Center(
        child: Text('Please select a substation to view energy data.'),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Substation Dropdown
              DropdownButtonFormField<Substation>(
                decoration: const InputDecoration(
                  labelText: 'Select Substation',
                  border: OutlineInputBorder(),
                ),
                value: _selectedSubstation,
                items: _allSubstations.map((substation) {
                  return DropdownMenuItem<Substation>(
                    value: substation,
                    child: Text(substation.name),
                  );
                }).toList(),
                onChanged: (Substation? newValue) {
                  print(
                    'DEBUG: Substation dropdown changed to: ${newValue?.name} (${newValue?.id})',
                  ); // Debug log
                  setState(() {
                    _selectedSubstation = newValue;
                    _checkSldExistenceAndFetchEnergyData(); // NEW: Re-check SLD and fetch data for new substation
                  });
                },
                isExpanded: true,
                hint: const Text('No substation selected'),
              ),
              const SizedBox(height: 16),
              // Date Range Pickers
              Row(
                children: [
                  Expanded(
                    child: ListTile(
                      title: Text(
                        'From: ${DateFormat('yyyy-MM-dd').format(_startDate)}',
                      ),
                      trailing: const Icon(Icons.calendar_today),
                      onTap: () => _selectDate(context, true),
                    ),
                  ),
                  Expanded(
                    child: ListTile(
                      title: Text(
                        'To: ${DateFormat('yyyy-MM-dd').format(_endDate)}',
                      ),
                      trailing: const Icon(Icons.calendar_today),
                      onTap: () => _selectDate(context, false),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 20),
                  // NEW: Conditional rendering based on SLD completeness
                  if (!_isSldCreated)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.dashboard_customize,
                              size: 60,
                              color: Colors.grey.shade600,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Create Substation SLD to view the energy consumption here.',
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(color: Colors.grey.shade700),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Please ensure an SLD layout is saved and busbar energy maps are configured for this substation.',
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      ),
                    )
                  else // If SLD is created, show the energy data sections
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Energy Readings Per Bay',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 10),
                        if (_computedBayEnergyData.isEmpty)
                          const Center(
                            child: Text(
                              'No energy readings available for the selected period or substation.',
                            ),
                          )
                        else
                          _buildEnergyReadingsTable(),

                        const SizedBox(height: 40), // Separator
                        // Existing Transformer Readings Charts
                        const Text(
                          'Transformer Readings (Charts)',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 20),
                        ..._baysMap
                            .values // Use _baysMap for all bays
                            .where(
                              (bay) => bay.bayType == 'Transformer',
                            ) // Filter for Transformer bays
                            .map((bay) {
                              final transformerReadings = _allLogsheetEntries
                                  .where((entry) => entry.bayId == bay.id)
                                  .toList();
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Bay: ${bay.name}',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  TransformerReadingsChart(
                                    readings: transformerReadings,
                                    fieldName:
                                        'Current', // Assuming these fields exist
                                    unit: 'A',
                                  ),
                                  const SizedBox(height: 20),
                                  TransformerReadingsChart(
                                    readings: transformerReadings,
                                    fieldName: 'Voltage',
                                    unit: 'V',
                                  ),
                                  const SizedBox(height: 20),
                                  TransformerReadingsChart(
                                    readings: transformerReadings,
                                    fieldName: 'Power Factor',
                                    unit: '',
                                  ),
                                  const SizedBox(height: 40),
                                ],
                              );
                            })
                            .toList(),
                        if (_baysMap.values
                            .where((bay) => bay.bayType == 'Transformer')
                            .isEmpty)
                          const Center(
                            child: Text(
                              'No Transformer bays found in selected substation.',
                            ),
                          )
                        else if (_allLogsheetEntries.isEmpty &&
                            _baysMap.values
                                .where((bay) => bay.bayType == 'Transformer')
                                .isNotEmpty)
                          const Center(
                            child: Text(
                              'No readings for Transformer bays in the selected period.',
                            ),
                          )
                        else if (_allLogsheetEntries.isEmpty)
                          const SizedBox.shrink(), // No data overall message is handled by overall table/summary

                        const SizedBox(height: 40), // Separator
                        // Substation Abstract Section
                        const Text(
                          'Substation Energy Abstract',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 10),
                        _buildEnergyAbstractTable(),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // _buildEnergyReadingsTable method (unchanged)
  Widget _buildEnergyReadingsTable() {
    print(
      'DEBUG: _buildEnergyReadingsTable called. Data entries: ${_computedBayEnergyData.length}',
    ); // Debug log
    final List<DataColumn> columns = [
      const DataColumn(
        label: Text('Bay (kV)', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      const DataColumn(
        label: Text(
          'Present IMP',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      const DataColumn(
        label: Text(
          'Previous IMP',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      const DataColumn(
        label: Text('M.F', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      const DataColumn(
        label: Text(
          'IMP (Comp.)',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      const DataColumn(
        label: Text(
          'Present EXP',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      const DataColumn(
        label: Text(
          'Previous EXP',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      const DataColumn(
        label: Text(
          'EXP (Comp.)',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
    ];

    final List<DataRow> rows = _computedBayEnergyData.map((data) {
      final String bayNameWithVoltage =
          '${data.bay.name} (${data.bay.voltageLevel})';
      final String presentImp = data.currImp?.toStringAsFixed(2) ?? '-';
      final String previousImp = data.prevImp?.toStringAsFixed(2) ?? '-';
      final String mfEnergy =
          data.bay.multiplyingFactor?.toStringAsFixed(2) ?? '-';
      final String computedImp = data.impConsumed != null
          ? data.impConsumed!.toStringAsFixed(2)
          : '-';
      final String presentExp = data.currExp?.toStringAsFixed(2) ?? '-';
      final String previousExp = data.prevExp?.toStringAsFixed(2) ?? '-';
      final String computedExp = data.expConsumed != null
          ? data.expConsumed!.toStringAsFixed(2)
          : '-';

      return DataRow(
        cells: [
          DataCell(Text(bayNameWithVoltage)),
          DataCell(Text(presentImp)),
          DataCell(Text(previousImp)),
          DataCell(Text(mfEnergy)),
          DataCell(Text(computedImp)),
          DataCell(Text(presentExp)),
          DataCell(Text(previousExp)),
          DataCell(Text(computedExp)),
        ],
      );
    }).toList();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: columns,
        rows: rows,
        dataRowMinHeight: 40,
        dataRowMaxHeight: 60,
        columnSpacing: 12,
        horizontalMargin: 0,
        headingRowColor: MaterialStateProperty.all(Colors.grey.shade200),
        border: TableBorder.all(color: Colors.grey.shade300, width: 0.5),
      ),
    );
  }

  // _buildEnergyAbstractTable method (unchanged)
  Widget _buildEnergyAbstractTable() {
    print('DEBUG: _buildEnergyAbstractTable called.'); // Debug log
    List<String> abstractTableHeaders = [''];
    final List<String> uniqueBusVoltages =
        _baysMap
            .values // Use _baysMap which includes busbars
            .where((bay) => bay.bayType == 'Busbar')
            .map((bay) => bay.voltageLevel)
            .toSet()
            .toList()
          ..sort(
            (a, b) => // Sort by voltage level (highest to lowest)
                _parseVoltageLevel(b).compareTo(_parseVoltageLevel(a)),
          );
    print('DEBUG: Unique bus voltages: $uniqueBusVoltages'); // Debug log

    for (String voltage in uniqueBusVoltages) {
      abstractTableHeaders.add('$voltage BUS');
    }
    abstractTableHeaders.add('ABSTRACT OF S/S');
    abstractTableHeaders.add('TOTAL');
    print('DEBUG: Abstract table headers: $abstractTableHeaders'); // Debug log

    List<DataRow> abstractTableDataRows = [];

    final List<String> rowLabels = [
      'Import (MWH)',
      'Export (MWH)',
      'Difference (MWH)',
      'Loss (%)',
    ];

    for (int i = 0; i < rowLabels.length; i++) {
      List<DataCell> rowCells = [DataCell(Text(rowLabels[i]))];
      double rowTotalSummable = 0.0;
      double overallTotalImpForLossCalc = 0.0;
      double overallTotalDiffForLossCalc = 0.0;

      for (String voltage in uniqueBusVoltages) {
        final busbarsOfThisVoltage = _baysMap.values.where(
          // Use _baysMap
          (bay) => bay.bayType == 'Busbar' && bay.voltageLevel == voltage,
        );
        double totalForThisBusVoltageImp = 0.0;
        double totalForThisBusVoltageExp = 0.0;
        double totalForThisBusVoltageDiff = 0.0;

        for (var busbar in busbarsOfThisVoltage) {
          final busSummary = _busEnergySummary[busbar.id];
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
          overallTotalImpForLossCalc += totalForThisBusVoltageImp;
        } else if (rowLabels[i].contains('Export')) {
          rowCells.add(
            DataCell(Text(totalForThisBusVoltageExp.toStringAsFixed(2))),
          );
          rowTotalSummable += totalForThisBusVoltageExp;
        } else if (rowLabels[i].contains('Diff.')) {
          rowCells.add(
            DataCell(Text(totalForThisBusVoltageDiff.toStringAsFixed(2))),
          );
          rowTotalSummable += totalForThisBusVoltageDiff;
          overallTotalDiffForLossCalc += totalForThisBusVoltageDiff;
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

      // Add Abstract of S/S data (overall substation totals)
      if (rowLabels[i].contains('Import')) {
        rowCells.add(
          DataCell(
            Text((_abstractEnergyData['totalImp'] ?? 0.0).toStringAsFixed(2)),
          ),
        );
        rowTotalSummable += (_abstractEnergyData['totalImp'] ?? 0.0);
        overallTotalImpForLossCalc += (_abstractEnergyData['totalImp'] ?? 0.0);
      } else if (rowLabels[i].contains('Export')) {
        rowCells.add(
          DataCell(
            Text((_abstractEnergyData['totalExp'] ?? 0.0).toStringAsFixed(2)),
          ),
        );
        rowTotalSummable += (_abstractEnergyData['totalExp'] ?? 0.0);
      } else if (rowLabels[i].contains('Diff.')) {
        rowCells.add(
          DataCell(
            Text((_abstractEnergyData['difference'] ?? 0.0).toStringAsFixed(2)),
          ),
        );
        rowTotalSummable += (_abstractEnergyData['difference'] ?? 0.0);
        overallTotalDiffForLossCalc +=
            (_abstractEnergyData['difference'] ?? 0.0);
      } else if (rowLabels[i].contains('Loss')) {
        rowCells.add(
          DataCell(
            Text(
              (_abstractEnergyData['lossPercentage'] ?? 0.0).toStringAsFixed(2),
            ),
          ),
        );
      }

      // Add TOTAL column
      if (rowLabels[i].contains('Loss')) {
        String overallTotalLossPercentage = 'N/A';
        if (overallTotalImpForLossCalc > 0) {
          overallTotalLossPercentage =
              ((overallTotalDiffForLossCalc / overallTotalImpForLossCalc) * 100)
                  .toStringAsFixed(2);
        }
        rowCells.add(DataCell(Text(overallTotalLossPercentage)));
      } else {
        rowCells.add(DataCell(Text(rowTotalSummable.toStringAsFixed(2))));
      }

      abstractTableDataRows.add(DataRow(cells: rowCells));
    }
    print(
      'DEBUG: _buildEnergyAbstractTable completed. Rows generated: ${abstractTableDataRows.length}',
    ); // Debug log
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: abstractTableHeaders
            .map(
              (header) => DataColumn(
                label: Text(
                  header,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            )
            .toList(),
        rows: abstractTableDataRows,
        dataRowMinHeight: 40,
        dataRowMaxHeight: 60,
        columnSpacing: 12,
        horizontalMargin: 0,
        headingRowColor: MaterialStateProperty.all(Colors.grey.shade200),
        border: TableBorder.all(color: Colors.grey.shade300, width: 0.5),
      ),
    );
  }
}

// Extension to help find firstWhereOrNull for List (already exists in OperationsTab, ensure consistency)
extension ListExtension<T> on List<T> {
  T? firstWhereOrNull(bool Function(T element) test) {
    for (var element in this) {
      if (test(element)) return element;
    }
    return null;
  }
}

// lib/screens/subdivision_dashboard_tabs/energy_tab.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:math';
import 'package:collection/collection.dart';

import '../../models/logsheet_models.dart';
import '../../models/user_model.dart';
import '../../models/bay_model.dart';
import '../../models/hierarchy_models.dart';
import '../../models/user_readings_config_model.dart';
import '../../utils/snackbar_utils.dart';
import '../../models/app_state_data.dart';
import '../../models/energy_readings_data.dart';
import '../../models/busbar_energy_map.dart';
import '../../models/assessment_model.dart';
import '../../models/substation_sld_layout_model.dart';

// Enhanced Equipment Icon Widget
class _EquipmentIcon extends StatelessWidget {
  final String type;
  final Color color;
  final double size;

  const _EquipmentIcon({
    required this.type,
    required this.color,
    this.size = 24.0,
  });

  @override
  Widget build(BuildContext context) {
    IconData iconData;

    switch (type.toLowerCase()) {
      case 'energy':
        iconData = Icons.electrical_services;
        break;
      case 'charts':
        iconData = Icons.show_chart;
        break;
      case 'transformer':
        iconData = Icons.electrical_services;
        break;
      case 'abstract':
        iconData = Icons.analytics;
        break;
      default:
        iconData = Icons.electrical_services;
        break;
    }

    return Icon(iconData, size: size, color: color);
  }
}

// Improved Transformer Readings Chart Widget
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
    final theme = Theme.of(context);
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
      return Container(
        height: 250,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.info_outline, size: 48, color: Colors.grey.shade400),
              const SizedBox(height: 12),
              Text(
                'No $fieldName data available',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                'for the selected period',
                style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
              ),
            ],
          ),
        ),
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
      height: 280,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: LineChart(
        LineChartData(
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: theme.colorScheme.primary,
              barWidth: 3,
              dotData: FlDotData(
                show: true,
                getDotPainter: (spot, percent, barData, index) {
                  return FlDotCirclePainter(
                    radius: 4,
                    color: theme.colorScheme.primary,
                    strokeWidth: 2,
                    strokeColor: Colors.white,
                  );
                },
              ),
              belowBarData: BarAreaData(
                show: true,
                color: theme.colorScheme.primary.withOpacity(0.1),
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
                      style: TextStyle(
                        fontSize: 10,
                        color: theme.colorScheme.onSurface.withOpacity(0.6),
                      ),
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
                reservedSize: 50,
                getTitlesWidget: (value, meta) {
                  return Text(
                    '${value.toStringAsFixed(0)} $unit',
                    style: TextStyle(
                      fontSize: 10,
                      color: theme.colorScheme.onSurface.withOpacity(0.6),
                    ),
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
              getTooltipColor: (touchedSpot) => theme.colorScheme.surface,
              tooltipBorder: BorderSide(color: theme.colorScheme.outline),
              getTooltipItems: (touchedSpots) {
                return touchedSpots.map((spot) {
                  final date = timeMap[spot.x];
                  return LineTooltipItem(
                    '${fieldName}: ${spot.y.toStringAsFixed(2)} $unit\n${date != null ? DateFormat('yyyy-MM-dd HH:mm').format(date) : ''}',
                    TextStyle(color: theme.colorScheme.onSurface),
                  );
                }).toList();
              },
            ),
            handleBuiltInTouches: true,
          ),
          gridData: FlGridData(
            show: true,
            drawHorizontalLine: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (value) {
              return FlLine(
                color: theme.colorScheme.outline.withOpacity(0.2),
                strokeWidth: 1,
              );
            },
          ),
          borderData: FlBorderData(
            show: true,
            border: Border.all(
              color: theme.colorScheme.outline.withOpacity(0.2),
              width: 1,
            ),
          ),
        ),
      ),
    );
  }
}

class EnergyTab extends StatefulWidget {
  final AppUser currentUser;
  final String? initialSelectedSubstationId;
  final DateTime startDate;
  final DateTime endDate;
  final String substationId;

  const EnergyTab({
    Key? key,
    required this.currentUser,
    this.initialSelectedSubstationId,
    required this.startDate,
    required this.endDate,
    required this.substationId,
  }) : super(key: key);

  @override
  _EnergyTabState createState() => _EnergyTabState();
}

class _EnergyTabState extends State<EnergyTab> {
  bool _isLoading = true;
  String? _errorMessage;
  Substation? _selectedSubstation;
  List<Substation> _allSubstations = [];
  List<LogsheetEntry> _allLogsheetEntries = [];
  List<BayEnergyData> _computedBayEnergyData = [];
  Map<String, Bay> _baysMap = {};
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 7));
  DateTime _endDate = DateTime.now();

  // Energy Calculation Results
  Map<String, Map<String, double>> _busEnergySummary = {};
  Map<String, double> _abstractEnergyData = {};

  // Hierarchy maps for lookup
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

  bool _isSldCreated = false;

  @override
  void initState() {
    super.initState();
    _startDate = widget.startDate;
    _endDate = widget.endDate;
    _initializeData();
  }

  @override
  void didUpdateWidget(EnergyTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.startDate != widget.startDate ||
        oldWidget.endDate != widget.endDate) {
      _startDate = widget.startDate;
      _endDate = widget.endDate;
      if (_selectedSubstation != null) {
        _fetchEnergyData();
      }
    }
  }

  int _parseVoltageLevel(String? voltageLevel) {
    if (voltageLevel == null || voltageLevel.isEmpty) return 0;
    final regex = RegExp(r'(\d+)kV');
    final match = regex.firstMatch(voltageLevel);
    if (match != null && match.groupCount > 0) {
      return int.tryParse(match.group(1)!) ?? 0;
    }
    return 0;
  }

  Future<void> _initializeData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final appState = Provider.of<AppStateData>(context, listen: false);
      final subdivisionId =
          appState.currentUser?.assignedLevels?['subdivisionId'];

      if (subdivisionId == null) {
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

      if (widget.initialSelectedSubstationId != null &&
          _allSubstations.any(
            (s) => s.id == widget.initialSelectedSubstationId,
          )) {
        _selectedSubstation = _allSubstations.firstWhere(
          (s) => s.id == widget.initialSelectedSubstationId,
        );
      } else if (_allSubstations.isNotEmpty) {
        _selectedSubstation = _allSubstations.first;
      }

      await _fetchTransmissionHierarchyData();
      await _fetchDistributionHierarchyData();
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

  Future<void> _checkSldExistenceAndFetchEnergyData() async {
    if (_selectedSubstation == null) {
      setState(() {
        _isSldCreated = false;
        _isLoading = false;
      });
      return;
    }

    final sldLayoutDoc = await FirebaseFirestore.instance
        .collection('substationSldLayouts')
        .doc(_selectedSubstation!.id)
        .get();

    final busbarEnergyMapsSnapshot = await FirebaseFirestore.instance
        .collection('busbarEnergyMaps')
        .where('substationId', isEqualTo: _selectedSubstation!.id)
        .limit(1)
        .get();

    setState(() {
      _isSldCreated =
          sldLayoutDoc.exists && busbarEnergyMapsSnapshot.docs.isNotEmpty;
    });

    if (_isSldCreated) {
      await _fetchEnergyData();
    } else {
      setState(() {
        _isLoading = false;
        _errorMessage = null;
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
    if (_zonesMap.isEmpty) {
      final zonesSnapshot = await FirebaseFirestore.instance
          .collection('zones')
          .get();
      _zonesMap = {
        for (var doc in zonesSnapshot.docs) doc.id: Zone.fromFirestore(doc),
      };
    }

    if (_circlesMap.isEmpty) {
      final circlesSnapshot = await FirebaseFirestore.instance
          .collection('circles')
          .get();
      _circlesMap = {
        for (var doc in circlesSnapshot.docs) doc.id: Circle.fromFirestore(doc),
      };
    }

    if (_divisionsMap.isEmpty) {
      final divisionsSnapshot = await FirebaseFirestore.instance
          .collection('divisions')
          .get();
      _divisionsMap = {
        for (var doc in divisionsSnapshot.docs)
          doc.id: Division.fromFirestore(doc),
      };
    }

    if (_subdivisionsMap.isEmpty) {
      final subdivisionsSnapshot = await FirebaseFirestore.instance
          .collection('subdivisions')
          .get();
      _subdivisionsMap = {
        for (var doc in subdivisionsSnapshot.docs)
          doc.id: Subdivision.fromFirestore(doc),
      };
    }

    _substationsMap = {for (var s in _allSubstations) s.id: s};
  }

  Future<void> _fetchDistributionHierarchyData() async {
    if (_distributionZonesMap.isEmpty) {
      final zonesSnapshot = await FirebaseFirestore.instance
          .collection('distributionZones')
          .get();
      _distributionZonesMap = {
        for (var doc in zonesSnapshot.docs)
          doc.id: DistributionZone.fromFirestore(doc),
      };
    }

    if (_distributionCirclesMap.isEmpty) {
      final circlesSnapshot = await FirebaseFirestore.instance
          .collection('distributionCircles')
          .get();
      _distributionCirclesMap = {
        for (var doc in circlesSnapshot.docs)
          doc.id: DistributionCircle.fromFirestore(doc),
      };
    }

    if (_distributionDivisionsMap.isEmpty) {
      final divisionsSnapshot = await FirebaseFirestore.instance
          .collection('distributionDivisions')
          .get();
      _distributionDivisionsMap = {
        for (var doc in divisionsSnapshot.docs)
          doc.id: DistributionDivision.fromFirestore(doc),
      };
    }

    if (_distributionSubdivisionsMap.isEmpty) {
      final subdivisionsSnapshot = await FirebaseFirestore.instance
          .collection('distributionSubdivisions')
          .get();
      _distributionSubdivisionsMap = {
        for (var doc in subdivisionsSnapshot.docs)
          doc.id: DistributionSubdivision.fromFirestore(doc),
      };
    }
  }

  Future<void> _fetchEnergyData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _allLogsheetEntries.clear();
      _baysMap.clear();
      _computedBayEnergyData.clear();
      _busEnergySummary.clear();
      _abstractEnergyData.clear();
      _busbarEnergyMaps.clear();
      _latestAssessmentsPerBay.clear();
    });

    try {
      // Fetch all bays for the selected substation
      List<Bay> fetchedBays = [];
      final baysSnapshot = await FirebaseFirestore.instance
          .collection('bays')
          .where('substationId', isEqualTo: _selectedSubstation!.id)
          .get();

      fetchedBays.addAll(
        baysSnapshot.docs.map((doc) => Bay.fromFirestore(doc)).toList(),
      );

      final List<Bay> nonBusbarBays = fetchedBays
          .where((bay) => bay.bayType != 'Busbar')
          .toList();
      final List<Bay> busbarBays = fetchedBays
          .where((bay) => bay.bayType == 'Busbar')
          .toList();

      nonBusbarBays.sort((a, b) {
        final voltageA = _parseVoltageLevel(a.voltageLevel);
        final voltageB = _parseVoltageLevel(b.voltageLevel);
        if (voltageA != voltageB) {
          return voltageB.compareTo(voltageA);
        }
        return a.name.compareTo(b.name);
      });

      busbarBays.sort((a, b) {
        final voltageA = _parseVoltageLevel(a.voltageLevel);
        final voltageB = _parseVoltageLevel(b.voltageLevel);
        return voltageB.compareTo(voltageA);
      });

      _baysMap = {for (var bay in fetchedBays) bay.id: bay};
      final List<String> allBayIds = fetchedBays.map((bay) => bay.id).toList();

      if (allBayIds.isNotEmpty) {
        final queryStartTime = Timestamp.fromDate(_startDate);
        final queryEndTime = Timestamp.fromDate(
          _endDate
              .add(const Duration(days: 1))
              .subtract(const Duration(seconds: 1)),
        );

        // Fetch Logsheet Entries in chunks
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
              .where('frequency', isEqualTo: 'hourly')
              .where('readingTimestamp', isGreaterThanOrEqualTo: queryStartTime)
              .where('readingTimestamp', isLessThanOrEqualTo: queryEndTime)
              .get();

          fetchedLogsheetEntries.addAll(
            readingsSnapshot.docs
                .map((doc) => LogsheetEntry.fromFirestore(doc))
                .toList(),
          );
        }

        _allLogsheetEntries = fetchedLogsheetEntries;

        // Fetch Busbar Energy Maps
        final fullBusbarEnergyMapsSnapshot = await FirebaseFirestore.instance
            .collection('busbarEnergyMaps')
            .where('substationId', isEqualTo: _selectedSubstation!.id)
            .get();

        _busbarEnergyMaps = {
          for (var doc in fullBusbarEnergyMapsSnapshot.docs)
            '${doc['busbarId']}-${doc['connectedBayId']}':
                BusbarEnergyMap.fromFirestore(doc),
        };

        // Fetch Assessments
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
            _latestAssessmentsPerBay[assessment.bayId] = assessment;
          }
        }

        _computeBayEnergyData(nonBusbarBays);
        _computeAbstractEnergyData(busbarBays);
      }

      if (!mounted) return;
      setState(() => _isLoading = false);
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

  void _computeBayEnergyData(List<Bay> baysToCompute) {
    _computedBayEnergyData.clear();

    for (var bay in baysToCompute) {
      final bayEntries = _allLogsheetEntries
          .where((entry) => entry.bayId == bay.id)
          .toList();

      bayEntries.sort(
        (a, b) => a.readingTimestamp.compareTo(b.readingTimestamp),
      );

      final LogsheetEntry? firstEntry = bayEntries.firstWhereOrNull(
        (entry) =>
            entry.values.containsKey('Energy_Import_Present') ||
            entry.values.containsKey('Energy_Export_Present'),
      );

      final LogsheetEntry? lastEntry = bayEntries.lastWhereOrNull(
        (entry) =>
            entry.values.containsKey('Energy_Import_Present') ||
            entry.values.containsKey('Energy_Export_Present'),
      );

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
      double? mfEnergy = bay.multiplyingFactor;

      double? computedImport;
      if (currentImp != null && previousImp != null && mfEnergy != null) {
        computedImport = max(0.0, (currentImp - previousImp) * mfEnergy);
      }

      double? computedExport;
      if (currentExp != null && previousExp != null && mfEnergy != null) {
        computedExport = max(0.0, (currentExp - previousExp) * mfEnergy);
      }

      final latestAssessment = _latestAssessmentsPerBay[bay.id];
      bool hasAssessment = latestAssessment != null;

      BayEnergyData bayEnergy = BayEnergyData(
        bayName: bay.name,
        bayId: bay.id,
        prevImp: previousImp,
        currImp: currentImp,
        prevExp: previousExp,
        currExp: currentExp,
        mf: mfEnergy,
        impConsumed: computedImport,
        expConsumed: computedExport,
        hasAssessment: hasAssessment,
        bay: bay,
      );

      if (latestAssessment != null) {
        bayEnergy = bayEnergy.applyAssessment(
          importAdjustment: latestAssessment.importAdjustment,
          exportAdjustment: latestAssessment.exportAdjustment,
        );
      }

      _computedBayEnergyData.add(bayEnergy);
    }
  }

  void _computeAbstractEnergyData(List<Bay> busbarBays) {
    _busEnergySummary.clear();
    _abstractEnergyData.clear();

    Map<String, Map<String, double>> temporaryBusFlows = {};
    for (var busbar in busbarBays) {
      temporaryBusFlows[busbar.id] = {'import': 0.0, 'export': 0.0};
    }

    for (var entry in _busbarEnergyMaps.values) {
      final Bay? connectedBay = _baysMap[entry.connectedBayId];
      final BayEnergyData? connectedBayEnergy = _computedBayEnergyData
          .firstWhereOrNull((data) => data.bayId == entry.connectedBayId);

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
    for (var busbar in busbarBays) {
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
    }

    _busEnergySummary = calculatedBusEnergySummary;

    double currentAbstractSubstationTotalImp = 0;
    double currentAbstractSubstationTotalExp = 0;

    final List<Bay> sortedBusbarsByVoltage = busbarBays
      ..sort(
        (a, b) => _parseVoltageLevel(
          b.voltageLevel,
        ).compareTo(_parseVoltageLevel(a.voltageLevel)),
      );

    final Bay? highestVoltageBus = sortedBusbarsByVoltage.firstWhereOrNull(
      (b) => true,
    );
    final Bay? lowestVoltageBus = sortedBusbarsByVoltage.lastWhereOrNull(
      (b) => true,
    );

    if (highestVoltageBus != null) {
      currentAbstractSubstationTotalImp =
          (calculatedBusEnergySummary[highestVoltageBus.id]?['totalImp']) ??
          0.0;
    }

    if (lowestVoltageBus != null) {
      currentAbstractSubstationTotalExp =
          (calculatedBusEnergySummary[lowestVoltageBus.id]?['totalExp']) ?? 0.0;
    }

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
  }

  Future<void> _selectDate(BuildContext context, bool isStartDate) async {
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
            _endDate = _startDate;
          }
        } else {
          _endDate = picked;
          if (_endDate.isBefore(_startDate)) {
            _startDate = _endDate;
          }
        }
      });
      _fetchEnergyData();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      body: Column(
        children: [
          // Enhanced Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer.withOpacity(
                          0.3,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: _EquipmentIcon(
                        type: 'energy',
                        color: theme.colorScheme.primary,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Energy Consumption Analysis',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                          Text(
                            '${DateFormat('MMM dd').format(_startDate)} - ${DateFormat('MMM dd, yyyy').format(_endDate)}',
                            style: TextStyle(
                              fontSize: 14,
                              color: theme.colorScheme.onSurface.withOpacity(
                                0.6,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Substation Dropdown
                DropdownButtonFormField<Substation>(
                  decoration: InputDecoration(
                    labelText: 'Select Substation',
                    prefixIcon: const Icon(Icons.location_on),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: theme.colorScheme.primary.withOpacity(0.05),
                  ),
                  value: _selectedSubstation,
                  items: _allSubstations.map((substation) {
                    return DropdownMenuItem(
                      value: substation,
                      child: Text(substation.name),
                    );
                  }).toList(),
                  onChanged: (Substation? newValue) {
                    setState(() {
                      _selectedSubstation = newValue;
                      _checkSldExistenceAndFetchEnergyData();
                    });
                  },
                  isExpanded: true,
                  hint: const Text('No substation selected'),
                ),
              ],
            ),
          ),

          // Content
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _selectedSubstation == null
                ? _buildSelectSubstationMessage(theme)
                : !_isSldCreated
                ? _buildSldRequiredMessage(theme)
                : _buildEnergyContent(theme),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectSubstationMessage(ThemeData theme) {
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
              Icons.location_searching,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              'Select a Substation',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Please select a substation to view energy consumption data.',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSldRequiredMessage(ThemeData theme) {
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
              Icons.dashboard_customize,
              size: 64,
              color: Colors.orange.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              'SLD Configuration Required',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Create Substation SLD to view the energy consumption here.\n\nPlease ensure an SLD layout is saved and busbar energy maps are configured for this substation.',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEnergyContent(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Energy Readings Per Bay Section
          _buildSectionHeader(theme, 'Energy Readings Per Bay', 'energy'),
          const SizedBox(height: 16),
          if (_computedBayEnergyData.isEmpty)
            _buildNoDataCard(
              'No energy readings available for the selected period or substation.',
              Icons.info_outline,
            )
          else
            _buildEnergyReadingsTable(),

          const SizedBox(height: 32),

          // Transformer Readings Charts Section
          _buildSectionHeader(theme, 'Transformer Readings (Charts)', 'charts'),
          const SizedBox(height: 16),
          ..._buildTransformerCharts(),

          const SizedBox(height: 32),

          // Substation Abstract Section
          _buildSectionHeader(theme, 'Substation Energy Abstract', 'abstract'),
          const SizedBox(height: 16),
          _buildEnergyAbstractTable(),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(ThemeData theme, String title, String iconType) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outline.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: _EquipmentIcon(
              type: iconType,
              color: theme.colorScheme.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoDataCard(String message, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Center(
        child: Column(
          children: [
            Icon(icon, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              message,
              style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEnergyReadingsTable() {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.all(16),
        child: DataTable(
          columns: const [
            DataColumn(
              label: Text(
                'Bay (kV)',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            DataColumn(
              label: Text(
                'Present IMP',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            DataColumn(
              label: Text(
                'Previous IMP',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            DataColumn(
              label: Text('M.F', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            DataColumn(
              label: Text(
                'IMP (Comp.)',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            DataColumn(
              label: Text(
                'Present EXP',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            DataColumn(
              label: Text(
                'Previous EXP',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            DataColumn(
              label: Text(
                'EXP (Comp.)',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
          rows: _computedBayEnergyData.map((data) {
            final String bayNameWithVoltage =
                '${data.bay.name} (${data.bay.voltageLevel})';

            return DataRow(
              cells: [
                DataCell(Text(bayNameWithVoltage)),
                DataCell(Text(data.currImp?.toStringAsFixed(2) ?? '-')),
                DataCell(Text(data.prevImp?.toStringAsFixed(2) ?? '-')),
                DataCell(
                  Text(data.bay.multiplyingFactor?.toStringAsFixed(2) ?? '-'),
                ),
                DataCell(Text(data.impConsumed?.toStringAsFixed(2) ?? '-')),
                DataCell(Text(data.currExp?.toStringAsFixed(2) ?? '-')),
                DataCell(Text(data.prevExp?.toStringAsFixed(2) ?? '-')),
                DataCell(Text(data.expConsumed?.toStringAsFixed(2) ?? '-')),
              ],
            );
          }).toList(),
          dataRowMinHeight: 48,
          dataRowMaxHeight: 64,
          columnSpacing: 16,
          horizontalMargin: 0,
          headingRowColor: MaterialStateProperty.all(
            theme.colorScheme.primary.withOpacity(0.1),
          ),
          border: TableBorder.all(color: Colors.grey.shade300, width: 0.5),
        ),
      ),
    );
  }

  List<Widget> _buildTransformerCharts() {
    final transformerBays = _baysMap.values
        .where((bay) => bay.bayType == 'Transformer')
        .toList();

    if (transformerBays.isEmpty) {
      return [
        _buildNoDataCard(
          'No Transformer bays found in selected substation.',
          Icons.electrical_services,
        ),
      ];
    }

    if (_allLogsheetEntries.isEmpty) {
      return [
        _buildNoDataCard(
          'No readings for Transformer bays in the selected period.',
          Icons.show_chart,
        ),
      ];
    }

    return transformerBays.map((bay) {
      final transformerReadings = _allLogsheetEntries
          .where((entry) => entry.bayId == bay.id)
          .toList();

      return Container(
        margin: const EdgeInsets.only(bottom: 24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _EquipmentIcon(
                    type: 'transformer',
                    color: Colors.orange,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Bay: ${bay.name}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TransformerReadingsChart(
                readings: transformerReadings,
                fieldName: 'Current',
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
            ],
          ),
        ),
      );
    }).toList();
  }

  Widget _buildEnergyAbstractTable() {
    final theme = Theme.of(context);

    List<String> abstractTableHeaders = [''];
    final List<String> uniqueBusVoltages =
        _baysMap.values
            .where((bay) => bay.bayType == 'Busbar')
            .map((bay) => bay.voltageLevel)
            .toSet()
            .toList()
          ..sort(
            (a, b) => _parseVoltageLevel(b).compareTo(_parseVoltageLevel(a)),
          );

    for (String voltage in uniqueBusVoltages) {
      abstractTableHeaders.add('$voltage BUS');
    }
    abstractTableHeaders.add('ABSTRACT OF S/S');
    abstractTableHeaders.add('TOTAL');

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

      // Add Abstract of S/S data
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

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.all(16),
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
          dataRowMinHeight: 48,
          dataRowMaxHeight: 64,
          columnSpacing: 16,
          horizontalMargin: 0,
          headingRowColor: MaterialStateProperty.all(
            theme.colorScheme.primary.withOpacity(0.1),
          ),
          border: TableBorder.all(color: Colors.grey.shade300, width: 0.5),
        ),
      ),
    );
  }
}

// Extension helper
extension ListExtension<T> on List<T> {
  T? firstWhereOrNull(bool Function(T element) test) {
    for (var element in this) {
      if (test(element)) return element;
    }
    return null;
  }
}

// lib/screens/subdivision_dashboard_tabs/energy_tab.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:math';

import '../../models/logsheet_models.dart';
import '../../models/user_model.dart';
import '../../models/bay_model.dart';
import '../../models/user_readings_config_model.dart';
import '../../utils/snackbar_utils.dart';
import '../../models/app_state_data.dart';

// Transformer Readings Chart Widget (moved from original)
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
  }) : super(key: key);

  @override
  _EnergyTabState createState() => _EnergyTabState();
}

class _EnergyTabState extends State<EnergyTab> {
  bool _isLoading = true;
  Map<String, List<LogsheetEntry>> _transformerReadings = {};
  Map<String, Bay> _baysMap = {};
  DateTime _startDate = DateTime.now().subtract(
    const Duration(days: 7),
  ); // New: Start date for filter
  DateTime _endDate = DateTime.now(); // New: End date for filter
  String? _selectedSubstationId;

  @override
  void initState() {
    super.initState();
    _selectedSubstationId = widget.initialSelectedSubstationId;
    _initializeData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final newSelectedSubstationId = Provider.of<AppStateData>(
      context,
    ).selectedSubstation?.id;
    if (newSelectedSubstationId != null &&
        newSelectedSubstationId != _selectedSubstationId) {
      setState(() {
        _selectedSubstationId = newSelectedSubstationId;
        _fetchEnergyData();
      });
    } else if (_selectedSubstationId == null &&
        newSelectedSubstationId != null) {
      setState(() {
        _selectedSubstationId = newSelectedSubstationId;
        _fetchEnergyData();
      });
    }
  }

  Future<void> _initializeData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      // User config for duration is less relevant now with explicit date pickers
      // but keeping the logic for initial date range if needed.
      final userId = widget.currentUser.uid;
      final configDoc = await FirebaseFirestore.instance
          .collection('userReadingsConfigurations')
          .doc(userId)
          .get();

      if (configDoc.exists) {
        final config = UserReadingsConfig.fromFirestore(configDoc);
        // Adjust initial _startDate based on config, but _endDate remains now
        _startDate = DateTime.now().subtract(
          Duration(
            hours: config.durationUnit == 'hours'
                ? config.durationValue
                : config.durationUnit == 'days'
                ? config.durationValue * 24
                : config.durationUnit == 'weeks'
                ? config.durationValue * 24 * 7
                : config.durationUnit == 'months'
                ? config.durationValue * 24 * 30
                : config.durationValue * 24 * 30,
          ),
        );
      } else {
        _startDate = DateTime.now().subtract(
          const Duration(days: 7),
        ); // Default to last 7 days
      }

      await _fetchEnergyData();
    } catch (e) {
      print('Error initializing energy tab data: $e');
      if (mounted) {
        SnackBarUtils.showSnackBar(
          context,
          'Error initializing energy data: $e',
          isError: true,
        );
      }
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _fetchEnergyData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    _transformerReadings.clear();
    _baysMap.clear();

    try {
      if (_selectedSubstationId == null) {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
        return;
      }

      List<Bay> fetchedBays = [];
      final baysSnapshot = await FirebaseFirestore.instance
          .collection('bays')
          .where('substationId', isEqualTo: _selectedSubstationId)
          .get();
      fetchedBays.addAll(
        baysSnapshot.docs.map((doc) => Bay.fromFirestore(doc)).toList(),
      );
      _baysMap = {for (var bay in fetchedBays) bay.id: bay};

      final transformerBayIds = _baysMap.values
          .where((bay) => bay.bayType == 'Transformer')
          .map((bay) => bay.id)
          .toList();

      if (transformerBayIds.isNotEmpty) {
        final queryStartTime = Timestamp.fromDate(_startDate);
        // To include the entire end day, set the end timestamp to just before midnight of the next day
        final queryEndTime = Timestamp.fromDate(
          _endDate
              .add(const Duration(days: 1))
              .subtract(const Duration(seconds: 1)),
        );

        for (int i = 0; i < transformerBayIds.length; i += 10) {
          final chunk = transformerBayIds.sublist(
            i,
            i + 10 > transformerBayIds.length
                ? transformerBayIds.length
                : i + 10,
          );
          if (chunk.isEmpty) continue;

          final readingsSnapshot = await FirebaseFirestore.instance
              .collection('logsheetEntries')
              .where('bayId', whereIn: chunk)
              .where('frequency', isEqualTo: 'hourly')
              .where('readingTimestamp', isGreaterThanOrEqualTo: queryStartTime)
              .where('readingTimestamp', isLessThanOrEqualTo: queryEndTime)
              .get();

          for (var doc in readingsSnapshot.docs) {
            final entry = LogsheetEntry.fromFirestore(doc);
            _transformerReadings.putIfAbsent(entry.bayId, () => []).add(entry);
          }
        }
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

  // New: Date picker method
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
            _endDate = _startDate; // Ensure end date is not before start date
          }
        } else {
          _endDate = picked;
          if (_endDate.isBefore(_startDate)) {
            _startDate = _endDate; // Ensure start date is not after end date
          }
        }
      });
      _fetchEnergyData(); // Re-fetch data with new date range
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_selectedSubstationId == null) {
      return const Center(
        child: Text('Please select a substation to view energy data.'),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
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
        ),
        Expanded(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Transformer Readings',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      // Display the actual date range being shown
                      Text(
                        'Period: ${DateFormat('yyyy-MM-dd').format(_startDate)} to ${DateFormat('yyyy-MM-dd').format(_endDate)}',
                        style: const TextStyle(fontSize: 14),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  ..._transformerReadings.entries
                      .where((entry) => _baysMap.containsKey(entry.key))
                      .map((entry) {
                        final bay = _baysMap[entry.key]!;
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
                              readings: entry.value,
                              fieldName: 'Current',
                              unit: 'A',
                            ),
                            const SizedBox(height: 20),
                            TransformerReadingsChart(
                              readings: entry.value,
                              fieldName: 'Voltage',
                              unit: 'V',
                            ),
                            const SizedBox(height: 20),
                            TransformerReadingsChart(
                              readings: entry.value,
                              fieldName: 'Power Factor',
                              unit: '',
                            ),
                            const SizedBox(height: 40),
                          ],
                        );
                      })
                      .toList(),
                  if (_transformerReadings.isEmpty && !_isLoading)
                    const Center(
                      child: Text(
                        'No transformer readings available for the selected period or substation.',
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

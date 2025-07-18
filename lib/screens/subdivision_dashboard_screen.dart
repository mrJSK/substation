import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:math';

import '../models/tripping_shutdown_model.dart';
import '../models/user_model.dart';
import '../models/bay_model.dart';
import '../models/logsheet_models.dart';
import '../utils/snackbar_utils.dart';
import './tripping_shutdown_entry_screen.dart';
import './reading_slot_overview_screen.dart';
import './tripping_shutdown_overview_screen.dart';
import './subdivision_asset_management_screen.dart';
import '../models/user_readings_config_model.dart';
import '../models/hierarchy_models.dart';

// Tripping & Shutdown Event List Widget
class TrippingShutdownEventsList extends StatelessWidget {
  final List<TrippingShutdownEntry> events;
  final AppUser currentUser;
  final Map<String, Bay> baysMap;
  final Function() onRefresh;

  const TrippingShutdownEventsList({
    Key? key,
    required this.events,
    required this.currentUser,
    required this.baysMap,
    required this.onRefresh,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (events.isEmpty) {
      return const Center(
        child: Text(
          'No Tripping/Shutdown events found for your assigned subdivisions.',
          style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16.0),
      itemCount: events.length,
      itemBuilder: (context, index) {
        final event = events[index];
        final bay =
            baysMap[event.bayId] ??
            Bay(
              id: event.bayId,
              name: event.bayName,
              substationId: event.substationId,
              voltageLevel: 'Unknown',
              bayType: 'Unknown',
              createdBy: '',
              createdAt: Timestamp.now(),
            );

        return Card(
          margin: const EdgeInsets.symmetric(vertical: 8.0),
          elevation: 3,
          child: ListTile(
            leading: Icon(
              event.status == 'OPEN'
                  ? Icons.hourglass_empty
                  : Icons.check_circle,
              color: event.status == 'OPEN' ? Colors.orange : Colors.green,
            ),
            title: Text('${event.eventType} - ${bay.name}'),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Start: ${DateFormat('dd.MMM.yyyy HH:mm').format(event.startTime.toDate())}',
                ),
                Text('Status: ${event.status}'),
                if (event.reasonForNonFeeder != null &&
                    event.reasonForNonFeeder!.isNotEmpty)
                  Text('Reason: ${event.reasonForNonFeeder}'),
                if (event.status == 'CLOSED' && event.endTime != null)
                  Text(
                    'End: ${DateFormat('dd.MMM.yyyy HH:mm').format(event.endTime!.toDate())}',
                  ),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.visibility),
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => TrippingShutdownEntryScreen(
                          substationId: event.substationId,
                          currentUser: currentUser,
                          entryToEdit: event,
                          isViewOnly: true,
                        ),
                      ),
                    );
                  },
                ),
                if (event.status == 'OPEN' &&
                    currentUser.role == UserRole.subdivisionManager)
                  IconButton(
                    icon: const Icon(Icons.edit),
                    onPressed: () {
                      Navigator.of(context)
                          .push(
                            MaterialPageRoute(
                              builder: (_) => TrippingShutdownEntryScreen(
                                substationId: event.substationId,
                                currentUser: currentUser,
                                entryToEdit: event,
                                isViewOnly: false,
                              ),
                            ),
                          )
                          .then((_) {
                            onRefresh();
                          });
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// Transformer Readings Chart Widget
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

// Report Generation Widget
class ReportGenerationSection extends StatefulWidget {
  final String subdivisionId;
  final AppUser currentUser;
  final String? selectedSubstationId; // Added selectedSubstationId

  const ReportGenerationSection({
    Key? key,
    required this.subdivisionId,
    required this.currentUser,
    this.selectedSubstationId, // Added selectedSubstationId
  }) : super(key: key);

  @override
  _ReportGenerationSectionState createState() =>
      _ReportGenerationSectionState();
}

class _ReportGenerationSectionState extends State<ReportGenerationSection> {
  String? _selectedBayId;
  List<Bay> _bays = [];
  DateTime _fromDate = DateTime.now().subtract(const Duration(days: 7));
  DateTime _toDate = DateTime.now();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchBays();
    });
  }

  @override
  void didUpdateWidget(covariant ReportGenerationSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedSubstationId != oldWidget.selectedSubstationId) {
      _selectedBayId = null; // Reset selected bay when substation changes
      _fetchBays();
    }
  }

  Future<void> _fetchBays() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      List<String> substationIds = [];
      if (widget.selectedSubstationId != null) {
        substationIds.add(widget.selectedSubstationId!);
      } else {
        // If no specific substation is selected, fetch all for the subdivision
        final substationsSnapshot = await FirebaseFirestore.instance
            .collection('substations')
            .where('subdivisionId', isEqualTo: widget.subdivisionId)
            .get();
        substationIds = substationsSnapshot.docs.map((doc) => doc.id).toList();
      }

      if (substationIds.isEmpty) {
        if (!mounted) return;
        SnackBarUtils.showSnackBar(
          context,
          'No substations found for report generation or no substation selected.',
          isError: true,
        );
        setState(() {
          _bays = [];
          _isLoading = false;
        });
        return;
      }

      List<Bay> fetchedBays = [];
      for (int i = 0; i < substationIds.length; i += 10) {
        final chunk = substationIds.sublist(
          i,
          i + 10 > substationIds.length ? substationIds.length : i + 10,
        );
        if (chunk.isEmpty) continue;

        final baysSnapshot = await FirebaseFirestore.instance
            .collection('bays')
            .where('substationId', whereIn: chunk)
            .orderBy('name')
            .get();
        fetchedBays.addAll(
          baysSnapshot.docs.map((doc) => Bay.fromFirestore(doc)).toList(),
        );
      }

      if (!mounted) return;
      setState(() {
        _bays = fetchedBays;
        // Keep the previously selected bay if it exists in the new list of bays for the selected substation
        if (_selectedBayId != null &&
            !_bays.any((bay) => bay.id == _selectedBayId)) {
          _selectedBayId = null;
        }
        _isLoading = false;
      });
    } catch (e) {
      print("Error fetching bays for reports: $e");
      if (!mounted) return;
      SnackBarUtils.showSnackBar(
        context,
        'Failed to load bays for reports: $e',
        isError: true,
      );
      setState(() => _isLoading = false);
    }
  }

  Future<void> _selectDate(BuildContext context, bool isFrom) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isFrom ? _fromDate : _toDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      if (!mounted) return;
      setState(() {
        if (isFrom) {
          _fromDate = picked;
        } else {
          _toDate = picked;
        }
      });
    }
  }

  Future<void> _generateReport() async {
    if (_selectedBayId == null) {
      SnackBarUtils.showSnackBar(
        context,
        'Please select a bay.',
        isError: true,
      );
      return;
    }

    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final bay = _bays.firstWhere((b) => b.id == _selectedBayId);
      final logsheetSnapshot = await FirebaseFirestore.instance
          .collection('logsheetEntries')
          .where('bayId', isEqualTo: _selectedBayId)
          .where('frequency', isEqualTo: 'hourly')
          .where(
            'readingTimestamp',
            isGreaterThanOrEqualTo: Timestamp.fromDate(_fromDate),
          )
          .where(
            'readingTimestamp',
            isLessThanOrEqualTo: Timestamp.fromDate(
              _toDate.add(const Duration(days: 1)),
            ),
          )
          .get();

      final trippingSnapshot = await FirebaseFirestore.instance
          .collection('trippingShutdownEntries')
          .where('bayId', isEqualTo: _selectedBayId)
          .where(
            'startTime',
            isGreaterThanOrEqualTo: Timestamp.fromDate(_fromDate),
          )
          .where(
            'startTime',
            isLessThanOrEqualTo: Timestamp.fromDate(
              _toDate.add(const Duration(days: 1)),
            ),
          )
          .get();

      final readings = logsheetSnapshot.docs
          .map((doc) => LogsheetEntry.fromFirestore(doc))
          .toList();
      double? maxCurrent,
          minCurrent,
          maxVoltage,
          minVoltage,
          maxPowerFactor,
          minPowerFactor;
      DateTime? maxCurrentTime,
          minCurrentTime,
          maxVoltageTime,
          minVoltageTime,
          maxPowerFactorTime,
          minPowerFactorTime;

      for (var entry in readings) {
        final current = double.tryParse(
          entry.values['Current']?.toString() ?? '',
        );
        final voltage = double.tryParse(
          entry.values['Voltage']?.toString() ?? '',
        );
        final powerFactor = double.tryParse(
          entry.values['Power Factor']?.toString() ?? '',
        );
        final timestamp = entry.readingTimestamp.toDate();

        if (current != null) {
          if (maxCurrent == null || current > maxCurrent) {
            maxCurrent = current;
            maxCurrentTime = timestamp;
          }
          if (minCurrent == null || current < minCurrent) {
            minCurrent = current;
            minCurrentTime = timestamp;
          }
        }
        if (voltage != null) {
          if (maxVoltage == null || voltage > maxVoltage) {
            maxVoltage = voltage;
            maxVoltageTime = timestamp;
          }
          if (minVoltage == null || voltage < minVoltage) {
            minVoltage = voltage;
            minVoltageTime = timestamp;
          }
        }
        if (powerFactor != null) {
          if (maxPowerFactor == null || powerFactor > maxPowerFactor) {
            maxPowerFactor = powerFactor;
            maxPowerFactorTime = timestamp;
          }
          if (minPowerFactor == null || powerFactor < minPowerFactor) {
            minPowerFactor = powerFactor;
            minPowerFactorTime = timestamp;
          }
        }
      }

      final trippingEvents = trippingSnapshot.docs
          .map((doc) => TrippingShutdownEntry.fromFirestore(doc))
          .toList();

      final reportContent = StringBuffer();
      reportContent.writeln('# Bay Report: ${bay.name}');
      reportContent.writeln(
        '**Generated on**: ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())}',
      );
      reportContent.writeln(
        '**Period**: ${DateFormat('yyyy-MM-dd').format(_fromDate)} to ${DateFormat('yyyy-MM-dd').format(_toDate)}',
      );
      reportContent.writeln('\n## Readings Summary');
      if (maxCurrent != null) {
        reportContent.writeln(
          '- **Max Current**: ${maxCurrent.toStringAsFixed(2)} A at ${DateFormat('yyyy-MM-dd HH:mm').format(maxCurrentTime!)}',
        );
        reportContent.writeln(
          '- **Min Current**: ${minCurrent?.toStringAsFixed(2)} A at ${DateFormat('yyyy-MM-dd HH:mm').format(minCurrentTime!)}',
        );
      } else {
        reportContent.writeln('- No Current data available.');
      }
      if (maxVoltage != null) {
        reportContent.writeln(
          '- **Max Voltage**: ${maxVoltage.toStringAsFixed(2)} V at ${DateFormat('yyyy-MM-dd HH:mm').format(maxVoltageTime!)}',
        );
        reportContent.writeln(
          '- **Min Voltage**: ${minVoltage?.toStringAsFixed(2)} V at ${DateFormat('yyyy-MM-dd HH:mm').format(minVoltageTime!)}',
        );
      } else {
        reportContent.writeln('- No Voltage data available.');
      }
      if (maxPowerFactor != null) {
        reportContent.writeln(
          '- **Max Power Factor**: ${maxPowerFactor.toStringAsFixed(2)} at ${DateFormat('yyyy-MM-dd HH:mm').format(maxPowerFactorTime!)}',
        );
        reportContent.writeln(
          '- **Min Power Factor**: ${minPowerFactor?.toStringAsFixed(2)} at ${DateFormat('yyyy-MM-dd HH:mm').format(minPowerFactorTime!)}',
        );
      } else {
        reportContent.writeln('- No Power Factor data available.');
      }

      reportContent.writeln('\n## Tripping/Shutdown Events');
      if (trippingEvents.isEmpty) {
        reportContent.writeln('- No Tripping/Shutdown events found.');
      } else {
        for (var event in trippingEvents) {
          final duration = event.endTime != null
              ? event.endTime!
                        .toDate()
                        .difference(event.startTime.toDate())
                        .inMinutes
                        .toString() +
                    ' minutes'
              : 'Ongoing';
          reportContent.writeln('- **Event Type**: ${event.eventType}');
          reportContent.writeln(
            '  - **Start**: ${DateFormat('yyyy-MM-dd HH:mm').format(event.startTime.toDate())}',
          );
          reportContent.writeln(
            '  - **End**: ${event.endTime != null ? DateFormat('yyyy-MM-dd HH:mm').format(event.endTime!.toDate()) : 'N/A'}',
          );
          reportContent.writeln('  - **Duration**: $duration');
          reportContent.writeln('  - **Flags/Cause**: ${event.flagsCause}');
          if (event.reasonForNonFeeder != null &&
              event.reasonForNonFeeder!.isNotEmpty) {
            reportContent.writeln(
              '  - **Reason**: ${event.reasonForNonFeeder}',
            );
          }
        }
      }

      if (!mounted) return;
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: Text('Report for ${bay.name}'),
          content: SingleChildScrollView(child: Text(reportContent.toString())),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    } catch (e) {
      print('Failed to generate report: $e');
      if (!mounted) return;
      SnackBarUtils.showSnackBar(
        context,
        'Failed to generate report: $e',
        isError: true,
      );
    } finally {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            'Generate Custom Bay Reports',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: DropdownButtonFormField<String>(
            decoration: const InputDecoration(
              labelText: 'Select Bay',
              border: OutlineInputBorder(),
            ),
            value: _selectedBayId,
            items: _bays
                .map(
                  (bay) => DropdownMenuItem(
                    value: bay.id,
                    child: Text('${bay.name} (${bay.bayType})'),
                  ),
                )
                .toList(),
            onChanged: (value) {
              setState(() {
                _selectedBayId = value;
              });
            },
            validator: (value) => value == null ? 'Please select a bay' : null,
          ),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            children: [
              Expanded(
                child: ListTile(
                  title: Text(
                    'From: ${DateFormat('yyyy-MM-dd').format(_fromDate)}',
                  ),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () => _selectDate(context, true),
                ),
              ),
              Expanded(
                child: ListTile(
                  title: Text(
                    'To: ${DateFormat('yyyy-MM-dd').format(_toDate)}',
                  ),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () => _selectDate(context, false),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Center(
          child: ElevatedButton(
            onPressed: _isLoading ? null : _generateReport,
            child: _isLoading
                ? const CircularProgressIndicator()
                : const Text('Generate Report'),
          ),
        ),
      ],
    );
  }
}

// Main Subdivision Dashboard Screen
class SubdivisionDashboardScreen extends StatefulWidget {
  final AppUser currentUser;
  final String? selectedSubstationId;

  const SubdivisionDashboardScreen({
    Key? key,
    required this.currentUser,
    this.selectedSubstationId,
  }) : super(key: key);

  @override
  State<SubdivisionDashboardScreen> createState() =>
      _SubdivisionDashboardScreenState();
}

class _SubdivisionDashboardScreenState
    extends State<SubdivisionDashboardScreen> {
  bool _isLoading = true;
  List<TrippingShutdownEntry> _trippingShutdownEvents = [];
  Map<String, List<LogsheetEntry>> _transformerReadings = {};
  Map<String, Bay> _baysMap = {};
  late DateTime _startTime;

  List<Substation> _substations = []; // Changed to List<Substation>
  String? _selectedSubstationId; // Holds the selected substation

  int _currentIndex = 0; // Current index for BottomNavigationBar

  @override
  void initState() {
    super.initState();
    _selectedSubstationId =
        widget.selectedSubstationId; // Initialize selected substation
    _loadConfigAndFetchData();
  }

  Future<void> _loadConfigAndFetchData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final userId = widget.currentUser.uid;
      final configDoc = await FirebaseFirestore.instance
          .collection('userReadingsConfigurations')
          .doc(userId)
          .get();

      if (configDoc.exists) {
        final config = UserReadingsConfig.fromFirestore(configDoc);
        final now = DateTime.now();
        _startTime = now.subtract(
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
        _startTime = DateTime.now().subtract(const Duration(hours: 48));
      }
      await _fetchSubstations(); // Fetch substations first
      if (_selectedSubstationId != null || _substations.isNotEmpty) {
        // If _selectedSubstationId is still null after fetching, try to set the first one
        if (_selectedSubstationId == null && _substations.isNotEmpty) {
          _selectedSubstationId = _substations.first.id;
        }
        await _fetchData();
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      print('Error loading configuration: $e');
      if (mounted) {
        SnackBarUtils.showSnackBar(
          context,
          'Error loading configuration: $e',
          isError: true,
        );
      }
      _startTime = DateTime.now().subtract(const Duration(hours: 48));
      setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchSubstations() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final AppUser currentUser = widget.currentUser;

      if (currentUser.assignedLevels?['subdivisionId'] == null) {
        if (!mounted) return;
        SnackBarUtils.showSnackBar(
          context,
          'Subdivision ID not found in user profile. Please contact admin.',
          isError: true,
        );
        setState(() => _isLoading = false);
        return;
      }

      final subdivisionId = currentUser.assignedLevels!['subdivisionId'];

      final substationsSnapshot = await FirebaseFirestore.instance
          .collection('substations')
          .where('subdivisionId', isEqualTo: subdivisionId)
          .orderBy('name')
          .get();

      if (!mounted) return;
      setState(() {
        _substations = substationsSnapshot.docs
            .map((doc) => Substation.fromFirestore(doc))
            .toList();
        if (_selectedSubstationId == null && _substations.isNotEmpty) {
          _selectedSubstationId = _substations.first.id;
        }
      });
    } catch (e) {
      print('Error fetching substations: $e');
      if (mounted) {
        SnackBarUtils.showSnackBar(
          context,
          'Error fetching substations: $e',
          isError: true,
        );
      }
      setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      if (_selectedSubstationId == null) {
        setState(() {
          _isLoading = false;
          _trippingShutdownEvents = [];
          _transformerReadings = {};
          _baysMap = {};
        });
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

      final List<String> bayIds = _baysMap.keys.toList();
      if (bayIds.isEmpty) {
        if (!mounted) return;
        SnackBarUtils.showSnackBar(
          context,
          'No bays found for the selected substation.',
          isError: true,
        );
        setState(() {
          _isLoading = false;
          _trippingShutdownEvents = [];
          _transformerReadings = {};
        });
        return;
      }

      List<TrippingShutdownEntry> fetchedTrippingEvents = [];
      final trippingSnapshot = await FirebaseFirestore.instance
          .collection('trippingShutdownEntries')
          .where('substationId', isEqualTo: _selectedSubstationId)
          .orderBy('startTime', descending: true)
          .get();
      fetchedTrippingEvents.addAll(
        trippingSnapshot.docs
            .map((doc) => TrippingShutdownEntry.fromFirestore(doc))
            .toList(),
      );
      _trippingShutdownEvents = fetchedTrippingEvents;

      final endTime = Timestamp.fromDate(DateTime.now());
      final startTime = Timestamp.fromDate(_startTime);

      final transformerBayIds = _baysMap.values
          .where((bay) => bay.bayType == 'Transformer')
          .map((bay) => bay.id)
          .toList();

      _transformerReadings.clear();
      if (transformerBayIds.isNotEmpty) {
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
              .where('readingTimestamp', isGreaterThanOrEqualTo: startTime)
              .where('readingTimestamp', isLessThanOrEqualTo: endTime)
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
      print('Error loading data for Subdivision Dashboard: $e');
      if (!mounted) return;
      SnackBarUtils.showSnackBar(
        context,
        'Error loading dashboard data: $e',
        isError: true,
      );
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = widget.currentUser;

    final List<Widget> _screens = [
      Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: DropdownButtonFormField<String>(
              decoration: InputDecoration(
                labelText: 'Select Substation',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              value: _selectedSubstationId,
              items: _substations
                  .map(
                    (substation) => DropdownMenuItem(
                      value: substation.id,
                      child: Text(substation.name),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                setState(() {
                  _selectedSubstationId = value;
                  _fetchData();
                });
              },
              validator: (value) =>
                  value == null ? 'Please select a substation' : null,
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _substations.isEmpty
                ? const Center(child: Text('No substations available.'))
                : TrippingShutdownEventsList(
                    events: _trippingShutdownEvents,
                    currentUser: currentUser,
                    baysMap: _baysMap,
                    onRefresh: _loadConfigAndFetchData,
                  ),
          ),
        ],
      ),
      Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: DropdownButtonFormField<String>(
              decoration: InputDecoration(
                labelText: 'Select Substation',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              value: _selectedSubstationId,
              items: _substations
                  .map(
                    (substation) => DropdownMenuItem(
                      value: substation.id,
                      child: Text(substation.name),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                setState(() {
                  _selectedSubstationId = value;
                  _fetchData();
                });
              },
              validator: (value) =>
                  value == null ? 'Please select a substation' : null,
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _substations.isEmpty
                ? const Center(child: Text('No substations available.'))
                : _buildTransformerReadingsCharts(),
          ),
        ],
      ),
      Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: DropdownButtonFormField<String>(
              decoration: InputDecoration(
                labelText: 'Select Substation',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              value: _selectedSubstationId,
              items: _substations
                  .map(
                    (substation) => DropdownMenuItem(
                      value: substation.id,
                      child: Text(substation.name),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                setState(() {
                  _selectedSubstationId = value;
                  _fetchData();
                });
              },
              validator: (value) =>
                  value == null ? 'Please select a substation' : null,
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _substations.isEmpty
                ? const Center(child: Text('No substations available.'))
                : ReportGenerationSection(
                    subdivisionId:
                        currentUser.assignedLevels!['subdivisionId']!,
                    currentUser: currentUser,
                    selectedSubstationId: _selectedSubstationId,
                  ),
          ),
        ],
      ),
      if (currentUser.role == UserRole.subdivisionManager)
        SubdivisionAssetManagementScreen(
          subdivisionId: currentUser.assignedLevels!['subdivisionId']!,
          currentUser: currentUser,
        ),
    ];

    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        selectedItemColor: Theme.of(context).colorScheme.primary,
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed, // Ensures all labels are visible
        items: [
          const BottomNavigationBarItem(
            icon: Icon(Icons.warning),
            label: 'Tripping',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.insights),
            label: 'Readings',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.bar_chart),
            label: 'Reports',
          ),
          if (currentUser.role == UserRole.subdivisionManager)
            const BottomNavigationBarItem(
              icon: Icon(Icons.engineering),
              label: 'Assets',
            ),
        ],
      ),
    );
  }

  Widget _buildTransformerReadingsCharts() {
    return SingleChildScrollView(
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
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Text(
                  'From: ${DateFormat('yyyy-MM-dd HH:mm').format(_startTime)}',
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
                  'No transformer readings available for the selected period.',
                ),
              ),
          ],
        ),
      ),
    );
  }
}

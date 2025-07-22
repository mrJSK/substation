// lib/screens/bay_readings_overview_screen.dart
import 'dart:math'; // Keep this import if 'min' and 'max' are used by fl_chart internally

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:collection/collection.dart'; // Import for firstWhereOrNull
import 'package:fl_chart/fl_chart.dart'; // Required for charts, ensure in pubspec.yaml

import '../../models/bay_model.dart';
import '../../models/user_model.dart';
import '../../models/reading_models.dart'; // For ReadingFieldDataType, ReadingFrequency
import '../../models/logsheet_models.dart'; // For LogsheetEntry
import '../../utils/snackbar_utils.dart';
import 'bay_readings_status_screen.dart'; // Screen 2: List of bays for a slot

// Enum for display modes
enum DisplayMode { charts, readings }

// Helper widget for rendering line charts (similar to TransformerReadingsChart)
class GenericReadingsLineChart extends StatelessWidget {
  final List<LogsheetEntry> readings;
  final String fieldName;
  final String? unit; // Unit is now optional
  final String frequencyType; // 'hourly' or 'daily'

  const GenericReadingsLineChart({
    Key? key,
    required this.readings,
    required this.fieldName,
    this.unit,
    required this.frequencyType,
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

    minY = minY * 0.9; // Add some padding to y-axis
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
                  String formatString = (frequencyType == 'hourly')
                      ? 'HH:mm'
                      : 'MMM dd';
                  return Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      DateFormat(formatString).format(date),
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
                    '${value.toStringAsFixed(0)} ${unit ?? ''}',
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
                    '${fieldName}: ${spot.y.toStringAsFixed(2)} ${unit ?? ''}\n${date != null ? DateFormat('yyyy-MM-dd HH:mm').format(date) : ''}',
                    const TextStyle(color: Colors.white),
                  );
                }).toList();
              },
            ),
            handleBuiltInTouches: true,
          ),
          gridData: FlGridData(show: true),
          borderData: FlBorderData(show: true),
        ),
      ),
    );
  }
}

class BayReadingsOverviewScreen extends StatefulWidget {
  final String substationId;
  final String substationName;
  final AppUser currentUser;
  final String frequencyType; // 'hourly' or 'daily'
  final DateTime startDate; // Date(s) for which data is to be displayed
  final DateTime endDate; // Date(s) for which data is to be displayed

  const BayReadingsOverviewScreen({
    super.key,
    required this.substationId,
    required this.substationName,
    required this.currentUser,
    required this.frequencyType,
    required this.startDate, // Passed from parent
    required this.endDate, // Passed from parent
  });

  @override
  State<BayReadingsOverviewScreen> createState() =>
      _BayReadingsOverviewScreenState(); // Corrected State class name
}

class _BayReadingsOverviewScreenState extends State<BayReadingsOverviewScreen> {
  bool _isLoading = true;
  DateTime _earliestAssignmentDate = DateTime(2000, 1, 1);

  final Map<String, bool> _overallSlotCompletionStatus = {};

  List<Bay> _allBaysInSubstation = [];
  Map<String, List<ReadingField>> _bayMandatoryFields = {};
  Map<String, Map<String, LogsheetEntry>> _logsheetEntriesForDate = {};

  // --- NEW: Chart/Display Mode States ---
  DisplayMode _displayMode = DisplayMode.charts; // Default to charts
  List<ReadingField> _selectedChartFields = []; // Fields chosen for charts
  List<ReadingTemplate> _allReadingTemplates =
      []; // To get available fields for config
  List<ReadingField> _availableReadingFieldsForCharts =
      []; // Filtered fields for config

  @override
  void initState() {
    super.initState();
    if (widget.substationId.isNotEmpty) {
      _loadAllDataAndCalculateStatuses();
    } else {
      _isLoading = false;
    }
  }

  @override
  void didUpdateWidget(covariant BayReadingsOverviewScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.substationId != oldWidget.substationId ||
        widget.frequencyType != oldWidget.frequencyType ||
        widget.startDate != oldWidget.startDate ||
        widget.endDate != oldWidget.endDate) {
      if (widget.substationId.isNotEmpty) {
        _loadAllDataAndCalculateStatuses();
      } else {
        setState(() {
          _isLoading = false;
          _overallSlotCompletionStatus.clear();
          _allBaysInSubstation = [];
          _bayMandatoryFields.clear();
          _logsheetEntriesForDate.clear();
          _selectedChartFields
              .clear(); // Clear chart fields on substation change
          _availableReadingFieldsForCharts.clear(); // Clear available fields
        });
      }
    }
  }

  Future<void> _loadAllDataAndCalculateStatuses() async {
    if (!mounted) return; // Always check mounted before setState in async
    setState(() {
      _isLoading = true;
      _overallSlotCompletionStatus.clear();
      _allBaysInSubstation = [];
      _bayMandatoryFields.clear();
      _logsheetEntriesForDate.clear();
      _availableReadingFieldsForCharts.clear(); // Clear for fresh load
    });

    if (widget.substationId.isEmpty) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    try {
      // 1. Fetch all bays for the current substation
      final baysSnapshot = await FirebaseFirestore.instance
          .collection('bays')
          .where('substationId', isEqualTo: widget.substationId)
          .orderBy('name')
          .get();
      _allBaysInSubstation = baysSnapshot.docs
          .map((doc) => Bay.fromFirestore(doc))
          .toList();

      // 2. Fetch all reading assignments for these bays to get mandatory fields
      final List<String> bayIds = _allBaysInSubstation
          .map((bay) => bay.id)
          .toList();
      if (bayIds.isEmpty) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }
      final assignmentsSnapshot = await FirebaseFirestore.instance
          .collection('bayReadingAssignments')
          .where('bayId', whereIn: bayIds)
          .get();

      _bayMandatoryFields.clear();
      DateTime? tempEarliestDate;
      for (var doc in assignmentsSnapshot.docs) {
        final assignedFieldsData =
            (doc.data() as Map<String, dynamic>)['assignedFields']
                as List<dynamic>;
        final List<ReadingField> allFields = assignedFieldsData
            .map(
              (fieldMap) =>
                  ReadingField.fromMap(fieldMap as Map<String, dynamic>),
            )
            .toList();

        _bayMandatoryFields[doc['bayId'] as String] = allFields
            .where(
              (field) =>
                  field.isMandatory &&
                  field.frequency.toString().split('.').last ==
                      widget.frequencyType,
            )
            .toList();

        if (doc.data().containsKey('readingStartDate') &&
            doc.data()['readingStartDate'] is Timestamp) {
          final Timestamp startDateTimestamp =
              doc.data()['readingStartDate'] as Timestamp;
          final DateTime startDate = startDateTimestamp.toDate();
          if (tempEarliestDate == null ||
              startDate.isBefore(tempEarliestDate)) {
            tempEarliestDate = startDate;
          }
        }
      }

      _earliestAssignmentDate = tempEarliestDate ?? DateTime(2000, 1, 1);

      // --- NEW: Fetch all Reading Templates for chart config ---
      final readingTemplateDocs = await FirebaseFirestore.instance
          .collection('readingTemplates')
          .get();
      _allReadingTemplates = readingTemplateDocs.docs
          .map((doc) => ReadingTemplate.fromFirestore(doc))
          .toList();

      // Filter available fields for charts based on substation's bay types
      _filterAvailableChartFields();

      // 3. Fetch ALL logsheet entries for the selected date range and frequencyType
      _logsheetEntriesForDate.clear();

      final startOfQueryPeriod = DateTime(
        widget.startDate.year,
        widget.startDate.month,
        widget.startDate.day,
      );
      // For endDate, set to end of the day to include full day's data
      final endOfQueryPeriod = DateTime(
        widget.endDate.year,
        widget.endDate.month,
        widget.endDate.day,
        23,
        59,
        59,
        999,
      );

      final logsheetsSnapshot = await FirebaseFirestore.instance
          .collection('logsheetEntries')
          .where('substationId', isEqualTo: widget.substationId)
          .where('frequency', isEqualTo: widget.frequencyType)
          .where(
            'readingTimestamp',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startOfQueryPeriod),
          )
          .where(
            'readingTimestamp',
            isLessThanOrEqualTo: Timestamp.fromDate(endOfQueryPeriod),
          )
          .get();

      for (var doc in logsheetsSnapshot.docs) {
        final entry = LogsheetEntry.fromFirestore(doc);
        final slotKey = _getTimeKeyFromLogsheetEntry(entry);
        _logsheetEntriesForDate.putIfAbsent(entry.bayId, () => {});
        _logsheetEntriesForDate[entry.bayId]![slotKey] = entry;
      }

      // 4. Calculate overall slot statuses
      _calculateSlotCompletionStatuses();
    } catch (e) {
      print("Error loading data for BayReadingsOverviewScreen: $e");
      if (mounted) {
        SnackBarUtils.showSnackBar(
          context,
          'Failed to load data: $e',
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // NEW: Filter available fields for chart configuration based on bay types in this substation
  void _filterAvailableChartFields() {
    Set<String> substationBayTypes = {};
    for (var bay in _allBaysInSubstation) {
      substationBayTypes.add(bay.bayType);
    }

    Set<ReadingField> uniqueFields = {};
    for (var template in _allReadingTemplates) {
      if (substationBayTypes.contains(template.bayType)) {
        for (var field in template.readingFields) {
          // Only add number type fields for charting
          if (field.name.isNotEmpty &&
              field.dataType == ReadingFieldDataType.number) {
            uniqueFields.add(field);
          }
        }
      }
    }
    _availableReadingFieldsForCharts = uniqueFields.toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    // Remove any previously selected chart fields that are no longer available
    _selectedChartFields.removeWhere(
      (field) =>
          !_availableReadingFieldsForCharts.any((f) => f.name == field.name),
    );
  }

  // Helper to get the time key string from a logsheet entry based on frequency
  String _getTimeKeyFromLogsheetEntry(LogsheetEntry entry) {
    if (entry.frequency == ReadingFrequency.hourly.toString().split('.').last &&
        entry.readingHour != null) {
      return '${DateFormat('yyyy-MM-dd').format(entry.readingTimestamp.toDate())}-${entry.readingHour!.toString().padLeft(2, '0')}';
    } else if (entry.frequency ==
        ReadingFrequency.daily.toString().split('.').last) {
      return DateFormat('yyyy-MM-dd').format(entry.readingTimestamp.toDate());
    }
    return ''; // Should not happen for hourly/daily
  }

  // Function to determine if a specific bay's logsheet is complete for a given slot
  bool _isBayLogsheetCompleteForSlot(
    String bayId,
    String
    slotTimeKey, // e.g., '2025-07-01-00' for hourly, '2025-07-01' for daily
  ) {
    final List<ReadingField> mandatoryFields = _bayMandatoryFields[bayId] ?? [];
    if (mandatoryFields.isEmpty) {
      return true; // No mandatory fields assigned for this bay/frequency, so considered complete
    }

    final LogsheetEntry? relevantLogsheet =
        _logsheetEntriesForDate[bayId]?[slotTimeKey];

    if (relevantLogsheet == null) {
      return false; // No logsheet found for this bay and slot
    }

    // Check if all mandatory fields in this logsheet entry have non-empty values
    return mandatoryFields.every((field) {
      final value = relevantLogsheet.values[field.name];
      if (field.dataType ==
              ReadingFieldDataType.boolean.toString().split('.').last &&
          value is Map &&
          value.containsKey('value')) {
        return value['value'] != null;
      }
      return value != null && (value is! String || value.isNotEmpty);
    });
  }

  void _calculateSlotCompletionStatuses() {
    _overallSlotCompletionStatus.clear();
    final List<String> slotKeys = _generateTimeSlotKeys();

    for (String slotKey in slotKeys) {
      bool allBaysCompleteForThisSlot = true;
      if (_allBaysInSubstation.isEmpty) {
        allBaysCompleteForThisSlot = true;
      } else {
        for (Bay bay in _allBaysInSubstation) {
          if (!_bayMandatoryFields.containsKey(bay.id) ||
              _bayMandatoryFields[bay.id]!.isEmpty) {
            continue;
          }
          if (!_isBayLogsheetCompleteForSlot(bay.id, slotKey)) {
            allBaysCompleteForThisSlot = false;
            break;
          }
        }
      }
      _overallSlotCompletionStatus[slotKey] = allBaysCompleteForThisSlot;
    }
  }

  List<String> _generateTimeSlotKeys() {
    List<String> keys = [];
    DateTime now = DateTime.now();

    for (
      DateTime d = widget.startDate;
      d.isBefore(widget.endDate.add(const Duration(days: 1)));
      d = d.add(const Duration(days: 1))
    ) {
      bool isCurrentDay = DateUtils.isSameDay(d, now);

      if (widget.frequencyType == 'hourly') {
        for (int hour = 0; hour < 24; hour++) {
          DateTime slotDateTime = DateTime(d.year, d.month, d.day, hour);
          if (slotDateTime.isAfter(now)) {
            continue;
          }
          keys.add(
            '${DateFormat('yyyy-MM-dd').format(d)}-${hour.toString().padLeft(2, '0')}',
          );
        }
      } else if (widget.frequencyType == 'daily') {
        if (d.isAfter(now) || (isCurrentDay && now.hour < 8)) {
          continue;
        }
        keys.add(DateFormat('yyyy-MM-dd').format(d));
      }
    }
    return keys;
  }

  // --- NEW: Chart Configuration Dialog ---
  void _showChartConfigurationDialog() {
    showDialog(
      context: context,
      builder: (ctx) {
        List<ReadingField> tempSelectedFields = List.from(_selectedChartFields);
        return AlertDialog(
          title: const Text('Configure Charts'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Select fields to display as charts:',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8.0,
                  runSpacing: 4.0,
                  children: _availableReadingFieldsForCharts.map((field) {
                    bool isSelected = tempSelectedFields.any(
                      (f) => f.name == field.name,
                    );
                    return FilterChip(
                      label: Text(
                        '${field.name} ${field.unit != null && field.unit!.isNotEmpty ? '(${field.unit})' : ''}',
                      ),
                      selected: isSelected,
                      onSelected: (selected) {
                        setState(() {
                          // setState on the dialog's state
                          if (selected) {
                            tempSelectedFields.add(field);
                          } else {
                            tempSelectedFields.removeWhere(
                              (f) => f.name == field.name,
                            );
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
                if (_availableReadingFieldsForCharts.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 8.0),
                    child: Text(
                      'No number-type reading fields available for charting in this substation.',
                      style: TextStyle(fontStyle: FontStyle.italic),
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  // setState on parent widget's state
                  _selectedChartFields = tempSelectedFields;
                });
                Navigator.pop(ctx);
              },
              child: const Text('Apply'),
            ),
          ],
        );
      },
    );
  }

  // --- NEW: Chart View Widget ---
  Widget _buildChartsView() {
    if (_selectedChartFields.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.show_chart, size: 60, color: Colors.grey),
              const SizedBox(height: 10),
              const Text(
                'No fields selected for charting.',
                style: TextStyle(
                  fontStyle: FontStyle.italic,
                  color: Colors.grey,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              ElevatedButton.icon(
                onPressed: _showChartConfigurationDialog,
                icon: const Icon(Icons.settings),
                label: const Text('Configure Charts'),
              ),
            ],
          ),
        ),
      );
    }

    // Group readings by bay for chart display
    Map<String, List<LogsheetEntry>> readingsByBay = {};
    for (var entryMap in _logsheetEntriesForDate.values) {
      for (var entry in entryMap.values) {
        readingsByBay.putIfAbsent(entry.bayId, () => []).add(entry);
      }
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: readingsByBay.entries.map((entry) {
          final String bayId = entry.key;
          final List<LogsheetEntry> bayReadings = entry.value;
          final Bay? bay = _allBaysInSubstation.firstWhereOrNull(
            (b) => b.id == bayId,
          );

          if (bay == null)
            return const SizedBox.shrink(); // Skip if bay not found

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Bay: ${bay.name}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              ..._selectedChartFields.map((field) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${field.name} ${field.unit != null ? '(${field.unit})' : ''}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    GenericReadingsLineChart(
                      readings: bayReadings,
                      fieldName: field.name,
                      unit: field.unit,
                      frequencyType: widget.frequencyType,
                    ),
                    const SizedBox(height: 20),
                  ],
                );
              }).toList(),
              const SizedBox(height: 40),
            ],
          );
        }).toList(),
      ),
    );
  }

  // --- NEW: Readings List View Widget ---
  Widget _buildReadingsListView() {
    List<LogsheetEntry> allEntries = [];
    _logsheetEntriesForDate.values.forEach((bayMap) {
      allEntries.addAll(bayMap.values);
    });
    // Sort to display chronologically
    allEntries.sort((a, b) => a.readingTimestamp.compareTo(b.readingTimestamp));

    if (allEntries.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            'No ${widget.frequencyType} readings available for ${widget.substationName} in the period ${DateFormat('dd.MMM.yyyy').format(widget.startDate)} - ${DateFormat('dd.MMM.yyyy').format(widget.endDate)}.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontStyle: FontStyle.italic,
              color: Colors.grey.shade600,
            ),
          ),
        ),
      );
    }

    return Column(
      children: [
        // This is the list of daily/hourly slots for completion status
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            itemCount: _generateTimeSlotKeys().length,
            itemBuilder: (context, index) {
              final slotKey = _generateTimeSlotKeys()[index];
              final bool isSlotComplete =
                  _overallSlotCompletionStatus[slotKey] ?? false;

              String slotTitle;
              DateTime slotDateTime;

              if (widget.frequencyType == 'hourly') {
                // slotKey format: 'yyyy-MM-dd-HH'
                List<String> parts = slotKey.split('-');
                DateTime datePart = DateFormat('yyyy-MM-dd').parse(parts[0]);
                int hourPart = int.parse(parts[1]);
                slotDateTime = DateTime(
                  datePart.year,
                  datePart.month,
                  datePart.day,
                  hourPart,
                );

                if (widget.startDate == widget.endDate) {
                  // Single day (SU mode)
                  slotTitle = '${hourPart.toString().padLeft(2, '0')}:00 Hr';
                } else {
                  // Date range (SM mode)
                  slotTitle =
                      '${hourPart.toString().padLeft(2, '0')}:00 Hr (${DateFormat('dd.MMM').format(datePart)})';
                }
              } else {
                // daily
                // slotKey format: 'yyyy-MM-dd'
                slotDateTime = DateFormat('yyyy-MM-dd').parse(slotKey);
                slotTitle =
                    'Daily Reading (${DateFormat('dd.MMM.yyyy').format(slotDateTime)})';
              }

              final bool isFutureSlot = slotDateTime.isAfter(DateTime.now());
              final bool isDisabled = isFutureSlot;

              return Card(
                margin: const EdgeInsets.symmetric(vertical: 8.0),
                elevation: 2,
                child: ListTile(
                  leading: Icon(
                    isSlotComplete ? Icons.check_circle : Icons.cancel,
                    color: isDisabled
                        ? Colors.grey
                        : (isSlotComplete ? Colors.green : Colors.red),
                  ),
                  title: Text(
                    slotTitle,
                    style: TextStyle(
                      color: isDisabled
                          ? Colors.grey
                          : Theme.of(context).textTheme.titleMedium?.color,
                    ),
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios),
                  onTap: isDisabled
                      ? null
                      : () {
                          int? selectedHour;
                          if (widget.frequencyType == 'hourly') {
                            List<String> parts = slotKey.split('-');
                            selectedHour = int.parse(parts[1]);
                          }

                          Navigator.of(context)
                              .push(
                                MaterialPageRoute(
                                  builder: (context) => BayReadingsStatusScreen(
                                    substationId: widget.substationId,
                                    substationName: widget.substationName,
                                    currentUser: widget.currentUser,
                                    frequencyType: widget.frequencyType,
                                    selectedDate: slotDateTime,
                                    selectedHour: selectedHour,
                                  ),
                                ),
                              )
                              .then((_) => _loadAllDataAndCalculateStatuses());
                        },
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    bool isDailyReading = widget.frequencyType == 'daily';
    bool isCurrentDayAndBefore8AM =
        isDailyReading &&
        DateUtils.isSameDay(widget.startDate, DateTime.now()) &&
        DateTime.now().hour < 8 &&
        widget.startDate == widget.endDate; // Only for single-day selection

    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Show daily reading message only if applicable
                if (showDailyReadingMessageForToday(
                  isDailyReading,
                  isCurrentDayAndBefore8AM,
                ))
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      'Daily readings for today will be available for entry after 08:00 AM IST.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontStyle: FontStyle.italic,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ),
                // Controls for Charts/Readings mode and Chart Configuration
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 8.0,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      SegmentedButton<DisplayMode>(
                        segments: const <ButtonSegment<DisplayMode>>[
                          ButtonSegment<DisplayMode>(
                            value: DisplayMode.charts,
                            label: Text('Charts'),
                            icon: Icon(Icons.show_chart),
                          ),
                          ButtonSegment<DisplayMode>(
                            value: DisplayMode.readings,
                            label: Text('Readings'),
                            icon: Icon(Icons.list),
                          ),
                        ],
                        selected: <DisplayMode>{_displayMode},
                        onSelectionChanged: (Set<DisplayMode> newSelection) {
                          setState(() {
                            _displayMode = newSelection.first;
                          });
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.settings),
                        tooltip: 'Configure Charts',
                        onPressed: _availableReadingFieldsForCharts.isEmpty
                            ? null
                            : _showChartConfigurationDialog,
                      ),
                    ],
                  ),
                ),
                // Conditional content based on display mode
                Expanded(
                  child:
                      (_logsheetEntriesForDate.isEmpty &&
                          !isCurrentDayAndBefore8AM)
                      ? Center(
                          child: Text(
                            'No ${widget.frequencyType} readings found for ${widget.substationName} in the period ${DateFormat('dd.MMM.yyyy').format(widget.startDate)} - ${DateFormat('dd.MMM.yyyy').format(widget.endDate)}.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontStyle: FontStyle.italic,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        )
                      : (_displayMode == DisplayMode.charts)
                      ? _buildChartsView()
                      : _buildReadingsListView(), // Show readings list when in readings mode
                ),
              ],
            ),
    );
  }

  // Helper to determine if daily reading message should be shown (refactored for clarity)
  bool showDailyReadingMessageForToday(
    bool isDailyReading,
    bool isCurrentDayAndBefore8AM,
  ) {
    return isDailyReading &&
        isCurrentDayAndBefore8AM &&
        widget.startDate == widget.endDate;
  }
}

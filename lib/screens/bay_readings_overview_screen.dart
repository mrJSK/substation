// lib/screens/bay_readings_overview_screen.dart

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:collection/collection.dart';
import 'package:fl_chart/fl_chart.dart';

import '../../models/bay_model.dart';
import '../../models/user_model.dart';
import '../../models/reading_models.dart';
import '../../models/logsheet_models.dart';
import '../../utils/snackbar_utils.dart';
import 'substation_dashboard/bay_readings_status_screen.dart';

enum DisplayMode { charts, readings }

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
      case 'charts':
        iconData = Icons.show_chart;
        break;
      case 'readings':
        iconData = Icons.list_alt;
        break;
      case 'hourly':
        iconData = Icons.access_time;
        break;
      case 'daily':
        iconData = Icons.calendar_today;
        break;
      default:
        iconData = Icons.electrical_services;
        break;
    }

    return Icon(iconData, size: size, color: color);
  }
}

// Enhanced Generic Readings Line Chart
class GenericReadingsLineChart extends StatelessWidget {
  final List readings;
  final String fieldName;
  final String? unit;
  final String frequencyType;

  const GenericReadingsLineChart({
    Key? key,
    required this.readings,
    required this.fieldName,
    this.unit,
    required this.frequencyType,
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
                  String formatString = (frequencyType == 'hourly')
                      ? 'HH:mm'
                      : 'MMM dd';
                  return Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      DateFormat(formatString).format(date),
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
                    '${value.toStringAsFixed(0)}\n${unit ?? ''}',
                    style: TextStyle(
                      fontSize: 10,
                      color: theme.colorScheme.onSurface.withOpacity(0.6),
                    ),
                    textAlign: TextAlign.center,
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
              getTooltipColor: (touchedSpot) =>
                  theme.colorScheme.surface, // Changed from tooltipBgColor
              tooltipBorder: BorderSide(color: theme.colorScheme.outline),
              getTooltipItems: (touchedSpots) {
                return touchedSpots.map((spot) {
                  final date = timeMap[spot.x];
                  return LineTooltipItem(
                    '${fieldName}: ${spot.y.toStringAsFixed(2)} ${unit ?? ''}\n${date != null ? DateFormat('yyyy-MM-dd HH:mm').format(date) : ''}',
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

class BayReadingsOverviewScreen extends StatefulWidget {
  final String substationId;
  final String substationName;
  final AppUser currentUser;
  final String frequencyType;
  final DateTime startDate;
  final DateTime endDate;

  const BayReadingsOverviewScreen({
    super.key,
    required this.substationId,
    required this.substationName,
    required this.currentUser,
    required this.frequencyType,
    required this.startDate,
    required this.endDate,
  });

  @override
  State<BayReadingsOverviewScreen> createState() =>
      _BayReadingsOverviewScreenState();
}

class _BayReadingsOverviewScreenState extends State<BayReadingsOverviewScreen> {
  bool _isLoading = true;
  final Map<String, bool> _overallSlotCompletionStatus = {};
  List<Bay> _allBaysInSubstation = [];
  Map<String, List<ReadingField>> _bayMandatoryFields = {};
  Map<String, Map<String, LogsheetEntry>> _logsheetEntriesForDate = {};

  DisplayMode _displayMode = DisplayMode.readings;
  List<ReadingField> _selectedChartFields = [];
  List<ReadingTemplate> _allReadingTemplates = [];
  List<ReadingField> _availableReadingFieldsForCharts = [];

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
          _selectedChartFields.clear();
          _availableReadingFieldsForCharts.clear();
        });
      }
    }
  }

  Future<void> _loadAllDataAndCalculateStatuses() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _overallSlotCompletionStatus.clear();
      _allBaysInSubstation = [];
      _bayMandatoryFields.clear();
      _logsheetEntriesForDate.clear();
      _availableReadingFieldsForCharts.clear();
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

      // 2. Fetch all reading assignments for these bays
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
            (doc.data() as Map)['assignedFields'] as List;
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

      // Fetch reading templates for chart configuration
      final readingTemplateDocs = await FirebaseFirestore.instance
          .collection('readingTemplates')
          .get();
      _allReadingTemplates = readingTemplateDocs.docs
          .map((doc) => ReadingTemplate.fromFirestore(doc))
          .toList();

      _filterAvailableChartFields();

      // 3. Fetch logsheet entries
      _logsheetEntriesForDate.clear();
      final startOfQueryPeriod = DateTime(
        widget.startDate.year,
        widget.startDate.month,
        widget.startDate.day,
      );
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

  void _filterAvailableChartFields() {
    Set<String> substationBayTypes = {};
    for (var bay in _allBaysInSubstation) {
      substationBayTypes.add(bay.bayType);
    }

    Set<ReadingField> uniqueFields = {};
    for (var template in _allReadingTemplates) {
      if (substationBayTypes.contains(template.bayType)) {
        for (var field in template.readingFields) {
          if (field.name.isNotEmpty &&
              field.dataType == ReadingFieldDataType.number) {
            uniqueFields.add(field);
          }
        }
      }
    }

    _availableReadingFieldsForCharts = uniqueFields.toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    _selectedChartFields.removeWhere(
      (field) =>
          !_availableReadingFieldsForCharts.any((f) => f.name == field.name),
    );
  }

  String _getTimeKeyFromLogsheetEntry(LogsheetEntry entry) {
    if (entry.frequency == ReadingFrequency.hourly.toString().split('.').last &&
        entry.readingHour != null) {
      return '${DateFormat('yyyy-MM-dd').format(entry.readingTimestamp.toDate())}-${entry.readingHour!.toString().padLeft(2, '0')}';
    } else if (entry.frequency ==
        ReadingFrequency.daily.toString().split('.').last) {
      return DateFormat('yyyy-MM-dd').format(entry.readingTimestamp.toDate());
    }
    return '';
  }

  bool _isBayLogsheetCompleteForSlot(String bayId, String slotTimeKey) {
    final List<ReadingField> mandatoryFields = _bayMandatoryFields[bayId] ?? [];
    if (mandatoryFields.isEmpty) {
      return true;
    }

    final LogsheetEntry? relevantLogsheet =
        _logsheetEntriesForDate[bayId]?[slotTimeKey];
    if (relevantLogsheet == null) {
      return false;
    }

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

  void _showChartConfigurationDialog() {
    showDialog(
      context: context,
      builder: (ctx) {
        List<ReadingField> tempSelectedFields = List.from(_selectedChartFields);
        final theme = Theme.of(context);

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Row(
                children: [
                  Icon(Icons.settings, color: theme.colorScheme.primary),
                  const SizedBox(width: 12),
                  const Text('Configure Charts'),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Select fields to display as charts:',
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.8),
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (_availableReadingFieldsForCharts.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.orange.shade200),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              color: Colors.orange.shade700,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'No number-type reading fields available for charting in this substation.',
                                style: TextStyle(color: Colors.orange.shade700),
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      Wrap(
                        spacing: 8.0,
                        runSpacing: 8.0,
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
                              setDialogState(() {
                                if (selected) {
                                  tempSelectedFields.add(field);
                                } else {
                                  tempSelectedFields.removeWhere(
                                    (f) => f.name == field.name,
                                  );
                                }
                              });
                            },
                            selectedColor: theme.colorScheme.primaryContainer,
                            checkmarkColor: theme.colorScheme.primary,
                          );
                        }).toList(),
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(
                    'Cancel',
                    style: TextStyle(
                      color: theme.colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ),
                ),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _selectedChartFields = tempSelectedFields;
                    });
                    Navigator.pop(ctx);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: theme.colorScheme.onPrimary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('Apply'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildChartsView() {
    final theme = Theme.of(context);

    if (_selectedChartFields.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(40),
                ),
                child: Icon(
                  Icons.show_chart,
                  size: 40,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'No fields selected for charting',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Configure chart fields to view data visualizations',
                style: TextStyle(
                  fontSize: 14,
                  color: theme.colorScheme.onSurface.withOpacity(0.6),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _showChartConfigurationDialog,
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: theme.colorScheme.onPrimary,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                icon: const Icon(Icons.settings),
                label: const Text('Configure Charts'),
              ),
            ],
          ),
        ),
      );
    }

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

          if (bay == null) return const SizedBox.shrink();

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: theme.colorScheme.primary.withOpacity(0.3),
                  ),
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
                      child: Icon(
                        Icons.electrical_services,
                        color: theme.colorScheme.primary,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            bay.name,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                          Text(
                            '${bay.voltageLevel} ${bay.bayType}',
                            style: TextStyle(
                              fontSize: 12,
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
              ),
              ..._selectedChartFields.map((field) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(left: 4, bottom: 8),
                      child: Text(
                        '${field.name} ${field.unit != null ? '(${field.unit})' : ''}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    GenericReadingsLineChart(
                      readings: bayReadings,
                      fieldName: field.name,
                      unit: field.unit,
                      frequencyType: widget.frequencyType,
                    ),
                    const SizedBox(height: 24),
                  ],
                );
              }).toList(),
              const SizedBox(height: 20),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildReadingsListView() {
    final theme = Theme.of(context);
    List<LogsheetEntry> allEntries = [];
    _logsheetEntriesForDate.values.forEach((bayMap) {
      allEntries.addAll(bayMap.values);
    });

    allEntries.sort((a, b) => a.readingTimestamp.compareTo(b.readingTimestamp));

    if (allEntries.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.info_outline, size: 64, color: Colors.grey.shade400),
              const SizedBox(height: 16),
              Text(
                'No ${widget.frequencyType} readings available',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'for ${widget.substationName} in the period\n${DateFormat('dd.MMM.yyyy').format(widget.startDate)} - ${DateFormat('dd.MMM.yyyy').format(widget.endDate)}',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
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
                List<String> parts = slotKey.split('-');
                DateTime datePart = DateFormat(
                  'yyyy-MM-dd',
                ).parse('${parts[0]}-${parts[1]}-${parts[2]}');
                int hourPart = int.parse(parts[3]);
                slotDateTime = DateTime(
                  datePart.year,
                  datePart.month,
                  datePart.day,
                  hourPart,
                );

                if (widget.startDate == widget.endDate) {
                  slotTitle = '${hourPart.toString().padLeft(2, '0')}:00 Hr';
                } else {
                  slotTitle =
                      '${hourPart.toString().padLeft(2, '0')}:00 Hr (${DateFormat('dd.MMM').format(datePart)})';
                }
              } else {
                slotDateTime = DateFormat('yyyy-MM-dd').parse(slotKey);
                slotTitle =
                    'Daily Reading (${DateFormat('dd.MMM.yyyy').format(slotDateTime)})';
              }

              final bool isFutureSlot = slotDateTime.isAfter(DateTime.now());
              final bool isDisabled = isFutureSlot;

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
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
                child: ListTile(
                  contentPadding: const EdgeInsets.all(16),
                  leading: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: isDisabled
                          ? Colors.grey.withOpacity(0.1)
                          : (isSlotComplete ? Colors.green : Colors.red)
                                .withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      isSlotComplete ? Icons.check_circle : Icons.cancel,
                      color: isDisabled
                          ? Colors.grey
                          : (isSlotComplete ? Colors.green : Colors.red),
                      size: 24,
                    ),
                  ),
                  title: Text(
                    slotTitle,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isDisabled
                          ? Colors.grey
                          : theme.colorScheme.onSurface,
                    ),
                  ),
                  subtitle: Text(
                    isSlotComplete
                        ? 'All readings completed'
                        : 'Readings pending',
                    style: TextStyle(
                      fontSize: 14,
                      color: isDisabled
                          ? Colors.grey
                          : (isSlotComplete ? Colors.green : Colors.red),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  trailing: Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                    color: isDisabled ? Colors.grey : null,
                  ),
                  onTap: isDisabled
                      ? null
                      : () {
                          int? selectedHour;
                          if (widget.frequencyType == 'hourly') {
                            List<String> parts = slotKey.split('-');
                            selectedHour = int.parse(parts[3]);
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
    final theme = Theme.of(context);
    bool isDailyReading = widget.frequencyType == 'daily';
    bool isCurrentDayAndBefore8AM =
        isDailyReading &&
        DateUtils.isSameDay(widget.startDate, DateTime.now()) &&
        DateTime.now().hour < 8 &&
        widget.startDate == widget.endDate;

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Header with frequency type info
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  margin: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: theme.colorScheme.primary.withOpacity(0.3),
                    ),
                  ),
                  child: Column(
                    children: [
                      _EquipmentIcon(
                        type: widget.frequencyType,
                        color: theme.colorScheme.primary,
                        size: 32,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${widget.frequencyType.capitalize()} Readings Overview',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.substationName,
                        style: TextStyle(
                          fontSize: 14,
                          color: theme.colorScheme.onSurface.withOpacity(0.7),
                        ),
                      ),
                    ],
                  ),
                ),

                // Show daily reading message only if applicable
                if (isCurrentDayAndBefore8AM)
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.orange.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.access_time, color: Colors.orange.shade700),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Daily readings for today will be available for entry after 08:00 AM IST.',
                            style: TextStyle(
                              color: Colors.orange.shade700,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
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
                        segments: [
                          ButtonSegment(
                            value: DisplayMode.readings,
                            label: const Text('Readings'),
                            icon: _EquipmentIcon(
                              type: 'readings',
                              color: _displayMode == DisplayMode.readings
                                  ? theme.colorScheme.onSecondaryContainer
                                  : theme.colorScheme.onSurface.withOpacity(
                                      0.6,
                                    ),
                              size: 18,
                            ),
                          ),
                          ButtonSegment(
                            value: DisplayMode.charts,
                            label: const Text('Charts'),
                            icon: _EquipmentIcon(
                              type: 'charts',
                              color: _displayMode == DisplayMode.charts
                                  ? theme.colorScheme.onSecondaryContainer
                                  : theme.colorScheme.onSurface.withOpacity(
                                      0.6,
                                    ),
                              size: 18,
                            ),
                          ),
                        ],
                        selected: {_displayMode},
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
                        style: IconButton.styleFrom(
                          backgroundColor: theme.colorScheme.primary
                              .withOpacity(0.1),
                          foregroundColor: theme.colorScheme.primary,
                        ),
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
                          child: Padding(
                            padding: const EdgeInsets.all(32.0),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.info_outline,
                                  size: 64,
                                  color: Colors.grey.shade400,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'No ${widget.frequencyType} readings found',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'for ${widget.substationName} in the period\n${DateFormat('dd.MMM.yyyy').format(widget.startDate)} - ${DateFormat('dd.MMM.yyyy').format(widget.endDate)}',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      : (_displayMode == DisplayMode.charts)
                      ? _buildChartsView()
                      : _buildReadingsListView(),
                ),
              ],
            ),
    );
  }

  bool showDailyReadingMessageForToday(
    bool isDailyReading,
    bool isCurrentDayAndBefore8AM,
  ) {
    return isDailyReading &&
        isCurrentDayAndBefore8AM &&
        widget.startDate == widget.endDate;
  }
}

// Extension to capitalize first letter
extension StringExtension on String {
  String capitalize() {
    if (isEmpty) {
      return this;
    }
    return "${this[0].toUpperCase()}${substring(1)}";
  }
}

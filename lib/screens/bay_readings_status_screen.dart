// lib/screens/bay_readings_status_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:collection/collection.dart';

import '../../models/bay_model.dart';
import '../../models/user_model.dart';
import '../../models/reading_models.dart';
import '../../models/logsheet_models.dart';
import '../../utils/snackbar_utils.dart';
import 'substation_dashboard/logsheet_entry_screen.dart';

// Enhanced Equipment Icon Widget
class _EquipmentIcon extends StatelessWidget {
  final String bayType;
  final Color color;
  final double size;

  const _EquipmentIcon({
    required this.bayType,
    required this.color,
    this.size = 24.0,
  });

  @override
  Widget build(BuildContext context) {
    IconData iconData;

    switch (bayType.toLowerCase()) {
      case 'transformer':
        iconData = Icons.electrical_services;
        break;
      case 'feeder':
        iconData = Icons.power;
        break;
      case 'line':
        iconData = Icons.power_input;
        break;
      case 'busbar':
        iconData = Icons.horizontal_rule;
        break;
      case 'capacitor bank':
        iconData = Icons.battery_charging_full;
        break;
      case 'reactor':
        iconData = Icons.device_hub;
        break;
      default:
        iconData = Icons.electrical_services;
        break;
    }

    return Icon(iconData, size: size, color: color);
  }
}

class BayReadingsStatusScreen extends StatefulWidget {
  final String substationId;
  final String substationName;
  final AppUser currentUser;
  final String frequencyType;
  final DateTime selectedDate;
  final int? selectedHour;

  const BayReadingsStatusScreen({
    super.key,
    required this.substationId,
    required this.substationName,
    required this.currentUser,
    required this.frequencyType,
    required this.selectedDate,
    this.selectedHour,
  });

  @override
  State<BayReadingsStatusScreen> createState() =>
      _BayReadingsStatusScreenState();
}

class _BayReadingsStatusScreenState extends State<BayReadingsStatusScreen> {
  bool _isLoading = true;
  List<Bay> _baysInSubstation = [];
  final Map<String, bool> _bayCompletionStatus = {};
  Map<String, List<ReadingField>> _bayMandatoryFields = {};
  Map<String, List<LogsheetEntry>> _logsheetEntriesForSlot = {};

  @override
  void initState() {
    super.initState();
    _loadDataAndCalculateStatuses();
  }

  Future<void> _loadDataAndCalculateStatuses() async {
    setState(() {
      _isLoading = true;
      _bayCompletionStatus.clear();
      _baysInSubstation.clear();
      _bayMandatoryFields.clear();
      _logsheetEntriesForSlot.clear();
    });

    try {
      // 1. Fetch all bays for the current substation
      final baysSnapshot = await FirebaseFirestore.instance
          .collection('bays')
          .where('substationId', isEqualTo: widget.substationId)
          .orderBy('name')
          .get();

      final Map<String, Bay> allBaysTempMap = {
        for (var doc in baysSnapshot.docs) doc.id: Bay.fromFirestore(doc),
      };

      final List<String> allBayIdsInSubstation = allBaysTempMap.keys.toList();

      if (allBayIdsInSubstation.isEmpty) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      // 2. Fetch all reading assignments for these bays
      final assignmentsSnapshot = await FirebaseFirestore.instance
          .collection('bayReadingAssignments')
          .where('bayId', whereIn: allBayIdsInSubstation)
          .get();

      final List<String> assignedBayIds = [];

      for (var doc in assignmentsSnapshot.docs) {
        final String bayId = doc['bayId'] as String;
        final assignedFieldsData =
            (doc.data() as Map)['assignedFields'] as List;
        final List<ReadingField> allFields = assignedFieldsData
            .map(
              (fieldMap) =>
                  ReadingField.fromMap(fieldMap as Map<String, dynamic>),
            )
            .toList();

        final List<ReadingField> relevantMandatoryFields = allFields
            .where(
              (field) =>
                  field.isMandatory &&
                  field.frequency.toString().split('.').last ==
                      widget.frequencyType,
            )
            .toList();

        _bayMandatoryFields[bayId] = relevantMandatoryFields;

        if (relevantMandatoryFields.isNotEmpty) {
          assignedBayIds.add(bayId);
        }
      }

      _baysInSubstation =
          assignedBayIds.map((id) => allBaysTempMap[id]!).toList()
            ..sort((a, b) => a.name.compareTo(b.name));

      if (_baysInSubstation.isEmpty) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      // 3. Fetch logsheet entries for the specific slot
      _logsheetEntriesForSlot.clear();
      DateTime queryStartTimestamp;
      DateTime queryEndTimestamp;

      if (widget.frequencyType == 'hourly' && widget.selectedHour != null) {
        queryStartTimestamp = DateTime(
          widget.selectedDate.year,
          widget.selectedDate.month,
          widget.selectedDate.day,
          widget.selectedHour!,
        );
        queryEndTimestamp = DateTime(
          widget.selectedDate.year,
          widget.selectedDate.month,
          widget.selectedDate.day,
          widget.selectedHour!,
          59,
          59,
          999,
        );
      } else {
        queryStartTimestamp = DateTime(
          widget.selectedDate.year,
          widget.selectedDate.month,
          widget.selectedDate.day,
        );
        queryEndTimestamp = DateTime(
          widget.selectedDate.year,
          widget.selectedDate.month,
          widget.selectedDate.day,
          23,
          59,
          59,
          999,
        );
      }

      final logsheetsSnapshot = await FirebaseFirestore.instance
          .collection('logsheetEntries')
          .where('substationId', isEqualTo: widget.substationId)
          .where('frequency', isEqualTo: widget.frequencyType)
          .where(
            'readingTimestamp',
            isGreaterThanOrEqualTo: Timestamp.fromDate(queryStartTimestamp),
          )
          .where(
            'readingTimestamp',
            isLessThanOrEqualTo: Timestamp.fromDate(queryEndTimestamp),
          )
          .get();

      for (var doc in logsheetsSnapshot.docs) {
        final entry = LogsheetEntry.fromFirestore(doc);
        _logsheetEntriesForSlot.putIfAbsent(entry.bayId, () => []).add(entry);
      }

      // 4. Calculate completion status for each bay
      _bayCompletionStatus.clear();
      for (var bay in _baysInSubstation) {
        final bool isBayCompleteForSlot = _isBayLogsheetCompleteForSlot(bay.id);
        _bayCompletionStatus[bay.id] = isBayCompleteForSlot;
      }
    } catch (e) {
      print("Error loading data for BayReadingsStatusScreen: $e");
      if (mounted) {
        SnackBarUtils.showSnackBar(
          context,
          'Failed to load data: $e',
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

  bool _isBayLogsheetCompleteForSlot(String bayId) {
    final List<ReadingField> mandatoryFields = _bayMandatoryFields[bayId] ?? [];
    if (mandatoryFields.isEmpty) {
      return true;
    }

    final relevantLogsheet = (_logsheetEntriesForSlot[bayId] ?? [])
        .firstWhereOrNull((entry) {
          final entryTimestamp = entry.readingTimestamp.toDate();
          if (widget.frequencyType == 'hourly' && widget.selectedHour != null) {
            return entryTimestamp.year == widget.selectedDate.year &&
                entryTimestamp.month == widget.selectedDate.month &&
                entryTimestamp.day == widget.selectedDate.day &&
                entryTimestamp.hour == widget.selectedHour;
          } else if (widget.frequencyType == 'daily') {
            return entryTimestamp.year == widget.selectedDate.year &&
                entryTimestamp.month == widget.selectedDate.month &&
                entryTimestamp.day == widget.selectedDate.day;
          }
          return false;
        });

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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    String slotTitle = DateFormat('dd.MMM.yyyy').format(widget.selectedDate);
    if (widget.frequencyType == 'hourly' && widget.selectedHour != null) {
      slotTitle +=
          ' - ${widget.selectedHour!.toString().padLeft(2, '0')}:00 Hr';
    } else if (widget.frequencyType == 'daily') {
      slotTitle += ' - Daily Reading';
    }

    // Calculate completion stats
    int completedBays = _bayCompletionStatus.values
        .where((status) => status)
        .length;
    int totalBays = _baysInSubstation.length;
    double completionPercentage = totalBays > 0
        ? (completedBays / totalBays) * 100
        : 0;

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'Bay Status',
          style: TextStyle(
            color: theme.colorScheme.onSurface,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: theme.colorScheme.onSurface),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Header with slot info and completion stats
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
                      Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              widget.frequencyType == 'hourly'
                                  ? Icons.access_time
                                  : Icons.calendar_today,
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
                                  slotTitle,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: theme.colorScheme.primary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  widget.substationName,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: theme.colorScheme.onSurface
                                        .withOpacity(0.7),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Completion Stats
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: theme.colorScheme.outline.withOpacity(0.2),
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                children: [
                                  Text(
                                    '$completedBays/$totalBays',
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w700,
                                      color: completedBays == totalBays
                                          ? Colors.green
                                          : Colors.orange,
                                    ),
                                  ),
                                  Text(
                                    'Completed',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: theme.colorScheme.onSurface
                                          .withOpacity(0.6),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              width: 1,
                              height: 40,
                              color: theme.colorScheme.outline.withOpacity(0.2),
                            ),
                            Expanded(
                              child: Column(
                                children: [
                                  Text(
                                    '${completionPercentage.toInt()}%',
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w700,
                                      color: completionPercentage == 100
                                          ? Colors.green
                                          : Colors.orange,
                                    ),
                                  ),
                                  Text(
                                    'Progress',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: theme.colorScheme.onSurface
                                          .withOpacity(0.6),
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
                ),

                // Bay list
                Expanded(
                  child: _baysInSubstation.isEmpty
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
                                  'No Assigned Bays Found',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'No bays with assigned readings found for ${widget.substationName} for this frequency and date. Please assign reading templates to bays in Asset Management.',
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
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          itemCount: _baysInSubstation.length,
                          itemBuilder: (context, index) {
                            final bay = _baysInSubstation[index];
                            final bool isBayCompleteForSlot =
                                _bayCompletionStatus[bay.id] ?? false;
                            final int mandatoryFieldsCount =
                                _bayMandatoryFields[bay.id]?.length ?? 0;

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
                                    color:
                                        (isBayCompleteForSlot
                                                ? Colors.green
                                                : Colors.red)
                                            .withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    isBayCompleteForSlot
                                        ? Icons.check_circle
                                        : Icons.cancel,
                                    color: isBayCompleteForSlot
                                        ? Colors.green
                                        : Colors.red,
                                    size: 24,
                                  ),
                                ),
                                title: Row(
                                  children: [
                                    _EquipmentIcon(
                                      bayType: bay.bayType,
                                      color: theme.colorScheme.primary,
                                      size: 16,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        bay.name,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 4),
                                    Text(
                                      '${bay.voltageLevel} ${bay.bayType}',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: theme.colorScheme.onSurface
                                            .withOpacity(0.6),
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Row(
                                      children: [
                                        Container(
                                          width: 8,
                                          height: 8,
                                          decoration: BoxDecoration(
                                            color: isBayCompleteForSlot
                                                ? Colors.green
                                                : Colors.red,
                                            borderRadius: BorderRadius.circular(
                                              4,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          isBayCompleteForSlot
                                              ? 'Readings complete'
                                              : 'Readings incomplete',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: isBayCompleteForSlot
                                                ? Colors.green
                                                : Colors.red,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        const Spacer(),
                                        Text(
                                          '$mandatoryFieldsCount fields',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: theme.colorScheme.onSurface
                                                .withOpacity(0.5),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                trailing: const Icon(
                                  Icons.arrow_forward_ios,
                                  size: 16,
                                ),
                                onTap: () {
                                  Navigator.of(context)
                                      .push(
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              LogsheetEntryScreen(
                                                substationId:
                                                    widget.substationId,
                                                substationName:
                                                    widget.substationName,
                                                bayId: bay.id,
                                                readingDate:
                                                    widget.selectedDate,
                                                frequency: widget.frequencyType,
                                                readingHour:
                                                    widget.selectedHour,
                                                currentUser: widget.currentUser,
                                              ),
                                        ),
                                      )
                                      .then(
                                        (_) => _loadDataAndCalculateStatuses(),
                                      );
                                },
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}

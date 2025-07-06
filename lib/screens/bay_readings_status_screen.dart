// lib/screens/bay_readings_status_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import '../../models/bay_model.dart';
import '../../models/user_model.dart';
import '../../models/reading_models.dart'; // For ReadingFieldDataType, ReadingFrequency
import '../../models/logsheet_models.dart'; // For LogsheetEntry
import '../../utils/snackbar_utils.dart';
import 'logsheet_entry_screen.dart'; // Screen 3: The detailed entry screen

class BayReadingsStatusScreen extends StatefulWidget {
  final String substationId;
  final String substationName;
  final AppUser currentUser;
  final String frequencyType; // 'hourly' or 'daily'
  final DateTime selectedDate;
  final int? selectedHour; // Only for hourly readings

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

  // Map to store completion status for each bay: {bayId: isComplete}
  final Map<String, bool> _bayCompletionStatus = {};

  // Data cached for efficient status checking
  Map<String, List<ReadingField>> _bayMandatoryFields = {};
  Map<String, List<LogsheetEntry>> _logsheetEntriesForSlot =
      {}; // Logsheets for the specific selected slot

  @override
  void initState() {
    super.initState();
    _loadDataAndCalculateStatuses();
  }

  Future<void> _loadDataAndCalculateStatuses() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // 1. Fetch all bays for the current substation
      final baysSnapshot = await FirebaseFirestore.instance
          .collection('bays')
          .where('substationId', isEqualTo: widget.substationId)
          .orderBy('name')
          .get();
      _baysInSubstation = baysSnapshot.docs
          .map((doc) => Bay.fromFirestore(doc))
          .toList();

      // 2. Fetch all reading assignments for these bays to get mandatory fields
      final List<String> bayIds = _baysInSubstation
          .map((bay) => bay.id)
          .toList();
      if (bayIds.isEmpty) {
        _isLoading = false;
        setState(() {});
        return;
      }
      final assignmentsSnapshot = await FirebaseFirestore.instance
          .collection('bayReadingAssignments')
          .where('bayId', whereIn: bayIds)
          .get();

      _bayMandatoryFields.clear();
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

        // Store only the mandatory fields relevant to this frequencyType
        _bayMandatoryFields[doc['bayId'] as String] = allFields
            .where(
              (field) =>
                  field.isMandatory &&
                  field.frequency.toString().split('.').last ==
                      widget.frequencyType,
            )
            .toList();
      }

      // 3. Fetch ALL logsheet entries for the SPECIFIC SLOT (date + hour/day)
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

      // 4. Calculate completion status for each bay for this specific slot
      _bayCompletionStatus.clear();
      for (var bay in _baysInSubstation) {
        final bool isComplete = _isBayLogsheetCompleteForSlot(bay.id);
        _bayCompletionStatus[bay.id] = isComplete;
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
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Helper function to check if a specific bay's logsheet is complete for THIS slot
  bool _isBayLogsheetCompleteForSlot(String bayId) {
    final List<ReadingField> mandatoryFields = _bayMandatoryFields[bayId] ?? [];
    if (mandatoryFields.isEmpty) {
      return true; // No mandatory fields for this bay/frequency, so considered complete
    }

    // Find the logsheet entry for this bay and this specific slot from cached data
    final relevantLogsheet = (_logsheetEntriesForSlot[bayId] ?? []).firstWhere(
      (entry) {
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
      },
      orElse: () => LogsheetEntry(
        // Dummy entry if not found
        bayId: '',
        templateId: '',
        readingTimestamp: Timestamp.now(),
        recordedBy: '',
        recordedAt: Timestamp.now(),
        values: {},
        frequency: '',
        readingHour: null,
        substationId: '', // Added dummy substationId
        modificationReason: '', // Added required parameter
      ),
    );

    if (relevantLogsheet.bayId.isEmpty) {
      // Dummy entry found, meaning no logsheet
      return false;
    }

    // Check if all mandatory fields in this logsheet entry have non-empty values
    return mandatoryFields.every((field) {
      final value = relevantLogsheet.values[field.name];
      if (field.dataType ==
              ReadingFieldDataType.boolean.toString().split('.').last &&
          value is Map &&
          value.containsKey('value')) {
        return value['value'] !=
            null; // Boolean value itself matters for completion
      }
      return value != null && (value is! String || value.isNotEmpty);
    });
  }

  @override
  Widget build(BuildContext context) {
    String slotTitle = DateFormat('dd.MMM.yyyy').format(widget.selectedDate);
    if (widget.frequencyType == 'hourly' && widget.selectedHour != null) {
      slotTitle +=
          ' - ${widget.selectedHour!.toString().padLeft(2, '0')}:00 Hr';
    } else if (widget.frequencyType == 'daily') {
      slotTitle += ' - Daily Reading';
    }

    return Scaffold(
      appBar: AppBar(title: Text('Bays for $slotTitle')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _baysInSubstation.isEmpty
          ? Center(
              child: Text(
                'No bays found for ${widget.substationName}.',
                style: TextStyle(
                  fontStyle: FontStyle.italic,
                  color: Colors.grey.shade600,
                ),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16.0),
              itemCount: _baysInSubstation.length,
              itemBuilder: (context, index) {
                final bay = _baysInSubstation[index];
                final bool isBayCompleteForSlot =
                    _bayCompletionStatus[bay.id] ?? false;

                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 8.0),
                  elevation: 2,
                  child: ListTile(
                    leading: Icon(
                      isBayCompleteForSlot ? Icons.check_circle : Icons.cancel,
                      color: isBayCompleteForSlot ? Colors.green : Colors.red,
                    ),
                    title: Text(
                      '${bay.name} (${bay.voltageLevel} ${bay.bayType})',
                    ),
                    subtitle: Text(
                      isBayCompleteForSlot
                          ? 'Readings complete'
                          : 'Readings incomplete',
                    ),
                    trailing: const Icon(Icons.arrow_forward_ios),
                    onTap: () {
                      Navigator.of(context)
                          .push(
                            MaterialPageRoute(
                              builder: (context) => LogsheetEntryScreen(
                                substationId: widget.substationId,
                                substationName: widget.substationName,
                                bayId: bay.id,
                                readingDate: widget.selectedDate,
                                frequency: widget.frequencyType,
                                readingHour: widget.selectedHour,
                                currentUser: widget.currentUser,
                              ),
                            ),
                          )
                          .then(
                            (_) => _loadDataAndCalculateStatuses(),
                          ); // Update status on return
                    },
                  ),
                );
              },
            ),
    );
  }
}

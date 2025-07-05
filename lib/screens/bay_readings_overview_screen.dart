// lib/screens/bay_readings_overview_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import '../../models/bay_model.dart';
import '../../models/user_model.dart';
import '../../models/reading_models.dart';
import '../../models/logsheet_models.dart';
import '../../utils/snackbar_utils.dart';
import 'bay_readings_status_screen.dart';

class BayReadingsOverviewScreen extends StatefulWidget {
  final String substationId;
  final String substationName;
  final AppUser currentUser;
  final String frequencyType;

  const BayReadingsOverviewScreen({
    super.key,
    required this.substationId,
    required this.substationName,
    required this.currentUser,
    required this.frequencyType,
  });

  @override
  State<BayReadingsOverviewScreen> createState() =>
      _ReadingSlotOverviewScreenState();
}

class _ReadingSlotOverviewScreenState extends State<BayReadingsOverviewScreen> {
  bool _isLoading = true;
  DateTime _selectedDate = DateTime.now();

  final Map<String, bool> _overallSlotCompletionStatus = {};
  List<Bay> _allBaysInSubstation = [];
  Map<String, List<ReadingField>> _bayMandatoryFields = {};
  Map<String, Map<String, LogsheetEntry>> _logsheetEntriesForDate = {};
  bool _hasAssignments = false;

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
    if (widget.substationId != oldWidget.substationId) {
      if (widget.substationId.isNotEmpty) {
        _loadAllDataAndCalculateStatuses();
      } else {
        setState(() {
          _isLoading = false;
          _allBaysInSubstation.clear();
          _bayMandatoryFields.clear();
          _logsheetEntriesForDate.clear();
          _overallSlotCompletionStatus.clear();
          _hasAssignments = false;
        });
      }
    }
  }

  Future<void> _loadAllDataAndCalculateStatuses() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _hasAssignments = false;
    });

    try {
      final baysSnapshot = await FirebaseFirestore.instance
          .collection('bays')
          .where('substationId', isEqualTo: widget.substationId)
          .orderBy('name')
          .get();
      _allBaysInSubstation = baysSnapshot.docs
          .map((doc) => Bay.fromFirestore(doc))
          .toList();

      if (_allBaysInSubstation.isEmpty) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      final bayIds = _allBaysInSubstation.map((bay) => bay.id).toList();

      final assignmentsSnapshot = await FirebaseFirestore.instance
          .collection('bayReadingAssignments')
          .where('bayId', whereIn: bayIds)
          .get();

      if (assignmentsSnapshot.docs.isEmpty) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }
      _hasAssignments = true;

      _bayMandatoryFields.clear();
      for (var doc in assignmentsSnapshot.docs) {
        final assignedFieldsData =
            doc.data()['assignedFields'] as List<dynamic>;
        final allFields = assignedFieldsData
            .map(
              (fieldMap) =>
                  ReadingField.fromMap(fieldMap as Map<String, dynamic>),
            )
            .toList();
        _bayMandatoryFields[doc['bayId']] = allFields
            .where(
              (field) =>
                  field.isMandatory &&
                  field.frequency.toString().split('.').last ==
                      widget.frequencyType,
            )
            .toList();
      }

      DateTime startOfPeriod;
      DateTime endOfPeriod;

      if (widget.frequencyType == 'monthly') {
        startOfPeriod = DateTime(_selectedDate.year, _selectedDate.month, 1);
        endOfPeriod = DateTime(
          _selectedDate.year,
          _selectedDate.month + 1,
          0,
          23,
          59,
          59,
          999,
        );
      } else {
        startOfPeriod = DateTime(
          _selectedDate.year,
          _selectedDate.month,
          _selectedDate.day,
        );
        endOfPeriod = DateTime(
          _selectedDate.year,
          _selectedDate.month,
          _selectedDate.day,
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
            isGreaterThanOrEqualTo: Timestamp.fromDate(startOfPeriod),
          )
          .where(
            'readingTimestamp',
            isLessThanOrEqualTo: Timestamp.fromDate(endOfPeriod),
          )
          .get();

      _logsheetEntriesForDate.clear();
      for (var doc in logsheetsSnapshot.docs) {
        final entry = LogsheetEntry.fromFirestore(doc);
        final slotKey = _getTimeKeyFromLogsheetEntry(entry);
        _logsheetEntriesForDate.putIfAbsent(entry.bayId, () => {})[slotKey] =
            entry;
      }

      _calculateSlotCompletionStatuses();
    } catch (e) {
      if (mounted)
        SnackBarUtils.showSnackBar(
          context,
          'Failed to load data: $e',
          isError: true,
        );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _getTimeKeyFromLogsheetEntry(LogsheetEntry entry) {
    switch (entry.frequency) {
      case 'hourly':
        return entry.readingHour!.toString().padLeft(2, '0');
      case 'daily':
        return DateFormat('yyyy-MM-dd').format(entry.readingTimestamp.toDate());
      case 'monthly':
        return DateFormat('yyyy-MM').format(entry.readingTimestamp.toDate());
      default:
        return '';
    }
  }

  bool _isBayLogsheetCompleteForSlot(String bayId, String slotTimeKey) {
    final relevantLogsheet = _logsheetEntriesForDate[bayId]?[slotTimeKey];
    if (relevantLogsheet == null) {
      return false; // **FIX**: If no logsheet exists, it is not complete.
    }

    final mandatoryFields = _bayMandatoryFields[bayId] ?? [];
    if (mandatoryFields.isEmpty) {
      return true;
    }

    return mandatoryFields.every((field) {
      final value = relevantLogsheet.values[field.name];
      if (field.dataType == ReadingFieldDataType.boolean) {
        return value is Map && value['value'] != null;
      }
      return value != null && (value is! String || value.isNotEmpty);
    });
  }

  void _calculateSlotCompletionStatuses() {
    _overallSlotCompletionStatus.clear();
    final slotKeys = _generateTimeSlotKeys();

    for (String slotKey in slotKeys) {
      bool allBaysComplete = _allBaysInSubstation.every((bay) {
        return _isBayLogsheetCompleteForSlot(bay.id, slotKey);
      });
      _overallSlotCompletionStatus[slotKey] = allBaysComplete;
    }
  }

  List<String> _generateTimeSlotKeys() {
    if (!_hasAssignments) {
      return [];
    }

    List<String> keys = [];
    DateTime now = DateTime.now();
    bool isToday = DateUtils.isSameDay(_selectedDate, now);

    if (widget.frequencyType == 'hourly') {
      for (int hour = 0; hour < 24; hour++) {
        if (isToday && hour > now.hour) continue;
        keys.add(hour.toString().padLeft(2, '0'));
      }
    } else if (widget.frequencyType == 'daily') {
      if (!isToday || (isToday && now.hour >= 8)) {
        keys.add(DateFormat('yyyy-MM-dd').format(_selectedDate));
      }
    } else if (widget.frequencyType == 'monthly') {
      bool isFirstDayOfMonth = _selectedDate.day == 1;
      if (isFirstDayOfMonth) {
        if (!isToday || (isToday && now.hour >= 8)) {
          keys.add(DateFormat('yyyy-MM').format(_selectedDate));
        }
      }
    }
    return keys.reversed.toList();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() => _selectedDate = picked);
      await _loadAllDataAndCalculateStatuses();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.substationId.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Text(
            'Please select a substation to view data.',
            textAlign: TextAlign.center,
            style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey),
          ),
        ),
      );
    }

    return _isLoading
        ? const Center(child: CircularProgressIndicator())
        : Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Readings For: ${DateFormat.yMMMMd().format(_selectedDate)}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    IconButton(
                      icon: const Icon(Icons.calendar_today),
                      onPressed: () => _selectDate(context),
                    ),
                  ],
                ),
              ),
              Expanded(child: _buildSlotList()),
            ],
          );
  }

  Widget _buildSlotList() {
    final slotKeys = _generateTimeSlotKeys();

    if (!_hasAssignments) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            'No reading templates have been assigned to the bays in this substation.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontStyle: FontStyle.italic,
              color: Colors.grey.shade600,
            ),
          ),
        ),
      );
    }

    if (slotKeys.isEmpty && !_isLoading) {
      String message = 'No reading slots available for the selected period.';
      final isToday = DateUtils.isSameDay(_selectedDate, DateTime.now());

      if (widget.frequencyType == 'daily' && isToday) {
        message = 'Daily readings for today will be available after 08:00 AM.';
      } else if (widget.frequencyType == 'monthly') {
        if (_selectedDate.day != 1) {
          message =
              'Monthly readings can only be entered on the 1st of the month.';
        } else if (isToday) {
          message = 'Monthly readings for today are available after 08:00 AM.';
        }
      }

      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontStyle: FontStyle.italic,
              color: Colors.grey.shade600,
            ),
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      itemCount: slotKeys.length,
      itemBuilder: (context, index) {
        final slotKey = slotKeys[index];
        final isComplete = _overallSlotCompletionStatus[slotKey] ?? false;

        String slotTitle;
        int? selectedHour;

        switch (widget.frequencyType) {
          case 'hourly':
            slotTitle = '$slotKey:00 Hr';
            selectedHour = int.parse(slotKey);
            break;
          case 'daily':
            slotTitle = 'Daily Reading';
            break;
          case 'monthly':
            slotTitle =
                'Monthly Reading for ${DateFormat('MMMM yyyy').format(_selectedDate)}';
            break;
          default:
            slotTitle = 'Reading';
        }

        return Card(
          margin: const EdgeInsets.symmetric(vertical: 8.0),
          elevation: 2,
          child: ListTile(
            leading: Icon(
              isComplete ? Icons.check_circle : Icons.cancel,
              color: isComplete ? Colors.green : Colors.red,
            ),
            title: Text(slotTitle),
            subtitle: Text('Status: ${isComplete ? 'Complete' : 'Pending'}'),
            trailing: const Icon(Icons.arrow_forward_ios),
            onTap: () {
              Navigator.of(context)
                  .push(
                    MaterialPageRoute(
                      builder: (context) => BayReadingsStatusScreen(
                        substationId: widget.substationId,
                        substationName: widget.substationName,
                        currentUser: widget.currentUser,
                        frequencyType: widget.frequencyType,
                        selectedDate: _selectedDate,
                        selectedHour: selectedHour,
                      ),
                    ),
                  )
                  .then((_) => _loadAllDataAndCalculateStatuses());
            },
          ),
        );
      },
    );
  }
}

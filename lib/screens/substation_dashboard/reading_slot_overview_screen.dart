// lib/screens/bay_readings_overview_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import '../../../models/bay_model.dart';
import '../../../models/user_model.dart';
import '../../../models/reading_models.dart'; // For ReadingFieldDataType, ReadingFrequency
import '../../../models/logsheet_models.dart'; // For LogsheetEntry
import '../../../utils/snackbar_utils.dart';
import 'bay_readings_status_screen.dart'; // Screen 2: List of bays for a slot

class BayReadingsOverviewScreen extends StatefulWidget {
  final String substationId;
  final String substationName;
  final AppUser currentUser;
  final String frequencyType; // 'hourly' or 'daily'

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
  DateTime _selectedDate = DateTime.now(); // Date for which to view slots

  // Maps to store computed completion statuses for each slot (e.g., '00', '2025-07-01')
  // Slot Key -> IsComplete (True if ALL bays are complete for that slot)
  final Map<String, bool> _overallSlotCompletionStatus = {};

  // Data cached for efficient status checking
  List<Bay> _allBaysInSubstation = [];
  Map<String, List<ReadingField>> _bayMandatoryFields = {};
  Map<String, Map<String, LogsheetEntry>> _logsheetEntriesForDate =
      {}; // bayId -> slotKey -> LogsheetEntry

  @override
  void initState() {
    super.initState();
    _loadAllDataAndCalculateStatuses();
  }

  Future<void> _loadAllDataAndCalculateStatuses() async {
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
      _allBaysInSubstation = baysSnapshot.docs
          .map((doc) => Bay.fromFirestore(doc))
          .toList();

      // 2. Fetch all reading assignments for these bays to get mandatory fields
      final List<String> bayIds = _allBaysInSubstation
          .map((bay) => bay.id)
          .toList();
      if (bayIds.isEmpty) {
        // No bays, nothing to do
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
            (doc.data())['assignedFields'] as List<dynamic>;
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

      // 3. Fetch ALL logsheet entries for the selected date and frequencyType
      // This is crucial for efficient in-memory processing.
      _logsheetEntriesForDate.clear();
      final startOfSelectedDate = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
      );
      final endOfSelectedDate = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        23,
        59,
        59,
        999,
      );

      final logsheetsSnapshot = await FirebaseFirestore.instance
          .collection('logsheetEntries')
          .where(
            'substationId',
            isEqualTo: widget.substationId,
          ) // Requires substationId in logsheet entry model
          .where('frequency', isEqualTo: widget.frequencyType)
          .where(
            'readingTimestamp',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startOfSelectedDate),
          )
          .where(
            'readingTimestamp',
            isLessThanOrEqualTo: Timestamp.fromDate(endOfSelectedDate),
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
      print("Error loading data for ReadingSlotOverviewScreen: $e");
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

  // Helper to get the time key string from a logsheet entry based on frequency
  String _getTimeKeyFromLogsheetEntry(LogsheetEntry entry) {
    if (entry.frequency == ReadingFrequency.hourly.toString().split('.').last &&
        entry.readingHour != null) {
      return entry.readingHour!.toString().padLeft(2, '0');
    } else if (entry.frequency ==
        ReadingFrequency.daily.toString().split('.').last) {
      return DateFormat('yyyy-MM-dd').format(entry.readingTimestamp.toDate());
    }
    return ''; // Should not happen for hourly/daily
  }

  // Function to determine if a specific bay's logsheet is complete for a given slot
  bool _isBayLogsheetCompleteForSlot(
    String bayId,
    String slotTimeKey, // e.g., '00' for hourly, '2025-07-01' for daily
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
        return value['value'] !=
            null; // Boolean value itself matters for completion
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
        allBaysCompleteForThisSlot =
            true; // If no bays, it's vacuously complete
      } else {
        for (Bay bay in _allBaysInSubstation) {
          if (!_bayMandatoryFields.containsKey(bay.id) ||
              _bayMandatoryFields[bay.id]!.isEmpty) {
            // If bay has no mandatory fields for this frequency, it's considered complete for this slot.
            continue;
          }
          if (!_isBayLogsheetCompleteForSlot(bay.id, slotKey)) {
            allBaysCompleteForThisSlot = false;
            break; // One incomplete bay makes the whole slot incomplete
          }
        }
      }
      _overallSlotCompletionStatus[slotKey] = allBaysCompleteForThisSlot;
    }
  }

  List<String> _generateTimeSlotKeys() {
    List<String> keys = [];
    DateTime now = DateTime.now();
    bool isCurrentDay = DateUtils.isSameDay(_selectedDate, now);

    if (widget.frequencyType == 'hourly') {
      // Start from 01:00 and go through 24 hours (01, 02, ..., 23, 00)
      for (int i = 0; i < 24; i++) {
        int hour = (i + 1) % 24; // This gives us: 1, 2, 3, ..., 23, 0

        // Calculate the actual DateTime for this slot
        DateTime slotDateTime = DateTime(
          _selectedDate.year,
          _selectedDate.month,
          _selectedDate.day,
          hour,
        );

        // For hour 00, it's actually the next day
        if (hour == 0) {
          slotDateTime = slotDateTime.add(const Duration(days: 1));
        }

        // Only show elapsed hours for the current date cycle
        if (isCurrentDay && slotDateTime.isAfter(now)) {
          continue; // Skip future hours
        }

        keys.add(hour.toString().padLeft(2, '0'));
      }
    } else if (widget.frequencyType == 'daily') {
      // Keep daily logic unchanged - still starts at 08:00 AM
      if (isCurrentDay && now.hour < 8) {
        return [];
      }
      keys.add(DateFormat('yyyy-MM-dd').format(_selectedDate));
    }
    return keys;
  }

  Future<void> _selectDate(BuildContext context) async {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000, 1, 1),
      lastDate: DateTime.now(), // Disable future dates
      builder: (context, child) {
        return Theme(
          data: theme.copyWith(
            colorScheme: theme.colorScheme.copyWith(
              surface: isDarkMode ? const Color(0xFF2C2C2E) : Colors.white,
              onSurface: isDarkMode ? Colors.white : Colors.black87,
            ),
            dialogBackgroundColor: isDarkMode
                ? const Color(0xFF2C2C2E)
                : Colors.white,
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
      await _loadAllDataAndCalculateStatuses(); // Recalculate statuses for new date
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    // Check for the "Daily reading available after 08:00" message condition
    bool showDailyReadingMessage =
        widget.frequencyType == 'daily' &&
        DateUtils.isSameDay(_selectedDate, DateTime.now()) &&
        DateTime.now().hour < 8;

    return Container(
      color: isDarkMode ? const Color(0xFF1C1C1E) : const Color(0xFFFAFAFA),
      child: _isLoading
          ? Center(
              child: Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: isDarkMode ? const Color(0xFF2C2C2E) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: isDarkMode
                          ? Colors.black.withOpacity(0.3)
                          : Colors.black.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: theme.colorScheme.primary),
                    const SizedBox(height: 16),
                    Text(
                      'Loading readings...',
                      style: TextStyle(
                        fontSize: 16,
                        color: isDarkMode ? Colors.white : Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
            )
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Container(
                    decoration: BoxDecoration(
                      color: isDarkMode
                          ? const Color(0xFF2C2C2E)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: isDarkMode
                              ? Colors.black.withOpacity(0.3)
                              : Colors.black.withOpacity(0.05),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.calendar_today,
                          color: theme.colorScheme.primary,
                          size: 20,
                        ),
                      ),
                      title: Text(
                        'Readings Date',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: isDarkMode ? Colors.white : Colors.black87,
                        ),
                      ),
                      subtitle: Text(
                        DateFormat('EEEE, dd MMMM yyyy').format(_selectedDate),
                        style: TextStyle(
                          fontSize: 14,
                          color: isDarkMode
                              ? Colors.white.withOpacity(0.7)
                              : theme.colorScheme.onSurface.withOpacity(0.7),
                        ),
                      ),
                      trailing: Icon(
                        Icons.arrow_forward_ios,
                        color: theme.colorScheme.primary,
                        size: 16,
                      ),
                      onTap: () => _selectDate(context),
                    ),
                  ),
                ),
                Expanded(
                  child: showDailyReadingMessage
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(32.0),
                            child: Container(
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: isDarkMode
                                      ? [
                                          Colors.orange.shade800.withOpacity(
                                            0.3,
                                          ),
                                          Colors.amber.shade800.withOpacity(
                                            0.3,
                                          ),
                                        ]
                                      : [
                                          Colors.orange.shade50,
                                          Colors.amber.shade50,
                                        ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: Colors.orange.withOpacity(0.3),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: isDarkMode
                                        ? Colors.black.withOpacity(0.3)
                                        : Colors.orange.withOpacity(0.1),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.orange.withOpacity(0.2),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.schedule,
                                      color: Colors.orange.shade700,
                                      size: 32,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'Daily Readings Available After 08:00 AM',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.orange.shade700,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Daily readings for today will be available for entry after 08:00 AM IST.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: isDarkMode
                                          ? Colors.white.withOpacity(0.7)
                                          : Colors.grey.shade700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        )
                      : _generateTimeSlotKeys().isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(32.0),
                            child: Container(
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color: isDarkMode
                                    ? const Color(0xFF2C2C2E)
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: isDarkMode
                                        ? Colors.black.withOpacity(0.3)
                                        : Colors.black.withOpacity(0.05),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.info_outline,
                                    size: 48,
                                    color: isDarkMode
                                        ? Colors.white.withOpacity(0.4)
                                        : Colors.grey.shade400,
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'No Slots Available',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                      color: isDarkMode
                                          ? Colors.white.withOpacity(0.7)
                                          : Colors.grey.shade600,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'No reading slots are available for the selected date.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: isDarkMode
                                          ? Colors.white.withOpacity(0.5)
                                          : Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          itemCount: _generateTimeSlotKeys().length,
                          itemBuilder: (context, index) {
                            final slotKey = _generateTimeSlotKeys()[index];
                            final bool isSlotComplete =
                                _overallSlotCompletionStatus[slotKey] ?? false;

                            String slotTitle;
                            DateTime
                            slotDateTime; // Represents the start of the slot
                            if (widget.frequencyType == 'hourly') {
                              int hourValue = int.parse(slotKey);
                              slotTitle = '${slotKey}:00 Hr';

                              slotDateTime = DateTime(
                                _selectedDate.year,
                                _selectedDate.month,
                                _selectedDate.day,
                                hourValue,
                              );

                              // For hour 00, it's actually the next day at midnight
                              if (hourValue == 0) {
                                slotDateTime = slotDateTime.add(
                                  const Duration(days: 1),
                                );
                              }
                            } else {
                              // daily - keep unchanged
                              slotTitle = 'Daily Reading';
                              slotDateTime =
                                  _selectedDate; // Use the selected date itself
                            }

                            // Check if the slot is in the future for the current date
                            final bool isFutureSlot =
                                DateUtils.isSameDay(
                                  slotDateTime,
                                  DateTime.now(),
                                ) &&
                                slotDateTime.isAfter(DateTime.now());

                            // Determine if the slot should be disabled
                            final bool isDisabled =
                                isFutureSlot; // Future slots are disabled

                            return Container(
                              margin: const EdgeInsets.symmetric(vertical: 6.0),
                              decoration: BoxDecoration(
                                color: isDarkMode
                                    ? const Color(0xFF2C2C2E)
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: isDarkMode
                                        ? Colors.black.withOpacity(0.3)
                                        : Colors.black.withOpacity(0.05),
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
                                        : (isSlotComplete
                                              ? Colors.green.withOpacity(0.1)
                                              : Colors.red.withOpacity(0.1)),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: isDisabled
                                          ? Colors.grey.withOpacity(0.3)
                                          : (isSlotComplete
                                                ? Colors.green.withOpacity(0.3)
                                                : Colors.red.withOpacity(0.3)),
                                    ),
                                  ),
                                  child: Icon(
                                    isSlotComplete
                                        ? Icons.check_circle
                                        : Icons.cancel,
                                    color: isDisabled
                                        ? Colors.grey
                                        : (isSlotComplete
                                              ? Colors.green
                                              : Colors.red),
                                    size: 24,
                                  ),
                                ),
                                title: Text(
                                  '${DateFormat('dd.MMM.yyyy').format(_selectedDate)} - $slotTitle',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: isDisabled
                                        ? (isDarkMode
                                              ? Colors.grey.shade600
                                              : Colors.grey)
                                        : (isDarkMode
                                              ? Colors.white
                                              : Colors.black87),
                                  ),
                                ),
                                subtitle: Text(
                                  isSlotComplete
                                      ? 'All readings completed'
                                      : 'Readings incomplete',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: isDisabled
                                        ? (isDarkMode
                                              ? Colors.grey.shade700
                                              : Colors.grey.shade500)
                                        : (isSlotComplete
                                              ? Colors.green.shade600
                                              : Colors.red.shade600),
                                  ),
                                ),
                                trailing: Icon(
                                  Icons.arrow_forward_ios,
                                  color: isDisabled
                                      ? (isDarkMode
                                            ? Colors.grey.shade600
                                            : Colors.grey)
                                      : theme.colorScheme.primary,
                                  size: 16,
                                ),
                                onTap: isDisabled
                                    ? null // Disable tap for future slots
                                    : () {
                                        Navigator.of(context)
                                            .push(
                                              MaterialPageRoute(
                                                builder: (context) =>
                                                    BayReadingsStatusScreen(
                                                      substationId:
                                                          widget.substationId,
                                                      substationName:
                                                          widget.substationName,
                                                      currentUser:
                                                          widget.currentUser,
                                                      frequencyType:
                                                          widget.frequencyType,
                                                      selectedDate:
                                                          _selectedDate,
                                                      selectedHour:
                                                          widget.frequencyType ==
                                                              'hourly'
                                                          ? int.parse(slotKey)
                                                          : null,
                                                    ),
                                              ),
                                            )
                                            .then(
                                              (_) =>
                                                  _loadAllDataAndCalculateStatuses(), // Update status on return
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

// Extension to capitalize first letter
extension StringExtension on String {
  String capitalize() {
    if (isEmpty) {
      return this;
    }
    return "${this[0].toUpperCase()}${substring(1)}";
  }
}

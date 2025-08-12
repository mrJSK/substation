import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../models/user_model.dart';
import '../../models/bay_model.dart';
import '../../models/reading_models.dart';
import '../../utils/snackbar_utils.dart';
import '../bay_readings_status_screen.dart';

class SubstationUserOperationsTab extends StatefulWidget {
  final String substationId;
  final String substationName;
  final AppUser currentUser;
  final DateTime selectedDate;

  const SubstationUserOperationsTab({
    super.key,
    required this.substationId,
    required this.substationName,
    required this.currentUser,
    required this.selectedDate,
  });

  @override
  State<SubstationUserOperationsTab> createState() =>
      _SubstationUserOperationsTabState();
}

class _SubstationUserOperationsTabState
    extends State<SubstationUserOperationsTab> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _hourlySlots = [];
  Map<String, bool> _slotCompletionStatus = {};
  List<Bay> _baysWithHourlyAssignments = [];
  bool _hasAnyBaysWithReadings = false;

  @override
  void initState() {
    super.initState();
    _loadHourlySlots();
  }

  @override
  void didUpdateWidget(SubstationUserOperationsTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedDate != widget.selectedDate ||
        oldWidget.substationId != widget.substationId) {
      _loadHourlySlots();
    }
  }

  Future<void> _loadHourlySlots() async {
    if (widget.substationId.isEmpty) {
      setState(() {
        _isLoading = false;
        _hourlySlots = [];
        _hasAnyBaysWithReadings = false;
      });
      return;
    }

    setState(() => _isLoading = true);

    try {
      // First check if there are any bays with hourly reading assignments
      await _checkForBaysWithHourlyAssignments();

      if (!_hasAnyBaysWithReadings) {
        setState(() {
          _isLoading = false;
          _hourlySlots = [];
        });
        return;
      }

      final DateTime now = DateTime.now();
      final bool isToday = DateUtils.isSameDay(widget.selectedDate, now);

      _hourlySlots.clear();
      _slotCompletionStatus.clear();

      // Generate hourly slots (0-23)
      for (int hour = 0; hour < 24; hour++) {
        final DateTime slotDateTime = DateTime(
          widget.selectedDate.year,
          widget.selectedDate.month,
          widget.selectedDate.day,
          hour,
        );

        // Skip future hours for today
        if (isToday && hour > now.hour) {
          continue;
        }

        final bool isCurrentHour = isToday && hour == now.hour;
        final bool isPastHour = isToday && hour < now.hour;

        _hourlySlots.add({
          'hour': hour,
          'displayTime': '${hour.toString().padLeft(2, '0')}:00',
          'slotDateTime': slotDateTime,
          'isCurrentHour': isCurrentHour,
          'isPastHour': isPastHour,
          'isFuture': false,
        });
      }

      // Check completion status for each slot
      await _checkSlotCompletionStatus();
    } catch (e) {
      if (mounted) {
        SnackBarUtils.showSnackBar(
          context,
          'Error loading hourly slots: $e',
          isError: true,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _checkForBaysWithHourlyAssignments() async {
    try {
      // Get all bays for this substation
      final baysSnapshot = await FirebaseFirestore.instance
          .collection('bays')
          .where('substationId', isEqualTo: widget.substationId)
          .get();

      if (baysSnapshot.docs.isEmpty) {
        _hasAnyBaysWithReadings = false;
        _baysWithHourlyAssignments = [];
        return;
      }

      List<String> bayIds = baysSnapshot.docs.map((doc) => doc.id).toList();
      _baysWithHourlyAssignments.clear();

      // Check for reading assignments with hourly frequency
      final assignmentsSnapshot = await FirebaseFirestore.instance
          .collection('bayReadingAssignments')
          .where('bayId', whereIn: bayIds)
          .get();

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

        // Check if there are any mandatory hourly fields
        final hasHourlyMandatoryFields = allFields.any(
          (field) =>
              field.isMandatory &&
              field.frequency.toString().split('.').last == 'hourly',
        );

        if (hasHourlyMandatoryFields) {
          final Bay bay = Bay.fromFirestore(
            baysSnapshot.docs.firstWhere((bayDoc) => bayDoc.id == bayId),
          );
          _baysWithHourlyAssignments.add(bay);
        }
      }

      _hasAnyBaysWithReadings = _baysWithHourlyAssignments.isNotEmpty;
    } catch (e) {
      print('Error checking for bays with hourly assignments: $e');
      _hasAnyBaysWithReadings = false;
      _baysWithHourlyAssignments = [];
    }
  }

  Future<void> _checkSlotCompletionStatus() async {
    try {
      if (_baysWithHourlyAssignments.isEmpty) {
        for (var slot in _hourlySlots) {
          _slotCompletionStatus['${slot['hour']}'] = true;
        }
        return;
      }

      // Check each hour slot
      for (var slot in _hourlySlots) {
        final int hour = slot['hour'];
        bool allBaysComplete = true;

        // Check if all bays with hourly assignments have readings for this hour
        for (var bay in _baysWithHourlyAssignments) {
          final logsheetQuery = await FirebaseFirestore.instance
              .collection('logsheetEntries')
              .where('bayId', isEqualTo: bay.id)
              .where('frequency', isEqualTo: 'hourly')
              .where('readingHour', isEqualTo: hour)
              .where(
                'readingTimestamp',
                isGreaterThanOrEqualTo: Timestamp.fromDate(
                  DateTime(
                    widget.selectedDate.year,
                    widget.selectedDate.month,
                    widget.selectedDate.day,
                  ),
                ),
              )
              .where(
                'readingTimestamp',
                isLessThan: Timestamp.fromDate(
                  DateTime(
                    widget.selectedDate.year,
                    widget.selectedDate.month,
                    widget.selectedDate.day + 1,
                  ),
                ),
              )
              .limit(1)
              .get();

          if (logsheetQuery.docs.isEmpty) {
            allBaysComplete = false;
            break;
          }
        }

        _slotCompletionStatus['$hour'] = allBaysComplete;
      }
    } catch (e) {
      print('Error checking slot completion: $e');
    }
  }

  Color _getSlotStatusColor(Map<String, dynamic> slot) {
    final bool isComplete = _slotCompletionStatus['${slot['hour']}'] ?? false;

    if (isComplete) {
      return Colors.green;
    } else if (slot['isCurrentHour']) {
      return Colors.orange;
    } else if (slot['isPastHour']) {
      return Colors.red;
    } else {
      return Colors.grey;
    }
  }

  IconData _getSlotStatusIcon(Map<String, dynamic> slot) {
    final bool isComplete = _slotCompletionStatus['${slot['hour']}'] ?? false;

    if (isComplete) {
      return Icons.check_circle;
    } else if (slot['isCurrentHour']) {
      return Icons.access_time;
    } else {
      return Icons.cancel;
    }
  }

  String _getSlotStatusText(Map<String, dynamic> slot) {
    final bool isComplete = _slotCompletionStatus['${slot['hour']}'] ?? false;

    if (isComplete) {
      return 'Complete';
    } else if (slot['isCurrentHour']) {
      return 'Current Hour';
    } else if (slot['isPastHour']) {
      return 'Pending';
    } else {
      return 'Upcoming';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (widget.substationId.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32.0),
          child: Text(
            'Please select a substation to view hourly operations.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              fontStyle: FontStyle.italic,
              color: Colors.grey,
            ),
          ),
        ),
      );
    }

    return Column(
      children: [
        // Header with date info
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
              Icon(
                Icons.access_time,
                color: theme.colorScheme.primary,
                size: 32,
              ),
              const SizedBox(height: 8),
              Text(
                'Hourly Operations',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                DateFormat('EEEE, dd MMMM yyyy').format(widget.selectedDate),
                style: TextStyle(
                  fontSize: 14,
                  color: theme.colorScheme.onSurface.withOpacity(0.7),
                ),
              ),
            ],
          ),
        ),

        // Content area
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : !_hasAnyBaysWithReadings
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
                          'No Hourly Reading Assignments',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'No bays have been assigned hourly reading templates in this substation. Please contact your administrator to set up bay reading assignments.',
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
              : _hourlySlots.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.schedule,
                        size: 64,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No hourly slots available for this date',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _hourlySlots.length,
                  itemBuilder: (context, index) {
                    final slot = _hourlySlots[index];
                    final statusColor = _getSlotStatusColor(slot);
                    final statusIcon = _getSlotStatusIcon(slot);
                    final statusText = _getSlotStatusText(slot);

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
                            color: statusColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(statusIcon, color: statusColor, size: 24),
                        ),
                        title: Text(
                          'Hour ${slot['displayTime']}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Text(
                              statusText,
                              style: TextStyle(
                                fontSize: 14,
                                color: statusColor,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${_baysWithHourlyAssignments.length} bays assigned',
                              style: TextStyle(
                                fontSize: 12,
                                color: theme.colorScheme.onSurface.withOpacity(
                                  0.6,
                                ),
                              ),
                            ),
                          ],
                        ),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                        onTap: () {
                          // Fixed navigation
                          Navigator.of(context)
                              .push(
                                MaterialPageRoute(
                                  builder: (context) => BayReadingsStatusScreen(
                                    substationId: widget.substationId,
                                    substationName: widget.substationName,
                                    currentUser: widget.currentUser,
                                    frequencyType: 'hourly',
                                    selectedDate: widget.selectedDate,
                                    selectedHour: slot['hour'],
                                  ),
                                ),
                              )
                              .then((_) {
                                _loadHourlySlots();
                              });
                        },
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

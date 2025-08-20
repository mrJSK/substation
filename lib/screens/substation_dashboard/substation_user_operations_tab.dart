import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../models/user_model.dart';
import '../../models/bay_model.dart';
import '../../models/reading_models.dart';
import '../../utils/snackbar_utils.dart';
import 'bay_readings_status_screen.dart';

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

// **KEY FIX: Add AutomaticKeepAliveClientMixin**
class _SubstationUserOperationsTabState
    extends State<SubstationUserOperationsTab>
    with AutomaticKeepAliveClientMixin {
  // **KEY FIX: Override wantKeepAlive**
  @override
  bool get wantKeepAlive => true;

  bool _isLoading = true;
  bool _isLoadingProgress = false;
  List<Map<String, dynamic>> _hourlySlots = [];
  Map<String, bool> _slotCompletionStatus = {};
  List<Bay> _baysWithHourlyAssignments = [];
  bool _hasAnyBaysWithReadings = false;

  // **KEY FIX: Add data loaded flag**
  bool _isDataInitialized = false;
  String? _lastLoadedSubstationId;
  DateTime? _lastLoadedDate;

  // Cache variables
  Map<String, Bay> _preLoadedBays = {};

  @override
  void initState() {
    super.initState();
    // **KEY FIX: Only load once**
    _initializeDataOnce();
  }

  @override
  void didUpdateWidget(SubstationUserOperationsTab oldWidget) {
    super.didUpdateWidget(oldWidget);

    // **KEY FIX: Only reload if substation or date actually changed**
    final bool shouldReload =
        oldWidget.substationId != widget.substationId ||
        !DateUtils.isSameDay(oldWidget.selectedDate, widget.selectedDate);

    if (shouldReload) {
      _isDataInitialized = false;
      _initializeDataOnce();
    }
  }

  // **KEY FIX: Prevent multiple Firebase calls**
  Future<void> _initializeDataOnce() async {
    if (_isDataInitialized &&
        _lastLoadedSubstationId == widget.substationId &&
        _lastLoadedDate != null &&
        DateUtils.isSameDay(_lastLoadedDate!, widget.selectedDate)) {
      // Data already loaded for this substation and date
      return;
    }

    await _loadHourlySlots();
    _isDataInitialized = true;
    _lastLoadedSubstationId = widget.substationId;
    _lastLoadedDate = widget.selectedDate;
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

    setState(() {
      _isLoading = true;
      _isLoadingProgress = true;
    });

    try {
      // Step 1: Pre-load all bays for this substation
      await _preLoadBays();

      // Step 2: Check if there are any bays with hourly reading assignments
      await _checkForBaysWithHourlyAssignments();

      if (!_hasAnyBaysWithReadings) {
        setState(() {
          _isLoading = false;
          _isLoadingProgress = false;
          _hourlySlots = [];
        });
        return;
      }

      // Step 3: Generate hourly slots
      _generateHourlySlots();

      // Update UI with slots before checking completion status
      setState(() {
        _isLoadingProgress = false;
      });

      // Step 4: Check completion status for each slot
      await _checkSlotCompletionStatusOptimized();
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
        setState(() {
          _isLoading = false;
          _isLoadingProgress = false;
        });
      }
    }
  }

  Future<void> _preLoadBays() async {
    // **KEY FIX: Only load if not already loaded**
    if (_preLoadedBays.isNotEmpty &&
        _lastLoadedSubstationId == widget.substationId) {
      return;
    }

    final baysSnapshot = await FirebaseFirestore.instance
        .collection('bays')
        .where('substationId', isEqualTo: widget.substationId)
        .get();

    _preLoadedBays = {
      for (var doc in baysSnapshot.docs) doc.id: Bay.fromFirestore(doc),
    };
  }

  Future<void> _checkForBaysWithHourlyAssignments() async {
    try {
      if (_preLoadedBays.isEmpty) {
        _hasAnyBaysWithReadings = false;
        _baysWithHourlyAssignments = [];
        return;
      }

      final List<String> bayIds = _preLoadedBays.keys.toList();
      _baysWithHourlyAssignments.clear();

      // Optimized: Single query instead of multiple
      final assignmentsSnapshot = await FirebaseFirestore.instance
          .collection('bayReadingAssignments')
          .where('bayId', whereIn: bayIds.take(10).toList()) // Firestore limit
          .get();

      // If we have more than 10 bays, fetch the rest
      if (bayIds.length > 10) {
        for (int i = 10; i < bayIds.length; i += 10) {
          final batch = bayIds.skip(i).take(10).toList();
          final additionalSnapshot = await FirebaseFirestore.instance
              .collection('bayReadingAssignments')
              .where('bayId', whereIn: batch)
              .get();
          assignmentsSnapshot.docs.addAll(additionalSnapshot.docs);
        }
      }

      for (var doc in assignmentsSnapshot.docs) {
        final String bayId = doc['bayId'] as String;
        final assignedFieldsData =
            (doc.data() as Map)['assignedFields'] as List;

        final hasHourlyMandatoryFields = assignedFieldsData.any((fieldMap) {
          final field = ReadingField.fromMap(fieldMap as Map<String, dynamic>);
          return field.isMandatory &&
              field.frequency.toString().split('.').last == 'hourly';
        });

        if (hasHourlyMandatoryFields) {
          final Bay? bay = _preLoadedBays[bayId];
          if (bay != null) {
            _baysWithHourlyAssignments.add(bay);
          }
        }
      }

      _hasAnyBaysWithReadings = _baysWithHourlyAssignments.isNotEmpty;
    } catch (e) {
      print('Error checking for bays with hourly assignments: $e');
      _hasAnyBaysWithReadings = false;
      _baysWithHourlyAssignments = [];
    }
  }

  void _generateHourlySlots() {
    final DateTime now = DateTime.now();
    final bool isToday = DateUtils.isSameDay(widget.selectedDate, now);
    _hourlySlots.clear();
    _slotCompletionStatus.clear();

    // Generate hourly slots starting from 01:00 to 00:00 (next day)
    for (int i = 0; i < 24; i++) {
      int hour = (i + 1) % 24; // This gives us: 1, 2, 3, ..., 23, 0

      DateTime slotDateTime = DateTime(
        widget.selectedDate.year,
        widget.selectedDate.month,
        widget.selectedDate.day,
        hour,
      );

      if (hour == 0) {
        slotDateTime = slotDateTime.add(const Duration(days: 1));
      }

      if (isToday && slotDateTime.isAfter(now)) {
        continue;
      }

      final bool isCurrentHour =
          isToday &&
          slotDateTime.hour == now.hour &&
          DateUtils.isSameDay(slotDateTime, now);
      final bool isPastHour = isToday && slotDateTime.isBefore(now);

      _hourlySlots.add({
        'hour': hour,
        'displayTime': '${hour.toString().padLeft(2, '0')}:00',
        'slotDateTime': slotDateTime,
        'isCurrentHour': isCurrentHour,
        'isPastHour': isPastHour,
        'isFuture': false,
      });

      _slotCompletionStatus['$hour'] = false;
    }
  }

  Future<void> _checkSlotCompletionStatusOptimized() async {
    try {
      if (_baysWithHourlyAssignments.isEmpty) {
        for (var slot in _hourlySlots) {
          _slotCompletionStatus['${slot['hour']}'] = true;
        }
        return;
      }

      // Single optimized query
      final allLogsheetsSnapshot = await FirebaseFirestore.instance
          .collection('logsheetEntries')
          .where('substationId', isEqualTo: widget.substationId)
          .where('frequency', isEqualTo: 'hourly')
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
          .get();

      // Create lookup map
      final Map<String, Set<int>> bayHourReadings = {};
      for (var doc in allLogsheetsSnapshot.docs) {
        final data = doc.data();
        final bayId = data['bayId'] as String;
        final readingHour = data['readingHour'] as int?;

        if (readingHour != null) {
          bayHourReadings.putIfAbsent(bayId, () => <int>{});
          bayHourReadings[bayId]!.add(readingHour);
        }
      }

      // Check completion status
      for (var slot in _hourlySlots) {
        final int hour = slot['hour'];
        bool allBaysComplete = true;

        for (var bay in _baysWithHourlyAssignments) {
          if (!bayHourReadings.containsKey(bay.id) ||
              !bayHourReadings[bay.id]!.contains(hour)) {
            allBaysComplete = false;
            break;
          }
        }

        _slotCompletionStatus['$hour'] = allBaysComplete;
      }

      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      print('Error checking slot completion: $e');
    }
  }

  // Method to refresh only specific slot status
  Future<void> _refreshSlotStatus(int hour) async {
    if (_baysWithHourlyAssignments.isEmpty) {
      setState(() {
        _slotCompletionStatus['$hour'] = true;
      });
      return;
    }

    bool allBaysComplete = true;
    for (var bay in _baysWithHourlyAssignments) {
      final hasReading = await _checkBayHasReadingForHour(bay.id, hour);
      if (!hasReading) {
        allBaysComplete = false;
        break;
      }
    }

    setState(() {
      _slotCompletionStatus['$hour'] = allBaysComplete;
    });
  }

  Future<bool> _checkBayHasReadingForHour(String bayId, int hour) async {
    final logsheetQuery = await FirebaseFirestore.instance
        .collection('logsheetEntries')
        .where('bayId', isEqualTo: bayId)
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

    return logsheetQuery.docs.isNotEmpty;
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
    // **KEY FIX: Call super.build for AutomaticKeepAliveClientMixin**
    super.build(context);

    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    if (widget.substationId.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Text(
            'Please select a substation to view hourly operations.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              fontStyle: FontStyle.italic,
              color: isDarkMode ? Colors.white.withOpacity(0.6) : Colors.grey,
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
            color: isDarkMode
                ? theme.colorScheme.primary.withOpacity(0.2)
                : theme.colorScheme.primaryContainer.withOpacity(0.3),
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
                  color: isDarkMode
                      ? Colors.white.withOpacity(0.7)
                      : theme.colorScheme.onSurface.withOpacity(0.7),
                ),
              ),
            ],
          ),
        ),

        // Content area
        Expanded(
          child: _isLoading
              ? Center(
                  child: CircularProgressIndicator(
                    color: theme.colorScheme.primary,
                  ),
                )
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
                          color: isDarkMode
                              ? Colors.white.withOpacity(0.4)
                              : Colors.grey.shade400,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No Hourly Reading Assignments',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: isDarkMode
                                ? Colors.white.withOpacity(0.6)
                                : Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'No bays have been assigned hourly reading templates in this substation. Please contact your administrator to set up bay reading assignments.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            color: isDarkMode
                                ? Colors.white.withOpacity(0.6)
                                : Colors.grey.shade600,
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
                        color: isDarkMode
                            ? Colors.white.withOpacity(0.4)
                            : Colors.grey.shade400,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No hourly slots available for this date',
                        style: TextStyle(
                          fontSize: 16,
                          color: isDarkMode
                              ? Colors.white.withOpacity(0.6)
                              : Colors.grey.shade600,
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
                            color: statusColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(statusIcon, color: statusColor, size: 24),
                        ),
                        title: Text(
                          'Hour ${slot['displayTime']}',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: isDarkMode ? Colors.white : Colors.black87,
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
                                color: isDarkMode
                                    ? Colors.white.withOpacity(0.6)
                                    : theme.colorScheme.onSurface.withOpacity(
                                        0.6,
                                      ),
                              ),
                            ),
                          ],
                        ),
                        trailing: Icon(
                          Icons.arrow_forward_ios,
                          size: 16,
                          color: isDarkMode
                              ? Colors.white.withOpacity(0.6)
                              : theme.colorScheme.onSurface.withOpacity(0.6),
                        ),
                        onTap: () {
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
                              .then((result) {
                                if (result == true) {
                                  _refreshSlotStatus(slot['hour']);
                                }
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

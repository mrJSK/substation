import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/user_model.dart';
import '../../models/bay_model.dart';
import '../../models/enhanced_bay_data.dart';
import '../../services/comprehensive_cache_service.dart';
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

class _SubstationUserOperationsTabState
    extends State<SubstationUserOperationsTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final ComprehensiveCacheService _cache = ComprehensiveCacheService();

  bool _isLoading = true;
  bool _isLoadingProgress = false;
  List<Map<String, dynamic>> _hourlySlots = [];
  Map<String, bool> _slotCompletionStatus = {};
  List<EnhancedBayData> _baysWithHourlyAssignments = [];
  bool _hasAnyBaysWithReadings = false;

  @override
  void initState() {
    super.initState();
    _loadHourlySlots();
  }

  @override
  void didUpdateWidget(SubstationUserOperationsTab oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Only reload if substation or date actually changed
    final bool shouldReload =
        oldWidget.substationId != widget.substationId ||
        !DateUtils.isSameDay(oldWidget.selectedDate, widget.selectedDate);

    if (shouldReload) {
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

    setState(() {
      _isLoading = true;
      _isLoadingProgress = true;
    });

    try {
      // ✅ USE CACHE - No Firebase queries!
      if (!_cache.isInitialized) {
        throw Exception('Cache not initialized - please restart the app');
      }

      // Get bays with hourly readings from cache
      _baysWithHourlyAssignments = _cache.getBaysWithReadings('hourly');
      _hasAnyBaysWithReadings = _baysWithHourlyAssignments.isNotEmpty;

      if (!_hasAnyBaysWithReadings) {
        setState(() {
          _isLoading = false;
          _isLoadingProgress = false;
          _hourlySlots = [];
        });
        return;
      }

      // Generate hourly slots
      _generateHourlySlots();

      // Update UI with slots before checking completion status
      setState(() {
        _isLoadingProgress = false;
      });

      // Check completion status for each slot from cache
      _checkSlotCompletionStatus();

      print(
        '✅ Operations tab loaded ${_baysWithHourlyAssignments.length} bays from cache',
      );
    } catch (e) {
      print('❌ Error loading hourly slots from cache: $e');
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

  void _checkSlotCompletionStatus() {
    if (_baysWithHourlyAssignments.isEmpty) {
      for (var slot in _hourlySlots) {
        _slotCompletionStatus['${slot['hour']}'] = true;
      }
      setState(() {});
      return;
    }

    // ✅ USE CACHE - Check completion from cached data
    for (var slot in _hourlySlots) {
      final int hour = slot['hour'];
      bool allBaysComplete = true;

      for (var bayData in _baysWithHourlyAssignments) {
        final entry = bayData.getReading(
          widget.selectedDate,
          'hourly',
          hour: hour,
        );
        if (entry == null) {
          allBaysComplete = false;
          break;
        }
      }

      _slotCompletionStatus['$hour'] = allBaysComplete;
    }

    if (mounted) {
      setState(() {});
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

    // ✅ USE CACHE - Check completion from updated cache data
    bool allBaysComplete = true;
    for (var bayData in _baysWithHourlyAssignments) {
      final entry = bayData.getReading(
        widget.selectedDate,
        'hourly',
        hour: hour,
      );
      if (entry == null) {
        allBaysComplete = false;
        break;
      }
    }

    setState(() {
      _slotCompletionStatus['$hour'] = allBaysComplete;
    });
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
    super.build(context); // Required for AutomaticKeepAliveClientMixin

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
        // Header with date info and cache indicator
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
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.access_time,
                    color: theme.colorScheme.primary,
                    size: 32,
                  ),
                  const SizedBox(width: 12),
                ],
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
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Loading from cache...',
                        style: TextStyle(
                          fontSize: 16,
                          color: isDarkMode ? Colors.white : Colors.black87,
                        ),
                      ),
                    ],
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

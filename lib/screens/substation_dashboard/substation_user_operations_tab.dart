import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/user_model.dart';
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

  // 🔧 FIX: Add cache health tracking
  bool _cacheHealthy = false;
  String? _cacheError;
  Map<String, int> _slotBayCompletionCount = {};

  @override
  void initState() {
    super.initState();
    _loadHourlySlots();
  }

  @override
  void didUpdateWidget(SubstationUserOperationsTab oldWidget) {
    super.didUpdateWidget(oldWidget);

    final bool shouldReload =
        oldWidget.substationId != widget.substationId ||
        !DateUtils.isSameDay(oldWidget.selectedDate, widget.selectedDate);

    if (shouldReload) {
      _loadHourlySlots();
    }
  }

  // 🔧 FIX: Enhanced loading with better error handling
  Future<void> _loadHourlySlots() async {
    if (widget.substationId.isEmpty) {
      setState(() {
        _isLoading = false;
        _hourlySlots = [];
        _hasAnyBaysWithReadings = false;
        _cacheHealthy = false;
        _cacheError = 'No substation selected';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _isLoadingProgress = true;
      _cacheError = null;
    });

    try {
      if (!_cache.isInitialized) {
        throw Exception('Cache not initialized - please restart the app');
      }

      // 🔧 FIX: Validate cache health
      if (!_cache.validateCache()) {
        throw Exception('Cache validation failed - data may be stale');
      }

      _baysWithHourlyAssignments = _cache.getBaysWithReadings('hourly');
      _hasAnyBaysWithReadings = _baysWithHourlyAssignments.isNotEmpty;
      _cacheHealthy = true;

      if (!_hasAnyBaysWithReadings) {
        setState(() {
          _isLoading = false;
          _isLoadingProgress = false;
          _hourlySlots = [];
        });
        return;
      }

      _generateHourlySlots();

      setState(() {
        _isLoadingProgress = false;
      });

      _checkSlotCompletionStatus();

      print(
        '✅ Operations tab loaded ${_baysWithHourlyAssignments.length} bays from cache',
      );
    } catch (e) {
      print('❌ Error loading hourly slots from cache: $e');
      setState(() {
        _cacheHealthy = false;
        _cacheError = e.toString();
      });

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

  // 🔧 FIX: Enhanced slot generation with better validation
  void _generateHourlySlots() {
    final DateTime now = DateTime.now();
    final bool isToday = DateUtils.isSameDay(widget.selectedDate, now);
    final bool isFutureDate = widget.selectedDate.isAfter(now);

    _hourlySlots.clear();
    _slotCompletionStatus.clear();
    _slotBayCompletionCount.clear();

    // Don't show slots for future dates
    if (isFutureDate) {
      return;
    }

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

      // 🔧 FIX: Enhanced slot filtering logic
      bool isAvailable = true;
      bool isCurrentHour = false;
      bool isPastHour = false;
      bool isFutureHour = false;

      if (isToday) {
        isCurrentHour =
            slotDateTime.hour == now.hour &&
            DateUtils.isSameDay(slotDateTime, now);
        isPastHour =
            slotDateTime.isBefore(now) ||
            (slotDateTime.hour < now.hour &&
                DateUtils.isSameDay(slotDateTime, now));
        isFutureHour = slotDateTime.isAfter(now);

        // Only show past hours, current hour, and next hour for today
        if (isFutureHour && slotDateTime.difference(now).inHours > 1) {
          isAvailable = false;
        }
      }

      if (!isAvailable) continue;

      _hourlySlots.add({
        'hour': hour,
        'displayTime': '${hour.toString().padLeft(2, '0')}:00',
        'slotDateTime': slotDateTime,
        'isCurrentHour': isCurrentHour,
        'isPastHour': isPastHour,
        'isFutureHour': isFutureHour,
        'isToday': isToday,
      });

      _slotCompletionStatus['$hour'] = false;
      _slotBayCompletionCount['$hour'] = 0;
    }
  }

  // 🔧 FIX: Enhanced completion checking with detailed tracking
  void _checkSlotCompletionStatus() {
    if (_baysWithHourlyAssignments.isEmpty) {
      for (var slot in _hourlySlots) {
        _slotCompletionStatus['${slot['hour']}'] = true;
        _slotBayCompletionCount['${slot['hour']}'] = 0;
      }
      setState(() {});
      return;
    }

    for (var slot in _hourlySlots) {
      final int hour = slot['hour'];
      int completedBays = 0;

      // 🔧 FIX: Check for existing readings to prevent duplicates
      for (var bayData in _baysWithHourlyAssignments) {
        final bool hasExistingReading = _cache.hasReadingForDate(
          bayData.id,
          widget.selectedDate,
          'hourly',
          hour: hour,
        );

        if (hasExistingReading) {
          completedBays++;
        }
      }

      final bool allBaysComplete =
          completedBays == _baysWithHourlyAssignments.length;
      _slotCompletionStatus['$hour'] = allBaysComplete;
      _slotBayCompletionCount['$hour'] = completedBays;
    }

    if (mounted) {
      setState(() {});
    }
  }

  // 🔧 FIX: Enhanced refresh with cache synchronization
  Future<void> _refreshSlotStatus(int hour) async {
    try {
      // Force refresh bay data to ensure we have latest readings
      for (var bayData in _baysWithHourlyAssignments) {
        await _cache.refreshBayData(bayData.id);
      }

      if (_baysWithHourlyAssignments.isEmpty) {
        setState(() {
          _slotCompletionStatus['$hour'] = true;
          _slotBayCompletionCount['$hour'] = 0;
        });
        return;
      }

      int completedBays = 0;
      for (var bayData in _baysWithHourlyAssignments) {
        final bool hasReading = _cache.hasReadingForDate(
          bayData.id,
          widget.selectedDate,
          'hourly',
          hour: hour,
        );

        if (hasReading) {
          completedBays++;
        }
      }

      final bool allBaysComplete =
          completedBays == _baysWithHourlyAssignments.length;

      setState(() {
        _slotCompletionStatus['$hour'] = allBaysComplete;
        _slotBayCompletionCount['$hour'] = completedBays;
      });

      print(
        '✅ Slot status refreshed for hour $hour: $completedBays/${_baysWithHourlyAssignments.length} bays complete',
      );
    } catch (e) {
      print('❌ Error refreshing slot status for hour $hour: $e');
    }
  }

  // 🔧 FIX: Enhanced status color logic
  Color _getSlotStatusColor(Map<String, dynamic> slot) {
    final bool isComplete = _slotCompletionStatus['${slot['hour']}'] ?? false;
    final int completedBays = _slotBayCompletionCount['${slot['hour']}'] ?? 0;

    if (isComplete) {
      return Colors.green;
    } else if (completedBays > 0) {
      return Colors.amber; // Partially complete
    } else if (slot['isCurrentHour']) {
      return Colors.blue;
    } else if (slot['isPastHour']) {
      return Colors.red;
    } else {
      return Colors.grey;
    }
  }

  IconData _getSlotStatusIcon(Map<String, dynamic> slot) {
    final bool isComplete = _slotCompletionStatus['${slot['hour']}'] ?? false;
    final int completedBays = _slotBayCompletionCount['${slot['hour']}'] ?? 0;

    if (isComplete) {
      return Icons.check_circle;
    } else if (completedBays > 0) {
      return Icons.radio_button_checked; // Partially complete
    } else if (slot['isCurrentHour']) {
      return Icons.access_time;
    } else if (slot['isPastHour']) {
      return Icons.warning;
    } else {
      return Icons.schedule;
    }
  }

  // 🔧 FIX: Enhanced status text with completion details
  String _getSlotStatusText(Map<String, dynamic> slot) {
    final bool isComplete = _slotCompletionStatus['${slot['hour']}'] ?? false;
    final int completedBays = _slotBayCompletionCount['${slot['hour']}'] ?? 0;
    final int totalBays = _baysWithHourlyAssignments.length;

    if (isComplete) {
      return 'Complete ($completedBays/$totalBays)';
    } else if (completedBays > 0) {
      return 'Partial ($completedBays/$totalBays)';
    } else if (slot['isCurrentHour']) {
      return 'Current Hour';
    } else if (slot['isPastHour']) {
      return 'Pending';
    } else {
      return 'Upcoming';
    }
  }

  // 🔧 FIX: Add cache status indicator
  Widget _buildCacheStatusIndicator() {
    if (!_cache.isInitialized) return const SizedBox.shrink();

    final cacheStats = _cache.getCacheStats();
    final cacheAge = cacheStats['cacheAge'] ?? 0;

    Color statusColor = Colors.green;
    IconData statusIcon = Icons.offline_bolt;
    String statusText = 'LIVE';

    if (!_cacheHealthy) {
      statusColor = Colors.red;
      statusIcon = Icons.error;
      statusText = 'ERROR';
    } else if (cacheAge > 60) {
      statusColor = Colors.orange;
      statusIcon = Icons.schedule;
      statusText = 'STALE';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: statusColor.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(statusIcon, size: 10, color: statusColor),
          const SizedBox(width: 2),
          Text(
            statusText,
            style: TextStyle(
              fontSize: 8,
              fontWeight: FontWeight.w600,
              color: statusColor,
            ),
          ),
        ],
      ),
    );
  }

  // 🔧 FIX: Enhanced slot card with better visual indicators
  Widget _buildSlotCard(Map<String, dynamic> slot, int index) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final statusColor = _getSlotStatusColor(slot);
    final statusIcon = _getSlotStatusIcon(slot);
    final statusText = _getSlotStatusText(slot);
    final completedBays = _slotBayCompletionCount['${slot['hour']}'] ?? 0;
    final totalBays = _baysWithHourlyAssignments.length;
    final bool isComplete = _slotCompletionStatus['${slot['hour']}'] ?? false;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF2C2C2E) : Colors.white,
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
        border: Border.all(
          color: statusColor.withOpacity(0.3),
          width: isComplete ? 2 : 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
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
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: statusColor.withOpacity(0.3)),
                  ),
                  child: Icon(statusIcon, color: statusColor, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Hour ${slot['displayTime']}',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: isDarkMode ? Colors.white : Colors.black87,
                        ),
                      ),
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
                      Row(
                        children: [
                          Icon(
                            Icons.electrical_services,
                            size: 12,
                            color: isDarkMode
                                ? Colors.white.withOpacity(0.6)
                                : theme.colorScheme.onSurface.withOpacity(0.6),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '$totalBays bays assigned',
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
                    ],
                  ),
                ),
                // Progress indicator for partial completion
                if (completedBays > 0 && !isComplete) ...[
                  Container(
                    width: 40,
                    height: 40,
                    child: Stack(
                      children: [
                        CircularProgressIndicator(
                          value: completedBays / totalBays,
                          backgroundColor: Colors.grey.shade300,
                          valueColor: AlwaysStoppedAnimation(statusColor),
                          strokeWidth: 3,
                        ),
                        Center(
                          child: Text(
                            '$completedBays',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: statusColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: isDarkMode
                      ? Colors.white.withOpacity(0.6)
                      : theme.colorScheme.onSurface.withOpacity(0.6),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    if (widget.substationId.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.location_off,
                size: 64,
                color: isDarkMode
                    ? Colors.white.withOpacity(0.4)
                    : Colors.grey.shade400,
              ),
              const SizedBox(height: 16),
              Text(
                'No Substation Selected',
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
                'Please select a substation to view hourly operations.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  fontStyle: FontStyle.italic,
                  color: isDarkMode
                      ? Colors.white.withOpacity(0.6)
                      : Colors.grey,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        // 🔧 FIX: Enhanced header with cache status
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
                  Expanded(
                    child: Column(
                      children: [
                        Text(
                          'Hourly Operations',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        Text(
                          DateFormat(
                            'EEEE, dd MMMM yyyy',
                          ).format(widget.selectedDate),
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
                  _buildCacheStatusIndicator(),
                ],
              ),
              if (_hasAnyBaysWithReadings && _hourlySlots.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isDarkMode ? const Color(0xFF3C3C3E) : Colors.white,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildStatItem(
                        'Total Slots',
                        '${_hourlySlots.length}',
                        Icons.schedule,
                        Colors.blue,
                      ),
                      _buildStatItem(
                        'Completed',
                        '${_slotCompletionStatus.values.where((c) => c).length}',
                        Icons.check_circle,
                        Colors.green,
                      ),
                      _buildStatItem(
                        'Bays',
                        '${_baysWithHourlyAssignments.length}',
                        Icons.electrical_services,
                        Colors.orange,
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),

        Expanded(
          child: _isLoading
              ? Center(
                  child: Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    color: isDarkMode ? const Color(0xFF2C2C2E) : Colors.white,
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(
                            color: theme.colorScheme.primary,
                            strokeWidth: 3,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Loading from cache...',
                            style: TextStyle(
                              fontSize: 16,
                              color: isDarkMode ? Colors.white : Colors.black87,
                            ),
                          ),
                          if (_cacheError != null) ...[
                            const SizedBox(height: 8),
                            Text(
                              _cacheError!,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.red,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
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
                        'No Hourly Slots Available',
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
                        widget.selectedDate.isAfter(DateTime.now())
                            ? 'Future dates are not available for reading entry.'
                            : 'No hourly slots available for this date.',
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
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _hourlySlots.length,
                  itemBuilder: (context, index) {
                    return _buildSlotCard(_hourlySlots[index], index);
                  },
                ),
        ),
      ],
    );
  }

  // Helper widget for statistics
  Widget _buildStatItem(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Column(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 10, color: color.withOpacity(0.8)),
        ),
      ],
    );
  }
}

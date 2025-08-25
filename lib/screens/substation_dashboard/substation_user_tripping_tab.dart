import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/tripping_shutdown_model.dart';
import '../../models/user_model.dart';
import '../../services/comprehensive_cache_service.dart';
import '../../utils/snackbar_utils.dart';
import 'tripping_shutdown_entry_screen.dart';

class SubstationUserTrippingTab extends StatefulWidget {
  final String substationId;
  final String substationName;
  final AppUser currentUser;
  final DateTime selectedDate;

  const SubstationUserTrippingTab({
    super.key,
    required this.substationId,
    required this.substationName,
    required this.currentUser,
    required this.selectedDate,
  });

  @override
  State<SubstationUserTrippingTab> createState() =>
      _SubstationUserTrippingTabState();
}

class _SubstationUserTrippingTabState extends State<SubstationUserTrippingTab>
    with TickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final ComprehensiveCacheService _cache = ComprehensiveCacheService();

  bool _isLoading = true;
  List<TrippingShutdownEntry> _openEvents = [];
  List<TrippingShutdownEntry> _closedEvents = [];
  List<TrippingShutdownEntry> _allRecentEvents = [];
  bool _hasAnyBays = false;
  late AnimationController _animationController;

  // Cache health tracking
  bool _cacheHealthy = false;
  String? _cacheError;

  // Current selected tab index
  int _selectedTabIndex = 0;

  // ✨ NEW: Valid event types including breakdown
  static const List<String> _validEventTypes = [
    'Tripping',
    'Shutdown',
    'Breakdown',
  ];

  // ✨ NEW: Helper methods for dynamic event labels
  String _getEventStartLabel(String eventType) {
    switch (eventType) {
      case 'Breakdown':
        return 'Breakdown Time';
      case 'Tripping':
        return 'Trip Time';
      case 'Shutdown':
        return 'S/D Time';
      default:
        return 'Event Time';
    }
  }

  String _getEventEndLabel(String eventType) {
    switch (eventType) {
      case 'Breakdown':
        return 'Breakdown Ended';
      case 'Tripping':
        return 'Tripping Ended';
      case 'Shutdown':
        return 'Shutdown Ended';
      default:
        return 'Event Ended';
    }
  }

  String _getEventRunningLabel(String eventType) {
    switch (eventType) {
      case 'Breakdown':
        return 'Breakdown Duration';
      case 'Tripping':
        return 'Trip Duration';
      case 'Shutdown':
        return 'Shutdown Duration';
      default:
        return 'Event Duration';
    }
  }

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _loadTrippingData();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(SubstationUserTrippingTab oldWidget) {
    super.didUpdateWidget(oldWidget);

    final bool shouldReload =
        oldWidget.substationId != widget.substationId ||
        !DateUtils.isSameDay(oldWidget.selectedDate, widget.selectedDate);

    if (shouldReload) {
      _loadTrippingData();
    }
  }

  // Enhanced data loading - open events from any time, closed events from today only
  Future<void> _loadTrippingData() async {
    if (widget.substationId.isEmpty) {
      setState(() {
        _isLoading = false;
        _openEvents = [];
        _closedEvents = [];
        _allRecentEvents = [];
        _hasAnyBays = false;
        _cacheHealthy = false;
        _cacheError = 'No substation selected';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _cacheError = null;
    });

    try {
      if (!_cache.isInitialized) {
        throw Exception('Cache not initialized - please restart the app');
      }

      if (!_cache.validateCache()) {
        throw Exception('Cache validation failed - data may be stale');
      }

      final substationData = _cache.substationData!;
      _hasAnyBays = substationData.bays.isNotEmpty;
      _cacheHealthy = true;

      if (_hasAnyBays) {
        final allRecentEvents = substationData.recentTrippingEvents;

        // ✨ UPDATED: Filter events to include all valid event types
        final validEvents = allRecentEvents
            .where((event) => _validEventTypes.contains(event.eventType))
            .toList();

        // Define current day boundaries for closed events only
        final now = DateTime.now();
        final startOfToday = DateTime(now.year, now.month, now.day);
        final endOfToday = DateTime(
          now.year,
          now.month,
          now.day,
          23,
          59,
          59,
          999,
        );

        // Get ALL open events (regardless of when they started)
        _openEvents = validEvents
            .where((event) => event.status == 'OPEN')
            .toList();

        // Get closed events that ended today only
        _closedEvents = validEvents
            .where(
              (event) =>
                  event.status == 'CLOSED' &&
                  event.endTime != null &&
                  _isEventFromToday(
                    event.endTime!.toDate(),
                    startOfToday,
                    endOfToday,
                  ),
            )
            .toList();

        // Total events = all open events + today's closed events
        _allRecentEvents = [..._openEvents, ..._closedEvents];
      }

      _animationController.forward();

      print(
        '✅ Event tab loaded ${_openEvents.length} open events (any time), ${_closedEvents.length} closed events for today, ${_allRecentEvents.length} total events from cache',
      );
    } catch (e) {
      print('❌ Error loading event data from cache: $e');
      setState(() {
        _cacheHealthy = false;
        _cacheError = e.toString();
      });

      if (mounted) {
        SnackBarUtils.showSnackBar(
          context,
          'Error loading event data: $e',
          isError: true,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // Helper method to check if an event is from today (used only for closed events)
  bool _isEventFromToday(
    DateTime eventTime,
    DateTime startOfToday,
    DateTime endOfToday,
  ) {
    return eventTime.isAfter(
          startOfToday.subtract(Duration(milliseconds: 1)),
        ) &&
        eventTime.isBefore(endOfToday.add(Duration(milliseconds: 1)));
  }

  // Enhanced refresh with cache synchronization
  Future<void> _refreshTrippingData() async {
    try {
      await _cache.forceRefresh();
      await _loadTrippingData();
      print('✅ Event data refreshed successfully');
    } catch (e) {
      print('❌ Error refreshing event data: $e');
      await _loadTrippingData();
    }
  }

  // ✨ UPDATED: Get event type colors including breakdown
  Color _getEventTypeColor(String eventType) {
    switch (eventType) {
      case 'Tripping':
        return Colors.red;
      case 'Shutdown':
        return Colors.orange;
      case 'Breakdown':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  // ✨ UPDATED: Get event type icons including breakdown
  IconData _getEventTypeIcon(String eventType) {
    switch (eventType) {
      case 'Tripping':
        return Icons.flash_on;
      case 'Shutdown':
        return Icons.power_off;
      case 'Breakdown':
        return Icons.build_circle_outlined;
      default:
        return Icons.warning;
    }
  }

  // Navigation methods - simplified for substation user only
  void _navigateToAddEvent() {
    if (!_hasAnyBays) {
      SnackBarUtils.showSnackBar(
        context,
        'Cannot create events. No bays configured in this substation.',
        isError: true,
      );
      return;
    }

    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (context) => TrippingShutdownEntryScreen(
              substationId: widget.substationId,
              substationName: widget.substationName,
              currentUser: widget.currentUser,
              entryToEdit: null,
              isViewOnly: false,
            ),
          ),
        )
        .then((result) {
          if (result == true) {
            _refreshTrippingData();
          }
        });
  }

  void _navigateToViewEvent(
    TrippingShutdownEntry event, {
    bool isViewOnly = false,
  }) {
    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (context) => TrippingShutdownEntryScreen(
              substationId: widget.substationId,
              substationName: widget.substationName,
              currentUser: widget.currentUser,
              entryToEdit: event,
              isViewOnly: isViewOnly,
            ),
          ),
        )
        .then((result) {
          if (result == true) {
            _refreshTrippingData();
          }
        });
  }

  void _navigateToCloseEvent(TrippingShutdownEntry event) {
    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (context) => TrippingShutdownEntryScreen(
              substationId: widget.substationId,
              substationName: widget.substationName,
              currentUser: widget.currentUser,
              entryToEdit: event,
              isViewOnly: false,
            ),
          ),
        )
        .then((result) {
          if (result == true) {
            _refreshTrippingData();
          }
        });
  }

  // ✨ UPDATED: Enhanced event card with dynamic labels based on event type
  Widget _buildEventCard(TrippingShutdownEntry event) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final eventColor = _getEventTypeColor(event.eventType);
    final eventIcon = _getEventTypeIcon(event.eventType);
    final isOpen = event.status == 'OPEN';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
        border: isOpen
            ? Border.all(color: eventColor.withOpacity(0.4), width: 2)
            : Border.all(color: eventColor.withOpacity(0.2), width: 1),
      ),
      child: Column(
        children: [
          ListTile(
            contentPadding: const EdgeInsets.all(16),
            leading: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: eventColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: eventColor.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Icon(eventIcon, color: eventColor, size: 24),
            ),
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    '${event.eventType} - ${event.bayName}',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isDarkMode ? Colors.white : Colors.black87,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: isOpen
                        ? eventColor.withOpacity(0.1)
                        : Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isOpen
                          ? eventColor.withOpacity(0.5)
                          : Colors.green.withOpacity(0.5),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isOpen ? Icons.hourglass_empty : Icons.check_circle,
                        size: 14,
                        color: isOpen
                            ? eventColor.withOpacity(0.9)
                            : Colors.green.shade700,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        event.status,
                        style: TextStyle(
                          color: isOpen
                              ? eventColor.withOpacity(0.9)
                              : Colors.green.shade700,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.access_time,
                      size: 14,
                      color: isDarkMode
                          ? Colors.white.withOpacity(0.6)
                          : theme.colorScheme.onSurface.withOpacity(0.6),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${_getEventStartLabel(event.eventType)}: ${DateFormat('dd MMM HH:mm').format(event.startTime.toDate())}',
                      style: TextStyle(
                        fontSize: 14,
                        color: isDarkMode
                            ? Colors.white.withOpacity(0.7)
                            : theme.colorScheme.onSurface.withOpacity(0.7),
                      ),
                    ),
                    const Spacer(),
                    _buildEventAgeIndicator(event),
                  ],
                ),
                // Show running duration for open events
                if (isOpen) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.timer_outlined,
                        size: 14,
                        color: eventColor.withOpacity(0.8),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${_getEventRunningLabel(event.eventType)}: ${_calculateRunningDuration(event.startTime.toDate())}',
                        style: TextStyle(
                          fontSize: 14,
                          color: eventColor.withOpacity(0.8),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
                if (event.status == 'CLOSED' && event.endTime != null) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.check_circle_outline,
                        size: 14,
                        color: Colors.green.shade600,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${_getEventEndLabel(event.eventType)}: ${DateFormat('dd MMM HH:mm').format(event.endTime!.toDate())}',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.green.shade600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.timer,
                        size: 14,
                        color: isDarkMode
                            ? Colors.white.withOpacity(0.6)
                            : theme.colorScheme.onSurface.withOpacity(0.6),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Total Duration: ${_calculateDuration(event.startTime.toDate(), event.endTime!.toDate())}',
                        style: TextStyle(
                          fontSize: 14,
                          color: isDarkMode
                              ? Colors.white.withOpacity(0.7)
                              : theme.colorScheme.onSurface.withOpacity(0.7),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
                if (event.flagsCause.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isDarkMode
                          ? Colors.blue.shade800.withOpacity(0.3)
                          : Colors.blue.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.blue.withOpacity(0.2)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: 14,
                          color: isDarkMode
                              ? Colors.blue.shade300
                              : Colors.blue.shade600,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            event.flagsCause,
                            style: TextStyle(
                              fontSize: 12,
                              color: isDarkMode
                                  ? Colors.blue.shade300
                                  : Colors.blue.shade700,
                              fontStyle: FontStyle.italic,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
            onTap: () => _navigateToViewEvent(event),
          ),
          // Action buttons for open events
          if (isOpen) ...[
            Divider(
              height: 1,
              color: isDarkMode
                  ? Colors.white.withOpacity(0.2)
                  : Colors.grey.shade300,
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  OutlinedButton.icon(
                    onPressed: () =>
                        _navigateToViewEvent(event, isViewOnly: false),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: theme.colorScheme.primary,
                      side: BorderSide(color: theme.colorScheme.primary),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    icon: const Icon(Icons.edit, size: 18),
                    label: const Text('Edit'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: () => _navigateToCloseEvent(event),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    icon: const Icon(Icons.check, size: 18),
                    label: const Text('Close Event'),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // Add event age indicator with enhanced colors for long-running events
  Widget _buildEventAgeIndicator(TrippingShutdownEntry event) {
    final now = DateTime.now();
    final eventTime = event.startTime.toDate();
    final duration = now.difference(eventTime);

    Color indicatorColor = Colors.grey;
    String ageText = '';

    if (duration.inMinutes < 60) {
      indicatorColor = Colors.green;
      ageText = '${duration.inMinutes}m ago';
    } else if (duration.inHours < 24) {
      indicatorColor = Colors.orange;
      ageText = '${duration.inHours}h ago';
    } else if (duration.inDays < 7) {
      indicatorColor = Colors.red;
      ageText = '${duration.inDays}d ago';
    } else {
      indicatorColor = Colors.purple;
      ageText = '${duration.inDays}d ago';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: indicatorColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: indicatorColor.withOpacity(0.3)),
      ),
      child: Text(
        ageText,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: indicatorColor,
        ),
      ),
    );
  }

  // Calculate running duration for open events
  String _calculateRunningDuration(DateTime start) {
    final now = DateTime.now();
    return _calculateDuration(start, now);
  }

  String _calculateDuration(DateTime start, DateTime end) {
    final duration = end.difference(start);
    if (duration.inDays > 0) {
      return '${duration.inDays}d ${duration.inHours % 24}h ${duration.inMinutes % 60}m';
    } else if (duration.inHours > 0) {
      return '${duration.inHours}h ${duration.inMinutes % 60}m';
    } else {
      return '${duration.inMinutes}m';
    }
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String message,
    required Color color,
    Widget? action,
  }) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 48, color: color),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: isDarkMode
                    ? Colors.white.withOpacity(0.6)
                    : Colors.grey.shade600,
              ),
            ),
            if (action != null) ...[const SizedBox(height: 24), action],
          ],
        ),
      ),
    );
  }

  // Add cache status indicator
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

  // Get current events list based on selected tab
  List<TrippingShutdownEntry> _getCurrentEventsList() {
    switch (_selectedTabIndex) {
      case 0:
        return _openEvents;
      case 1:
        return _closedEvents;
      case 2:
        return _allRecentEvents;
      default:
        return _openEvents;
    }
  }

  // Get empty state for current tab
  Widget _getCurrentEmptyState() {
    final currentDate = DateFormat('dd MMM yyyy').format(DateTime.now());

    switch (_selectedTabIndex) {
      case 0:
        return _buildEmptyState(
          icon: Icons.check_circle_outline,
          title: 'No Open Events',
          message:
              'All events have been resolved. Great work maintaining system stability!',
          color: Colors.green,
        );
      case 1:
        return _buildEmptyState(
          icon: Icons.info_outline,
          title: 'No Closed Events Today',
          message: 'No events were closed today ($currentDate).',
          color: Colors.grey,
        );
      case 2:
        return _buildEmptyState(
          icon: Icons.event_available,
          title: 'No Events',
          message: 'No active events or events closed today.',
          color: Colors.grey,
        );
      default:
        return _buildEmptyState(
          icon: Icons.info,
          title: 'No Events',
          message: 'No events found.',
          color: Colors.grey,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final currentDate = DateFormat('dd MMM yyyy').format(DateTime.now());

    if (widget.substationId.isEmpty) {
      return _buildEmptyState(
        icon: Icons.location_off,
        title: 'No Substation Selected',
        message: 'Please select a substation to view events.',
        color: Colors.grey,
      );
    }

    return Scaffold(
      body: Column(
        children: [
          // ✨ UPDATED: Enhanced header to include breakdown events
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDarkMode
                    ? [
                        Colors.red.shade800.withOpacity(0.3),
                        Colors.orange.shade800.withOpacity(0.3),
                      ]
                    : [Colors.red.shade50, Colors.orange.shade50],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDarkMode
                    ? Colors.red.withOpacity(0.4)
                    : Colors.red.shade200,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.red.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isDarkMode
                            ? Colors.red.withOpacity(0.3)
                            : Colors.red.shade100,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.warning,
                        color: Colors.red.shade700,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'System Events',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Colors.red.shade700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.substationName,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: isDarkMode
                                  ? Colors.white.withOpacity(0.8)
                                  : theme.colorScheme.onSurface.withOpacity(
                                      0.8,
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    _buildCacheStatusIndicator(),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Open: All active events • Closed: Today only ($currentDate)',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDarkMode
                        ? Colors.white.withOpacity(0.7)
                        : theme.colorScheme.onSurface.withOpacity(0.7),
                    fontStyle: FontStyle.italic,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),

          // Tab Selector
          if (!_isLoading && _hasAnyBays) ...[
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: isDarkMode ? Colors.grey.shade800 : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  // Open Tab
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedTabIndex = 0),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: _selectedTabIndex == 0
                              ? (isDarkMode
                                    ? const Color(0xFF2C2C2E)
                                    : Colors.white)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: _selectedTabIndex == 0
                              ? [
                                  BoxShadow(
                                    color: isDarkMode
                                        ? Colors.black.withOpacity(0.3)
                                        : Colors.black.withOpacity(0.1),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ]
                              : null,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.pending_actions,
                              size: 14,
                              color: _selectedTabIndex == 0
                                  ? theme.colorScheme.primary
                                  : (isDarkMode
                                        ? Colors.white.withOpacity(0.6)
                                        : Colors.grey.shade600),
                            ),
                            const SizedBox(width: 3),
                            Text(
                              'Open',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: _selectedTabIndex == 0
                                    ? FontWeight.w600
                                    : FontWeight.w500,
                                color: _selectedTabIndex == 0
                                    ? theme.colorScheme.primary
                                    : (isDarkMode
                                          ? Colors.white.withOpacity(0.6)
                                          : Colors.grey.shade600),
                              ),
                            ),
                            if (_openEvents.isNotEmpty) ...[
                              const SizedBox(width: 2),
                              Container(
                                constraints: const BoxConstraints(maxWidth: 20),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 3,
                                  vertical: 1,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.orange.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '${_openEvents.length}',
                                  style: TextStyle(
                                    fontSize: 8,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.orange.shade700,
                                  ),
                                  textAlign: TextAlign.center,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Closed Tab
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedTabIndex = 1),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: _selectedTabIndex == 1
                              ? (isDarkMode
                                    ? const Color(0xFF2C2C2E)
                                    : Colors.white)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: _selectedTabIndex == 1
                              ? [
                                  BoxShadow(
                                    color: isDarkMode
                                        ? Colors.black.withOpacity(0.3)
                                        : Colors.black.withOpacity(0.1),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ]
                              : null,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.check_circle_outline,
                              size: 14,
                              color: _selectedTabIndex == 1
                                  ? theme.colorScheme.primary
                                  : (isDarkMode
                                        ? Colors.white.withOpacity(0.6)
                                        : Colors.grey.shade600),
                            ),
                            const SizedBox(width: 3),
                            Text(
                              'Closed',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: _selectedTabIndex == 1
                                    ? FontWeight.w600
                                    : FontWeight.w500,
                                color: _selectedTabIndex == 1
                                    ? theme.colorScheme.primary
                                    : (isDarkMode
                                          ? Colors.white.withOpacity(0.6)
                                          : Colors.grey.shade600),
                              ),
                            ),
                            if (_closedEvents.isNotEmpty) ...[
                              const SizedBox(width: 2),
                              Container(
                                constraints: const BoxConstraints(maxWidth: 20),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 3,
                                  vertical: 1,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.green.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '${_closedEvents.length}',
                                  style: TextStyle(
                                    fontSize: 8,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.green.shade700,
                                  ),
                                  textAlign: TextAlign.center,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Total Tab
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedTabIndex = 2),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: _selectedTabIndex == 2
                              ? (isDarkMode
                                    ? const Color(0xFF2C2C2E)
                                    : Colors.white)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: _selectedTabIndex == 2
                              ? [
                                  BoxShadow(
                                    color: isDarkMode
                                        ? Colors.black.withOpacity(0.3)
                                        : Colors.black.withOpacity(0.1),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ]
                              : null,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.bar_chart,
                              size: 14,
                              color: _selectedTabIndex == 2
                                  ? theme.colorScheme.primary
                                  : (isDarkMode
                                        ? Colors.white.withOpacity(0.6)
                                        : Colors.grey.shade600),
                            ),
                            const SizedBox(width: 3),
                            Text(
                              'Total',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: _selectedTabIndex == 2
                                    ? FontWeight.w600
                                    : FontWeight.w500,
                                color: _selectedTabIndex == 2
                                    ? theme.colorScheme.primary
                                    : (isDarkMode
                                          ? Colors.white.withOpacity(0.6)
                                          : Colors.grey.shade600),
                              ),
                            ),
                            if (_allRecentEvents.isNotEmpty) ...[
                              const SizedBox(width: 2),
                              Container(
                                constraints: const BoxConstraints(maxWidth: 20),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 3,
                                  vertical: 1,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.blue.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '${_allRecentEvents.length}',
                                  style: TextStyle(
                                    fontSize: 8,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.blue.shade700,
                                  ),
                                  textAlign: TextAlign.center,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Main content area - Expanded to fill remaining space
          Expanded(
            child: _isLoading
                ? Center(
                    child: Container(
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        color: isDarkMode
                            ? const Color(0xFF2C2C2E)
                            : Colors.white,
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
                          CircularProgressIndicator(
                            color: theme.colorScheme.primary,
                            strokeWidth: 3,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Loading events...',
                            style: TextStyle(
                              fontSize: 16,
                              color: isDarkMode
                                  ? Colors.white
                                  : theme.colorScheme.onSurface,
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
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ],
                      ),
                    ),
                  )
                : !_hasAnyBays
                ? _buildEmptyState(
                    icon: Icons.electrical_services_outlined,
                    title: 'No Bays Configured',
                    message:
                        'No bays have been configured in this substation. Events can only be recorded for configured bays.',
                    color: Colors.orange,
                  )
                : _getCurrentEventsList().isEmpty
                ? _getCurrentEmptyState()
                : ListView.builder(
                    padding: const EdgeInsets.only(
                      left: 16,
                      right: 16,
                      bottom: 100, // Space for FAB
                    ),
                    itemCount: _getCurrentEventsList().length,
                    itemBuilder: (context, index) {
                      return _buildEventCard(_getCurrentEventsList()[index]);
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: _hasAnyBays
          ? FloatingActionButton.extended(
              onPressed: _navigateToAddEvent,
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add),
              label: const Text('New Event'),
            )
          : null,
    );
  }
}

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
  List<TrippingShutdownEntry> _todayEvents = [];
  List<TrippingShutdownEntry> _openEvents = [];
  List<TrippingShutdownEntry> _allRecentEvents = [];
  bool _hasAnyBays = false;
  late AnimationController _animationController;

  // 🔧 FIX: Add cache health tracking and error handling
  bool _cacheHealthy = false;
  String? _cacheError;
  Map<String, int> _eventStats = {};

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

  // 🔧 FIX: Enhanced data loading with better error handling and validation
  Future<void> _loadTrippingData() async {
    if (widget.substationId.isEmpty) {
      setState(() {
        _isLoading = false;
        _todayEvents = [];
        _openEvents = [];
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

      // 🔧 FIX: Validate cache health before proceeding
      if (!_cache.validateCache()) {
        throw Exception('Cache validation failed - data may be stale');
      }

      final substationData = _cache.substationData!;
      _hasAnyBays = substationData.bays.isNotEmpty;
      _cacheHealthy = true;

      if (_hasAnyBays) {
        // Get today's events from cache
        _todayEvents = _cache.getTrippingEventsForDate(widget.selectedDate);

        // Get open events from cache
        _openEvents = _cache.getOpenTrippingEvents();

        // Get all recent events for statistics
        _allRecentEvents = substationData.recentTrippingEvents;

        // 🔧 FIX: Apply role-based filtering
        _applyRoleBasedFiltering();

        // Calculate statistics
        _calculateEventStats();
      }

      _animationController.forward();

      print(
        '✅ Tripping tab loaded ${_todayEvents.length} today events and ${_openEvents.length} open events from cache',
      );
    } catch (e) {
      print('❌ Error loading tripping data from cache: $e');
      setState(() {
        _cacheHealthy = false;
        _cacheError = e.toString();
      });

      if (mounted) {
        SnackBarUtils.showSnackBar(
          context,
          'Error loading tripping data: $e',
          isError: true,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // 🔧 FIX: Apply role-based filtering for events
  void _applyRoleBasedFiltering() {
    final bool isDivisionOrHigher = [
      UserRole.admin,
      UserRole.zoneManager,
      UserRole.circleManager,
      UserRole.divisionManager,
    ].contains(widget.currentUser.role);

    final bool isSubdivisionManager =
        widget.currentUser.role == UserRole.subdivisionManager;
    final bool isSubstationUser =
        widget.currentUser.role == UserRole.substationUser;

    // Filter based on user role
    if (isDivisionOrHigher) {
      // Division level and above can only see closed events
      _todayEvents = _todayEvents
          .where((event) => event.status == 'CLOSED')
          .toList();
      _openEvents = []; // No open events for division level
    } else if (isSubdivisionManager || isSubstationUser) {
      // Subdivision manager and substation user can see all events
      // No filtering needed
    }
  }

  // 🔧 FIX: Calculate event statistics for better insights
  void _calculateEventStats() {
    _eventStats.clear();

    // Count events by type
    final trippingCount = _allRecentEvents
        .where((e) => e.eventType == 'Tripping')
        .length;
    final shutdownCount = _allRecentEvents
        .where((e) => e.eventType == 'Shutdown')
        .length;
    final openCount = _openEvents.length;
    final todayCount = _todayEvents.length;

    _eventStats = {
      'tripping': trippingCount,
      'shutdown': shutdownCount,
      'open': openCount,
      'today': todayCount,
      'total': _allRecentEvents.length,
    };
  }

  // 🔧 FIX: Enhanced refresh with cache synchronization
  Future<void> _refreshTrippingData() async {
    try {
      // Force refresh the cache to ensure we have latest data
      await _cache.forceRefresh();

      // Reload from refreshed cache
      await _loadTrippingData();

      print('✅ Tripping data refreshed successfully');
    } catch (e) {
      print('❌ Error refreshing tripping data: $e');
      // Fallback to just reloading from existing cache
      await _loadTrippingData();
    }
  }

  // 🔧 FIX: Check user permissions for event operations
  bool _canCreateEvents() {
    return [
      UserRole.admin,
      UserRole.substationUser,
      UserRole.subdivisionManager,
    ].contains(widget.currentUser.role);
  }

  bool _canEditEvent(TrippingShutdownEntry event) {
    if (event.status == 'CLOSED') {
      return [
        UserRole.admin,
        UserRole.subdivisionManager,
      ].contains(widget.currentUser.role);
    }
    return [
      UserRole.admin,
      UserRole.substationUser,
      UserRole.subdivisionManager,
    ].contains(widget.currentUser.role);
  }

  Color _getEventTypeColor(String eventType) {
    switch (eventType) {
      case 'Tripping':
        return Colors.red;
      case 'Shutdown':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  IconData _getEventTypeIcon(String eventType) {
    switch (eventType) {
      case 'Tripping':
        return Icons.flash_on;
      case 'Shutdown':
        return Icons.power_off;
      default:
        return Icons.warning;
    }
  }

  // 🔧 FIX: Enhanced navigation with permission checks
  void _navigateToAddEvent() {
    if (!_hasAnyBays) {
      SnackBarUtils.showSnackBar(
        context,
        'Cannot create events. No bays configured in this substation.',
        isError: true,
      );
      return;
    }

    if (!_canCreateEvents()) {
      SnackBarUtils.showSnackBar(
        context,
        'You do not have permission to create events.',
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
    // Override viewOnly based on permissions and event status
    final bool forceViewOnly = !_canEditEvent(event) || isViewOnly;

    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (context) => TrippingShutdownEntryScreen(
              substationId: widget.substationId,
              substationName: widget.substationName,
              currentUser: widget.currentUser,
              entryToEdit: event,
              isViewOnly: forceViewOnly,
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
    if (!_canEditEvent(event)) {
      SnackBarUtils.showSnackBar(
        context,
        'You do not have permission to edit this event.',
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

  // 🔧 FIX: Enhanced event card with better visual indicators and permissions
  Widget _buildEventCard(TrippingShutdownEntry event) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final eventColor = _getEventTypeColor(event.eventType);
    final eventIcon = _getEventTypeIcon(event.eventType);
    final isOpen = event.status == 'OPEN';
    final canEdit = _canEditEvent(event);

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
            ? Border.all(color: Colors.orange.withOpacity(0.3), width: 2)
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
                        ? Colors.orange.withOpacity(0.1)
                        : Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isOpen
                          ? Colors.orange.withOpacity(0.5)
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
                            ? Colors.orange.shade700
                            : Colors.green.shade700,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        event.status,
                        style: TextStyle(
                          color: isOpen
                              ? Colors.orange.shade700
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
                      'Started: ${DateFormat('HH:mm').format(event.startTime.toDate())}',
                      style: TextStyle(
                        fontSize: 14,
                        color: isDarkMode
                            ? Colors.white.withOpacity(0.7)
                            : theme.colorScheme.onSurface.withOpacity(0.7),
                      ),
                    ),
                    const Spacer(),
                    // 🔧 FIX: Add event age indicator
                    _buildEventAgeIndicator(event),
                  ],
                ),
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
                        'Ended: ${DateFormat('HH:mm').format(event.endTime!.toDate())}',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.green.shade600,
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
                        Icons.timer,
                        size: 14,
                        color: isDarkMode
                            ? Colors.white.withOpacity(0.6)
                            : theme.colorScheme.onSurface.withOpacity(0.6),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Duration: ${_calculateDuration(event.startTime.toDate(), event.endTime!.toDate())}',
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
                // 🔧 FIX: Add permission indicator for non-editable events
                if (!canEdit && isOpen) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.amber.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.amber.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.lock,
                          size: 12,
                          color: Colors.amber.shade700,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'View only - Contact supervisor to edit',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.amber.shade700,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
            onTap: () {
              _navigateToViewEvent(event, isViewOnly: !canEdit);
            },
          ),

          // 🔧 FIX: Enhanced action buttons with permission-based visibility
          if (isOpen && canEdit) ...[
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
          ] else if (isOpen && !canEdit) ...[
            Divider(
              height: 1,
              color: isDarkMode
                  ? Colors.white.withOpacity(0.2)
                  : Colors.grey.shade300,
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () =>
                          _navigateToViewEvent(event, isViewOnly: true),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.grey,
                        side: BorderSide(color: Colors.grey),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      icon: const Icon(Icons.visibility, size: 18),
                      label: const Text('View Only'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // 🔧 FIX: Add event age indicator
  Widget _buildEventAgeIndicator(TrippingShutdownEntry event) {
    final now = DateTime.now();
    final eventTime = event.startTime.toDate();
    final duration = now.difference(eventTime);

    Color indicatorColor = Colors.grey;
    String ageText = '';

    if (duration.inMinutes < 60) {
      indicatorColor = Colors.red;
      ageText = '${duration.inMinutes}m ago';
    } else if (duration.inHours < 24) {
      indicatorColor = Colors.orange;
      ageText = '${duration.inHours}h ago';
    } else {
      indicatorColor = Colors.grey;
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

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    if (widget.substationId.isEmpty) {
      return _buildEmptyState(
        icon: Icons.location_off,
        title: 'No Substation Selected',
        message:
            'Please select a substation to view tripping & shutdown events.',
        color: Colors.grey,
      );
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        children: [
          // 🔧 FIX: Enhanced header with cache status and statistics
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
                            'Tripping & Shutdown Events',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Colors.red.shade700,
                            ),
                          ),
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
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.calendar_today,
                      size: 16,
                      color: isDarkMode
                          ? Colors.white.withOpacity(0.6)
                          : theme.colorScheme.onSurface.withOpacity(0.6),
                    ),
                    const SizedBox(width: 4),
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

                // 🔧 FIX: Add statistics row
                if (_hasAnyBays && _eventStats.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isDarkMode
                          ? const Color(0xFF3C3C3E)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildStatItem(
                          'Today',
                          '${_eventStats['today']}',
                          Icons.today,
                          Colors.red,
                        ),
                        _buildStatItem(
                          'Open',
                          '${_eventStats['open']}',
                          Icons.pending_actions,
                          Colors.orange,
                        ),
                        _buildStatItem(
                          'Total',
                          '${_eventStats['total']}',
                          Icons.bar_chart,
                          Colors.blue,
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
                            'Loading from cache...',
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
                        'No bays have been configured in this substation. Tripping and shutdown events can only be recorded for configured bays.',
                    color: Colors.orange,
                  )
                : DefaultTabController(
                    length: 2,
                    child: Column(
                      children: [
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 16),
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: isDarkMode
                                ? Colors.grey.shade800
                                : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: TabBar(
                            labelColor: theme.colorScheme.primary,
                            unselectedLabelColor: isDarkMode
                                ? Colors.white.withOpacity(0.6)
                                : Colors.grey.shade600,
                            labelStyle: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                            unselectedLabelStyle: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                            indicator: BoxDecoration(
                              color: isDarkMode
                                  ? const Color(0xFF2C2C2E)
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: [
                                BoxShadow(
                                  color: isDarkMode
                                      ? Colors.black.withOpacity(0.3)
                                      : Colors.black.withOpacity(0.1),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            indicatorSize: TabBarIndicatorSize.tab,
                            dividerColor: Colors.transparent,
                            tabs: [
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.today, size: 18),
                                    const SizedBox(width: 8),
                                    const Text('Today'),
                                    if (_todayEvents.isNotEmpty) ...[
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.red.withOpacity(0.15),
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                        child: Text(
                                          '${_todayEvents.length}',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.red.shade700,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.pending_actions, size: 18),
                                    const SizedBox(width: 8),
                                    const Text('Open'),
                                    if (_openEvents.isNotEmpty) ...[
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.orange.withOpacity(
                                            0.15,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                        child: Text(
                                          '${_openEvents.length}',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.orange.shade700,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        Expanded(
                          child: TabBarView(
                            children: [
                              _todayEvents.isEmpty
                                  ? _buildEmptyState(
                                      icon: Icons.check_circle_outline,
                                      title: 'No Events Today',
                                      message:
                                          'No tripping or shutdown events recorded for today. This is good news!',
                                      color: Colors.green,
                                    )
                                  : ListView(
                                      padding: const EdgeInsets.only(
                                        left: 16,
                                        right: 16,
                                        bottom: 100,
                                      ),
                                      children: _todayEvents
                                          .map(
                                            (event) => _buildEventCard(event),
                                          )
                                          .toList(),
                                    ),
                              _openEvents.isEmpty
                                  ? _buildEmptyState(
                                      icon: Icons.check_circle_outline,
                                      title: 'No Open Events',
                                      message:
                                          'All events have been resolved. Great work!',
                                      color: Colors.green,
                                    )
                                  : ListView(
                                      padding: const EdgeInsets.only(
                                        left: 16,
                                        right: 16,
                                        bottom: 100,
                                      ),
                                      children: _openEvents
                                          .map(
                                            (event) => _buildEventCard(event),
                                          )
                                          .toList(),
                                    ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
      floatingActionButton: (_hasAnyBays && _canCreateEvents())
          ? FloatingActionButton.extended(
              onPressed: _navigateToAddEvent,
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.notification_add),
              label: const Text(
                'Add Event',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              elevation: 6,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
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
        Icon(icon, color: color, size: 16),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
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

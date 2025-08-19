// lib/screens/tripping_shutdown_overview_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import '../../../models/user_model.dart';
import '../../../models/tripping_shutdown_model.dart';
import '../../../models/bay_model.dart';
import '../../../utils/snackbar_utils.dart';
import 'tripping_shutdown_entry_screen.dart';

class TrippingShutdownOverviewScreen extends StatefulWidget {
  final String substationId; // Now can be empty
  final String substationName; // Now can be "N/A"
  final AppUser currentUser;
  final DateTime? startDate; // NEW PARAMETER - Now nullable
  final DateTime? endDate; // NEW PARAMETER - Now nullable
  final bool canCreateTrippingEvents; // NEW PARAMETER

  const TrippingShutdownOverviewScreen({
    super.key,
    required this.substationId,
    required this.substationName,
    required this.currentUser,
    this.startDate, // No default value here, as it's nullable
    this.endDate, // No default value here, as it's nullable
    this.canCreateTrippingEvents = true,
  });

  @override
  State<TrippingShutdownOverviewScreen> createState() =>
      _TrippingShutdownOverviewScreenState();
}

class _TrippingShutdownOverviewScreenState
    extends State<TrippingShutdownOverviewScreen>
    with TickerProviderStateMixin {
  bool _isLoading = true;
  Map<String, List<TrippingShutdownEntry>> _groupedEntriesByBayType = {};
  List<String> _sortedBayTypes = [];
  Map<String, Bay> _baysMap = {};

  // Animation controllers for enhanced UI
  late AnimationController _fadeAnimationController;
  late AnimationController _slideAnimationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();

    // Initialize animations
    _fadeAnimationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _slideAnimationController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _fadeAnimationController,
        curve: Curves.easeInOut,
      ),
    );
    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _slideAnimationController,
            curve: Curves.easeOutCubic,
          ),
        );

    if (widget.substationId.isNotEmpty) {
      _fetchTrippingShutdownEvents();
    } else {
      _isLoading = false;
    }
  }

  @override
  void dispose() {
    _fadeAnimationController.dispose();
    _slideAnimationController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant TrippingShutdownOverviewScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Check if substationId or date filters have changed
    if (widget.substationId != oldWidget.substationId ||
        widget.startDate != oldWidget.startDate ||
        widget.endDate != oldWidget.endDate) {
      if (widget.substationId.isNotEmpty) {
        _fetchTrippingShutdownEvents();
      } else {
        setState(() {
          _isLoading = false;
          _groupedEntriesByBayType.clear();
          _sortedBayTypes.clear();
          _baysMap.clear();
        });
      }
    }
  }

  Future<void> _fetchTrippingShutdownEvents() async {
    setState(() {
      _isLoading = true;
      _groupedEntriesByBayType.clear();
      _sortedBayTypes.clear();
      _baysMap.clear();
    });

    try {
      // Fetch bays first
      final baysSnapshot = await FirebaseFirestore.instance
          .collection('bays')
          .where('substationId', isEqualTo: widget.substationId)
          .orderBy('name')
          .get();

      for (var doc in baysSnapshot.docs) {
        final bay = Bay.fromFirestore(doc);
        _baysMap[bay.id] = bay;
      }

      // Build events query
      Query eventsQuery = FirebaseFirestore.instance
          .collection('trippingShutdownEntries')
          .where('substationId', isEqualTo: widget.substationId);

      // Apply start date filter
      if (widget.startDate != null) {
        eventsQuery = eventsQuery.where(
          'startTime',
          isGreaterThanOrEqualTo: Timestamp.fromDate(widget.startDate!),
        );
      } else {
        // If no start date is provided, query from a very old date
        eventsQuery = eventsQuery.where(
          'startTime',
          isGreaterThanOrEqualTo: Timestamp.fromDate(DateTime.utc(1900)),
        );
      }

      // Apply end date filter
      if (widget.endDate != null) {
        // To include the entire end day, add one day and subtract one second
        eventsQuery = eventsQuery.where(
          'startTime',
          isLessThanOrEqualTo: Timestamp.fromDate(
            widget.endDate!
                .add(const Duration(days: 1))
                .subtract(const Duration(seconds: 1)),
          ),
        );
      } else {
        // If no end date is provided, query up to a very future date
        eventsQuery = eventsQuery.where(
          'startTime',
          isLessThanOrEqualTo: Timestamp.fromDate(DateTime.utc(2200)),
        );
      }

      eventsQuery = eventsQuery.orderBy('startTime', descending: true);

      final entriesSnapshot = await eventsQuery.get();

      List<TrippingShutdownEntry> fetchedEntries = entriesSnapshot.docs
          .map((doc) => TrippingShutdownEntry.fromFirestore(doc))
          .toList();

      // Apply role-based filtering
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

      fetchedEntries = fetchedEntries.where((entry) {
        if (isDivisionOrHigher) {
          return entry.status == 'CLOSED';
        } else if (isSubdivisionManager || isSubstationUser) {
          return true;
        }
        return false;
      }).toList();

      // Group entries by bay type
      for (var entry in fetchedEntries) {
        final Bay? bay = _baysMap[entry.bayId];
        if (bay != null) {
          final String bayType = bay.bayType;
          _groupedEntriesByBayType.putIfAbsent(bayType, () => []).add(entry);
        } else {
          _groupedEntriesByBayType
              .putIfAbsent('Unknown Bay Type', () => [])
              .add(entry);
        }
      }

      _sortedBayTypes = _groupedEntriesByBayType.keys.toList()..sort();

      // Start animations after data is loaded
      _fadeAnimationController.forward();
      _slideAnimationController.forward();
    } catch (e) {
      print("Error fetching tripping/shutdown events: $e");
      if (mounted) {
        SnackBarUtils.showSnackBar(
          context,
          'Failed to load events: $e',
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

  Future<void> _confirmDeleteEntry(
    String entryId,
    String eventType,
    String bayName,
  ) async {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    final bool confirm =
        await showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              backgroundColor: isDarkMode ? const Color(0xFF1C1C1E) : null,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Row(
                children: [
                  Icon(Icons.warning, color: Colors.red.shade600),
                  const SizedBox(width: 8),
                  Text(
                    'Confirm Deletion',
                    style: TextStyle(color: isDarkMode ? Colors.white : null),
                  ),
                ],
              ),
              content: Text(
                'Are you sure you want to delete this $eventType event for $bayName?\n\nThis action cannot be undone.',
                style: TextStyle(color: isDarkMode ? Colors.white : null),
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text(
                    'Cancel',
                    style: TextStyle(
                      color: isDarkMode
                          ? Colors.white
                          : theme.colorScheme.onSurface,
                    ),
                  ),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade600,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('Delete'),
                ),
              ],
            );
          },
        ) ??
        false;

    if (confirm) {
      try {
        await FirebaseFirestore.instance
            .collection('trippingShutdownEntries')
            .doc(entryId)
            .delete();
        if (mounted) {
          SnackBarUtils.showSnackBar(
            context,
            '$eventType event deleted successfully!',
          );
        }
        _fetchTrippingShutdownEvents(); // Re-fetch events after deletion
      } catch (e) {
        print("Error deleting event: $e");
        if (mounted) {
          SnackBarUtils.showSnackBar(
            context,
            'Failed to delete event: $e',
            isError: true,
          );
        }
      }
    }
  }

  // Updated navigation methods with substationName parameter
  void _navigateToViewEvent(TrippingShutdownEntry entry) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => TrippingShutdownEntryScreen(
          substationId: widget.substationId,
          substationName: widget.substationName, // ✅ Added required parameter
          currentUser: widget.currentUser,
          entryToEdit: entry,
          isViewOnly: true,
        ),
      ),
    );
  }

  void _navigateToEditEvent(TrippingShutdownEntry entry) {
    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (context) => TrippingShutdownEntryScreen(
              substationId: widget.substationId,
              substationName:
                  widget.substationName, // ✅ Added required parameter
              currentUser: widget.currentUser,
              entryToEdit: entry,
              isViewOnly: false,
            ),
          ),
        )
        .then((_) => _fetchTrippingShutdownEvents());
  }

  void _navigateToCreateEvent() {
    if (widget.substationId.isEmpty) {
      SnackBarUtils.showSnackBar(
        context,
        'Please select a substation first.',
        isError: true,
      );
      return;
    }

    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (context) => TrippingShutdownEntryScreen(
              substationId: widget.substationId,
              substationName:
                  widget.substationName, // ✅ Added required parameter
              currentUser: widget.currentUser,
              isViewOnly: false,
            ),
          ),
        )
        .then((_) => _fetchTrippingShutdownEvents());
  }

  // Get color for different bay types
  Color _getBayTypeColor(String bayType) {
    switch (bayType.toLowerCase()) {
      case 'transformer':
        return Colors.orange;
      case 'line':
        return Colors.blue;
      case 'feeder':
        return Colors.green;
      case 'busbar':
        return Colors.purple;
      case 'capacitor bank':
        return Colors.indigo;
      case 'reactor':
        return Colors.teal;
      default:
        return Colors.grey;
    }
  }

  // Get icon for different bay types
  IconData _getBayTypeIcon(String bayType) {
    switch (bayType.toLowerCase()) {
      case 'transformer':
        return Icons.transform;
      case 'line':
        return Icons.timeline;
      case 'feeder':
        return Icons.power;
      case 'busbar':
        return Icons.view_stream;
      case 'capacitor bank':
        return Icons.battery_full;
      case 'reactor':
        return Icons.settings_input_component;
      default:
        return Icons.electrical_services;
    }
  }

  // Enhanced event card widget
  Widget _buildEventCard(TrippingShutdownEntry entry) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final bay = _baysMap[entry.bayId];
    final String startTimeFormatted = DateFormat(
      'dd.MMM.yyyy HH:mm',
    ).format(entry.startTime.toDate());
    final String endTimeFormatted = entry.endTime != null
        ? DateFormat('dd.MMM.yyyy HH:mm').format(entry.endTime!.toDate())
        : 'N/A';

    final isOpen = entry.status == 'OPEN';
    final statusColor = isOpen ? Colors.orange : Colors.green;
    final statusIcon = isOpen ? Icons.hourglass_empty : Icons.check_circle;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
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
            ? Border.all(color: Colors.orange.withOpacity(0.3), width: 1)
            : null,
      ),
      child: Column(
        children: [
          ListTile(
            contentPadding: const EdgeInsets.all(16),
            leading: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: statusColor.withOpacity(0.3)),
              ),
              child: Icon(statusIcon, color: statusColor, size: 24),
            ),
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    '${entry.eventType} - ${entry.bayName}',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isDarkMode ? Colors.white : null,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: statusColor.withOpacity(0.5)),
                  ),
                  child: Text(
                    entry.status,
                    style: TextStyle(
                      color: statusColor.shade700,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
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
                      Icons.play_arrow,
                      size: 14,
                      color: isDarkMode
                          ? Colors.white.withOpacity(0.6)
                          : theme.colorScheme.onSurface.withOpacity(0.6),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Start: $startTimeFormatted',
                      style: TextStyle(
                        fontSize: 13,
                        color: isDarkMode
                            ? Colors.white.withOpacity(0.7)
                            : theme.colorScheme.onSurface.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
                if (entry.status == 'CLOSED') ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.stop, size: 14, color: Colors.green.shade600),
                      const SizedBox(width: 4),
                      Text(
                        'End: $endTimeFormatted',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.green.shade600,
                        ),
                      ),
                    ],
                  ),
                ],
                if (bay != null) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        _getBayTypeIcon(bay.bayType),
                        size: 14,
                        color: _getBayTypeColor(bay.bayType),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${bay.bayType} • ${bay.voltageLevel}',
                        style: TextStyle(
                          fontSize: 13,
                          color: _getBayTypeColor(bay.bayType),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
                if (entry.reasonForNonFeeder != null &&
                    entry.reasonForNonFeeder!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.blue.withOpacity(0.2)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: 14,
                          color: Colors.blue.shade600,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            'Reason: ${entry.reasonForNonFeeder}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.blue.shade700,
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
            trailing: Icon(
              Icons.arrow_forward_ios,
              color: isDarkMode
                  ? Colors.white.withOpacity(0.4)
                  : theme.colorScheme.onSurface.withOpacity(0.4),
              size: 16,
            ),
            onTap: () => _navigateToViewEvent(entry),
          ),
          // Action buttons
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDarkMode ? const Color(0xFF3C3C3E) : Colors.grey.shade50,
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(12),
                bottomRight: Radius.circular(12),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (entry.status == 'OPEN' &&
                    (widget.currentUser.role == UserRole.substationUser ||
                        widget.currentUser.role == UserRole.admin ||
                        widget.currentUser.role == UserRole.subdivisionManager))
                  ElevatedButton.icon(
                    onPressed: () => _navigateToEditEvent(entry),
                    icon: const Icon(Icons.check_circle_outline, size: 18),
                    label: const Text('Close Event'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                if (widget.currentUser.role == UserRole.admin) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    tooltip: 'Delete Event',
                    color: Colors.red.shade600,
                    onPressed: () => _confirmDeleteEntry(
                      entry.id!,
                      entry.eventType,
                      entry.bayName,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    // Handle empty substation case
    if (widget.substationId.isEmpty) {
      return Center(
        child: Container(
          margin: const EdgeInsets.all(32),
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
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: isDarkMode
                      ? Colors.white
                      : theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Please select a substation from the dropdown above to view tripping & shutdown events.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  fontStyle: FontStyle.italic,
                  color: isDarkMode
                      ? Colors.white.withOpacity(0.6)
                      : Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Define default dates for display
    final DateTime displayStartDate = widget.startDate ?? DateTime.utc(1900);
    final DateTime displayEndDate = widget.endDate ?? DateTime.utc(2200);

    return Scaffold(
      backgroundColor: isDarkMode
          ? const Color(0xFF1C1C1E)
          : const Color(0xFFF8F9FA),
      body: Column(
        children: [
          // Enhanced Header
          if (widget.substationName != "N/A")
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isDarkMode
                      ? [
                          Colors.red.shade900.withOpacity(0.3),
                          Colors.orange.shade900.withOpacity(0.3),
                        ]
                      : [Colors.red.shade50, Colors.orange.shade50],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDarkMode
                      ? Colors.red.shade600.withOpacity(0.3)
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
                          color: Colors.red.shade100,
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
                      // Auto-notify indicator
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.blue.withOpacity(0.3),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.notifications_active,
                              size: 14,
                              color: Colors.blue.shade700,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Auto-notify',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: Colors.blue.shade700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (widget.startDate != null && widget.endDate != null) ...[
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.date_range,
                          size: 16,
                          color: isDarkMode
                              ? Colors.white.withOpacity(0.6)
                              : theme.colorScheme.onSurface.withOpacity(0.6),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${DateFormat('dd.MMM.yyyy').format(widget.startDate!)} - ${DateFormat('dd.MMM.yyyy').format(widget.endDate!)}',
                          style: TextStyle(
                            fontSize: 14,
                            color: isDarkMode
                                ? Colors.white.withOpacity(0.7)
                                : theme.colorScheme.onSurface.withOpacity(0.7),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),

          // Content
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
                        ],
                      ),
                    ),
                  )
                : _groupedEntriesByBayType.isEmpty
                ? Center(
                    child: Container(
                      margin: const EdgeInsets.all(32),
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
                          Icon(
                            Icons.event_available,
                            size: 64,
                            color: Colors.green.shade400,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No Events Found',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                              color: Colors.green.shade700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            widget.startDate != null && widget.endDate != null
                                ? 'No tripping or shutdown events recorded for ${widget.substationName} between ${DateFormat('dd.MMM.yyyy').format(displayStartDate)} and ${DateFormat('dd.MMM.yyyy').format(displayEndDate)}.'
                                : 'No tripping or shutdown events recorded for ${widget.substationName}.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              fontStyle: FontStyle.italic,
                              color: isDarkMode
                                  ? Colors.white.withOpacity(0.6)
                                  : Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : FadeTransition(
                    opacity: _fadeAnimation,
                    child: SlideTransition(
                      position: _slideAnimation,
                      child: ListView.builder(
                        padding: const EdgeInsets.only(
                          left: 16,
                          right: 16,
                          bottom: 100, // Space for FAB
                        ),
                        itemCount: _sortedBayTypes.length,
                        itemBuilder: (context, index) {
                          final String bayType = _sortedBayTypes[index];
                          final List<TrippingShutdownEntry> entriesForType =
                              _groupedEntriesByBayType[bayType]!;

                          return Container(
                            margin: const EdgeInsets.only(bottom: 16),
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
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Theme(
                              data: theme.copyWith(
                                dividerColor: Colors.transparent,
                                textTheme: theme.textTheme.copyWith(
                                  titleMedium: TextStyle(
                                    color: isDarkMode ? Colors.white : null,
                                  ),
                                ),
                              ),
                              child: ExpansionTile(
                                initiallyExpanded: true,
                                title: Row(
                                  children: [
                                    Container(
                                      width: 32,
                                      height: 32,
                                      decoration: BoxDecoration(
                                        color: _getBayTypeColor(
                                          bayType,
                                        ).withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Icon(
                                        _getBayTypeIcon(bayType),
                                        color: _getBayTypeColor(bayType),
                                        size: 18,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      '$bayType Events',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: isDarkMode ? Colors.white : null,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: _getBayTypeColor(
                                          bayType,
                                        ).withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        '${entriesForType.length}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: _getBayTypeColor(bayType),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                children: entriesForType
                                    .map((entry) => _buildEventCard(entry))
                                    .toList(),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
          ),
        ],
      ),
      floatingActionButton: widget.canCreateTrippingEvents
          ? FloatingActionButton.extended(
              onPressed: _navigateToCreateEvent,
              label: const Text(
                'Add Event',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              icon: const Icon(Icons.notification_add),
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
              elevation: 6,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            )
          : null,
    );
  }
}

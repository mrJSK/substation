import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../models/tripping_shutdown_model.dart';
import '../../models/user_model.dart';
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

class _SubstationUserTrippingTabState extends State<SubstationUserTrippingTab> {
  bool _isLoading = true;
  List<TrippingShutdownEntry> _todayEvents = [];
  List<TrippingShutdownEntry> _openEvents = [];
  bool _hasAnyBays = false;

  @override
  void initState() {
    super.initState();
    _loadTrippingData();
  }

  @override
  void didUpdateWidget(SubstationUserTrippingTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedDate != widget.selectedDate ||
        oldWidget.substationId != widget.substationId) {
      _loadTrippingData();
    }
  }

  Future<void> _loadTrippingData() async {
    if (widget.substationId.isEmpty) {
      setState(() {
        _isLoading = false;
        _todayEvents = [];
        _openEvents = [];
        _hasAnyBays = false;
      });
      return;
    }

    setState(() => _isLoading = true);

    try {
      // First check if there are any bays in this substation
      await _checkForBays();

      if (_hasAnyBays) {
        await Future.wait([_loadTodayEvents(), _loadOpenEvents()]);
      }
    } catch (e) {
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

  Future<void> _checkForBays() async {
    try {
      final baysSnapshot = await FirebaseFirestore.instance
          .collection('bays')
          .where('substationId', isEqualTo: widget.substationId)
          .limit(1)
          .get();

      _hasAnyBays = baysSnapshot.docs.isNotEmpty;
    } catch (e) {
      print('Error checking for bays: $e');
      _hasAnyBays = false;
    }
  }

  Future<void> _loadTodayEvents() async {
    final startOfDay = DateTime(
      widget.selectedDate.year,
      widget.selectedDate.month,
      widget.selectedDate.day,
    );
    final endOfDay = startOfDay.add(const Duration(days: 1));

    final snapshot = await FirebaseFirestore.instance
        .collection('trippingShutdownEntries')
        .where('substationId', isEqualTo: widget.substationId)
        .where(
          'startTime',
          isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay),
        )
        .where('startTime', isLessThan: Timestamp.fromDate(endOfDay))
        .orderBy('startTime', descending: true)
        .get();

    _todayEvents = snapshot.docs
        .map((doc) => TrippingShutdownEntry.fromFirestore(doc))
        .toList();
  }

  Future<void> _loadOpenEvents() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('trippingShutdownEntries')
        .where('substationId', isEqualTo: widget.substationId)
        .where('status', isEqualTo: 'OPEN')
        .orderBy('startTime', descending: true)
        .limit(10)
        .get();

    _openEvents = snapshot.docs
        .map((doc) => TrippingShutdownEntry.fromFirestore(doc))
        .toList();
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
              currentUser: widget.currentUser,
              entryToEdit: null, // null for new entry
              isViewOnly: false,
            ),
          ),
        )
        .then((_) {
          // Refresh data when returning from add screen
          _loadTrippingData();
        });
  }

  Widget _buildEventCard(TrippingShutdownEntry event) {
    final theme = Theme.of(context);
    final eventColor = _getEventTypeColor(event.eventType);
    final eventIcon = _getEventTypeIcon(event.eventType);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
              ),
              child: Icon(eventIcon, color: eventColor, size: 24),
            ),
            title: Text(
              '${event.eventType} - ${event.bayName}',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text(
                  'Started: ${DateFormat('HH:mm').format(event.startTime.toDate())}',
                  style: TextStyle(
                    fontSize: 14,
                    color: theme.colorScheme.onSurface.withOpacity(0.7),
                  ),
                ),
                if (event.status == 'CLOSED' && event.endTime != null) ...[
                  Text(
                    'Ended: ${DateFormat('HH:mm').format(event.endTime!.toDate())}',
                    style: TextStyle(
                      fontSize: 14,
                      color: theme.colorScheme.onSurface.withOpacity(0.7),
                    ),
                  ),
                ],
              ],
            ),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: event.status == 'OPEN' ? Colors.orange : Colors.green,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                event.status,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            onTap: () {
              Navigator.of(context)
                  .push(
                    MaterialPageRoute(
                      builder: (context) => TrippingShutdownEntryScreen(
                        substationId: widget.substationId,
                        currentUser: widget.currentUser,
                        entryToEdit: event,
                        isViewOnly: event.status == 'CLOSED',
                      ),
                    ),
                  )
                  .then((_) {
                    _loadTrippingData();
                  });
            },
          ),
          if (event.status == 'OPEN') ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.of(context)
                          .push(
                            MaterialPageRoute(
                              builder: (context) => TrippingShutdownEntryScreen(
                                substationId: widget.substationId,
                                currentUser: widget.currentUser,
                                entryToEdit: event,
                                isViewOnly: false,
                              ),
                            ),
                          )
                          .then((_) {
                            _loadTrippingData();
                          });
                    },
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (widget.substationId.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32.0),
          child: Text(
            'Please select a substation to view tripping & shutdown events.',
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

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        children: [
          // Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.red.shade200),
            ),
            child: Column(
              children: [
                Icon(Icons.warning, color: Colors.red.shade700, size: 32),
                const SizedBox(height: 8),
                Text(
                  'Tripping & Shutdown Events',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.red.shade700,
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

          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : !_hasAnyBays
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
                            'No Bays Configured',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'No bays have been configured in this substation. Tripping and shutdown events can only be recorded for configured bays.',
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
                : DefaultTabController(
                    length: 2, // Today and Open events
                    child: Column(
                      children: [
                        // Sub-tabs
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: TabBar(
                            labelColor: theme.colorScheme.primary,
                            unselectedLabelColor: Colors.grey,
                            indicator: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            tabs: [
                              Tab(
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.today, size: 18),
                                    const SizedBox(width: 4),
                                    Text('Today (${_todayEvents.length})'),
                                  ],
                                ),
                              ),
                              Tab(
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.pending_actions, size: 18),
                                    const SizedBox(width: 4),
                                    Text('Open (${_openEvents.length})'),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Tab content
                        Expanded(
                          child: TabBarView(
                            children: [
                              // Today's Events
                              _todayEvents.isEmpty
                                  ? Center(
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.check_circle_outline,
                                            size: 64,
                                            color: Colors.green.shade400,
                                          ),
                                          const SizedBox(height: 16),
                                          Text(
                                            'No Events Today',
                                            style: TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.green.shade700,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            'No tripping or shutdown events recorded for today.',
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: Colors.grey.shade600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    )
                                  : ListView(
                                      padding: const EdgeInsets.only(
                                        left: 16,
                                        right: 16,
                                        bottom: 80, // Space for FAB
                                      ),
                                      children: _todayEvents
                                          .map(
                                            (event) => _buildEventCard(event),
                                          )
                                          .toList(),
                                    ),

                              // Open Events
                              _openEvents.isEmpty
                                  ? Center(
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.check_circle_outline,
                                            size: 64,
                                            color: Colors.green.shade400,
                                          ),
                                          const SizedBox(height: 16),
                                          Text(
                                            'No Open Events',
                                            style: TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.green.shade700,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            'All events have been resolved.',
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: Colors.grey.shade600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    )
                                  : ListView(
                                      padding: const EdgeInsets.only(
                                        left: 16,
                                        right: 16,
                                        bottom: 80, // Space for FAB
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
      // FAB for adding new events
      floatingActionButton: _hasAnyBays
          ? FloatingActionButton.extended(
              onPressed: _navigateToAddEvent,
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add),
              label: const Text(
                'Add Event',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            )
          : null, // Don't show FAB if no bays configured
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }
}

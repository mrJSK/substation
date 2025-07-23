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
    extends State<TrippingShutdownOverviewScreen> {
  bool _isLoading = true;
  Map<String, List<TrippingShutdownEntry>> _groupedEntriesByBayType = {};
  List<String> _sortedBayTypes = [];

  Map<String, Bay> _baysMap = {};

  @override
  void initState() {
    super.initState();
    if (widget.substationId.isNotEmpty) {
      _fetchTrippingShutdownEvents();
    } else {
      _isLoading = false;
    }
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
      final baysSnapshot = await FirebaseFirestore.instance
          .collection('bays')
          .where('substationId', isEqualTo: widget.substationId)
          .orderBy('name')
          .get();
      for (var doc in baysSnapshot.docs) {
        final bay = Bay.fromFirestore(doc);
        _baysMap[bay.id] = bay;
      }

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
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _confirmDeleteEntry(
    String entryId,
    String eventType,
    String bayName,
  ) async {
    final bool confirm =
        await showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('Confirm Deletion'),
              content: Text(
                'Are you sure you want to delete this $eventType event for $bayName? This action cannot be undone.',
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
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

  @override
  Widget build(BuildContext context) {
    if (widget.substationId.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Text(
            'Please select a substation from the dropdown above to view tripping & shutdown events.',
            textAlign: TextAlign.center,
            style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey),
          ),
        ),
      );
    }

    // Define default dates for display if they are null for the message
    // These should ideally match the default filter dates used in _fetchTrippingShutdownEvents
    final DateTime displayStartDate = widget.startDate ?? DateTime.utc(1900);
    final DateTime displayEndDate = widget.endDate ?? DateTime.utc(2200);

    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _groupedEntriesByBayType.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'No tripping or shutdown events recorded for ${widget.substationName} in the period ${DateFormat('dd.MMM.yyyy').format(displayStartDate)} - ${DateFormat('dd.MMM.yyyy').format(displayEndDate)}.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontStyle: FontStyle.italic,
                    color: Colors.grey.shade600,
                  ),
                ),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16.0),
              itemCount: _sortedBayTypes.length,
              itemBuilder: (context, index) {
                final String bayType = _sortedBayTypes[index];
                final List<TrippingShutdownEntry> entriesForType =
                    _groupedEntriesByBayType[bayType]!;

                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 8.0),
                  elevation: 3,
                  child: ExpansionTile(
                    initiallyExpanded: true,
                    title: Text(
                      '$bayType Events (${entriesForType.length})',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    leading: Icon(
                      Icons.category,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    children: entriesForType.map((entry) {
                      final String startTimeFormatted = DateFormat(
                        'dd.MMM.yyyy HH:mm',
                      ).format(entry.startTime.toDate());
                      final String endTimeFormatted = entry.endTime != null
                          ? DateFormat(
                              'dd.MMM.yyyy HH:mm',
                            ).format(entry.endTime!.toDate())
                          : 'N/A';

                      IconData statusIcon;
                      Color statusColor;
                      String statusText;

                      if (entry.status == 'OPEN') {
                        statusIcon = Icons.hourglass_empty;
                        statusColor = Colors.orange.shade700;
                        statusText = 'OPEN';
                      } else {
                        statusIcon = Icons.check_circle;
                        statusColor = Colors.green.shade700;
                        statusText = 'CLOSED';
                      }

                      return Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16.0,
                          vertical: 4.0,
                        ),
                        child: Column(
                          children: [
                            ListTile(
                              leading: Icon(statusIcon, color: statusColor),
                              title: Text(
                                '${entry.eventType} - ${entry.bayName}',
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Start: $startTimeFormatted'),
                                  Text('Status: $statusText'),
                                  if (entry.reasonForNonFeeder != null &&
                                      entry.reasonForNonFeeder!.isNotEmpty)
                                    Text('Reason: ${entry.reasonForNonFeeder}'),
                                  if (entry.status == 'CLOSED')
                                    Text('End: $endTimeFormatted'),
                                ],
                              ),
                              trailing: const Icon(Icons.arrow_forward_ios),
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        TrippingShutdownEntryScreen(
                                          substationId: widget.substationId,
                                          currentUser: widget.currentUser,
                                          entryToEdit: entry,
                                          isViewOnly: true,
                                        ),
                                  ),
                                );
                              },
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16.0,
                                vertical: 8.0,
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  if (entry.status == 'OPEN' &&
                                      (widget.currentUser.role ==
                                              UserRole.substationUser ||
                                          widget.currentUser.role ==
                                              UserRole.admin ||
                                          widget.currentUser.role ==
                                              UserRole.subdivisionManager))
                                    ElevatedButton.icon(
                                      onPressed: () {
                                        Navigator.of(context)
                                            .push(
                                              MaterialPageRoute(
                                                builder: (context) =>
                                                    TrippingShutdownEntryScreen(
                                                      substationId:
                                                          widget.substationId,
                                                      currentUser:
                                                          widget.currentUser,
                                                      entryToEdit: entry,
                                                      isViewOnly: false,
                                                    ),
                                              ),
                                            )
                                            .then(
                                              (_) =>
                                                  _fetchTrippingShutdownEvents(),
                                            );
                                      },
                                      icon: const Icon(Icons.flash_on),
                                      label: const Text('Close Event'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.green,
                                      ),
                                    ),
                                  const SizedBox(width: 8),
                                  if (widget.currentUser.role == UserRole.admin)
                                    Padding(
                                      padding: const EdgeInsets.only(left: 8.0),
                                      child: IconButton(
                                        icon: const Icon(Icons.delete_outline),
                                        tooltip: 'Delete Event',
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.error,
                                        onPressed: () => _confirmDeleteEntry(
                                          entry.id!,
                                          entry.eventType,
                                          entry.bayName,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            const Divider(height: 1),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
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
                    currentUser: widget.currentUser,
                    isViewOnly: false,
                  ),
                ),
              )
              .then(
                (_) => _fetchTrippingShutdownEvents(),
              ); // Re-fetch when returning
        },
        label: const Text('Add New Event'),
        icon: const Icon(Icons.add),
        backgroundColor: Theme.of(context).colorScheme.primary,
      ),
    );
  }
}

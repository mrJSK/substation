// lib/screens/tripping_shutdown_overview_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import '../../models/user_model.dart';
import '../../models/tripping_shutdown_model.dart'; // Import the new model
import '../../models/bay_model.dart'; // Import Bay model to get bay type
import '../../utils/snackbar_utils.dart';
import 'tripping_shutdown_entry_screen.dart'; // Screen 2: Entry form

class TrippingShutdownOverviewScreen extends StatefulWidget {
  final String substationId;
  final String substationName;
  final AppUser currentUser;

  const TrippingShutdownOverviewScreen({
    super.key,
    required this.substationId,
    required this.substationName,
    required this.currentUser,
  });

  @override
  State<TrippingShutdownOverviewScreen> createState() =>
      _TrippingShutdownOverviewScreenState();
}

class _TrippingShutdownOverviewScreenState
    extends State<TrippingShutdownOverviewScreen> {
  bool _isLoading = true;
  // Group events by bay type
  Map<String, List<TrippingShutdownEntry>> _groupedEntriesByBayType = {};
  List<String> _sortedBayTypes = []; // To maintain order of groups

  // Cache bay data for quick lookup of bayType by bayId
  Map<String, Bay> _baysMap = {};

  @override
  void initState() {
    super.initState();
    _fetchTrippingShutdownEntries();
  }

  Future<void> _fetchTrippingShutdownEntries() async {
    setState(() {
      _isLoading = true;
      _groupedEntriesByBayType.clear();
      _sortedBayTypes.clear();
      _baysMap.clear();
    });
    try {
      // 1. Fetch all bays for this substation to get their types
      final baysSnapshot = await FirebaseFirestore.instance
          .collection('bays')
          .where('substationId', isEqualTo: widget.substationId)
          .orderBy('name')
          .get();
      for (var doc in baysSnapshot.docs) {
        final bay = Bay.fromFirestore(doc);
        _baysMap[bay.id] = bay;
      }

      // 2. Fetch all tripping/shutdown entries for this substation
      final entriesSnapshot = await FirebaseFirestore.instance
          .collection('trippingShutdownEntries')
          .where('substationId', isEqualTo: widget.substationId)
          .orderBy(
            'startTime',
            descending: true,
          ) // Order by latest events first
          .get();

      final List<TrippingShutdownEntry> fetchedEntries = entriesSnapshot.docs
          .map((doc) => TrippingShutdownEntry.fromFirestore(doc))
          .toList();

      // 3. Group entries by bay type
      for (var entry in fetchedEntries) {
        final Bay? bay = _baysMap[entry.bayId];
        if (bay != null) {
          final String bayType = bay.bayType;
          _groupedEntriesByBayType.putIfAbsent(bayType, () => []).add(entry);
        } else {
          // Handle entries without a matching bay (e.g., bay deleted)
          _groupedEntriesByBayType
              .putIfAbsent('Unknown Bay Type', () => [])
              .add(entry);
        }
      }

      // 4. Sort bay types (groups) for consistent display
      _sortedBayTypes = _groupedEntriesByBayType.keys.toList()..sort();
    } catch (e) {
      print("Error fetching tripping/shutdown entries: $e");
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
        _fetchTrippingShutdownEntries(); // Refresh list
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
    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _groupedEntriesByBayType.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'No tripping or shutdown events recorded for ${widget.substationName}. Tap "+" to add one.',
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
                    initiallyExpanded: true, // Expand all groups by default
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

                      // Determine event status icon and color
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
                              // Main display for the event summary
                              leading: Icon(statusIcon, color: statusColor),
                              title: Text(
                                '${entry.eventType} - ${entry.bayName}',
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Start: $startTimeFormatted'),
                                  Text('Status: $statusText'),
                                  if (entry.status == 'CLOSED')
                                    Text('End: $endTimeFormatted'),
                                ],
                              ),
                              trailing: const Icon(
                                Icons.arrow_forward_ios,
                              ), // Keep arrow for expansion
                              onTap: () {
                                // NEW: onTap navigates to view-only details
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        TrippingShutdownEntryScreen(
                                          substationId: widget.substationId,
                                          currentUser: widget.currentUser,
                                          entryToEdit: entry,
                                          isViewOnly:
                                              true, // Always view-only for this tap
                                        ),
                                  ),
                                );
                              },
                            ),
                            // Action buttons moved below the ListTile for better layout
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16.0,
                                vertical: 8.0,
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  // Close Event Button (visible only if OPEN and user has permission)
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
                                                      entryToEdit:
                                                          entry, // Pass the existing entry to close
                                                      isViewOnly:
                                                          false, // It's an edit/close operation
                                                    ),
                                              ),
                                            )
                                            .then(
                                              (_) =>
                                                  _fetchTrippingShutdownEntries(),
                                            ); // Refresh on return
                                      },
                                      icon: const Icon(Icons.flash_on),
                                      label: const Text(
                                        'Close Event',
                                      ), // Changed label for clarity
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.green,
                                      ),
                                    ),
                                  const SizedBox(width: 8),
                                  // Delete Button (only for Admin)
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
                            const Divider(
                              height: 1,
                            ), // Separator between entries
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
          Navigator.of(context)
              .push(
                MaterialPageRoute(
                  builder: (context) => TrippingShutdownEntryScreen(
                    substationId: widget.substationId,
                    currentUser: widget.currentUser,
                    isViewOnly: false, // New creation is not view-only
                    // No entryToEdit for new creation
                  ),
                ),
              )
              .then(
                (_) => _fetchTrippingShutdownEntries(),
              ); // Refresh on return
        },
        label: const Text('Add New Event'),
        icon: const Icon(Icons.add),
        backgroundColor: Theme.of(context).colorScheme.primary,
      ),
    );
  }
}

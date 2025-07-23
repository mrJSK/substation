// lib/screens/subdivision_tripping_shutdown_overview_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:dropdown_search/dropdown_search.dart';
import 'package:provider/provider.dart';

import '../../models/user_model.dart';
import '../../models/tripping_shutdown_model.dart';
import '../../models/bay_model.dart';
import '../../models/hierarchy_models.dart'; // For Substation model
import '../../utils/snackbar_utils.dart';
import '../../models/app_state_data.dart';
import '../substation_dashboard/tripping_shutdown_entry_screen.dart';
import 'package:collection/collection.dart'; // For firstWhereOrNull

class TrippingTab extends StatefulWidget {
  final AppUser currentUser;
  final DateTime startDate; // Date range for filtering events
  final DateTime endDate; // Date range for filtering events

  const TrippingTab({
    super.key,
    required this.currentUser,
    required this.startDate,
    required this.endDate,
  });

  @override
  State<TrippingTab> createState() => _TrippingTabState();
}

class _TrippingTabState extends State<TrippingTab> {
  bool _isLoading = true;
  Map<String, List<TrippingShutdownEntry>> _groupedEntriesByBayType = {};
  List<String> _sortedBayTypes = [];

  Map<String, Bay> _baysMap = {}; // All bays in the subdivision (for lookup)
  List<Bay> _allBaysInSubdivisionList = []; // List of all bays for filters

  List<Substation> _substationsInSubdivision =
      []; // All substations in subdivision (for filter)
  Map<String, Substation> _substationsMap = {}; // Map for easy lookup

  // Filter States
  List<String> _selectedFilterSubstationIds = [];
  List<String> _selectedFilterVoltageLevels = [];
  List<String> _selectedFilterBayTypes = [];
  List<String> _selectedFilterBayIds = [];

  final List<String> _availableVoltageLevels = [
    '765kV',
    '400kV',
    '220kV',
    '132kV',
    '33kV',
    '11kV',
    '800kV',
    '25kV',
    '400V',
  ];
  final List<String> _availableBayTypes = [
    'Busbar',
    'Transformer',
    'Line',
    'Feeder',
    'Capacitor Bank',
    'Reactor',
    'Bus Coupler',
    'Battery',
  ];

  @override
  void initState() {
    super.initState();
    _fetchInitialHierarchyDataAndEvents();
  }

  @override
  void didUpdateWidget(covariant TrippingTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.startDate != oldWidget.startDate ||
        widget.endDate != oldWidget.endDate) {
      _fetchInitialHierarchyDataAndEvents();
    }
  }

  // Helper to parse voltage level values for sorting/comparison
  int _parseVoltageLevel(String? voltageLevel) {
    if (voltageLevel == null || voltageLevel.isEmpty) return 0;
    final regex = RegExp(r'(\d+)kV');
    final match = regex.firstMatch(voltageLevel);
    if (match != null && match.groupCount > 0) {
      return int.tryParse(match.group(1)!) ?? 0;
    }
    return 0;
  }

  // Fetch all substations and bays in the subdivision, then events
  Future<void> _fetchInitialHierarchyDataAndEvents() async {
    setState(() {
      _isLoading = true;
      _groupedEntriesByBayType.clear();
      _sortedBayTypes.clear();
      _baysMap.clear();
      _allBaysInSubdivisionList.clear();
      _substationsInSubdivision.clear();
      _substationsMap.clear();
    });

    try {
      final appState = Provider.of<AppStateData>(context, listen: false);
      final subdivisionId =
          appState.currentUser?.assignedLevels?['subdivisionId'];

      if (subdivisionId == null) {
        throw Exception('Subdivision ID not found for current user.');
      }

      // 1. Fetch all substations in the user's subdivision
      final substationsSnapshot = await FirebaseFirestore.instance
          .collection('substations')
          .where('subdivisionId', isEqualTo: subdivisionId)
          .orderBy('name')
          .get();
      _substationsInSubdivision = substationsSnapshot.docs
          .map((doc) => Substation.fromFirestore(doc))
          .toList();
      _substationsMap = {
        for (var sub in _substationsInSubdivision) sub.id: sub,
      };

      if (_substationsInSubdivision.isEmpty) {
        setState(() => _isLoading = false);
        return;
      }

      // 2. Fetch all bays within these substations
      final List<String> allSubstationIds = _substationsInSubdivision
          .map((s) => s.id)
          .toList();
      List<Bay> fetchedBays = [];
      for (int i = 0; i < allSubstationIds.length; i += 10) {
        // Chunking for whereIn query
        final chunk = allSubstationIds.sublist(
          i,
          i + 10 > allSubstationIds.length ? allSubstationIds.length : i + 10,
        );
        if (chunk.isEmpty) continue;

        final baysSnapshot = await FirebaseFirestore.instance
            .collection('bays')
            .where('substationId', whereIn: chunk)
            .get();
        fetchedBays.addAll(
          baysSnapshot.docs.map((doc) => Bay.fromFirestore(doc)).toList(),
        );
      }
      _allBaysInSubdivisionList = fetchedBays;
      _baysMap = {for (var bay in fetchedBays) bay.id: bay};

      // 3. Now fetch events based on fetched hierarchy data
      _fetchTrippingShutdownEvents(); // Call main event fetcher
    } catch (e) {
      print("Error fetching initial hierarchy data: $e");
      if (mounted) {
        SnackBarUtils.showSnackBar(
          context,
          'Failed to load hierarchy data: $e',
          isError: true,
        );
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _fetchTrippingShutdownEvents() async {
    if (!_isLoading) {
      // Only set loading if initial hierarchy data is already fetched
      setState(() => _isLoading = true);
    }
    _groupedEntriesByBayType.clear();
    _sortedBayTypes.clear();

    try {
      if (_substationsInSubdivision.isEmpty) {
        setState(() => _isLoading = false);
        return;
      }

      // Determine substation IDs to query events for
      List<String> eventSubstationIds = _substationsInSubdivision
          .map((s) => s.id)
          .toList();
      if (_selectedFilterSubstationIds.isNotEmpty) {
        eventSubstationIds = eventSubstationIds
            .where((id) => _selectedFilterSubstationIds.contains(id))
            .toList();
      }

      if (eventSubstationIds.isEmpty) {
        setState(() => _isLoading = false);
        return;
      }

      // Determine bay IDs to query based on applied filters
      List<String> bayIdsToQuery = [];

      if (_selectedFilterBayIds.isNotEmpty) {
        bayIdsToQuery = _selectedFilterBayIds;
      } else {
        List<Bay> filteredBays = _allBaysInSubdivisionList.where((bay) {
          if (_selectedFilterSubstationIds.isNotEmpty &&
              !_selectedFilterSubstationIds.contains(bay.substationId)) {
            return false;
          }

          bool matchesVoltage =
              _selectedFilterVoltageLevels.isEmpty ||
              _selectedFilterVoltageLevels.contains(bay.voltageLevel);
          bool matchesBayType =
              _selectedFilterBayTypes.isEmpty ||
              _selectedFilterBayTypes.contains(bay.bayType);
          return matchesVoltage && matchesBayType;
        }).toList();
        bayIdsToQuery = filteredBays.map((bay) => bay.id).toList();
      }

      if (bayIdsToQuery.isEmpty) {
        setState(() => _isLoading = false);
        return;
      }

      Query eventsQuery = FirebaseFirestore.instance.collection(
        'trippingShutdownEntries',
      );

      List<TrippingShutdownEntry> fetchedEntries = [];
      for (int i = 0; i < bayIdsToQuery.length; i += 10) {
        final chunk = bayIdsToQuery.sublist(
          i,
          i + 10 > bayIdsToQuery.length ? bayIdsToQuery.length : i + 10,
        );
        if (chunk.isEmpty) continue;

        final chunkQuery = eventsQuery
            .where('bayId', whereIn: chunk)
            .where('substationId', whereIn: eventSubstationIds);

        final startOfStartDate = DateTime(
          widget.startDate.year,
          widget.startDate.month,
          widget.startDate.day,
        );
        final endOfEndDate = DateTime(
          widget.endDate.year,
          widget.endDate.month,
          widget.endDate.day,
          23,
          59,
          59,
          999,
        );

        final entriesSnapshot = await chunkQuery
            .where(
              'startTime',
              isGreaterThanOrEqualTo: Timestamp.fromDate(startOfStartDate),
            )
            .where(
              'startTime',
              isLessThanOrEqualTo: Timestamp.fromDate(endOfEndDate),
            )
            .orderBy('startTime', descending: true)
            .get();

        fetchedEntries.addAll(
          entriesSnapshot.docs
              .map((doc) => TrippingShutdownEntry.fromFirestore(doc))
              .toList(),
        );
      }

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
        _fetchTrippingShutdownEvents(); // Refresh data
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

  // Filter Dialog Method
  Future<void> _showFilterDialog() async {
    List<String> tempSelectedSubstationIds = List.from(
      _selectedFilterSubstationIds,
    );
    List<String> tempSelectedVoltageLevels = List.from(
      _selectedFilterVoltageLevels,
    );
    List<String> tempSelectedBayTypes = List.from(_selectedFilterBayTypes);
    List<String> tempSelectedBayIds = List.from(_selectedFilterBayIds);

    await showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setStateInDialog) {
            return AlertDialog(
              title: const Text('Filter Events'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Filter by Substation (NEW for Subdivision user)
                    DropdownSearch<String>.multiSelection(
                      popupProps: const PopupPropsMultiSelection.menu(
                        showSearchBox: true,
                      ),
                      dropdownDecoratorProps: const DropDownDecoratorProps(
                        dropdownSearchDecoration: InputDecoration(
                          labelText: 'Substation(s)',
                          hintText: 'Filter by substation',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      itemAsString: (String id) =>
                          _substationsMap[id]?.name ?? 'Unknown Substation',
                      selectedItems: tempSelectedSubstationIds,
                      items: _substationsInSubdivision
                          .map((s) => s.id)
                          .toList(),
                      onChanged: (List<String> newValue) {
                        setStateInDialog(() {
                          tempSelectedSubstationIds = newValue;
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    // Filter by Voltage Level
                    DropdownSearch<String>.multiSelection(
                      popupProps: const PopupPropsMultiSelection.menu(
                        showSearchBox: true,
                      ),
                      dropdownDecoratorProps: const DropDownDecoratorProps(
                        dropdownSearchDecoration: InputDecoration(
                          labelText: 'Voltage Level(s)',
                          hintText: 'Filter by voltage level',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      itemAsString: (String s) => s,
                      selectedItems: tempSelectedVoltageLevels,
                      items: _availableVoltageLevels,
                      onChanged: (List<String> newValue) {
                        setStateInDialog(() {
                          tempSelectedVoltageLevels = newValue;
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    // Filter by Bay Type
                    DropdownSearch<String>.multiSelection(
                      popupProps: const PopupPropsMultiSelection.menu(
                        showSearchBox: true,
                      ),
                      dropdownDecoratorProps: const DropDownDecoratorProps(
                        dropdownSearchDecoration: InputDecoration(
                          labelText: 'Bay Type(s)',
                          hintText: 'Filter by bay type',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      itemAsString: (String s) => s,
                      selectedItems: tempSelectedBayTypes,
                      items: _availableBayTypes,
                      onChanged: (List<String> newValue) {
                        setStateInDialog(() {
                          tempSelectedBayTypes = newValue;
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    // Filter by Individual Bay
                    DropdownSearch<String>.multiSelection(
                      popupProps: const PopupPropsMultiSelection.menu(
                        showSearchBox: true,
                      ),
                      dropdownDecoratorProps: const DropDownDecoratorProps(
                        dropdownSearchDecoration: InputDecoration(
                          labelText: 'Specific Bay(s)',
                          hintText: 'Select individual bays',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      itemAsString: (String bayId) =>
                          _baysMap[bayId]?.name ?? 'Unknown Bay',
                      selectedItems: tempSelectedBayIds,
                      items: _allBaysInSubdivisionList
                          .map((bay) => bay.id)
                          .toList(), // List all bays in subdivision
                      onChanged: (List<String> newValue) {
                        setStateInDialog(() {
                          tempSelectedBayIds = newValue;
                        });
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    setStateInDialog(() {
                      tempSelectedSubstationIds.clear();
                      tempSelectedVoltageLevels.clear();
                      tempSelectedBayTypes.clear();
                      tempSelectedBayIds.clear();
                    });
                    // Apply cleared filters to parent state
                    setState(() {
                      _selectedFilterSubstationIds.clear();
                      _selectedFilterVoltageLevels.clear();
                      _selectedFilterBayTypes.clear();
                      _selectedFilterBayIds.clear();
                    });
                    _fetchTrippingShutdownEvents();
                    Navigator.of(dialogContext).pop();
                  },
                  child: const Text('Clear Filters'),
                ),
                ElevatedButton(
                  onPressed: () {
                    // Apply selected filters to parent state
                    setState(() {
                      _selectedFilterSubstationIds = tempSelectedSubstationIds;
                      _selectedFilterVoltageLevels = tempSelectedVoltageLevels;
                      _selectedFilterBayTypes = tempSelectedBayTypes;
                      _selectedFilterBayIds = tempSelectedBayIds;
                    });
                    _fetchTrippingShutdownEvents(); // Re-fetch events with new filters
                    Navigator.of(dialogContext).pop();
                  },
                  child: const Text('Apply Filters'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_substationsInSubdivision.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Text(
            'No substations found in your subdivision. Please ensure your user is assigned to a subdivision with substations.',
            textAlign: TextAlign.center,
            style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Events for ${widget.currentUser.assignedLevels?['subdivisionName'] ?? 'Your Subdivision'}',
        ), // Show subdivision name
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilterDialog, // Open filter dialog
            tooltip: 'Filter Events',
          ),
        ],
      ),
      body: _groupedEntriesByBayType.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'No tripping or shutdown events recorded for the selected period '
                  '${(_selectedFilterSubstationIds.isNotEmpty || _selectedFilterVoltageLevels.isNotEmpty || _selectedFilterBayTypes.isNotEmpty || _selectedFilterBayIds.isNotEmpty) ? 'with applied filters.' : 'in your subdivision.'}',
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
                                '${entry.eventType} - ${entry.bayName} '
                                '(${_substationsMap[entry.substationId]?.name ?? 'Unknown Substation'})', // Show substation name
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
                                  if (entry.eventType == 'Shutdown' &&
                                      entry.shutdownType != null)
                                    Text(
                                      'Shutdown Type: ${entry.shutdownType}',
                                    ),
                                  if (entry.eventType == 'Shutdown' &&
                                      entry.shutdownPersonName != null)
                                    Text('Person: ${entry.shutdownPersonName}'),
                                  if (entry.eventType == 'Shutdown' &&
                                      entry.shutdownPersonDesignation != null)
                                    Text(
                                      'Designation: ${entry.shutdownPersonDesignation}',
                                    ),
                                ],
                              ),
                              trailing: const Icon(Icons.arrow_forward_ios),
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        TrippingShutdownEntryScreen(
                                          substationId: entry
                                              .substationId, // Pass the specific substation ID
                                          currentUser: widget.currentUser,
                                          entryToEdit: entry,
                                          isViewOnly:
                                              true, // View details are read-only
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
                                  // Close Event Button (for OPEN events)
                                  if (entry.status == 'OPEN' &&
                                      (widget.currentUser.role ==
                                              UserRole.subdivisionManager ||
                                          widget.currentUser.role ==
                                              UserRole.admin))
                                    ElevatedButton.icon(
                                      onPressed: () {
                                        Navigator.of(context)
                                            .push(
                                              MaterialPageRoute(
                                                builder: (context) =>
                                                    TrippingShutdownEntryScreen(
                                                      substationId:
                                                          entry.substationId,
                                                      currentUser:
                                                          widget.currentUser,
                                                      entryToEdit: entry,
                                                      isViewOnly:
                                                          false, // Allow editing/closing for managers
                                                    ),
                                              ),
                                            )
                                            .then(
                                              (_) =>
                                                  _fetchTrippingShutdownEvents(),
                                            );
                                      },
                                      icon: const Icon(
                                        Icons.check_circle_outline,
                                      ),
                                      label: const Text('Close Event'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.green,
                                      ),
                                    ),
                                  const SizedBox(width: 8),
                                  // Edit Event Button (for OPEN events)
                                  if (entry.status == 'OPEN' &&
                                      (widget.currentUser.role ==
                                              UserRole.subdivisionManager ||
                                          widget.currentUser.role ==
                                              UserRole.admin))
                                    ElevatedButton.icon(
                                      onPressed: () {
                                        Navigator.of(context)
                                            .push(
                                              MaterialPageRoute(
                                                builder: (context) =>
                                                    TrippingShutdownEntryScreen(
                                                      substationId:
                                                          entry.substationId,
                                                      currentUser:
                                                          widget.currentUser,
                                                      entryToEdit: entry,
                                                      isViewOnly:
                                                          false, // Allow editing for managers
                                                    ),
                                              ),
                                            )
                                            .then(
                                              (_) =>
                                                  _fetchTrippingShutdownEvents(),
                                            );
                                      },
                                      icon: const Icon(Icons.edit),
                                      label: const Text('Edit Event'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Theme.of(
                                          context,
                                        ).colorScheme.secondary,
                                      ),
                                    ),
                                  const SizedBox(width: 8),
                                  // Delete Event Button (for Subdivision Manager and Admin)
                                  if (widget.currentUser.role ==
                                          UserRole.subdivisionManager ||
                                      widget.currentUser.role == UserRole.admin)
                                    IconButton(
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
          if (_substationsInSubdivision.isEmpty) {
            SnackBarUtils.showSnackBar(
              context,
              'No substations available in your subdivision to create an event.',
              isError: true,
            );
            return;
          }
          final defaultSubstationId = _substationsInSubdivision.first.id;

          Navigator.of(context)
              .push(
                MaterialPageRoute(
                  builder: (context) => TrippingShutdownEntryScreen(
                    substationId:
                        defaultSubstationId, // Pass a substation ID for new event
                    currentUser: widget.currentUser,
                    isViewOnly: false,
                  ),
                ),
              )
              .then((_) => _fetchTrippingShutdownEvents());
        },
        label: const Text('Add New Event'),
        icon: const Icon(Icons.add),
        backgroundColor: Theme.of(context).colorScheme.primary,
      ),
    );
  }
}

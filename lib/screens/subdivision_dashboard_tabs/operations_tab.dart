// lib/screens/subdivision_dashboard_tabs/operations_tab.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../models/hierarchy_models.dart';
import '../../models/bay_model.dart';
import '../../models/user_model.dart';
import '../../utils/snackbar_utils.dart';
import '../../models/app_state_data.dart';
import '../../models/logsheet_models.dart'; // Required for LogsheetEntry
import '../substation_dashboard/logsheet_entry_screen.dart'; // To navigate to single entry view

class OperationsTab extends StatefulWidget {
  final AppUser currentUser;
  final String? initialSelectedSubstationId;
  final VoidCallback? onRefreshParent;

  const OperationsTab({
    super.key,
    required this.currentUser,
    this.initialSelectedSubstationId,
    this.onRefreshParent,
  });

  @override
  State<OperationsTab> createState() => _OperationsTabState();
}

class _OperationsTabState extends State<OperationsTab> {
  // State variables for selection UI
  Substation? _selectedSubstation;
  List<String> _selectedBayIds = [];
  DateTime? _startDate;
  DateTime? _endDate;
  List<Bay> _bays = [];
  bool _isBaysLoading = false;

  // State variables for viewer UI (combined from MultiBayLogsheetViewerScreen)
  bool _isViewerLoading =
      false; // Initialized to false, will be true when fetching
  String? _viewerErrorMessage;
  List<LogsheetEntry> _rawLogsheetEntriesForViewer = [];
  Map<String, Bay> _viewerBaysMap = {}; // Map bay IDs to Bay objects for names
  Map<String, Map<DateTime, List<LogsheetEntry>>> _groupedEntriesForViewer = {};

  // New state for individual reading selection dropdown
  LogsheetEntry? _selectedIndividualReadingEntry;
  List<LogsheetEntry> _individualEntriesForDropdown =
      []; // Entries for the dropdown

  @override
  void initState() {
    super.initState();
    _startDate = DateTime.now();
    _endDate = DateTime.now();
  }

  // --- Methods for Selection UI ---
  Future<void> _fetchBaysForSelectedSubstation() async {
    if (_selectedSubstation == null) {
      if (mounted) {
        setState(() {
          _bays = []; // Clear bays if no substation selected
          _selectedBayIds = [];
          _individualEntriesForDropdown =
              []; // Clear individual entry dropdown data
          _selectedIndividualReadingEntry =
              null; // Clear selected individual entry
        });
      }
      return;
    }

    if (_isBaysLoading) return; // Prevent multiple concurrent fetches

    if (mounted) setState(() => _isBaysLoading = true);
    try {
      final baysSnapshot = await FirebaseFirestore.instance
          .collection('bays')
          .where('substationId', isEqualTo: _selectedSubstation!.id)
          .orderBy('name')
          .get();
      if (mounted) {
        setState(() {
          _bays = baysSnapshot.docs
              .map((doc) => Bay.fromFirestore(doc))
              .toList();
          // Filter out any previously selected bays that are no longer available
          _selectedBayIds = _selectedBayIds
              .where((id) => _bays.any((bay) => bay.id == id))
              .toList();
          _isBaysLoading = false;
        });
      }
    } catch (e) {
      print('Error fetching bays: $e');
      if (mounted) {
        SnackBarUtils.showSnackBar(
          context,
          'Error loading bays: $e',
          isError: true,
        );
        setState(() => _isBaysLoading = false);
      }
    }
  }

  Future<void> _selectDate(bool isStartDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isStartDate
          ? _startDate ?? DateTime.now()
          : _endDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate:
          DateTime.now(), // Restrict to current date for end date to avoid future entries
    );
    if (picked != null) {
      setState(() {
        if (isStartDate) {
          _startDate = picked;
          // Ensure end date is not before start date
          if (_endDate != null && _endDate!.isBefore(_startDate!)) {
            _endDate = _startDate;
          }
        } else {
          _endDate = picked;
          // Ensure start date is not after end date
          if (_startDate != null && _startDate!.isAfter(_endDate!)) {
            _startDate = _endDate;
          }
        }
        // Reset viewer data and individual dropdown on date change
        _rawLogsheetEntriesForViewer = [];
        _groupedEntriesForViewer = {};
        _individualEntriesForDropdown = [];
        _selectedIndividualReadingEntry = null;
      });
    }
  }

  Future<void> _selectMultipleBays() async {
    if (_bays.isEmpty) {
      SnackBarUtils.showSnackBar(
        context,
        'No bays available to select.',
        isError: true,
      );
      return;
    }

    final List<String> tempSelectedBayIds = List.from(_selectedBayIds);

    final List<String>? result = await showDialog<List<String>>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Select Bays'),
          content: SingleChildScrollView(
            child: Column(
              children: _bays.map((bay) {
                return StatefulBuilder(
                  builder:
                      (BuildContext context, StateSetter setStateInDialog) {
                        return CheckboxListTile(
                          title: Text('${bay.name} (${bay.bayType})'),
                          value: tempSelectedBayIds.contains(bay.id),
                          onChanged: (bool? selected) {
                            setStateInDialog(() {
                              if (selected == true) {
                                tempSelectedBayIds.add(bay.id);
                              } else {
                                tempSelectedBayIds.remove(bay.id);
                              }
                            });
                          },
                        );
                      },
                );
              }).toList(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(null); // Cancel
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(tempSelectedBayIds); // Confirm
              },
              child: const Text('Done'),
            ),
          ],
        );
      },
    );

    if (result != null) {
      setState(() {
        _selectedBayIds = result;
        // Reset viewer data and individual dropdown on bay change
        _rawLogsheetEntriesForViewer = [];
        _groupedEntriesForViewer = {};
        _individualEntriesForDropdown = [];
        _selectedIndividualReadingEntry = null;
      });
    }
  }

  // --- Methods for Viewer UI ---
  Future<void> _fetchLogsheetEntriesForViewer() async {
    setState(() {
      _isViewerLoading = true;
      _viewerErrorMessage = null;
      _rawLogsheetEntriesForViewer = [];
      _groupedEntriesForViewer = {};
      _individualEntriesForDropdown = [];
      _selectedIndividualReadingEntry = null;
    });

    try {
      // Fetch Bay details first to map IDs to names
      _viewerBaysMap.clear(); // Clear existing map
      final baysSnapshot = await FirebaseFirestore.instance
          .collection('bays')
          .where(FieldPath.documentId, whereIn: _selectedBayIds)
          .get();
      for (var doc in baysSnapshot.docs) {
        _viewerBaysMap[doc.id] = Bay.fromFirestore(doc);
      }

      // Prepare dates for query (Firestore Timestamps are UTC based)
      final DateTime queryStartDate = DateTime(
        _startDate!.year,
        _startDate!.month,
        _startDate!.day,
      ).toUtc();
      final DateTime queryEndDate = DateTime(
        _endDate!.year,
        _endDate!.month,
        _endDate!.day,
        23,
        59,
        59,
        999,
      ).toUtc();

      final logsheetSnapshot = await FirebaseFirestore.instance
          .collection('logsheetEntries')
          .where('substationId', isEqualTo: _selectedSubstation!.id)
          .where('bayId', whereIn: _selectedBayIds)
          .where(
            'frequency',
            isEqualTo: 'hourly',
          ) // Assuming hourly for this tab
          .where(
            'readingTimestamp',
            isGreaterThanOrEqualTo: Timestamp.fromDate(queryStartDate),
          )
          .where(
            'readingTimestamp',
            isLessThanOrEqualTo: Timestamp.fromDate(queryEndDate),
          )
          .orderBy('bayId')
          .orderBy('readingTimestamp')
          .get();

      _rawLogsheetEntriesForViewer = logsheetSnapshot.docs
          .map((doc) => LogsheetEntry.fromFirestore(doc))
          .toList();

      _groupLogsheetEntriesForViewer();

      // Populate individual entry dropdown if only one bay is selected
      if (_selectedBayIds.length == 1) {
        _individualEntriesForDropdown = _rawLogsheetEntriesForViewer;
        _individualEntriesForDropdown.sort(
          (a, b) => a.readingTimestamp.compareTo(b.readingTimestamp),
        );
      }
    } catch (e) {
      print('Error fetching logsheet entries for viewer: $e');
      if (mounted) {
        setState(() {
          _viewerErrorMessage = 'Failed to load logsheet entries: $e';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isViewerLoading = false;
        });
      }
    }
  }

  void _groupLogsheetEntriesForViewer() {
    _groupedEntriesForViewer.clear();
    for (var entry in _rawLogsheetEntriesForViewer) {
      final String bayId = entry.bayId;
      // Normalize timestamp to just the date part (midnight) for grouping
      final DateTime entryDate = DateTime(
        entry.readingTimestamp.toDate().year,
        entry.readingTimestamp.toDate().month,
        entry.readingTimestamp.toDate().day,
      );

      _groupedEntriesForViewer.putIfAbsent(bayId, () => {});
      _groupedEntriesForViewer[bayId]!.putIfAbsent(entryDate, () => []);
      _groupedEntriesForViewer[bayId]![entryDate]!.add(entry);
    }

    // Sort entries within each date group by hour
    _groupedEntriesForViewer.forEach((bayId, datesMap) {
      datesMap.forEach((date, entriesList) {
        entriesList.sort((a, b) {
          final hourA = a.readingTimestamp.toDate().hour;
          final hourB = b.readingTimestamp.toDate().hour;
          return hourA.compareTo(hourB);
        });
      });
    });
  }

  // --- Main UI Logic ---
  void _viewLogsheetEntry() {
    if (_selectedSubstation == null ||
        _selectedBayIds.isEmpty ||
        _startDate == null ||
        _endDate == null) {
      SnackBarUtils.showSnackBar(
        context,
        'Please select a substation, at least one bay, and a date range.',
        isError: true,
      );
      return;
    }
    // Directly fetch and display results on the same page
    _fetchLogsheetEntriesForViewer();
  }

  // UI for viewer display (will be called directly in the main build method)
  Widget _buildLogsheetViewerContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        Text(
          'Logsheet Entries for ${_selectedSubstation?.name ?? ''}',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        Text(
          '${DateFormat('MMM dd, yyyy').format(_startDate!)} - '
          '${DateFormat('MMM dd, yyyy').format(_endDate!)}',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 20),
        // New dropdown for individual readings (if only one bay selected)
        if (_selectedBayIds.length == 1 && !_isViewerLoading)
          DropdownButtonFormField<LogsheetEntry>(
            decoration: const InputDecoration(
              labelText: 'Select Specific Reading',
              border: OutlineInputBorder(),
            ),
            value: _selectedIndividualReadingEntry,
            items: _individualEntriesForDropdown.map((entry) {
              return DropdownMenuItem<LogsheetEntry>(
                value: entry,
                child: Text(
                  '${DateFormat('yyyy-MM-dd HH:mm').format(entry.readingTimestamp.toDate().toLocal())}',
                ),
              );
            }).toList(),
            onChanged: (LogsheetEntry? newValue) {
              setState(() {
                _selectedIndividualReadingEntry = newValue;
              });
              if (newValue != null) {
                // Navigate to LogsheetEntryScreen to view this specific entry
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => LogsheetEntryScreen(
                      substationId: _selectedSubstation!.id,
                      substationName: _selectedSubstation!.name,
                      bayId: newValue.bayId,
                      readingDate: newValue.readingTimestamp.toDate(),
                      frequency: newValue.frequency,
                      readingHour: newValue.readingHour,
                      currentUser: widget.currentUser,
                      forceReadOnly: true, // Always view in read-only mode here
                    ),
                  ),
                );
              }
            },
            isExpanded: true,
            hint: const Text('Select an individual reading to view details'),
          ),
        const SizedBox(height: 20),
        _isViewerLoading
            ? const Center(child: CircularProgressIndicator())
            : _viewerErrorMessage != null
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    _viewerErrorMessage!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              )
            : _groupedEntriesForViewer.isEmpty
            ? const Center(
                child: Text(
                  'No logsheet entries found for the selected criteria.',
                ),
              )
            : ListView.builder(
                shrinkWrap: true, // Important for nested ListView in Column
                physics: const NeverScrollableScrollPhysics(), // Important
                itemCount: _groupedEntriesForViewer.keys.length,
                itemBuilder: (context, bayIndex) {
                  final String bayId = _groupedEntriesForViewer.keys.elementAt(
                    bayIndex,
                  );
                  final Bay? bay = _viewerBaysMap[bayId];
                  final Map<DateTime, List<LogsheetEntry>> bayEntries =
                      _groupedEntriesForViewer[bayId]!;
                  final List<DateTime> sortedDates = bayEntries.keys.toList()
                    ..sort();

                  return Card(
                    margin: const EdgeInsets.all(8.0),
                    child: ExpansionTile(
                      title: Text(
                        bay != null
                            ? '${bay.name} (${bay.bayType})'
                            : 'Bay ID: $bayId',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      children: sortedDates.map((date) {
                        final List<LogsheetEntry> hourlyEntries =
                            bayEntries[date]!;
                        return Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16.0,
                            vertical: 8.0,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                DateFormat('yyyy-MM-dd').format(date),
                                style: Theme.of(context).textTheme.titleSmall,
                              ),
                              const SizedBox(height: 8),
                              Table(
                                columnWidths: const {
                                  0: FlexColumnWidth(1),
                                  1: FlexColumnWidth(2),
                                },
                                border: TableBorder.all(
                                  color: Colors.grey.shade300,
                                ),
                                children: [
                                  TableRow(
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade200,
                                    ),
                                    children: const [
                                      Padding(
                                        padding: EdgeInsets.all(8.0),
                                        child: Text(
                                          'Hour',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      Padding(
                                        padding: EdgeInsets.all(8.0),
                                        child: Text(
                                          'Readings',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  ...hourlyEntries.map((entry) {
                                    final String hour = DateFormat('HH:mm')
                                        .format(
                                          entry.readingTimestamp
                                              .toDate()
                                              .toLocal(),
                                        );
                                    final String readings = entry.values.entries
                                        .map((e) {
                                          if (e.value is Map &&
                                              e.value.containsKey('value')) {
                                            final bool boolValue =
                                                e.value['value'] as bool;
                                            final String? description =
                                                e.value['description_remarks']
                                                    as String?;
                                            return '${e.key}: ${boolValue ? 'Yes' : 'No'}${description != null && description.isNotEmpty ? ' ($description)' : ''}';
                                          } else if (e.value is Timestamp) {
                                            return '${e.key}: ${DateFormat('yyyy-MM-dd HH:mm').format((e.value as Timestamp).toDate().toLocal())}';
                                          }
                                          return '${e.key}: ${e.value}';
                                        })
                                        .join('\n');
                                    return TableRow(
                                      children: [
                                        Padding(
                                          padding: const EdgeInsets.all(8.0),
                                          child: Text(hour),
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.all(8.0),
                                          child: Text(readings),
                                        ),
                                      ],
                                    );
                                  }).toList(),
                                ],
                              ),
                              const SizedBox(height: 16),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  );
                },
              ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    // The main Column now includes both selection and viewer content
    final appState = Provider.of<AppStateData>(context);

    final substationsStream = FirebaseFirestore.instance
        .collection('substations')
        .where(
          'subdivisionId',
          isEqualTo: appState.currentUser?.assignedLevels?['subdivisionId'],
        )
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => Substation.fromFirestore(doc))
              .toList(),
        );

    return SingleChildScrollView(
      // Wrap in SingleChildScrollView to allow scrolling if content overflows
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          StreamBuilder<List<Substation>>(
            stream: substationsStream,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Text('Error loading substations: ${snapshot.error}');
              }
              final List<Substation> substations = snapshot.data ?? [];

              Substation? newSelectedSubstation;

              if (widget.initialSelectedSubstationId != null) {
                newSelectedSubstation = substations.firstWhereOrNull(
                  (sub) => sub.id == widget.initialSelectedSubstationId,
                );
              }

              if (newSelectedSubstation == null &&
                  _selectedSubstation != null) {
                newSelectedSubstation = substations.firstWhereOrNull(
                  (sub) => sub.id == _selectedSubstation!.id,
                );
              }

              if (newSelectedSubstation == null && substations.isNotEmpty) {
                newSelectedSubstation = substations.first;
              }

              // Update state for selected substation if it has changed
              if (newSelectedSubstation != _selectedSubstation) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  setState(() {
                    _selectedSubstation = newSelectedSubstation;
                    _fetchBaysForSelectedSubstation();
                    // Clear viewer data on substation change
                    _rawLogsheetEntriesForViewer = [];
                    _groupedEntriesForViewer = {};
                    _individualEntriesForDropdown = [];
                    _selectedIndividualReadingEntry = null;
                  });
                });
              } else if (_selectedSubstation != null &&
                  _bays.isEmpty &&
                  !_isBaysLoading) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _fetchBaysForSelectedSubstation();
                });
              }

              return DropdownButtonFormField<Substation>(
                decoration: const InputDecoration(
                  labelText: 'Select Substation',
                  border: OutlineInputBorder(),
                ),
                value: _selectedSubstation,
                items: substations.map((substation) {
                  return DropdownMenuItem(
                    value: substation,
                    child: Text(substation.name),
                  );
                }).toList(),
                onChanged: (Substation? newValue) {
                  setState(() {
                    _selectedSubstation = newValue;
                    _selectedBayIds = [];
                    _bays = [];
                    if (newValue != null) {
                      _fetchBaysForSelectedSubstation();
                    }
                    // Clear viewer data on substation change
                    _rawLogsheetEntriesForViewer = [];
                    _groupedEntriesForViewer = {};
                    _individualEntriesForDropdown = [];
                    _selectedIndividualReadingEntry = null;
                  });
                },
                isExpanded: true,
              );
            },
          ),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: _selectMultipleBays,
            child: AbsorbPointer(
              child: TextFormField(
                decoration: InputDecoration(
                  labelText: 'Selected Bays (${_selectedBayIds.length})',
                  border: const OutlineInputBorder(),
                  suffixIcon: _isBaysLoading
                      ? const CircularProgressIndicator()
                      : const Icon(Icons.arrow_drop_down),
                  filled: true,
                  fillColor: Theme.of(context).inputDecorationTheme.fillColor,
                ),
                controller: TextEditingController(
                  text: _selectedBayIds.isEmpty
                      ? 'No bays selected'
                      : _selectedBayIds
                            .map(
                              (id) =>
                                  _bays
                                      .firstWhereOrNull((bay) => bay.id == id)
                                      ?.name ??
                                  'Unknown Bay',
                            )
                            .join(', '),
                ),
                readOnly: true,
              ),
            ),
          ),
          const SizedBox(height: 10),
          ListTile(
            title: Text(
              'Start Date: ${_startDate != null ? DateFormat('yyyy-MM-dd').format(_startDate!) : 'Select Start Date'}',
            ),
            trailing: const Icon(Icons.calendar_today),
            onTap: () => _selectDate(true),
          ),
          const SizedBox(height: 10),
          ListTile(
            title: Text(
              'End Date: ${_endDate != null ? DateFormat('yyyy-MM-dd').format(_endDate!) : 'Select End Date'}',
            ),
            trailing: const Icon(Icons.calendar_today),
            onTap: () => _selectDate(false),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _viewLogsheetEntry,
            child: const Text('View Logsheet Entries'),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 50),
            ),
          ),
          // Conditionally show the viewer content directly below the button
          if (_rawLogsheetEntriesForViewer.isNotEmpty ||
              _isViewerLoading ||
              _viewerErrorMessage != null)
            _buildLogsheetViewerContent(),
        ],
      ),
    );
  }
}

// Extension to help with firstWhereOrNull, if not universally available
extension IterableExtension<T> on Iterable<T> {
  T? firstWhereOrNull(bool Function(T element) test) {
    for (var element in this) {
      if (test(element)) {
        return element;
      }
    }
    return null;
  }
}

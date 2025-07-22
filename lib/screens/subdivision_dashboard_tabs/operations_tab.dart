// lib/screens/subdivision_dashboard_tabs/operations_tab.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import '../../models/tripping_shutdown_model.dart';
import '../../models/user_model.dart';
import '../../models/bay_model.dart';
import '../../models/hierarchy_models.dart';
import '../../utils/snackbar_utils.dart';
import '../../models/user_readings_config_model.dart';
import '../tripping_shutdown_entry_screen.dart';
import '../../models/app_state_data.dart';
import '../create_report_template_screen.dart';

// Tripping & Shutdown Event List Widget (no change to its internal logic, just moved location)
class TrippingShutdownEventsList extends StatelessWidget {
  final List<TrippingShutdownEntry> events;
  final AppUser currentUser;
  final Map<String, Bay> baysMap;
  final Function() onRefresh;

  const TrippingShutdownEventsList({
    Key? key,
    required this.events,
    required this.currentUser,
    required this.baysMap,
    required this.onRefresh,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (events.isEmpty) {
      return const Center(
        child: Text(
          'No Tripping/Shutdown events found for the selected period.',
          style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16.0),
      itemCount: events.length,
      itemBuilder: (context, index) {
        final event = events[index];
        final bay =
            baysMap[event.bayId] ??
            Bay(
              id: event.bayId,
              name: event.bayName,
              substationId: event.substationId,
              voltageLevel: 'Unknown',
              bayType: 'Unknown',
              createdBy: '',
              createdAt: Timestamp.now(),
            );

        return Card(
          margin: const EdgeInsets.symmetric(vertical: 8.0),
          elevation: 3,
          child: ListTile(
            leading: Icon(
              event.status == 'OPEN'
                  ? Icons.hourglass_empty
                  : Icons.check_circle,
              color: event.status == 'OPEN' ? Colors.orange : Colors.green,
            ),
            title: Text('${event.eventType} - ${bay.name}'),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Start: ${DateFormat('dd.MMM.yyyy HH:mm').format(event.startTime.toDate())}',
                ),
                Text('Status: ${event.status}'),
                if (event.reasonForNonFeeder != null &&
                    event.reasonForNonFeeder!.isNotEmpty)
                  Text('Reason: ${event.reasonForNonFeeder}'),
                if (event.status == 'CLOSED' && event.endTime != null)
                  Text(
                    'End: ${DateFormat('dd.MMM.yyyy HH:mm').format(event.endTime!.toDate())}',
                  ),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.visibility),
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => TrippingShutdownEntryScreen(
                          substationId: event.substationId,
                          currentUser: currentUser,
                          entryToEdit: event,
                          isViewOnly: true,
                        ),
                      ),
                    );
                  },
                ),
                if (event.status == 'OPEN' &&
                    currentUser.role == UserRole.subdivisionManager)
                  IconButton(
                    icon: const Icon(Icons.edit),
                    onPressed: () {
                      Navigator.of(context)
                          .push(
                            MaterialPageRoute(
                              builder: (_) => TrippingShutdownEntryScreen(
                                substationId: event.substationId,
                                currentUser: currentUser,
                                entryToEdit: event,
                                isViewOnly: false,
                              ),
                            ),
                          )
                          .then((_) {
                            onRefresh();
                          });
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class OperationsTab extends StatefulWidget {
  final AppUser currentUser;
  final String? initialSelectedSubstationId;
  final Function() onRefreshParent;

  const OperationsTab({
    Key? key,
    required this.currentUser,
    this.initialSelectedSubstationId,
    required this.onRefreshParent,
  }) : super(key: key);

  @override
  _OperationsTabState createState() => _OperationsTabState();
}

class _OperationsTabState extends State<OperationsTab> {
  bool _isLoading = true;
  List<TrippingShutdownEntry> _trippingShutdownEvents = [];
  Map<String, Bay> _baysMap = {};
  List<Substation> _substations = [];
  String? _selectedSubstationId;
  late DateTime
  _startTime; // This is the old config-based start time, might not be needed directly for display
  DateTime _startDate = DateTime.now().subtract(
    const Duration(days: 7),
  ); // New: Start date for filter
  DateTime _endDate = DateTime.now(); // New: End date for filter

  @override
  void initState() {
    super.initState();
    _selectedSubstationId = widget.initialSelectedSubstationId;
    _initializeData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final newSelectedSubstationId = Provider.of<AppStateData>(
      context,
    ).selectedSubstation?.id;
    if (newSelectedSubstationId != null &&
        newSelectedSubstationId != _selectedSubstationId) {
      setState(() {
        _selectedSubstationId = newSelectedSubstationId;
        _fetchOperationsData(); // Re-fetch data for the new substation
      });
    } else if (_selectedSubstationId == null &&
        newSelectedSubstationId != null) {
      setState(() {
        _selectedSubstationId = newSelectedSubstationId;
        _fetchOperationsData();
      });
    }
  }

  Future<void> _initializeData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      // The user config for _startTime is less relevant now as we have explicit date pickers
      // However, keeping it for initial data load if no date is picked yet.
      final userId = widget.currentUser.uid;
      final configDoc = await FirebaseFirestore.instance
          .collection('userReadingsConfigurations')
          .doc(userId)
          .get();

      if (configDoc.exists) {
        final config = UserReadingsConfig.fromFirestore(configDoc);
        final now = DateTime.now();
        _startTime = now.subtract(
          Duration(
            hours: config.durationUnit == 'hours'
                ? config.durationValue
                : config.durationUnit == 'days'
                ? config.durationValue * 24
                : config.durationUnit == 'weeks'
                ? config.durationValue * 24 * 7
                : config.durationUnit == 'months'
                ? config.durationValue * 24 * 30
                : config.durationValue * 24 * 30, // Fallback
          ),
        );
      } else {
        _startTime = DateTime.now().subtract(const Duration(hours: 48));
      }

      await _fetchSubstations();
      if (_selectedSubstationId != null) {
        await _fetchOperationsData();
      } else {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    } catch (e) {
      print('Error initializing operations tab data: $e');
      if (mounted) {
        SnackBarUtils.showSnackBar(
          context,
          'Error initializing operations data: $e',
          isError: true,
        );
      }
      _startTime = DateTime.now().subtract(const Duration(hours: 48));
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _fetchSubstations() async {
    if (!mounted) return;
    try {
      final AppUser currentUser = widget.currentUser;

      if (currentUser.assignedLevels?['subdivisionId'] == null) {
        if (!mounted) return;
        SnackBarUtils.showSnackBar(
          context,
          'Subdivision ID not found in user profile. Please contact admin.',
          isError: true,
        );
        setState(() => _isLoading = false);
        return;
      }

      final subdivisionId = currentUser.assignedLevels!['subdivisionId'];

      final substationsSnapshot = await FirebaseFirestore.instance
          .collection('substations')
          .where('subdivisionId', isEqualTo: subdivisionId)
          .orderBy('name')
          .get();

      if (!mounted) return;
      setState(() {
        _substations = substationsSnapshot.docs
            .map((doc) => Substation.fromFirestore(doc))
            .toList();
        if (_selectedSubstationId == null && _substations.isNotEmpty) {
          _selectedSubstationId = _substations.first.id;
        }
        if (_selectedSubstationId != null) {
          final selectedSubstation = _substations.firstWhere(
            (s) => s.id == _selectedSubstationId,
          );
          Provider.of<AppStateData>(
            context,
            listen: false,
          ).setSelectedSubstation(selectedSubstation);
        }
      });
    } catch (e) {
      print('Error fetching substations for operations tab: $e');
      if (mounted) {
        SnackBarUtils.showSnackBar(
          context,
          'Error fetching substations for operations tab: $e',
          isError: true,
        );
      }
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _fetchOperationsData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    _trippingShutdownEvents.clear();
    _baysMap.clear();

    try {
      if (_selectedSubstationId == null) {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
        return;
      }

      List<Bay> fetchedBays = [];
      final baysSnapshot = await FirebaseFirestore.instance
          .collection('bays')
          .where('substationId', isEqualTo: _selectedSubstationId)
          .get();
      fetchedBays.addAll(
        baysSnapshot.docs.map((doc) => Bay.fromFirestore(doc)).toList(),
      );
      _baysMap = {for (var bay in fetchedBays) bay.id: bay};

      // Filter tripping events by the selected date range
      final trippingSnapshot = await FirebaseFirestore.instance
          .collection('trippingShutdownEntries')
          .where('substationId', isEqualTo: _selectedSubstationId)
          .where(
            'startTime',
            isGreaterThanOrEqualTo: Timestamp.fromDate(_startDate),
          )
          .where(
            'startTime',
            isLessThanOrEqualTo: Timestamp.fromDate(
              _endDate
                  .add(const Duration(days: 1))
                  .subtract(const Duration(seconds: 1)),
            ),
          ) // End of day
          .orderBy('startTime', descending: true)
          .get();
      _trippingShutdownEvents = trippingSnapshot.docs
          .map((doc) => TrippingShutdownEntry.fromFirestore(doc))
          .toList();

      if (!mounted) return;
      setState(() => _isLoading = false);
    } catch (e) {
      print('Error loading operations data: $e');
      if (mounted) {
        SnackBarUtils.showSnackBar(
          context,
          'Error loading operations data: $e',
          isError: true,
        );
      }
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // New: Date picker method
  Future<void> _selectDate(BuildContext context, bool isStartDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isStartDate ? _startDate : _endDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      if (!mounted) return;
      setState(() {
        if (isStartDate) {
          _startDate = picked;
          if (_startDate.isAfter(_endDate)) {
            _endDate = _startDate; // Ensure end date is not before start date
          }
        } else {
          _endDate = picked;
          if (_endDate.isBefore(_startDate)) {
            _startDate = _endDate; // Ensure start date is not after end date
          }
        }
      });
      _fetchOperationsData(); // Re-fetch data with new date range
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppStateData>(context);

    return Scaffold(
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                DropdownButtonFormField<String>(
                  decoration: InputDecoration(
                    labelText: 'Select Substation',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  value: _selectedSubstationId,
                  items: _substations
                      .map(
                        (substation) => DropdownMenuItem(
                          value: substation.id,
                          child: Text(substation.name),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedSubstationId = value;
                      _fetchOperationsData();
                      final selectedSubstation = _substations.firstWhere(
                        (s) => s.id == value,
                      );
                      appState.setSelectedSubstation(selectedSubstation);
                      widget.onRefreshParent();
                    });
                  },
                  validator: (value) =>
                      value == null ? 'Please select a substation' : null,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: ListTile(
                        title: Text(
                          'From: ${DateFormat('yyyy-MM-dd').format(_startDate)}',
                        ),
                        trailing: const Icon(Icons.calendar_today),
                        onTap: () => _selectDate(context, true),
                      ),
                    ),
                    Expanded(
                      child: ListTile(
                        title: Text(
                          'To: ${DateFormat('yyyy-MM-dd').format(_endDate)}',
                        ),
                        trailing: const Icon(Icons.calendar_today),
                        onTap: () => _selectDate(context, false),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _substations.isEmpty
                ? const Center(child: Text('No substations available.'))
                : TrippingShutdownEventsList(
                    events: _trippingShutdownEvents,
                    currentUser: widget.currentUser,
                    baysMap: _baysMap,
                    onRefresh: _fetchOperationsData,
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => CreateReportTemplateScreen(),
            ),
          );
        },
        label: const Text('Create Report Template'),
        icon: const Icon(Icons.add),
      ),
    );
  }
}

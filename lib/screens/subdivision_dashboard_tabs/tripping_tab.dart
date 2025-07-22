// lib/screens/subdivision_dashboard_tabs/tripping_tab.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart'; // For date formatting

import '../../models/user_model.dart';
import '../../models/app_state_data.dart';
import '../tripping_shutdown_overview_screen.dart'; // Assuming this screen exists

class TrippingTab extends StatefulWidget {
  final AppUser currentUser;
  final String? selectedSubstationId;

  const TrippingTab({
    Key? key,
    required this.currentUser,
    this.selectedSubstationId,
  }) : super(key: key);

  @override
  State<TrippingTab> createState() => _TrippingTabState();
}

class _TrippingTabState extends State<TrippingTab> {
  String? _currentSubstationId;
  String _currentSubstationName = 'N/A';
  DateTime _startDate = DateTime.now().subtract(
    const Duration(days: 7),
  ); // New: Start date for filter
  DateTime _endDate = DateTime.now(); // New: End date for filter

  @override
  void initState() {
    super.initState();
    _currentSubstationId = widget.selectedSubstationId;
    _updateSubstationInfo();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final appState = Provider.of<AppStateData>(context);
    final newSelectedSubstation = appState.selectedSubstation;

    if (newSelectedSubstation?.id != _currentSubstationId) {
      setState(() {
        _currentSubstationId = newSelectedSubstation?.id;
        _currentSubstationName = newSelectedSubstation?.name ?? 'N/A';
        // When substation changes, reset dates or keep them, depending on desired UX
        // For now, we'll keep the current date range.
      });
    } else if (_currentSubstationId == null && newSelectedSubstation != null) {
      setState(() {
        _currentSubstationId = newSelectedSubstation.id;
        _currentSubstationName = newSelectedSubstation.name;
      });
    }
  }

  void _updateSubstationInfo() {
    final appState = Provider.of<AppStateData>(context, listen: false);
    final selectedSubstation = appState.selectedSubstation;
    if (selectedSubstation != null) {
      _currentSubstationId = selectedSubstation.id;
      _currentSubstationName = selectedSubstation.name;
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
      // No explicit _fetchData call here, as TrippingShutdownOverviewScreen will react to prop changes
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_currentSubstationId == null || _currentSubstationId!.isEmpty) {
      return const Center(
        child: Text('Please select a substation to view tripping events.'),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text(
            'Tripping and Shutdown Events for $_currentSubstationName',
            style: Theme.of(context).textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
        ),
        // New: Date range selection UI
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
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
        ),
        const SizedBox(height: 16),
        Expanded(
          child: TrippingShutdownOverviewScreen(
            substationId: _currentSubstationId!,
            substationName: _currentSubstationName,
            currentUser: widget.currentUser,
            startDate: _startDate, // Pass start date
            endDate: _endDate, // Pass end date
            canCreateTrippingEvents: false, // User can only close, not create
          ),
        ),
      ],
    );
  }
}

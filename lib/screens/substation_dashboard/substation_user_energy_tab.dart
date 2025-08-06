import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../models/user_model.dart';
import '../../models/bay_model.dart';
import '../../models/reading_models.dart';
import '../../utils/snackbar_utils.dart';
import 'logsheet_entry_screen.dart';

class SubstationUserEnergyTab extends StatefulWidget {
  final String substationId;
  final String substationName;
  final AppUser currentUser;
  final DateTime selectedDate;

  const SubstationUserEnergyTab({
    super.key,
    required this.substationId,
    required this.substationName,
    required this.currentUser,
    required this.selectedDate,
  });

  @override
  State<SubstationUserEnergyTab> createState() =>
      _SubstationUserEnergyTabState();
}

class _SubstationUserEnergyTabState extends State<SubstationUserEnergyTab> {
  bool _isLoading = true;
  bool _isDailyReadingAvailable = false;
  bool _isDailyReadingComplete = false;
  List<Bay> _baysWithDailyAssignments = [];
  bool _hasAnyBaysWithReadings = false;

  @override
  void initState() {
    super.initState();
    _loadEnergyData();
  }

  @override
  void didUpdateWidget(SubstationUserEnergyTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedDate != widget.selectedDate ||
        oldWidget.substationId != widget.substationId) {
      _loadEnergyData();
    }
  }

  Future<void> _loadEnergyData() async {
    if (widget.substationId.isEmpty) {
      setState(() {
        _isLoading = false;
        _isDailyReadingAvailable = false;
        _isDailyReadingComplete = false;
        _hasAnyBaysWithReadings = false;
      });
      return;
    }

    setState(() => _isLoading = true);

    try {
      // First check if there are any bays with daily reading assignments
      await _checkForBaysWithDailyAssignments();

      if (!_hasAnyBaysWithReadings) {
        setState(() {
          _isLoading = false;
          _isDailyReadingAvailable = false;
          _isDailyReadingComplete = false;
        });
        return;
      }

      final DateTime now = DateTime.now();
      final bool isToday = DateUtils.isSameDay(widget.selectedDate, now);

      // Daily readings are available after 8 AM
      _isDailyReadingAvailable = !isToday || now.hour >= 8;

      if (_isDailyReadingAvailable) {
        await _checkDailyReadingCompletion();
      }
    } catch (e) {
      if (mounted) {
        SnackBarUtils.showSnackBar(
          context,
          'Error loading energy data: $e',
          isError: true,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _checkForBaysWithDailyAssignments() async {
    try {
      // Get all bays for this substation
      final baysSnapshot = await FirebaseFirestore.instance
          .collection('bays')
          .where('substationId', isEqualTo: widget.substationId)
          .get();

      if (baysSnapshot.docs.isEmpty) {
        _hasAnyBaysWithReadings = false;
        _baysWithDailyAssignments = [];
        return;
      }

      List<String> bayIds = baysSnapshot.docs.map((doc) => doc.id).toList();
      _baysWithDailyAssignments.clear();

      // Check for reading assignments with daily frequency
      final assignmentsSnapshot = await FirebaseFirestore.instance
          .collection('bayReadingAssignments')
          .where('bayId', whereIn: bayIds)
          .get();

      for (var doc in assignmentsSnapshot.docs) {
        final String bayId = doc['bayId'] as String;
        final assignedFieldsData =
            (doc.data() as Map)['assignedFields'] as List;

        final List<ReadingField> allFields = assignedFieldsData
            .map(
              (fieldMap) =>
                  ReadingField.fromMap(fieldMap as Map<String, dynamic>),
            )
            .toList();

        // Check if there are any mandatory daily fields
        final hasDailyMandatoryFields = allFields.any(
          (field) =>
              field.isMandatory &&
              field.frequency.toString().split('.').last == 'daily',
        );

        if (hasDailyMandatoryFields) {
          final Bay bay = Bay.fromFirestore(
            baysSnapshot.docs.firstWhere((bayDoc) => bayDoc.id == bayId),
          );
          _baysWithDailyAssignments.add(bay);
        }
      }

      _hasAnyBaysWithReadings = _baysWithDailyAssignments.isNotEmpty;
    } catch (e) {
      print('Error checking for bays with daily assignments: $e');
      _hasAnyBaysWithReadings = false;
      _baysWithDailyAssignments = [];
    }
  }

  Future<void> _checkDailyReadingCompletion() async {
    try {
      if (_baysWithDailyAssignments.isEmpty) {
        _isDailyReadingComplete = true;
        return;
      }

      bool allBaysComplete = true;

      // Check if all bays with daily assignments have readings
      for (var bay in _baysWithDailyAssignments) {
        final logsheetQuery = await FirebaseFirestore.instance
            .collection('logsheetEntries')
            .where('bayId', isEqualTo: bay.id)
            .where('frequency', isEqualTo: 'daily')
            .where(
              'readingTimestamp',
              isGreaterThanOrEqualTo: Timestamp.fromDate(
                DateTime(
                  widget.selectedDate.year,
                  widget.selectedDate.month,
                  widget.selectedDate.day,
                ),
              ),
            )
            .where(
              'readingTimestamp',
              isLessThan: Timestamp.fromDate(
                DateTime(
                  widget.selectedDate.year,
                  widget.selectedDate.month,
                  widget.selectedDate.day + 1,
                ),
              ),
            )
            .limit(1)
            .get();

        if (logsheetQuery.docs.isEmpty) {
          allBaysComplete = false;
          break;
        }
      }

      _isDailyReadingComplete = allBaysComplete;
    } catch (e) {
      print('Error checking daily reading completion: $e');
      _isDailyReadingComplete = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (widget.substationId.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32.0),
          child: Text(
            'Please select a substation to view energy data.',
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

    return Column(
      children: [
        // Header
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          margin: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.colorScheme.secondaryContainer.withOpacity(0.3),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: theme.colorScheme.secondary.withOpacity(0.3),
            ),
          ),
          child: Column(
            children: [
              Icon(
                Icons.electrical_services,
                color: theme.colorScheme.secondary,
                size: 32,
              ),
              const SizedBox(height: 8),
              Text(
                'Daily Energy Readings',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.secondary,
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
              : !_hasAnyBaysWithReadings
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
                          'No Daily Reading Assignments',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'No bays have been assigned daily reading templates in this substation. Please contact your administrator to set up bay reading assignments.',
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
              : !_isDailyReadingAvailable
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.access_time_filled,
                          size: 64,
                          color: Colors.orange.shade400,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Daily Energy Readings Unavailable',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.orange.shade700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Daily readings for today will be available after 08:00 AM IST.',
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
              : Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
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
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              color:
                                  (_isDailyReadingComplete
                                          ? Colors.green
                                          : Colors.orange)
                                      .withOpacity(0.1),
                              borderRadius: BorderRadius.circular(32),
                            ),
                            child: Icon(
                              _isDailyReadingComplete
                                  ? Icons.check_circle
                                  : Icons.pending,
                              color: _isDailyReadingComplete
                                  ? Colors.green
                                  : Colors.orange,
                              size: 32,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Daily Reading Status',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _isDailyReadingComplete
                                ? 'All readings completed'
                                : 'Readings pending',
                            style: TextStyle(
                              fontSize: 16,
                              color: _isDailyReadingComplete
                                  ? Colors.green
                                  : Colors.orange,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${_baysWithDailyAssignments.length} bays assigned for daily readings',
                            style: TextStyle(
                              fontSize: 14,
                              color: theme.colorScheme.onSurface.withOpacity(
                                0.6,
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton.icon(
                            onPressed: () {
                              Navigator.of(context)
                                  .push(
                                    MaterialPageRoute(
                                      builder: (context) => LogsheetEntryScreen(
                                        substationId: widget.substationId,
                                        substationName: widget.substationName,
                                        bayId: '',
                                        readingDate: widget.selectedDate,
                                        frequency: 'daily',
                                        currentUser: widget.currentUser,
                                        forceReadOnly: false,
                                      ),
                                    ),
                                  )
                                  .then((_) {
                                    _loadEnergyData();
                                  });
                            },
                            icon: Icon(
                              _isDailyReadingComplete
                                  ? Icons.visibility
                                  : Icons.edit,
                            ),
                            label: Text(
                              _isDailyReadingComplete
                                  ? 'View Readings'
                                  : 'Enter Readings',
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: theme.colorScheme.primary,
                              foregroundColor: theme.colorScheme.onPrimary,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}

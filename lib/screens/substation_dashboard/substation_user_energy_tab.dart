import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../models/user_model.dart';
import '../../models/bay_model.dart';
import '../../models/reading_models.dart';
import '../../models/logsheet_models.dart';
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

class _SubstationUserEnergyTabState extends State<SubstationUserEnergyTab>
    with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  bool _isDailyReadingAvailable = false;
  List<Bay> _baysWithDailyAssignments = [];
  bool _hasAnyBaysWithReadings = false;
  late AnimationController _animationController;

  // Track completion status for each bay
  Map<String, bool> _bayCompletionStatus = {};
  Map<String, bool> _bayEnergyCompletionStatus = {};
  Map<String, int> _bayMandatoryFieldsCount = {};
  Map<String, Map<String, dynamic>> _bayLastReadings = {};

  // Required energy fields for calculation
  static const List<String> REQUIRED_ENERGY_FIELDS = [
    'Current Day Reading (Import)',
    'Previous Day Reading (Import)',
    'Current Day Reading (Export)',
    'Previous Day Reading (Export)',
  ];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _loadEnergyData();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
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
        });
        return;
      }

      final DateTime now = DateTime.now();
      final bool isToday = DateUtils.isSameDay(widget.selectedDate, now);

      // Daily readings are available after 8 AM
      _isDailyReadingAvailable = !isToday || now.hour >= 8;

      if (_isDailyReadingAvailable) {
        await _checkDailyReadingCompletion();
        await _loadLastReadingsForAutoPopulate();
      }

      _animationController.forward();
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
          .orderBy('name')
          .get();

      if (baysSnapshot.docs.isEmpty) {
        _hasAnyBaysWithReadings = false;
        _baysWithDailyAssignments = [];
        return;
      }

      List<String> bayIds = baysSnapshot.docs.map((doc) => doc.id).toList();
      _baysWithDailyAssignments.clear();
      _bayMandatoryFieldsCount.clear();

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
        final dailyMandatoryFields = allFields
            .where(
              (field) =>
                  field.isMandatory &&
                  field.frequency.toString().split('.').last == 'daily',
            )
            .toList();

        if (dailyMandatoryFields.isNotEmpty) {
          final Bay bay = Bay.fromFirestore(
            baysSnapshot.docs.firstWhere((bayDoc) => bayDoc.id == bayId),
          );
          _baysWithDailyAssignments.add(bay);
          _bayMandatoryFieldsCount[bayId] = dailyMandatoryFields.length;
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
      _bayCompletionStatus.clear();
      _bayEnergyCompletionStatus.clear();

      // Check completion for each bay individually
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

        bool isComplete = false;
        bool hasEnergyReadings = false;

        if (logsheetQuery.docs.isNotEmpty) {
          final entry = LogsheetEntry.fromFirestore(logsheetQuery.docs.first);
          isComplete = true;

          // Check if all required energy fields are present and have valid values
          hasEnergyReadings = REQUIRED_ENERGY_FIELDS.every((fieldName) {
            final value = entry.values[fieldName];
            if (value == null) return false;

            final stringValue = value.toString().trim();
            if (stringValue.isEmpty) return false;

            // Check if it's a valid number
            final numValue = double.tryParse(stringValue);
            return numValue != null && numValue >= 0;
          });
        }

        _bayCompletionStatus[bay.id] = isComplete;
        _bayEnergyCompletionStatus[bay.id] = hasEnergyReadings;
      }
    } catch (e) {
      print('Error checking daily reading completion: $e');
      for (var bay in _baysWithDailyAssignments) {
        _bayCompletionStatus[bay.id] = false;
        _bayEnergyCompletionStatus[bay.id] = false;
      }
    }
  }

  Future<void> _loadLastReadingsForAutoPopulate() async {
    try {
      _bayLastReadings.clear();

      // Get previous day for auto-populate
      final previousDay = widget.selectedDate.subtract(const Duration(days: 1));
      final startOfPreviousDay = DateTime(
        previousDay.year,
        previousDay.month,
        previousDay.day,
      );
      final endOfPreviousDay = DateTime(
        previousDay.year,
        previousDay.month,
        previousDay.day,
        23,
        59,
        59,
      );

      for (var bay in _baysWithDailyAssignments) {
        try {
          final yesterdaySnapshot = await FirebaseFirestore.instance
              .collection('logsheetEntries')
              .where('bayId', isEqualTo: bay.id)
              .where('frequency', isEqualTo: 'daily')
              .where(
                'readingTimestamp',
                isGreaterThanOrEqualTo: Timestamp.fromDate(startOfPreviousDay),
              )
              .where(
                'readingTimestamp',
                isLessThanOrEqualTo: Timestamp.fromDate(endOfPreviousDay),
              )
              .orderBy('readingTimestamp', descending: true)
              .limit(1)
              .get();

          if (yesterdaySnapshot.docs.isNotEmpty) {
            final yesterdayEntry = LogsheetEntry.fromFirestore(
              yesterdaySnapshot.docs.first,
            );
            _bayLastReadings[bay.id] = {
              'Previous Day Reading (Import)':
                  yesterdayEntry.values['Current Day Reading (Import)'],
              'Previous Day Reading (Export)':
                  yesterdayEntry.values['Current Day Reading (Export)'],
              'lastReadingDate': DateFormat('dd-MMM-yyyy').format(previousDay),
            };
          }
        } catch (e) {
          print('Error loading last reading for bay ${bay.id}: $e');
        }
      }
    } catch (e) {
      print('Error loading last readings for auto-populate: $e');
    }
  }

  Future<bool> validateEnergyDataForCalculation() async {
    final incompleteBays = <String>[];

    for (var bay in _baysWithDailyAssignments) {
      if (!(_bayEnergyCompletionStatus[bay.id] ?? false)) {
        incompleteBays.add(bay.name);
      }
    }

    if (incompleteBays.isNotEmpty) {
      SnackBarUtils.showSnackBar(
        context,
        'Energy calculation incomplete. Missing energy readings for: ${incompleteBays.join(', ')}',
        isError: true,
      );
      return false;
    }

    SnackBarUtils.showSnackBar(
      context,
      'All energy readings are complete and ready for calculation!',
    );
    return true;
  }

  Widget _buildBayCard(Bay bay, int index) {
    final theme = Theme.of(context);
    final bool isComplete = _bayCompletionStatus[bay.id] ?? false;
    final bool hasEnergyReadings = _bayEnergyCompletionStatus[bay.id] ?? false;
    final int mandatoryFields = _bayMandatoryFieldsCount[bay.id] ?? 0;
    final bool hasLastReading = _bayLastReadings.containsKey(bay.id);

    // Status colors based on energy completion
    Color statusColor = hasEnergyReadings
        ? Colors.green
        : (isComplete ? Colors.blue : Colors.orange);
    IconData statusIcon = hasEnergyReadings
        ? Icons.check_circle
        : (isComplete ? Icons.assignment_turned_in : Icons.pending);
    String statusText = hasEnergyReadings
        ? 'Energy Complete'
        : (isComplete ? 'Readings Complete' : 'Pending');

    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return SlideTransition(
          position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
              .animate(
                CurvedAnimation(
                  parent: _animationController,
                  curve: Interval(index * 0.1, 1.0, curve: Curves.easeOut),
                ),
              ),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
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
              border: Border.all(color: statusColor.withOpacity(0.3), width: 1),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: _isDailyReadingAvailable
                    ? () {
                        Navigator.of(context)
                            .push(
                              MaterialPageRoute(
                                builder: (context) => LogsheetEntryScreen(
                                  substationId: widget.substationId,
                                  substationName: widget.substationName,
                                  bayId: bay.id,
                                  readingDate: widget.selectedDate,
                                  frequency: 'daily',
                                  readingHour: null,
                                  currentUser: widget.currentUser,
                                  forceReadOnly: false,
                                  autoPopulateData:
                                      _bayLastReadings[bay
                                          .id], // Pass auto-populate data
                                ),
                              ),
                            )
                            .then((_) => _loadEnergyData());
                      }
                    : null,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          // Bay Icon
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: statusColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              _getBayTypeIcon(bay.bayType),
                              color: statusColor,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 16),

                          // Bay Details
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  bay.name,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Voltage Level: ${bay.voltageLevel}',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: theme.colorScheme.onSurface
                                        .withOpacity(0.6),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.assignment,
                                      size: 16,
                                      color: theme.colorScheme.onSurface
                                          .withOpacity(0.6),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '$mandatoryFields mandatory fields',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: theme.colorScheme.onSurface
                                            .withOpacity(0.6),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          // Status Badge
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: statusColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: statusColor.withOpacity(0.3),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(statusIcon, size: 14, color: statusColor),
                                const SizedBox(width: 4),
                                Text(
                                  statusText,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: statusColor,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          if (_isDailyReadingAvailable) ...[
                            const SizedBox(width: 12),
                            Icon(
                              Icons.arrow_forward_ios,
                              color: theme.colorScheme.primary,
                              size: 16,
                            ),
                          ],
                        ],
                      ),

                      // Auto-populate indicator
                      if (hasLastReading && !isComplete) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.blue.shade200),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.auto_awesome,
                                size: 16,
                                color: Colors.blue.shade700,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Previous readings will be auto-populated from ${_bayLastReadings[bay.id]!['lastReadingDate']}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.blue.shade700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  IconData _getBayTypeIcon(String bayType) {
    switch (bayType.toLowerCase()) {
      case 'transformer':
        return Icons.electrical_services;
      case 'feeder':
        return Icons.power;
      case 'line':
        return Icons.power_input;
      case 'busbar':
        return Icons.horizontal_rule;
      case 'capacitor bank':
        return Icons.battery_charging_full;
      case 'reactor':
        return Icons.device_hub;
      default:
        return Icons.electrical_services;
    }
  }

  Widget _buildHeader() {
    final theme = Theme.of(context);
    final int completedBays = _bayCompletionStatus.values
        .where((status) => status)
        .length;
    final int energyCompleteBays = _bayEnergyCompletionStatus.values
        .where((status) => status)
        .length;
    final int totalBays = _baysWithDailyAssignments.length;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.secondary.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.secondary.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.electrical_services,
                  color: theme.colorScheme.secondary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
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
                      DateFormat(
                        'EEEE, dd MMMM yyyy',
                      ).format(widget.selectedDate),
                      style: TextStyle(
                        fontSize: 14,
                        color: theme.colorScheme.onSurface.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (_isDailyReadingAvailable && totalBays > 0) ...[
            const SizedBox(height: 16),

            // General Progress
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: theme.colorScheme.outline.withOpacity(0.2),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.analytics,
                    color: theme.colorScheme.primary,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'General Progress: $completedBays of $totalBays bays',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: LinearProgressIndicator(
                      value: totalBays > 0 ? completedBays / totalBays : 0,
                      backgroundColor: Colors.grey.shade200,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        completedBays == totalBays
                            ? Colors.green
                            : theme.colorScheme.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // Energy Progress
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.electric_bolt, color: Colors.green, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    'Energy Progress: $energyCompleteBays of $totalBays bays',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.green,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: LinearProgressIndicator(
                      value: totalBays > 0 ? energyCompleteBays / totalBays : 0,
                      backgroundColor: Colors.grey.shade200,
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        Colors.green,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Validation Button
            if (energyCompleteBays == totalBays && totalBays > 0) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: validateEnergyDataForCalculation,
                  icon: const Icon(Icons.check_circle, size: 20),
                  label: const Text('Validate Energy Data for Calculation'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        // Header
        _buildHeader(),

        // Content
        Expanded(
          child: !_hasAnyBaysWithReadings
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
              : ListView.builder(
                  padding: const EdgeInsets.only(bottom: 16),
                  itemCount: _baysWithDailyAssignments.length,
                  itemBuilder: (context, index) {
                    return _buildBayCard(
                      _baysWithDailyAssignments[index],
                      index,
                    );
                  },
                ),
        ),
      ],
    );
  }
}

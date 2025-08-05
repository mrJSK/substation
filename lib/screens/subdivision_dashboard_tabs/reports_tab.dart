// lib/screens/subdivision_dashboard_tabs/reports_tab.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import '../../models/user_model.dart';
import '../../models/bay_model.dart';
import '../../models/logsheet_models.dart';
import '../../models/tripping_shutdown_model.dart';
import '../../utils/snackbar_utils.dart';
import '../../models/app_state_data.dart';

class ReportsTab extends StatefulWidget {
  final AppUser currentUser;
  final String? selectedSubstationId;
  final String subdivisionId;
  final DateTime startDate;
  final DateTime endDate;
  final String substationId;

  const ReportsTab({
    Key? key,
    required this.currentUser,
    required this.selectedSubstationId,
    required this.subdivisionId,
    required this.startDate,
    required this.endDate,
    required this.substationId,
  }) : super(key: key);

  @override
  State<ReportsTab> createState() => _ReportsTabState();
}

class _ReportsTabState extends State<ReportsTab> {
  String? _selectedBayId;
  List<Bay> _bays = [];
  DateTime _fromDate = DateTime.now().subtract(const Duration(days: 7));
  DateTime _toDate = DateTime.now();
  bool _isLoading = false;
  bool _isGenerating = false;
  String? _currentSelectedSubstationId;

  @override
  void initState() {
    super.initState();
    _currentSelectedSubstationId = widget.selectedSubstationId;
    WidgetsBinding.instance.addPostFrameCallback((_) => _fetchBays());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final newSelectedSubstationId = Provider.of<AppStateData>(
      context,
    ).selectedSubstation?.id;

    if (newSelectedSubstationId != null &&
        newSelectedSubstationId != _currentSelectedSubstationId) {
      setState(() {
        _currentSelectedSubstationId = newSelectedSubstationId;
        _selectedBayId = null;
      });
      _fetchBays();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      color: const Color(0xFFFAFAFA),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeaderSection(theme),
            const SizedBox(height: 24),
            if (_currentSelectedSubstationId == null ||
                _currentSelectedSubstationId!.isEmpty)
              _buildNoSubstationSelected(theme)
            else
              _buildReportConfiguration(theme),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderSection(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.assessment,
              color: theme.colorScheme.primary,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Custom Bay Reports',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Generate detailed reports for specific bays and time periods',
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoSubstationSelected(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Center(
        child: Column(
          children: [
            Icon(
              Icons.location_off,
              size: 64,
              color: theme.colorScheme.onSurface.withOpacity(0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'No Substation Selected',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: theme.colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Please select a substation from the dashboard to generate reports.',
              style: TextStyle(
                fontSize: 14,
                color: theme.colorScheme.onSurface.withOpacity(0.5),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReportConfiguration(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(
                  Icons.settings,
                  color: Colors.orange,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Report Configuration',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildBaySelection(theme),
          const SizedBox(height: 16),
          _buildDateRangeSelection(theme),
          const SizedBox(height: 24),
          _buildGenerateButton(theme),
        ],
      ),
    );
  }

  Widget _buildBaySelection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Select Bay',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: _selectedBayId,
          decoration: InputDecoration(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            prefixIcon: const Icon(Icons.electrical_services),
            hintText: 'Choose a bay for the report',
          ),
          items: _bays
              .map(
                (bay) => DropdownMenuItem(
                  value: bay.id,
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: _getBayTypeColor(bay.bayType),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(child: Text('${bay.name} (${bay.bayType})')),
                    ],
                  ),
                ),
              )
              .toList(),
          onChanged: (value) => setState(() => _selectedBayId = value),
          isExpanded: true,
        ),
      ],
    );
  }

  Widget _buildDateRangeSelection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Report Period',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _buildDateField(
                label: 'From Date',
                date: _fromDate,
                onTap: () => _selectDate(true),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildDateField(
                label: 'To Date',
                date: _toDate,
                onTap: () => _selectDate(false),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _buildQuickDateRanges(theme),
      ],
    );
  }

  Widget _buildDateField({
    required String label,
    required DateTime date,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_today, size: 16, color: Colors.blue),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 2),
                Text(
                  DateFormat('MMM dd, yyyy').format(date),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickDateRanges(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Select',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            _buildQuickDateChip('Last 7 days', 7),
            _buildQuickDateChip('Last 15 days', 15),
            _buildQuickDateChip('Last 30 days', 30),
            _buildQuickDateChip('This month', 0, isThisMonth: true),
          ],
        ),
      ],
    );
  }

  Widget _buildQuickDateChip(
    String label,
    int days, {
    bool isThisMonth = false,
  }) {
    return InkWell(
      onTap: () {
        setState(() {
          if (isThisMonth) {
            final now = DateTime.now();
            _fromDate = DateTime(now.year, now.month, 1);
            _toDate = DateTime(now.year, now.month + 1, 0);
          } else {
            _toDate = DateTime.now();
            _fromDate = _toDate.subtract(Duration(days: days));
          }
        });
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.blue.shade50,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.blue.shade200),
        ),
        child: Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.blue.shade700),
        ),
      ),
    );
  }

  Widget _buildGenerateButton(ThemeData theme) {
    final bool canGenerate = _selectedBayId != null && !_isGenerating;

    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton.icon(
        onPressed: canGenerate ? _generateReport : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: theme.colorScheme.primary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        icon: _isGenerating
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.file_download),
        label: Text(
          _isGenerating ? 'Generating Report...' : 'Generate Report',
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
      ),
    );
  }

  Color _getBayTypeColor(String bayType) {
    switch (bayType.toLowerCase()) {
      case 'transformer':
        return Colors.orange;
      case 'line':
        return Colors.blue;
      case 'feeder':
        return Colors.green;
      case 'capacitor bank':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  Future<void> _selectDate(bool isFromDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isFromDate ? _fromDate : _toDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: Theme.of(context).colorScheme.primary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        if (isFromDate) {
          _fromDate = picked;
          // Ensure to date is not before from date
          if (_toDate.isBefore(_fromDate)) {
            _toDate = _fromDate;
          }
        } else {
          _toDate = picked;
          // Ensure from date is not after to date
          if (_fromDate.isAfter(_toDate)) {
            _fromDate = _toDate;
          }
        }
      });
    }
  }

  Future<void> _fetchBays() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      List<String> substationIds = [];
      if (_currentSelectedSubstationId != null &&
          _currentSelectedSubstationId!.isNotEmpty) {
        substationIds.add(_currentSelectedSubstationId!);
      } else {
        // If no specific substation is selected, fetch all for the subdivision
        final substationsSnapshot = await FirebaseFirestore.instance
            .collection('substations')
            .where('subdivisionId', isEqualTo: widget.subdivisionId)
            .get();
        substationIds = substationsSnapshot.docs.map((doc) => doc.id).toList();
      }

      if (substationIds.isEmpty) {
        if (!mounted) return;
        SnackBarUtils.showSnackBar(
          context,
          'No substations found for report generation or no substation selected.',
          isError: true,
        );
        setState(() {
          _bays = [];
          _isLoading = false;
        });
        return;
      }

      List<Bay> fetchedBays = [];
      // Firestore `whereIn` has a limit of 10. Chunking for safety.
      for (int i = 0; i < substationIds.length; i += 10) {
        final chunk = substationIds.sublist(
          i,
          i + 10 > substationIds.length ? substationIds.length : i + 10,
        );
        if (chunk.isEmpty) continue;

        final baysSnapshot = await FirebaseFirestore.instance
            .collection('bays')
            .where('substationId', whereIn: chunk)
            .orderBy('name')
            .get();

        fetchedBays.addAll(
          baysSnapshot.docs.map((doc) => Bay.fromFirestore(doc)).toList(),
        );
      }

      if (!mounted) return;
      setState(() {
        _bays = fetchedBays;
        // Keep the previously selected bay if it exists in the new list of bays
        if (_selectedBayId != null &&
            !_bays.any((bay) => bay.id == _selectedBayId)) {
          _selectedBayId = null;
        }
        _isLoading = false;
      });
    } catch (e) {
      print("Error fetching bays for reports: $e");
      if (!mounted) return;
      SnackBarUtils.showSnackBar(
        context,
        'Failed to load bays for reports: $e',
        isError: true,
      );
      setState(() => _isLoading = false);
    }
  }

  Future<void> _generateReport() async {
    if (_selectedBayId == null) {
      SnackBarUtils.showSnackBar(
        context,
        'Please select a bay.',
        isError: true,
      );
      return;
    }

    if (!mounted) return;
    setState(() => _isGenerating = true);

    try {
      final bay = _bays.firstWhere((b) => b.id == _selectedBayId);

      // Fetch logsheet entries
      final logsheetSnapshot = await FirebaseFirestore.instance
          .collection('logsheetEntries')
          .where('bayId', isEqualTo: _selectedBayId)
          .where('frequency', isEqualTo: 'hourly')
          .where(
            'readingTimestamp',
            isGreaterThanOrEqualTo: Timestamp.fromDate(_fromDate),
          )
          .where(
            'readingTimestamp',
            isLessThanOrEqualTo: Timestamp.fromDate(
              _toDate.add(const Duration(days: 1)),
            ),
          )
          .get();

      // Fetch tripping events
      final trippingSnapshot = await FirebaseFirestore.instance
          .collection('trippingShutdownEntries')
          .where('bayId', isEqualTo: _selectedBayId)
          .where(
            'startTime',
            isGreaterThanOrEqualTo: Timestamp.fromDate(_fromDate),
          )
          .where(
            'startTime',
            isLessThanOrEqualTo: Timestamp.fromDate(
              _toDate.add(const Duration(days: 1)),
            ),
          )
          .get();

      final readings = logsheetSnapshot.docs
          .map((doc) => LogsheetEntry.fromFirestore(doc))
          .toList();

      // Calculate statistics
      double? maxCurrent,
          minCurrent,
          maxVoltage,
          minVoltage,
          maxPowerFactor,
          minPowerFactor;
      DateTime? maxCurrentTime,
          minCurrentTime,
          maxVoltageTime,
          minVoltageTime,
          maxPowerFactorTime,
          minPowerFactorTime;

      for (var entry in readings) {
        final current = double.tryParse(
          entry.values['Current']?.toString() ?? '',
        );
        final voltage = double.tryParse(
          entry.values['Voltage']?.toString() ?? '',
        );
        final powerFactor = double.tryParse(
          entry.values['Power Factor']?.toString() ?? '',
        );
        final timestamp = entry.readingTimestamp.toDate();

        if (current != null) {
          if (maxCurrent == null || current > maxCurrent) {
            maxCurrent = current;
            maxCurrentTime = timestamp;
          }
          if (minCurrent == null || current < minCurrent) {
            minCurrent = current;
            minCurrentTime = timestamp;
          }
        }

        if (voltage != null) {
          if (maxVoltage == null || voltage > maxVoltage) {
            maxVoltage = voltage;
            maxVoltageTime = timestamp;
          }
          if (minVoltage == null || voltage < minVoltage) {
            minVoltage = voltage;
            minVoltageTime = timestamp;
          }
        }

        if (powerFactor != null) {
          if (maxPowerFactor == null || powerFactor > maxPowerFactor) {
            maxPowerFactor = powerFactor;
            maxPowerFactorTime = timestamp;
          }
          if (minPowerFactor == null || powerFactor < minPowerFactor) {
            minPowerFactor = powerFactor;
            minPowerFactorTime = timestamp;
          }
        }
      }

      final trippingEvents = trippingSnapshot.docs
          .map((doc) => TrippingShutdownEntry.fromFirestore(doc))
          .toList();

      // Generate report content
      final reportContent = StringBuffer();
      reportContent.writeln('# Bay Report: ${bay.name}');
      reportContent.writeln(
        '**Generated on**: ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())}',
      );
      reportContent.writeln(
        '**Period**: ${DateFormat('yyyy-MM-dd').format(_fromDate)} to ${DateFormat('yyyy-MM-dd').format(_toDate)}',
      );
      reportContent.writeln('\n## Readings Summary');

      if (maxCurrent != null) {
        reportContent.writeln(
          '- **Max Current**: ${maxCurrent.toStringAsFixed(2)} A at ${DateFormat('yyyy-MM-dd HH:mm').format(maxCurrentTime!)}',
        );
        reportContent.writeln(
          '- **Min Current**: ${minCurrent?.toStringAsFixed(2)} A at ${DateFormat('yyyy-MM-dd HH:mm').format(minCurrentTime!)}',
        );
      } else {
        reportContent.writeln('- No Current data available.');
      }

      if (maxVoltage != null) {
        reportContent.writeln(
          '- **Max Voltage**: ${maxVoltage.toStringAsFixed(2)} V at ${DateFormat('yyyy-MM-dd HH:mm').format(maxVoltageTime!)}',
        );
        reportContent.writeln(
          '- **Min Voltage**: ${minVoltage?.toStringAsFixed(2)} V at ${DateFormat('yyyy-MM-dd HH:mm').format(minVoltageTime!)}',
        );
      } else {
        reportContent.writeln('- No Voltage data available.');
      }

      if (maxPowerFactor != null) {
        reportContent.writeln(
          '- **Max Power Factor**: ${maxPowerFactor.toStringAsFixed(2)} at ${DateFormat('yyyy-MM-dd HH:mm').format(maxPowerFactorTime!)}',
        );
        reportContent.writeln(
          '- **Min Power Factor**: ${minPowerFactor?.toStringAsFixed(2)} at ${DateFormat('yyyy-MM-dd HH:mm').format(minPowerFactorTime!)}',
        );
      } else {
        reportContent.writeln('- No Power Factor data available.');
      }

      reportContent.writeln('\n## Tripping/Shutdown Events');
      if (trippingEvents.isEmpty) {
        reportContent.writeln('- No Tripping/Shutdown events found.');
      } else {
        for (var event in trippingEvents) {
          final duration = event.endTime != null
              ? event.endTime!
                        .toDate()
                        .difference(event.startTime.toDate())
                        .inMinutes
                        .toString() +
                    ' minutes'
              : 'Ongoing';
          reportContent.writeln('- **Event Type**: ${event.eventType}');
          reportContent.writeln(
            ' - **Start**: ${DateFormat('yyyy-MM-dd HH:mm').format(event.startTime.toDate())}',
          );
          reportContent.writeln(
            ' - **End**: ${event.endTime != null ? DateFormat('yyyy-MM-dd HH:mm').format(event.endTime!.toDate()) : 'N/A'}',
          );
          reportContent.writeln(' - **Duration**: $duration');
          reportContent.writeln(' - **Flags/Cause**: ${event.flagsCause}');
          if (event.reasonForNonFeeder != null &&
              event.reasonForNonFeeder!.isNotEmpty) {
            reportContent.writeln(' - **Reason**: ${event.reasonForNonFeeder}');
          }
        }
      }

      if (!mounted) return;

      // Show report in dialog
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: Text('Report for ${bay.name}'),
          content: SizedBox(
            width: double.maxFinite,
            height: 400,
            child: SingleChildScrollView(child: Text(reportContent.toString())),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      );

      if (mounted) {
        SnackBarUtils.showSnackBar(context, 'Report generated successfully!');
      }
    } catch (e) {
      print('Failed to generate report: $e');
      if (mounted) {
        SnackBarUtils.showSnackBar(
          context,
          'Failed to generate report: $e',
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }
}

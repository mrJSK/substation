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

// Report Generation Section (moved from original)
class ReportGenerationSection extends StatefulWidget {
  final String subdivisionId;
  final AppUser currentUser;
  final String? initialSelectedSubstationId; // Added selectedSubstationId

  const ReportGenerationSection({
    Key? key,
    required this.subdivisionId,
    required this.currentUser,
    this.initialSelectedSubstationId, // Added selectedSubstationId
  }) : super(key: key);

  @override
  _ReportGenerationSectionState createState() =>
      _ReportGenerationSectionState();
}

class _ReportGenerationSectionState extends State<ReportGenerationSection> {
  String? _selectedBayId;
  List<Bay> _bays = [];
  DateTime _fromDate = DateTime.now().subtract(const Duration(days: 7));
  DateTime _toDate = DateTime.now();
  bool _isLoading = false;
  String? _currentSelectedSubstationId;

  @override
  void initState() {
    super.initState();
    _currentSelectedSubstationId = widget.initialSelectedSubstationId;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchBays();
    });
  }

  @override
  void didUpdateWidget(covariant ReportGenerationSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialSelectedSubstationId !=
        oldWidget.initialSelectedSubstationId) {
      _currentSelectedSubstationId = widget.initialSelectedSubstationId;
      _selectedBayId = null; // Reset selected bay when substation changes
      _fetchBays();
    }
  }

  // Listen for changes in the selected substation from AppStateData
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
        _selectedBayId = null; // Reset selected bay when substation changes
      });
      _fetchBays(); // Fetch bays for the newly selected substation
    } else if (_currentSelectedSubstationId == null &&
        newSelectedSubstationId != null) {
      // Handle initial set if it wasn't there before
      setState(() {
        _currentSelectedSubstationId = newSelectedSubstationId;
        _selectedBayId = null;
      });
      _fetchBays();
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
        // This case might be less common if parent dashboard always has a selected substation
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
        // Keep the previously selected bay if it exists in the new list of bays for the selected substation
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

  Future<void> _selectDate(BuildContext context, bool isFrom) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isFrom ? _fromDate : _toDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      if (!mounted) return;
      setState(() {
        if (isFrom) {
          _fromDate = picked;
        } else {
          _toDate = picked;
        }
      });
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
    setState(() => _isLoading = true);
    try {
      final bay = _bays.firstWhere((b) => b.id == _selectedBayId);
      final logsheetSnapshot = await FirebaseFirestore.instance
          .collection('logsheetEntries')
          .where('bayId', isEqualTo: _selectedBayId)
          .where(
            'frequency',
            isEqualTo: 'hourly',
          ) // Assuming hourly for reports
          .where(
            'readingTimestamp',
            isGreaterThanOrEqualTo: Timestamp.fromDate(_fromDate),
          )
          .where(
            'readingTimestamp',
            isLessThanOrEqualTo: Timestamp.fromDate(
              _toDate.add(
                const Duration(days: 1),
              ), // Include readings up to the end of the selected day
            ),
          )
          .get();

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
            '  - **Start**: ${DateFormat('yyyy-MM-dd HH:mm').format(event.startTime.toDate())}',
          );
          reportContent.writeln(
            '  - **End**: ${event.endTime != null ? DateFormat('yyyy-MM-dd HH:mm').format(event.endTime!.toDate()) : 'N/A'}',
          );
          reportContent.writeln('  - **Duration**: $duration');
          reportContent.writeln('  - **Flags/Cause**: ${event.flagsCause}');
          if (event.reasonForNonFeeder != null &&
              event.reasonForNonFeeder!.isNotEmpty) {
            reportContent.writeln(
              '  - **Reason**: ${event.reasonForNonFeeder}',
            );
          }
        }
      }

      if (!mounted) return;
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: Text('Report for ${bay.name}'),
          content: SingleChildScrollView(child: Text(reportContent.toString())),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    } catch (e) {
      print('Failed to generate report: $e');
      if (!mounted) return;
      SnackBarUtils.showSnackBar(
        context,
        'Failed to generate report: $e',
        isError: true,
      );
    } finally {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            'Generate Custom Bay Reports',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
        if (_currentSelectedSubstationId == null ||
            _currentSelectedSubstationId!.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0),
            child: Text(
              'Please select a substation to enable report generation.',
              style: TextStyle(color: Colors.grey),
            ),
          )
        else ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: DropdownButtonFormField<String>(
              decoration: const InputDecoration(
                labelText: 'Select Bay',
                border: OutlineInputBorder(),
              ),
              value: _selectedBayId,
              items: _bays
                  .map(
                    (bay) => DropdownMenuItem(
                      value: bay.id,
                      child: Text('${bay.name} (${bay.bayType})'),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                setState(() {
                  _selectedBayId = value;
                });
              },
              validator: (value) =>
                  value == null ? 'Please select a bay' : null,
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                Expanded(
                  child: ListTile(
                    title: Text(
                      'From: ${DateFormat('yyyy-MM-dd').format(_fromDate)}',
                    ),
                    trailing: const Icon(Icons.calendar_today),
                    onTap: () => _selectDate(context, true),
                  ),
                ),
                Expanded(
                  child: ListTile(
                    title: Text(
                      'To: ${DateFormat('yyyy-MM-dd').format(_toDate)}',
                    ),
                    trailing: const Icon(Icons.calendar_today),
                    onTap: () => _selectDate(context, false),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: ElevatedButton(
              onPressed: _isLoading || _selectedBayId == null
                  ? null
                  : _generateReport,
              child: _isLoading
                  ? const CircularProgressIndicator()
                  : const Text('Generate Report'),
            ),
          ),
        ],
      ],
    );
  }
}

class ReportsTab extends StatelessWidget {
  final AppUser currentUser;
  final String? selectedSubstationId;
  final String subdivisionId;

  const ReportsTab({
    Key? key,
    required this.currentUser,
    required this.selectedSubstationId,
    required this.subdivisionId,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ReportGenerationSection(
      subdivisionId: subdivisionId,
      currentUser: currentUser,
      initialSelectedSubstationId: selectedSubstationId,
    );
  }
}

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
import '../../models/logsheet_models.dart';

class OperationsTab extends StatefulWidget {
  final AppUser currentUser;
  final String? initialSelectedSubstationId;
  final VoidCallback? onRefreshParent;
  final String substationId;
  final DateTime startDate;
  final DateTime endDate;

  const OperationsTab({
    super.key,
    required this.currentUser,
    this.initialSelectedSubstationId,
    this.onRefreshParent,
    required this.substationId,
    required this.startDate,
    required this.endDate,
  });

  @override
  State<OperationsTab> createState() => _OperationsTabState();
}

class _OperationsTabState extends State<OperationsTab> {
  Substation? _selectedSubstation;
  List<String> _selectedBayIds = [];
  DateTime? _startDate;
  DateTime? _endDate;
  List<Bay> _bays = [];
  bool _isBaysLoading = false;

  // Viewer state
  bool _isViewerLoading = false;
  String? _viewerErrorMessage;
  List<LogsheetEntry> _rawLogsheetEntriesForViewer = [];
  Map<String, Bay> _viewerBaysMap = {};
  Map<String, Map<DateTime, List<LogsheetEntry>>> _groupedEntriesForViewer = {};
  LogsheetEntry? _selectedIndividualReadingEntry;
  List<LogsheetEntry> _individualEntriesForDropdown = [];

  @override
  void initState() {
    super.initState();
    _startDate = widget.startDate;
    _endDate = widget.endDate;
    _initializeData();
  }

  @override
  void didUpdateWidget(OperationsTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.startDate != widget.startDate ||
        oldWidget.endDate != widget.endDate) {
      setState(() {
        _startDate = widget.startDate;
        _endDate = widget.endDate;
        _clearViewerData();
      });
    }
  }

  // Initialize data using substation from app state
  Future<void> _initializeData() async {
    final appState = Provider.of<AppStateData>(context, listen: false);
    _selectedSubstation = appState.selectedSubstation;

    if (_selectedSubstation != null) {
      await _fetchBaysForSelectedSubstation();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildBaySelectionSection(theme),
            const SizedBox(height: 16),
            _buildActionButton(theme),
            const SizedBox(height: 16),
            if (_shouldShowResults()) _buildResultsSection(theme),
          ],
        ),
      ),
    );
  }

  Widget _buildBaySelectionSection(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Select Bays to View Operations',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 16),
          _buildBayMultiSelect(theme),
        ],
      ),
    );
  }

  Widget _buildBayMultiSelect(ThemeData theme) {
    if (_bays.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            Icon(Icons.info_outline, color: Colors.grey.shade600),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _selectedSubstation == null
                    ? 'No substation selected from dashboard'
                    : 'Loading bays for ${_selectedSubstation!.name}...',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                _selectedBayIds.isEmpty
                    ? 'No bays selected'
                    : '${_selectedBayIds.length} bay(s) selected',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            ElevatedButton.icon(
              onPressed: _showBaySelectionDialog,
              icon: const Icon(Icons.list, size: 16),
              label: const Text('Select Bays', style: TextStyle(fontSize: 13)),
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
                foregroundColor: theme.colorScheme.primary,
                elevation: 0,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
              ),
            ),
          ],
        ),
        if (_selectedBayIds.isNotEmpty) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _selectedBayIds.map((bayId) {
              final bay = _bays.firstWhere((b) => b.id == bayId);
              return Chip(
                label: Text(
                  '${bay.name} (${bay.bayType})',
                  style: const TextStyle(fontSize: 11),
                ),
                onDeleted: () {
                  setState(() {
                    _selectedBayIds.remove(bayId);
                    _clearViewerData();
                  });
                },
                deleteIconColor: Colors.red,
                backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
                side: BorderSide(
                  color: theme.colorScheme.primary.withOpacity(0.3),
                ),
              );
            }).toList(),
          ),
        ],
      ],
    );
  }

  Widget _buildActionButton(ThemeData theme) {
    final bool canViewEntries =
        _selectedSubstation != null &&
        _selectedBayIds.isNotEmpty &&
        _startDate != null &&
        _endDate != null;

    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton.icon(
        onPressed: canViewEntries ? _viewLogsheetEntry : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: theme.colorScheme.primary,
          foregroundColor: theme.colorScheme.onPrimary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
        ),
        icon: _isViewerLoading
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.search, size: 18),
        label: Text(
          _isViewerLoading ? 'Searching...' : 'Search Logsheet Entries',
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
        ),
      ),
    );
  }

  Widget _buildResultsSection(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
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
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(
                  Icons.list_alt,
                  color: Colors.green,
                  size: 16,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Search Results for ${_selectedSubstation?.name ?? ''}',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    Text(
                      '${_rawLogsheetEntriesForViewer.length} entries found',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_selectedBayIds.length == 1 &&
              !_isViewerLoading &&
              _individualEntriesForDropdown.isNotEmpty)
            _buildIndividualEntryDropdown(theme),
          const SizedBox(height: 16),
          if (_isViewerLoading)
            const Center(child: CircularProgressIndicator())
          else if (_viewerErrorMessage != null)
            _buildErrorMessage(_viewerErrorMessage!)
          else if (_groupedEntriesForViewer.isEmpty)
            _buildNoDataMessage()
          else
            _buildEntriesTable(theme),
        ],
      ),
    );
  }

  Widget _buildIndividualEntryDropdown(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.timeline, color: Colors.blue.shade700, size: 16),
              const SizedBox(width: 8),
              Text(
                'View Individual Entry Details',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Colors.blue.shade700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<LogsheetEntry>(
            value: _selectedIndividualReadingEntry,
            decoration: InputDecoration(
              labelText: 'Select Specific Reading',
              labelStyle: const TextStyle(fontSize: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              filled: true,
              fillColor: Colors.white,
              isDense: true,
            ),
            items: _individualEntriesForDropdown
                .map(
                  (entry) => DropdownMenuItem<LogsheetEntry>(
                    value: entry,
                    child: Text(
                      DateFormat(
                        'yyyy-MM-dd HH:mm',
                      ).format(entry.readingTimestamp.toDate().toLocal()),
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                )
                .toList(),
            onChanged: (newValue) {
              setState(() => _selectedIndividualReadingEntry = newValue);
            },
            isExpanded: true,
          ),
        ],
      ),
    );
  }

  Widget _buildErrorMessage(String error) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: Colors.red.shade700),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              error,
              style: TextStyle(color: Colors.red.shade700, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoDataMessage() {
    return Container(
      padding: const EdgeInsets.all(32),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.search_off, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text(
              'No logsheet entries found',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'No data available for the selected parameters and date range.',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEntriesTable(ThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowColor: MaterialStateColor.resolveWith(
            (states) => theme.colorScheme.primary.withOpacity(0.1),
          ),
          dataRowMinHeight: 100, // Increased minimum height
          dataRowMaxHeight: 400, // Increased maximum height
          columnSpacing: 16, // Increased spacing
          horizontalMargin: 16,
          columns: const [
            DataColumn(
              label: Text(
                'Bay',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
              ),
            ),
            DataColumn(
              label: Text(
                'Date',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
              ),
            ),
            DataColumn(
              label: Text(
                'Time',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
              ),
            ),
            DataColumn(
              label: Text(
                'Readings Summary',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
              ),
            ),
          ],
          rows: _buildDataRows(),
        ),
      ),
    );
  }

  List<DataRow> _buildDataRows() {
    List<DataRow> rows = [];
    _groupedEntriesForViewer.forEach((bayId, datesMap) {
      final bay = _viewerBaysMap[bayId];
      datesMap.forEach((date, entries) {
        for (var entry in entries) {
          rows.add(
            DataRow(
              cells: [
                DataCell(
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Text(
                      bay?.name ?? 'Unknown',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: Colors.blue,
                      ),
                    ),
                  ),
                ),
                DataCell(
                  Text(
                    DateFormat('MMM dd, yyyy').format(date),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                DataCell(
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      DateFormat(
                        'HH:mm',
                      ).format(entry.readingTimestamp.toDate().toLocal()),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.green,
                      ),
                    ),
                  ),
                ),
                DataCell(
                  Container(
                    constraints: const BoxConstraints(
                      maxWidth: 350,
                      minHeight: 80, // Increased height
                    ),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: _buildReadingsDisplay(entry),
                  ),
                ),
              ],
            ),
          );
        }
      });
    });
    return rows;
  }

  Widget _buildReadingsDisplay(LogsheetEntry entry) {
    List<Widget> readingWidgets = [];

    // Group readings by type for better organization
    Map<String, dynamic> currentReadings = {};
    Map<String, dynamic> voltageReadings = {};
    Map<String, dynamic> statusReadings = {};
    Map<String, dynamic> otherReadings = {};

    entry.values.forEach((key, value) {
      final keyLower = key.toLowerCase();
      if (keyLower.contains('current') || keyLower.contains('amp')) {
        currentReadings[key] = value;
      } else if (keyLower.contains('voltage') || keyLower.contains('volt')) {
        voltageReadings[key] = value;
      } else if (value is Map &&
          value.containsKey('value') &&
          value['value'] is bool) {
        statusReadings[key] = value;
      } else {
        otherReadings[key] = value;
      }
    });

    // Build organized display
    if (currentReadings.isNotEmpty) {
      readingWidgets.add(
        _buildReadingSection('Current Readings', currentReadings, Colors.blue),
      );
    }

    if (voltageReadings.isNotEmpty) {
      readingWidgets.add(
        _buildReadingSection(
          'Voltage Readings',
          voltageReadings,
          Colors.orange,
        ),
      );
    }

    if (statusReadings.isNotEmpty) {
      readingWidgets.add(
        _buildReadingSection('Status', statusReadings, Colors.green),
      );
    }

    if (otherReadings.isNotEmpty) {
      readingWidgets.add(
        _buildReadingSection('Other Readings', otherReadings, Colors.purple),
      );
    }

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: readingWidgets,
      ),
    );
  }

  Widget _buildReadingSection(
    String title,
    Map<String, dynamic> readings,
    Color color,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ),
        ...readings.entries.map((entry) {
          String displayValue;
          if (entry.value is Map && entry.value.containsKey('value')) {
            final boolValue = entry.value['value'] as bool;
            displayValue = boolValue ? 'ON' : 'OFF';
          } else {
            displayValue = entry.value.toString();
          }

          return Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: Text(
                    '${entry.key}:',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Colors.black87,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Text(
                      displayValue,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color:
                            entry.value is Map &&
                                entry.value.containsKey('value')
                            ? (entry.value['value'] as bool
                                  ? Colors.green
                                  : Colors.red)
                            : Colors.black87,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
        if (readings.isNotEmpty) const SizedBox(height: 12),
      ],
    );
  }

  bool _shouldShowResults() {
    return _rawLogsheetEntriesForViewer.isNotEmpty ||
        _isViewerLoading ||
        _viewerErrorMessage != null;
  }

  void _clearViewerData() {
    _rawLogsheetEntriesForViewer.clear();
    _groupedEntriesForViewer.clear();
    _individualEntriesForDropdown.clear();
    _selectedIndividualReadingEntry = null;
    _viewerErrorMessage = null;
  }

  Future<void> _showBaySelectionDialog() async {
    if (_bays.isEmpty) {
      SnackBarUtils.showSnackBar(
        context,
        'No bays available. Please select a substation from the dashboard.',
        isError: true,
      );
      return;
    }

    final List<String> tempSelected = List.from(_selectedBayIds);
    final result = await showDialog<List<String>?>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              title: const Text('Select Bays', style: TextStyle(fontSize: 16)),
              content: SizedBox(
                width: double.maxFinite,
                height: 400,
                child: ListView.builder(
                  itemCount: _bays.length,
                  itemBuilder: (context, index) {
                    final bay = _bays[index];
                    final isSelected = tempSelected.contains(bay.id);
                    return CheckboxListTile(
                      title: Text(
                        '${bay.name} (${bay.bayType})',
                        style: const TextStyle(fontSize: 14),
                      ),
                      subtitle: Text(
                        'Voltage: ${bay.voltageLevel}',
                        style: const TextStyle(fontSize: 12),
                      ),
                      value: isSelected,
                      onChanged: (bool? value) {
                        setDialogState(() {
                          if (value == true) {
                            tempSelected.add(bay.id);
                          } else {
                            tempSelected.remove(bay.id);
                          }
                        });
                      },
                    );
                  },
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel', style: TextStyle(fontSize: 13)),
                ),
                TextButton(
                  onPressed: () {
                    setDialogState(() {
                      tempSelected.clear();
                    });
                  },
                  child: const Text(
                    'Clear All',
                    style: TextStyle(fontSize: 13),
                  ),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(tempSelected),
                  child: Text(
                    'Select (${tempSelected.length})',
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    if (result != null) {
      setState(() {
        _selectedBayIds = result;
        _clearViewerData();
      });
    }
  }

  Future<void> _fetchBaysForSelectedSubstation() async {
    if (_selectedSubstation == null) {
      if (mounted) {
        setState(() {
          _bays = [];
          _selectedBayIds = [];
          _clearViewerData();
        });
      }
      return;
    }

    if (_isBaysLoading) return;
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

  void _viewLogsheetEntry() {
    if (_selectedSubstation == null ||
        _selectedBayIds.isEmpty ||
        _startDate == null ||
        _endDate == null) {
      SnackBarUtils.showSnackBar(
        context,
        'Please complete all selections before viewing entries.',
        isError: true,
      );
      return;
    }

    _fetchLogsheetEntriesForViewer();
  }

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
      _viewerBaysMap.clear();
      final baysSnapshot = await FirebaseFirestore.instance
          .collection('bays')
          .where(FieldPath.documentId, whereIn: _selectedBayIds)
          .get();

      for (var doc in baysSnapshot.docs) {
        _viewerBaysMap[doc.id] = Bay.fromFirestore(doc);
      }

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
          .where('frequency', isEqualTo: 'hourly')
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
      final DateTime entryDate = DateTime(
        entry.readingTimestamp.toDate().year,
        entry.readingTimestamp.toDate().month,
        entry.readingTimestamp.toDate().day,
      );

      _groupedEntriesForViewer.putIfAbsent(bayId, () => {});
      _groupedEntriesForViewer[bayId]!.putIfAbsent(entryDate, () => []);
      _groupedEntriesForViewer[bayId]![entryDate]!.add(entry);
    }

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
}

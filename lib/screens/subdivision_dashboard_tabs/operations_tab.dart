import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:excel/excel.dart' hide Border;
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:permission_handler/permission_handler.dart';
import 'package:open_filex/open_filex.dart';
import '../../models/hierarchy_models.dart';
import '../../models/bay_model.dart';
import '../../models/user_model.dart';
import '../../utils/snackbar_utils.dart';
import '../../models/app_state_data.dart';
import '../../models/logsheet_models.dart';

class OperationsTab extends StatefulWidget {
  final AppUser currentUser;
  final List<Substation> accessibleSubstations;

  const OperationsTab({
    super.key,
    required this.currentUser,
    required this.accessibleSubstations,
  });

  @override
  State<OperationsTab> createState() => _OperationsTabState();
}

class _OperationsTabState extends State<OperationsTab> {
  Substation? _selectedSubstation;
  List<String> _selectedBayIds = [];
  DateTime? _startDate;
  DateTime? _endDate;

  // Cache for bays by substation ID to avoid refetching
  Map<String, List<Bay>> _bayCache = {};
  Map<String, List<String>> _selectedBayCache = {};
  bool _isBaysLoading = false;

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
    _startDate = DateTime.now().subtract(const Duration(days: 7));
    _endDate = DateTime.now();

    if (widget.accessibleSubstations.isNotEmpty) {
      _selectedSubstation = widget.accessibleSubstations.first;
      _fetchBaysForSelectedSubstation();
    }
  }

  List<Bay> get _bays {
    if (_selectedSubstation == null) return [];
    return _bayCache[_selectedSubstation!.id] ?? [];
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
            'View Hourly Readings',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(flex: 1, child: _buildSubstationSelector(theme)),
              const SizedBox(width: 16),
              Expanded(flex: 1, child: _buildDateRangeSelector(theme)),
            ],
          ),
          const SizedBox(height: 16),
          _buildBaySelector(theme),
        ],
      ),
    );
  }

  Widget _buildSubstationSelector(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Select Substation',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: theme.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: theme.colorScheme.primary.withOpacity(0.2),
            ),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<Substation>(
              value: _selectedSubstation,
              isExpanded: true,
              items: widget.accessibleSubstations.map((substation) {
                return DropdownMenuItem(
                  value: substation,
                  child: Text(
                    substation.name,
                    style: const TextStyle(fontSize: 14),
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              }).toList(),
              onChanged: (Substation? newValue) {
                if (newValue != null &&
                    newValue.id != _selectedSubstation?.id) {
                  // Save current selection before changing
                  if (_selectedSubstation != null) {
                    _selectedBayCache[_selectedSubstation!.id] = List.from(
                      _selectedBayIds,
                    );
                  }

                  setState(() {
                    _selectedSubstation = newValue;
                    // Restore previous selection for this substation if available
                    _selectedBayIds = List.from(
                      _selectedBayCache[newValue.id] ?? [],
                    );
                    _clearViewerData();
                  });

                  _fetchBaysForSelectedSubstation();
                }
              },
              icon: Icon(
                Icons.keyboard_arrow_down,
                color: theme.colorScheme.primary,
                size: 20,
              ),
              hint: const Text(
                'Select Substation',
                style: TextStyle(fontSize: 14),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDateRangeSelector(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Date Range',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: theme.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: _showDateRangePicker,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: theme.colorScheme.secondary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: theme.colorScheme.secondary.withOpacity(0.3),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.date_range,
                  size: 16,
                  color: theme.colorScheme.secondary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _startDate != null && _endDate != null
                        ? '${DateFormat('dd.MMM').format(_startDate!)} - ${DateFormat('dd.MMM').format(_endDate!)}'
                        : 'Select dates',
                    style: TextStyle(
                      fontSize: 13,
                      color: theme.colorScheme.secondary,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBaySelector(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Select Bays',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: theme.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        _buildBayMultiSelect(theme),
      ],
    );
  }

  Future<void> _showDateRangePicker() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      initialDateRange: _startDate != null && _endDate != null
          ? DateTimeRange(start: _startDate!, end: _endDate!)
          : DateTimeRange(
              start: DateTime.now().subtract(const Duration(days: 7)),
              end: DateTime.now(),
            ),
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
        _startDate = picked.start;
        _endDate = picked.end;
        _clearViewerData();
      });
    }
  }

  Widget _buildBayMultiSelect(ThemeData theme) {
    if (_bays.isEmpty) {
      return Container(
        width: double.infinity,
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
                    ? 'Please select a substation'
                    : _isBaysLoading
                    ? 'Loading bays for ${_selectedSubstation!.name}...'
                    : 'No bays available for ${_selectedSubstation!.name}',
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
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withOpacity(0.05),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: theme.colorScheme.primary.withOpacity(0.2),
              ),
            ),
            child: Wrap(
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
                      if (_selectedSubstation != null) {
                        _selectedBayCache[_selectedSubstation!.id] = List.from(
                          _selectedBayIds,
                        );
                      }
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
              if (_rawLogsheetEntriesForViewer.isNotEmpty)
                ElevatedButton.icon(
                  onPressed: _exportToExcel,
                  icon: const Icon(Icons.download, size: 16),
                  label: const Text(
                    'Export Excel',
                    style: TextStyle(fontSize: 12),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.withOpacity(0.1),
                    foregroundColor: Colors.green,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
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
          dataRowMinHeight: 100,
          dataRowMaxHeight: 400,
          columnSpacing: 16,
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
                      minHeight: 80,
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
        'No bays available. Please select a substation first.',
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
            final theme = Theme.of(context);
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Container(
                width: double.maxFinite,
                height: 500,
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.fromLTRB(20, 16, 16, 16),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withOpacity(0.1),
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(12),
                          topRight: Radius.circular(12),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Select Bays',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          ),
                          InkWell(
                            onTap: () => Navigator.of(context).pop(),
                            borderRadius: BorderRadius.circular(4),
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              child: Icon(
                                Icons.close,
                                size: 20,
                                color: theme.colorScheme.onSurface.withOpacity(
                                  0.7,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${tempSelected.length} of ${_bays.length} bays selected',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          Row(
                            children: [
                              TextButton.icon(
                                onPressed: () {
                                  setDialogState(() {
                                    if (tempSelected.length == _bays.length) {
                                      tempSelected.clear();
                                    } else {
                                      tempSelected.clear();
                                      tempSelected.addAll(
                                        _bays.map((bay) => bay.id),
                                      );
                                    }
                                  });
                                },
                                icon: Icon(
                                  tempSelected.length == _bays.length
                                      ? Icons.deselect
                                      : Icons.select_all,
                                  size: 16,
                                ),
                                label: Text(
                                  tempSelected.length == _bays.length
                                      ? 'Deselect All'
                                      : 'Select All',
                                  style: const TextStyle(fontSize: 13),
                                ),
                                style: TextButton.styleFrom(
                                  foregroundColor: theme.colorScheme.primary,
                                ),
                              ),
                              const SizedBox(width: 8),
                              TextButton.icon(
                                onPressed: tempSelected.isNotEmpty
                                    ? () {
                                        setDialogState(() {
                                          tempSelected.clear();
                                        });
                                      }
                                    : null,
                                icon: const Icon(Icons.clear, size: 16),
                                label: const Text(
                                  'Clear',
                                  style: TextStyle(fontSize: 13),
                                ),
                                style: TextButton.styleFrom(
                                  foregroundColor: Colors.orange,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _bays.length,
                        itemBuilder: (context, index) {
                          final bay = _bays[index];
                          final isSelected = tempSelected.contains(bay.id);
                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isSelected
                                    ? theme.colorScheme.primary.withOpacity(0.3)
                                    : Colors.grey.shade300,
                                width: isSelected ? 2 : 1,
                              ),
                            ),
                            child: CheckboxListTile(
                              title: Text(
                                '${bay.name} (${bay.bayType})',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: isSelected
                                      ? FontWeight.w600
                                      : FontWeight.w500,
                                  color: isSelected
                                      ? theme.colorScheme.primary
                                      : null,
                                ),
                              ),
                              subtitle: Text(
                                'Voltage: ${bay.voltageLevel}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isSelected
                                      ? theme.colorScheme.primary.withOpacity(
                                          0.7,
                                        )
                                      : Colors.grey.shade600,
                                ),
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
                              controlAffinity: ListTileControlAffinity.leading,
                              activeColor: theme.colorScheme.primary,
                            ),
                          );
                        },
                      ),
                    ),
                    const Divider(height: 1),
                    Container(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          ElevatedButton.icon(
                            onPressed: () =>
                                Navigator.of(context).pop(tempSelected),
                            icon: const Icon(Icons.check, size: 16),
                            label: Text(
                              'Select (${tempSelected.length})',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: theme.colorScheme.primary,
                              foregroundColor: theme.colorScheme.onPrimary,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (result != null) {
      setState(() {
        _selectedBayIds = result;
        if (_selectedSubstation != null) {
          _selectedBayCache[_selectedSubstation!.id] = List.from(
            _selectedBayIds,
          );
        }
        _clearViewerData();
      });
    }
  }

  Future<void> _exportToExcel() async {
    try {
      if (Platform.isAndroid) {
        var status = await Permission.storage.status;
        if (!status.isGranted) {
          status = await Permission.storage.request();
          if (!status.isGranted) {
            SnackBarUtils.showSnackBar(
              context,
              'Storage permission is required to export data',
              isError: true,
            );
            return;
          }
        }
      }

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: Card(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Generating Excel file...'),
                ],
              ),
            ),
          ),
        ),
      );

      var excel = Excel.createExcel();
      excel.delete('Sheet1');

      Map<String, List<LogsheetEntry>> dataByBayType = {};

      for (var entry in _rawLogsheetEntriesForViewer) {
        final bay = _viewerBaysMap[entry.bayId];
        if (bay != null) {
          final bayType = bay.bayType;
          dataByBayType.putIfAbsent(bayType, () => []);
          dataByBayType[bayType]!.add(entry);
        }
      }

      dataByBayType.forEach((bayType, entries) {
        var sheet = excel[bayType];

        Set<String> allParameters = {};
        for (var entry in entries) {
          allParameters.addAll(entry.values.keys);
        }

        List<String> sortedParameters = allParameters.toList()..sort();

        List<String> headers = [
          'Date & Time',
          'Bay Name',
          'Bay Type',
          'Voltage Level',
          ...sortedParameters,
        ];

        for (int i = 0; i < headers.length; i++) {
          var cell = sheet.cell(
            CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0),
          );
          cell.value = TextCellValue(headers[i]);
          cell.cellStyle = CellStyle(
            bold: true,
            backgroundColorHex: ExcelColor.fromHexString('#E3F2FD'),
          );
        }

        int rowIndex = 1;

        entries.sort((a, b) {
          final bayA = _viewerBaysMap[a.bayId]?.name ?? '';
          final bayB = _viewerBaysMap[b.bayId]?.name ?? '';
          if (bayA != bayB) {
            return bayA.compareTo(bayB);
          }
          return a.readingTimestamp.compareTo(b.readingTimestamp);
        });

        for (var entry in entries) {
          final bay = _viewerBaysMap[entry.bayId];
          final dateTime = entry.readingTimestamp.toDate().toLocal();

          List<dynamic> rowData = [
            DateFormat('yyyy-MM-dd HH:mm:ss').format(dateTime),
            bay?.name ?? 'Unknown',
            bay?.bayType ?? 'Unknown',
            bay?.voltageLevel ?? 'Unknown',
          ];

          for (String parameter in sortedParameters) {
            dynamic value = entry.values[parameter];
            String cellValue = '';

            if (value != null) {
              if (value is Map && value.containsKey('value')) {
                if (value['value'] is bool) {
                  cellValue = value['value'] as bool ? 'ON' : 'OFF';
                } else {
                  cellValue = '${value['value']}${value['unit'] ?? ''}';
                }
              } else {
                cellValue = value.toString();
              }
            }

            rowData.add(cellValue);
          }

          for (int i = 0; i < rowData.length; i++) {
            var cell = sheet.cell(
              CellIndex.indexByColumnRow(columnIndex: i, rowIndex: rowIndex),
            );
            cell.value = TextCellValue(rowData[i].toString());

            if (rowIndex % 2 == 0) {
              cell.cellStyle = CellStyle(
                backgroundColorHex: ExcelColor.fromHexString('#F5F5F5'),
              );
            }

            if (i == 1 && rowIndex > 1) {
              var prevBayCell = sheet.cell(
                CellIndex.indexByColumnRow(
                  columnIndex: 1,
                  rowIndex: rowIndex - 1,
                ),
              );
              if (prevBayCell.value?.toString() != rowData[1].toString()) {
                cell.cellStyle = CellStyle(
                  backgroundColorHex: ExcelColor.fromHexString('#E8F5E8'),
                  bold: true,
                );
              }
            }
          }
          rowIndex++;
        }

        sheet.setColumnWidth(0, 18);
        sheet.setColumnWidth(1, 15);
        sheet.setColumnWidth(2, 12);
        sheet.setColumnWidth(3, 12);

        for (int i = 4; i < headers.length; i++) {
          sheet.setColumnWidth(i, 12);
        }

        sheet.insertRowIterables([
          TextCellValue('Bay Type: $bayType'),
          TextCellValue(''),
          TextCellValue('Total Entries: ${entries.length}'),
          TextCellValue(''),
          TextCellValue(
            'Date Range: ${DateFormat('yyyy-MM-dd').format(_startDate!)} to ${DateFormat('yyyy-MM-dd').format(_endDate!)}',
          ),
        ], 0);

        for (int i = 0; i < 5; i++) {
          var cell = sheet.cell(
            CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0),
          );
          cell.cellStyle = CellStyle(
            bold: true,
            backgroundColorHex: ExcelColor.fromHexString('#FFF3E0'),
          );
        }
      });

      final directory = await getApplicationDocumentsDirectory();
      final fileName =
          'logsheet_data_${_selectedSubstation?.name.replaceAll(' ', '_')}_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.xlsx';
      final file = File('${directory.path}/$fileName');

      await file.writeAsBytes(excel.encode()!);

      Navigator.of(context).pop();

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green),
              SizedBox(width: 8),
              Text('Export Successful'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('File saved as: $fileName'),
              const SizedBox(height: 8),
              Text('Location: ${directory.path}'),
              const SizedBox(height: 16),
              Container(
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
                        Icon(
                          Icons.info_outline,
                          color: Colors.blue.shade700,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Excel Format Details:',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.blue.shade700,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '• Separate sheets for each bay type\n• Parameters as column headers\n• Time-series data in rows\n• Sorted by bay name and timestamp',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.blue.shade700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
            ElevatedButton.icon(
              onPressed: () async {
                Navigator.of(context).pop();
                try {
                  await OpenFilex.open(file.path);
                } catch (e) {
                  SnackBarUtils.showSnackBar(
                    context,
                    'Could not open file. Please check your file manager.',
                    isError: true,
                  );
                }
              },
              icon: const Icon(Icons.open_in_new, size: 16),
              label: const Text('Open File'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (Navigator.canPop(context)) {
        Navigator.of(context).pop();
      }

      print('Error exporting to Excel: $e');
      SnackBarUtils.showSnackBar(
        context,
        'Failed to export data: $e',
        isError: true,
      );
    }
  }

  Future<void> _fetchBaysForSelectedSubstation() async {
    if (_selectedSubstation == null) {
      return;
    }

    // Check cache first
    if (_bayCache.containsKey(_selectedSubstation!.id)) {
      setState(() {
        // Restore bay selection from cache
        _selectedBayIds = List.from(
          _selectedBayCache[_selectedSubstation!.id] ?? [],
        );
      });
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
        final bays = baysSnapshot.docs
            .map((doc) => Bay.fromFirestore(doc))
            .toList();

        setState(() {
          _bayCache[_selectedSubstation!.id] = bays;
          _selectedBayIds = List.from(
            _selectedBayCache[_selectedSubstation!.id] ?? [],
          );
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

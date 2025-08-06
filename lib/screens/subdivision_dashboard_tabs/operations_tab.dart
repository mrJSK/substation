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

// Enhanced Equipment Icon Widget
class _EquipmentIcon extends StatelessWidget {
  final String type;
  final Color color;
  final double size;

  const _EquipmentIcon({
    required this.type,
    required this.color,
    this.size = 24.0,
  });

  @override
  Widget build(BuildContext context) {
    IconData iconData;

    switch (type.toLowerCase()) {
      case 'operations':
        iconData = Icons.settings;
        break;
      case 'search':
        iconData = Icons.search;
        break;
      case 'results':
        iconData = Icons.list_alt;
        break;
      default:
        iconData = Icons.settings;
        break;
    }

    return Icon(iconData, size: size, color: color);
  }
}

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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      body: Column(
        children: [
          // Enhanced Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: _EquipmentIcon(
                    type: 'operations',
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
                        'Operations Data Viewer',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      Text(
                        '${DateFormat('MMM dd').format(_startDate!)} - ${DateFormat('MMM dd, yyyy').format(_endDate!)}',
                        style: TextStyle(
                          fontSize: 14,
                          color: theme.colorScheme.onSurface.withOpacity(0.6),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSelectionSection(theme),
                  const SizedBox(height: 16),
                  _buildActionButton(theme),
                  const SizedBox(height: 16),
                  if (_shouldShowResults()) _buildResultsSection(theme),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectionSection(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(20),
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
                  color: theme.colorScheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: _EquipmentIcon(
                  type: 'search',
                  color: theme.colorScheme.primary,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Search Parameters',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildSubstationDropdown(theme),
          const SizedBox(height: 16),
          _buildBayMultiSelect(theme),
          const SizedBox(height: 16),
          _buildDateRangeDisplay(theme),
        ],
      ),
    );
  }

  Widget _buildSubstationDropdown(ThemeData theme) {
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

    return StreamBuilder<List<Substation>>(
      stream: substationsStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: const Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.red.shade200),
            ),
            child: Text('Error: ${snapshot.error}'),
          );
        }

        final substations = snapshot.data ?? [];
        if (_selectedSubstation == null && substations.isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            setState(() {
              _selectedSubstation = substations.first;
              _fetchBaysForSelectedSubstation();
            });
          });
        }

        return DropdownButtonFormField<Substation>(
          value: _selectedSubstation,
          decoration: InputDecoration(
            labelText: 'Select Substation',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            prefixIcon: const Icon(Icons.location_on),
            filled: true,
            fillColor: theme.colorScheme.primary.withOpacity(0.05),
          ),
          items: substations
              .map(
                (substation) => DropdownMenuItem(
                  value: substation,
                  child: Text(substation.name),
                ),
              )
              .toList(),
          onChanged: (newValue) {
            setState(() {
              _selectedSubstation = newValue;
              _selectedBayIds.clear();
              _bays.clear();
              _clearViewerData();
              if (newValue != null) {
                _fetchBaysForSelectedSubstation();
              }
            });
          },
          isExpanded: true,
        );
      },
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
                'Select a substation to view available bays',
                style: TextStyle(color: Colors.grey.shade600),
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
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            ElevatedButton.icon(
              onPressed: _showBaySelectionDialog,
              icon: const Icon(Icons.list, size: 16),
              label: const Text('Select Bays'),
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
                foregroundColor: theme.colorScheme.primary,
                elevation: 0,
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
                  style: const TextStyle(fontSize: 12),
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

  Widget _buildDateRangeDisplay(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondary.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.secondary.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.calendar_today,
            color: theme.colorScheme.secondary,
            size: 20,
          ),
          const SizedBox(width: 8),
          Text(
            'Period: ${DateFormat('MMM dd, yyyy').format(_startDate!)} - ${DateFormat('MMM dd, yyyy').format(_endDate!)}',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: theme.colorScheme.secondary,
            ),
          ),
        ],
      ),
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
      height: 52,
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
            : _EquipmentIcon(type: 'search', color: Colors.white, size: 20),
        label: Text(
          _isViewerLoading ? 'Searching...' : 'Search Logsheet Entries',
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
        ),
      ),
    );
  }

  Widget _buildResultsSection(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(20),
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
                child: _EquipmentIcon(
                  type: 'results',
                  color: Colors.green,
                  size: 18,
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
                        fontSize: 16,
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
          const SizedBox(height: 20),

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
                  fontSize: 14,
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
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              filled: true,
              fillColor: Colors.white,
              isDense: true,
            ),
            items: _individualEntriesForDropdown
                .map(
                  (entry) => DropdownMenuItem(
                    value: entry,
                    child: Text(
                      DateFormat(
                        'yyyy-MM-dd HH:mm',
                      ).format(entry.readingTimestamp.toDate().toLocal()),
                      style: const TextStyle(fontSize: 14),
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
            child: Text(error, style: TextStyle(color: Colors.red.shade700)),
          ),
        ],
      ),
    );
  }

  Widget _buildNoDataMessage() {
    return Container(
      padding: const EdgeInsets.all(48),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.search_off, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'No logsheet entries found',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'No data available for the selected parameters and date range.',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
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
          dataRowMinHeight: 48,
          dataRowMaxHeight: 64,
          columns: const [
            DataColumn(
              label: Text('Bay', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            DataColumn(
              label: Text(
                'Date',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            DataColumn(
              label: Text(
                'Time',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            DataColumn(
              label: Text(
                'Readings Summary',
                style: TextStyle(fontWeight: FontWeight.bold),
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
          final readings = entry.values.entries
              .map((e) {
                if (e.value is Map && e.value.containsKey('value')) {
                  final boolValue = e.value['value'] as bool;
                  return '${e.key}: ${boolValue ? 'Yes' : 'No'}';
                }
                return '${e.key}: ${e.value}';
              })
              .take(3)
              .join(', '); // Limit to 3 readings for display

          final hasMoreReadings = entry.values.length > 3;

          rows.add(
            DataRow(
              cells: [
                DataCell(
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      bay?.name ?? 'Unknown',
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ),
                ),
                DataCell(Text(DateFormat('MMM dd, yyyy').format(date))),
                DataCell(
                  Text(
                    DateFormat(
                      'HH:mm',
                    ).format(entry.readingTimestamp.toDate().toLocal()),
                  ),
                ),
                DataCell(
                  Container(
                    constraints: const BoxConstraints(maxWidth: 250),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          readings,
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                          style: const TextStyle(fontSize: 12),
                        ),
                        if (hasMoreReadings)
                          Text(
                            '... and ${entry.values.length - 3} more fields',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey.shade600,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                      ],
                    ),
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
    final result = await showDialog<List<String>>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              title: const Text('Select Bays'),
              content: SizedBox(
                width: double.maxFinite,
                height: 400,
                child: ListView.builder(
                  itemCount: _bays.length,
                  itemBuilder: (context, index) {
                    final bay = _bays[index];
                    final isSelected = tempSelected.contains(bay.id);
                    return CheckboxListTile(
                      title: Text('${bay.name} (${bay.bayType})'),
                      subtitle: Text('Voltage: ${bay.voltageLevel}'),
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
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () {
                    setDialogState(() {
                      tempSelected.clear();
                    });
                  },
                  child: const Text('Clear All'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(tempSelected),
                  child: Text('Select (${tempSelected.length})'),
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

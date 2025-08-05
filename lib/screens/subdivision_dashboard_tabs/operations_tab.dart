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
import '../substation_dashboard/logsheet_entry_screen.dart';

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
    _startDate = DateTime.now();
    _endDate = DateTime.now();
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
            _buildSelectionSection(theme),
            const SizedBox(height: 24),
            _buildActionButton(theme),
            const SizedBox(height: 24),
            if (_shouldShowResults()) _buildResultsSection(theme),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectionSection(ThemeData theme) {
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
                  color: theme.colorScheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(
                  Icons.settings,
                  color: theme.colorScheme.primary,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Operation Parameters',
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
          _buildDateRangeSelector(theme),
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
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Text('Error: ${snapshot.error}');
        }

        final substations = snapshot.data ?? [];

        // Auto-select first substation if none selected
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
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            prefixIcon: const Icon(Icons.location_on),
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
          borderRadius: BorderRadius.circular(8),
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
            TextButton.icon(
              onPressed: _showBaySelectionDialog,
              icon: const Icon(Icons.list, size: 16),
              label: const Text('Select Bays'),
            ),
          ],
        ),
        if (_selectedBayIds.isNotEmpty) ...[
          const SizedBox(height: 8),
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
              );
            }).toList(),
          ),
        ],
      ],
    );
  }

  Widget _buildDateRangeSelector(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: _buildDateField(
                label: 'Start Date',
                date: _startDate!,
                onTap: () => _selectDate(true),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildDateField(
                label: 'End Date',
                date: _endDate!,
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
            _buildQuickDateChip('Today', 0),
            _buildQuickDateChip('Last 7 days', 7),
            _buildQuickDateChip('Last 15 days', 15),
            _buildQuickDateChip('Last 30 days', 30),
          ],
        ),
      ],
    );
  }

  Widget _buildQuickDateChip(String label, int days) {
    return InkWell(
      onTap: () {
        setState(() {
          _endDate = DateTime.now();
          _startDate = days == 0
              ? DateTime.now()
              : _endDate!.subtract(Duration(days: days));
          _clearViewerData();
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
            : const Icon(Icons.search),
        label: Text(
          _isViewerLoading ? 'Loading...' : 'View Logsheet Entries',
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
      ),
    );
  }

  Widget _buildResultsSection(ThemeData theme) {
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
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(
                  Icons.list_alt,
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
                      'Logsheet Entries for ${_selectedSubstation?.name ?? ''}',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    Text(
                      '${DateFormat('MMM dd, yyyy').format(_startDate!)} - ${DateFormat('MMM dd, yyyy').format(_endDate!)}',
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
    return DropdownButtonFormField<LogsheetEntry>(
      value: _selectedIndividualReadingEntry,
      decoration: InputDecoration(
        labelText: 'Select Specific Reading',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        prefixIcon: const Icon(Icons.timeline),
      ),
      items: _individualEntriesForDropdown
          .map(
            (entry) => DropdownMenuItem(
              value: entry,
              child: Text(
                DateFormat(
                  'yyyy-MM-dd HH:mm',
                ).format(entry.readingTimestamp.toDate().toLocal()),
              ),
            ),
          )
          .toList(),
      onChanged: (newValue) {
        setState(() => _selectedIndividualReadingEntry = newValue);
        if (newValue != null) {
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
                forceReadOnly: true,
              ),
            ),
          );
        }
      },
      isExpanded: true,
    );
  }

  Widget _buildErrorMessage(String error) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(8),
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
      padding: const EdgeInsets.all(32),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.search_off, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'No logsheet entries found',
              style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 8),
            Text(
              'Try adjusting your search criteria',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEntriesTable(ThemeData theme) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowColor: MaterialStateColor.resolveWith(
          (states) => theme.colorScheme.primary.withOpacity(0.1),
        ),
        columns: const [
          DataColumn(label: Text('Bay')),
          DataColumn(label: Text('Date')),
          DataColumn(label: Text('Hour')),
          DataColumn(label: Text('Readings')),
        ],
        rows: _buildDataRows(),
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
              .join(', ');

          rows.add(
            DataRow(
              cells: [
                DataCell(Text(bay?.name ?? 'Unknown')),
                DataCell(Text(DateFormat('MMM dd').format(date))),
                DataCell(
                  Text(
                    DateFormat(
                      'HH:mm',
                    ).format(entry.readingTimestamp.toDate().toLocal()),
                  ),
                ),
                DataCell(
                  Container(
                    constraints: const BoxConstraints(maxWidth: 200),
                    child: Text(
                      readings,
                      overflow: TextOverflow.ellipsis,
                      maxLines: 2,
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

  Future<void> _selectDate(bool isStartDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isStartDate ? _startDate! : _endDate!,
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
        if (isStartDate) {
          _startDate = picked;
          if (_endDate!.isBefore(_startDate!)) {
            _endDate = _startDate;
          }
        } else {
          _endDate = picked;
          if (_startDate!.isAfter(_endDate!)) {
            _startDate = _endDate;
          }
        }
        _clearViewerData();
      });
    }
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
      // Fetch Bay details first to map IDs to names
      _viewerBaysMap.clear();
      final baysSnapshot = await FirebaseFirestore.instance
          .collection('bays')
          .where(FieldPath.documentId, whereIn: _selectedBayIds)
          .get();

      for (var doc in baysSnapshot.docs) {
        _viewerBaysMap[doc.id] = Bay.fromFirestore(doc);
      }

      // Prepare dates for query
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
}

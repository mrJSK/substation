import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:excel/excel.dart' hide Border;
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'dart:math';
import 'package:permission_handler/permission_handler.dart';
import 'package:open_filex/open_filex.dart';
import '../../models/logsheet_models.dart';
import '../../models/user_model.dart';
import '../../models/bay_model.dart';
import '../../models/hierarchy_models.dart';
import '../../utils/snackbar_utils.dart';
import '../../models/app_state_data.dart';

class EnergyTab extends StatefulWidget {
  final AppUser currentUser;
  final List<Substation> accessibleSubstations;

  const EnergyTab({
    Key? key,
    required this.currentUser,
    required this.accessibleSubstations,
  }) : super(key: key);

  @override
  _EnergyTabState createState() => _EnergyTabState();
}

class _EnergyTabState extends State<EnergyTab> {
  bool _isLoading = true;
  Substation? _selectedSubstation;
  DateTime? _startDate;
  DateTime? _endDate;

  // Cache for data persistence
  Map<String, List<Bay>> _bayCache = {};
  Map<String, List<String>> _selectedBayCache = {};
  Map<String, Bay> _baysMap = {};

  List<String> _selectedBayIds = [];
  bool _isViewerLoading = false;
  String? _viewerErrorMessage;
  List<LogsheetEntry> _rawLogsheetEntriesForViewer = [];
  Map<String, Bay> _viewerBaysMap = {};
  Map<String, Map<DateTime, List<LogsheetEntry>>> _groupedEntriesForViewer = {};
  LogsheetEntry? _selectedIndividualReadingEntry;
  List<LogsheetEntry> _individualEntriesForDropdown = [];

  Map<String, Map<String, double>> _bayEnergyData = {};
  Map<String, double> _substationAbstract = {};
  Map<String, Map<String, double>> _busbarAbstract = {};

  List<Bay> get _bays {
    if (_selectedSubstation == null) return [];
    return _bayCache[_selectedSubstation!.id] ?? [];
  }

  @override
  void initState() {
    super.initState();
    _startDate = DateTime.now().subtract(const Duration(days: 7));
    _endDate = DateTime.now();

    if (widget.accessibleSubstations.isNotEmpty) {
      _selectedSubstation = widget.accessibleSubstations.first;
      _initializeData();
    } else {
      setState(() => _isLoading = false);
    }
  }

  void _clearViewerData() {
    _rawLogsheetEntriesForViewer.clear();
    _groupedEntriesForViewer.clear();
    _individualEntriesForDropdown.clear();
    _selectedIndividualReadingEntry = null;
    _viewerErrorMessage = null;
  }

  Future<void> _initializeData() async {
    if (_selectedSubstation != null) {
      await _fetchBaysForSelectedSubstation();
      await _fetchEnergyData();
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchBaysForSelectedSubstation() async {
    if (_selectedSubstation == null) return;

    // Check cache first
    if (_bayCache.containsKey(_selectedSubstation!.id)) {
      setState(() {
        _baysMap = {
          for (var bay in _bayCache[_selectedSubstation!.id]!) bay.id: bay,
        };
        _selectedBayIds = List.from(
          _selectedBayCache[_selectedSubstation!.id] ?? [],
        );
      });
      return;
    }

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
          _baysMap = {for (var bay in bays) bay.id: bay};
          _selectedBayIds = List.from(
            _selectedBayCache[_selectedSubstation!.id] ?? [],
          );
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
      }
    }
  }

  Future<void> _fetchEnergyData() async {
    if (_selectedSubstation == null) return;

    if (mounted) {
      setState(() => _isLoading = true);
    }

    try {
      await _calculateEnergyLosses();
    } catch (e) {
      print('Error fetching data: $e');
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

  Future<void> _calculateEnergyLosses() async {
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

    final entriesSnapshot = await FirebaseFirestore.instance
        .collection('logsheetEntries')
        .where('substationId', isEqualTo: _selectedSubstation!.id)
        .where('frequency', isEqualTo: 'daily')
        .where(
          'readingTimestamp',
          isGreaterThanOrEqualTo: Timestamp.fromDate(queryStartDate),
        )
        .where(
          'readingTimestamp',
          isLessThanOrEqualTo: Timestamp.fromDate(queryEndDate),
        )
        .orderBy('readingTimestamp')
        .get();

    final entries = entriesSnapshot.docs
        .map((doc) => LogsheetEntry.fromFirestore(doc))
        .toList();

    _bayEnergyData.clear();
    _substationAbstract.clear();
    _busbarAbstract.clear();

    final uniqueBusVoltages =
        _baysMap.values
            .where((bay) => bay.bayType == 'Busbar')
            .map((bay) => bay.voltageLevel)
            .toSet()
            .toList()
          ..sort(
            (a, b) =>
                _getVoltageLevelValue(b).compareTo(_getVoltageLevelValue(a)),
          );

    for (String voltage in uniqueBusVoltages) {
      _busbarAbstract['$voltage BUS'] = {
        'totalImport': 0.0,
        'totalExport': 0.0,
        'totalLosses': 0.0,
        'lossPercentage': 0.0,
        'efficiency': 0.0,
        'activeBays': 0.0,
      };
    }

    for (var bay in _baysMap.values) {
      final bayEntries = entries.where((e) => e.bayId == bay.id).toList();
      final bayData = _calculateBayLosses(bay, bayEntries);

      if (bayData.isNotEmpty) {
        _bayEnergyData[bay.id] = bayData;

        if (bay.bayType == 'Busbar') {
          final busKey = '${bay.voltageLevel} BUS';
          if (_busbarAbstract.containsKey(busKey)) {
            _busbarAbstract[busKey]!['totalImport'] =
                (_busbarAbstract[busKey]!['totalImport'] ?? 0.0) +
                (bayData['import'] ?? 0.0);
            _busbarAbstract[busKey]!['totalExport'] =
                (_busbarAbstract[busKey]!['totalExport'] ?? 0.0) +
                (bayData['export'] ?? 0.0);
            _busbarAbstract[busKey]!['totalLosses'] =
                (_busbarAbstract[busKey]!['totalLosses'] ?? 0.0) +
                (bayData['losses'] ?? 0.0);
            _busbarAbstract[busKey]!['activeBays'] =
                (_busbarAbstract[busKey]!['activeBays'] ?? 0.0) + 1.0;
          }
        }
      }
    }

    _busbarAbstract.forEach((key, data) {
      final import = data['totalImport'] ?? 0.0;
      if (import > 0) {
        data['lossPercentage'] = ((data['totalLosses'] ?? 0.0) / import) * 100;
        data['efficiency'] = ((data['totalExport'] ?? 0.0) / import) * 100;
      }
    });

    _substationAbstract = _calculateSubstationTotalColumn();
  }

  Map<String, double> _calculateSubstationTotalColumn() {
    double totalImportEnergy = 0.0;
    double totalExportEnergy = 0.0;
    double totalLosses = 0.0;

    _busbarAbstract.forEach((busName, busData) {
      totalImportEnergy += busData['totalImport'] ?? 0.0;
      totalExportEnergy += busData['totalExport'] ?? 0.0;
      totalLosses += busData['totalLosses'] ?? 0.0;
    });

    if (totalImportEnergy == 0.0 && totalExportEnergy == 0.0) {
      _bayEnergyData.forEach((bayId, bayData) {
        totalImportEnergy += bayData['import'] ?? 0.0;
        totalExportEnergy += bayData['export'] ?? 0.0;
        totalLosses += bayData['losses'] ?? 0.0;
      });
    }

    final double lossPercentage = totalImportEnergy > 0
        ? (totalLosses / totalImportEnergy) * 100
        : 0.0;

    final double efficiency = totalImportEnergy > 0
        ? (totalExportEnergy / totalImportEnergy) * 100
        : 0.0;

    return {
      'totalImport': totalImportEnergy,
      'totalExport': totalExportEnergy,
      'totalLosses': totalLosses,
      'lossPercentage': lossPercentage,
      'efficiency': efficiency,
      'activeBays': _bayEnergyData.length.toDouble(),
    };
  }

  double _getVoltageLevelValue(String voltageLevel) {
    final regex = RegExp(r'(\d+(?:\.\d+)?)');
    final match = regex.firstMatch(voltageLevel);
    if (match != null) {
      return double.tryParse(match.group(1)!) ?? 0.0;
    }
    return 0.0;
  }

  Map<String, double> _calculateBayLosses(
    Bay bay,
    List<LogsheetEntry> entries,
  ) {
    if (entries.isEmpty) return {};

    entries.sort((a, b) => a.readingTimestamp.compareTo(b.readingTimestamp));

    double totalImport = 0.0;
    double totalExport = 0.0;

    LogsheetEntry? previousEntry;
    for (final entry in entries) {
      if (previousEntry != null) {
        final duration = entry.readingTimestamp
            .toDate()
            .difference(previousEntry.readingTimestamp.toDate())
            .inHours;

        if (duration > 0 && duration <= 48) {
          entry.values.forEach((key, value) {
            final keyLower = key.toLowerCase();

            if (keyLower.contains('energy') || keyLower.contains('kwh')) {
              final currentVal = _parseNumericValue(value);
              final previousVal = _parseNumericValue(
                previousEntry!.values[key],
              );

              if (currentVal != null && previousVal != null) {
                final energyDiff = max(0, currentVal - previousVal);
                if (keyLower.contains('import') ||
                    keyLower.contains('received')) {
                  totalImport += energyDiff;
                } else if (keyLower.contains('export') ||
                    keyLower.contains('sent')) {
                  totalExport += energyDiff;
                }
              }
            }
          });
        }
      }
      previousEntry = entry;
    }

    final losses = totalImport - totalExport;
    final lossPercentage = totalImport > 0 ? (losses / totalImport) * 100 : 0.0;

    return {
      'import': totalImport,
      'export': totalExport,
      'losses': max(0, losses),
      'lossPercentage': lossPercentage,
      'efficiency': totalImport > 0 ? (totalExport / totalImport) * 100 : 0.0,
    };
  }

  double? _parseNumericValue(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    if (value is Map && value.containsKey('value')) {
      return _parseNumericValue(value['value']);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildConfigurationSection(theme),
              const SizedBox(height: 16),
              _buildCalculateButton(theme),
              const SizedBox(height: 16),
              if (!_isLoading && _selectedSubstation != null)
                ..._buildEnergyContent(theme),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildConfigurationSection(ThemeData theme) {
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
            'Daily Readings and Energy Summary',
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
                  if (_selectedSubstation != null) {
                    _selectedBayCache[_selectedSubstation!.id] = List.from(
                      _selectedBayIds,
                    );
                  }

                  setState(() {
                    _selectedSubstation = newValue;
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

  Widget _buildCalculateButton(ThemeData theme) {
    final bool canCalculate =
        _selectedSubstation != null && _startDate != null && _endDate != null;

    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton.icon(
        onPressed: canCalculate ? _fetchEnergyData : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: theme.colorScheme.primary,
          foregroundColor: theme.colorScheme.onPrimary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
        ),
        icon: _isLoading
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.calculate, size: 18),
        label: Text(
          _isLoading ? 'Calculating...' : 'Calculate Energy Analysis',
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
        ),
      ),
    );
  }

  List<Widget> _buildEnergyContent(ThemeData theme) {
    return [
      _buildSectionHeader(
        theme,
        'Bay Energy Losses',
        Icons.battery_alert,
        Colors.red,
        hasExport: true,
        onExport: _exportBayLossesToExcel,
      ),
      const SizedBox(height: 12),
      _buildBayLossesTable(theme),
      const SizedBox(height: 24),

      _buildSectionHeader(
        theme,
        'Busbar Energy Abstract',
        Icons.electric_bolt,
        Colors.purple,
        hasExport: true,
        onExport: _exportBusbarAbstractToExcel,
      ),
      const SizedBox(height: 12),
      _buildBusbarAbstractTable(theme),
      const SizedBox(height: 24),

      _buildSectionHeader(
        theme,
        'Substation Energy Abstract',
        Icons.analytics,
        Colors.green,
        hasExport: true,
        onExport: _exportSubstationAbstractToExcel,
      ),
      const SizedBox(height: 12),
      _buildSubstationAbstractTable(theme),
      const SizedBox(height: 24),

      _buildSectionHeader(
        theme,
        'Bay Readings Viewer',
        Icons.search,
        Colors.blue,
      ),
      const SizedBox(height: 12),
      _buildBayReadingsViewerSection(theme),
      const SizedBox(height: 150),
    ];
  }

  Widget _buildSectionHeader(
    ThemeData theme,
    String title,
    IconData icon,
    Color color, {
    bool hasExport = false,
    VoidCallback? onExport,
  }) {
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
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),
          if (hasExport && onExport != null)
            ElevatedButton.icon(
              onPressed: onExport,
              icon: const Icon(Icons.download, size: 16),
              label: const Text('Export Excel', style: TextStyle(fontSize: 12)),
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
    );
  }

  Widget _buildBayLossesTable(ThemeData theme) {
    if (_bayEnergyData.isEmpty) {
      return _buildNoDataCard('No energy data available for loss calculation.');
    }

    return Container(
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
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowColor: MaterialStateColor.resolveWith(
            (states) => Colors.red.withOpacity(0.1),
          ),
          columns: const [
            DataColumn(
              label: Text(
                'Bay Name',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            DataColumn(
              label: Text(
                'Bay Type',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            DataColumn(
              label: Text(
                'Import (kWh)',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            DataColumn(
              label: Text(
                'Export (kWh)',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            DataColumn(
              label: Text(
                'Losses (kWh)',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            DataColumn(
              label: Text(
                'Loss %',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            DataColumn(
              label: Text(
                'Efficiency %',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
          rows: _bayEnergyData.entries.map((entry) {
            final bay = _baysMap[entry.key]!;
            final data = entry.value;

            return DataRow(
              cells: [
                DataCell(
                  Text(
                    bay.name,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                ),
                DataCell(
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      bay.bayType,
                      style: const TextStyle(fontSize: 12, color: Colors.blue),
                    ),
                  ),
                ),
                DataCell(
                  Text(
                    data['import']?.toStringAsFixed(2) ?? '0.00',
                    style: const TextStyle(
                      fontWeight: FontWeight.w500,
                      color: Colors.green,
                    ),
                  ),
                ),
                DataCell(
                  Text(
                    data['export']?.toStringAsFixed(2) ?? '0.00',
                    style: const TextStyle(
                      fontWeight: FontWeight.w500,
                      color: Colors.orange,
                    ),
                  ),
                ),
                DataCell(
                  Text(
                    data['losses']?.toStringAsFixed(2) ?? '0.00',
                    style: const TextStyle(
                      fontWeight: FontWeight.w500,
                      color: Colors.red,
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
                      color: _getLossColor(
                        data['lossPercentage'] ?? 0.0,
                      ).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${data['lossPercentage']?.toStringAsFixed(1) ?? '0.0'}%',
                      style: TextStyle(
                        fontSize: 12,
                        color: _getLossColor(data['lossPercentage'] ?? 0.0),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                DataCell(
                  Text(
                    '${data['efficiency']?.toStringAsFixed(1) ?? '0.0'}%',
                    style: const TextStyle(
                      fontWeight: FontWeight.w500,
                      color: Colors.teal,
                    ),
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildBusbarAbstractTable(ThemeData theme) {
    if (_busbarAbstract.isEmpty) {
      return _buildNoDataCard('No busbar data available.');
    }

    return Container(
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
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowColor: MaterialStateColor.resolveWith(
            (states) => Colors.purple.withOpacity(0.1),
          ),
          columns: const [
            DataColumn(
              label: Text(
                'Busbar',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            DataColumn(
              label: Text(
                'Import (kWh)',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            DataColumn(
              label: Text(
                'Export (kWh)',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            DataColumn(
              label: Text(
                'Losses (kWh)',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            DataColumn(
              label: Text(
                'Loss %',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            DataColumn(
              label: Text(
                'Efficiency %',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            DataColumn(
              label: Text(
                'Active Bays',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
          rows: _busbarAbstract.entries.map((entry) {
            final busbarName = entry.key;
            final data = entry.value;

            return DataRow(
              cells: [
                DataCell(
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.purple.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      busbarName,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.purple,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                DataCell(
                  Text(
                    data['totalImport']?.toStringAsFixed(2) ?? '0.00',
                    style: const TextStyle(
                      fontWeight: FontWeight.w500,
                      color: Colors.green,
                    ),
                  ),
                ),
                DataCell(
                  Text(
                    data['totalExport']?.toStringAsFixed(2) ?? '0.00',
                    style: const TextStyle(
                      fontWeight: FontWeight.w500,
                      color: Colors.orange,
                    ),
                  ),
                ),
                DataCell(
                  Text(
                    data['totalLosses']?.toStringAsFixed(2) ?? '0.00',
                    style: const TextStyle(
                      fontWeight: FontWeight.w500,
                      color: Colors.red,
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
                      color: _getLossColor(
                        data['lossPercentage'] ?? 0.0,
                      ).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${data['lossPercentage']?.toStringAsFixed(1) ?? '0.0'}%',
                      style: TextStyle(
                        fontSize: 12,
                        color: _getLossColor(data['lossPercentage'] ?? 0.0),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                DataCell(
                  Text(
                    '${data['efficiency']?.toStringAsFixed(1) ?? '0.0'}%',
                    style: const TextStyle(
                      fontWeight: FontWeight.w500,
                      color: Colors.teal,
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
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${data['activeBays']?.toInt() ?? 0}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.blue,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildSubstationAbstractTable(ThemeData theme) {
    if (_substationAbstract.isEmpty) {
      return _buildNoDataCard('No substation data available.');
    }

    return Container(
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
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildAbstractRow(
              'Total Import Energy',
              '${_substationAbstract['totalImport']?.toStringAsFixed(2)} kWh',
              Icons.flash_on,
              Colors.green,
            ),
            _buildAbstractRow(
              'Total Export Energy',
              '${_substationAbstract['totalExport']?.toStringAsFixed(2)} kWh',
              Icons.flash_off,
              Colors.orange,
            ),
            _buildAbstractRow(
              'Total Energy Losses',
              '${_substationAbstract['totalLosses']?.toStringAsFixed(2)} kWh',
              Icons.battery_alert,
              Colors.red,
            ),
            _buildAbstractRow(
              'Overall Loss Percentage',
              '${_substationAbstract['lossPercentage']?.toStringAsFixed(1)}%',
              Icons.trending_down,
              _getLossColor(_substationAbstract['lossPercentage'] ?? 0.0),
            ),
            _buildAbstractRow(
              'Overall Efficiency',
              '${_substationAbstract['efficiency']?.toStringAsFixed(1)}%',
              Icons.speed,
              Colors.teal,
            ),
            _buildAbstractRow(
              'Active Bays',
              '${_substationAbstract['activeBays']?.toInt()}',
              Icons.electrical_services,
              Colors.purple,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAbstractRow(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87,
                  ),
                ),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getLossColor(double lossPercentage) {
    if (lossPercentage > 10) return Colors.red;
    if (lossPercentage > 5) return Colors.orange;
    return Colors.green;
  }

  Widget _buildNoDataCard(String message) {
    return Container(
      padding: const EdgeInsets.all(32),
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
      child: Center(
        child: Column(
          children: [
            Icon(Icons.info_outline, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No Data Available',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: TextStyle(color: Colors.grey[500], fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBayReadingsViewerSection(ThemeData theme) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildBaySelectionSection(theme),
        const SizedBox(height: 16),
        _buildSearchButton(theme),
        const SizedBox(height: 16),
        if (_shouldShowResults()) _buildViewerResultsSection(theme),
      ],
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
            'Select Bays to View Detailed Readings',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 16),
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
                label: const Text(
                  'Select Bays',
                  style: TextStyle(fontSize: 13),
                ),
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
                  final bay = _baysMap[bayId];
                  if (bay == null) return const SizedBox();
                  return Chip(
                    label: Text('${bay.name} (${bay.bayType})'),
                    onDeleted: () {
                      setState(() {
                        _selectedBayIds.remove(bayId);
                        if (_selectedSubstation != null) {
                          _selectedBayCache[_selectedSubstation!.id] =
                              List.from(_selectedBayIds);
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
      ),
    );
  }

  Widget _buildSearchButton(ThemeData theme) {
    final bool canViewEntries =
        _selectedSubstation != null && _selectedBayIds.isNotEmpty;

    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton.icon(
        onPressed: canViewEntries ? _viewBayReadings : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: theme.colorScheme.primary,
          foregroundColor: theme.colorScheme.onPrimary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
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
          _isViewerLoading ? 'Searching...' : 'Search Bay Readings',
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
        ),
      ),
    );
  }

  Widget _buildViewerResultsSection(ThemeData theme) {
    return Container(
      width: double.infinity,
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
        mainAxisSize: MainAxisSize.min,
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
                      'Bay Readings for ${_selectedSubstation?.name ?? ''}',
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
                  onPressed: _exportBayReadingsToExcel,
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
          if (_isViewerLoading)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(
                child: Column(
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text(
                      'Searching for bay readings...',
                      style: TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            )
          else if (_viewerErrorMessage != null)
            _buildErrorMessage(_viewerErrorMessage!)
          else if (!_isViewerLoading && _rawLogsheetEntriesForViewer.isEmpty)
            _buildNoReadingsMessage()
          else if (_groupedEntriesForViewer.isNotEmpty)
            _buildBayReadingsTable(theme)
          else
            _buildNoReadingsMessage(),
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

  Widget _buildNoReadingsMessage() {
    return Container(
      padding: const EdgeInsets.all(32),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.search_off, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text(
              'No bay readings found',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'No readings exist for the selected bays in the period from ${DateFormat('MMM dd, yyyy').format(_startDate!)} to ${DateFormat('MMM dd, yyyy').format(_endDate!)}.',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
              textAlign: TextAlign.center,
            ),
            if (_selectedBayIds.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                'Selected bays: ${_selectedBayIds.map((id) => _baysMap[id]?.name ?? 'Unknown').join(', ')}',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBayReadingsTable(ThemeData theme) {
    List<DataRow> rows = [];
    _groupedEntriesForViewer.forEach((bayId, datesMap) {
      final bay = _viewerBaysMap[bayId];
      datesMap.forEach((date, entries) {
        for (var entry in entries) {
          rows.add(
            DataRow(
              cells: [
                DataCell(Text(bay?.name ?? 'Unknown')),
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
                    width: 300,
                    child: _buildSimpleReadingsDisplay(entry),
                  ),
                ),
              ],
            ),
          );
        }
      });
    });

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: const [
          DataColumn(label: Text('Bay')),
          DataColumn(label: Text('Date')),
          DataColumn(label: Text('Time')),
          DataColumn(label: Text('Readings')),
        ],
        rows: rows,
      ),
    );
  }

  Widget _buildSimpleReadingsDisplay(LogsheetEntry entry) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: entry.values.entries.take(5).map((e) {
        return Text(
          '${e.key}: ${e.value}',
          style: const TextStyle(fontSize: 12),
        );
      }).toList(),
    );
  }

  Future<void> _showBaySelectionDialog() async {
    final availableBays = _baysMap.values.toList();

    if (availableBays.isEmpty) {
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
      builder: (context) {
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
                              '${tempSelected.length} of ${availableBays.length} bays selected',
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
                                    if (tempSelected.length ==
                                        availableBays.length) {
                                      tempSelected.clear();
                                    } else {
                                      tempSelected.clear();
                                      tempSelected.addAll(
                                        availableBays.map((bay) => bay.id),
                                      );
                                    }
                                  });
                                },
                                icon: Icon(
                                  tempSelected.length == availableBays.length
                                      ? Icons.deselect
                                      : Icons.select_all,
                                  size: 16,
                                ),
                                label: Text(
                                  tempSelected.length == availableBays.length
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
                        itemCount: availableBays.length,
                        itemBuilder: (context, index) {
                          final bay = availableBays[index];
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
                                    if (!tempSelected.contains(bay.id)) {
                                      tempSelected.add(bay.id);
                                    }
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
        _selectedBayIds = result.toSet().toList();
        if (_selectedSubstation != null) {
          _selectedBayCache[_selectedSubstation!.id] = List.from(
            _selectedBayIds,
          );
        }
        _clearViewerData();
      });
    }
  }

  void _viewBayReadings() {
    _fetchBayReadingsForViewer();
  }

  Future<void> _fetchBayReadingsForViewer() async {
    setState(() {
      _isViewerLoading = true;
      _viewerErrorMessage = null;
      _rawLogsheetEntriesForViewer = [];
      _groupedEntriesForViewer = {};
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
          .where('frequency', isEqualTo: 'daily')
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

      _groupBayReadingsForViewer();
    } catch (e) {
      if (mounted) {
        setState(() {
          _viewerErrorMessage = 'Failed to load readings: $e';
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

  void _groupBayReadingsForViewer() {
    _groupedEntriesForViewer.clear();
    for (var entry in _rawLogsheetEntriesForViewer) {
      final bayId = entry.bayId;
      final entryDate = DateTime(
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

  bool _shouldShowResults() {
    return _isViewerLoading ||
        _viewerErrorMessage != null ||
        (!_isViewerLoading && _selectedBayIds.isNotEmpty);
  }

  // Excel Export Methods
  Future<void> _exportBayLossesToExcel() async {
    await _exportToExcel('Bay_Energy_Losses', _createBayLossesWorkbook);
  }

  Future<void> _exportBusbarAbstractToExcel() async {
    await _exportToExcel(
      'Busbar_Energy_Abstract',
      _createBusbarAbstractWorkbook,
    );
  }

  Future<void> _exportSubstationAbstractToExcel() async {
    await _exportToExcel(
      'Substation_Energy_Abstract',
      _createSubstationAbstractWorkbook,
    );
  }

  Future<void> _exportBayReadingsToExcel() async {
    await _exportToExcel('Bay_Readings', _createBayReadingsWorkbook);
  }

  Future<void> _exportToExcel(
    String filePrefix,
    Excel Function() createWorkbook,
  ) async {
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

      final excel = createWorkbook();
      final directory = await getApplicationDocumentsDirectory();
      final fileName =
          '${filePrefix}_${_selectedSubstation?.name.replaceAll(' ', '_')}_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.xlsx';
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
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Colors.blue.shade700,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Energy analysis data exported successfully with calculations.',
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

  Excel _createBayLossesWorkbook() {
    var excel = Excel.createExcel();
    excel.delete('Sheet1');
    var sheet = excel['Bay Energy Losses'];

    List<String> headers = [
      'Bay Name',
      'Bay Type',
      'Voltage Level',
      'Import Energy (kWh)',
      'Export Energy (kWh)',
      'Energy Losses (kWh)',
      'Loss Percentage (%)',
      'Efficiency (%)',
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
    _bayEnergyData.entries.forEach((entry) {
      final bay = _baysMap[entry.key]!;
      final data = entry.value;

      List<dynamic> rowData = [
        bay.name,
        bay.bayType,
        bay.voltageLevel,
        data['import']?.toStringAsFixed(2) ?? '0.00',
        data['export']?.toStringAsFixed(2) ?? '0.00',
        data['losses']?.toStringAsFixed(2) ?? '0.00',
        data['lossPercentage']?.toStringAsFixed(2) ?? '0.00',
        data['efficiency']?.toStringAsFixed(2) ?? '0.00',
      ];

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
      }
      rowIndex++;
    });

    for (int i = 0; i < headers.length; i++) {
      sheet.setColumnWidth(i, 15);
    }

    return excel;
  }

  Excel _createBusbarAbstractWorkbook() {
    var excel = Excel.createExcel();
    excel.delete('Sheet1');
    var sheet = excel['Busbar Energy Abstract'];

    List<String> headers = [
      'Busbar',
      'Total Import (kWh)',
      'Total Export (kWh)',
      'Total Losses (kWh)',
      'Loss Percentage (%)',
      'Efficiency (%)',
      'Active Bays',
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
    _busbarAbstract.entries.forEach((entry) {
      final busbarName = entry.key;
      final data = entry.value;

      List<dynamic> rowData = [
        busbarName,
        data['totalImport']?.toStringAsFixed(2) ?? '0.00',
        data['totalExport']?.toStringAsFixed(2) ?? '0.00',
        data['totalLosses']?.toStringAsFixed(2) ?? '0.00',
        data['lossPercentage']?.toStringAsFixed(2) ?? '0.00',
        data['efficiency']?.toStringAsFixed(2) ?? '0.00',
        data['activeBays']?.toInt().toString() ?? '0',
      ];

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
      }
      rowIndex++;
    });

    for (int i = 0; i < headers.length; i++) {
      sheet.setColumnWidth(i, 18);
    }

    return excel;
  }

  Excel _createSubstationAbstractWorkbook() {
    var excel = Excel.createExcel();
    excel.delete('Sheet1');
    var sheet = excel['Substation Energy Abstract'];

    List<List<String>> data = [
      ['Metric', 'Value'],
      [
        'Total Import Energy',
        '${_substationAbstract['totalImport']?.toStringAsFixed(2) ?? '0.00'} kWh',
      ],
      [
        'Total Export Energy',
        '${_substationAbstract['totalExport']?.toStringAsFixed(2) ?? '0.00'} kWh',
      ],
      [
        'Total Energy Losses',
        '${_substationAbstract['totalLosses']?.toStringAsFixed(2) ?? '0.00'} kWh',
      ],
      [
        'Overall Loss Percentage',
        '${_substationAbstract['lossPercentage']?.toStringAsFixed(2) ?? '0.00'}%',
      ],
      [
        'Overall Efficiency',
        '${_substationAbstract['efficiency']?.toStringAsFixed(2) ?? '0.00'}%',
      ],
      ['Active Bays', '${_substationAbstract['activeBays']?.toInt() ?? 0}'],
    ];

    for (int row = 0; row < data.length; row++) {
      for (int col = 0; col < data[row].length; col++) {
        var cell = sheet.cell(
          CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row),
        );
        cell.value = TextCellValue(data[row][col]);

        if (row == 0) {
          cell.cellStyle = CellStyle(
            bold: true,
            backgroundColorHex: ExcelColor.fromHexString('#E3F2FD'),
          );
        } else if (row % 2 == 0) {
          cell.cellStyle = CellStyle(
            backgroundColorHex: ExcelColor.fromHexString('#F5F5F5'),
          );
        }
      }
    }

    sheet.setColumnWidth(0, 25);
    sheet.setColumnWidth(1, 20);

    return excel;
  }

  Excel _createBayReadingsWorkbook() {
    var excel = Excel.createExcel();
    excel.delete('Sheet1');

    // Group data by bay type
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
    });

    return excel;
  }
}

// lib/screens/subdivision_dashboard_tabs/energy_tab.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'dart:math';

import '../../models/logsheet_models.dart';
import '../../models/user_model.dart';
import '../../models/bay_model.dart';
import '../../models/hierarchy_models.dart';
import '../../utils/snackbar_utils.dart';
import '../../models/app_state_data.dart';

class EnergyTab extends StatefulWidget {
  final AppUser currentUser;
  final String? initialSelectedSubstationId;
  final DateTime startDate;
  final DateTime endDate;
  final String substationId;

  const EnergyTab({
    Key? key,
    required this.currentUser,
    this.initialSelectedSubstationId,
    required this.startDate,
    required this.endDate,
    required this.substationId,
  }) : super(key: key);

  @override
  _EnergyTabState createState() => _EnergyTabState();
}

class _EnergyTabState extends State<EnergyTab> {
  bool _isLoading = true;
  Substation? _selectedSubstation;
  Map<String, Bay> _baysMap = {};
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 7));
  DateTime _endDate = DateTime.now();

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

  @override
  void initState() {
    super.initState();
    _startDate = widget.startDate;
    _endDate = widget.endDate;
    _initializeData();
  }

  @override
  void didUpdateWidget(EnergyTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.startDate != widget.startDate ||
        oldWidget.endDate != widget.endDate) {
      _startDate = widget.startDate;
      _endDate = widget.endDate;
      _clearViewerData();
      if (_selectedSubstation != null) {
        _fetchEnergyData();
      }
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
    final appState = Provider.of<AppStateData>(context, listen: false);
    _selectedSubstation = appState.selectedSubstation;

    if (_selectedSubstation != null) {
      await _fetchEnergyData();
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchEnergyData() async {
    if (_selectedSubstation == null) return;

    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      await _loadBays();
      await _calculateEnergyLosses();
    } catch (e) {
      print('Error fetching data: $e');
      if (mounted) {
        SnackBarUtils.showSnackBar(
          context,
          'Error loading data: $e',
          isError: true,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadBays() async {
    final baysSnapshot = await FirebaseFirestore.instance
        .collection('bays')
        .where('substationId', isEqualTo: _selectedSubstation!.id)
        .get();

    _baysMap = {
      for (var doc in baysSnapshot.docs) doc.id: Bay.fromFirestore(doc),
    };
  }

  Future<void> _calculateEnergyLosses() async {
    final DateTime queryStartDate = DateTime(
      _startDate.year,
      _startDate.month,
      _startDate.day,
    ).toUtc();
    final DateTime queryEndDate = DateTime(
      _endDate.year,
      _endDate.month,
      _endDate.day,
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
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _selectedSubstation == null
            ? _buildSelectSubstationMessage(theme)
            : _buildEnergyContent(theme),
      ),
    );
  }

  Widget _buildSelectSubstationMessage(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.location_off, size: 80, color: Colors.grey[400]),
            const SizedBox(height: 24),
            Text(
              'No Substation Selected',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Please select a substation from the dashboard to view energy data.',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEnergyContent(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            theme,
            'Bay Energy Losses',
            Icons.battery_alert,
            Colors.red,
          ),
          const SizedBox(height: 12),
          _buildBayLossesTable(theme),
          const SizedBox(height: 24),

          _buildSectionHeader(
            theme,
            'Busbar Energy Abstract',
            Icons.electric_bolt,
            Colors.purple,
          ),
          const SizedBox(height: 12),
          _buildBusbarAbstractTable(theme),
          const SizedBox(height: 24),

          _buildSectionHeader(
            theme,
            'Substation Energy Abstract',
            Icons.analytics,
            Colors.green,
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
        ],
      ),
    );
  }

  Widget _buildSectionHeader(
    ThemeData theme,
    String title,
    IconData icon,
    Color color,
  ) {
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
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface,
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
            Wrap(
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
                      _clearViewerData();
                    });
                  },
                );
              }).toList(),
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
            ],
          ),
          const SizedBox(height: 16),
          // Loading state
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
          // Error state
          else if (_viewerErrorMessage != null)
            _buildErrorMessage(_viewerErrorMessage!)
          // No data state - FIXED: Check if search completed but no data found
          else if (!_isViewerLoading && _rawLogsheetEntriesForViewer.isEmpty)
            _buildNoReadingsMessage()
          // Success state - FIXED: Check if we have actual grouped data
          else if (_groupedEntriesForViewer.isNotEmpty)
            _buildBayReadingsTable(theme)
          // Fallback state
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
              'No readings exist for the selected bays in the period from ${DateFormat('MMM dd, yyyy').format(_startDate)} to ${DateFormat('MMM dd, yyyy').format(_endDate)}.',
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
        'No bays available. Please ensure data is loaded.',
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
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              title: const Text('Select Bays', style: TextStyle(fontSize: 16)),
              content: SizedBox(
                width: double.maxFinite,
                height: 400,
                child: ListView.builder(
                  itemCount: availableBays.length,
                  itemBuilder: (context, index) {
                    final bay = availableBays[index];
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
                            if (!tempSelected.contains(bay.id)) {
                              tempSelected.add(bay.id);
                            }
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
                  onPressed: () => Navigator.pop(context),
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
                  onPressed: () => Navigator.pop(context, tempSelected),
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
        _selectedBayIds = result.toSet().toList();
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
        _startDate.year,
        _startDate.month,
        _startDate.day,
      ).toUtc();
      final DateTime queryEndDate = DateTime(
        _endDate.year,
        _endDate.month,
        _endDate.day,
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
    // Show results section if:
    // 1. Currently loading (to show spinner)
    // 2. Has error message (to show error)
    // 3. Search completed (regardless of whether data found or not)
    return _isViewerLoading ||
        _viewerErrorMessage != null ||
        (!_isViewerLoading && _selectedBayIds.isNotEmpty);
  }
}

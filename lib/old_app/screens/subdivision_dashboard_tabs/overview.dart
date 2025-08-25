import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

import '../../models/hierarchy_models.dart';
import '../../models/user_model.dart';
import '../../models/logsheet_models.dart';
import '../../models/bay_model.dart';
import '../../utils/snackbar_utils.dart';
import '../../models/app_state_data.dart';

class OverviewScreen extends StatefulWidget {
  final AppUser currentUser;
  final List<Substation> accessibleSubstations;

  const OverviewScreen({
    Key? key,
    required this.currentUser,
    required this.accessibleSubstations,
  }) : super(key: key);

  @override
  State<OverviewScreen> createState() => _OverviewScreenState();
}

class _OverviewScreenState extends State<OverviewScreen> {
  Substation? _selectedSubstation;
  String _selectedTimeframe = '7 days';
  late DateTime _endDate;
  late DateTime _startDate;

  final Map<String, List<Bay>> _bayCache = {};
  final Map<String, List<String>> _selectedBayCache = {};
  List<String> _selectedBayIds = [];
  bool _isBaysLoading = false;

  final Map<String, Set<String>> _availableFieldCache = {};
  Set<String> _availableFields = {};
  Set<String> _selectedFields = {};

  bool _isLoading = false;
  String? _error_dbg;
  List<LogsheetEntry> _entries = [];
  Map<String, Bay> _viewerBaysMap = {};
  Map<String, Map<String, List<TimePoint>>> _series = {};
  Map<String, Map<String, SummaryStats>> _summaries = {};

  final TooltipBehavior _tooltipBehavior = TooltipBehavior(
    enable: true,
    activationMode: ActivationMode.singleTap,
    color: Colors.grey[800],
    textStyle: const TextStyle(color: Colors.white, fontSize: 12),
  );

  final Legend _legend = const Legend(
    isVisible: true,
    overflowMode: LegendItemOverflowMode.wrap,
    textStyle: TextStyle(fontSize: 12),
  );

  final DateFormat _dtFmt = DateFormat('yyyy-MM-dd HH:mm');

  @override
  void initState() {
    super.initState();
    _endDate = DateTime.now();
    _applyTimeframe(_selectedTimeframe);
    if (widget.accessibleSubstations.isNotEmpty) {
      _selectedSubstation = widget.accessibleSubstations.first;
      _fetchBaysForSelectedSubstation();
    }
  }

  void _applyTimeframe(String label) {
    final now = DateTime.now();
    DateTime start;
    switch (label) {
      case '1 day':
        start = now.subtract(const Duration(days: 1));
        break;
      case '7 days':
        start = now.subtract(const Duration(days: 7));
        break;
      case '1 month':
        start = DateTime(now.year, now.month - 1, now.day);
        break;
      case '6 months':
        start = DateTime(now.year, now.month - 6, now.day);
        break;
      case '1 year':
        start = DateTime(now.year - 1, now.month, now.day);
        break;
      case '3 years':
        start = DateTime(now.year - 3, now.month, now.day);
        break;
      case 'max':
        start = DateTime(2000, 1, 1);
        break;
      default:
        start = now.subtract(const Duration(days: 7));
    }
    setState(() {
      _selectedTimeframe = label;
      _startDate = start;
      _endDate = now;
    });
  }

  List<Bay> get _bays {
    if (_selectedSubstation == null) return [];
    return _bayCache[_selectedSubstation!.id] ?? [];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return SafeArea(
      child: Scaffold(
        backgroundColor: isDark ? Colors.grey[900] : Colors.grey[50],
        floatingActionButton: _buildFloatingActionButton(theme, isDark),
        body: CustomScrollView(
          slivers: [
            SliverAppBar(
              backgroundColor: isDark ? Colors.grey[900] : Colors.grey[50],
              pinned: true,
              title: Row(
                children: [
                  Icon(
                    Icons.show_chart,
                    color: theme.colorScheme.primary,
                    size: 24,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Overview',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : Colors.grey[900],
                    ),
                  ),
                ],
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildFiltersSection(theme, isDark),
                    const SizedBox(height: 16),
                    _buildFieldsFilterSection(theme, isDark),
                    const SizedBox(height: 16),
                    _buildResults(theme, isDark),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFloatingActionButton(ThemeData theme, bool isDark) {
    final canRun = _selectedSubstation != null && _selectedBayIds.isNotEmpty;
    return FloatingActionButton.extended(
      onPressed: canRun ? _fetchAndBuildSeries : null,
      backgroundColor: canRun ? theme.colorScheme.primary : Colors.grey[400],
      label: Row(
        children: [
          if (_isLoading)
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          else
            const Icon(Icons.show_chart, size: 18),
          const SizedBox(width: 8),
          Text(
            _isLoading ? 'Loading...' : 'Fetch & Plot',
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildFiltersSection(ThemeData theme, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[850] : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.grey[700]! : Colors.grey[200]!,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Filters',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : Colors.grey[900],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _buildSubstationSelector(theme, isDark)),
              const SizedBox(width: 12),
              Expanded(child: _buildTimeframeSelector(theme, isDark)),
            ],
          ),
          const SizedBox(height: 12),
          _buildBaySelector(theme, isDark),
        ],
      ),
    );
  }

  Widget _buildSubstationSelector(ThemeData theme, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Substation',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: isDark ? Colors.white70 : Colors.grey[700],
          ),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
          decoration: BoxDecoration(
            color: isDark ? Colors.grey[800] : Colors.grey[100],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
            ),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<Substation>(
              value: _selectedSubstation,
              isExpanded: true,
              dropdownColor: isDark ? Colors.grey[850] : Colors.white,
              items: widget.accessibleSubstations.map((s) {
                return DropdownMenuItem(
                  value: s,
                  child: Text(
                    s.name,
                    style: const TextStyle(fontSize: 14),
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              }).toList(),
              onChanged: (Substation? newValue) {
                if (newValue == null || newValue.id == _selectedSubstation?.id)
                  return;
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
                  _availableFields = _availableFieldCache[newValue.id] ?? {};
                  _selectedFields = _availableFields.isNotEmpty
                      ? {..._availableFields}
                      : {};
                  _entries.clear();
                  _series.clear();
                  _summaries.clear();
                  _error_dbg = null;
                });
                _fetchBaysForSelectedSubstation();
              },
              icon: Icon(
                Icons.arrow_drop_down,
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

  Widget _buildTimeframeSelector(ThemeData theme, bool isDark) {
    const options = [
      '1 day',
      '7 days',
      '1 month',
      '6 months',
      '1 year',
      '3 years',
      'max',
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Timeframe',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: isDark ? Colors.white70 : Colors.grey[700],
          ),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
          decoration: BoxDecoration(
            color: isDark ? Colors.grey[800] : Colors.grey[100],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
            ),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedTimeframe,
              isExpanded: true,
              dropdownColor: isDark ? Colors.grey[850] : Colors.white,
              items: options
                  .map(
                    (opt) => DropdownMenuItem(
                      value: opt,
                      child: Text(opt, style: const TextStyle(fontSize: 14)),
                    ),
                  )
                  .toList(),
              onChanged: (val) {
                if (val == null) return;
                setState(() {
                  _applyTimeframe(val);
                  _entries.clear();
                  _series.clear();
                  _summaries.clear();
                  _error_dbg = null;
                });
              },
              icon: Icon(
                Icons.arrow_drop_down,
                color: theme.colorScheme.secondary,
                size: 20,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBaySelector(ThemeData theme, bool isDark) {
    if (_bays.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? Colors.grey[850] : Colors.grey[100],
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(
              Icons.info_outline,
              color: isDark ? Colors.white70 : Colors.grey[600],
              size: 18,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _selectedSubstation == null
                    ? 'Select a substation'
                    : _isBaysLoading
                    ? 'Loading bays...'
                    : 'No bays available',
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? Colors.white70 : Colors.grey[600],
                ),
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
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.white70 : Colors.grey[700],
                ),
              ),
            ),
            TextButton.icon(
              onPressed: _showBaySelectionDialog,
              icon: const Icon(Icons.list, size: 16),
              label: const Text('Select Bays', style: TextStyle(fontSize: 13)),
              style: TextButton.styleFrom(
                foregroundColor: theme.colorScheme.primary,
              ),
            ),
          ],
        ),
        if (_selectedBayIds.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: _selectedBayIds.map((bayId) {
              final bay = _bays.firstWhere(
                (b) => b.id == bayId,
                orElse: () => Bay(
                  id: bayId,
                  name: 'Unknown',
                  bayType: 'Unknown',
                  voltageLevel: 'Unknown',
                  substationId: _selectedSubstation?.id ?? '',
                  createdBy: '',
                  createdAt: Timestamp.now(),
                ),
              );
              return Chip(
                label: Text(bay.name, style: const TextStyle(fontSize: 12)),
                onDeleted: () {
                  setState(() {
                    _selectedBayIds.remove(bayId);
                    if (_selectedSubstation != null) {
                      _selectedBayCache[_selectedSubstation!.id] = List.from(
                        _selectedBayIds,
                      );
                    }
                    _entries.clear();
                    _series.clear();
                    _summaries.clear();
                    _error_dbg = null;
                  });
                },
                deleteIconColor: Colors.red,
                backgroundColor: isDark ? Colors.grey[800] : Colors.grey[100],
                side: BorderSide(
                  color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
                ),
              );
            }).toList(),
          ),
        ],
      ],
    );
  }

  Widget _buildFieldsFilterSection(ThemeData theme, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[850] : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.grey[700]! : Colors.grey[200]!,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Fields',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : Colors.grey[900],
                  ),
                ),
              ),
              TextButton(
                onPressed: _availableFields.isEmpty
                    ? null
                    : () {
                        setState(() {
                          if (_selectedFields.length ==
                              _availableFields.length) {
                            _selectedFields.clear();
                          } else {
                            _selectedFields = {..._availableFields};
                          }
                        });
                      },
                child: Text(
                  _selectedFields.length == _availableFields.length
                      ? 'Deselect All'
                      : 'Select All',
                  style: TextStyle(
                    fontSize: 13,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
              TextButton(
                onPressed: _selectedFields.isNotEmpty
                    ? () => setState(() => _selectedFields.clear())
                    : null,
                child: const Text(
                  'Clear',
                  style: TextStyle(fontSize: 13, color: Colors.orange),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_availableFields.isEmpty)
            Text(
              'No fields available. Fetch data to view fields.',
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.white70 : Colors.grey[600],
              ),
            )
          else
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: (_availableFields.toList()..sort())
                  .map(
                    (field) => FilterChip(
                      label: Text(field, style: const TextStyle(fontSize: 12)),
                      selected: _selectedFields.contains(field),
                      onSelected: (selected) {
                        setState(() {
                          if (selected) {
                            _selectedFields.add(field);
                          } else {
                            _selectedFields.remove(field);
                          }
                        });
                      },
                      selectedColor: theme.colorScheme.primary.withOpacity(0.3),
                      backgroundColor: isDark
                          ? Colors.grey[800]
                          : Colors.grey[100],
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: BorderSide(
                          color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildResults(ThemeData theme, bool isDark) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error_dbg != null) {
      return _buildErrorMessage(_error_dbg!, isDark);
    }
    if (_series.isEmpty) {
      return _buildNoDataMessage(isDark);
    }

    final bayIds = _series.keys.toList()
      ..sort(
        (a, b) => (_viewerBaysMap[a]?.name ?? a).compareTo(
          _viewerBaysMap[b]?.name ?? b,
        ),
      );
    return Column(
      children: bayIds
          .map(
            (bayId) => Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: _buildBaySection(theme, isDark, bayId),
            ),
          )
          .toList(),
    );
  }

  Widget _buildBaySection(ThemeData theme, bool isDark, String bayId) {
    final bay = _viewerBaysMap[bayId];
    final fieldsMap = _series[bayId] ?? {};
    final fields =
        fieldsMap.keys
            .where(
              (f) => _selectedFields.isEmpty || _selectedFields.contains(f),
            )
            .toList()
          ..sort();

    if (fields.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? Colors.grey[850] : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? Colors.grey[700]! : Colors.grey[200]!,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              bay?.name ?? 'Unknown',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : Colors.grey[900],
              ),
            ),
            Text(
              '(${bay?.bayType ?? 'Unknown'} • ${bay?.voltageLevel ?? 'Unknown'})',
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.white70 : Colors.grey[600],
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[800] : Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.filter_alt_off,
                    color: isDark ? Colors.white70 : Colors.grey[600],
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'No selected fields to display.',
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? Colors.white70 : Colors.grey[600],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final palette = _sfPalette();
    double? globalMin;
    double? globalMax;
    final List<CartesianSeries<TimePoint, DateTime>> seriesList = [];
    for (int i = 0; i < fields.length; i++) {
      final field = fields[i];
      final points = List<TimePoint>.from(fieldsMap[field] ?? [])
        ..sort((a, b) => a.time.compareTo(b.time));
      if (points.isEmpty) continue;

      for (final p in points) {
        globalMin = globalMin == null
            ? p.value
            : (p.value < globalMin ? p.value : globalMin);
        globalMax = globalMax == null
            ? p.value
            : (p.value > globalMax ? p.value : globalMax);
      }

      seriesList.add(
        LineSeries<TimePoint, DateTime>(
          name: field,
          dataSource: points,
          xValueMapper: (p, _) => p.time,
          yValueMapper: (p, _) => p.value,
          markerSettings: const MarkerSettings(
            isVisible: true,
            width: 4,
            height: 4,
          ),
          dataLabelSettings: const DataLabelSettings(isVisible: false),
          width: 2,
        ),
      );
    }

    if (seriesList.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? Colors.grey[850] : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? Colors.grey[700]! : Colors.grey[200]!,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              bay?.name ?? 'Unknown',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : Colors.grey[900],
              ),
            ),
            Text(
              '(${bay?.bayType ?? 'Unknown'} • ${bay?.voltageLevel ?? 'Unknown'})',
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.white70 : Colors.grey[600],
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[800] : Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.show_chart_outlined,
                    color: isDark ? Colors.white70 : Colors.amber,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'No data available for selected fields.',
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? Colors.white70 : Colors.grey[600],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    double? axisMin = globalMin;
    double? axisMax = globalMax;
    if (axisMin != null && axisMax != null && axisMin == axisMax) {
      final pad = (axisMin.abs() * 0.1).clamp(0.1, 10.0);
      axisMin -= pad;
      axisMax += pad;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[850] : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.grey[700]! : Colors.grey[200]!,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      bay?.name ?? 'Unknown',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : Colors.grey[900],
                      ),
                    ),
                    Text(
                      '(${bay?.bayType ?? 'Unknown'} • ${bay?.voltageLevel ?? 'Unknown'})',
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? Colors.white70 : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${seriesList.length} field${seriesList.length == 1 ? '' : 's'}',
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 260),
            child: SfCartesianChart(
              enableAxisAnimation: true,
              tooltipBehavior: _tooltipBehavior,
              legend: _legend,
              palette: palette,
              primaryXAxis: DateTimeAxis(
                majorGridLines: const MajorGridLines(width: 0.5),
                edgeLabelPlacement: EdgeLabelPlacement.shift,
                intervalType: DateTimeIntervalType.auto,
                dateFormat: DateFormat('MMMd HH:mm'),
                labelStyle: const TextStyle(fontSize: 12),
              ),
              primaryYAxis: NumericAxis(
                majorGridLines: const MajorGridLines(width: 0.5),
                minimum: axisMin,
                maximum: axisMax,
                rangePadding: ChartRangePadding.round,
                labelStyle: const TextStyle(fontSize: 12),
              ),
              series: seriesList,
            ),
          ),
          const SizedBox(height: 16),
          _buildSummaryTable(theme, isDark, bayId, fields),
          const Divider(height: 32),
        ],
      ),
    );
  }

  Widget _buildSummaryTable(
    ThemeData theme,
    bool isDark,
    String bayId,
    List<String> fields,
  ) {
    final baySummaries = _summaries[bayId] ?? {};
    final availableFields = fields
        .where((f) => baySummaries.containsKey(f))
        .toList();
    if (availableFields.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Summary',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : Colors.grey[900],
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            border: Border.all(
              color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor: MaterialStateColor.resolveWith(
                (states) => theme.colorScheme.primary.withOpacity(0.1),
              ),
              dataRowMinHeight: 44,
              dataRowMaxHeight: 48,
              columnSpacing: 16,
              horizontalMargin: 12,
              headingTextStyle: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: theme.colorScheme.primary,
              ),
              dataTextStyle: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.white : Colors.grey[900],
              ),
              columns: const [
                DataColumn(label: Text('Field')),
                DataColumn(label: Text('Min'), numeric: true),
                DataColumn(label: Text('Min Time')),
                DataColumn(label: Text('Max'), numeric: true),
                DataColumn(label: Text('Max Time')),
              ],
              rows: availableFields.map((field) {
                final summary = baySummaries[field]!;
                final isCurrentField =
                    field.toLowerCase().contains('current') ||
                    field.toLowerCase().contains('amp');
                final isVoltageField =
                    field.toLowerCase().contains('voltage') ||
                    field.toLowerCase().contains('volt');

                return DataRow(
                  color: MaterialStateColor.resolveWith(
                    (states) => isCurrentField
                        ? Colors.blue.withOpacity(0.05)
                        : isVoltageField
                        ? Colors.orange.withOpacity(0.05)
                        : Colors.transparent,
                  ),
                  cells: [
                    DataCell(
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: isCurrentField
                                  ? Colors.blue
                                  : isVoltageField
                                  ? Colors.orange
                                  : Colors.grey,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            field,
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ),
                    DataCell(
                      Text(
                        _fmtNum(summary.min),
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Colors.red,
                        ),
                      ),
                    ),
                    DataCell(
                      Text(
                        DateFormat('MMM dd HH:mm').format(summary.minAt),
                        style: const TextStyle(fontSize: 11),
                      ),
                    ),
                    DataCell(
                      Text(
                        _fmtNum(summary.max),
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Colors.green,
                        ),
                      ),
                    ),
                    DataCell(
                      Text(
                        DateFormat('MMM dd HH:mm').format(summary.maxAt),
                        style: const TextStyle(fontSize: 11),
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          children: [
            _buildLegendItem(Colors.blue, 'Current', isDark),
            _buildLegendItem(Colors.orange, 'Voltage', isDark),
            _buildLegendItem(Colors.grey, 'Other', isDark),
          ],
        ),
      ],
    );
  }

  Widget _buildLegendItem(Color color, String label, bool isDark) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: isDark ? Colors.white70 : Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildErrorMessage(String error, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? Colors.red.withOpacity(0.2) : Colors.red[50],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: Colors.red[700], size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              error,
              style: TextStyle(fontSize: 13, color: Colors.red[700]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoDataMessage(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Column(
          children: [
            Icon(
              Icons.search_off,
              size: 36,
              color: isDark ? Colors.white70 : Colors.grey[400],
            ),
            const SizedBox(height: 8),
            Text(
              'No Data',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white70 : Colors.grey[600],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Select bays and tap Fetch & Plot.',
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.white70 : Colors.grey[500],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showBaySelectionDialog() async {
    if (_bays.isEmpty) {
      SnackBarUtils.showSnackBar(
        context,
        'No bays available. Select a substation.',
        isError: true,
      );
      return;
    }
    final List<String> tempSelected = List.from(_selectedBayIds);
    final result = await showDialog<List<String>>(
      context: context,
      builder: (BuildContext context) {
        final theme = Theme.of(context);
        final isDark = theme.brightness == Brightness.dark;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              backgroundColor: isDark ? Colors.grey[900] : Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              child: SizedBox(
                width: double.maxFinite,
                height: 450,
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.grey[850] : Colors.grey[100],
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(10),
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
                                color: isDark
                                    ? Colors.white
                                    : theme.colorScheme.primary,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(Icons.close, size: 20),
                            color: isDark ? Colors.white70 : Colors.grey[600],
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${tempSelected.length}/${_bays.length} bays selected',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: isDark
                                    ? Colors.white70
                                    : Colors.grey[700],
                              ),
                            ),
                          ),
                          Row(
                            children: [
                              TextButton(
                                onPressed: () {
                                  setDialogState(() {
                                    if (tempSelected.length == _bays.length) {
                                      tempSelected.clear();
                                    } else {
                                      tempSelected.clear();
                                      tempSelected.addAll(
                                        _bays.map((b) => b.id),
                                      );
                                    }
                                  });
                                },
                                child: Text(
                                  tempSelected.length == _bays.length
                                      ? 'Deselect All'
                                      : 'Select All',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: theme.colorScheme.primary,
                                  ),
                                ),
                              ),
                              TextButton(
                                onPressed: tempSelected.isNotEmpty
                                    ? () => setDialogState(
                                        () => tempSelected.clear(),
                                      )
                                    : null,
                                child: const Text(
                                  'Clear',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.orange,
                                  ),
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
                        padding: const EdgeInsets.all(12),
                        itemCount: _bays.length,
                        itemBuilder: (context, index) {
                          final bay = _bays[index];
                          final isSelected = tempSelected.contains(bay.id);
                          return Container(
                            margin: const EdgeInsets.only(bottom: 6),
                            decoration: BoxDecoration(
                              color: isDark ? Colors.grey[850] : Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isSelected
                                    ? theme.colorScheme.primary
                                    : (isDark
                                          ? Colors.grey[700]!
                                          : Colors.grey[300]!),
                              ),
                            ),
                            child: CheckboxListTile(
                              title: Text(
                                bay.name,
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
                                  color: isDark
                                      ? Colors.white70
                                      : Colors.grey[600],
                                ),
                              ),
                              value: isSelected,
                              onChanged: (v) {
                                setDialogState(() {
                                  if (v == true) {
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
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          ElevatedButton(
                            onPressed: () =>
                                Navigator.of(context).pop(tempSelected),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: theme.colorScheme.primary,
                              foregroundColor: theme.colorScheme.onPrimary,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.check, size: 16),
                                const SizedBox(width: 8),
                                Text(
                                  'Select (${tempSelected.length})',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
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
        _entries.clear();
        _series.clear();
        _summaries.clear();
        _error_dbg = null;
      });
    }
  }

  Future<void> _fetchBaysForSelectedSubstation() async {
    if (_selectedSubstation == null) return;
    if (_bayCache.containsKey(_selectedSubstation!.id)) {
      setState(() {
        _selectedBayIds = List.from(
          _selectedBayCache[_selectedSubstation!.id] ?? [],
        );
      });
      return;
    }

    if (_isBaysLoading) return;
    setState(() => _isBaysLoading = true);
    try {
      final baysSnapshot = await FirebaseFirestore.instance
          .collection('bays')
          .where('substationId', isEqualTo: _selectedSubstation!.id)
          .orderBy('name')
          .get();

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
    } catch (e) {
      setState(() => _isBaysLoading = false);
      SnackBarUtils.showSnackBar(
        context,
        'Error loading bays: $e',
        isError: true,
      );
    }
  }

  Future<void> _fetchAndBuildSeries() async {
    if (_selectedSubstation == null || _selectedBayIds.isEmpty) {
      SnackBarUtils.showSnackBar(
        context,
        'Please select substation and bays.',
        isError: true,
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _error_dbg = null;
      _entries.clear();
      _series.clear();
      _summaries.clear();
    });

    try {
      _viewerBaysMap.clear();
      const chunkSize = 10;
      for (int i = 0; i < _selectedBayIds.length; i += chunkSize) {
        final chunk = _selectedBayIds.sublist(
          i,
          (i + chunkSize).clamp(0, _selectedBayIds.length),
        );
        final baysSnapshot = await FirebaseFirestore.instance
            .collection('bays')
            .where(FieldPath.documentId, whereIn: chunk)
            .get();
        for (var doc in baysSnapshot.docs) {
          _viewerBaysMap[doc.id] = Bay.fromFirestore(doc);
        }
      }

      final queryStart = DateTime(
        _startDate.year,
        _startDate.month,
        _startDate.day,
      ).toUtc();
      final queryEnd = _endDate.toUtc();

      List<LogsheetEntry> all = [];
      for (int i = 0; i < _selectedBayIds.length; i += chunkSize) {
        final chunk = _selectedBayIds.sublist(
          i,
          (i + chunkSize).clamp(0, _selectedBayIds.length),
        );
        final snap = await FirebaseFirestore.instance
            .collection('logsheetEntries')
            .where('substationId', isEqualTo: _selectedSubstation!.id)
            .where('bayId', whereIn: chunk)
            .where('frequency', isEqualTo: 'hourly')
            .where(
              'readingTimestamp',
              isGreaterThanOrEqualTo: Timestamp.fromDate(queryStart),
            )
            .where(
              'readingTimestamp',
              isLessThanOrEqualTo: Timestamp.fromDate(queryEnd),
            )
            .orderBy('readingTimestamp')
            .get();

        all.addAll(snap.docs.map((d) => LogsheetEntry.fromFirestore(d)));
      }

      setState(() {
        _entries = all;
      });

      if (all.isEmpty) {
        setState(() {
          _error_dbg =
              'No logsheet entries found for the selected bays and time range.';
        });
        return;
      }

      final fields = <String>{};
      for (final e in all.take(200)) {
        e.values.forEach((key, value) {
          fields.add(key.toString());
        });
      }

      if (_selectedSubstation != null) {
        _availableFieldCache[_selectedSubstation!.id] = fields;
      }
      if (_selectedFields.isEmpty || !fields.containsAll(_selectedFields)) {
        _selectedFields = {...fields};
      }
      _availableFields = fields;

      final Map<String, Map<String, List<TimePoint>>> series = {};
      for (final e in all) {
        final dt = e.readingTimestamp.toDate().toLocal();
        e.values.forEach((key, raw) {
          final String field = key.toString();
          final double? val = _extractNumeric(raw);
          if (val == null) return;

          series.putIfAbsent(e.bayId, () => {});
          series[e.bayId]!.putIfAbsent(field, () => []);
          series[e.bayId]![field]!.add(TimePoint(time: dt, value: val));
        });
      }

      series.removeWhere((bayId, fieldMap) => fieldMap.isEmpty);

      final Map<String, Map<String, SummaryStats>> summaries = {};
      series.forEach((bayId, fieldMap) {
        summaries[bayId] = {};
        fieldMap.forEach((field, points) {
          if (points.isEmpty) return;
          points.sort((a, b) => a.time.compareTo(b.time));
          double min = points.first.value;
          double max = points.first.value;
          DateTime minAt = points.first.time;
          DateTime maxAt = points.first.time;

          for (final p in points) {
            if (p.value < min) {
              min = p.value;
              minAt = p.time;
            }
            if (p.value > max) {
              max = p.value;
              maxAt = p.time;
            }
          }
          summaries[bayId]![field] = SummaryStats(
            min: min,
            max: max,
            minAt: minAt,
            maxAt: maxAt,
          );
        });
      });

      setState(() {
        _series = series;
        _summaries = summaries;
      });
    } catch (e) {
      setState(() {
        _error_dbg = 'Failed to fetch data: $e';
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  double? _extractNumeric(dynamic raw) {
    if (raw == null) return null;
    if (raw is num) return raw.toDouble();
    if (raw is bool) return raw ? 1.0 : 0.0;
    if (raw is Map) {
      final hasValue = raw.containsKey('value');
      if (!hasValue) return null;
      final v = raw['value'];
      if (v is num) return v.toDouble();
      if (v is bool) return v ? 1.0 : 0.0;
      if (v is String) return double.tryParse(v);
      return null;
    }
    if (raw is String) {
      final lower = raw.toLowerCase();
      if (lower == 'on') return 1.0;
      if (lower == 'off') return 0.0;
      return double.tryParse(raw);
    }
    return null;
  }

  List<Color> _sfPalette() {
    return [
      Colors.blue,
      Colors.orange,
      Colors.green,
      Colors.purple,
      Colors.red,
      Colors.teal,
      Colors.indigo,
      Colors.brown,
      Colors.pink,
      Colors.cyan,
      Colors.lime,
      Colors.amber,
    ];
  }

  String _fmtNum(double v) {
    if (v.abs() >= 1000) return v.toStringAsFixed(0);
    if (v.abs() >= 100) return v.toStringAsFixed(1);
    return v.toStringAsFixed(2);
  }
}

class TimePoint {
  final DateTime time;
  final double value;
  TimePoint({required this.time, required this.value});
}

class SummaryStats {
  final double min;
  final double max;
  final DateTime minAt;
  final DateTime maxAt;
  SummaryStats({
    required this.min,
    required this.max,
    required this.minAt,
    required this.maxAt,
  });
}

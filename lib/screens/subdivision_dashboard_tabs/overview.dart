// lib/screens/subdivision_dashboard_tabs/overview.dart

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

  // Timeframe control
  String _selectedTimeframe = '7 days';
  late DateTime _endDate;
  late DateTime _startDate;

  // Bay selection and caching
  final Map<String, List<Bay>> _bayCache = {}; // substationId -> bays
  final Map<String, List<String>> _selectedBayCache =
      {}; // substationId -> selected bayIds
  List<String> _selectedBayIds = [];
  bool _isBaysLoading = false;

  // Field filtering and caching
  final Map<String, Set<String>> _availableFieldCache =
      {}; // substationId -> field names
  Set<String> _availableFields = {}; // derived from sample data
  Set<String> _selectedFields = {}; // chosen by user

  // Firestore results and parsing
  bool _isLoading = false;
  String? _errorMessage;
  List<LogsheetEntry> _entries = [];
  Map<String, Bay> _viewerBaysMap = {}; // bayId -> Bay

  // Parsed time-series: bayId -> fieldName -> List<TimePoint>
  Map<String, Map<String, List<TimePoint>>> _series = {};

  // Min/Max summaries: bayId -> fieldName -> SummaryStats
  Map<String, Map<String, SummaryStats>> _summaries = {};

  // Chart interaction - Initialize immediately to avoid late initialization error
  final TooltipBehavior _tooltipBehavior = TooltipBehavior(
    enable: true,
    activationMode: ActivationMode.singleTap,
  );

  final Legend _legend = const Legend(
    isVisible: true,
    overflowMode: LegendItemOverflowMode.wrap,
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

  // Timeframe utilities
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
        start = DateTime(
          now.year,
          now.month - 1,
          now.day,
          now.hour,
          now.minute,
          now.second,
        );
        break;
      case '6 months':
        start = DateTime(
          now.year,
          now.month - 6,
          now.day,
          now.hour,
          now.minute,
          now.second,
        );
        break;
      case '1 year':
        start = DateTime(
          now.year - 1,
          now.month,
          now.day,
          now.hour,
          now.minute,
          now.second,
        );
        break;
      case '3 years':
        start = DateTime(
          now.year - 3,
          now.month,
          now.day,
          now.hour,
          now.minute,
          now.second,
        );
        break;
      case 'max':
        // Far past to include all
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

  // Accessors
  List<Bay> get _bays {
    if (_selectedSubstation == null) return [];
    return _bayCache[_selectedSubstation!.id] ?? [];
  }

  // UI
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return SafeArea(
      child: Scaffold(
        backgroundColor: isDark
            ? const Color(0xFF1C1C1E)
            : const Color(0xFFFAFAFA),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(theme, isDark),
              const SizedBox(height: 16),
              _buildSelectorsCard(theme, isDark),
              const SizedBox(height: 16),
              _buildFieldsFilterCard(theme, isDark),
              const SizedBox(height: 16),
              _buildActionBar(theme, isDark),
              const SizedBox(height: 16),
              _buildResults(theme, isDark),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme, bool isDark) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            Icons.show_chart,
            color: theme.colorScheme.primary,
            size: 20,
          ),
        ),
        const SizedBox(width: 12),
        Text(
          'Overview',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : theme.colorScheme.onSurface,
          ),
        ),
      ],
    );
  }

  Widget _buildSelectorsCard(ThemeData theme, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2C2C2E) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withOpacity(0.3)
                : Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Selection',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _buildSubstationSelector(theme, isDark)),
              const SizedBox(width: 16),
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
            color: isDark ? Colors.white : theme.colorScheme.onSurface,
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
              dropdownColor: isDark ? const Color(0xFF2C2C2E) : Colors.white,
              items: widget.accessibleSubstations.map((s) {
                return DropdownMenuItem(
                  value: s,
                  child: Text(
                    s.name,
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark ? Colors.white : null,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              }).toList(),
              onChanged: (Substation? newValue) {
                if (newValue == null || newValue.id == _selectedSubstation?.id)
                  return;
                // cache current selection
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
                  _errorMessage = null;
                });
                _fetchBaysForSelectedSubstation();
              },
              icon: Icon(
                Icons.keyboard_arrow_down,
                color: theme.colorScheme.primary,
                size: 20,
              ),
              hint: Text(
                'Select Substation',
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? Colors.white : null,
                ),
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
            color: isDark ? Colors.white : theme.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: theme.colorScheme.secondary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: theme.colorScheme.secondary.withOpacity(0.3),
            ),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedTimeframe,
              isExpanded: true,
              dropdownColor: isDark ? const Color(0xFF2C2C2E) : Colors.white,
              items: options
                  .map(
                    (opt) => DropdownMenuItem(
                      value: opt,
                      child: Text(
                        opt,
                        style: TextStyle(color: isDark ? Colors.white : null),
                      ),
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
                  _errorMessage = null;
                });
              },
              icon: Icon(
                Icons.keyboard_arrow_down,
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
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF3C3C3E) : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark
                ? Colors.white.withOpacity(0.1)
                : Colors.grey.shade200,
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.info_outline,
              color: isDark
                  ? Colors.white.withOpacity(0.6)
                  : Colors.grey.shade600,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _selectedSubstation == null
                    ? 'Please select a substation'
                    : _isBaysLoading
                    ? 'Loading bays for ${_selectedSubstation!.name}...'
                    : 'No bays available for ${_selectedSubstation!.name}',
                style: TextStyle(
                  color: isDark
                      ? Colors.white.withOpacity(0.6)
                      : Colors.grey.shade600,
                  fontSize: 13,
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
                  color: isDark ? Colors.white : null,
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
                      _entries.clear();
                      _series.clear();
                      _summaries.clear();
                      _errorMessage = null;
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

  Widget _buildFieldsFilterCard(ThemeData theme, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2C2C2E) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withOpacity(0.3)
                : Colors.black.withOpacity(0.05),
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
              Expanded(
                child: Text(
                  'Reading Fields',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : theme.colorScheme.onSurface,
                  ),
                ),
              ),
              TextButton.icon(
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
                icon: Icon(
                  _selectedFields.length == _availableFields.length
                      ? Icons.deselect
                      : Icons.select_all,
                  size: 16,
                ),
                label: Text(
                  _selectedFields.length == _availableFields.length
                      ? 'Deselect All'
                      : 'Select All',
                ),
                style: TextButton.styleFrom(
                  foregroundColor: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(width: 8),
              TextButton.icon(
                onPressed: _selectedFields.isNotEmpty
                    ? () => setState(() {
                        _selectedFields.clear();
                      })
                    : null,
                icon: const Icon(Icons.clear, size: 16),
                label: const Text('Clear'),
                style: TextButton.styleFrom(foregroundColor: Colors.orange),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Empty state
          if (_availableFields.isEmpty)
            Text(
              'No fields yet. Fetch data to discover fields.',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.white70 : Colors.grey.shade600,
              ),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
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
                    ),
                  )
                  .toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildActionBar(ThemeData theme, bool isDark) {
    final canRun = _selectedSubstation != null && _selectedBayIds.isNotEmpty;
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton.icon(
        onPressed: canRun ? _fetchAndBuildSeries : null,
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
            : const Icon(Icons.show_chart, size: 18),
        label: Text(
          _isLoading ? 'Loading...' : 'Fetch & Plot',
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
        ),
      ),
    );
  }

  Widget _buildResults(ThemeData theme, bool isDark) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_errorMessage != null) {
      return _buildErrorMessage(_errorMessage!, isDark);
    }
    if (_series.isEmpty) {
      return _buildNoDataMessage(isDark);
    }

    final bayIds = _series.keys.toList();
    bayIds.sort((a, b) {
      final an = _viewerBaysMap[a]?.name ?? a;
      final bn = _viewerBaysMap[b]?.name ?? b;
      return an.compareTo(bn);
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // One chart per bay
        for (final bayId in bayIds) ...[
          _buildBayChartCard(theme, isDark, bayId),
          const SizedBox(height: 16),
        ],
      ],
    );
  }

  Widget _buildBayChartCard(ThemeData theme, bool isDark, String bayId) {
    final bay = _viewerBaysMap[bayId];
    final fieldsMap = _series[bayId] ?? {};
    final allFields = fieldsMap.keys.toList();

    if (allFields.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF2C2C2E) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: isDark
                  ? Colors.black.withOpacity(0.3)
                  : Colors.black.withOpacity(0.05),
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Text(
                    bay?.name ?? 'Unknown',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: Colors.orange,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '(${bay?.bayType ?? 'Unknown'} • ${bay?.voltageLevel ?? 'Unknown'})',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white70 : Colors.grey.shade700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.orange.withOpacity(0.1)
                    : Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: Colors.orange.shade700,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'No readings available for this bay in the selected time range.',
                      style: TextStyle(
                        color: Colors.orange.shade700,
                        fontSize: 13,
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

    // Respect selected fields; if none selected, show nothing
    final fields =
        allFields
            .where(
              (f) => _selectedFields.isEmpty || _selectedFields.contains(f),
            )
            .toList()
          ..sort();
    if (fields.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF2C2C2E) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: isDark
                  ? Colors.black.withOpacity(0.3)
                  : Colors.black.withOpacity(0.05),
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
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
                const SizedBox(width: 8),
                Text(
                  '(${bay?.bayType ?? 'Unknown'} • ${bay?.voltageLevel ?? 'Unknown'})',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white70 : Colors.grey.shade700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.blue.withOpacity(0.1)
                    : Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.filter_alt_off,
                    color: Colors.blue.shade700,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'No selected fields to display. Please select reading fields above.',
                      style: TextStyle(
                        color: Colors.blue.shade700,
                        fontSize: 13,
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

    // Prepare series and detect global min/max for better Y axis range
    final palette = _sfPalette();
    double? globalMin;
    double? globalMax;

    final List<CartesianSeries<TimePoint, DateTime>> seriesList = [];
    for (int i = 0; i < fields.length; i++) {
      final field = fields[i];
      final points = List<TimePoint>.from(fieldsMap[field] ?? []);
      points.sort((a, b) => a.time.compareTo(b.time));

      if (points.isEmpty) continue;

      // track min/max across visible fields
      for (final p in points) {
        globalMin = (globalMin == null)
            ? p.value
            : (p.value < globalMin! ? p.value : globalMin);
        globalMax = (globalMax == null)
            ? p.value
            : (p.value > globalMax! ? p.value : globalMax);
      }

      seriesList.add(
        LineSeries<TimePoint, DateTime>(
          name: field,
          dataSource: points,
          xValueMapper: (p, _) => p.time,
          yValueMapper: (p, _) => p.value,
          markerSettings: const MarkerSettings(
            isVisible: true,
            width: 6,
            height: 6,
          ),
          dataLabelSettings: const DataLabelSettings(isVisible: false),
          width: 2,
        ),
      );
    }

    // If after filtering there's nothing to plot
    if (seriesList.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF2C2C2E) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: isDark
                  ? Colors.black.withOpacity(0.3)
                  : Colors.black.withOpacity(0.05),
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Text(
                    bay?.name ?? 'Unknown',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '(${bay?.bayType ?? 'Unknown'} • ${bay?.voltageLevel ?? 'Unknown'})',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white70 : Colors.grey.shade700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.grey.withOpacity(0.1)
                    : Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.show_chart_outlined,
                    color: Colors.grey.shade600,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'No data points available for the selected fields in the chosen time range.',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 13,
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

    // Y-axis padding to avoid flat line look when data is constant/sparse
    double? axisMin = globalMin;
    double? axisMax = globalMax;
    if (axisMin != null && axisMax != null && axisMin == axisMax) {
      // expand a bit
      final pad = (axisMin.abs() * 0.1).clamp(0.1, 10.0);
      axisMin -= pad;
      axisMax += pad;
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2C2C2E) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withOpacity(0.3)
                : Colors.black.withOpacity(0.05),
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Text(
                  bay?.name ?? 'Unknown',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: Colors.green,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '(${bay?.bayType ?? 'Unknown'} • ${bay?.voltageLevel ?? 'Unknown'})',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.white70 : Colors.grey.shade700,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.green.withOpacity(0.3)),
                ),
                child: Text(
                  '${seriesList.length} field${seriesList.length == 1 ? '' : 's'}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Colors.green,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 280),
            child: SfCartesianChart(
              enableAxisAnimation: true,
              tooltipBehavior: _tooltipBehavior,
              legend: _legend,
              palette: palette,
              primaryXAxis: DateTimeAxis(
                majorGridLines: const MajorGridLines(width: 0.5),
                edgeLabelPlacement: EdgeLabelPlacement.shift,
                // For data possibly ≤1 day and sparse, show readable labels
                intervalType: DateTimeIntervalType.auto,
                dateFormat: DateFormat('MMMd HH:mm'),
              ),
              primaryYAxis: NumericAxis(
                majorGridLines: const MajorGridLines(width: 0.5),
                // guard against nulls
                minimum: axisMin,
                maximum: axisMax,
                // nice tick distribution
                rangePadding: ChartRangePadding.round,
              ),
              series: seriesList,
            ),
          ),
          const SizedBox(height: 12),
          _buildSummaryTable(theme, isDark, bayId, fields),
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
    if (baySummaries.isEmpty) {
      return SizedBox(
        width: double.infinity,
        child: Text(
          'No summary available.',
          style: TextStyle(
            color: isDark ? Colors.white70 : Colors.grey.shade700,
            fontSize: 12,
          ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Summary (Min/Max)',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : null,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: fields.map((f) {
            final s = baySummaries[f];
            if (s == null) return const SizedBox.shrink();
            return Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF3C3C3E) : Colors.grey.shade50,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withOpacity(0.1)
                      : Colors.grey.shade200,
                ),
              ),
              child: Text(
                '$f: min ${_fmtNum(s.min)} at ${_dtFmt.format(s.minAt)}, max ${_fmtNum(s.max)} at ${_dtFmt.format(s.maxAt)}',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.white : null,
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildErrorMessage(String error, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.red.withOpacity(0.1) : Colors.red.shade50,
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

  Widget _buildNoDataMessage(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(32),
      child: Center(
        child: Column(
          children: [
            Icon(
              Icons.search_off,
              size: 48,
              color: isDark
                  ? Colors.white.withOpacity(0.4)
                  : Colors.grey.shade400,
            ),
            const SizedBox(height: 12),
            Text(
              'No data to display',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: isDark
                    ? Colors.white.withOpacity(0.6)
                    : Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Select bays and tap "Fetch & Plot" to view reading data.',
              style: TextStyle(
                fontSize: 13,
                color: isDark
                    ? Colors.white.withOpacity(0.5)
                    : Colors.grey.shade500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // Dialog for bay multi-select
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
        final theme = Theme.of(context);
        final isDark = theme.brightness == Brightness.dark;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              backgroundColor: isDark ? const Color(0xFF1C1C1E) : Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: SizedBox(
                width: double.maxFinite,
                height: 500,
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.fromLTRB(20, 16, 16, 16),
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF2C2C2E)
                            : theme.colorScheme.primary.withOpacity(0.1),
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
                                color: isDark
                                    ? Colors.white
                                    : theme.colorScheme.primary,
                              ),
                            ),
                          ),
                          InkWell(
                            onTap: () => Navigator.of(context).pop(),
                            borderRadius: BorderRadius.circular(4),
                            child: Padding(
                              padding: const EdgeInsets.all(4),
                              child: Icon(
                                Icons.close,
                                size: 20,
                                color: isDark
                                    ? Colors.white
                                    : theme.colorScheme.onSurface.withOpacity(
                                        0.7,
                                      ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${tempSelected.length} of ${_bays.length} bays selected',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: isDark ? Colors.white : null,
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
                                      tempSelected
                                        ..clear()
                                        ..addAll(_bays.map((b) => b.id));
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
                                    ? () => setDialogState(
                                        () => tempSelected.clear(),
                                      )
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
                    Divider(
                      height: 1,
                      color: isDark ? Colors.white.withOpacity(0.1) : null,
                    ),
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
                              color: isDark
                                  ? const Color(0xFF2C2C2E)
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isSelected
                                    ? theme.colorScheme.primary.withOpacity(0.3)
                                    : (isDark
                                          ? Colors.white.withOpacity(0.1)
                                          : Colors.grey.shade300),
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
                                      : (isDark ? Colors.white : null),
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
                                      : (isDark
                                            ? Colors.white.withOpacity(0.6)
                                            : Colors.grey.shade600),
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
                    Divider(
                      height: 1,
                      color: isDark ? Colors.white.withOpacity(0.1) : null,
                    ),
                    Padding(
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
        _entries.clear();
        _series.clear();
        _summaries.clear();
        _errorMessage = null;
      });
    }
  }

  // Data fetching and parsing

  Future<void> _fetchBaysForSelectedSubstation() async {
    if (_selectedSubstation == null) return;

    // Use cache if available to save reads
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
      _errorMessage = null;
      _entries.clear();
      _series.clear();
      _summaries.clear();
    });

    try {
      // Load bay meta for viewer labels
      _viewerBaysMap.clear();
      // If large list, consider chunking whereIn to <=10 ids per query
      // Here we chunk for safety.
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

      // Range
      final queryStart = DateTime(
        _startDate.year,
        _startDate.month,
        _startDate.day,
      ).toUtc();
      final queryEnd = _endDate.toUtc();

      // Fetch entries, chunk on bayIds for whereIn
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
          _errorMessage =
              'No logsheet entries found for the selected bays and time range.';
        });
        return;
      }

      // Discover available fields from sample of the dataset (to avoid huge iteration costs)
      final fields = <String>{};
      for (final e in all.take(200)) {
        e.values.forEach((key, value) {
          fields.add(key.toString());
        });
      }

      // Update caches for fields
      if (_selectedSubstation != null) {
        _availableFieldCache[_selectedSubstation!.id] = fields;
      }
      // If no previously selected fields or selectedFields not subset of new fields, refresh selection
      if (_selectedFields.isEmpty || !fields.containsAll(_selectedFields)) {
        _selectedFields = {...fields};
      }
      _availableFields = fields;

      // Build series (bay -> field -> time-series)
      final Map<String, Map<String, List<TimePoint>>> series = {};
      for (final e in all) {
        final dt = e.readingTimestamp.toDate().toLocal();
        e.values.forEach((key, raw) {
          final String field = key.toString();

          // Only prepare all fields; chips will show/hide in chart
          final double? val = _extractNumeric(raw);
          if (val == null) return;

          series.putIfAbsent(e.bayId, () => {});
          series[e.bayId]!.putIfAbsent(field, () => []);
          series[e.bayId]![field]!.add(TimePoint(time: dt, value: val));
        });
      }

      // Remove bays with no data
      series.removeWhere((bayId, fieldMap) => fieldMap.isEmpty);

      // Compute summaries
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
        _errorMessage = 'Failed to fetch data: $e';
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // Converts various value shapes into doubles suitable for charting
  // - Primitive num -> double
  // - Map with { value, unit } -> parses value as num, boolean -> 1/0
  // - Boolean -> 1 for ON/true, 0 for OFF/false
  double? _extractNumeric(dynamic raw) {
    if (raw == null) return null;

    if (raw is num) {
      return raw.toDouble();
    }
    if (raw is bool) {
      return raw ? 1.0 : 0.0;
    }
    if (raw is Map) {
      final hasValue = raw.containsKey('value');
      if (!hasValue) return null;
      final v = raw['value'];
      if (v is num) return v.toDouble();
      if (v is bool) return v ? 1.0 : 0.0;
      if (v is String) {
        final parsed = double.tryParse(v);
        return parsed;
      }
      return null;
    }
    if (raw is String) {
      // Try parse numeric embedded text, else support ON/OFF
      final lower = raw.toLowerCase();
      if (lower == 'on') return 1.0;
      if (lower == 'off') return 0.0;
      return double.tryParse(raw);
    }
    return null;
  }

  // Palette for line colors (Syncfusion will cycle)
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
    if (v.abs() >= 1000) {
      return v.toStringAsFixed(0);
    } else if (v.abs() >= 100) {
      return v.toStringAsFixed(1);
    } else {
      return v.toStringAsFixed(2);
    }
  }
}

// Simple data carriers
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

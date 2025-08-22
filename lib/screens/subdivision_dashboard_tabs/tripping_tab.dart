import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:excel/excel.dart' hide Border;
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:permission_handler/permission_handler.dart';
import 'package:open_filex/open_filex.dart';

import '../../models/user_model.dart';
import '../../models/tripping_shutdown_model.dart';
import '../../models/bay_model.dart';
import '../../models/hierarchy_models.dart';
import '../../utils/snackbar_utils.dart';
import '../substation_dashboard/tripping_shutdown_entry_screen.dart';
import 'tripping_details_screen.dart';

class TrippingTab extends StatefulWidget {
  final AppUser currentUser;
  final List<Substation> accessibleSubstations;

  const TrippingTab({
    super.key,
    required this.currentUser,
    required this.accessibleSubstations,
  });

  @override
  State<TrippingTab> createState() => _TrippingTabState();
}

class _TrippingTabState extends State<TrippingTab>
    with TickerProviderStateMixin {
  bool _isLoading = true;

  // Configuration
  Substation? _selectedSubstation;
  DateTime? _startDate;
  DateTime? _endDate;

  // Cache for data persistence
  Map<String, List<Bay>> _bayCache = {};
  Map<String, List<String>> _selectedBayCache = {};

  // Data
  Map<String, List<TrippingShutdownEntry>> _groupedEntriesByBayType = {};
  List<String> _sortedBayTypes = [];
  Map<String, Bay> _baysMap = {};
  Map<String, Substation> _substationsMap = {};
  Map<String, String> _substationNamesCache = {};

  // Filter States
  List<String> _selectedFilterBayIds = [];
  List<String> _selectedFilterBayTypes = [];
  List<String> _selectedFilterVoltageLevels = [];

  late AnimationController _filterAnimationController;
  late AnimationController _fabAnimationController;

  final List<String> _availableVoltageLevels = [
    '765kV',
    '400kV',
    '220kV',
    '132kV',
    '33kV',
    '11kV',
    '800kV',
    '25kV',
    '400V',
  ];

  final List<String> _availableBayTypes = [
    'Busbar',
    'Transformer',
    'Line',
    'Feeder',
    'Capacitor Bank',
    'Reactor',
    'Bus Coupler',
    'Battery',
  ];

  List<Bay> get _bays {
    if (_selectedSubstation == null) return [];
    return _bayCache[_selectedSubstation!.id] ?? [];
  }

  @override
  void initState() {
    super.initState();
    _startDate = DateTime.now().subtract(const Duration(days: 7));
    _endDate = DateTime.now();

    _filterAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fabAnimationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );

    if (widget.accessibleSubstations.isNotEmpty) {
      _selectedSubstation = widget.accessibleSubstations.first;
      _substationsMap = {
        for (var substation in widget.accessibleSubstations)
          substation.id: substation,
      };
      _initializeData();
    } else {
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _filterAnimationController.dispose();
    _fabAnimationController.dispose();
    super.dispose();
  }

  Future<void> _initializeData() async {
    if (_selectedSubstation != null) {
      await _fetchBaysForSelectedSubstation();
      await _fetchTrippingShutdownEvents();
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
        _selectedFilterBayIds = List.from(
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
          _selectedFilterBayIds = List.from(
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

  Future<String> _getSubstationName(String substationId) async {
    if (_substationNamesCache.containsKey(substationId)) {
      return _substationNamesCache[substationId]!;
    }

    if (_substationsMap.containsKey(substationId)) {
      final name = _substationsMap[substationId]!.name;
      _substationNamesCache[substationId] = name;
      return name;
    }

    try {
      final substationDoc = await FirebaseFirestore.instance
          .collection('substations')
          .doc(substationId)
          .get();

      if (substationDoc.exists) {
        final name = substationDoc.data()?['name'] ?? 'Unknown Substation';
        _substationNamesCache[substationId] = name;
        return name;
      }
    } catch (e) {
      print('Error fetching substation name: $e');
    }

    _substationNamesCache[substationId] = 'Unknown Substation';
    return 'Unknown Substation';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDarkMode
          ? const Color(0xFF1C1C1E) // Dark mode background
          : const Color(0xFFF8F9FA),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildConfigurationSection(theme, isDarkMode),
            const SizedBox(height: 16),
            _buildSearchButton(theme, isDarkMode),
            const SizedBox(height: 16),
            if (_hasActiveFilters())
              _buildActiveFiltersChips(theme, isDarkMode),
            _buildContent(theme, isDarkMode),
          ],
        ),
      ),
    );
  }

  Widget _buildConfigurationSection(ThemeData theme, bool isDarkMode) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDarkMode
            ? const Color(0xFF2C2C2E) // Dark elevated surface
            : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: isDarkMode
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
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.warning,
                  color: Colors.orange,
                  size: 16,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Find Trippings & Shutdowns',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: isDarkMode
                        ? Colors.white
                        : theme.colorScheme.onSurface,
                  ),
                ),
              ),
              IconButton(
                onPressed: _showFilterDialog,
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _hasActiveFilters()
                        ? theme.colorScheme.primary.withOpacity(0.1)
                        : Colors.grey.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.filter_list,
                    color: _hasActiveFilters()
                        ? theme.colorScheme.primary
                        : Colors.grey.shade600,
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                flex: 1,
                child: _buildSubstationSelector(theme, isDarkMode),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 1,
                child: _buildDateRangeSelector(theme, isDarkMode),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSubstationSelector(ThemeData theme, bool isDarkMode) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Select Substation',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: isDarkMode ? Colors.white : theme.colorScheme.onSurface,
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
              dropdownColor: isDarkMode
                  ? const Color(0xFF2C2C2E)
                  : Colors.white,
              items: widget.accessibleSubstations.map((substation) {
                return DropdownMenuItem(
                  value: substation,
                  child: Text(
                    substation.name,
                    style: TextStyle(
                      fontSize: 14,
                      color: isDarkMode ? Colors.white : null,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              }).toList(),
              onChanged: (Substation? newValue) {
                if (newValue != null &&
                    newValue.id != _selectedSubstation?.id) {
                  if (_selectedSubstation != null) {
                    _selectedBayCache[_selectedSubstation!.id] = List.from(
                      _selectedFilterBayIds,
                    );
                  }

                  setState(() {
                    _selectedSubstation = newValue;
                    _selectedFilterBayIds = List.from(
                      _selectedBayCache[newValue.id] ?? [],
                    );
                    _clearFilters();
                  });

                  _fetchBaysForSelectedSubstation();
                }
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
                  color: isDarkMode ? Colors.white : null,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDateRangeSelector(ThemeData theme, bool isDarkMode) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Date Range',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: isDarkMode ? Colors.white : theme.colorScheme.onSurface,
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
      });
    }
  }

  Widget _buildSearchButton(ThemeData theme, bool isDarkMode) {
    final bool canSearch =
        _selectedSubstation != null && _startDate != null && _endDate != null;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SizedBox(
        width: double.infinity,
        height: 48,
        child: ElevatedButton.icon(
          onPressed: canSearch ? _fetchTrippingShutdownEvents : null,
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
              : const Icon(Icons.search, size: 18),
          label: Text(
            _isLoading ? 'Searching...' : 'Search Events',
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
          ),
        ),
      ),
    );
  }

  Widget _buildActiveFiltersChips(ThemeData theme, bool isDarkMode) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Active Filters:',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: isDarkMode
                  ? Colors.white.withOpacity(0.6)
                  : Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              ..._selectedFilterVoltageLevels.map(
                (level) => _buildFilterChip('Voltage: $level', isDarkMode),
              ),
              ..._selectedFilterBayTypes.map(
                (type) => _buildFilterChip('Type: $type', isDarkMode),
              ),
              if (_selectedFilterBayIds.isNotEmpty)
                _buildFilterChip(
                  '${_selectedFilterBayIds.length} specific bay(s)',
                  isDarkMode,
                ),
              _buildClearFiltersChip(isDarkMode),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, bool isDarkMode) {
    return Chip(
      label: Text(label, style: const TextStyle(fontSize: 11)),
      backgroundColor: isDarkMode
          ? Colors.blue.withOpacity(0.2)
          : Colors.blue.shade50,
      side: BorderSide(color: Colors.blue.shade200),
      labelStyle: TextStyle(color: Colors.blue.shade700),
    );
  }

  Widget _buildClearFiltersChip(bool isDarkMode) {
    return InkWell(
      onTap: _clearAllFilters,
      child: Chip(
        label: const Text('Clear All', style: TextStyle(fontSize: 11)),
        backgroundColor: isDarkMode
            ? Colors.red.withOpacity(0.2)
            : Colors.red.shade50,
        side: BorderSide(color: Colors.red.shade200),
        labelStyle: TextStyle(color: Colors.red.shade700),
        deleteIcon: Icon(Icons.clear, size: 16, color: Colors.red.shade700),
        onDeleted: _clearAllFilters,
      ),
    );
  }

  Widget _buildContent(ThemeData theme, bool isDarkMode) {
    if (_isLoading) {
      return Container(
        padding: const EdgeInsets.all(40),
        child: _buildLoadingState(isDarkMode),
      );
    }

    if (widget.accessibleSubstations.isEmpty) {
      return _buildNoSubstationsState(theme, isDarkMode);
    }

    if (_groupedEntriesByBayType.isEmpty) {
      return _buildNoEventsState(theme, isDarkMode);
    }

    return Column(
      children: [
        _buildResultsHeader(theme, isDarkMode),
        const SizedBox(height: 16),
        _buildEventsList(theme, isDarkMode),
      ],
    );
  }

  Widget _buildResultsHeader(ThemeData theme, bool isDarkMode) {
    final totalEvents = _groupedEntriesByBayType.values
        .expand((events) => events)
        .length;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDarkMode
            ? const Color(0xFF2C2C2E) // Dark elevated surface
            : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: isDarkMode
                ? Colors.black.withOpacity(0.3)
                : Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Icon(Icons.list_alt, color: Colors.green, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Events for ${_selectedSubstation?.name ?? ''}',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: isDarkMode
                        ? Colors.white
                        : theme.colorScheme.onSurface,
                  ),
                ),
                Text(
                  '$totalEvents events found',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDarkMode
                        ? Colors.white.withOpacity(0.6)
                        : Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          if (totalEvents > 0)
            ElevatedButton.icon(
              onPressed: _exportToExcel,
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

  Widget _buildLoadingState(bool isDarkMode) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(
            'Loading events...',
            style: TextStyle(color: isDarkMode ? Colors.white : null),
          ),
        ],
      ),
    );
  }

  Widget _buildNoSubstationsState(ThemeData theme, bool isDarkMode) {
    return Container(
      margin: const EdgeInsets.all(32),
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: isDarkMode
            ? const Color(0xFF2C2C2E) // Dark elevated surface
            : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: isDarkMode
                ? Colors.black.withOpacity(0.3)
                : Colors.black.withOpacity(0.05),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.location_off,
            size: 64,
            color: isDarkMode
                ? Colors.white.withOpacity(0.4)
                : Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            'No Substations Found',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: isDarkMode ? Colors.white : theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'No accessible substations found. Please contact your administrator.',
            style: TextStyle(
              fontSize: 14,
              color: isDarkMode
                  ? Colors.white.withOpacity(0.6)
                  : Colors.grey.shade600,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildNoEventsState(ThemeData theme, bool isDarkMode) {
    return Container(
      margin: const EdgeInsets.all(32),
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: isDarkMode
            ? const Color(0xFF2C2C2E) // Dark elevated surface
            : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: isDarkMode
                ? Colors.black.withOpacity(0.3)
                : Colors.black.withOpacity(0.05),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.event_available,
            size: 64,
            color: isDarkMode
                ? Colors.white.withOpacity(0.4)
                : Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            'No Events Found',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: isDarkMode ? Colors.white : theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _hasActiveFilters()
                ? 'No tripping or shutdown events found with the applied filters.'
                : 'No tripping or shutdown events recorded for the selected period.',
            style: TextStyle(
              fontSize: 14,
              color: isDarkMode
                  ? Colors.white.withOpacity(0.6)
                  : Colors.grey.shade600,
            ),
            textAlign: TextAlign.center,
          ),
          if (_hasActiveFilters()) ...[
            const SizedBox(height: 16),
            TextButton(
              onPressed: _clearAllFilters,
              child: const Text('Clear Filters'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEventsList(ThemeData theme, bool isDarkMode) {
    return Column(
      children: _sortedBayTypes.map((bayType) {
        final entries = _groupedEntriesByBayType[bayType]!;
        return _buildBayTypeGroup(theme, bayType, entries, isDarkMode);
      }).toList(),
    );
  }

  Widget _buildBayTypeGroup(
    ThemeData theme,
    String bayType,
    List<TrippingShutdownEntry> entries,
    bool isDarkMode,
  ) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      decoration: BoxDecoration(
        color: isDarkMode
            ? const Color(0xFF2C2C2E) // Dark elevated surface
            : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: isDarkMode
                ? Colors.black.withOpacity(0.3)
                : Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Theme(
        data: theme.copyWith(
          dividerColor: isDarkMode ? Colors.white.withOpacity(0.1) : null,
          listTileTheme: ListTileThemeData(
            iconColor: isDarkMode ? Colors.white : null,
            textColor: isDarkMode ? Colors.white : null,
          ),
        ),
        child: ExpansionTile(
          initiallyExpanded: true,
          title: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: _getBayTypeColor(bayType).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  _getBayTypeIcon(bayType),
                  color: _getBayTypeColor(bayType),
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '$bayType Events',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: isDarkMode ? Colors.white : null,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _getBayTypeColor(bayType).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${entries.length}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _getBayTypeColor(bayType),
                  ),
                ),
              ),
            ],
          ),
          children: entries
              .map((entry) => _buildEventCard(theme, entry, isDarkMode))
              .toList(),
        ),
      ),
    );
  }

  Widget _buildEventCard(
    ThemeData theme,
    TrippingShutdownEntry entry,
    bool isDarkMode,
  ) {
    final isOpen = entry.status == 'OPEN';
    final statusColor = isOpen ? Colors.orange : Colors.green;
    final statusIcon = isOpen ? Icons.hourglass_empty : Icons.check_circle;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF3C3C3E) : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDarkMode
              ? Colors.white.withOpacity(0.1)
              : Colors.grey.shade200,
        ),
      ),
      child: Column(
        children: [
          ListTile(
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(statusIcon, color: statusColor, size: 20),
            ),
            title: Text(
              '${entry.eventType} - ${entry.bayName}',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: isDarkMode ? Colors.white : null,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _substationsMap[entry.substationId]?.name ??
                      'Unknown Substation',
                  style: TextStyle(
                    color: isDarkMode
                        ? Colors.white.withOpacity(0.6)
                        : Colors.grey.shade600,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Start: ${DateFormat('dd.MMM.yyyy HH:mm').format(entry.startTime.toDate())}',
                  style: TextStyle(
                    color: isDarkMode
                        ? Colors.white.withOpacity(0.6)
                        : Colors.grey.shade600,
                    fontSize: 12,
                  ),
                ),
                if (!isOpen && entry.endTime != null)
                  Text(
                    'End: ${DateFormat('dd.MMM.yyyy HH:mm').format(entry.endTime!.toDate())}',
                    style: TextStyle(
                      color: isDarkMode
                          ? Colors.white.withOpacity(0.6)
                          : Colors.grey.shade600,
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
            trailing: PopupMenuButton<String>(
              onSelected: (value) => _handleEventAction(value, entry),
              color: isDarkMode ? const Color(0xFF2C2C2E) : Colors.white,
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'view',
                  child: ListTile(
                    leading: const Icon(Icons.visibility, size: 20),
                    title: Text(
                      'View Details',
                      style: TextStyle(
                        fontSize: 14,
                        color: isDarkMode ? Colors.white : null,
                      ),
                    ),
                    dense: true,
                  ),
                ),
                if (isOpen && _canEditEvents()) ...[
                  PopupMenuItem(
                    value: 'close',
                    child: ListTile(
                      leading: const Icon(Icons.check_circle_outline, size: 20),
                      title: Text(
                        'Close Event',
                        style: TextStyle(
                          fontSize: 14,
                          color: isDarkMode ? Colors.white : null,
                        ),
                      ),
                      dense: true,
                    ),
                  ),
                  PopupMenuItem(
                    value: 'edit',
                    child: ListTile(
                      leading: const Icon(Icons.edit, size: 20),
                      title: Text(
                        'Edit Event',
                        style: TextStyle(
                          fontSize: 14,
                          color: isDarkMode ? Colors.white : null,
                        ),
                      ),
                      dense: true,
                    ),
                  ),
                ],
                if (_canDeleteEvents())
                  PopupMenuItem(
                    value: 'delete',
                    child: ListTile(
                      leading: Icon(
                        Icons.delete,
                        size: 20,
                        color: Colors.red.shade600,
                      ),
                      title: Text(
                        'Delete Event',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.red.shade600,
                        ),
                      ),
                      dense: true,
                    ),
                  ),
              ],
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isDarkMode ? const Color(0xFF2C2C2E) : Colors.white,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: isDarkMode
                        ? Colors.white.withOpacity(0.2)
                        : Colors.grey.shade300,
                  ),
                ),
                child: Icon(
                  Icons.more_vert,
                  size: 16,
                  color: isDarkMode
                      ? Colors.white.withOpacity(0.6)
                      : Colors.grey.shade600,
                ),
              ),
            ),
            onTap: () => _viewEventDetails(entry),
          ),
          if (entry.reasonForNonFeeder != null &&
              entry.reasonForNonFeeder!.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDarkMode
                    ? Colors.blue.withOpacity(0.1)
                    : Colors.blue.shade50,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(8),
                  bottomRight: Radius.circular(8),
                ),
              ),
              child: Text(
                'Reason: ${entry.reasonForNonFeeder}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.blue.shade700,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // Helper methods
  bool _hasActiveFilters() {
    return _selectedFilterVoltageLevels.isNotEmpty ||
        _selectedFilterBayTypes.isNotEmpty ||
        _selectedFilterBayIds.isNotEmpty;
  }

  bool _canEditEvents() {
    return widget.currentUser.role == UserRole.subdivisionManager ||
        widget.currentUser.role == UserRole.admin;
  }

  bool _canDeleteEvents() {
    return widget.currentUser.role == UserRole.subdivisionManager ||
        widget.currentUser.role == UserRole.admin;
  }

  Color _getBayTypeColor(String bayType) {
    switch (bayType.toLowerCase()) {
      case 'transformer':
        return Colors.orange;
      case 'line':
        return Colors.blue;
      case 'feeder':
        return Colors.green;
      case 'busbar':
        return Colors.purple;
      case 'capacitor bank':
        return Colors.indigo;
      default:
        return Colors.grey;
    }
  }

  IconData _getBayTypeIcon(String bayType) {
    switch (bayType.toLowerCase()) {
      case 'transformer':
        return Icons.transform;
      case 'line':
        return Icons.timeline;
      case 'feeder':
        return Icons.power;
      case 'busbar':
        return Icons.view_stream;
      case 'capacitor bank':
        return Icons.battery_full;
      default:
        return Icons.electrical_services;
    }
  }

  void _clearFilters() {
    _selectedFilterVoltageLevels.clear();
    _selectedFilterBayTypes.clear();
    // Don't clear bay IDs here as they are managed separately
  }

  void _clearAllFilters() {
    setState(() {
      _selectedFilterVoltageLevels.clear();
      _selectedFilterBayTypes.clear();
      _selectedFilterBayIds.clear();
      if (_selectedSubstation != null) {
        _selectedBayCache[_selectedSubstation!.id] = List.from(
          _selectedFilterBayIds,
        );
      }
    });
    _fetchTrippingShutdownEvents();
  }

  void _handleEventAction(String action, TrippingShutdownEntry entry) {
    switch (action) {
      case 'view':
        _viewEventDetails(entry);
        break;
      case 'close':
      case 'edit':
        _editEvent(entry);
        break;
      case 'delete':
        _confirmDeleteEntry(entry.id!, entry.eventType, entry.bayName);
        break;
    }
  }

  // Navigation methods
  void _viewEventDetails(TrippingShutdownEntry entry) async {
    final substationName = await _getSubstationName(entry.substationId);

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) =>
            TrippingDetailsScreen(entry: entry, substationName: substationName),
      ),
    );
  }

  void _editEvent(TrippingShutdownEntry entry) async {
    final substationName = await _getSubstationName(entry.substationId);

    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (context) => TrippingShutdownEntryScreen(
              substationId: entry.substationId,
              substationName: substationName,
              currentUser: widget.currentUser,
              entryToEdit: entry,
              isViewOnly: false,
            ),
          ),
        )
        .then((_) => _fetchTrippingShutdownEvents());
  }

  void _createNewEvent() async {
    if (widget.accessibleSubstations.isEmpty) {
      SnackBarUtils.showSnackBar(
        context,
        'No substations available to create an event.',
        isError: true,
      );
      return;
    }

    final defaultSubstation =
        _selectedSubstation ?? widget.accessibleSubstations.first;
    final substationName = await _getSubstationName(defaultSubstation.id);

    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (context) => TrippingShutdownEntryScreen(
              substationId: defaultSubstation.id,
              substationName: substationName,
              currentUser: widget.currentUser,
              isViewOnly: false,
            ),
          ),
        )
        .then((_) => _fetchTrippingShutdownEvents());
  }

  // Filter dialog
  Future<void> _showFilterDialog() async {
    await showDialog(
      context: context,
      builder: (context) => _FilterDialog(
        selectedVoltageLevels: _selectedFilterVoltageLevels,
        selectedBayTypes: _selectedFilterBayTypes,
        selectedBayIds: _selectedFilterBayIds,
        availableVoltageLevels: _availableVoltageLevels,
        availableBayTypes: _availableBayTypes,
        allBaysInSubdivisionList: _bays,
        baysMap: _baysMap,
        onApplyFilters: (voltageLevels, bayTypes, bayIds) {
          setState(() {
            _selectedFilterVoltageLevels = voltageLevels;
            _selectedFilterBayTypes = bayTypes;
            _selectedFilterBayIds = bayIds;
            if (_selectedSubstation != null) {
              _selectedBayCache[_selectedSubstation!.id] = List.from(
                _selectedFilterBayIds,
              );
            }
          });
          _fetchTrippingShutdownEvents();
        },
      ),
    );
  }

  // Data fetching
  Future<void> _fetchTrippingShutdownEvents() async {
    if (_selectedSubstation == null || _startDate == null || _endDate == null) {
      setState(() {
        _groupedEntriesByBayType = {};
        _sortedBayTypes = [];
      });
      return;
    }

    setState(() => _isLoading = true);

    try {
      Query query = FirebaseFirestore.instance.collection(
        'trippingShutdownEntries',
      );

      query = query.where('substationId', isEqualTo: _selectedSubstation!.id);

      query = query
          .where(
            'startTime',
            isGreaterThanOrEqualTo: Timestamp.fromDate(_startDate!),
          )
          .where(
            'startTime',
            isLessThanOrEqualTo: Timestamp.fromDate(
              _endDate!.add(const Duration(days: 1)),
            ),
          );

      query = query.orderBy('startTime', descending: true);

      final eventsSnapshot = await query.get();
      List<TrippingShutdownEntry> allEvents = eventsSnapshot.docs
          .map((doc) => TrippingShutdownEntry.fromFirestore(doc))
          .toList();

      // Apply additional filters
      if (_selectedFilterBayIds.isNotEmpty) {
        allEvents = allEvents
            .where((event) => _selectedFilterBayIds.contains(event.bayId))
            .toList();
      }

      if (_selectedFilterBayTypes.isNotEmpty) {
        allEvents = allEvents.where((event) {
          final bay = _baysMap[event.bayId];
          return bay != null && _selectedFilterBayTypes.contains(bay.bayType);
        }).toList();
      }

      if (_selectedFilterVoltageLevels.isNotEmpty) {
        allEvents = allEvents.where((event) {
          final bay = _baysMap[event.bayId];
          return bay != null &&
              _selectedFilterVoltageLevels.contains(bay.voltageLevel);
        }).toList();
      }

      // Group by bay type
      _groupedEntriesByBayType = {};
      for (var event in allEvents) {
        final bay = _baysMap[event.bayId];
        final bayType = bay?.bayType ?? 'Unknown';

        _groupedEntriesByBayType.putIfAbsent(bayType, () => []).add(event);
      }

      // Sort bay types
      _sortedBayTypes = _groupedEntriesByBayType.keys.toList()..sort();

      if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      print('Error fetching events: $e');
      if (mounted) {
        SnackBarUtils.showSnackBar(
          context,
          'Error loading events: $e',
          isError: true,
        );
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _confirmDeleteEntry(
    String entryId,
    String eventType,
    String bayName,
  ) async {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDarkMode ? const Color(0xFF1C1C1E) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Row(
          children: [
            Icon(Icons.warning, color: Colors.red.shade600),
            const SizedBox(width: 8),
            Text(
              'Confirm Delete',
              style: TextStyle(color: isDarkMode ? Colors.white : null),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to delete this $eventType event for $bayName?\n\nThis action cannot be undone.',
          style: TextStyle(color: isDarkMode ? Colors.white : null),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await FirebaseFirestore.instance
            .collection('trippingShutdownEntries')
            .doc(entryId)
            .delete();

        if (mounted) {
          SnackBarUtils.showSnackBar(context, 'Event deleted successfully.');
          _fetchTrippingShutdownEvents();
        }
      } catch (e) {
        if (mounted) {
          SnackBarUtils.showSnackBar(
            context,
            'Error deleting event: $e',
            isError: true,
          );
        }
      }
    }
  }

  // Excel Export - Updated _exportToExcel method in TrippingTab
  Future<void> _exportToExcel() async {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

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
        builder: (context) => Center(
          child: Card(
            color: isDarkMode ? const Color(0xFF1C1C1E) : Colors.white,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(
                    'Generating Excel file...',
                    style: TextStyle(color: isDarkMode ? Colors.white : null),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      var excel = Excel.createExcel();
      excel.delete('Sheet1');

      // Collect all events
      final allEvents = _groupedEntriesByBayType.values
          .expand((events) => events)
          .toList();

      // Group by bay type for separate sheets
      Map<String, List<TrippingShutdownEntry>> eventsByBayType = {};
      for (var event in allEvents) {
        final bay = _baysMap[event.bayId];
        final bayType = bay?.bayType ?? 'Unknown';
        eventsByBayType.putIfAbsent(bayType, () => []);
        eventsByBayType[bayType]!.add(event);
      }

      eventsByBayType.forEach((bayType, events) {
        var sheet = excel[bayType];

        // Complete list of headers based on the model
        List<String> headers = [
          'Event Type',
          'Bay Name',
          'Bay Type',
          'Voltage Level',
          'Substation',
          'Start Time',
          'End Time',
          'Duration (Hours)',
          'Status',
          'Flags/Cause',
          'Reason for Non-Feeder',
          'Has Auto Reclose',
          'Phase Faults',
          'Distance',
          'Shutdown Type',
          'Shutdown Person Name',
          'Shutdown Person Designation',
          'Created By',
          'Created At',
          'Closed By',
          'Closed At',
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

        events.sort((a, b) => b.startTime.compareTo(a.startTime));

        for (var event in events) {
          final bay = _baysMap[event.bayId];
          final substation = _substationsMap[event.substationId];

          Duration? duration;
          if (event.endTime != null) {
            duration = event.endTime!.toDate().difference(
              event.startTime.toDate(),
            );
          }

          List<dynamic> rowData = [
            event.eventType,
            event.bayName,
            bay?.bayType ?? 'Unknown',
            bay?.voltageLevel ?? 'Unknown',
            substation?.name ?? 'Unknown',
            DateFormat(
              'yyyy-MM-dd HH:mm:ss',
            ).format(event.startTime.toDate().toLocal()),
            event.endTime != null
                ? DateFormat(
                    'yyyy-MM-dd HH:mm:ss',
                  ).format(event.endTime!.toDate().toLocal())
                : 'Ongoing',
            duration != null
                ? '${duration.inHours}.${((duration.inMinutes % 60) / 60 * 100).round()}'
                : 'Ongoing',
            event.status,
            event.flagsCause,
            event.reasonForNonFeeder ?? '',
            event.hasAutoReclose?.toString() ?? '',
            event.phaseFaults?.join(', ') ?? '',
            event.distance ?? '',
            event.shutdownType ?? '',
            event.shutdownPersonName ?? '',
            event.shutdownPersonDesignation ?? '',
            event.createdBy,
            DateFormat(
              'yyyy-MM-dd HH:mm:ss',
            ).format(event.createdAt.toDate().toLocal()),
            event.closedBy ?? '',
            event.closedAt != null
                ? DateFormat(
                    'yyyy-MM-dd HH:mm:ss',
                  ).format(event.closedAt!.toDate().toLocal())
                : '',
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

            // Color-code status column
            if (i == 8) {
              // Status column
              if (event.status == 'OPEN') {
                cell.cellStyle = CellStyle(
                  backgroundColorHex: ExcelColor.fromHexString('#FFF3CD'),
                );
              } else {
                cell.cellStyle = CellStyle(
                  backgroundColorHex: ExcelColor.fromHexString('#D4EDDA'),
                );
              }
            }

            // Color-code event type column
            if (i == 0) {
              // Event Type column
              if (event.eventType == 'Tripping') {
                cell.cellStyle = CellStyle(
                  backgroundColorHex: ExcelColor.fromHexString('#F8D7DA'),
                );
              } else if (event.eventType == 'Shutdown') {
                cell.cellStyle = CellStyle(
                  backgroundColorHex: ExcelColor.fromHexString('#D1ECF1'),
                );
              }
            }
          }
          rowIndex++;
        }

        // Set column widths for better readability
        List<double> columnWidths = [
          12, // Event Type
          15, // Bay Name
          12, // Bay Type
          12, // Voltage Level
          15, // Substation
          18, // Start Time
          18, // End Time
          12, // Duration
          10, // Status
          25, // Flags/Cause
          20, // Reason for Non-Feeder
          12, // Has Auto Reclose
          15, // Phase Faults
          10, // Distance
          15, // Shutdown Type
          20, // Shutdown Person Name
          25, // Shutdown Person Designation
          15, // Created By
          18, // Created At
          15, // Closed By
          18, // Closed At
        ];

        for (int i = 0; i < columnWidths.length && i < headers.length; i++) {
          sheet.setColumnWidth(i, columnWidths[i]);
        }

        // Add summary row with metadata
        sheet.insertRowIterables([
          TextCellValue('Bay Type: $bayType'),
          TextCellValue(''),
          TextCellValue('Total Events: ${events.length}'),
          TextCellValue(''),
          TextCellValue(
            'Open Events: ${events.where((e) => e.status == 'OPEN').length}',
          ),
          TextCellValue(''),
          TextCellValue(
            'Closed Events: ${events.where((e) => e.status == 'CLOSED').length}',
          ),
          TextCellValue(''),
          TextCellValue(
            'Date Range: ${DateFormat('yyyy-MM-dd').format(_startDate!)} to ${DateFormat('yyyy-MM-dd').format(_endDate!)}',
          ),
        ], 0);

        // Style summary row
        for (int i = 0; i < 9; i++) {
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
          'tripping_events_complete_${_selectedSubstation?.name.replaceAll(' ', '_')}_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.xlsx';
      final file = File('${directory.path}/$fileName');

      await file.writeAsBytes(excel.encode()!);

      Navigator.of(context).pop();

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: isDarkMode ? const Color(0xFF1C1C1E) : Colors.white,
          title: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.green),
              const SizedBox(width: 8),
              Text(
                'Export Successful',
                style: TextStyle(color: isDarkMode ? Colors.white : null),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'File saved as: $fileName',
                style: TextStyle(color: isDarkMode ? Colors.white : null),
              ),
              const SizedBox(height: 8),
              Text(
                'Location: ${directory.path}',
                style: TextStyle(color: isDarkMode ? Colors.white : null),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDarkMode
                      ? Colors.blue.withOpacity(0.1)
                      : Colors.blue.shade50,
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
                            'Complete Export Details:',
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
                      '• All model fields included varied header length columns)\n• Separate sheets by bay type\n• Status and event type color-coding\n• Summary statistics per sheet\n• Proper duration calculations',
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
}

// Filter Dialog
class _FilterDialog extends StatefulWidget {
  final List<String> selectedVoltageLevels;
  final List<String> selectedBayTypes;
  final List<String> selectedBayIds;
  final List<String> availableVoltageLevels;
  final List<String> availableBayTypes;
  final List<Bay> allBaysInSubdivisionList;
  final Map<String, Bay> baysMap;
  final Function(List<String>, List<String>, List<String>) onApplyFilters;

  const _FilterDialog({
    required this.selectedVoltageLevels,
    required this.selectedBayTypes,
    required this.selectedBayIds,
    required this.availableVoltageLevels,
    required this.availableBayTypes,
    required this.allBaysInSubdivisionList,
    required this.baysMap,
    required this.onApplyFilters,
  });

  @override
  State<_FilterDialog> createState() => _FilterDialogState();
}

class _FilterDialogState extends State<_FilterDialog> {
  late List<String> tempSelectedVoltageLevels;
  late List<String> tempSelectedBayTypes;
  late List<String> tempSelectedBayIds;

  @override
  void initState() {
    super.initState();
    tempSelectedVoltageLevels = List.from(widget.selectedVoltageLevels);
    tempSelectedBayTypes = List.from(widget.selectedBayTypes);
    tempSelectedBayIds = List.from(widget.selectedBayIds);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return Dialog(
      backgroundColor: isDarkMode ? const Color(0xFF1C1C1E) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        width: double.maxFinite,
        height: 500,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 16, 16),
              decoration: BoxDecoration(
                color: isDarkMode
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
                      'Filter Events',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: isDarkMode
                            ? Colors.white
                            : theme.colorScheme.primary,
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
                        color: isDarkMode
                            ? Colors.white
                            : theme.colorScheme.onSurface.withOpacity(0.7),
                      ),
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
                    _buildMultiSelectSection(
                      'Voltage Levels',
                      widget.availableVoltageLevels,
                      tempSelectedVoltageLevels,
                      (level) => level,
                      (selected) =>
                          setState(() => tempSelectedVoltageLevels = selected),
                      isDarkMode,
                    ),
                    const SizedBox(height: 16),
                    _buildMultiSelectSection(
                      'Bay Types',
                      widget.availableBayTypes,
                      tempSelectedBayTypes,
                      (type) => type,
                      (selected) =>
                          setState(() => tempSelectedBayTypes = selected),
                      isDarkMode,
                    ),
                    const SizedBox(height: 16),
                    _buildMultiSelectSection(
                      'Specific Bays',
                      widget.allBaysInSubdivisionList.map((b) => b.id).toList(),
                      tempSelectedBayIds,
                      (id) => widget.baysMap[id]?.name ?? 'Unknown',
                      (selected) =>
                          setState(() => tempSelectedBayIds = selected),
                      isDarkMode,
                    ),
                  ],
                ),
              ),
            ),
            Divider(
              height: 1,
              color: isDarkMode ? Colors.white.withOpacity(0.1) : null,
            ),
            Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  TextButton(
                    onPressed: () {
                      setState(() {
                        tempSelectedVoltageLevels.clear();
                        tempSelectedBayTypes.clear();
                        tempSelectedBayIds.clear();
                      });
                    },
                    child: const Text('Clear All'),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () {
                      widget.onApplyFilters(
                        tempSelectedVoltageLevels,
                        tempSelectedBayTypes,
                        tempSelectedBayIds,
                      );
                      Navigator.of(context).pop();
                    },
                    child: const Text('Apply'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMultiSelectSection(
    String title,
    List<String> items,
    List<String> selected,
    String Function(String) itemToString,
    Function(List<String>) onChanged,
    bool isDarkMode,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: isDarkMode ? Colors.white : null,
              ),
            ),
            const Spacer(),
            if (items.isNotEmpty)
              TextButton(
                onPressed: () {
                  final newSelected = selected.length == items.length
                      ? <String>[]
                      : List<String>.from(items);
                  onChanged(newSelected);
                },
                child: Text(
                  selected.length == items.length
                      ? 'Deselect All'
                      : 'Select All',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            border: Border.all(
              color: isDarkMode
                  ? Colors.white.withOpacity(0.2)
                  : Colors.grey.shade300,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: items.take(5).map((item) {
              final isSelected = selected.contains(item);
              return Container(
                decoration: BoxDecoration(
                  color: isDarkMode ? const Color(0xFF2C2C2E) : Colors.white,
                  border: Border(
                    bottom: BorderSide(
                      color: isDarkMode
                          ? Colors.white.withOpacity(0.1)
                          : Colors.grey.shade200,
                      width: 0.5,
                    ),
                  ),
                ),
                child: CheckboxListTile(
                  dense: true,
                  title: Text(
                    itemToString(item),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: isSelected
                          ? FontWeight.w500
                          : FontWeight.normal,
                      color: isDarkMode ? Colors.white : null,
                    ),
                  ),
                  value: isSelected,
                  onChanged: (bool? value) {
                    final newSelected = List<String>.from(selected);
                    if (value == true) {
                      newSelected.add(item);
                    } else {
                      newSelected.remove(item);
                    }
                    onChanged(newSelected);
                  },
                  controlAffinity: ListTileControlAffinity.leading,
                ),
              );
            }).toList(),
          ),
        ),
        if (items.length > 5)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              '${items.length - 5} more items available',
              style: TextStyle(
                fontSize: 12,
                color: isDarkMode
                    ? Colors.white.withOpacity(0.6)
                    : Colors.grey.shade600,
              ),
            ),
          ),
      ],
    );
  }
}

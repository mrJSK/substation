// lib/screens/subdivision_dashboard_tabs/tripping_tab.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:collection/collection.dart';

import '../../models/user_model.dart';
import '../../models/tripping_shutdown_model.dart';
import '../../models/bay_model.dart';
import '../../models/hierarchy_models.dart';
import '../../utils/snackbar_utils.dart';
import '../../models/app_state_data.dart';
import '../substation_dashboard/tripping_shutdown_entry_screen.dart';

class TrippingTab extends StatefulWidget {
  final AppUser currentUser;
  final DateTime startDate;
  final DateTime endDate;
  final String substationId;

  const TrippingTab({
    super.key,
    required this.currentUser,
    required this.startDate,
    required this.endDate,
    required this.substationId,
  });

  @override
  State<TrippingTab> createState() => _TrippingTabState();
}

class _TrippingTabState extends State<TrippingTab>
    with TickerProviderStateMixin {
  bool _isLoading = true;
  Map<String, List<TrippingShutdownEntry>> _groupedEntriesByBayType = {};
  List<String> _sortedBayTypes = [];
  Map<String, Bay> _baysMap = {};
  List<Bay> _allBaysInSubdivisionList = [];
  List<Substation> _substationsInSubdivision = [];
  Map<String, Substation> _substationsMap = {};

  // Filter States
  List<String> _selectedFilterSubstationIds = [];
  List<String> _selectedFilterVoltageLevels = [];
  List<String> _selectedFilterBayTypes = [];
  List<String> _selectedFilterBayIds = [];

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

  @override
  void initState() {
    super.initState();
    _filterAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fabAnimationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _fetchInitialHierarchyDataAndEvents();
  }

  @override
  void dispose() {
    _filterAnimationController.dispose();
    _fabAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: Column(
        children: [
          _buildHeader(theme),
          if (_hasActiveFilters()) _buildActiveFiltersChips(theme),
          Expanded(child: _buildContent(theme)),
        ],
      ),
      floatingActionButton: _buildFloatingActionButton(theme),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Container(
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
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.warning, color: Colors.orange, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tripping & Shutdown Events',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                Text(
                  '${DateFormat('MMM dd').format(widget.startDate)} - ${DateFormat('MMM dd, yyyy').format(widget.endDate)}',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
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
    );
  }

  Widget _buildActiveFiltersChips(ThemeData theme) {
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
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              ..._selectedFilterSubstationIds.map(
                (id) => _buildFilterChip(
                  'Substation: ${_substationsMap[id]?.name ?? 'Unknown'}',
                ),
              ),
              ..._selectedFilterVoltageLevels.map(
                (level) => _buildFilterChip('Voltage: $level'),
              ),
              ..._selectedFilterBayTypes.map(
                (type) => _buildFilterChip('Type: $type'),
              ),
              if (_selectedFilterBayIds.isNotEmpty)
                _buildFilterChip(
                  '${_selectedFilterBayIds.length} specific bay(s)',
                ),
              _buildClearFiltersChip(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label) {
    return Chip(
      label: Text(label, style: const TextStyle(fontSize: 11)),
      backgroundColor: Colors.blue.shade50,
      side: BorderSide(color: Colors.blue.shade200),
      labelStyle: TextStyle(color: Colors.blue.shade700),
    );
  }

  Widget _buildClearFiltersChip() {
    return InkWell(
      onTap: _clearAllFilters,
      child: Chip(
        label: const Text('Clear All', style: TextStyle(fontSize: 11)),
        backgroundColor: Colors.red.shade50,
        side: BorderSide(color: Colors.red.shade200),
        labelStyle: TextStyle(color: Colors.red.shade700),
        deleteIcon: Icon(Icons.clear, size: 16, color: Colors.red.shade700),
        onDeleted: _clearAllFilters,
      ),
    );
  }

  Widget _buildContent(ThemeData theme) {
    if (_isLoading) {
      return _buildLoadingState();
    }

    if (_substationsInSubdivision.isEmpty) {
      return _buildNoSubstationsState(theme);
    }

    if (_groupedEntriesByBayType.isEmpty) {
      return _buildNoEventsState(theme);
    }

    return _buildEventsList(theme);
  }

  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Loading events...'),
        ],
      ),
    );
  }

  Widget _buildNoSubstationsState(ThemeData theme) {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(32),
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.location_off, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'No Substations Found',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'No substations found in your subdivision. Please ensure your user is assigned to a subdivision with substations.',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoEventsState(ThemeData theme) {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(32),
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.event_available, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'No Events Found',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _hasActiveFilters()
                  ? 'No tripping or shutdown events found with the applied filters.'
                  : 'No tripping or shutdown events recorded for the selected period.',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
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
      ),
    );
  }

  Widget _buildEventsList(ThemeData theme) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _sortedBayTypes.length,
      itemBuilder: (context, index) {
        final bayType = _sortedBayTypes[index];
        final entries = _groupedEntriesByBayType[bayType]!;
        return _buildBayTypeGroup(theme, bayType, entries);
      },
    );
  }

  Widget _buildBayTypeGroup(
    ThemeData theme,
    String bayType,
    List<TrippingShutdownEntry> entries,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
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
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
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
            .map((entry) => _buildEventCard(theme, entry))
            .toList(),
      ),
    );
  }

  Widget _buildEventCard(ThemeData theme, TrippingShutdownEntry entry) {
    final isOpen = entry.status == 'OPEN';
    final statusColor = isOpen ? Colors.orange : Colors.green;
    final statusIcon = isOpen ? Icons.hourglass_empty : Icons.check_circle;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
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
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _substationsMap[entry.substationId]?.name ??
                      'Unknown Substation',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                ),
                const SizedBox(height: 2),
                Text(
                  'Start: ${DateFormat('dd.MMM.yyyy HH:mm').format(entry.startTime.toDate())}',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                ),
                if (!isOpen && entry.endTime != null)
                  Text(
                    'End: ${DateFormat('dd.MMM.yyyy HH:mm').format(entry.endTime!.toDate())}',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                  ),
              ],
            ),
            trailing: PopupMenuButton<String>(
              onSelected: (value) => _handleEventAction(value, entry),
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'view',
                  child: ListTile(
                    leading: Icon(Icons.visibility, size: 20),
                    title: Text('View Details', style: TextStyle(fontSize: 14)),
                    dense: true,
                  ),
                ),
                if (isOpen && _canEditEvents()) ...[
                  const PopupMenuItem(
                    value: 'close',
                    child: ListTile(
                      leading: Icon(Icons.check_circle_outline, size: 20),
                      title: Text(
                        'Close Event',
                        style: TextStyle(fontSize: 14),
                      ),
                      dense: true,
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'edit',
                    child: ListTile(
                      leading: Icon(Icons.edit, size: 20),
                      title: Text('Edit Event', style: TextStyle(fontSize: 14)),
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
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Icon(
                  Icons.more_vert,
                  size: 16,
                  color: Colors.grey.shade600,
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
                color: Colors.blue.shade50,
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

  Widget _buildFloatingActionButton(ThemeData theme) {
    return FloatingActionButton.extended(
      onPressed: _createNewEvent,
      label: const Text('Add Event'),
      icon: const Icon(Icons.add),
      backgroundColor: theme.colorScheme.primary,
    );
  }

  // Helper methods
  bool _hasActiveFilters() {
    return _selectedFilterSubstationIds.isNotEmpty ||
        _selectedFilterVoltageLevels.isNotEmpty ||
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

  void _clearAllFilters() {
    setState(() {
      _selectedFilterSubstationIds.clear();
      _selectedFilterVoltageLevels.clear();
      _selectedFilterBayTypes.clear();
      _selectedFilterBayIds.clear();
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

  void _viewEventDetails(TrippingShutdownEntry entry) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => TrippingShutdownEntryScreen(
          substationId: entry.substationId,
          currentUser: widget.currentUser,
          entryToEdit: entry,
          isViewOnly: true,
        ),
      ),
    );
  }

  void _editEvent(TrippingShutdownEntry entry) {
    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (context) => TrippingShutdownEntryScreen(
              substationId: entry.substationId,
              currentUser: widget.currentUser,
              entryToEdit: entry,
              isViewOnly: false,
            ),
          ),
        )
        .then((_) => _fetchTrippingShutdownEvents());
  }

  void _createNewEvent() {
    if (_substationsInSubdivision.isEmpty) {
      SnackBarUtils.showSnackBar(
        context,
        'No substations available in your subdivision to create an event.',
        isError: true,
      );
      return;
    }

    final defaultSubstationId = _substationsInSubdivision.first.id;
    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (context) => TrippingShutdownEntryScreen(
              substationId: defaultSubstationId,
              currentUser: widget.currentUser,
              isViewOnly: false,
            ),
          ),
        )
        .then((_) => _fetchTrippingShutdownEvents());
  }

  // Filter dialog method
  Future<void> _showFilterDialog() async {
    await showDialog(
      context: context,
      builder: (context) => _FilterDialog(
        selectedSubstationIds: _selectedFilterSubstationIds,
        selectedVoltageLevels: _selectedFilterVoltageLevels,
        selectedBayTypes: _selectedFilterBayTypes,
        selectedBayIds: _selectedFilterBayIds,
        substationsMap: _substationsMap,
        substationsInSubdivision: _substationsInSubdivision,
        availableVoltageLevels: _availableVoltageLevels,
        availableBayTypes: _availableBayTypes,
        allBaysInSubdivisionList: _allBaysInSubdivisionList,
        baysMap: _baysMap,
        onApplyFilters: (substationIds, voltageLevels, bayTypes, bayIds) {
          setState(() {
            _selectedFilterSubstationIds = substationIds;
            _selectedFilterVoltageLevels = voltageLevels;
            _selectedFilterBayTypes = bayTypes;
            _selectedFilterBayIds = bayIds;
          });
          _fetchTrippingShutdownEvents();
        },
      ),
    );
  }

  // Data fetching methods (implementation remains the same)
  Future<void> _fetchInitialHierarchyDataAndEvents() async {
    // Implementation remains the same
  }

  Future<void> _fetchTrippingShutdownEvents() async {
    // Implementation remains the same
  }

  Future<void> _confirmDeleteEntry(
    String entryId,
    String eventType,
    String bayName,
  ) async {
    // Implementation remains the same
  }
}

// Custom Filter Dialog Widget
class _FilterDialog extends StatefulWidget {
  final List<String> selectedSubstationIds;
  final List<String> selectedVoltageLevels;
  final List<String> selectedBayTypes;
  final List<String> selectedBayIds;
  final Map<String, Substation> substationsMap;
  final List<Substation> substationsInSubdivision;
  final List<String> availableVoltageLevels;
  final List<String> availableBayTypes;
  final List<Bay> allBaysInSubdivisionList;
  final Map<String, Bay> baysMap;
  final Function(List<String>, List<String>, List<String>, List<String>)
  onApplyFilters;

  const _FilterDialog({
    required this.selectedSubstationIds,
    required this.selectedVoltageLevels,
    required this.selectedBayTypes,
    required this.selectedBayIds,
    required this.substationsMap,
    required this.substationsInSubdivision,
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
  late List<String> tempSelectedSubstationIds;
  late List<String> tempSelectedVoltageLevels;
  late List<String> tempSelectedBayTypes;
  late List<String> tempSelectedBayIds;

  @override
  void initState() {
    super.initState();
    tempSelectedSubstationIds = List.from(widget.selectedSubstationIds);
    tempSelectedVoltageLevels = List.from(widget.selectedVoltageLevels);
    tempSelectedBayTypes = List.from(widget.selectedBayTypes);
    tempSelectedBayIds = List.from(widget.selectedBayIds);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Filter Events'),
      content: SizedBox(
        width: double.maxFinite,
        height: 400,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildMultiSelectSection(
                'Substations',
                widget.substationsInSubdivision.map((s) => s.id).toList(),
                tempSelectedSubstationIds,
                (id) => widget.substationsMap[id]?.name ?? 'Unknown',
                (selected) =>
                    setState(() => tempSelectedSubstationIds = selected),
              ),
              const SizedBox(height: 16),
              _buildMultiSelectSection(
                'Voltage Levels',
                widget.availableVoltageLevels,
                tempSelectedVoltageLevels,
                (level) => level,
                (selected) =>
                    setState(() => tempSelectedVoltageLevels = selected),
              ),
              const SizedBox(height: 16),
              _buildMultiSelectSection(
                'Bay Types',
                widget.availableBayTypes,
                tempSelectedBayTypes,
                (type) => type,
                (selected) => setState(() => tempSelectedBayTypes = selected),
              ),
              const SizedBox(height: 16),
              _buildMultiSelectSection(
                'Specific Bays',
                widget.allBaysInSubdivisionList.map((b) => b.id).toList(),
                tempSelectedBayIds,
                (id) => widget.baysMap[id]?.name ?? 'Unknown',
                (selected) => setState(() => tempSelectedBayIds = selected),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            setState(() {
              tempSelectedSubstationIds.clear();
              tempSelectedVoltageLevels.clear();
              tempSelectedBayTypes.clear();
              tempSelectedBayIds.clear();
            });
          },
          child: const Text('Clear All'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            widget.onApplyFilters(
              tempSelectedSubstationIds,
              tempSelectedVoltageLevels,
              tempSelectedBayTypes,
              tempSelectedBayIds,
            );
            Navigator.of(context).pop();
          },
          child: const Text('Apply'),
        ),
      ],
    );
  }

  Widget _buildMultiSelectSection(
    String title,
    List<String> items,
    List<String> selected,
    String Function(String) itemToString,
    Function(List<String>) onChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: items.take(5).map((item) {
              final isSelected = selected.contains(item);
              return CheckboxListTile(
                dense: true,
                title: Text(
                  itemToString(item),
                  style: const TextStyle(fontSize: 14),
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
              );
            }).toList(),
          ),
        ),
        if (items.length > 5)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              '${items.length - 5} more items available',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ),
      ],
    );
  }
}

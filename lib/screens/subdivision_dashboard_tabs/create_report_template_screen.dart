// lib/screens/generate_custom_report_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:dropdown_search/dropdown_search.dart';
import '../../models/bay_model.dart';
import '../../models/tripping_shutdown_model.dart';

enum ReportMode { summary, export }

enum ExportDataType { operations, tripping, energy, customReports }

class GenerateCustomReportScreen extends StatefulWidget {
  static const routeName = '/generate-custom-report';

  final DateTime startDate;
  final DateTime endDate;

  const GenerateCustomReportScreen({
    super.key,
    required this.startDate,
    required this.endDate,
  });

  @override
  State<GenerateCustomReportScreen> createState() =>
      _GenerateCustomReportScreenState();
}

class _GenerateCustomReportScreenState extends State<GenerateCustomReportScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  ReportMode _currentMode = ReportMode.summary;

  final List<Bay> _availableBays = [];
  Bay? _selectedBay;
  final bool _isLoading = false;
  final bool _isGenerating = false;

  final Map<String, dynamic> _statisticalSummary = {};
  final List<TrippingShutdownEntry> _bayTrippingEvents = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _fetchInitialData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: _isLoading
          ? _buildLoadingState()
          : CustomScrollView(
              slivers: [
                // _buildSliverAppBar(theme),
                SliverToBoxAdapter(child: _buildModeToggle(theme)),
                if (_currentMode == ReportMode.summary)
                  SliverToBoxAdapter(child: _buildBaySelector(theme)),
                SliverToBoxAdapter(child: _buildTabBar(theme)),
                SliverFillRemaining(
                  child: TabBarView(
                    controller: _tabController,
                    children: _currentMode == ReportMode.summary
                        ? [
                            _buildSummaryTab(theme),
                            _buildOperationsTab(theme),
                            _buildTrippingTab(theme),
                            _buildEnergyTab(theme),
                            _buildCustomReportsTab(theme),
                          ]
                        : [
                            _buildOperationsTab(theme),
                            _buildTrippingTab(theme),
                            _buildEnergyTab(theme),
                            _buildCustomReportsTab(theme),
                            _buildBulkExportTab(theme),
                          ],
                  ),
                ),
                const SliverToBoxAdapter(
                  child: SizedBox(height: 80), // Bottom padding
                ),
              ],
            ),
    );
  }

  // Widget _buildSliverAppBar(ThemeData theme) {
  //   return SliverAppBar(
  //     backgroundColor: Colors.white,
  //     elevation: 0,
  //     pinned: true,
  //     expandedHeight: 60,
  //     flexibleSpace: FlexibleSpaceBar(
  //       titlePadding: const EdgeInsets.only(left: 56, bottom: 16),
  //       title: Text(
  //         _currentMode == ReportMode.summary ? 'Bay Analysis' : 'Data Export',
  //         style: TextStyle(
  //           color: theme.colorScheme.onSurface,
  //           fontSize: 18,
  //           fontWeight: FontWeight.w600,
  //         ),
  //       ),
  //     ),
  //     leading: IconButton(
  //       icon: Icon(Icons.arrow_back, color: theme.colorScheme.onSurface),
  //       onPressed: () => Navigator.pop(context),
  //     ),
  //   );
  // }

  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Loading reports...'),
        ],
      ),
    );
  }

  Widget _buildModeToggle(ThemeData theme) {
    return Container(
      margin: const EdgeInsets.all(16),
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
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() {
                _currentMode = ReportMode.summary;
                _tabController.dispose();
                _tabController = TabController(length: 5, vsync: this);
              }),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: _currentMode == ReportMode.summary
                      ? theme.colorScheme.primary
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.analytics,
                      size: 18,
                      color: _currentMode == ReportMode.summary
                          ? Colors.white
                          : theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Statistical Summary',
                      style: TextStyle(
                        color: _currentMode == ReportMode.summary
                            ? Colors.white
                            : theme.colorScheme.primary,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() {
                _currentMode = ReportMode.export;
                _tabController.dispose();
                _tabController = TabController(length: 5, vsync: this);
              }),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: _currentMode == ReportMode.export
                      ? theme.colorScheme.primary
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.download,
                      size: 18,
                      color: _currentMode == ReportMode.export
                          ? Colors.white
                          : theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Data Export',
                      style: TextStyle(
                        color: _currentMode == ReportMode.export
                            ? Colors.white
                            : theme.colorScheme.primary,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBaySelector(ThemeData theme) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
            'Select Bay for Analysis',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 12),
          DropdownSearch<Bay>(
            items: _availableBays,
            popupProps: PopupProps.menu(
              showSearchBox: true,
              menuProps: MenuProps(borderRadius: BorderRadius.circular(10)),
            ),
            dropdownDecoratorProps: DropDownDecoratorProps(
              dropdownSearchDecoration: InputDecoration(
                labelText: 'Select Bay',
                prefixIcon: const Icon(Icons.electrical_services),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                filled: true,
                fillColor: Colors.grey.shade50,
              ),
            ),
            itemAsString: (bay) =>
                '${bay.name} (${bay.bayType} - ${bay.voltageLevel})',
            onChanged: (bay) {
              setState(() => _selectedBay = bay);
              if (bay != null) {
                _generateStatisticalSummary();
              }
            },
            selectedItem: _selectedBay,
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar(ThemeData theme) {
    final summaryTabs = [
      _buildTabItem('Summary', Icons.summarize, Colors.purple),
      _buildTabItem('Operations', Icons.settings, Colors.blue),
      _buildTabItem('Tripping', Icons.warning, Colors.orange),
      _buildTabItem('Energy', Icons.electrical_services, Colors.green),
      _buildTabItem('Templates', Icons.description, Colors.indigo),
    ];

    final exportTabs = [
      _buildTabItem('Operations', Icons.settings, Colors.blue),
      _buildTabItem('Tripping', Icons.warning, Colors.orange),
      _buildTabItem('Energy', Icons.electrical_services, Colors.green),
      _buildTabItem('Templates', Icons.description, Colors.indigo),
      _buildTabItem('Bulk Export', Icons.batch_prediction, Colors.red),
    ];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
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
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        tabs: _currentMode == ReportMode.summary ? summaryTabs : exportTabs,
        indicator: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: theme.colorScheme.primary.withOpacity(0.1),
        ),
        labelColor: theme.colorScheme.primary,
        unselectedLabelColor: Colors.grey.shade600,
        labelStyle: const TextStyle(fontWeight: FontWeight.w600),
        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w400),
        padding: const EdgeInsets.all(8),
        tabAlignment: TabAlignment.start,
      ),
    );
  }

  Widget _buildTabItem(String label, IconData icon, Color color) {
    return Tab(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 8),
            Text(label, style: const TextStyle(fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryTab(ThemeData theme) {
    if (_selectedBay == null) {
      return _buildSelectBayMessage(theme);
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      child: Column(
        children: [
          _buildStatisticalSummaryCard(theme),
          const SizedBox(height: 16),
          _buildTrippingEventsCard(theme),
          const SizedBox(height: 16),
          _buildQuickActionsCard(theme),
        ],
      ),
    );
  }

  Widget _buildSelectBayMessage(ThemeData theme) {
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
            Icon(
              Icons.electrical_services,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              'Select a Bay',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Choose a bay from the dropdown above to view detailed statistics and analysis.',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatisticalSummaryCard(ThemeData theme) {
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
              Icon(Icons.analytics, color: theme.colorScheme.primary, size: 24),
              const SizedBox(width: 12),
              Text(
                'Statistical Summary',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_statisticalSummary.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text('Loading statistical data...'),
              ),
            )
          else
            _buildSummaryContent(theme),
        ],
      ),
    );
  }

  Widget _buildSummaryContent(ThemeData theme) {
    return Column(
      children: _statisticalSummary.entries.map((entry) {
        final fieldName = entry.key;
        final stats = entry.value as Map<String, dynamic>;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                fieldName,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _buildStatItem(
                      'Max',
                      stats['max']?.toString() ?? 'N/A',
                      stats['maxTimestamp'],
                      Colors.green,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildStatItem(
                      'Min',
                      stats['min']?.toString() ?? 'N/A',
                      stats['minTimestamp'],
                      Colors.red,
                    ),
                  ),
                ],
              ),
              if (stats['avg'] != null) ...[
                const SizedBox(height: 8),
                _buildStatItem(
                  'Average',
                  stats['avg'].toStringAsFixed(2),
                  null,
                  Colors.blue,
                ),
              ],
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildStatItem(
    String label,
    String value,
    Timestamp? timestamp,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          if (timestamp != null) ...[
            const SizedBox(height: 2),
            Text(
              DateFormat('MMM dd, HH:mm').format(timestamp.toDate()),
              style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTrippingEventsCard(ThemeData theme) {
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
              Icon(Icons.warning, color: Colors.orange, size: 24),
              const SizedBox(width: 12),
              Text(
                'Tripping Events',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${_bayTrippingEvents.length}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.orange,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_bayTrippingEvents.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('No tripping events found for this period.'),
              ),
            )
          else
            ..._bayTrippingEvents
                .take(3)
                .map((event) => _buildEventItem(event, theme)),
          if (_bayTrippingEvents.length > 3)
            Center(
              child: TextButton(
                onPressed: () => _showAllTrippingEvents(),
                child: Text('View all ${_bayTrippingEvents.length} events'),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEventItem(TrippingShutdownEntry event, ThemeData theme) {
    final isOpen = event.status == 'OPEN';
    final statusColor = isOpen ? Colors.orange : Colors.green;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: statusColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.eventType,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                Text(
                  DateFormat(
                    'MMM dd, yyyy HH:mm',
                  ).format(event.startTime.toDate()),
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              event.status,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: statusColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionsCard(ThemeData theme) {
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
            'Quick Actions',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _exportBayDetailedReport(),
                  icon: const Icon(Icons.download, size: 16),
                  label: const Text('Export Details'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () =>
                      setState(() => _currentMode = ReportMode.export),
                  icon: const Icon(Icons.tune, size: 16),
                  label: const Text('Advanced Export'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOperationsTab(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      child: Column(
        children: [
          if (_currentMode == ReportMode.export) _buildOperationsFilters(theme),
          const SizedBox(height: 16),
          _buildExportButton(theme, 'Operations', ExportDataType.operations),
        ],
      ),
    );
  }

  Widget _buildTrippingTab(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      child: Column(
        children: [
          if (_currentMode == ReportMode.export) _buildTrippingFilters(theme),
          const SizedBox(height: 16),
          _buildExportButton(theme, 'Tripping', ExportDataType.tripping),
        ],
      ),
    );
  }

  Widget _buildEnergyTab(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      child: Column(
        children: [
          if (_currentMode == ReportMode.export) _buildEnergyFilters(theme),
          const SizedBox(height: 16),
          _buildExportButton(theme, 'Energy', ExportDataType.energy),
        ],
      ),
    );
  }

  Widget _buildCustomReportsTab(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      child: Column(
        children: [
          if (_currentMode == ReportMode.export)
            _buildCustomReportFilters(theme),
          const SizedBox(height: 16),
          _buildExportButton(
            theme,
            'Custom Report',
            ExportDataType.customReports,
          ),
        ],
      ),
    );
  }

  Widget _buildBulkExportTab(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      child: Column(
        children: [
          Container(
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
                  'Bulk Export Options',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading: const Icon(Icons.select_all),
                  title: const Text('Export All Data Types'),
                  subtitle: const Text(
                    'Generate separate files for Operations, Tripping, and Energy',
                  ),
                  trailing: ElevatedButton(
                    onPressed: _exportAllDataTypes,
                    child: const Text('Export All'),
                  ),
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.merge_type),
                  title: const Text('Export Combined Report'),
                  subtitle: const Text(
                    'Single file with all data types combined',
                  ),
                  trailing: ElevatedButton(
                    onPressed: _exportCombinedReport,
                    child: const Text('Export Combined'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Keep all your existing filter and export methods here...
  // (All the _buildOperationsFilters, _buildTrippingFilters, etc. methods remain the same)
  // (All the data fetching and processing methods remain the same)

  Widget _buildOperationsFilters(ThemeData theme) {
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
            'Operations Export Filters',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface,
            ),
          ),
          // Add your filter widgets here
        ],
      ),
    );
  }

  Widget _buildTrippingFilters(ThemeData theme) {
    return Container();
  }

  Widget _buildEnergyFilters(ThemeData theme) {
    return Container();
  }

  Widget _buildCustomReportFilters(ThemeData theme) {
    return Container();
  }

  Widget _buildExportButton(
    ThemeData theme,
    String label,
    ExportDataType type,
  ) {
    return Container(
      width: double.infinity,
      height: 48,
      child: ElevatedButton.icon(
        onPressed: _isGenerating ? null : () => _generateReport(type),
        style: ElevatedButton.styleFrom(
          backgroundColor: theme.colorScheme.primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
        ),
        icon: _isGenerating
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.download, size: 20),
        label: Text(
          _isGenerating ? 'Generating...' : 'Export $label Data',
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
        ),
      ),
    );
  }

  // Add all your existing data methods here
  Future<void> _fetchInitialData() async {
    // Your existing implementation
  }

  Future<void> _generateStatisticalSummary() async {
    // Your existing implementation
  }

  Future<void> _generateReport(ExportDataType type) async {
    // Your existing implementation
  }

  Future<void> _exportBayDetailedReport() async {
    // Your existing implementation
  }

  Future<void> _exportAllDataTypes() async {
    // Your existing implementation
  }

  Future<void> _exportCombinedReport() async {
    // Your existing implementation
  }

  void _showAllTrippingEvents() {
    // Your existing implementation
  }
}

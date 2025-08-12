// lib/screens/generate_custom_report_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:excel/excel.dart' hide Border;
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:share_plus/share_plus.dart';
import 'package:dropdown_search/dropdown_search.dart';

import '../../models/app_state_data.dart';
import '../../models/bay_model.dart';
import '../../models/logsheet_models.dart';
import '../../models/reading_models.dart';
import '../../models/report_template_model.dart';
import '../../models/tripping_shutdown_model.dart';
import '../../utils/snackbar_utils.dart';

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
  List<ReportTemplate> _availableTemplates = [];
  ReportTemplate? _selectedTemplate;
  bool _isLoading = false;
  bool _isGenerating = false;
  late TabController _tabController;

  List<String> _selectedBayTypes = [];
  List<String> _selectedVoltageLevels = [];
  List<ReadingField> _selectedReadingFields = [];
  List<String> _selectedEventTypes = ['Tripping', 'Shutdown'];
  List<String> _selectedStatuses = ['OPEN', 'CLOSED'];
  List<String> _selectedEnergyFields = [
    'Energy_Import_Present',
    'Energy_Export_Present',
    'Current',
    'Voltage',
    'Power Factor',
  ];

  List<String> _allBayTypes = [];
  final List<String> _allVoltageLevels = [
    '765kV',
    '400kV',
    '220kV',
    '132kV',
    '33kV',
    '11kV',
  ];
  List<ReadingField> _availableReadingFields = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
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
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: _buildAppBar(theme),
      body: _isLoading
          ? _buildLoadingState()
          : Column(
              children: [
                _buildHeaderSection(theme),
                _buildTabBar(theme),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildOperationsTab(theme),
                      _buildTrippingTab(theme),
                      _buildEnergyTab(theme),
                      _buildCustomReportsTab(theme),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  PreferredSizeWidget _buildAppBar(ThemeData theme) {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      title: Text(
        'Generate Reports',
        style: TextStyle(
          color: theme.colorScheme.onSurface,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
      leading: IconButton(
        icon: Icon(Icons.arrow_back, color: theme.colorScheme.onSurface),
        onPressed: () => Navigator.pop(context),
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Loading export options...'),
        ],
      ),
    );
  }

  Widget _buildHeaderSection(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      theme.colorScheme.primary,
                      theme.colorScheme.primary.withOpacity(0.7),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.download,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Generate Reports',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Export Operations, Tripping, Energy data and Custom Reports',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
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
                Text(
                  '${DateFormat('MMM dd').format(widget.startDate)} - ${DateFormat('MMM dd, yyyy').format(widget.endDate)}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: theme.colorScheme.secondary,
                  ),
                ),
                const Spacer(),
                Text(
                  '(From Dashboard)',
                  style: TextStyle(
                    fontSize: 11,
                    color: theme.colorScheme.secondary.withOpacity(0.7),
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar(ThemeData theme) {
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
        tabs: [
          _buildTabItem('Operations', Icons.settings, Colors.blue),
          _buildTabItem('Tripping', Icons.warning, Colors.orange),
          _buildTabItem('Energy', Icons.electrical_services, Colors.green),
          _buildTabItem('Custom Reports', Icons.description, Colors.purple),
        ],
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

  Widget _buildOperationsTab(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildOperationsFilters(theme),
          const SizedBox(height: 16),
          _buildExportButton(theme, 'Operations', ExportDataType.operations),
        ],
      ),
    );
  }

  Widget _buildTrippingTab(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildTrippingFilters(theme),
          const SizedBox(height: 16),
          _buildExportButton(theme, 'Tripping', ExportDataType.tripping),
        ],
      ),
    );
  }

  Widget _buildEnergyTab(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildEnergyFilters(theme),
          const SizedBox(height: 16),
          _buildExportButton(theme, 'Energy', ExportDataType.energy),
        ],
      ),
    );
  }

  Widget _buildCustomReportsTab(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
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
          const SizedBox(height: 16),

          DropdownSearch<String>.multiSelection(
            items: _allBayTypes,
            popupProps: PopupPropsMultiSelection.menu(
              showSearchBox: true,
              menuProps: MenuProps(borderRadius: BorderRadius.circular(10)),
            ),
            dropdownDecoratorProps: DropDownDecoratorProps(
              dropdownSearchDecoration: InputDecoration(
                labelText: 'Bay Types',
                prefixIcon: const Icon(Icons.settings),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                filled: true,
                fillColor: Colors.grey.shade50,
              ),
            ),
            onChanged: (data) => setState(() => _selectedBayTypes = data),
            selectedItems: _selectedBayTypes,
          ),
          const SizedBox(height: 16),

          DropdownSearch<String>.multiSelection(
            items: _allVoltageLevels,
            popupProps: PopupPropsMultiSelection.menu(
              showSearchBox: true,
              menuProps: MenuProps(borderRadius: BorderRadius.circular(10)),
            ),
            dropdownDecoratorProps: DropDownDecoratorProps(
              dropdownSearchDecoration: InputDecoration(
                labelText: 'Voltage Levels',
                prefixIcon: const Icon(Icons.flash_on),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                filled: true,
                fillColor: Colors.grey.shade50,
              ),
            ),
            onChanged: (data) => setState(() => _selectedVoltageLevels = data),
            selectedItems: _selectedVoltageLevels,
          ),
          const SizedBox(height: 16),

          DropdownSearch<ReadingField>.multiSelection(
            items: _availableReadingFields,
            popupProps: PopupPropsMultiSelection.menu(
              showSearchBox: true,
              menuProps: MenuProps(borderRadius: BorderRadius.circular(10)),
              itemBuilder: (context, field, isSelected) {
                return ListTile(
                  title: Text(field.name),
                  subtitle: Text(
                    '${field.dataType.toString().split('.').last}${field.unit != null ? ' (${field.unit})' : ''}',
                  ),
                  selected: isSelected,
                );
              },
            ),
            dropdownDecoratorProps: DropDownDecoratorProps(
              dropdownSearchDecoration: InputDecoration(
                labelText: 'Reading Fields',
                prefixIcon: const Icon(Icons.list),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                filled: true,
                fillColor: Colors.grey.shade50,
              ),
            ),
            itemAsString: (field) =>
                '${field.name}${field.unit != null ? ' (${field.unit})' : ''}',
            onChanged: (data) => setState(() => _selectedReadingFields = data),
            selectedItems: _selectedReadingFields,
          ),
        ],
      ),
    );
  }

  Widget _buildTrippingFilters(ThemeData theme) {
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
            'Tripping Export Filters',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 16),

          DropdownSearch<String>.multiSelection(
            items: const ['Tripping', 'Shutdown'],
            dropdownDecoratorProps: DropDownDecoratorProps(
              dropdownSearchDecoration: InputDecoration(
                labelText: 'Event Types',
                prefixIcon: const Icon(Icons.warning),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                filled: true,
                fillColor: Colors.grey.shade50,
              ),
            ),
            onChanged: (data) => setState(() => _selectedEventTypes = data),
            selectedItems: _selectedEventTypes,
          ),
          const SizedBox(height: 16),

          DropdownSearch<String>.multiSelection(
            items: const ['OPEN', 'CLOSED'],
            dropdownDecoratorProps: DropDownDecoratorProps(
              dropdownSearchDecoration: InputDecoration(
                labelText: 'Event Status',
                prefixIcon: const Icon(Icons.check_circle),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                filled: true,
                fillColor: Colors.grey.shade50,
              ),
            ),
            onChanged: (data) => setState(() => _selectedStatuses = data),
            selectedItems: _selectedStatuses,
          ),
        ],
      ),
    );
  }

  Widget _buildEnergyFilters(ThemeData theme) {
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
            'Energy Export Filters',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 16),

          DropdownSearch<String>.multiSelection(
            items: const [
              'Energy_Import_Present',
              'Energy_Export_Present',
              'Current',
              'Voltage',
              'Power Factor',
              'Frequency',
              'Active Power',
              'Reactive Power',
            ],
            dropdownDecoratorProps: DropDownDecoratorProps(
              dropdownSearchDecoration: InputDecoration(
                labelText: 'Energy Fields',
                prefixIcon: const Icon(Icons.electrical_services),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                filled: true,
                fillColor: Colors.grey.shade50,
              ),
            ),
            onChanged: (data) => setState(() => _selectedEnergyFields = data),
            selectedItems: _selectedEnergyFields,
          ),
        ],
      ),
    );
  }

  Widget _buildCustomReportFilters(ThemeData theme) {
    if (_availableTemplates.isEmpty) {
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
              Icon(
                Icons.description_outlined,
                size: 48,
                color: theme.colorScheme.onSurface.withOpacity(0.3),
              ),
              const SizedBox(height: 16),
              Text(
                'No Report Templates Found',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Create a report template first to generate custom reports.',
                style: TextStyle(
                  fontSize: 13,
                  color: theme.colorScheme.onSurface.withOpacity(0.5),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

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
            'Custom Report Template',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<ReportTemplate>(
            value: _selectedTemplate,
            decoration: InputDecoration(
              labelText: 'Select Template',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
              filled: true,
              fillColor: Colors.grey.shade50,
            ),
            items: _availableTemplates
                .map(
                  (template) => DropdownMenuItem(
                    value: template,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          template.templateName,
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                        Text(
                          '${template.selectedBayIds.length} bays, ${template.selectedReadingFieldIds.length} fields',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
                .toList(),
            onChanged: (template) {
              setState(() {
                _selectedTemplate = template;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildExportButton(
    ThemeData theme,
    String label,
    ExportDataType type,
  ) {
    bool canExport = true;
    String? disabledReason;

    switch (type) {
      case ExportDataType.operations:
        canExport = _selectedReadingFields.isNotEmpty;
        disabledReason = canExport ? null : 'Select at least one reading field';
        break;
      case ExportDataType.tripping:
        canExport = _selectedEventTypes.isNotEmpty;
        disabledReason = canExport ? null : 'Select at least one event type';
        break;
      case ExportDataType.energy:
        canExport = _selectedEnergyFields.isNotEmpty;
        disabledReason = canExport ? null : 'Select at least one energy field';
        break;
      case ExportDataType.customReports:
        canExport = _selectedTemplate != null;
        disabledReason = canExport ? null : 'Select a report template';
        break;
    }

    return Container(
      width: double.infinity,
      height: 48,
      child: ElevatedButton.icon(
        onPressed: (_isGenerating || !canExport)
            ? null
            : () => _generateReport(type),
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
        label: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _isGenerating ? 'Generating...' : 'Export $label Data',
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
            ),
            if (disabledReason != null)
              Text(
                disabledReason,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w400,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _fetchInitialData() async {
    setState(() => _isLoading = true);
    try {
      final appState = Provider.of<AppStateData>(context, listen: false);
      final currentUserUid = appState.currentUser?.uid;
      final selectedSubstation = appState.selectedSubstation;

      if (currentUserUid == null || selectedSubstation == null) {
        if (mounted) {
          SnackBarUtils.showSnackBar(
            context,
            'Please log in and select a substation first.',
            isError: true,
          );
        }
        return;
      }

      final templateQuerySnapshot = await FirebaseFirestore.instance
          .collection('reportTemplates')
          .where('createdByUid', isEqualTo: currentUserUid)
          .where('substationId', isEqualTo: selectedSubstation.id)
          .get();

      _availableTemplates = templateQuerySnapshot.docs
          .map((doc) => ReportTemplate.fromFirestore(doc))
          .toList();

      if (_availableTemplates.isNotEmpty) {
        _selectedTemplate = _availableTemplates.first;
      }

      final readingTemplatesSnapshot = await FirebaseFirestore.instance
          .collection('readingTemplates')
          .get();

      final availableReadingTemplates = readingTemplatesSnapshot.docs
          .map((doc) => ReadingTemplate.fromFirestore(doc))
          .toList();

      final Set<String> bayTypesSet = {};
      final Set<ReadingField> readingFieldsSet = {};

      for (final template in availableReadingTemplates) {
        bayTypesSet.add(template.bayType);
        readingFieldsSet.addAll(template.readingFields);
      }

      _allBayTypes = bayTypesSet.toList()..sort();
      _availableReadingFields = readingFieldsSet.toList()
        ..sort((a, b) => a.name.compareTo(b.name));
    } catch (e) {
      if (mounted) {
        SnackBarUtils.showSnackBar(
          context,
          'Error loading data: $e',
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _generateReport(ExportDataType type) async {
    setState(() => _isGenerating = true);
    try {
      switch (type) {
        case ExportDataType.operations:
          await _generateOperationsReport();
          break;
        case ExportDataType.tripping:
          await _generateTrippingReport();
          break;
        case ExportDataType.energy:
          await _generateEnergyReport();
          break;
        case ExportDataType.customReports:
          await _generateCustomReport();
          break;
      }
      if (mounted) {
        SnackBarUtils.showSnackBar(context, 'Report generated successfully!');
      }
    } catch (e) {
      if (mounted) {
        SnackBarUtils.showSnackBar(
          context,
          'Failed to generate report: $e',
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  Future<void> _generateOperationsReport() async {
    final appState = Provider.of<AppStateData>(context, listen: false);
    final selectedSubstation = appState.selectedSubstation;

    if (selectedSubstation == null) {
      throw Exception('No substation selected');
    }

    List<List<dynamic>> rows = [];

    List<String> headers = [
      'Timestamp',
      'Bay Name',
      'Bay Type',
      'Voltage Level',
      'Frequency',
      'Recorded By',
    ];

    for (final field in _selectedReadingFields) {
      headers.add(
        '${field.name}${field.unit != null ? ' (${field.unit})' : ''}',
      );
    }

    rows.add(headers);

    await _addOperationsDataForSubstation(selectedSubstation, rows);
    await _saveAndShareCsv(rows, 'operations_report');
  }

  Future<void> _generateTrippingReport() async {
    final appState = Provider.of<AppStateData>(context, listen: false);
    final selectedSubstation = appState.selectedSubstation;

    if (selectedSubstation == null) {
      throw Exception('No substation selected');
    }

    List<List<dynamic>> rows = [];

    rows.add([
      'Bay Name',
      'Event Type',
      'Start Time',
      'End Time',
      'Status',
      'Duration (Hours)',
      'Flags/Cause',
      'Phase Faults',
      'Distance',
      'Shutdown Type',
      'Shutdown Person',
      'Created By',
      'Created At',
      'Closed By',
      'Closed At',
    ]);

    await _addTrippingDataForSubstation(selectedSubstation, rows);
    await _saveAndShareCsv(rows, 'tripping_report');
  }

  Future<void> _generateEnergyReport() async {
    final appState = Provider.of<AppStateData>(context, listen: false);
    final selectedSubstation = appState.selectedSubstation;

    if (selectedSubstation == null) {
      throw Exception('No substation selected');
    }

    List<List<dynamic>> rows = [];

    List<String> headers = [
      'Timestamp',
      'Bay Name',
      'Bay Type',
      'Voltage Level',
      'Frequency',
    ];

    headers.addAll(_selectedEnergyFields);

    rows.add(headers);

    await _addEnergyDataForSubstation(selectedSubstation, rows);
    await _saveAndShareCsv(rows, 'energy_report');
  }

  Future<void> _generateCustomReport() async {
    if (_selectedTemplate == null) {
      throw Exception('No template selected');
    }

    await _performExcelGeneration();
  }

  Future<void> _addOperationsDataForSubstation(
    substation,
    List<List<dynamic>> rows,
  ) async {
    try {
      Query baysQuery = FirebaseFirestore.instance
          .collection('bays')
          .where('substationId', isEqualTo: substation.id);

      if (_selectedBayTypes.isNotEmpty) {
        baysQuery = baysQuery.where('bayType', whereIn: _selectedBayTypes);
      }

      if (_selectedVoltageLevels.isNotEmpty) {
        baysQuery = baysQuery.where(
          'voltageLevel',
          whereIn: _selectedVoltageLevels,
        );
      }

      final baysSnapshot = await baysQuery.get();
      final bays = baysSnapshot.docs
          .map((doc) => Bay.fromFirestore(doc))
          .toList();

      if (bays.isEmpty) return;

      final bayIds = bays.map((bay) => bay.id).toList();
      final baysMap = {for (var bay in bays) bay.id: bay};

      Query logsheetQuery = FirebaseFirestore.instance
          .collection('logsheetEntries')
          .where('bayId', whereIn: bayIds);

      logsheetQuery = logsheetQuery.where(
        'readingTimestamp',
        isGreaterThanOrEqualTo: Timestamp.fromDate(widget.startDate),
      );

      logsheetQuery = logsheetQuery.where(
        'readingTimestamp',
        isLessThanOrEqualTo: Timestamp.fromDate(widget.endDate),
      );

      final logsheetSnapshot = await logsheetQuery.get();
      final logsheetEntries = logsheetSnapshot.docs
          .map((doc) => LogsheetEntry.fromFirestore(doc))
          .toList();

      for (final entry in logsheetEntries) {
        final bay = baysMap[entry.bayId];
        if (bay == null) continue;

        List<dynamic> row = [
          DateFormat(
            'yyyy-MM-dd HH:mm:ss',
          ).format(entry.readingTimestamp.toDate()),
          bay.name,
          bay.bayType,
          bay.voltageLevel,
          entry.frequency,
          entry.recordedBy,
        ];

        for (final field in _selectedReadingFields) {
          final value = entry.values[field.name];
          row.add(value?.toString() ?? '');
        }

        rows.add(row);
      }
    } catch (e) {
      print('Error adding operations data for ${substation.name}: $e');
    }
  }

  Future<void> _addTrippingDataForSubstation(
    substation,
    List<List<dynamic>> rows,
  ) async {
    try {
      Query trippingQuery = FirebaseFirestore.instance
          .collection('trippingShutdownEntries')
          .where('substationId', isEqualTo: substation.id);

      if (_selectedEventTypes.isNotEmpty) {
        trippingQuery = trippingQuery.where(
          'eventType',
          whereIn: _selectedEventTypes,
        );
      }

      if (_selectedStatuses.isNotEmpty) {
        trippingQuery = trippingQuery.where(
          'status',
          whereIn: _selectedStatuses,
        );
      }

      trippingQuery = trippingQuery.where(
        'startTime',
        isGreaterThanOrEqualTo: Timestamp.fromDate(widget.startDate),
      );

      trippingQuery = trippingQuery.where(
        'startTime',
        isLessThanOrEqualTo: Timestamp.fromDate(widget.endDate),
      );

      final trippingSnapshot = await trippingQuery.get();
      final trippingEntries = trippingSnapshot.docs
          .map((doc) => TrippingShutdownEntry.fromFirestore(doc))
          .toList();

      for (final entry in trippingEntries) {
        final duration = entry.endTime != null
            ? entry.endTime!
                  .toDate()
                  .difference(entry.startTime.toDate())
                  .inHours
            : null;

        rows.add([
          entry.bayName,
          entry.eventType,
          DateFormat('yyyy-MM-dd HH:mm:ss').format(entry.startTime.toDate()),
          entry.endTime != null
              ? DateFormat(
                  'yyyy-MM-dd HH:mm:ss',
                ).format(entry.endTime!.toDate())
              : '',
          entry.status,
          duration?.toString() ?? '',
          entry.flagsCause,
          entry.phaseFaults?.join(', ') ?? '',
          entry.distance ?? '',
          entry.shutdownType ?? '',
          entry.shutdownPersonName ?? '',
          entry.createdBy,
          DateFormat('yyyy-MM-dd HH:mm:ss').format(entry.createdAt.toDate()),
          entry.closedBy ?? '',
          entry.closedAt != null
              ? DateFormat(
                  'yyyy-MM-dd HH:mm:ss',
                ).format(entry.closedAt!.toDate())
              : '',
        ]);
      }
    } catch (e) {
      print('Error adding tripping data for ${substation.name}: $e');
    }
  }

  Future<void> _addEnergyDataForSubstation(
    substation,
    List<List<dynamic>> rows,
  ) async {
    try {
      Query baysQuery = FirebaseFirestore.instance
          .collection('bays')
          .where('substationId', isEqualTo: substation.id);

      if (_selectedBayTypes.isNotEmpty) {
        baysQuery = baysQuery.where('bayType', whereIn: _selectedBayTypes);
      }

      if (_selectedVoltageLevels.isNotEmpty) {
        baysQuery = baysQuery.where(
          'voltageLevel',
          whereIn: _selectedVoltageLevels,
        );
      }

      final baysSnapshot = await baysQuery.get();
      final bays = baysSnapshot.docs
          .map((doc) => Bay.fromFirestore(doc))
          .toList();

      if (bays.isEmpty) return;

      final bayIds = bays.map((bay) => bay.id).toList();
      final baysMap = {for (var bay in bays) bay.id: bay};

      Query logsheetQuery = FirebaseFirestore.instance
          .collection('logsheetEntries')
          .where('bayId', whereIn: bayIds);

      logsheetQuery = logsheetQuery.where(
        'readingTimestamp',
        isGreaterThanOrEqualTo: Timestamp.fromDate(widget.startDate),
      );

      logsheetQuery = logsheetQuery.where(
        'readingTimestamp',
        isLessThanOrEqualTo: Timestamp.fromDate(widget.endDate),
      );

      final logsheetSnapshot = await logsheetQuery.get();
      final logsheetEntries = logsheetSnapshot.docs
          .map((doc) => LogsheetEntry.fromFirestore(doc))
          .toList();

      for (final entry in logsheetEntries) {
        final bay = baysMap[entry.bayId];
        if (bay == null) continue;

        List<dynamic> row = [
          DateFormat(
            'yyyy-MM-dd HH:mm:ss',
          ).format(entry.readingTimestamp.toDate()),
          bay.name,
          bay.bayType,
          bay.voltageLevel,
          entry.frequency,
        ];

        for (final fieldName in _selectedEnergyFields) {
          final value = entry.values[fieldName];
          row.add(value?.toString() ?? '');
        }

        rows.add(row);
      }
    } catch (e) {
      print('Error adding energy data for ${substation.name}: $e');
    }
  }

  Future<void> _saveAndShareCsv(
    List<List<dynamic>> rows,
    String fileName,
  ) async {
    if (rows.length <= 1) {
      SnackBarUtils.showSnackBar(
        context,
        'No data available to export.',
        isError: true,
      );
      return;
    }

    try {
      String csv = const ListToCsvConverter().convert(rows);

      final directory = await getApplicationDocumentsDirectory();
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final file = File('${directory.path}/${fileName}_$timestamp.csv');

      await file.writeAsString(csv);

      await Share.shareXFiles([XFile(file.path)], text: 'Data Export');

      if (mounted) {
        SnackBarUtils.showSnackBar(
          context,
          'Report generated successfully! ${rows.length - 1} records exported.',
          isError: false,
        );
      }
    } catch (e) {
      print("Error saving CSV: $e");
      if (mounted) {
        SnackBarUtils.showSnackBar(
          context,
          'Failed to generate CSV file: $e',
          isError: true,
        );
      }
    }
  }

  Future<void> _performExcelGeneration() async {
    final appState = Provider.of<AppStateData>(context, listen: false);
    final selectedSubstation = appState.selectedSubstation;
    if (selectedSubstation == null) {
      SnackBarUtils.showSnackBar(
        context,
        'No substation selected. Cannot generate report.',
        isError: true,
      );
      return;
    }

    if (_selectedTemplate == null) {
      SnackBarUtils.showSnackBar(
        context,
        'No template selected. Cannot generate report.',
        isError: true,
      );
      return;
    }

    try {
      final baysQuery = await FirebaseFirestore.instance
          .collection('bays')
          .where(
            FieldPath.documentId,
            whereIn: _selectedTemplate!.selectedBayIds,
          )
          .get();

      final bays = baysQuery.docs.map((doc) => Bay.fromFirestore(doc)).toList();
      if (bays.isEmpty) {
        SnackBarUtils.showSnackBar(
          context,
          'No bays found for this template.',
          isError: true,
        );
        return;
      }

      List<ReadingField> readingFields = [];

      final readingTemplatesSnapshot = await FirebaseFirestore.instance
          .collection('readingTemplates')
          .get();

      final availableReadingTemplates = readingTemplatesSnapshot.docs
          .map((doc) => ReadingTemplate.fromFirestore(doc))
          .toList();

      for (final template in availableReadingTemplates) {
        for (final field in template.readingFields) {
          if (_selectedTemplate!.selectedReadingFieldIds.contains(field.name)) {
            readingFields.add(field);
          }
        }
      }

      // FIXED: Use field.name instead of field.id for uniqueness
      final Map<String, ReadingField> uniqueFields = {};
      for (final field in readingFields) {
        uniqueFields[field.name] = field;
      }
      readingFields = uniqueFields.values.toList();

      if (readingFields.isEmpty) {
        SnackBarUtils.showSnackBar(
          context,
          'No reading fields found for this template.',
          isError: true,
        );
        return;
      }

      // Rest of the method remains the same...
      final queryStartTime = Timestamp.fromDate(widget.startDate);
      final queryEndTime = Timestamp.fromDate(widget.endDate);

      final logsheetEntriesQuery = await FirebaseFirestore.instance
          .collection('logsheetEntries')
          .where('bayId', whereIn: _selectedTemplate!.selectedBayIds)
          .where('readingTimestamp', isGreaterThanOrEqualTo: queryStartTime)
          .where('readingTimestamp', isLessThanOrEqualTo: queryEndTime)
          .orderBy('readingTimestamp')
          .get();

      final logsheetEntries = logsheetEntriesQuery.docs
          .map((doc) => LogsheetEntry.fromFirestore(doc))
          .toList();

      if (logsheetEntries.isEmpty) {
        SnackBarUtils.showSnackBar(
          context,
          'No data found for the selected date range.',
          isError: true,
        );
        return;
      }

      final excel = Excel.createExcel();
      final sheet = excel['Report'];

      final headerRow = ['Date', 'Time', 'Bay Name', 'Bay Type', 'Frequency'];
      for (final field in readingFields) {
        headerRow.add(
          '${field.name}${field.unit != null ? ' (${field.unit})' : ''}',
        );
      }

      for (int col = 0; col < headerRow.length; col++) {
        sheet
            .cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: 0))
            .value = TextCellValue(
          headerRow[col],
        );
      }

      int rowIndex = 1;
      for (final entry in logsheetEntries) {
        final bay = bays.firstWhere((b) => b.id == entry.bayId);
        final timestamp = entry.readingTimestamp.toDate();

        int colIndex = 0;
        sheet
            .cell(
              CellIndex.indexByColumnRow(
                columnIndex: colIndex++,
                rowIndex: rowIndex,
              ),
            )
            .value = TextCellValue(
          DateFormat('yyyy-MM-dd').format(timestamp),
        );
        sheet
            .cell(
              CellIndex.indexByColumnRow(
                columnIndex: colIndex++,
                rowIndex: rowIndex,
              ),
            )
            .value = TextCellValue(
          DateFormat('HH:mm:ss').format(timestamp),
        );
        sheet
            .cell(
              CellIndex.indexByColumnRow(
                columnIndex: colIndex++,
                rowIndex: rowIndex,
              ),
            )
            .value = TextCellValue(
          bay.name,
        );
        sheet
            .cell(
              CellIndex.indexByColumnRow(
                columnIndex: colIndex++,
                rowIndex: rowIndex,
              ),
            )
            .value = TextCellValue(
          bay.bayType,
        );
        sheet
            .cell(
              CellIndex.indexByColumnRow(
                columnIndex: colIndex++,
                rowIndex: rowIndex,
              ),
            )
            .value = TextCellValue(
          entry.frequency,
        );

        for (final field in readingFields) {
          final value = entry.values[field.name];
          String cellValue = '';

          if (value != null) {
            if (field.dataType == ReadingFieldDataType.boolean &&
                value is Map) {
              cellValue = value['value']?.toString() ?? '';
            } else {
              cellValue = value.toString();
            }
          }

          sheet
              .cell(
                CellIndex.indexByColumnRow(
                  columnIndex: colIndex++,
                  rowIndex: rowIndex,
                ),
              )
              .value = TextCellValue(
            cellValue,
          );
        }

        rowIndex++;
      }

      final directory = await getApplicationDocumentsDirectory();
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final filePath =
          '${directory.path}/${_selectedTemplate!.templateName}_$timestamp.xlsx';
      final excelBytes = excel.save();

      if (excelBytes != null) {
        final file = File(filePath);
        await file.writeAsBytes(excelBytes);

        await Share.shareXFiles([XFile(filePath)]);

        SnackBarUtils.showSnackBar(
          context,
          'Excel report generated successfully!',
        );
      }
    } catch (e) {
      print('Error generating Excel report: $e');
      SnackBarUtils.showSnackBar(
        context,
        'Failed to generate Excel report: $e',
        isError: true,
      );
    }
  }
}

extension StringCapitalizeExtension on String {
  String capitalize() {
    if (isEmpty) return '';
    return "${this[0].toUpperCase()}${substring(1)}";
  }
}

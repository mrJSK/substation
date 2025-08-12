// lib/screens/report_builder_wizard_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/user_model.dart';
import '../models/report_builder_models.dart';
import '../services/report_builder_service.dart';
import '../widgets/report_wizard_steps.dart';
import '../utils/snackbar_utils.dart';

class ReportBuilderWizardScreen extends StatefulWidget {
  static const routeName = '/report-builder-wizard';

  final AppUser currentUser;
  final ReportConfiguration? existingConfig;

  const ReportBuilderWizardScreen({
    super.key,
    required this.currentUser,
    this.existingConfig,
  });

  @override
  State<ReportBuilderWizardScreen> createState() =>
      _ReportBuilderWizardScreenState();
}

class _ReportBuilderWizardScreenState extends State<ReportBuilderWizardScreen> {
  int _currentStep = 0;
  late ReportConfiguration _config;
  bool _isGeneratingPreview = false;
  bool _isSaving = false;
  bool _isExporting = false;

  final List<String> _stepTitles = [
    'Report Info',
    'Scope Selection',
    'Data Sources',
    'Column Mapping',
    'Row Mapping',
    'Preview',
    'Save & Export',
  ];

  @override
  void initState() {
    super.initState();
    _config = widget.existingConfig ?? ReportConfiguration();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: _buildAppBar(theme),
      body: Column(
        children: [
          _buildProgressIndicator(theme),
          Expanded(child: _buildCurrentStep()),
          _buildNavigationBar(theme),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(ThemeData theme) {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      title: Text(
        'Report Builder Wizard',
        style: TextStyle(
          color: theme.colorScheme.onSurface,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
      leading: IconButton(
        icon: Icon(Icons.arrow_back, color: theme.colorScheme.onSurface),
        onPressed: () => _handleBackNavigation(),
      ),
      actions: [
        Container(
          margin: const EdgeInsets.only(right: 16, top: 8, bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Center(
            child: Text(
              _stepTitles[_currentStep],
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: theme.colorScheme.primary,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProgressIndicator(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: Column(
        children: [
          Row(
            children: List.generate(_stepTitles.length, (index) {
              final isCompleted = index < _currentStep;
              final isActive = index == _currentStep;

              return Expanded(
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 4,
                        decoration: BoxDecoration(
                          color: isCompleted || isActive
                              ? theme.colorScheme.primary
                              : Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    if (index < _stepTitles.length - 1)
                      Container(
                        width: 24,
                        height: 24,
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: BoxDecoration(
                          color: isCompleted
                              ? theme.colorScheme.primary
                              : isActive
                              ? theme.colorScheme.primary
                              : Colors.grey.shade300,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: isCompleted
                              ? const Icon(
                                  Icons.check,
                                  color: Colors.white,
                                  size: 16,
                                )
                              : isActive
                              ? Container(
                                  width: 8,
                                  height: 8,
                                  decoration: const BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                  ),
                                )
                              : Text(
                                  '${index + 1}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ),
                  ],
                ),
              );
            }),
          ),
          const SizedBox(height: 12),
          Text(
            '${_currentStep + 1}. ${_stepTitles[_currentStep]}',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentStep() {
    switch (_currentStep) {
      case 0:
        return ReportMetadataStep(
          config: _config,
          onConfigChanged: _updateConfig,
        );
      case 1:
        return SubstationSelectionStep(
          config: _config,
          onConfigChanged: _updateConfig,
          currentUser: widget.currentUser, // Add this line
        );
      case 2:
        return DataSourceSelectionStep(
          config: _config,
          onConfigChanged: _updateConfig,
        );
      case 3:
        return ColumnMappingStep(
          config: _config,
          onConfigChanged: _updateConfig,
        );
      case 4:
        return _buildRowMappingStep();
      case 5:
        return _buildPreviewStep();
      case 6:
        return _buildSaveExportStep();
      default:
        return Container();
    }
  }

  Widget _buildRowMappingStep() {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.indigo.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.table_rows,
                  color: Colors.indigo,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Row Configuration',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Configure how data should be grouped and filtered',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Primary Data Source',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _config.rowConfig.primaryDataSource.isEmpty
                      ? null
                      : _config.rowConfig.primaryDataSource,
                  decoration: InputDecoration(
                    hintText: 'Select primary data source',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                  ),
                  items: _config.dataSources
                      .where((ds) => ds.isEnabled)
                      .map(
                        (ds) => DropdownMenuItem(
                          value: ds.sourceId,
                          child: Text(ds.sourceName),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    setState(() {
                      _config.rowConfig.primaryDataSource = value ?? '';
                    });
                  },
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.indigo.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.info, color: Colors.indigo, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Row Configuration Options',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Colors.indigo.shade800,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '• Primary data source determines the main entity for each row\n'
                        '• Additional grouping and filtering options will be available in future updates\n'
                        '• Data from other sources will be joined based on common fields',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.indigo.shade700,
                          height: 1.4,
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
    );
  }

  Widget _buildPreviewStep() {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.teal.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.preview,
                      color: Colors.teal,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Report Preview',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Review your report before saving',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              ElevatedButton.icon(
                onPressed: _isGeneratingPreview ? null : _generatePreview,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
                icon: _isGeneratingPreview
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.refresh),
                label: Text(
                  _isGeneratingPreview ? 'Generating...' : 'Generate Preview',
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          _buildPreviewContent(theme),
        ],
      ),
    );
  }

  Widget _buildPreviewContent(ThemeData theme) {
    if (_config.preview == null) {
      return Container(
        padding: const EdgeInsets.all(40),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.preview, size: 64, color: Colors.grey.shade400),
              const SizedBox(height: 16),
              Text(
                'Generate Preview',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Click the button above to generate a preview of your report',
                style: TextStyle(color: Colors.grey.shade500),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Preview stats
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.teal.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.info, color: Colors.teal, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${_config.preview!.sampleRows.length} sample rows • ${_config.preview!.totalEstimatedRows} total estimated • Generated ${DateFormat('HH:mm').format(_config.preview!.generatedAt)}',
                    style: TextStyle(fontSize: 12, color: Colors.teal.shade700),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Report title
          if (_config.title.isNotEmpty) ...[
            Text(
              _config.title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            if (_config.subtitle != null && _config.subtitle!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                _config.subtitle!,
                style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
              ),
            ],
            const SizedBox(height: 16),
          ],

          // Preview table
          Container(
            constraints: const BoxConstraints(maxHeight: 400),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
            ),
            child: InteractiveViewer(
              constrained: false,
              scaleEnabled: false,
              child: DataTable(
                headingRowColor: MaterialStateProperty.all(
                  theme.colorScheme.primary.withOpacity(0.1),
                ),
                columns: _buildPreviewColumns(),
                rows: _buildPreviewRows(),
                border: TableBorder.all(color: Colors.grey.shade300),
                headingTextStyle: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<DataColumn> _buildPreviewColumns() {
    List<DataColumn> columns = [];
    for (var column in _config.columns) {
      columns.addAll(_buildDataColumnsRecursive(column));
    }
    return columns;
  }

  List<DataColumn> _buildDataColumnsRecursive(ColumnConfig column) {
    List<DataColumn> columns = [];

    if (column.isGroupHeader && column.subColumns != null) {
      for (var subColumn in column.subColumns!) {
        columns.addAll(_buildDataColumnsRecursive(subColumn));
      }
    } else {
      columns.add(
        DataColumn(
          label: Text(
            column.header,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      );
    }

    return columns;
  }

  List<DataRow> _buildPreviewRows() {
    if (_config.preview == null) return [];

    return _config.preview!.sampleRows.take(10).map((row) {
      return DataRow(cells: _buildDataCells(row));
    }).toList();
  }

  List<DataCell> _buildDataCells(Map<String, dynamic> row) {
    List<DataCell> cells = [];
    for (var column in _config.columns) {
      cells.addAll(_buildDataCellsRecursive(column, row));
    }
    return cells;
  }

  List<DataCell> _buildDataCellsRecursive(
    ColumnConfig column,
    Map<String, dynamic> row,
  ) {
    List<DataCell> cells = [];

    if (column.isGroupHeader && column.subColumns != null) {
      for (var subColumn in column.subColumns!) {
        cells.addAll(_buildDataCellsRecursive(subColumn, row));
      }
    } else {
      String key = column.getColumnKey();
      dynamic value = row[key] ?? '';
      cells.add(
        DataCell(Text(value.toString(), style: const TextStyle(fontSize: 13))),
      );
    }

    return cells;
  }

  Widget _buildSaveExportStep() {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.save, color: Colors.green, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Save & Export',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Save your report template and export data',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),

          // Template Information Section
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Template Information',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  decoration: InputDecoration(
                    labelText: 'Template Name',
                    hintText: 'Give your template a memorable name',
                    prefixIcon: const Icon(Icons.bookmark),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                  ),
                  initialValue: _config.templateInfo?.name ?? _config.title,
                  onChanged: (value) {
                    _config.templateInfo ??= TemplateMetadata(
                      name: '',
                      createdBy: widget.currentUser.uid,
                      createdAt: DateTime.now(),
                    );
                    _config.templateInfo!.name = value;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  decoration: InputDecoration(
                    labelText: 'Description (Optional)',
                    hintText: 'Describe what this report template does',
                    prefixIcon: const Icon(Icons.description),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                  ),
                  maxLines: 3,
                  initialValue: _config.templateInfo?.description ?? '',
                  onChanged: (value) {
                    _config.templateInfo ??= TemplateMetadata(
                      name: '',
                      createdBy: widget.currentUser.uid,
                      createdAt: DateTime.now(),
                    );
                    _config.templateInfo!.description = value.isEmpty
                        ? null
                        : value;
                  },
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isSaving ? null : _saveTemplate,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    icon: _isSaving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.save),
                    label: Text(
                      _isSaving ? 'Saving Template...' : 'Save Template',
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Export Options Section
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Export Options',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 16),
                if (_config.preview == null ||
                    _config.preview!.sampleRows.isEmpty) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.warning, color: Colors.orange, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Generate a preview first to enable export options',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.orange.shade700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _isExporting
                              ? null
                              : () => _exportReport('excel'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          icon: _isExporting
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.table_chart),
                          label: Text(
                            _isExporting ? 'Exporting...' : 'Export Excel',
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _isExporting
                              ? null
                              : () => _exportReport('pdf'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          icon: const Icon(Icons.picture_as_pdf),
                          label: const Text('Export PDF'),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationBar(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: Row(
        children: [
          if (_currentStep > 0)
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _goToPreviousStep,
                icon: const Icon(Icons.arrow_back),
                label: const Text('Previous'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          if (_currentStep > 0) const SizedBox(width: 16),
          if (_currentStep < _stepTitles.length - 1)
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _canProceed() ? _goToNextStep : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                icon: const Icon(Icons.arrow_forward),
                label: const Text('Next'),
              ),
            ),
          if (_currentStep == _stepTitles.length - 1)
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _canFinish() ? _finishWizard : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                icon: const Icon(Icons.check),
                label: const Text('Finish'),
              ),
            ),
        ],
      ),
    );
  }

  void _updateConfig(ReportConfiguration config) {
    setState(() {
      _config = config;
    });
  }

  void _goToPreviousStep() {
    if (_currentStep > 0) {
      setState(() {
        _currentStep--;
      });
    }
  }

  void _goToNextStep() {
    if (_canProceed() && _currentStep < _stepTitles.length - 1) {
      setState(() {
        _currentStep++;
      });
    }
  }

  bool _canProceed() {
    final validation = ReportValidationService.validateStep(
      _currentStep,
      _config,
    );
    return validation.isValid;
  }

  bool _canFinish() {
    // Can finish if we have a preview or if this is just saving a template
    return _config.preview != null ||
        (_config.templateInfo?.name.isNotEmpty ?? false);
  }

  void _handleBackNavigation() {
    if (_currentStep > 0) {
      _goToPreviousStep();
    } else {
      Navigator.pop(context);
    }
  }

  Future<void> _generatePreview() async {
    setState(() => _isGeneratingPreview = true);

    try {
      // Validate current configuration
      final validation = ReportValidationService.validateStep(
        3,
        _config,
      ); // Column validation
      if (!validation.isValid) {
        SnackBarUtils.showSnackBar(
          context,
          validation.errorMessage ?? 'Please complete column configuration',
          isError: true,
        );
        return;
      }

      // Generate preview data
      final preview = await ReportBuilderService.generatePreview(_config);

      setState(() {
        _config.preview = preview;
      });

      if (preview.sampleRows.isEmpty) {
        SnackBarUtils.showSnackBar(
          context,
          'No data found for the selected criteria',
          isError: true,
        );
      } else {
        SnackBarUtils.showSnackBar(
          context,
          'Preview generated successfully! ${preview.totalEstimatedRows} total rows found',
        );
      }
    } catch (e) {
      SnackBarUtils.showSnackBar(
        context,
        'Error generating preview: $e',
        isError: true,
      );
    } finally {
      setState(() => _isGeneratingPreview = false);
    }
  }

  Future<void> _saveTemplate() async {
    final templateName = _config.templateInfo?.name ?? _config.title;
    if (templateName.isEmpty) {
      SnackBarUtils.showSnackBar(
        context,
        'Please enter a template name',
        isError: true,
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      // Ensure template metadata is set
      _config.templateInfo ??= TemplateMetadata(
        name: templateName,
        createdBy: widget.currentUser.uid,
        createdAt: DateTime.now(),
      );

      await ReportBuilderService.saveTemplate(_config, widget.currentUser.uid);

      SnackBarUtils.showSnackBar(context, 'Template saved successfully!');
    } catch (e) {
      SnackBarUtils.showSnackBar(
        context,
        'Error saving template: $e',
        isError: true,
      );
    } finally {
      setState(() => _isSaving = false);
    }
  }

  Future<void> _exportReport(String format) async {
    if (_config.preview == null || _config.preview!.sampleRows.isEmpty) {
      SnackBarUtils.showSnackBar(
        context,
        'Please generate a preview first',
        isError: true,
      );
      return;
    }

    setState(() => _isExporting = true);

    try {
      // Get all data, not just preview
      final fullData = await ReportBuilderService.generatePreview(_config);

      if (format == 'excel') {
        await ReportBuilderService.exportToExcel(_config, fullData.sampleRows);
        SnackBarUtils.showSnackBar(context, 'Excel export completed!');
      } else if (format == 'pdf') {
        // PDF export would be implemented here
        SnackBarUtils.showSnackBar(context, 'PDF export feature coming soon!');
      }
    } catch (e) {
      SnackBarUtils.showSnackBar(
        context,
        'Error exporting report: $e',
        isError: true,
      );
    } finally {
      setState(() => _isExporting = false);
    }
  }

  void _finishWizard() {
    Navigator.pop(context, _config);
  }
}

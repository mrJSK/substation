// lib/screens/create_report_template_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/app_state_data.dart';
import '../../models/bay_model.dart';
import '../../models/reading_models.dart';
import '../../models/report_template_model.dart';
import '../../utils/snackbar_utils.dart';

class CreateReportTemplateScreen extends StatefulWidget {
  static const routeName = '/create-report-template';

  const CreateReportTemplateScreen({super.key});

  @override
  State<CreateReportTemplateScreen> createState() =>
      _CreateReportTemplateScreenState();
}

class _CreateReportTemplateScreenState
    extends State<CreateReportTemplateScreen> {
  final _templateNameController = TextEditingController();
  List<Bay> _availableBays = [];
  List<ReadingTemplate> _allReadingTemplates = [];
  List<ReadingField> _filteredReadingFields = [];
  List<String> _selectedBayIds = [];
  List<String> _selectedReadingFieldNames = [];
  ReportFrequency _selectedFrequency = ReportFrequency.daily;
  List<CustomReportColumn> _customColumns = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchInitialData();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: _buildAppBar(theme),
      body: _isLoading ? _buildLoadingState() : _buildMainContent(theme),
    );
  }

  PreferredSizeWidget _buildAppBar(ThemeData theme) {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      title: Text(
        'Create Report Template',
        style: TextStyle(
          color: theme.colorScheme.onSurface,
          fontSize: 18,
          fontWeight: FontWeight.w500,
        ),
      ),
      leading: IconButton(
        icon: Icon(Icons.arrow_back, color: theme.colorScheme.onSurface),
        onPressed: () => Navigator.pop(context),
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Center(child: CircularProgressIndicator());
  }

  Widget _buildMainContent(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTemplateNameSection(theme),
          const SizedBox(height: 24),
          _buildBaySelectionSection(theme),
          const SizedBox(height: 24),
          _buildReadingFieldsSection(theme),
          const SizedBox(height: 24),
          _buildFrequencySection(theme),
          const SizedBox(height: 24),
          _buildCustomColumnsSection(theme),
          const SizedBox(height: 32),
          _buildSaveButton(theme),
        ],
      ),
    );
  }

  Widget _buildTemplateNameSection(ThemeData theme) {
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
                  Icons.description,
                  color: theme.colorScheme.primary,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Template Information',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _templateNameController,
            decoration: const InputDecoration(
              labelText: 'Report Template Name',
              hintText: 'e.g., Daily Transformer Report',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBaySelectionSection(ThemeData theme) {
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
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(
                  Icons.electrical_services,
                  color: Colors.blue,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Bay Selection',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          if (_availableBays.isEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Center(
                child: Text(
                  'No bays available for the selected substation.',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              ),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _availableBays.map((bay) {
                final isSelected = _selectedBayIds.contains(bay.id);
                return FilterChip(
                  label: Text(
                    '${bay.name} (${bay.bayType})',
                    style: const TextStyle(fontSize: 12),
                  ),
                  selected: isSelected,
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        _selectedBayIds.add(bay.id!);
                      } else {
                        _selectedBayIds.remove(bay.id!);
                      }
                      _filterReadingFields();
                    });
                  },
                  selectedColor: _getBayTypeColor(bay.bayType).withOpacity(0.2),
                  checkmarkColor: _getBayTypeColor(bay.bayType),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildReadingFieldsSection(ThemeData theme) {
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
              Text(
                'Reading Fields',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          if (_selectedBayIds.isEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Center(
                child: Text(
                  'Select bays to see available reading fields.',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              ),
            )
          else if (_filteredReadingFields.isEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning_amber, color: Colors.orange.shade700),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'No reading fields available for the selected bay types.',
                      style: TextStyle(color: Colors.orange.shade700),
                    ),
                  ),
                ],
              ),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _filteredReadingFields.map((field) {
                final isSelected = _selectedReadingFieldNames.contains(
                  field.name,
                );
                return FilterChip(
                  label: Text(
                    field.unit != null && field.unit!.isNotEmpty
                        ? '${field.name} (${field.unit})'
                        : field.name,
                    style: const TextStyle(fontSize: 12),
                  ),
                  selected: isSelected,
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        _selectedReadingFieldNames.add(field.name);
                      } else {
                        _selectedReadingFieldNames.remove(field.name);
                      }
                    });
                  },
                  selectedColor: _getFieldTypeColor(
                    field.dataType,
                  ).withOpacity(0.2),
                  checkmarkColor: _getFieldTypeColor(field.dataType),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildFrequencySection(ThemeData theme) {
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
                  color: Colors.purple.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(
                  Icons.schedule,
                  color: Colors.purple,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Report Frequency',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          Column(
            children: ReportFrequency.values
                .where((freq) => freq != ReportFrequency.onDemand)
                .map(
                  (freq) => RadioListTile<ReportFrequency>(
                    title: Text(freq.toShortString().capitalize()),
                    value: freq,
                    groupValue: _selectedFrequency,
                    onChanged: (value) =>
                        setState(() => _selectedFrequency = value!),
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomColumnsSection(ThemeData theme) {
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
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(
                  Icons.view_column,
                  color: Colors.orange,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Custom Columns',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed:
                    _selectedBayIds.isEmpty || _filteredReadingFields.isEmpty
                    ? null
                    : _addCustomColumn,
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Add Column'),
              ),
            ],
          ),
          const SizedBox(height: 16),

          if (_customColumns.isEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Center(
                child: Text(
                  'No custom columns added yet.',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              ),
            )
          else
            ..._customColumns.asMap().entries.map((entry) {
              final index = entry.key;
              final column = entry.value;
              return _buildCustomColumnCard(column, index, theme);
            }).toList(),
        ],
      ),
    );
  }

  Widget _buildCustomColumnCard(
    CustomReportColumn column,
    int index,
    ThemeData theme,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  column.columnName,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Base: ${column.baseReadingFieldId}',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
                if (column.secondaryReadingFieldId != null)
                  Text(
                    'Secondary: ${column.secondaryReadingFieldId}',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                Text(
                  'Operation: ${column.operation.toShortString().capitalize()}',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => setState(() => _customColumns.removeAt(index)),
            icon: Icon(Icons.delete_outline, color: theme.colorScheme.error),
          ),
        ],
      ),
    );
  }

  Widget _buildSaveButton(ThemeData theme) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _saveReportTemplate,
        style: ElevatedButton.styleFrom(
          backgroundColor: theme.colorScheme.primary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: _isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Text(
                'Save Report Template',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
      ),
    );
  }

  // Helper methods
  Color _getBayTypeColor(String bayType) {
    switch (bayType.toLowerCase()) {
      case 'transformer':
        return Colors.orange;
      case 'line':
        return Colors.blue;
      case 'feeder':
        return Colors.green;
      case 'capacitor bank':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  Color _getFieldTypeColor(ReadingFieldDataType dataType) {
    switch (dataType) {
      case ReadingFieldDataType.number:
        return Colors.blue;
      case ReadingFieldDataType.text:
        return Colors.green;
      case ReadingFieldDataType.boolean:
        return Colors.orange;
      case ReadingFieldDataType.date:
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  void _filterReadingFields() {
    // Implementation remains the same
  }

  void _addCustomColumn() {
    showDialog(
      context: context,
      builder: (ctx) => AddCustomColumnDialog(
        availableReadingFields: _filteredReadingFields,
        onAdd: (column) => setState(() => _customColumns.add(column)),
      ),
    );
  }

  Future<void> _fetchInitialData() async {
    // Implementation remains the same
  }

  Future<void> _saveReportTemplate() async {
    // Implementation remains the same
  }

  @override
  void dispose() {
    _templateNameController.dispose();
    super.dispose();
  }
}

// Custom Column Dialog with improved styling
class AddCustomColumnDialog extends StatefulWidget {
  final List<ReadingField> availableReadingFields;
  final Function(CustomReportColumn) onAdd;

  const AddCustomColumnDialog({
    super.key,
    required this.availableReadingFields,
    required this.onAdd,
  });

  @override
  State<AddCustomColumnDialog> createState() => _AddCustomColumnDialogState();
}

class _AddCustomColumnDialogState extends State<AddCustomColumnDialog> {
  final _columnNameController = TextEditingController();
  ReadingField? _selectedBaseField;
  ReadingField? _selectedSecondaryField;
  MathOperation _selectedOperation = MathOperation.none;
  final _operandValueController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        width: 500,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Add Custom Column',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 20),

            TextField(
              controller: _columnNameController,
              decoration: const InputDecoration(
                labelText: 'Column Name',
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 16),

            DropdownButtonFormField<ReadingField>(
              value: _selectedBaseField,
              decoration: const InputDecoration(
                labelText: 'Base Reading Field',
                border: OutlineInputBorder(),
              ),
              items: widget.availableReadingFields
                  .map(
                    (field) => DropdownMenuItem(
                      value: field,
                      child: Text(
                        field.unit != null && field.unit!.isNotEmpty
                            ? '${field.name} (${field.unit})'
                            : field.name,
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (field) => setState(() => _selectedBaseField = field),
            ),

            const SizedBox(height: 16),

            DropdownButtonFormField<MathOperation>(
              value: _selectedOperation,
              decoration: const InputDecoration(
                labelText: 'Operation',
                border: OutlineInputBorder(),
              ),
              items: MathOperation.values
                  .map(
                    (op) => DropdownMenuItem(
                      value: op,
                      child: Text(op.toShortString().capitalize()),
                    ),
                  )
                  .toList(),
              onChanged: (op) => setState(() => _selectedOperation = op!),
            ),

            if (_showSecondaryField()) ...[
              const SizedBox(height: 16),
              DropdownButtonFormField<ReadingField>(
                value: _selectedSecondaryField,
                decoration: const InputDecoration(
                  labelText: 'Secondary Reading Field',
                  border: OutlineInputBorder(),
                ),
                items: widget.availableReadingFields
                    .where((field) => field != _selectedBaseField)
                    .map(
                      (field) => DropdownMenuItem(
                        value: field,
                        child: Text(
                          field.unit != null && field.unit!.isNotEmpty
                              ? '${field.name} (${field.unit})'
                              : field.name,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (field) =>
                    setState(() => _selectedSecondaryField = field),
              ),
            ],

            if (_showOperandValue()) ...[
              const SizedBox(height: 16),
              TextField(
                controller: _operandValueController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Operand Value',
                  hintText: 'Enter a number for constant operations',
                  border: OutlineInputBorder(),
                ),
              ),
            ],

            const SizedBox(height: 24),

            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: _validateAndAdd,
                  child: const Text('Add Column'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  bool _showSecondaryField() {
    return [
      MathOperation.add,
      MathOperation.subtract,
      MathOperation.multiply,
      MathOperation.divide,
    ].contains(_selectedOperation);
  }

  bool _showOperandValue() {
    return ![
          MathOperation.max,
          MathOperation.min,
          MathOperation.sum,
          MathOperation.average,
          MathOperation.none,
        ].contains(_selectedOperation) &&
        _selectedSecondaryField == null;
  }

  void _validateAndAdd() {
    if (_columnNameController.text.trim().isEmpty) {
      SnackBarUtils.showSnackBar(context, 'Column name cannot be empty.');
      return;
    }

    if (_selectedBaseField == null) {
      SnackBarUtils.showSnackBar(
        context,
        'Please select a base reading field.',
      );
      return;
    }

    widget.onAdd(
      CustomReportColumn(
        columnName: _columnNameController.text.trim(),
        baseReadingFieldId: _selectedBaseField!.name,
        secondaryReadingFieldId: _selectedSecondaryField?.name,
        operation: _selectedOperation,
        operandValue: _operandValueController.text.trim().isEmpty
            ? null
            : _operandValueController.text.trim(),
      ),
    );

    Navigator.pop(context);
  }

  @override
  void dispose() {
    _columnNameController.dispose();
    _operandValueController.dispose();
    super.dispose();
  }
}

// Extensions
extension StringExtension on String {
  String capitalize() {
    if (isEmpty) return '';
    return "${this[0].toUpperCase()}${substring(1)}";
  }
}

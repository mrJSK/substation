// lib/screens/report_template_designer_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/report_template_models.dart';
import '../services/report_template_service.dart';
import '../services/field_discovery_service.dart';
import '../utils/snackbar_utils.dart';

class ReportTemplateDesignerScreen extends StatefulWidget {
  final String? templateId;
  final String currentUserId;

  const ReportTemplateDesignerScreen({
    Key? key,
    this.templateId,
    required this.currentUserId,
  }) : super(key: key);

  @override
  _ReportTemplateDesignerScreenState createState() =>
      _ReportTemplateDesignerScreenState();
}

class _ReportTemplateDesignerScreenState
    extends State<ReportTemplateDesignerScreen> {
  final ReportTemplateService _templateService = ReportTemplateService();
  final FieldDiscoveryService _fieldService = FieldDiscoveryService();

  bool _isLoading = true;
  bool _isSaving = false;

  ReportTemplate? _template;
  Map<String, List<AvailableField>> _availableFields = {};

  String _selectedDataSourceId = '';
  HeaderCell? _selectedHeaderCell;
  DynamicFieldMapping? _selectedFieldMapping;

  final TextEditingController _templateNameController = TextEditingController();
  final TextEditingController _templateDescriptionController =
      TextEditingController();

  @override
  void initState() {
    super.initState();
    _initializeTemplate();
  }

  @override
  void dispose() {
    _templateNameController.dispose();
    _templateDescriptionController.dispose();
    super.dispose();
  }

  Future<void> _initializeTemplate() async {
    setState(() => _isLoading = true);

    try {
      await _loadAvailableFields();

      if (widget.templateId != null) {
        _template = await _templateService.getTemplate(widget.templateId!);
        _templateNameController.text = _template!.name;
        _templateDescriptionController.text = _template!.description;
      } else {
        _createNewTemplate();
      }
    } catch (e) {
      if (mounted) {
        SnackBarUtils.showSnackBar(
          context,
          'Error loading template: $e',
          isError: true,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _createNewTemplate() {
    _template = ReportTemplate(
      id: '',
      name: 'New Report Template',
      description: '',
      createdAt: DateTime.now(),
      createdBy: widget.currentUserId,
      dataSources: [],
      headerLevels: [
        HeaderLevel(
          level: 0,
          cells: List.generate(
            6,
            (index) => HeaderCell(
              id: 'header_0_$index',
              text: '',
              colspan: 1,
              rowspan: 1,
              style: HeaderCellStyle(),
              columnIndex: index,
              rowIndex: 0,
            ),
          ),
        ),
      ],
      fieldMappings: {},
      computedColumns: [],
      formatting: ReportFormatting(),
      periodConfig: PeriodConfiguration(),
    );

    _templateNameController.text = _template!.name;
    _templateDescriptionController.text = _template!.description;
  }

  Future<void> _loadAvailableFields() async {
    _availableFields = await _fieldService.loadAllAvailableFields(
      widget.currentUserId,
    );
    if (_availableFields.isNotEmpty) {
      _selectedDataSourceId = _availableFields.keys.first;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: _buildAppBar(),
      body: _buildResponsiveLayout(),
      bottomNavigationBar: _buildActionBar(),
    );
  }

  Widget _buildResponsiveLayout() {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth > 1200) {
          return _buildDesktopLayout();
        } else if (constraints.maxWidth > 800) {
          return _buildTabletLayout();
        } else {
          return _buildMobileLayout();
        }
      },
    );
  }

  Widget _buildDesktopLayout() {
    return Row(
      children: [
        Expanded(flex: 25, child: _buildDataSourcePanel()),
        Expanded(flex: 50, child: _buildVisualDesigner()),
        Expanded(flex: 25, child: _buildPropertiesPanel()),
      ],
    );
  }

  Widget _buildTabletLayout() {
    return Column(
      children: [
        Expanded(
          flex: 30,
          child: Row(
            children: [
              Expanded(child: _buildDataSourcePanel()),
              Expanded(child: _buildPropertiesPanel()),
            ],
          ),
        ),
        Expanded(flex: 70, child: _buildVisualDesigner()),
      ],
    );
  }

  Widget _buildMobileLayout() {
    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.data_usage), text: 'Fields'),
              Tab(icon: Icon(Icons.design_services), text: 'Design'),
              Tab(icon: Icon(Icons.settings), text: 'Properties'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildDataSourcePanel(),
                _buildVisualDesigner(),
                _buildPropertiesPanel(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: Text(_template?.name ?? 'Report Template Designer'),
      actions: [
        IconButton(
          onPressed: _previewTemplate,
          icon: const Icon(Icons.preview),
          tooltip: 'Preview',
        ),
        IconButton(
          onPressed: _saveTemplate,
          icon: _isSaving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.save),
          tooltip: 'Save Template',
        ),
      ],
    );
  }

  Widget _buildDataSourcePanel() {
    return Container(
      color: Colors.grey.shade50,
      child: Column(
        children: [
          _buildDataSourceSelector(),
          Expanded(child: _buildFieldsList()),
          _buildCustomFieldActions(),
        ],
      ),
    );
  }

  Widget _buildDataSourceSelector() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: DropdownButtonFormField<String>(
        value: _selectedDataSourceId.isEmpty ? null : _selectedDataSourceId,
        decoration: const InputDecoration(
          labelText: 'Data Source',
          border: OutlineInputBorder(),
        ),
        items: _availableFields.keys
            .map(
              (sourceId) => DropdownMenuItem(
                value: sourceId,
                child: Text(_formatDataSourceName(sourceId)),
              ),
            )
            .toList(),
        onChanged: (value) {
          setState(() {
            _selectedDataSourceId = value ?? '';
          });
        },
      ),
    );
  }

  Widget _buildFieldsList() {
    final fields = _availableFields[_selectedDataSourceId] ?? [];

    return ListView.builder(
      itemCount: fields.length,
      itemBuilder: (context, index) {
        final field = fields[index];
        return _buildFieldItem(field);
      },
    );
  }

  Widget _buildFieldItem(AvailableField field) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        dense: true,
        leading: Icon(
          _getFieldOriginIcon(field.origin),
          color: _getFieldOriginColor(field.origin),
          size: 16,
        ),
        title: Text(field.name, style: const TextStyle(fontSize: 13)),
        subtitle: Text(
          field.description ?? field.path,
          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
        ),
        trailing: _buildFieldTypeChip(field.type),
        onTap: () => _selectField(field),
      ),
    );
  }

  Widget _buildFieldTypeChip(DataType type) {
    final typeInfo = _getDataTypeInfo(type);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: typeInfo['color'].withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        typeInfo['label'],
        style: TextStyle(
          fontSize: 10,
          color: typeInfo['color'],
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildVisualDesigner() {
    return Container(
      color: Colors.white,
      child: Column(
        children: [
          _buildDesignerToolbar(),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  _buildReportTitle(),
                  _buildHeaderDesigner(),
                  _buildDataRowsPreview(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesignerToolbar() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: _undoAction,
            icon: const Icon(Icons.undo),
            tooltip: 'Undo',
          ),
          IconButton(
            onPressed: _redoAction,
            icon: const Icon(Icons.redo),
            tooltip: 'Redo',
          ),
          const VerticalDivider(),
          ElevatedButton.icon(
            onPressed: _addHeaderLevel,
            icon: const Icon(Icons.add, size: 16),
            label: const Text('Add Header Level'),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            onPressed: _selectedHeaderCell != null ? _mergeSelectedCells : null,
            icon: const Icon(Icons.merge, size: 16),
            label: const Text('Merge Cells'),
          ),
        ],
      ),
    );
  }

  Widget _buildReportTitle() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          TextFormField(
            controller: _templateNameController,
            decoration: const InputDecoration(
              labelText: 'Report Title',
              border: OutlineInputBorder(),
            ),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            onChanged: (value) {
              if (_template != null) {
                _template = _template!.copyWith(name: value);
              }
            },
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _templateDescriptionController,
            decoration: const InputDecoration(
              labelText: 'Report Subtitle (Optional)',
              border: OutlineInputBorder(),
            ),
            onChanged: (value) {
              if (_template != null) {
                _template = _template!.copyWith(description: value);
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderDesigner() {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [Container(height: 200, child: _buildHeaderGrid())],
      ),
    );
  }

  Widget _buildHeaderGrid() {
    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 6,
        childAspectRatio: 3,
      ),
      itemCount: _getMaxHeaderCells(),
      itemBuilder: (context, index) {
        return _buildHeaderCellWidget(index);
      },
    );
  }

  Widget _buildHeaderCellWidget(int index) {
    final cell = _getHeaderCellByIndex(index);
    final isSelected = _selectedHeaderCell?.id == cell.id;

    return GestureDetector(
      onTap: () => _selectHeaderCell(cell),
      child: Container(
        margin: const EdgeInsets.all(1),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue.shade100 : Colors.white,
          border: Border.all(
            color: isSelected ? Colors.blue : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Center(
          child: Text(
            cell.text.isEmpty ? 'Header ${index + 1}' : cell.text,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: cell.text.isEmpty ? Colors.grey.shade400 : Colors.black,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }

  Widget _buildDataRowsPreview() {
    return Container(
      margin: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Data Rows Preview',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Container(
            height: 200,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
            ),
            child: _buildDataPreviewTable(),
          ),
        ],
      ),
    );
  }

  Widget _buildDataPreviewTable() {
    if (_template?.fieldMappings.isEmpty ?? true) {
      return const Center(
        child: Text(
          'Select fields from the left panel to preview data rows',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: _template!.fieldMappings.values
            .where((mapping) => mapping.isVisible)
            .map((mapping) => DataColumn(label: Text(mapping.displayName)))
            .toList(),
        rows: List.generate(
          3,
          (index) => DataRow(
            cells: _template!.fieldMappings.values
                .where((mapping) => mapping.isVisible)
                .map((mapping) => DataCell(Text('Sample Data ${index + 1}')))
                .toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildPropertiesPanel() {
    return Container(
      color: Colors.grey.shade50,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4),
              ],
            ),
            child: const Text(
              'Properties',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: _buildPropertiesContent(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPropertiesContent() {
    if (_selectedHeaderCell != null) {
      return _buildHeaderCellProperties();
    } else if (_selectedFieldMapping != null) {
      return _buildFieldMappingProperties();
    } else {
      return _buildTemplateProperties();
    }
  }

  Widget _buildHeaderCellProperties() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Header Cell Properties',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 16),

        TextFormField(
          initialValue: _selectedHeaderCell!.text,
          decoration: const InputDecoration(
            labelText: 'Cell Text',
            border: OutlineInputBorder(),
          ),
          onChanged: (value) {
            setState(() {
              _selectedHeaderCell!.text = value;
            });
          },
        ),
        const SizedBox(height: 16),

        Row(
          children: [
            Expanded(
              child: TextFormField(
                initialValue: _selectedHeaderCell!.colspan.toString(),
                decoration: const InputDecoration(
                  labelText: 'Column Span',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                onChanged: (value) {
                  setState(() {
                    _selectedHeaderCell!.colspan = int.tryParse(value) ?? 1;
                  });
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextFormField(
                initialValue: _selectedHeaderCell!.rowspan.toString(),
                decoration: const InputDecoration(
                  labelText: 'Row Span',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                onChanged: (value) {
                  setState(() {
                    _selectedHeaderCell!.rowspan = int.tryParse(value) ?? 1;
                  });
                },
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),
        _buildHeaderCellStyleProperties(),
      ],
    );
  }

  Widget _buildHeaderCellStyleProperties() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Cell Style', style: TextStyle(fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),

        Row(
          children: [
            Expanded(
              child: ElevatedButton(
                onPressed: () => _showColorPicker(true),
                child: const Text('Background'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ElevatedButton(
                onPressed: () => _showColorPicker(false),
                child: const Text('Text Color'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        Row(
          children: [
            Expanded(
              child: CheckboxListTile(
                title: const Text('Bold'),
                value: _selectedHeaderCell!.style.bold,
                onChanged: (value) {
                  setState(() {
                    _selectedHeaderCell!.style.bold = value ?? false;
                  });
                },
              ),
            ),
            Expanded(
              child: CheckboxListTile(
                title: const Text('Italic'),
                value: _selectedHeaderCell!.style.italic,
                onChanged: (value) {
                  setState(() {
                    _selectedHeaderCell!.style.italic = value ?? false;
                  });
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFieldMappingProperties() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Field Mapping Properties',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 16),

        TextFormField(
          initialValue: _selectedFieldMapping!.displayName,
          decoration: const InputDecoration(
            labelText: 'Display Name',
            border: OutlineInputBorder(),
          ),
          onChanged: (value) {
            setState(() {
              _selectedFieldMapping!.displayName = value;
            });
          },
        ),
        const SizedBox(height: 16),

        if (_selectedFieldMapping!.origin == FieldOrigin.computed)
          _buildFormulaEditor(),

        const SizedBox(height: 16),
        _buildFormatSelector(),
      ],
    );
  }

  Widget _buildFormulaEditor() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Formula', style: TextStyle(fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),

        TextFormField(
          initialValue: _selectedFieldMapping!.formula ?? '',
          decoration: const InputDecoration(
            hintText: 'e.g., SUM(Import_Energy) - SUM(Export_Energy)',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
          onChanged: (value) {
            setState(() {
              _selectedFieldMapping!.formula = value;
            });
          },
        ),
        const SizedBox(height: 8),

        Wrap(
          spacing: 4,
          children: ['SUM', 'AVG', 'COUNT', 'MAX', 'MIN', 'IF']
              .map(
                (func) => ActionChip(
                  label: Text(func, style: const TextStyle(fontSize: 10)),
                  onPressed: () => _insertFormulaFunction(func),
                ),
              )
              .toList(),
        ),
      ],
    );
  }

  Widget _buildFormatSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Number Format',
          style: TextStyle(fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),

        DropdownButtonFormField<String>(
          value: _selectedFieldMapping!.format.isEmpty
              ? null
              : _selectedFieldMapping!.format,
          decoration: const InputDecoration(border: OutlineInputBorder()),
          items: const [
            DropdownMenuItem(value: '0.00', child: Text('0.00')),
            DropdownMenuItem(value: '0,000.00', child: Text('0,000.00')),
            DropdownMenuItem(value: '0.0%', child: Text('0.0%')),
            DropdownMenuItem(value: 'dd/MM/yyyy', child: Text('dd/MM/yyyy')),
          ],
          onChanged: (value) {
            setState(() {
              _selectedFieldMapping!.format = value ?? '0.00';
            });
          },
        ),
      ],
    );
  }

  Widget _buildTemplateProperties() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Template Properties',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 16),

        TextFormField(
          controller: _templateNameController,
          decoration: const InputDecoration(
            labelText: 'Template Name',
            border: OutlineInputBorder(),
          ),
          onChanged: (value) {
            if (_template != null) {
              _template = _template!.copyWith(name: value);
            }
          },
        ),
        const SizedBox(height: 16),

        TextFormField(
          controller: _templateDescriptionController,
          decoration: const InputDecoration(
            labelText: 'Description',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
          onChanged: (value) {
            if (_template != null) {
              _template = _template!.copyWith(description: value);
            }
          },
        ),
      ],
    );
  }

  Widget _buildCustomFieldActions() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: ElevatedButton.icon(
        onPressed: _createCustomField,
        icon: const Icon(Icons.add, size: 16),
        label: const Text('Add Custom Field'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green,
          foregroundColor: Colors.white,
        ),
      ),
    );
  }

  Widget _buildActionBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          ElevatedButton(
            onPressed: _previewTemplate,
            child: const Text('Preview'),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: _isSaving ? null : _saveTemplate,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: _isSaving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text('Save Template'),
          ),
          const Spacer(),
          ElevatedButton(
            onPressed: _testGenerateReport,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
            child: const Text('Test Generate'),
          ),
        ],
      ),
    );
  }

  // Helper Methods
  String _formatDataSourceName(String sourceId) {
    return sourceId[0].toUpperCase() + sourceId.substring(1);
  }

  Color _getFieldOriginColor(FieldOrigin origin) {
    switch (origin) {
      case FieldOrigin.standard:
        return Colors.blue;
      case FieldOrigin.custom:
        return Colors.green;
      case FieldOrigin.computed:
        return Colors.orange;
    }
  }

  IconData _getFieldOriginIcon(FieldOrigin origin) {
    switch (origin) {
      case FieldOrigin.standard:
        return Icons.settings;
      case FieldOrigin.custom:
        return Icons.person;
      case FieldOrigin.computed:
        return Icons.functions;
    }
  }

  Map<String, dynamic> _getDataTypeInfo(DataType type) {
    switch (type) {
      case DataType.string:
        return {'label': 'Text', 'color': Colors.blue};
      case DataType.number:
        return {'label': 'Number', 'color': Colors.green};
      case DataType.boolean:
        return {'label': 'Yes/No', 'color': Colors.orange};
      case DataType.date:
        return {'label': 'Date', 'color': Colors.purple};
      case DataType.enum_:
        return {'label': 'Choice', 'color': Colors.teal};
      case DataType.object:
        return {'label': 'Object', 'color': Colors.grey};
    }
  }

  int _getMaxHeaderCells() {
    if (_template?.headerLevels.isEmpty ?? true) return 0;
    return _template!.headerLevels.first.cells.length;
  }

  HeaderCell _getHeaderCellByIndex(int index) {
    if (_template?.headerLevels.isEmpty ?? true) {
      return HeaderCell(
        id: 'cell_$index',
        text: '',
        colspan: 1,
        rowspan: 1,
        style: HeaderCellStyle(),
        columnIndex: index,
        rowIndex: 0,
      );
    }

    if (index < _template!.headerLevels.first.cells.length) {
      return _template!.headerLevels.first.cells[index];
    }

    return HeaderCell(
      id: 'cell_$index',
      text: '',
      colspan: 1,
      rowspan: 1,
      style: HeaderCellStyle(),
      columnIndex: index,
      rowIndex: 0,
    );
  }

  // Action Methods
  void _selectField(AvailableField field) {
    final mapping = DynamicFieldMapping(
      fieldId: field.id,
      displayName: field.name,
      sourcePath: field.path,
      dataType: field.type,
      origin: field.origin,
      format: '0.00',
      columnIndex: _template?.fieldMappings.length ?? 0,
    );

    setState(() {
      _selectedFieldMapping = mapping;
      _template?.fieldMappings[field.id] = mapping;
    });
  }

  void _selectHeaderCell(HeaderCell cell) {
    setState(() {
      _selectedHeaderCell = cell;
      _selectedFieldMapping = null;
    });
  }

  void _addHeaderLevel() {
    if (_template == null) return;

    final newLevel = HeaderLevel(
      level: _template!.headerLevels.length,
      cells: List.generate(
        6,
        (index) => HeaderCell(
          id: 'header_${_template!.headerLevels.length}_$index',
          text: '',
          colspan: 1,
          rowspan: 1,
          style: HeaderCellStyle(),
          columnIndex: index,
          rowIndex: _template!.headerLevels.length,
        ),
      ),
    );

    setState(() {
      _template!.headerLevels.add(newLevel);
    });
  }

  void _mergeSelectedCells() {
    // Implement cell merging logic
    if (_selectedHeaderCell != null) {
      setState(() {
        _selectedHeaderCell!.colspan = 2;
      });
    }
  }

  void _insertFormulaFunction(String function) {
    // Implement formula function insertion
  }

  void _createCustomField() {
    // Show dialog to create custom field
  }

  void _showColorPicker(bool isBackground) {
    // Show color picker dialog
  }

  void _previewTemplate() {
    // Show preview dialog
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Template Preview'),
        content: const Text('Preview functionality will be implemented here'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _saveTemplate() async {
    if (_template == null) return;

    setState(() => _isSaving = true);

    try {
      if (_template!.id.isEmpty) {
        final templateId = await _templateService.createTemplate(_template!);
        _template = _template!.copyWith(id: templateId);
        if (mounted) {
          SnackBarUtils.showSnackBar(context, 'Template created successfully!');
        }
      } else {
        await _templateService.updateTemplate(_template!);
        if (mounted) {
          SnackBarUtils.showSnackBar(context, 'Template updated successfully!');
        }
      }
    } catch (e) {
      if (mounted) {
        SnackBarUtils.showSnackBar(
          context,
          'Error saving template: $e',
          isError: true,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  void _testGenerateReport() {
    // Navigate to test report generation
    SnackBarUtils.showSnackBar(
      context,
      'Test report generation feature coming soon!',
    );
  }

  void _undoAction() {
    // Implement undo
  }

  void _redoAction() {
    // Implement redo
  }
}

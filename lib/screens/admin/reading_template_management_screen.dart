// lib/screens/admin/reading_template_management_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async'; // For debouncing
import '../../models/reading_models.dart';
import '../../models/bay_model.dart';
import '../../utils/snackbar_utils.dart';

enum ReadingTemplateViewMode { list, form }

class ReadingTemplateManagementScreen extends StatefulWidget {
  const ReadingTemplateManagementScreen({super.key});

  @override
  State<ReadingTemplateManagementScreen> createState() =>
      _ReadingTemplateManagementScreenState();
}

class _ReadingTemplateManagementScreenState
    extends State<ReadingTemplateManagementScreen> {
  ReadingTemplateViewMode _viewMode = ReadingTemplateViewMode.list;
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  ReadingTemplate? _templateToEdit;
  List<ReadingTemplate> _templates = [];
  bool _isLoading = true;
  bool _isSaving = false;

  String? _selectedBayType;
  List<Map<String, dynamic>> _templateReadingFields = [];

  final List<String> _dataTypes = ReadingFieldDataType.values
      .map((e) => e.toString().split('.').last)
      .toList();
  final List<String> _frequencies = ReadingFrequency.values
      .map((e) => e.toString().split('.').last)
      .toList();

  final List<String> _bayTypes = [
    'Transformer',
    'Line',
    'Feeder',
    'Capacitor Bank',
    'Reactor',
    'Bus Coupler',
    'Battery',
    'Busbar',
  ];

  final List<ReadingField> _defaultEnergyFields = [
    ReadingField(
      name: 'Previous Day Reading (Import)',
      dataType: ReadingFieldDataType.number,
      isMandatory: true,
      unit: 'MWH',
      frequency: ReadingFrequency.daily,
    ),
    ReadingField(
      name: 'Current Day Reading (Import)',
      dataType: ReadingFieldDataType.number,
      isMandatory: true,
      unit: 'MWH',
      frequency: ReadingFrequency.daily,
    ),
    ReadingField(
      name: 'Previous Day Reading (Export)',
      dataType: ReadingFieldDataType.number,
      isMandatory: true,
      unit: 'MWH',
      frequency: ReadingFrequency.daily,
    ),
    ReadingField(
      name: 'Current Day Reading (Export)',
      dataType: ReadingFieldDataType.number,
      isMandatory: true,
      unit: 'MWH',
      frequency: ReadingFrequency.daily,
    ),
    ReadingField(
      name: 'Previous Month Reading (Import)',
      dataType: ReadingFieldDataType.number,
      isMandatory: true,
      unit: 'MWH',
      frequency: ReadingFrequency.monthly,
    ),
    ReadingField(
      name: 'Current Month Reading (Import)',
      dataType: ReadingFieldDataType.number,
      isMandatory: true,
      unit: 'MWH',
      frequency: ReadingFrequency.monthly,
    ),
    ReadingField(
      name: 'Previous Month Reading (Export)',
      dataType: ReadingFieldDataType.number,
      isMandatory: true,
      unit: 'MWH',
      frequency: ReadingFrequency.monthly,
    ),
    ReadingField(
      name: 'Current Month Reading (Export)',
      dataType: ReadingFieldDataType.number,
      isMandatory: true,
      unit: 'MWH',
      frequency: ReadingFrequency.monthly,
    ),
  ];

  final Map<String, List<ReadingField>> _defaultHourlyFields = {
    'Feeder': [
      ReadingField(
        name: 'Current',
        unit: 'A',
        dataType: ReadingFieldDataType.number,
        isMandatory: true,
        frequency: ReadingFrequency.hourly,
      ),
    ],
    'Transformer': [
      ReadingField(
        name: 'Current',
        unit: 'A',
        dataType: ReadingFieldDataType.number,
        isMandatory: true,
        frequency: ReadingFrequency.hourly,
      ),
      ReadingField(
        name: 'Power Factor',
        unit: '',
        dataType: ReadingFieldDataType.number,
        isMandatory: true,
        frequency: ReadingFrequency.hourly,
      ),
      ReadingField(
        name: 'Real Power (MW)',
        unit: 'MW',
        dataType: ReadingFieldDataType.number,
        isMandatory: true,
        frequency: ReadingFrequency.hourly,
      ),
      ReadingField(
        name: 'Voltage',
        unit: 'kV',
        dataType: ReadingFieldDataType.number,
        isMandatory: true,
        frequency: ReadingFrequency.hourly,
      ),
      ReadingField(
        name: 'Apparent Power (MVAR)',
        unit: 'MVAR',
        dataType: ReadingFieldDataType.number,
        isMandatory: true,
        frequency: ReadingFrequency.hourly,
      ),
      ReadingField(
        name: 'Gas Pressure (SF6)',
        unit: 'kg/cm2',
        dataType: ReadingFieldDataType.number,
        isMandatory: false,
        frequency: ReadingFrequency.hourly,
      ),
      ReadingField(
        name: 'Winding Temperature',
        unit: 'Celsius',
        dataType: ReadingFieldDataType.number,
        isMandatory: true,
        frequency: ReadingFrequency.hourly,
      ),
      ReadingField(
        name: 'Oil Temperature',
        unit: 'Celsius',
        dataType: ReadingFieldDataType.number,
        isMandatory: true,
        frequency: ReadingFrequency.hourly,
      ),
      ReadingField(
        name: 'Tap Position',
        unit: 'No.',
        dataType: ReadingFieldDataType.number,
        isMandatory: true,
        frequency: ReadingFrequency.hourly,
      ),
      ReadingField(
        name: 'Frequency',
        unit: 'Hz',
        dataType: ReadingFieldDataType.number,
        isMandatory: true,
        frequency: ReadingFrequency.hourly,
      ),
    ],
    'Line': [
      ReadingField(
        name: 'Current',
        unit: 'A',
        dataType: ReadingFieldDataType.number,
        isMandatory: true,
        frequency: ReadingFrequency.hourly,
      ),
      ReadingField(
        name: 'Power Factor',
        unit: '',
        dataType: ReadingFieldDataType.number,
        isMandatory: true,
        frequency: ReadingFrequency.hourly,
      ),
      ReadingField(
        name: 'Real Power (MW)',
        unit: 'MW',
        dataType: ReadingFieldDataType.number,
        isMandatory: true,
        frequency: ReadingFrequency.hourly,
      ),
      ReadingField(
        name: 'Voltage',
        unit: 'kV',
        dataType: ReadingFieldDataType.number,
        isMandatory: true,
        frequency: ReadingFrequency.hourly,
      ),
      ReadingField(
        name: 'Apparent Power (MVAR)',
        unit: 'MVAR',
        dataType: ReadingFieldDataType.number,
        isMandatory: true,
        frequency: ReadingFrequency.hourly,
      ),
      ReadingField(
        name: 'Gas Pressure (SF6)',
        unit: 'kg/cm2',
        dataType: ReadingFieldDataType.number,
        isMandatory: false,
        frequency: ReadingFrequency.hourly,
      ),
    ],
    'Capacitor Bank': [
      ReadingField(
        name: 'Current',
        unit: 'A',
        dataType: ReadingFieldDataType.number,
        isMandatory: true,
        frequency: ReadingFrequency.hourly,
      ),
      ReadingField(
        name: 'Power Factor',
        unit: '',
        dataType: ReadingFieldDataType.number,
        isMandatory: true,
        frequency: ReadingFrequency.hourly,
      ),
    ],
    'Battery': [
      ReadingField(
        name: 'Voltage',
        unit: 'V',
        dataType: ReadingFieldDataType.number,
        isMandatory: true,
        frequency: ReadingFrequency.hourly,
      ),
      ReadingField(
        name: 'Current',
        unit: 'A',
        dataType: ReadingFieldDataType.number,
        isMandatory: true,
        frequency: ReadingFrequency.hourly,
      ),
    ],
    'Busbar': [
      ReadingField(
        name: 'Voltage',
        unit: 'kV',
        dataType: ReadingFieldDataType.number,
        isMandatory: true,
        frequency: ReadingFrequency.hourly,
      ),
    ],
  };

  final Map<String, List<ReadingField>> _defaultDailyFields = {
    'Battery': List.generate(
      8,
      (i) => ReadingField(
        name: 'Cell ${i + 1}',
        dataType: ReadingFieldDataType.group,
        isMandatory: true,
        frequency: ReadingFrequency.daily,
        nestedFields: [
          ReadingField(
            name: 'Cell Number',
            dataType: ReadingFieldDataType.number,
            isMandatory: true,
          ),
          ReadingField(
            name: 'Voltage',
            unit: 'V',
            dataType: ReadingFieldDataType.number,
            isMandatory: true,
          ),
          ReadingField(
            name: 'Specific Gravity',
            unit: '',
            dataType: ReadingFieldDataType.number,
            isMandatory: true,
          ),
        ],
      ),
    ),
  };

  final Map<String, List<ReadingField>> _defaultMonthlyFields = {
    'Battery': List.generate(
      55,
      (i) => ReadingField(
        name: 'Cell ${i + 1}',
        dataType: ReadingFieldDataType.group,
        isMandatory: true,
        frequency: ReadingFrequency.monthly,
        nestedFields: [
          ReadingField(
            name: 'Cell Number',
            dataType: ReadingFieldDataType.number,
            isMandatory: true,
          ),
          ReadingField(
            name: 'Voltage',
            unit: 'V',
            dataType: ReadingFieldDataType.number,
            isMandatory: true,
          ),
          ReadingField(
            name: 'Specific Gravity',
            unit: '',
            dataType: ReadingFieldDataType.number,
            isMandatory: true,
          ),
        ],
      ),
    ),
  };

  // Debounce timer for input fields
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _fetchReadingTemplates();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _fetchReadingTemplates() async {
    setState(() => _isLoading = true);
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('readingTemplates')
          .orderBy('bayType')
          .get();
      _templates = snapshot.docs
          .map((doc) => ReadingTemplate.fromFirestore(doc))
          .toList();
    } catch (e) {
      if (mounted)
        SnackBarUtils.showSnackBar(
          context,
          'Failed to load reading templates: $e',
          isError: true,
        );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showListView() {
    setState(() {
      _viewMode = ReadingTemplateViewMode.list;
      _templateToEdit = null;
      _selectedBayType = null;
      _templateReadingFields = [];
    });
    _fetchReadingTemplates();
  }

  void _showFormForNew() {
    setState(() {
      _viewMode = ReadingTemplateViewMode.form;
      _templateToEdit = null;
      _selectedBayType = null;
      _templateReadingFields = [];
    });
  }

  void _showFormForEdit(ReadingTemplate template) {
    setState(() {
      _viewMode = ReadingTemplateViewMode.form;
      _templateToEdit = template;
      _selectedBayType = template.bayType;
      _templateReadingFields = template.readingFields
          .map(
            (field) =>
                field.toMap()..['isDefault'] = _isDefaultField(field.name),
          )
          .toList();
    });
  }

  bool _isDefaultField(String fieldName) {
    if (_selectedBayType != 'Battery' &&
        _selectedBayType != 'Busbar' &&
        _defaultEnergyFields.any((field) => field.name == fieldName))
      return true;
    if (_selectedBayType != null) {
      if (_defaultHourlyFields[_selectedBayType]?.any(
            (field) => field.name == fieldName,
          ) ??
          false)
        return true;
      if (_defaultDailyFields[_selectedBayType]?.any(
            (field) => field.name == fieldName,
          ) ??
          false)
        return true;
      if (_defaultMonthlyFields[_selectedBayType]?.any(
            (field) => field.name == fieldName,
          ) ??
          false)
        return true;
    }
    return false;
  }

  void _onBayTypeSelected(String? newBayType) {
    setState(() {
      _selectedBayType = newBayType;
      _templateReadingFields.removeWhere(
        (field) => !(field['isDefault'] ?? false),
      );

      if (newBayType != null) {
        List<ReadingField> defaultFields = [];
        if (newBayType != 'Battery' && newBayType != 'Busbar') {
          defaultFields.addAll(_defaultEnergyFields);
        }
        defaultFields.addAll(_defaultHourlyFields[newBayType] ?? []);
        defaultFields.addAll(_defaultDailyFields[newBayType] ?? []);
        defaultFields.addAll(_defaultMonthlyFields[newBayType] ?? []);

        final defaultFieldsAsMaps = defaultFields
            .map((field) => field.toMap()..['isDefault'] = true)
            .toList();

        for (var defaultField in defaultFieldsAsMaps) {
          if (!_templateReadingFields.any(
            (existing) => existing['name'] == defaultField['name'],
          )) {
            _templateReadingFields.insert(0, defaultField);
          }
        }
      }
    });
  }

  void _addReadingField() {
    setState(() {
      _templateReadingFields.add({
        'name': '',
        'dataType': ReadingFieldDataType.text.toString().split('.').last,
        'unit': '',
        'options': [],
        'isMandatory': false,
        'frequency': ReadingFrequency.daily.toString().split('.').last,
        'description_remarks': '',
        'isDefault': false,
        'nestedFields': null,
      });
    });
  }

  void _addGroupReadingField() {
    setState(() {
      _templateReadingFields.add({
        'name': '',
        'dataType': ReadingFieldDataType.group.toString().split('.').last,
        'unit': '',
        'options': [],
        'isMandatory': false,
        'frequency': ReadingFrequency.daily.toString().split('.').last,
        'description_remarks': '',
        'isDefault': false,
        'nestedFields': <Map<String, dynamic>>[],
      });
    });
  }

  void _addNestedReadingField(Map<String, dynamic> groupField) {
    setState(() {
      (groupField['nestedFields'] as List<dynamic>).add({
        'name': '',
        'dataType': ReadingFieldDataType.text.toString().split('.').last,
        'unit': '',
        'options': [],
        'isMandatory': false,
        // No frequency for nested fields
        'description_remarks': '',
      });
    });
  }

  void _removeReadingField(int index) {
    setState(() {
      _templateReadingFields.removeAt(index);
    });
  }

  void _removeNestedReadingField(
    Map<String, dynamic> groupField,
    int nestedIndex,
  ) {
    setState(() {
      (groupField['nestedFields'] as List<dynamic>).removeAt(nestedIndex);
    });
  }

  Future<void> _saveTemplate() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedBayType == null) {
      SnackBarUtils.showSnackBar(
        context,
        'Please select a Bay Type.',
        isError: true,
      );
      return;
    }

    setState(() => _isSaving = true);
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      if (mounted)
        SnackBarUtils.showSnackBar(
          context,
          'Error: User not logged in.',
          isError: true,
        );
      setState(() => _isSaving = false);
      return;
    }

    try {
      final List<ReadingField> readingFields = _templateReadingFields
          .map((fieldMap) => ReadingField.fromMap(fieldMap))
          .toList();

      final newTemplate = ReadingTemplate(
        bayType: _selectedBayType!,
        readingFields: readingFields,
        createdBy: currentUser.uid,
        createdAt: Timestamp.now(),
      );

      if (_templateToEdit == null) {
        await FirebaseFirestore.instance
            .collection('readingTemplates')
            .add(newTemplate.toFirestore());
        if (mounted)
          SnackBarUtils.showSnackBar(
            context,
            'Reading template added successfully!',
          );
      } else {
        await FirebaseFirestore.instance
            .collection('readingTemplates')
            .doc(_templateToEdit!.id)
            .update(newTemplate.toFirestore());
        if (mounted)
          SnackBarUtils.showSnackBar(
            context,
            'Reading template updated successfully!',
          );
      }
      _showListView();
    } catch (e) {
      if (mounted)
        SnackBarUtils.showSnackBar(
          context,
          'Failed to save template: $e',
          isError: true,
        );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _deleteTemplate(String? templateId) async {
    if (templateId == null) return;
    final bool confirm =
        await showDialog(
          context: context,
          builder: (BuildContext context) => AlertDialog(
            title: const Text('Confirm Deletion'),
            content: const Text(
              'Are you sure you want to delete this reading template? This action cannot be undone.',
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text('Delete'),
              ),
            ],
          ),
        ) ??
        false;

    if (confirm) {
      try {
        await FirebaseFirestore.instance
            .collection('readingTemplates')
            .doc(templateId)
            .delete();
        if (mounted)
          SnackBarUtils.showSnackBar(
            context,
            'Reading template deleted successfully!',
          );
        _fetchReadingTemplates();
      } catch (e) {
        if (mounted)
          SnackBarUtils.showSnackBar(
            context,
            'Failed to delete template: $e',
            isError: true,
          );
      }
    }
  }

  // Debounced update method
  void _debouncedUpdate(VoidCallback callback) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) setState(callback);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _viewMode == ReadingTemplateViewMode.list
              ? 'Reading Templates'
              : (_templateToEdit == null
                    ? 'Define New Reading Template'
                    : 'Edit Reading Template'),
        ),
        leading: _viewMode == ReadingTemplateViewMode.form
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: _showListView,
              )
            : null,
      ),
      body: _viewMode == ReadingTemplateViewMode.list
          ? _buildListView()
          : _buildFormView(),
      floatingActionButton: _viewMode == ReadingTemplateViewMode.list
          ? FloatingActionButton.extended(
              onPressed: _showFormForNew,
              label: const Text('Add New Template'),
              icon: const Icon(Icons.add),
            )
          : null,
    );
  }

  Widget _buildListView() {
    return _templates.isEmpty
        ? const Center(
            child: Text(
              'No reading templates defined yet. Tap "+" to add one.',
            ),
          )
        : ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _templates.length,
            itemBuilder: (context, index) {
              final template = _templates[index];
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 8),
                elevation: 3,
                child: ListTile(
                  title: Text(template.bayType),
                  subtitle: Text(
                    '${template.readingFields.length} reading fields defined',
                  ),
                  trailing: PopupMenuButton<String>(
                    onSelected: (String result) {
                      if (result == 'edit')
                        _showFormForEdit(template);
                      else if (result == 'delete')
                        _deleteTemplate(template.id);
                    },
                    itemBuilder: (BuildContext context) =>
                        <PopupMenuEntry<String>>[
                          const PopupMenuItem<String>(
                            value: 'edit',
                            child: ListTile(
                              leading: Icon(Icons.edit),
                              title: Text('Edit'),
                            ),
                          ),
                          PopupMenuItem<String>(
                            value: 'delete',
                            child: ListTile(
                              leading: Icon(
                                Icons.delete,
                                color: Theme.of(context).colorScheme.error,
                              ),
                              title: Text(
                                'Delete',
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.error,
                                ),
                              ),
                            ),
                          ),
                        ],
                  ),
                ),
              );
            },
          );
  }

  Widget _buildFormView() {
    final colorScheme = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DropdownButtonFormField<String>(
              value: _selectedBayType,
              decoration: InputDecoration(
                labelText: 'Applies to Bay Type',
                prefixIcon: Icon(Icons.category, color: colorScheme.primary),
                border: const OutlineInputBorder(),
              ),
              items: _bayTypes
                  .map(
                    (String type) => DropdownMenuItem<String>(
                      value: type,
                      child: Text(type),
                    ),
                  )
                  .toList(),
              onChanged: _onBayTypeSelected,
              validator: (value) =>
                  value == null ? 'Please select a bay type' : null,
            ),
            const SizedBox(height: 20),
            _buildReadingFieldsSection(
              'Reading Fields',
              _templateReadingFields,
              colorScheme,
              Icons.list_alt,
            ),
            const SizedBox(height: 30),
            ElevatedButton.icon(
              onPressed: _isSaving ? null : _saveTemplate,
              icon: _isSaving
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(_templateToEdit == null ? Icons.add : Icons.save),
              label: Text(
                _templateToEdit == null ? 'Add Template' : 'Update Template',
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: colorScheme.primary,
                foregroundColor: colorScheme.onPrimary,
                minimumSize: const Size(double.infinity, 50),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReadingFieldsSection(
    String title,
    List<Map<String, dynamic>> fieldsList,
    ColorScheme colorScheme,
    IconData icon,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: colorScheme.primary),
            const SizedBox(width: 8),
            Text(title, style: Theme.of(context).textTheme.titleMedium),
          ],
        ),
        const SizedBox(height: 10),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: fieldsList.length,
          itemBuilder: (context, index) {
            final field = fieldsList[index];
            final bool isDefault = field['isDefault'] ?? false;
            return AbsorbPointer(
              absorbing: isDefault,
              child: Card(
                margin: const EdgeInsets.symmetric(vertical: 8.0),
                elevation: 2,
                color: isDefault ? Colors.grey.shade200 : null,
                child: _buildReadingFieldDefinitionInput(
                  field,
                  index,
                  fieldsList,
                  colorScheme,
                  isDefault: isDefault,
                ),
              ),
            );
          },
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _addReadingField,
                icon: const Icon(Icons.add),
                label: const Text('Add Field'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _addGroupReadingField,
                icon: const Icon(Icons.playlist_add),
                label: const Text('Grouped Field'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorScheme.secondary,
                  foregroundColor: colorScheme.onSecondary,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildReadingFieldDefinitionInput(
    Map<String, dynamic> fieldDef,
    int index,
    List<Map<String, dynamic>> parentList,
    ColorScheme colorScheme, {
    required bool isDefault,
    bool isNested = false,
  }) {
    final fieldName = fieldDef['name'] as String;
    final dataType = fieldDef['dataType'] as String;
    final isMandatory = fieldDef['isMandatory'] as bool;
    final isGroupField =
        dataType == ReadingFieldDataType.group.toString().split('.').last;

    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextFormField(
            initialValue: fieldName,
            decoration: InputDecoration(
              labelText: isNested ? 'Item Name' : 'Reading Field Name',
              border: const OutlineInputBorder(),
              hintText: isNested
                  ? 'e.g., Phase A Current'
                  : 'e.g., Voltage, Temperature',
            ),
            onChanged: isDefault
                ? null
                : (value) => _debouncedUpdate(() => fieldDef['name'] = value),
            validator: (value) => value == null || value.trim().isEmpty
                ? (isNested ? 'Item name required' : 'Field name required')
                : null,
          ),
          const SizedBox(height: 10),
          if (!isGroupField)
            DropdownButtonFormField<String>(
              value: fieldDef['dataType'] as String,
              decoration: const InputDecoration(
                labelText: 'Data Type',
                border: OutlineInputBorder(),
              ),
              items: _dataTypes
                  .where((type) => type != 'group' || isNested)
                  .map(
                    (type) => DropdownMenuItem(value: type, child: Text(type)),
                  )
                  .toList(),
              onChanged: isDefault
                  ? null
                  : (value) => _debouncedUpdate(() {
                      fieldDef['dataType'] = value!;
                      if (value != 'dropdown') fieldDef['options'] = [];
                      if (value != 'number') fieldDef['unit'] = '';
                      if (value != 'boolean')
                        fieldDef['description_remarks'] = '';
                      fieldDef['nestedFields'] = null;
                    }),
            ),
          if (isGroupField)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Text(
                'Data Type: Group',
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(fontStyle: FontStyle.italic),
              ),
            ),
          const SizedBox(height: 10),
          if (!isNested)
            DropdownButtonFormField<String>(
              value: fieldDef['frequency'] as String,
              decoration: const InputDecoration(
                labelText: 'Reading Frequency',
                border: OutlineInputBorder(),
              ),
              items: _frequencies
                  .map(
                    (freq) => DropdownMenuItem(value: freq, child: Text(freq)),
                  )
                  .toList(),
              onChanged: isDefault
                  ? null
                  : (value) =>
                        _debouncedUpdate(() => fieldDef['frequency'] = value!),
            ),
          if (!isNested) const SizedBox(height: 10),
          if (!isGroupField) ...[
            if (fieldDef['dataType'] == 'dropdown')
              TextFormField(
                initialValue: (fieldDef['options'] as List<dynamic>?)?.join(
                  ',',
                ),
                decoration: const InputDecoration(
                  labelText: 'Options (comma-separated)',
                  hintText: 'e.g., Option1, Option2',
                  border: OutlineInputBorder(),
                ),
                onChanged: isDefault
                    ? null
                    : (value) => _debouncedUpdate(
                        () => fieldDef['options'] = value
                            .split(',')
                            .map((e) => e.trim())
                            .where((e) => e.isNotEmpty)
                            .toList(),
                      ),
              ),
            if (fieldDef['dataType'] == 'number')
              TextFormField(
                initialValue: fieldDef['unit'] as String?,
                decoration: const InputDecoration(
                  labelText: 'Unit (e.g., V, A, kW)',
                  border: OutlineInputBorder(),
                ),
                onChanged: isDefault
                    ? null
                    : (value) =>
                          _debouncedUpdate(() => fieldDef['unit'] = value),
              ),
            if (fieldDef['dataType'] == 'boolean')
              TextFormField(
                initialValue: fieldDef['description_remarks'] as String?,
                decoration: const InputDecoration(
                  labelText: 'Description / Remarks (Optional)',
                  border: OutlineInputBorder(),
                ),
                onChanged: isDefault
                    ? null
                    : (value) => _debouncedUpdate(
                        () => fieldDef['description_remarks'] = value,
                      ),
                maxLines: 2,
              ),
          ],
          if (isGroupField) ...[
            const SizedBox(height: 10),
            Text(
              'Fields in this Group:',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            if ((fieldDef['nestedFields'] as List<dynamic>).isEmpty)
              const Padding(
                padding: EdgeInsets.only(bottom: 8.0),
                child: Text('No fields defined for this group.'),
              ),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: (fieldDef['nestedFields'] as List<dynamic>).length,
              itemBuilder: (context, nestedIndex) {
                final nestedField =
                    (fieldDef['nestedFields'] as List<dynamic>)[nestedIndex];
                return _buildReadingFieldDefinitionInput(
                  nestedField,
                  nestedIndex,
                  (fieldDef['nestedFields'] as List<dynamic>)
                      .cast<Map<String, dynamic>>(),
                  colorScheme,
                  isDefault: false,
                  isNested: true,
                );
              },
            ),
            ElevatedButton.icon(
              onPressed: () => _addNestedReadingField(fieldDef),
              icon: const Icon(Icons.add),
              label: const Text('Add Field to Group'),
              style: ElevatedButton.styleFrom(
                backgroundColor: colorScheme.secondary,
                foregroundColor: colorScheme.onSecondary,
              ),
            ),
            const SizedBox(height: 10),
          ],
          CheckboxListTile(
            title: const Text('Mandatory'),
            value: fieldDef['isMandatory'] as bool,
            onChanged: isDefault
                ? null
                : (value) =>
                      _debouncedUpdate(() => fieldDef['isMandatory'] = value!),
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
          ),
          Align(
            alignment: Alignment.centerRight,
            child: IconButton(
              icon: Icon(
                Icons.remove_circle_outline,
                color: isDefault ? Colors.grey : colorScheme.error,
              ),
              onPressed: isDefault ? null : () => _removeReadingField(index),
            ),
          ),
        ],
      ),
    );
  }
}

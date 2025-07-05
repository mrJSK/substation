// lib/screens/admin/master_equipment_management_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/equipment_model.dart';
import '../../utils/snackbar_utils.dart';
import 'package:intl/intl.dart';
import 'package:flutter/widgets.dart'; // <-- Add this import for CustomPainter

// Import all your equipment icon painters here
import '../../equipment_icons/transformer_icon.dart';
import '../../equipment_icons/busbar_icon.dart';
import '../../equipment_icons/circuit_breaker_icon.dart';
import '../../equipment_icons/ct_icon.dart';
import '../../equipment_icons/disconnector_icon.dart';
import '../../equipment_icons/ground_icon.dart';
import '../../equipment_icons/isolator_icon.dart';
import '../../equipment_icons/pt_icon.dart';

enum MasterEquipmentViewMode { list, form }

class MasterEquipmentScreen extends StatefulWidget {
  const MasterEquipmentScreen({super.key});

  @override
  State<MasterEquipmentScreen> createState() => _MasterEquipmentScreenState();
}

class _MasterEquipmentScreenState extends State<MasterEquipmentScreen> {
  MasterEquipmentViewMode _viewMode = MasterEquipmentViewMode.list;
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _equipmentTypeController =
      TextEditingController();
  final TextEditingController _makeController = TextEditingController();
  DateTime? _dateOfManufacture;
  DateTime? _dateOfCommissioning;

  String? _selectedSymbolKey;
  MasterEquipmentTemplate? _templateToEdit;
  List<MasterEquipmentTemplate> _templates = [];
  List<Map<String, dynamic>> _equipmentCustomFields = [];
  bool _isLoading = true;
  bool _isSaving = false;

  // UPDATED: Pre-defined list of data types for custom fields (does NOT include 'group')
  final List<String> _dataTypes = [
    'text',
    'number',
    'boolean',
    'date',
    'dropdown',
  ];

  // Pre-defined symbol keys
  final List<String> _availableSymbolKeys = [
    'Transformer',
    'Circuit Breaker',
    'Disconnector',
    'Current Transformer',
    'Voltage Transformer',
    'Relay',
    'Capacitor Bank',
    'Reactor',
    'Surge Arrester',
    'Energy Meter',
    'Ground',
    'Busbar',
    'Isolator',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    _fetchEquipmentTemplates();
  }

  @override
  void dispose() {
    _equipmentTypeController.dispose();
    _makeController.dispose();
    super.dispose();
  }

  Future<void> _fetchEquipmentTemplates() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('masterEquipmentTemplates')
          .orderBy('equipmentType')
          .get();
      setState(() {
        _templates = snapshot.docs
            .map((doc) => MasterEquipmentTemplate.fromFirestore(doc))
            .toList();
        _isLoading = false;
      });
    } catch (e) {
      print("Error fetching equipment templates: $e");
      if (mounted) {
        SnackBarUtils.showSnackBar(
          context,
          'Failed to load templates: $e',
          isError: true,
        );
      }
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showListView() {
    setState(() {
      _viewMode = MasterEquipmentViewMode.list;
      _templateToEdit = null;
      _equipmentTypeController.clear();
      _makeController.clear();
      _dateOfManufacture = null;
      _dateOfCommissioning = null;
      _selectedSymbolKey = null;
      _equipmentCustomFields = [];
    });
    _fetchEquipmentTemplates();
  }

  void _showFormForNew() {
    setState(() {
      _viewMode = MasterEquipmentViewMode.form;
      _templateToEdit = null;
      _equipmentTypeController.clear();
      _makeController.clear();
      _dateOfManufacture = null;
      _dateOfCommissioning = null;
      _selectedSymbolKey = _availableSymbolKeys.first;
      _equipmentCustomFields = [];
    });
  }

  void _showFormForEdit(MasterEquipmentTemplate template) {
    setState(() {
      _viewMode = MasterEquipmentViewMode.form;
      _templateToEdit = template;
      _equipmentTypeController.text = template.equipmentType;
      _makeController.text = template.make ?? '';
      _dateOfManufacture = template.dateOfManufacture?.toDate();
      _dateOfCommissioning = template.dateOfCommissioning?.toDate();

      _selectedSymbolKey = template.symbolKey;
      _equipmentCustomFields = template.equipmentCustomFields
          .map((field) => field.toMap())
          .toList();
    });
  }

  // Modified _addCustomField to default to 'text' for new fields
  void _addCustomField(List<Map<String, dynamic>> targetList) {
    setState(() {
      targetList.add({
        'name': '',
        'dataType': CustomFieldDataType.text
            .toString()
            .split('.')
            .last, // Default to text
        'isMandatory': false,
        'hasUnits': false,
        'units': '',
        'options': [],
        'hasRemarksField': false,
        'templateRemarkText': '',
        'nestedFields': null, // Explicitly null for non-group types
      });
    });
  }

  // Add a new group (list) custom field
  void _addListCustomField(List<Map<String, dynamic>> targetList) {
    setState(() {
      targetList.add({
        'name': '',
        'dataType': CustomFieldDataType.group
            .toString()
            .split('.')
            .last, // Use 'group' as data type
        'isMandatory': false,
        'hasUnits': false,
        'units': '',
        'options': [],
        'hasRemarksField': false,
        'templateRemarkText': '',
        'nestedFields':
            <Map<String, dynamic>>[], // Start with empty nested fields
      });
    });
  }

  // This helper is for adding a nested field *within* a group field
  void _addNestedField(Map<String, dynamic> groupField) {
    setState(() {
      (groupField['nestedFields'] as List<dynamic>).add({
        'name': '',
        'dataType': CustomFieldDataType.text
            .toString()
            .split('.')
            .last, // Default nested field to text
        'isMandatory': false,
        'hasUnits': false,
        'units': '',
        'options': [],
        'hasRemarksField': false,
        'templateRemarkText': '',
      });
    });
  }

  void _removeCustomField(List<Map<String, dynamic>> targetList, int index) {
    setState(() {
      targetList.removeAt(index);
    });
  }

  // Helper to remove a nested field from a group field
  void _removeNestedField(Map<String, dynamic> groupField, int nestedIndex) {
    setState(() {
      (groupField['nestedFields'] as List<dynamic>).removeAt(nestedIndex);
    });
  }

  Future<void> _selectDate(
    BuildContext context,
    DateTime? initialDate,
    Function(DateTime?) onSelect,
  ) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate ?? DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime.now().add(const Duration(days: 365 * 10)),
    );
    if (picked != null && picked != initialDate) {
      setState(() {
        onSelect(picked);
      });
    }
  }

  Future<void> _saveTemplate() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      if (mounted) {
        SnackBarUtils.showSnackBar(
          context,
          'Error: User not logged in.',
          isError: true,
        );
      }
      setState(() {
        _isSaving = false;
      });
      return;
    }

    try {
      final List<CustomField> customFields = _equipmentCustomFields
          .map((fieldMap) => CustomField.fromMap(fieldMap))
          .toList();

      final MasterEquipmentTemplate newTemplate = MasterEquipmentTemplate(
        equipmentType: _equipmentTypeController.text.trim(),
        symbolKey: _selectedSymbolKey!,
        equipmentCustomFields: customFields,
        createdBy: currentUser.uid,
        createdAt: Timestamp.now(),
        make: _makeController.text.trim().isEmpty
            ? null
            : _makeController.text.trim(),
        dateOfManufacture: _dateOfManufacture != null
            ? Timestamp.fromDate(_dateOfManufacture!)
            : null,
        dateOfCommissioning: _dateOfCommissioning != null
            ? Timestamp.fromDate(_dateOfCommissioning!)
            : null,
      );

      if (_templateToEdit == null) {
        await FirebaseFirestore.instance
            .collection('masterEquipmentTemplates')
            .add(newTemplate.toFirestore());
        if (mounted) {
          SnackBarUtils.showSnackBar(
            context,
            'Equipment template added successfully!',
          );
        }
      } else {
        await FirebaseFirestore.instance
            .collection('masterEquipmentTemplates')
            .doc(_templateToEdit!.id)
            .update(newTemplate.toFirestore());
        if (mounted) {
          SnackBarUtils.showSnackBar(
            context,
            'Equipment template updated successfully!',
          );
        }
      }
      _showListView();
    } catch (e) {
      print("Error saving template: $e");
      if (mounted) {
        SnackBarUtils.showSnackBar(
          context,
          'Failed to save template: $e',
          isError: true,
        );
      }
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
  }

  Future<void> _deleteTemplate(String? templateId) async {
    if (templateId == null) return;

    final bool confirm =
        await showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('Confirm Deletion'),
              content: const Text(
                'Are you sure you want to delete this equipment template? This action cannot be undone.',
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
            );
          },
        ) ??
        false;

    if (confirm) {
      try {
        await FirebaseFirestore.instance
            .collection('masterEquipmentTemplates')
            .doc(templateId)
            .delete();
        if (mounted) {
          SnackBarUtils.showSnackBar(
            context,
            'Equipment template deleted successfully!',
          );
        }
        _fetchEquipmentTemplates();
      } catch (e) {
        print("Error deleting template: $e");
        if (mounted) {
          SnackBarUtils.showSnackBar(
            context,
            'Failed to delete template: $e',
            isError: true,
          );
        }
      }
    }
  }

  Size _getSymbolPreviewSize(String symbolKey) {
    return const Size(32, 32);
  }

  CustomPainter _getSymbolPreviewPainter(String symbolKey, Color color) {
    const Size equipmentDrawingSize = Size(100, 100);
    switch (symbolKey.toLowerCase()) {
      case 'transformer':
        return TransformerIconPainter(
          color: color,
          equipmentSize: equipmentDrawingSize,
          symbolSize: equipmentDrawingSize,
        );
      case 'busbar':
        return BusbarIconPainter(
          color: color,
          equipmentSize: equipmentDrawingSize,
          symbolSize: equipmentDrawingSize,
        );
      case 'circuit breaker':
        return CircuitBreakerIconPainter(
          color: color,
          equipmentSize: equipmentDrawingSize,
          symbolSize: equipmentDrawingSize,
        );
      case 'current transformer':
      case 'ct':
        return CurrentTransformerIconPainter(
          color: color,
          equipmentSize: equipmentDrawingSize,
          symbolSize: equipmentDrawingSize,
        );
      case 'disconnector':
        return DisconnectorIconPainter(
          color: color,
          equipmentSize: equipmentDrawingSize,
          symbolSize: equipmentDrawingSize,
        );
      case 'ground':
        return GroundIconPainter(
          color: color,
          equipmentSize: equipmentDrawingSize,
          symbolSize: equipmentDrawingSize,
        );
      case 'isolator':
        return IsolatorIconPainter(
          color: color,
          equipmentSize: equipmentDrawingSize,
          symbolSize: const Size(32, 32),
        );
      case 'voltage transformer':
      case 'pt':
        return PotentialTransformerIconPainter(
          color: color,
          equipmentSize: equipmentDrawingSize,
          symbolSize: equipmentDrawingSize,
        );
      default:
        return _GenericIconPainter(color: color);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _viewMode == MasterEquipmentViewMode.list
              ? 'Equipment Templates'
              : (_templateToEdit == null
                    ? 'Define New Equipment Type'
                    : 'Edit Equipment Type'),
        ),
        leading: _viewMode == MasterEquipmentViewMode.form
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: _showListView,
              )
            : null,
      ),
      body: _viewMode == MasterEquipmentViewMode.list
          ? _buildListView()
          : _buildFormView(),
      floatingActionButton: _viewMode == MasterEquipmentViewMode.list
          ? FloatingActionButton.extended(
              onPressed: _showFormForNew,
              label: const Text('Add New Type'),
              icon: const Icon(Icons.add),
            )
          : null,
    );
  }

  Widget _buildListView() {
    return _templates.isEmpty
        ? const Center(
            child: Text('No templates defined yet. Tap "+" to add one.'),
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
                  title: Text(template.equipmentType),
                  subtitle: Text(
                    'Symbol: ${template.symbolKey}\nMake: ${template.make ?? 'N/A'}\nCommissioned: ${template.dateOfCommissioning != null ? DateFormat('yyyy-MM-dd').format(template.dateOfCommissioning!.toDate()) : 'N/A'}\n${template.equipmentCustomFields.length} custom fields',
                  ),
                  trailing: PopupMenuButton<String>(
                    onSelected: (String result) {
                      if (result == 'edit') {
                        _showFormForEdit(template);
                      } else if (result == 'delete') {
                        _deleteTemplate(template.id);
                      }
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
            TextFormField(
              controller: _equipmentTypeController,
              decoration: InputDecoration(
                labelText: 'Equipment Type Name',
                hintText: 'e.g., Power Transformer, Relay, Energy Meter',
                prefixIcon: Icon(Icons.category, color: colorScheme.primary),
                border: const OutlineInputBorder(),
              ),
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Equipment Type cannot be empty'
                  : null,
            ),
            const SizedBox(height: 20),
            DropdownButtonFormField<String>(
              value: _selectedSymbolKey,
              decoration: InputDecoration(
                labelText: 'Map to Symbol',
                prefixIcon: Icon(Icons.star, color: colorScheme.primary),
                border: const OutlineInputBorder(),
              ),
              items: _availableSymbolKeys.map((String key) {
                return DropdownMenuItem<String>(
                  value: key,
                  child: Row(
                    children: [
                      SizedBox(
                        width: _getSymbolPreviewSize(key).width,
                        height: _getSymbolPreviewSize(key).height,
                        child: CustomPaint(
                          painter: _getSymbolPreviewPainter(
                            key,
                            colorScheme.onSurface,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(key),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (String? newValue) =>
                  setState(() => _selectedSymbolKey = newValue!),
              validator: (value) =>
                  value == null ? 'Please select a symbol' : null,
            ),
            const SizedBox(height: 20),

            // Basic Details Section
            Text(
              'Basic Details',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(color: colorScheme.primary),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _makeController,
              decoration: InputDecoration(
                labelText: 'Make',
                prefixIcon: Icon(Icons.business, color: colorScheme.primary),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              title: Text(
                _dateOfManufacture == null
                    ? 'Select Date of Manufacture'
                    : 'Date of Manufacture: ${DateFormat('yyyy-MM-dd').format(_dateOfManufacture!)}',
              ),
              trailing: const Icon(Icons.calendar_today),
              onTap: () => _selectDate(context, _dateOfManufacture, (date) {
                _dateOfManufacture = date;
              }),
            ),
            const SizedBox(height: 16),
            ListTile(
              title: Text(
                _dateOfCommissioning == null
                    ? 'Select Date of Commissioning'
                    : 'Date of Commissioning: ${DateFormat('yyyy-MM-dd').format(_dateOfCommissioning!)}',
              ),
              trailing: const Icon(Icons.calendar_today),
              onTap: () => _selectDate(context, _dateOfCommissioning, (date) {
                _dateOfCommissioning = date;
              }),
            ),
            const SizedBox(height: 20),

            _buildCustomFieldsSection(
              'Custom Fields',
              _equipmentCustomFields,
              colorScheme,
              Icons.settings_input_component,
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

  Widget _buildCustomFieldsSection(
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
            return _buildCustomFieldDefinitionInput(
              field,
              index,
              fieldsList,
              colorScheme,
            );
          },
        ),
        // Row for "Add Field" and "Add List Field" buttons
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => _addCustomField(fieldsList),
                icon: const Icon(Icons.add),
                label: const Text('Add Field'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => _addListCustomField(
                  fieldsList,
                ), // NEW: Button for adding list type
                icon: const Icon(Icons.playlist_add), // A list-like icon
                label: const Text('Grouped Field'), // Renamed label
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

  // Helper to build a single custom field definition input (including 'group' type details)
  Widget _buildCustomFieldDefinitionInput(
    Map<String, dynamic> fieldDef,
    int index,
    List<Map<String, dynamic>> parentList,
    ColorScheme colorScheme, {
    bool isNested = false,
  }) {
    final fieldName = fieldDef['name'] as String;
    final dataType =
        fieldDef['dataType'] as String; // This is the string representation
    final isMandatory = fieldDef['isMandatory'] as bool;
    final hasUnits = fieldDef['hasUnits'] as bool;
    final units = fieldDef['units'] as String;
    final options = List<String>.from(fieldDef['options'] ?? []);
    final bool hasRemarksField = fieldDef['hasRemarksField'] as bool;

    // Determine if this field is a Group field
    final bool isGroupField =
        dataType == CustomFieldDataType.group.toString().split('.').last;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextFormField(
              initialValue: fieldName,
              decoration: InputDecoration(
                labelText: isNested ? 'Item Name' : 'Field Name',
                border: const OutlineInputBorder(),
                hintText: isNested
                    ? 'e.g., Phase A Current'
                    : 'e.g., Manufacturer, Last Service Date',
              ),
              onChanged: (value) => fieldDef['name'] = value,
              validator: (value) => value == null || value.trim().isEmpty
                  ? (isNested ? 'Item name required' : 'Field name required')
                  : null,
            ),
            const SizedBox(height: 10),

            // Data Type dropdown (hidden if it's a Group field)
            if (!isGroupField)
              DropdownButtonFormField<String>(
                value: dataType,
                decoration: const InputDecoration(
                  labelText: 'Data Type',
                  border: OutlineInputBorder(),
                ),
                items: _dataTypes
                    .map(
                      (type) =>
                          DropdownMenuItem(value: type, child: Text(type)),
                    )
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    fieldDef['dataType'] = value!;
                    // Reset properties based on new data type
                    fieldDef['options'] = [];
                    fieldDef['hasUnits'] = false;
                    fieldDef['units'] = '';
                    fieldDef['hasRemarksField'] = false;
                    fieldDef['templateRemarkText'] = '';
                    fieldDef['nestedFields'] =
                        null; // Ensure null if changing from group
                  });
                },
              ),
            // Display 'Group' label if it is a Group field
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

            // Conditional UI based on data types (only if not a group field)
            if (!isGroupField) ...[
              if (dataType == 'dropdown')
                TextFormField(
                  initialValue: (fieldDef['options'] as List<dynamic>?)?.join(
                    ',',
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Options (comma-separated)',
                    border: OutlineInputBorder(),
                    hintText: 'e.g., Option1, Option2, Option3',
                  ),
                  onChanged: (value) => fieldDef['options'] = value
                      .split(',')
                      .map((e) => e.trim())
                      .where((e) => e.isNotEmpty)
                      .toList(),
                ),
              if (dataType == 'number') ...[
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Row(
                    children: [
                      Switch(
                        value: hasUnits,
                        onChanged: (value) =>
                            setState(() => fieldDef['hasUnits'] = value),
                        activeColor: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      const Text('Has Units'),
                    ],
                  ),
                ),
                if (hasUnits)
                  TextFormField(
                    initialValue: units,
                    decoration: const InputDecoration(
                      labelText: 'Units (e.g., V, A, kW, Hz)',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (value) => fieldDef['units'] = value,
                    validator: (value) {
                      if (hasUnits && (value == null || value.trim().isEmpty)) {
                        return 'Units required if "Has Units" is checked';
                      }
                      return null;
                    },
                  ),
              ],
              if (dataType == 'boolean') ...[
                const SizedBox(height: 10),
                TextFormField(
                  initialValue: fieldDef['description_remarks'] as String?,
                  decoration: const InputDecoration(
                    labelText: 'Description / Remarks (Optional)',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (value) => fieldDef['description_remarks'] = value,
                  maxLines: 2,
                ),
              ],
            ], // End of if (!isGroupField)
            // UI for 'group' type custom field (nested fields management)
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
                  return _buildCustomFieldDefinitionInput(
                    nestedField,
                    nestedIndex,
                    (fieldDef['nestedFields'] as List<dynamic>)
                        .cast<Map<String, dynamic>>(),
                    colorScheme,
                    isNested: true,
                  );
                },
              ),
              ElevatedButton.icon(
                onPressed: () => _addNestedField(fieldDef),
                icon: const Icon(Icons.add),
                label: const Text('Add Field to Group'), // Renamed button
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorScheme.secondary,
                  foregroundColor: colorScheme.onSecondary,
                ),
              ),
              const SizedBox(height: 10),
            ],

            CheckboxListTile(
              title: const Text('Mandatory'),
              value: isMandatory,
              onChanged: (value) =>
                  setState(() => fieldDef['isMandatory'] = value!),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
            ),
            Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                icon: Icon(
                  Icons.remove_circle_outline,
                  color: colorScheme.error,
                ),
                onPressed: () => _removeCustomField(parentList, index),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GenericIconPainter extends CustomPainter {
  final Color color;

  _GenericIconPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    final double centerX = size.width / 2;
    final double centerY = size.height / 2;
    final double halfWidth = size.width / 3;
    final double halfHeight = size.height / 3;

    canvas.drawRect(
      Rect.fromCenter(
        center: Offset(centerX, centerY),
        width: halfWidth * 2,
        height: halfHeight * 2,
      ),
      paint,
    );
    canvas.drawLine(
      Offset(centerX - halfWidth, centerY - halfHeight),
      Offset(centerX + halfWidth, centerY + halfHeight),
      paint,
    );
    canvas.drawLine(
      Offset(centerX + halfWidth, centerY - halfHeight),
      Offset(centerX - halfWidth, centerY + halfHeight),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

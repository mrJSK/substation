// lib/screens/admin/master_equipment_management_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/equipment_model.dart';
import '../../utils/snackbar_utils.dart'; // Ensure you have this utility
import 'package:intl/intl.dart'; // Import for date formatting

// Import all your equipment icon painters here
import '../../equipment_icons/transformer_icon.dart'; // Example: TransformerIconPainter
import '../../equipment_icons/busbar_icon.dart'; // Assuming you have this
import '../../equipment_icons/circuit_breaker_icon.dart'; // Assuming you have this
import '../../equipment_icons/ct_icon.dart'; // Assuming you have this
import '../../equipment_icons/disconnector_icon.dart'; // Assuming you have this
import '../../equipment_icons/ground_icon.dart'; // Assuming you have this
import '../../equipment_icons/isolator_icon.dart'; // Assuming you have this
import '../../equipment_icons/pt_icon.dart'; // Assuming you have this

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
  // NEW: Controllers for Basic Details fields
  final TextEditingController _makeController = TextEditingController();
  DateTime? _dateOfManufacture;
  DateTime? _dateOfCommissioning;

  String? _selectedSymbolKey;
  MasterEquipmentTemplate? _templateToEdit;
  List<MasterEquipmentTemplate> _templates = [];
  List<Map<String, dynamic>> _equipmentCustomFields = [];
  bool _isLoading = true;
  bool _isSaving = false;

  // Pre-defined list of data types for custom fields
  final List<String> _dataTypes = [
    'text',
    'number',
    'boolean',
    'date',
    'dropdown',
  ];

  // Pre-defined symbol keys (you can expand this as needed)
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
    _makeController.dispose(); // Dispose new controller
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
      _makeController.clear(); // Clear new controller
      _dateOfManufacture = null; // Clear new date
      _dateOfCommissioning = null; // Clear new date
      _selectedSymbolKey = null;
      _equipmentCustomFields = [];
    });
    _fetchEquipmentTemplates(); // Refresh list after returning
  }

  void _showFormForNew() {
    setState(() {
      _viewMode = MasterEquipmentViewMode.form;
      _templateToEdit = null;
      _equipmentTypeController.clear();
      _makeController.clear(); // Clear new controller
      _dateOfManufacture = null; // Clear new date
      _dateOfCommissioning = null; // Clear new date
      _selectedSymbolKey = _availableSymbolKeys.first; // Default symbol
      _equipmentCustomFields = [];
    });
  }

  void _showFormForEdit(MasterEquipmentTemplate template) {
    setState(() {
      _viewMode = MasterEquipmentViewMode.form;
      _templateToEdit = template;
      _equipmentTypeController.text = template.equipmentType;
      // Populate new fields
      _makeController.text = template.make ?? '';
      _dateOfManufacture = template.dateOfManufacture?.toDate();
      _dateOfCommissioning = template.dateOfCommissioning?.toDate();

      _selectedSymbolKey = template.symbolKey;
      _equipmentCustomFields = template.equipmentCustomFields
          .map((field) => field.toMap())
          .toList();
    });
  }

  void _addCustomField(List<Map<String, dynamic>> targetList) {
    setState(() {
      targetList.add({
        'name': '',
        'dataType': CustomFieldDataType.text.toString().split('.').last,
        'isMandatory': false,
        'hasUnits': false,
        'units': '',
        'options': [],
        'description_remarks': '', // Initialize for boolean
      });
    });
  }

  void _removeCustomField(List<Map<String, dynamic>> targetList, int index) {
    setState(() {
      targetList.removeAt(index);
    });
  }

  // NEW: Date picker helper function
  Future<void> _selectDate(
    BuildContext context,
    DateTime? initialDate,
    Function(DateTime?) onSelect,
  ) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate ?? DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime.now().add(
        const Duration(days: 365 * 10),
      ), // Allow up to 10 years in future for commissioning
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
        // Save new fields
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
        // Add new template
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
        // Update existing template
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
      _showListView(); // Go back to list view and refresh
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
        _fetchEquipmentTemplates(); // Refresh list
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

  // Helper to provide a simple preview of the selected symbol (for demonstration)
  Size _getSymbolPreviewSize(String symbolKey) {
    switch (symbolKey) {
      case 'Transformer':
        return const Size(30, 30);
      case 'Circuit Breaker':
        return const Size(25, 25);
      case 'Busbar':
        return const Size(35, 15);
      case 'Disconnector':
        return const Size(25, 25);
      case 'Current Transformer':
      case 'Voltage Transformer':
        return const Size(25, 25);
      case 'Ground':
        return const Size(20, 20);
      case 'Isolator':
        return const Size(25, 25);
      default:
        return const Size(20, 20);
    }
  }

  // Dynamically get the correct CustomPainter based on the symbolKey
  CustomPainter _getSymbolPreviewPainter(String symbolKey, Color color) {
    // Use a fixed default size for drawing the symbol within the preview
    const Size equipmentDrawingSize = Size(100, 100);

    switch (symbolKey) {
      case 'Transformer':
        return TransformerIconPainter(
          color: color,
          equipmentSize: equipmentDrawingSize,
          symbolSize: equipmentDrawingSize,
        );
      case 'Circuit Breaker':
        return CircuitBreakerIconPainter(
          color: color,
          equipmentSize: equipmentDrawingSize,
          symbolSize: equipmentDrawingSize,
        );
      case 'Disconnector':
        return DisconnectorIconPainter(
          color: color,
          equipmentSize: equipmentDrawingSize,
          symbolSize: equipmentDrawingSize,
        );
      case 'Current Transformer':
        return CurrentTransformerIconPainter(
          color: color,
          equipmentSize: equipmentDrawingSize,
          symbolSize: equipmentDrawingSize,
        );
      case 'Voltage Transformer':
        return PotentialTransformerIconPainter(
          color: color,
          equipmentSize: equipmentDrawingSize,
          symbolSize: equipmentDrawingSize,
        );
      case 'Busbar':
        return BusbarIconPainter(
          color: color,
          equipmentSize: equipmentDrawingSize,
          symbolSize: equipmentDrawingSize,
        );
      case 'Ground':
        return GroundIconPainter(
          color: color,
          equipmentSize: equipmentDrawingSize,
          symbolSize: equipmentDrawingSize,
        );
      case 'Isolator':
        return IsolatorIconPainter(
          color: color,
          equipmentSize: equipmentDrawingSize,
          symbolSize: const Size(32, 32),
        );
      case 'Relay':
      case 'Capacitor Bank':
      case 'Reactor':
      case 'Surge Arrester':
      case 'Energy Meter':
      case 'Other':
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

            // NEW: Basic Details Section
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
                labelText: 'Make (Optional)',
                prefixIcon: Icon(Icons.business, color: colorScheme.primary),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              title: Text(
                _dateOfManufacture == null
                    ? 'Select Date of Manufacture (Optional)'
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
                    ? 'Select Date of Commissioning (Optional)'
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
            return Card(
              margin: const EdgeInsets.symmetric(vertical: 8.0),
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextFormField(
                      initialValue: field['name'] as String,
                      decoration: const InputDecoration(
                        labelText: 'Field Name',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (value) => field['name'] = value,
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                          ? 'Field name required'
                          : null,
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      value: field['dataType'] as String,
                      decoration: const InputDecoration(
                        labelText: 'Data Type',
                        border: OutlineInputBorder(),
                      ),
                      items: _dataTypes
                          .map(
                            (type) => DropdownMenuItem(
                              value: type,
                              child: Text(type),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        setState(() {
                          field['dataType'] = value!;
                          // Reset options/units when data type changes
                          if (value != 'dropdown') {
                            field['options'] = [];
                          }
                          if (value != 'number') {
                            field['hasUnits'] = false;
                            field['units'] = '';
                          }
                          // Clear description for boolean if data type changes from boolean
                          if (value != 'boolean') {
                            field['description_remarks'] = '';
                          }
                        });
                      },
                    ),
                    const SizedBox(height: 10),
                    if (field['dataType'] == 'dropdown')
                      TextFormField(
                        initialValue: (field['options'] as List<dynamic>?)
                            ?.join(','),
                        decoration: const InputDecoration(
                          labelText: 'Options (comma-separated)',
                          border: OutlineInputBorder(),
                          hintText: 'e.g., Option1, Option2, Option3',
                        ),
                        onChanged: (value) => field['options'] = value
                            .split(',')
                            .map((e) => e.trim())
                            .where((e) => e.isNotEmpty)
                            .toList(),
                      ),
                    if (field['dataType'] == 'number') ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Row(
                          children: [
                            Switch(
                              value: field['hasUnits'] as bool,
                              onChanged: (value) =>
                                  setState(() => field['hasUnits'] = value),
                              activeColor: Theme.of(
                                context,
                              ).colorScheme.primary,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Has Units',
                              style: Theme.of(context).textTheme.bodyLarge,
                            ),
                          ],
                        ),
                      ),
                      if (field['hasUnits'] as bool)
                        TextFormField(
                          initialValue: field['units'] as String,
                          decoration: const InputDecoration(
                            labelText: 'Units (e.g., V, A, kW, Hz)',
                            border: OutlineInputBorder(),
                          ),
                          onChanged: (value) => field['units'] = value,
                          validator: (value) {
                            if (field['hasUnits'] as bool &&
                                (value == null || value.trim().isEmpty)) {
                              return 'Units required if "Has Units" is checked';
                            }
                            return null;
                          },
                        ),
                    ],
                    // NEW: Description / Remarks for boolean fields
                    if (field['dataType'] == 'boolean') ...[
                      const SizedBox(height: 10),
                      TextFormField(
                        initialValue: field['description_remarks'] as String?,
                        decoration: const InputDecoration(
                          labelText: 'Description / Remarks (Optional)',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (value) =>
                            field['description_remarks'] = value,
                        maxLines: 2,
                      ),
                    ],
                    CheckboxListTile(
                      title: const Text('Mandatory'),
                      value: field['isMandatory'] as bool,
                      onChanged: (value) =>
                          setState(() => field['isMandatory'] = value!),
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
                        onPressed: () => _removeCustomField(fieldsList, index),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        ElevatedButton.icon(
          onPressed: () => _addCustomField(fieldsList),
          icon: const Icon(Icons.add),
          label: const Text('Add Field'),
        ),
      ],
    );
  }
}

// A generic painter for symbols that don't have a specific CustomPainter
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

    // Draw a simple rectangle with a cross to represent a generic component
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

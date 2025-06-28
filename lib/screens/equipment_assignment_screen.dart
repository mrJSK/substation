// lib/screens/equipment_assignment_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../models/equipment_model.dart'; // Ensure CustomField and MasterEquipmentTemplate are updated here
import '../utils/snackbar_utils.dart';
// Import equipment icon painters
import '../../equipment_icons/transformer_icon.dart';
import '../../equipment_icons/busbar_icon.dart';
import '../../equipment_icons/circuit_breaker_icon.dart';
import '../../equipment_icons/ct_icon.dart';
import '../../equipment_icons/disconnector_icon.dart';
import '../../equipment_icons/ground_icon.dart';
import '../../equipment_icons/isolator_icon.dart';
import '../../equipment_icons/pt_icon.dart';

class EquipmentAssignmentScreen extends StatefulWidget {
  final String bayId;
  final String bayName;
  final String substationId;

  const EquipmentAssignmentScreen({
    super.key,
    required this.bayId,
    required this.bayName,
    required this.substationId,
  });

  @override
  State<EquipmentAssignmentScreen> createState() =>
      _EquipmentAssignmentScreenState();
}

// Move _GenericIconPainter outside of the state class
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
  bool shouldRepaint(covariant _GenericIconPainter oldDelegate) => false;
}

class _EquipmentAssignmentScreenState extends State<EquipmentAssignmentScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  bool _isLoading = true;
  List<MasterEquipmentTemplate> _equipmentTemplates = [];
  MasterEquipmentTemplate? _selectedTemplate;
  bool _isSavingEquipment = false;

  // Controllers/Values for template-defined fields (mapped by field name)
  final Map<String, TextEditingController> _templateTextFieldControllers = {};
  final Map<String, bool> _templateBooleanFieldValues = {};
  final Map<String, DateTime?> _templateDateFieldValues = {};
  final Map<String, String?> _templateDropdownFieldValues = {};
  final Map<String, TextEditingController>
  _templateBooleanDescriptionControllers = {};
  // New map to store whether a template-defined boolean field requires remarks
  final Map<String, bool> _templateBooleanHasRemarks = {};

  // For dynamically added custom fields by the user for this instance
  final List<Map<String, dynamic>> _userAddedCustomFieldDefinitions = [];
  final Map<String, TextEditingController> _userAddedTextFieldControllers = {};
  final Map<String, bool> _userAddedBooleanFieldValues = {};
  final Map<String, DateTime?> _userAddedDateFieldValues = {};
  final Map<String, String?> _userAddedDropdownFieldValues = {};
  final Map<String, TextEditingController>
  _userAddedBooleanDescriptionControllers = {};

  final List<String> _dataTypes = [
    'text',
    'number',
    'boolean',
    'date',
    'dropdown',
  ];

  @override
  void initState() {
    super.initState();
    _fetchEquipmentTemplates();
  }

  @override
  void dispose() {
    _templateTextFieldControllers.forEach(
      (key, controller) => controller.dispose(),
    );
    _userAddedTextFieldControllers.forEach(
      (key, controller) => controller.dispose(),
    );
    _templateBooleanDescriptionControllers.forEach(
      (key, controller) => controller.dispose(),
    );
    _userAddedBooleanDescriptionControllers.forEach(
      (key, controller) => controller.dispose(),
    );
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
        _equipmentTemplates = snapshot.docs
            .map((doc) => MasterEquipmentTemplate.fromFirestore(doc))
            .toList();
        _isLoading = false;
      });
    } catch (e) {
      print("Error fetching equipment templates: $e");
      if (mounted) {
        SnackBarUtils.showSnackBar(
          context,
          'Failed to load equipment types: $e',
          isError: true,
        );
      }
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _onTemplateSelected(MasterEquipmentTemplate? template) {
    setState(() {
      _selectedTemplate = template;
      _templateTextFieldControllers.forEach(
        (key, controller) => controller.dispose(),
      );
      _templateTextFieldControllers.clear();
      _templateBooleanFieldValues.clear();
      _templateDateFieldValues.clear();
      _templateDropdownFieldValues.clear();
      _templateBooleanDescriptionControllers.forEach(
        (key, controller) => controller.dispose(),
      );
      _templateBooleanDescriptionControllers.clear();
      _templateBooleanHasRemarks.clear(); // Clear the remarks map

      _userAddedCustomFieldDefinitions.clear();
      _userAddedTextFieldControllers.forEach(
        (key, controller) => controller.dispose(),
      );
      _userAddedTextFieldControllers.clear();
      _userAddedBooleanFieldValues.clear();
      _userAddedDateFieldValues.clear();
      _userAddedDropdownFieldValues.clear();
      _userAddedBooleanDescriptionControllers.forEach(
        (key, controller) => controller.dispose(),
      );
      _userAddedBooleanDescriptionControllers.clear();

      if (_selectedTemplate != null) {
        for (var field in _selectedTemplate!.equipmentCustomFields) {
          final String fieldName = field.name;
          final String dataType = field.dataType.toString().split('.').last;

          if (dataType == 'text' || dataType == 'number') {
            _templateTextFieldControllers[fieldName] = TextEditingController();
          } else if (dataType == 'boolean') {
            _templateBooleanFieldValues[fieldName] = false;
            _templateBooleanDescriptionControllers[fieldName] =
                TextEditingController();
            // Store the hasRemarksField property from the template
            _templateBooleanHasRemarks[fieldName] =
                field.hasRemarksField; // Make sure field.hasRemarksField exists
          } else if (dataType == 'date') {
            _templateDateFieldValues[fieldName] = null;
          } else if (dataType == 'dropdown') {
            _templateDropdownFieldValues[fieldName] = null;
          }
        }
      }
    });
  }

  void _addUserCustomField() {
    setState(() {
      _userAddedCustomFieldDefinitions.add({
        'name': '',
        'dataType': 'text',
        'isMandatory': false,
        'hasUnits': false,
        'units': '',
        'options': [],
        'hasRemarksField': false, // Initialize for user-added boolean fields
      });
    });
  }

  void _removeUserCustomField(int index) {
    setState(() {
      final fieldName = _userAddedCustomFieldDefinitions[index]['name'];
      _userAddedCustomFieldDefinitions.removeAt(index);
      _userAddedTextFieldControllers.remove(fieldName)?.dispose();
      _userAddedBooleanFieldValues.remove(fieldName);
      _userAddedDateFieldValues.remove(fieldName);
      _userAddedDropdownFieldValues.remove(fieldName);
      _userAddedBooleanDescriptionControllers.remove(fieldName)?.dispose();
    });
  }

  Future<void> _saveEquipmentInstance() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    if (_selectedTemplate == null) {
      SnackBarUtils.showSnackBar(
        context,
        'Please select an equipment type.',
        isError: true,
      );
      return;
    }

    setState(() {
      _isSavingEquipment = true;
    });

    final firebaseUser = FirebaseAuth.instance.currentUser;
    if (firebaseUser == null) {
      if (mounted) {
        SnackBarUtils.showSnackBar(
          context,
          'User not authenticated.',
          isError: true,
        );
      }
      setState(() {
        _isSavingEquipment = false;
      });
      return;
    }

    try {
      Map<String, dynamic> allCustomFieldValues = {};

      for (var field in _selectedTemplate!.equipmentCustomFields) {
        final String fieldName = field.name;
        final String dataType = field.dataType.toString().split('.').last;

        if (dataType == 'text' || dataType == 'number') {
          allCustomFieldValues[fieldName] =
              _templateTextFieldControllers[fieldName]?.text.trim();
        } else if (dataType == 'boolean') {
          // Only save description_remarks if hasRemarksField was true in the template
          if (_templateBooleanHasRemarks[fieldName] == true) {
            allCustomFieldValues[fieldName] = {
              'value': _templateBooleanFieldValues[fieldName],
              'description_remarks':
                  _templateBooleanDescriptionControllers[fieldName]?.text
                      .trim(),
            };
          } else {
            // If no remarks field was defined, just save the boolean value
            allCustomFieldValues[fieldName] =
                _templateBooleanFieldValues[fieldName];
          }
        } else if (dataType == 'date') {
          allCustomFieldValues[fieldName] =
              _templateDateFieldValues[fieldName] != null
              ? Timestamp.fromDate(_templateDateFieldValues[fieldName]!)
              : null;
        } else if (dataType == 'dropdown') {
          allCustomFieldValues[fieldName] =
              _templateDropdownFieldValues[fieldName];
        }
      }

      // NO, DO NOT SAVE USER-ADDED FIELDS ON THIS SCREEN. THIS IS FOR TEMPLATE DEFINITION.
      // The `EquipmentInstance` model will only use the predefined template fields.
      // If you intend for user-added fields to be *part of the template definition*,
      // then the MasterEquipmentTemplate model needs to be updated to include a list of CustomField for user-added ones,
      // and this logic should be shifted to updating the MasterEquipmentTemplate document.

      // For the purpose of this request, assuming user-added fields are *ephemeral* for this instance,
      // we would traditionally gather them here. BUT since the request explicitly says
      // "remove sample UI permanently its a template not actual value filling screen",
      // we should not be generating instance-specific customFieldValues from user-added definitions on *this* screen.
      // This implies that this screen's role is purely about associating an equipment template
      // and defining *additional template-level fields* (which would then require saving
      // those definitions back to the MasterEquipmentTemplate, not creating instance-specific values).

      // Given the current structure, if "Additional Custom Properties" are truly meant
      // to be *for this instance only* and *not* part of the template, then the UI
      // for defining them should probably be on the screen where you *create* an instance,
      // not where you select a template and add to a bay.

      // For now, I will remove the logic that processes user-added fields for saving,
      // as they are not "actual values filling" if this is a template screen.
      // If the intent is to allow users to add *new custom fields to the template itself*
      // from this screen, then the save logic needs to be entirely different,
      // updating `MasterEquipmentTemplate` in Firestore.

      final newEquipmentInstanceRef = FirebaseFirestore.instance
          .collection('equipmentInstances')
          .doc();

      final newEquipmentInstance = EquipmentInstance(
        id: newEquipmentInstanceRef.id,
        bayId: widget.bayId,
        templateId: _selectedTemplate!.id!,
        equipmentTypeName: _selectedTemplate!.equipmentType,
        symbolKey: _selectedTemplate!.symbolKey,
        createdBy: firebaseUser.uid,
        createdAt: Timestamp.now(),
        customFieldValues: allCustomFieldValues,
      );

      await newEquipmentInstanceRef.set(newEquipmentInstance.toFirestore());

      if (mounted) {
        SnackBarUtils.showSnackBar(
          context,
          '${_selectedTemplate!.equipmentType} added to bay "${widget.bayName}" successfully!',
        );
        Navigator.of(
          context,
        ).pop(); // Navigate back to BayEquipmentManagementScreen
      }
    } catch (e) {
      print('Error saving equipment instance: $e');
      if (mounted) {
        SnackBarUtils.showSnackBar(
          context,
          'Failed to add equipment: $e',
          isError: true,
        );
      }
    } finally {
      setState(() {
        _isSavingEquipment = false;
      });
    }
  }

  // This _buildFieldInput is for rendering the *values* of fields,
  // whether from template or user-added definition.
  // Given the request, this function should NOT be used on this screen
  // for user-added fields if this is solely for template definition.
  // It should only be used for template-defined fields.
  Widget _buildFieldInput({
    required String fieldName,
    required String dataType,
    bool isMandatory = false,
    bool hasUnits = false,
    List<String> options = const [],
    required bool isUserAddedField,
    String units = '', // Added units here as it was missing in the signature
    bool hasRemarksField = false, // Pass this from template/user-added def
  }) {
    // Determine which set of controllers/values to use based on isUserAddedField
    // This part is crucial for correctly linking the input to the right state variable.
    final Map<String, TextEditingController> textFieldControllers =
        isUserAddedField
        ? _userAddedTextFieldControllers
        : _templateTextFieldControllers;
    final Map<String, bool> booleanValues = isUserAddedField
        ? _userAddedBooleanFieldValues
        : _templateBooleanFieldValues;
    final Map<String, DateTime?> dateValues = isUserAddedField
        ? _userAddedDateFieldValues
        : _templateDateFieldValues;
    final Map<String, String?> dropdownValues = isUserAddedField
        ? _userAddedDropdownFieldValues
        : _templateDropdownFieldValues;
    final Map<String, TextEditingController> booleanDescriptionControllers =
        isUserAddedField
        ? _userAddedBooleanDescriptionControllers
        : _templateBooleanDescriptionControllers;

    String unitHint = '';
    if (hasUnits && units.isEmpty) {
      unitHint = ' (e.g., A, kV, MW, Hz)';
    } else if (hasUnits && units.isNotEmpty) {
      unitHint = ' (${units})';
    }

    final inputDecoration = InputDecoration(
      labelText: fieldName + (isMandatory ? ' *' : ''),
      border: const OutlineInputBorder(),
      suffixText: hasUnits ? units : null,
      hintText: hasUnits && units.isEmpty ? 'Enter value' : null,
      suffixIcon: hasUnits
          ? (units.isEmpty ? const Icon(Icons.abc) : null)
          : null,
    );

    switch (dataType) {
      case 'text':
        return TextFormField(
          controller: textFieldControllers.putIfAbsent(
            fieldName,
            () => TextEditingController(),
          ),
          decoration: inputDecoration,
          validator: isMandatory
              ? (value) => value == null || value.isEmpty
                    ? '$fieldName is mandatory'
                    : null
              : null,
        );
      case 'number':
        return TextFormField(
          controller: textFieldControllers.putIfAbsent(
            fieldName,
            () => TextEditingController(),
          ),
          decoration: inputDecoration.copyWith(
            labelText: fieldName + (isMandatory ? ' *' : '') + unitHint,
          ),
          keyboardType: TextInputType.number,
          validator: isMandatory
              ? (value) {
                  if (value == null || value.isEmpty)
                    return '$fieldName is mandatory';
                  if (double.tryParse(value) == null)
                    return 'Enter a valid number for $fieldName';
                  return null;
                }
              : (value) => value!.isNotEmpty && double.tryParse(value) == null
                    ? 'Enter a valid number for $fieldName'
                    : null,
        );
      case 'boolean':
        final bool currentBooleanValue = booleanValues.putIfAbsent(
          fieldName,
          () => false,
        );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Checkbox(
                  value: currentBooleanValue,
                  onChanged: (value) {
                    setState(() {
                      booleanValues[fieldName] = value!;
                    });
                  },
                ),
                Expanded(
                  flex: 1,
                  child: Text(
                    fieldName + (isMandatory ? ' *' : ''),
                    style: Theme.of(context).textTheme.bodyLarge,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (hasRemarksField && currentBooleanValue)
                  Expanded(
                    flex: 3,
                    child: TextFormField(
                      controller: booleanDescriptionControllers.putIfAbsent(
                        fieldName,
                        () => TextEditingController(),
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Remarks (Optional)',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(
                          vertical: 10.0,
                          horizontal: 12.0,
                        ),
                        isDense: true,
                      ),
                      maxLines: 2,
                      minLines: 1,
                      keyboardType: TextInputType.multiline,
                    ),
                  ),
              ],
            ),
            if (isMandatory && !currentBooleanValue)
              Padding(
                padding: const EdgeInsets.only(left: 48.0, top: 4.0),
                child: Text(
                  '$fieldName is mandatory',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                    fontSize: 12,
                  ),
                ),
              ),
          ],
        );
      case 'date':
        return ListTile(
          title: Text(
            fieldName +
                (isMandatory ? ' *' : '') +
                ': ' +
                (dateValues[fieldName] == null
                    ? 'Select Date'
                    : DateFormat('yyyy-MM-dd').format(dateValues[fieldName]!)),
          ),
          trailing: const Icon(Icons.calendar_today),
          onTap: () async {
            final DateTime? picked = await showDatePicker(
              context: context,
              initialDate: dateValues[fieldName] ?? DateTime.now(),
              firstDate: DateTime(2000),
              lastDate: DateTime(2101),
            );
            if (picked != null) {
              setState(() {
                dateValues[fieldName] = picked;
              });
            }
          },
        );
      case 'dropdown':
        return DropdownButtonFormField<String>(
          value: dropdownValues[fieldName],
          decoration: inputDecoration,
          items: options.map((option) {
            return DropdownMenuItem(value: option, child: Text(option));
          }).toList(),
          onChanged: (value) {
            setState(() {
              dropdownValues[fieldName] = value;
            });
          },
          validator: isMandatory
              ? (value) => value == null || value.isEmpty
                    ? '$fieldName is mandatory'
                    : null
              : null,
        );
      default:
        return Text('Unsupported data type: $dataType for $fieldName');
    }
  }

  // This function is purely for defining the properties of a custom field.
  // It does NOT render the input widget for filling its value.
  Widget _buildUserAddedFieldDefinitionInput(
    Map<String, dynamic> fieldDef,
    int index,
  ) {
    final fieldName = fieldDef['name'] as String;
    final dataType = fieldDef['dataType'] as String;
    final isMandatory = fieldDef['isMandatory'] as bool;
    final hasUnits = fieldDef['hasUnits'] as bool;
    final units = fieldDef['units'] as String;
    final options = List<String>.from(fieldDef['options'] ?? []);
    final bool hasRemarksField =
        fieldDef['hasRemarksField'] as bool; // Get from definition

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
              decoration: const InputDecoration(
                labelText: 'New Field Name', // Clarified label for definition
                border: OutlineInputBorder(),
                hintText: 'e.g., Manufacturer, Last Service Date',
              ),
              onChanged: (value) {
                setState(() {
                  fieldDef['name'] = value;
                  // Clear and re-initialize controllers/values for the old fieldName
                  // when the field name itself changes to avoid conflicts if name is reused
                  if (_userAddedTextFieldControllers.containsKey(fieldName)) {
                    _userAddedTextFieldControllers.remove(fieldName)?.dispose();
                  }
                  if (_userAddedBooleanFieldValues.containsKey(fieldName)) {
                    _userAddedBooleanFieldValues.remove(fieldName);
                  }
                  if (_userAddedBooleanDescriptionControllers.containsKey(
                    fieldName,
                  )) {
                    _userAddedBooleanDescriptionControllers
                        .remove(fieldName)
                        ?.dispose();
                  }
                  if (_userAddedDateFieldValues.containsKey(fieldName)) {
                    _userAddedDateFieldValues.remove(fieldName);
                  }
                  if (_userAddedDropdownFieldValues.containsKey(fieldName)) {
                    _userAddedDropdownFieldValues.remove(fieldName);
                  }

                  // Initialize for the new value if it's not empty
                  if (value.isNotEmpty) {
                    if (dataType == 'text' || dataType == 'number') {
                      _userAddedTextFieldControllers[value] =
                          TextEditingController();
                    } else if (dataType == 'boolean') {
                      _userAddedBooleanFieldValues[value] = false;
                      _userAddedBooleanDescriptionControllers[value] =
                          TextEditingController();
                    }
                    // No need to initialize for date/dropdown here, they are handled differently
                  }
                });
              },
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Field name required'
                  : null,
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              value: dataType,
              decoration: const InputDecoration(
                labelText: 'Data Type',
                border: OutlineInputBorder(),
              ),
              items: _dataTypes
                  .map(
                    (type) => DropdownMenuItem(value: type, child: Text(type)),
                  )
                  .toList(),
              onChanged: (value) {
                setState(() {
                  fieldDef['dataType'] = value!;
                  fieldDef['options'] = [];
                  fieldDef['hasUnits'] = false;
                  fieldDef['units'] = '';
                  fieldDef['hasRemarksField'] =
                      false; // Reset when data type changes
                  // Dispose and clear controllers/values when data type changes
                  _userAddedTextFieldControllers.remove(fieldName)?.dispose();
                  _userAddedBooleanFieldValues.remove(fieldName);
                  _userAddedDateFieldValues.remove(fieldName);
                  _userAddedDropdownFieldValues.remove(fieldName);
                  _userAddedBooleanDescriptionControllers
                      .remove(fieldName)
                      ?.dispose();
                  // Re-initialize based on new type
                  if (value == 'text' || value == 'number') {
                    _userAddedTextFieldControllers[fieldName] =
                        TextEditingController();
                  } else if (value == 'boolean') {
                    _userAddedBooleanFieldValues[fieldName] = false;
                    _userAddedBooleanDescriptionControllers[fieldName] =
                        TextEditingController();
                  }
                });
              },
            ),
            const SizedBox(height: 10),
            if (dataType == 'dropdown')
              TextFormField(
                initialValue: options.join(','),
                decoration: const InputDecoration(
                  labelText: 'Options (comma-separated)',
                  hintText: 'e.g., Option1, Option2',
                  border: OutlineInputBorder(),
                ),
                onChanged: (value) => fieldDef['options'] = value
                    .split(',')
                    .map((e) => e.trim())
                    .where((e) => e.isNotEmpty)
                    .toList(),
              ),
            if (dataType == 'number')
              Row(
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
            if (dataType == 'number' && hasUnits)
              TextFormField(
                initialValue: units,
                decoration: const InputDecoration(
                  labelText: 'Units',
                  hintText: 'e.g., A, kV, MW', // Added hint for units input
                  border: OutlineInputBorder(),
                ),
                onChanged: (value) => fieldDef['units'] = value,
                validator: (value) =>
                    hasUnits && (value == null || value.isEmpty)
                    ? 'Units required'
                    : null,
              ),
            // NEW: Switch for user-added boolean fields to enable/disable remarks
            if (dataType == 'boolean')
              Row(
                children: [
                  Switch(
                    value: hasRemarksField,
                    onChanged: (value) =>
                        setState(() => fieldDef['hasRemarksField'] = value),
                    activeColor: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  const Text('Add Remarks Field'),
                ],
              ),
            SwitchListTile(
              value: isMandatory,
              onChanged: (val) {
                setState(() {
                  fieldDef['isMandatory'] = val;
                });
              },
              title: const Text('Mandatory'),
              contentPadding: EdgeInsets.zero,
            ),
            Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                icon: Icon(
                  Icons.remove_circle_outline,
                  color: Theme.of(context).colorScheme.error,
                ),
                onPressed: () => _removeUserCustomField(index),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Size _getSymbolPreviewSize(String symbolKey) {
    return const Size(32, 32);
  }

  CustomPainter _getSymbolPreviewPainter(String symbolKey, Color color) {
    const Size equipmentDrawingSize = Size(
      100,
      100,
    ); // Base size for the painter
    switch (symbolKey.toLowerCase()) {
      // Use toLowerCase for robust matching
      case 'transformer':
        return TransformerIconPainter(
          color: color,
          equipmentSize: equipmentDrawingSize,
          symbolSize: equipmentDrawingSize, // Pass symbolSize
        );
      case 'busbar':
        return BusbarIconPainter(
          color: color,
          equipmentSize: equipmentDrawingSize,
          symbolSize: equipmentDrawingSize, // Pass symbolSize
        );
      case 'circuit breaker': // Match the exact string from _availableSymbolKeys if it's "Circuit Breaker"
        return CircuitBreakerIconPainter(
          color: color,
          equipmentSize: equipmentDrawingSize,
          symbolSize: equipmentDrawingSize, // Pass symbolSize
        );
      case 'current transformer':
      case 'ct':
        return CurrentTransformerIconPainter(
          color: color,
          equipmentSize: equipmentDrawingSize,
          symbolSize: equipmentDrawingSize, // Pass symbolSize
        );
      case 'disconnector':
        return DisconnectorIconPainter(
          color: color,
          equipmentSize: equipmentDrawingSize,
          symbolSize: equipmentDrawingSize, // Pass symbolSize
        );
      case 'ground':
        return GroundIconPainter(
          color: color,
          equipmentSize: equipmentDrawingSize,
          symbolSize: equipmentDrawingSize, // Pass symbolSize
        );
      case 'isolator':
        return IsolatorIconPainter(
          color: color,
          equipmentSize: equipmentDrawingSize,
          symbolSize: const Size(
            32,
            32,
          ), // IsolatorIconPainter does not take symbolSize in its constructor (fix later if needed)
        );
      case 'voltage transformer':
      case 'pt':
        return PotentialTransformerIconPainter(
          color: color,
          equipmentSize: equipmentDrawingSize,
          symbolSize: equipmentDrawingSize, // Pass symbolSize
        );
      default:
        return _GenericIconPainter(color: color);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Add Equipment to Bay: ${widget.bayName}')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Bay: ${widget.bayName}',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    Text(
                      'Substation ID: ${widget.substationId}',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Select Equipment Type',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 16),
                    if (_equipmentTemplates.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Center(
                          child: Text(
                            'No equipment templates defined. Please define them in Admin Dashboard > Master Equipment.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontStyle: FontStyle.italic,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ),
                      )
                    else
                      DropdownButtonFormField<MasterEquipmentTemplate>(
                        value: _selectedTemplate,
                        decoration: const InputDecoration(
                          labelText: 'Equipment Template',
                          prefixIcon: Icon(Icons.electrical_services),
                          border: OutlineInputBorder(),
                        ),
                        items: _equipmentTemplates.map((template) {
                          return DropdownMenuItem<MasterEquipmentTemplate>(
                            value: template,
                            child: Row(
                              children: [
                                SizedBox(
                                  width: _getSymbolPreviewSize(
                                    template.symbolKey,
                                  ).width,
                                  height: _getSymbolPreviewSize(
                                    template.symbolKey,
                                  ).height,
                                  child: CustomPaint(
                                    painter: _getSymbolPreviewPainter(
                                      template.symbolKey,
                                      Theme.of(context).colorScheme.onSurface,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Text(template.equipmentType),
                              ],
                            ),
                          );
                        }).toList(),
                        onChanged: _onTemplateSelected,
                        validator: (value) => value == null
                            ? 'Please select an equipment type'
                            : null,
                      ),
                    const SizedBox(height: 24),

                    if (_selectedTemplate != null) ...[
                      Text(
                        'Template-defined Properties for ${_selectedTemplate!.equipmentType}',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 16),
                      if (_selectedTemplate!.equipmentCustomFields.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          child: Text(
                            'This template has no predefined custom fields.',
                            style: TextStyle(
                              fontStyle: FontStyle.italic,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        )
                      else
                        // These are the actual input fields for template-defined properties
                        ..._selectedTemplate!.equipmentCustomFields.map((
                          field,
                        ) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8.0),
                            child: _buildFieldInput(
                              fieldName: field.name,
                              dataType: field.dataType
                                  .toString()
                                  .split('.')
                                  .last,
                              isMandatory: field.isMandatory,
                              hasUnits: field.units.isNotEmpty,
                              units: field.units,
                              options: field.options,
                              isUserAddedField:
                                  false, // This is a template field
                              hasRemarksField: field.hasRemarksField,
                            ),
                          );
                        }).toList(),
                      const SizedBox(height: 24),

                      Text(
                        'Define Additional Custom Properties (for this instance)', // Clarified purpose
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      // This ListView builds the *definitions* for user-added fields
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _userAddedCustomFieldDefinitions.length,
                        itemBuilder: (context, index) {
                          final fieldDef =
                              _userAddedCustomFieldDefinitions[index];
                          return _buildUserAddedFieldDefinitionInput(
                            fieldDef,
                            index,
                          );
                        },
                      ),
                      ElevatedButton.icon(
                        onPressed: _addUserCustomField,
                        icon: const Icon(Icons.add),
                        label: const Text('Add New Custom Field Definition'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(
                            context,
                          ).colorScheme.secondary,
                          foregroundColor: Theme.of(
                            context,
                          ).colorScheme.onSecondary,
                        ),
                      ),
                      const SizedBox(height: 32),

                      // REMOVED THE SECTION FOR RENDERING "Values for Additional Custom Properties"
                      // because this screen is for template definition, not value filling.
                      Center(
                        child: _isSavingEquipment
                            ? const CircularProgressIndicator()
                            : ElevatedButton.icon(
                                onPressed: _selectedTemplate != null
                                    ? _saveEquipmentInstance
                                    : null,
                                icon: const Icon(Icons.save),
                                label: const Text('Save Equipment to Bay'),
                                style: ElevatedButton.styleFrom(
                                  minimumSize: const Size(double.infinity, 50),
                                ),
                              ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
    );
  }
}

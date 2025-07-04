// lib/screens/equipment_assignment_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../models/equipment_model.dart';
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

  // Supported data types for user-added custom fields (excluding 'group')
  final List<String> _dataTypes = [
    'text',
    'number',
    'boolean',
    'date',
    'dropdown',
  ];

  // Map to store values for template-defined fields (mapped by field name)
  // This map now holds the actual values to be saved in customFieldValues.
  // For 'group' types, it will hold a List<Map<String, dynamic>>
  final Map<String, dynamic> _templateCustomFieldValues = {};

  // For dynamically added custom fields by the user for this instance
  // This list now holds CustomField definitions added by the user
  final List<Map<String, dynamic>> _userAddedCustomFieldDefinitions = [];

  // Centralized controllers for ALL fields (template-defined and user-added), keyed by a unique path
  final Map<String, TextEditingController> _textControllers = {};
  final Map<String, bool> _booleanValues = {};
  final Map<String, DateTime?> _dateValues = {};
  final Map<String, String?> _dropdownValues = {};
  // For boolean remarks controller, use a unique key if needed (e.g., "fieldName_remarks")

  @override
  void initState() {
    super.initState();
    _fetchEquipmentTemplates();
  }

  @override
  void dispose() {
    // Dispose all text controllers created
    _textControllers.forEach((key, controller) => controller.dispose());
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
      _templateCustomFieldValues.clear(); // Clear all previous values
      _userAddedCustomFieldDefinitions.clear(); // Clear user added definitions
      _clearAllControllers(); // Clear and dispose all controllers

      if (_selectedTemplate != null) {
        // Initialize the top-level template-defined custom field values and controllers
        _initializeCustomFieldValues(
          _selectedTemplate!.equipmentCustomFields,
          _templateCustomFieldValues,
          'template',
        );
      }
    });
  }

  // Helper to clear and dispose all controllers
  void _clearAllControllers() {
    _textControllers.forEach((key, controller) => controller.dispose());
    _textControllers.clear();
    _booleanValues.clear();
    _dateValues.clear();
    _dropdownValues.clear();
  }

  // Recursive helper to initialize the value maps and controllers for fields
  // prefix is used to create unique keys for controllers in nested structures.
  // This also handles loading existing values if available (e.g. from an edit scenario, which is not implemented here yet)
  void _initializeCustomFieldValues(
    List<CustomField> fields,
    Map<String, dynamic> currentValuesMap,
    String prefix,
  ) {
    for (var field in fields) {
      final String uniqueControllerKey = prefix.isEmpty
          ? field.name
          : '${prefix}_${field.name}';
      final String dataType = field.dataType.toString().split('.').last;

      // Ensure the map has a placeholder for this field's value
      currentValuesMap.putIfAbsent(field.name, () => null);

      if (dataType == 'text' || dataType == 'number') {
        _textControllers[uniqueControllerKey] = TextEditingController(
          text: (currentValuesMap[field.name] as String?) ?? '',
        );
      } else if (dataType == 'boolean') {
        _booleanValues[uniqueControllerKey] =
            (currentValuesMap[field.name]?['value'] as bool?) ?? false;
        // If there are boolean remarks, create a controller for them too
        _textControllers['${uniqueControllerKey}_remarks'] =
            TextEditingController(
              text:
                  (currentValuesMap[field.name]?['description_remarks']
                      as String?) ??
                  '',
            );
      } else if (dataType == 'date') {
        _dateValues[uniqueControllerKey] =
            (currentValuesMap[field.name] as Timestamp?)?.toDate();
      } else if (dataType == 'dropdown') {
        _dropdownValues[uniqueControllerKey] =
            (currentValuesMap[field.name] as String?);
      } else if (dataType == 'group') {
        // For 'group' type, initialize with an empty list if null, then recursively initialize its items
        currentValuesMap.putIfAbsent(field.name, () => []);
        if (field.nestedFields != null && field.nestedFields!.isNotEmpty) {
          // Iterate existing nested items (if loading data for editing)
          final List<dynamic> existingItems =
              currentValuesMap[field.name] as List<dynamic>;
          for (int i = 0; i < existingItems.length; i++) {
            _initializeCustomFieldValues(
              field.nestedFields!,
              existingItems[i] as Map<String, dynamic>,
              '${uniqueControllerKey}_item_$i',
            );
          }
        }
      }
    }
  }

  // Helper to add a new basic type custom field definition to _userAddedCustomFieldDefinitions
  void _addUserCustomFieldDefinition() {
    setState(() {
      final Map<String, dynamic> newFieldDef = {
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
        'nestedFields': null, // No nested fields by default
      };
      _userAddedCustomFieldDefinitions.add(newFieldDef);
      // Initialize controllers for this new definition (with a unique prefix)
      _initializeCustomFieldValues(
        [CustomField.fromMap(newFieldDef)],
        newFieldDef,
        'user_added_${_userAddedCustomFieldDefinitions.length - 1}',
      );
    });
  }

  // Helper to add a new group type custom field definition to _userAddedCustomFieldDefinitions
  void _addUserGroupFieldDefinition() {
    setState(() {
      final Map<String, dynamic> newFieldDef = {
        'name': '',
        'dataType': CustomFieldDataType.group
            .toString()
            .split('.')
            .last, // Set as group type
        'isMandatory': false,
        'nestedFields': [], // Initialize with empty list of nested fields
        // FIX: Initialize other properties that might be accessed by _buildUserAddedFieldDefinitionInput
        'hasUnits': false,
        'units': '',
        'options': [],
        'hasRemarksField': false,
        'templateRemarkText': '',
      };
      _userAddedCustomFieldDefinitions.add(newFieldDef);
      // Initialize controllers for this new definition (with a unique prefix)
      _initializeCustomFieldValues(
        [CustomField.fromMap(newFieldDef)],
        newFieldDef,
        'user_added_group_${_userAddedCustomFieldDefinitions.length - 1}',
      );
    });
  }

  // Helper to remove a user-added field definition and its associated controllers
  void _removeUserCustomFieldDefinition(int index) {
    setState(() {
      final Map<String, dynamic> removedFieldDef =
          _userAddedCustomFieldDefinitions[index];
      // Generate the unique prefix used for controllers of this definition
      final String uniquePrefix =
          (removedFieldDef['dataType'] ==
              CustomFieldDataType.group.toString().split('.').last)
          ? 'user_added_group_$index'
          : 'user_added_$index';

      // Clean up controllers recursively associated with this definition
      _cleanupControllers(
        [CustomField.fromMap(removedFieldDef)],
        removedFieldDef,
        uniquePrefix,
      );
      _userAddedCustomFieldDefinitions.removeAt(index);
      // Note: If using index-based prefixes, removal means subsequent items' prefixes are now stale.
      // For a robust solution, consider using UUIDs for items or re-initializing all controllers on removal.
    });
  }

  // Helper to add a new item to a 'group' type custom field (for user-added groups)
  void _addNestedFieldDefinitionToUserDefinedGroup(
    Map<String, dynamic> groupFieldMap,
  ) {
    setState(() {
      final List<dynamic> nestedFieldsList =
          groupFieldMap['nestedFields'] as List<dynamic>;
      final Map<String, dynamic> newNestedFieldDef = {
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
        'nestedFields':
            null, // Nested fields of nested fields are null by default
      };
      nestedFieldsList.add(newNestedFieldDef);
      // Initialize controllers for this new nested definition
      final String groupPrefix =
          'user_added_group_${_userAddedCustomFieldDefinitions.indexOf(groupFieldMap)}'; // Find parent group's index
      final String newNestedPrefix =
          '${groupPrefix}_item_${nestedFieldsList.length - 1}';
      _initializeCustomFieldValues(
        [CustomField.fromMap(newNestedFieldDef)],
        newNestedFieldDef,
        newNestedPrefix,
      );
    });
  }

  // Helper to remove an item from a 'group' type custom field (for user-added groups)
  void _removeNestedFieldDefinitionFromUserDefinedGroup(
    List<Map<String, dynamic>> parentNestedList,
    int nestedIndex,
    Map<String, dynamic> parentGroupFieldMap,
  ) {
    setState(() {
      final Map<String, dynamic> removedNestedFieldDef =
          parentNestedList[nestedIndex];
      final String groupPrefix =
          'user_added_group_${_userAddedCustomFieldDefinitions.indexOf(parentGroupFieldMap)}';
      final String removedNestedPrefix = '${groupPrefix}_item_$nestedIndex';
      _cleanupControllers(
        [CustomField.fromMap(removedNestedFieldDef)],
        removedNestedFieldDef,
        removedNestedPrefix,
      );
      parentNestedList.removeAt(nestedIndex);
    });
  }

  // Recursive helper to clean up controllers associated with field values
  void _cleanupControllers(
    List<CustomField> fields,
    Map<String, dynamic> valuesMap,
    String prefix,
  ) {
    for (var field in fields) {
      final String uniqueControllerKey = prefix.isEmpty
          ? field.name
          : '${prefix}_${field.name}';
      final String dataType = field.dataType.toString().split('.').last;

      if (dataType == 'text' || dataType == 'number') {
        _textControllers[uniqueControllerKey]?.dispose();
        _textControllers.remove(uniqueControllerKey);
      } else if (dataType == 'boolean') {
        _booleanValues.remove(uniqueControllerKey);
        _textControllers['${uniqueControllerKey}_remarks']?.dispose();
        _textControllers.remove('${uniqueControllerKey}_remarks');
      } else if (dataType == 'date') {
        _dateValues.remove(uniqueControllerKey);
      } else if (dataType == 'dropdown') {
        _dropdownValues.remove(uniqueControllerKey);
      } else if (dataType == 'group') {
        List<dynamic> nestedList =
            (valuesMap[field.name] as List<dynamic>?) ??
            []; // Handle potential null
        for (int i = 0; i < nestedList.length; i++) {
          _cleanupControllers(
            field.nestedFields ?? [],
            nestedList[i] as Map<String, dynamic>,
            '${uniqueControllerKey}_item_$i',
          );
        }
      }
    }
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
      // 1. Collect values for template-defined custom fields
      Map<String, dynamic> templateCustomFieldValuesCollected =
          _collectCustomFieldValues(
            _selectedTemplate!.equipmentCustomFields,
            _templateCustomFieldValues,
            'template',
          );

      // 2. Collect values for user-added custom field definitions
      Map<String, dynamic> userAddedCustomFieldValuesCollected = {};
      for (int i = 0; i < _userAddedCustomFieldDefinitions.length; i++) {
        final Map<String, dynamic> fieldDefMap =
            _userAddedCustomFieldDefinitions[i];
        final CustomField userAddedFieldDef = CustomField.fromMap(fieldDefMap);
        final String uniquePrefix =
            (userAddedFieldDef.dataType == CustomFieldDataType.group)
            ? 'user_added_group_$i'
            : 'user_added_$i';

        // Recursively collect values for this user-added field definition
        Map<String, dynamic> collectedValueForThisField =
            _collectCustomFieldValues(
              [userAddedFieldDef],
              fieldDefMap,
              uniquePrefix,
            ); // Pass the definition map as its value source

        // Extract the actual value for this field's name
        if (collectedValueForThisField.containsKey(userAddedFieldDef.name)) {
          userAddedCustomFieldValuesCollected[userAddedFieldDef.name] =
              collectedValueForThisField[userAddedFieldDef.name];
        }
      }

      // Combine all custom field values (template-defined + user-added)
      Map<String, dynamic> allCustomFieldValues = {
        ...templateCustomFieldValuesCollected,
        ...userAddedCustomFieldValuesCollected,
      };

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
        Navigator.of(context).pop();
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

  // Recursive helper to collect all custom field values from controllers into a nested map
  // It now collects from the `_textControllers` map directly.
  Map<String, dynamic> _collectCustomFieldValues(
    List<CustomField> fieldDefinitions,
    Map<String, dynamic> currentValuesMap,
    String prefix,
  ) {
    Map<String, dynamic> collectedValues = {};
    for (var fieldDef in fieldDefinitions) {
      final String fieldName = fieldDef.name;
      final String uniqueControllerKey = prefix.isEmpty
          ? fieldName
          : '${prefix}_$fieldName';
      final String dataType = fieldDef.dataType.toString().split('.').last;

      if (dataType == 'text' || dataType == 'number') {
        final value = _textControllers[uniqueControllerKey]?.text.trim();
        collectedValues[fieldName] =
            dataType == 'number' && value != null && value.isNotEmpty
            ? num.tryParse(value)
            : value;
      } else if (dataType == 'boolean') {
        collectedValues[fieldName] = {
          'value': _booleanValues[uniqueControllerKey] ?? false,
          'description_remarks':
              _textControllers['${uniqueControllerKey}_remarks']?.text.trim(),
        };
      } else if (dataType == 'date') {
        collectedValues[fieldName] = _dateValues[uniqueControllerKey] != null
            ? Timestamp.fromDate(_dateValues[uniqueControllerKey]!)
            : null;
      } else if (dataType == 'dropdown') {
        collectedValues[fieldName] = _dropdownValues[uniqueControllerKey];
      } else if (dataType == 'group') {
        // Recursively collect values for each item in the group
        List<dynamic> groupItems =
            (currentValuesMap[fieldName] as List<dynamic>?) ??
            []; // Safely cast and handle null
        List<Map<String, dynamic>> collectedGroupItems = [];
        for (int i = 0; i < groupItems.length; i++) {
          collectedGroupItems.add(
            _collectCustomFieldValues(
              fieldDef.nestedFields ?? [],
              groupItems[i] as Map<String, dynamic>,
              '${uniqueControllerKey}_item_$i',
            ),
          );
        }
        collectedValues[fieldName] = collectedGroupItems;
      }
    }
    return collectedValues;
  }

  // This _buildFieldInput is for rendering the *values* of template-defined fields.
  // It now explicitly handles the 'group' type by displaying a message.
  Widget _buildFieldInput({
    required CustomField fieldDef,
    required Map<String, dynamic>
    currentValuesMap, // The map where this field's value lives
    required String prefix, // Prefix for unique controller keys
  }) {
    final String fieldName = fieldDef.name;
    final String uniqueControllerKey = prefix.isEmpty
        ? fieldName
        : '${prefix}_$fieldName';
    final String dataType = fieldDef.dataType.toString().split('.').last;
    final bool isMandatory = fieldDef.isMandatory;
    final String? unit = fieldDef.units.isNotEmpty ? fieldDef.units : null;
    final List<String> options = fieldDef.options;
    final bool hasRemarksField = fieldDef.hasRemarksField;

    String? Function(String?)? validator;
    if (isMandatory) {
      validator = (value) {
        if (value == null || value.isEmpty) {
          return '$fieldName is mandatory';
        }
        return null;
      };
    }

    Widget fieldWidget;
    switch (dataType) {
      case 'text':
        fieldWidget = TextFormField(
          controller: _textControllers.putIfAbsent(
            uniqueControllerKey,
            () => TextEditingController(
              text: (currentValuesMap[fieldName] as String?) ?? '',
            ),
          ),
          decoration: InputDecoration(
            labelText: fieldName + (isMandatory ? ' *' : ''),
            border: const OutlineInputBorder(),
          ),
          onChanged: (value) => currentValuesMap[fieldName] = value,
          validator: validator,
        );
        break;
      case 'number':
        fieldWidget = TextFormField(
          controller: _textControllers.putIfAbsent(
            uniqueControllerKey,
            () => TextEditingController(
              text: (currentValuesMap[fieldName]?.toString()) ?? '',
            ),
          ),
          decoration: InputDecoration(
            labelText: fieldName + (isMandatory ? ' *' : ''),
            border: const OutlineInputBorder(),
            suffixText: unit,
          ),
          keyboardType: TextInputType.number,
          onChanged: (value) =>
              currentValuesMap[fieldName] = num.tryParse(value),
          validator: (value) {
            if (validator != null && validator(value) != null)
              return validator(value);
            if (value!.isNotEmpty && num.tryParse(value) == null)
              return 'Enter a valid number for $fieldName';
            return null;
          },
        );
        break;
      case 'boolean':
        final bool currentBooleanValue = _booleanValues.putIfAbsent(
          uniqueControllerKey,
          () => (currentValuesMap[fieldName]?['value'] as bool?) ?? false,
        );
        fieldWidget = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SwitchListTile(
              title: Text(fieldName + (isMandatory ? ' *' : '')),
              value: currentBooleanValue,
              onChanged: (value) {
                setState(() {
                  _booleanValues[uniqueControllerKey] = value;
                  currentValuesMap[fieldName] = {
                    'value': value,
                    'description_remarks':
                        currentValuesMap[fieldName]?['description_remarks'],
                  };
                });
              },
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
            ),
            if (hasRemarksField && currentBooleanValue)
              Padding(
                padding: const EdgeInsets.only(
                  left: 16.0,
                  right: 16.0,
                  bottom: 8.0,
                ),
                child: TextFormField(
                  controller: _textControllers.putIfAbsent(
                    '${uniqueControllerKey}_remarks',
                    () => TextEditingController(
                      text:
                          (currentValuesMap[fieldName]?['description_remarks']
                              as String?) ??
                          '',
                    ),
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
                  onChanged: (value) =>
                      currentValuesMap[fieldName]['description_remarks'] =
                          value,
                ),
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
        break;
      case 'date':
        final DateTime? currentDate = _dateValues.putIfAbsent(
          uniqueControllerKey,
          () => (currentValuesMap[fieldName] as Timestamp?)?.toDate(),
        );
        fieldWidget = ListTile(
          title: Text(
            fieldName +
                (isMandatory ? ' *' : '') +
                ': ' +
                (currentDate == null
                    ? 'Select Date'
                    : DateFormat('yyyy-MM-dd').format(currentDate)),
          ),
          trailing: const Icon(Icons.calendar_today),
          onTap: () async {
            final DateTime? picked = await showDatePicker(
              context: context,
              initialDate: currentDate ?? DateTime.now(),
              firstDate: DateTime(1900),
              lastDate: DateTime.now().add(const Duration(days: 365 * 100)),
            );
            if (picked != null) {
              setState(() {
                _dateValues[uniqueControllerKey] = picked;
                currentValuesMap[fieldName] = Timestamp.fromDate(picked);
              });
            }
          },
        );
        break;
      case 'dropdown':
        fieldWidget = DropdownButtonFormField<String>(
          value: _dropdownValues.putIfAbsent(
            uniqueControllerKey,
            () => (currentValuesMap[fieldName] as String?),
          ),
          decoration: InputDecoration(
            labelText: fieldName + (isMandatory ? ' *' : ''),
            border: const OutlineInputBorder(),
          ),
          items: options.map((option) {
            return DropdownMenuItem(value: option, child: Text(option));
          }).toList(),
          onChanged: (value) {
            setState(() {
              _dropdownValues[uniqueControllerKey] = value;
              currentValuesMap[fieldName] = value;
            });
          },
          validator: validator,
        );
        break;
      case 'group': // Explicitly handle 'group' type
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 8.0),
          elevation: 1,
          color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$fieldName (Group Type - Data Entry Not Fully Supported Here)',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontStyle: FontStyle.italic,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'This field is a group type. Its complex structure for data entry is not fully integrated with this screen\'s current input mechanism. Please define its items in Master Equipment Templates.',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: Colors.grey.shade700),
                ),
              ],
            ),
          ),
        );
      default:
        return Text('Unsupported data type: $dataType for ${fieldDef.name}');
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: fieldWidget,
    );
  }

  // This function is purely for defining the properties of a custom field.
  // It builds the UI for dynamically user-added fields (not template fields).
  // It now supports adding nested fields within user-defined groups.
  Widget _buildUserAddedFieldDefinitionInput(
    Map<String, dynamic>
    fieldDefMap, // Map holding the definition of this field
    int index,
    List<Map<String, dynamic>>
    parentList, { // Reference to the list this definition belongs to
    bool isNestedDefinition = false, // Flag for nested definition
  }) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final String fieldName = fieldDefMap['name'] as String;
    final String dataType = fieldDefMap['dataType'] as String;
    final bool isMandatory = fieldDefMap['isMandatory'] as bool;
    final bool hasUnits = fieldDefMap['hasUnits'] as bool;
    final String units = fieldDefMap['units'] as String;
    final List<String> options = List<String>.from(
      fieldDefMap['options'] ?? [],
    );
    final bool hasRemarksField = fieldDefMap['hasRemarksField'] as bool;

    // Determine if this definition is for a Group field
    final bool isGroupFieldDefinition =
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
                labelText: isNestedDefinition
                    ? 'Nested Field Name'
                    : 'Custom Field Name',
                border: const OutlineInputBorder(),
                hintText: isNestedDefinition
                    ? 'e.g., Value, Unit'
                    : 'e.g., Max Current, Last Inspection Date',
              ),
              onChanged: (value) => fieldDefMap['name'] = value,
              validator: (value) => value == null || value.trim().isEmpty
                  ? (isNestedDefinition
                        ? 'Nested field name required'
                        : 'Custom field name required')
                  : null,
            ),
            const SizedBox(height: 10),

            // Data Type dropdown (hidden if it's a Group field definition)
            if (!isGroupFieldDefinition)
              DropdownButtonFormField<String>(
                value: dataType,
                decoration: const InputDecoration(
                  labelText: 'Data Type',
                  border: OutlineInputBorder(),
                ),
                items:
                    _dataTypes // Use the _dataTypes list (does not include 'group')
                        .map(
                          (type) =>
                              DropdownMenuItem(value: type, child: Text(type)),
                        )
                        .toList(),
                onChanged: (value) {
                  setState(() {
                    fieldDefMap['dataType'] = value!;
                    // Reset properties based on new data type
                    fieldDefMap['options'] = [];
                    fieldDefMap['hasUnits'] = false;
                    fieldDefMap['units'] = '';
                    fieldDefMap['hasRemarksField'] = false;
                    fieldDefMap['templateRemarkText'] = '';
                    fieldDefMap['nestedFields'] =
                        null; // Ensure null if changing from group
                    // No need for separate controller cleanup/re-init here, handled by _removeUserCustomFieldDefinition
                    // For user-added definitions, values are stored in the definition map itself.
                  });
                },
              ),
            // Display 'Group' label if it is a Group field definition
            if (isGroupFieldDefinition)
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

            // Conditional UI based on data types (only if not a group field definition)
            if (!isGroupFieldDefinition) ...[
              if (dataType == 'dropdown')
                TextFormField(
                  initialValue: options.join(','),
                  decoration: const InputDecoration(
                    labelText: 'Options (comma-separated)',
                    border: OutlineInputBorder(),
                    hintText: 'e.g., Option1, Option2, Option3',
                  ),
                  onChanged: (value) => fieldDefMap['options'] = value
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
                            setState(() => fieldDefMap['hasUnits'] = value),
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
                      labelText: 'Units',
                      hintText: 'e.g., A, kV, MW',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (value) => fieldDefMap['units'] = value,
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
                  initialValue: fieldDefMap['description_remarks'] as String?,
                  decoration: const InputDecoration(
                    labelText: 'Description / Remarks (Optional)',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (value) =>
                      fieldDefMap['description_remarks'] = value,
                  maxLines: 2,
                ),
              ],
            ], // End of if (!isGroupFieldDefinition)
            // UI for 'group' type custom field (nested fields management)
            if (isGroupFieldDefinition) ...[
              const SizedBox(height: 10),
              Text(
                'Nested Fields in this Group:',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              if ((fieldDefMap['nestedFields'] as List<dynamic>).isEmpty)
                const Padding(
                  padding: EdgeInsets.only(bottom: 8.0),
                  child: Text('No nested fields defined for this group.'),
                ),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount:
                    (fieldDefMap['nestedFields'] as List<dynamic>).length,
                itemBuilder: (context, nestedIndex) {
                  final nestedFieldDefMap =
                      (fieldDefMap['nestedFields']
                          as List<dynamic>)[nestedIndex];
                  return _buildUserAddedFieldDefinitionInput(
                    nestedFieldDefMap,
                    nestedIndex, // Pass this index
                    (fieldDefMap['nestedFields'] as List<dynamic>)
                        .cast<
                          Map<String, dynamic>
                        >(), // Pass the nested list as parent
                    isNestedDefinition: true,
                  );
                },
              ),
              ElevatedButton.icon(
                onPressed: () =>
                    _addNestedFieldDefinitionToUserDefinedGroup(fieldDefMap),
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
                  setState(() => fieldDefMap['isMandatory'] = value!),
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
                onPressed: () => _removeUserCustomFieldDefinition(index),
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
      case 'circuit breaker':
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
                        'Equipment Properties',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 16),
                      if (_selectedTemplate!.equipmentCustomFields.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          child: Text(
                            'This template has no custom fields defined.',
                            style: TextStyle(
                              fontStyle: FontStyle.italic,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        )
                      else
                        // These are the actual input fields for template-defined properties
                        // Note: Group type fields will show a placeholder message.
                        ..._selectedTemplate!.equipmentCustomFields.map((
                          field,
                        ) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8.0),
                            child: _buildFieldInput(
                              fieldDef: field, // Pass CustomField object
                              currentValuesMap: _templateCustomFieldValues,
                              prefix:
                                  'template_field', // Common prefix for template fields
                            ),
                          );
                        }).toList(),
                      const SizedBox(height: 24),

                      Text(
                        'Define Additional Custom Properties (for this instance)',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      // This ListView builds the *definitions* for user-added fields
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _userAddedCustomFieldDefinitions.length,
                        itemBuilder: (context, index) {
                          final fieldDefMap =
                              _userAddedCustomFieldDefinitions[index];
                          // Pass the definition map to manage its properties
                          return _buildUserAddedFieldDefinitionInput(
                            fieldDefMap,
                            index,
                            _userAddedCustomFieldDefinitions, // Pass list for removal
                          );
                        },
                      ),
                      // Buttons for adding user-defined custom fields
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _addUserCustomFieldDefinition,
                              icon: const Icon(Icons.add),
                              label: const Text('Add Field'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Theme.of(
                                  context,
                                ).colorScheme.secondary,
                                foregroundColor: Theme.of(
                                  context,
                                ).colorScheme.onSecondary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _addUserGroupFieldDefinition,
                              icon: const Icon(
                                Icons.group_add,
                              ), // Icon for adding a group
                              label: const Text('Add Group Field'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Theme.of(
                                  context,
                                ).colorScheme.secondary,
                                foregroundColor: Theme.of(
                                  context,
                                ).colorScheme.onSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),

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

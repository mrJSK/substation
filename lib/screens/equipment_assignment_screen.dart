// lib/screens/equipment_assignment_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart'; // Import Uuid for generating unique keys
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

  final Map<String, dynamic> _templateCustomFieldValues = {};

  // MODIFIED: This now holds the definitions AND values for user-added fields
  final List<Map<String, dynamic>> _userAddedCustomFields = [];

  final Map<String, TextEditingController> _textControllers = {};
  final Map<String, bool> _booleanValues = {};
  final Map<String, DateTime?> _dateValues = {};
  final Map<String, String?> _dropdownValues = {};

  final List<String> _dataTypes = [
    'text',
    'number',
    'boolean',
    'date',
    'dropdown',
  ];

  final Uuid _uuid = const Uuid();

  @override
  void initState() {
    super.initState();
    _fetchEquipmentTemplates();
  }

  @override
  void dispose() {
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
    _templateCustomFieldValues.clear();
    _userAddedCustomFields.clear();
    _clearAllControllers();

    _selectedTemplate = template;

    if (_selectedTemplate != null) {
      _initializeCustomFieldValues(
        _selectedTemplate!.equipmentCustomFields,
        _templateCustomFieldValues,
        'template',
      );
    }

    setState(() {});
  }

  void _clearAllControllers() {
    _textControllers.forEach((key, controller) => controller.dispose());
    _textControllers.clear();
    _booleanValues.clear();
    _dateValues.clear();
    _dropdownValues.clear();
  }

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

      currentValuesMap.putIfAbsent(field.name, () => null);

      if (dataType == 'text' || dataType == 'number') {
        _textControllers[uniqueControllerKey] = TextEditingController(
          text: (currentValuesMap[field.name] as String?) ?? '',
        );
      } else if (dataType == 'boolean') {
        _booleanValues[uniqueControllerKey] =
            (currentValuesMap[field.name]?['value'] as bool?) ?? false;
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
        Map<String, dynamic> groupItemMap;
        if (currentValuesMap[field.name] is Map<String, dynamic>) {
          groupItemMap = currentValuesMap[field.name] as Map<String, dynamic>;
        } else {
          groupItemMap = {};
          currentValuesMap[field.name] = groupItemMap;
        }

        if (field.nestedFields != null && field.nestedFields!.isNotEmpty) {
          _initializeCustomFieldValues(
            field.nestedFields!,
            groupItemMap,
            '${uniqueControllerKey}_item_single',
          );
        }
      }
    }
  }

  // MODIFIED: Methods to manage user-added fields for the instance
  void _addUserCustomField() {
    setState(() {
      final newField = {
        'uuid': _uuid.v4(),
        'definition': {
          'name': '',
          'dataType': 'text',
          'isMandatory': false,
          'options': [],
          'units': '',
        },
        'value': null,
      };
      _userAddedCustomFields.add(newField);
    });
  }

  void _addUserGroupField() {
    setState(() {
      final newField = {
        'uuid': _uuid.v4(),
        'definition': {
          'name': '',
          'dataType': 'group',
          'isMandatory': false,
          'nestedFields': [],
        },
        'value': {},
      };
      _userAddedCustomFields.add(newField);
    });
  }

  void _removeUserCustomField(int index) {
    setState(() {
      final removedField = _userAddedCustomFields[index];
      // Cleanup controllers associated with this field
      final prefix = 'user_added_${removedField['uuid']}';
      // This is a simplified cleanup. A more robust solution would recursively
      // clean up controllers for nested fields in a group.
      _textControllers.removeWhere((key, value) => key.startsWith(prefix));
      _booleanValues.removeWhere((key, value) => key.startsWith(prefix));
      _dateValues.removeWhere((key, value) => key.startsWith(prefix));
      _dropdownValues.removeWhere((key, value) => key.startsWith(prefix));

      _userAddedCustomFields.removeAt(index);
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
      // 1. Collect values for template-defined fields
      Map<String, dynamic> templateCustomFieldValuesCollected =
          _collectCustomFieldValues(
            _selectedTemplate!.equipmentCustomFields,
            _templateCustomFieldValues,
            'template',
          );

      // 2. Collect user-added custom fields (definitions and values)
      Map<String, dynamic> userAddedFieldsToSave = {};
      for (var userField in _userAddedCustomFields) {
        final definition = userField['definition'] as Map<String, dynamic>;
        final fieldName = definition['name'] as String;
        if (fieldName.trim().isNotEmpty) {
          // Here, we save both the definition and the value.
          // The structure in Firestore will be slightly different for these.
          // For simplicity, we'll store the value directly under its name,
          // assuming the app can later infer the type if needed, or we store definition alongside.
          // Let's store a map containing both.
          userAddedFieldsToSave[fieldName] = {
            'definition': definition,
            'value': userField['value'], // The value entered by the user.
          };
        }
      }

      // Combine all custom field values
      Map<String, dynamic> allCustomFieldValues = {
        ...templateCustomFieldValuesCollected,
        ...userAddedFieldsToSave,
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

  Map<String, dynamic> _collectCustomFieldValues(
    List<CustomField> fieldDefinitions,
    Map<String, dynamic> currentValuesMap,
    String prefix,
  ) {
    Map<String, dynamic> collectedValues = {};
    for (var fieldDef in fieldDefinitions) {
      final String fieldName = fieldDef.name;
      final String itemIdentifier =
          currentValuesMap['uuid'] as String? ?? fieldName;
      final String uniqueControllerKey = prefix.isEmpty
          ? itemIdentifier
          : '${prefix}_$itemIdentifier';
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
        // MODIFIED for single instance group
        Map<String, dynamic> groupItemMap =
            (currentValuesMap[fieldName] as Map<String, dynamic>?) ?? {};
        collectedValues[fieldName] = _collectCustomFieldValues(
          fieldDef.nestedFields ?? [],
          groupItemMap,
          '${uniqueControllerKey}_item_single',
        );
      }
    }
    return collectedValues;
  }

  // This widget builds the UI for template-defined fields.
  Widget _buildFieldInput({
    required CustomField fieldDef,
    required Map<String, dynamic> currentValuesMap,
    required String prefix,
  }) {
    // ... (This function remains mostly the same as the previous version, handling group as a single object)
    // No changes needed here from the last version you approved.
    final String fieldName = fieldDef.name;
    final String itemIdentifier =
        currentValuesMap['uuid'] as String? ?? fieldName;
    final String uniqueControllerKey = prefix.isEmpty
        ? itemIdentifier
        : '${prefix}_$itemIdentifier';
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
        return TextFormField(
          key: ValueKey(uniqueControllerKey),
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
      case 'number':
        fieldWidget = TextFormField(
          key: ValueKey(uniqueControllerKey),
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
              key: ValueKey(uniqueControllerKey),
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
                  key: ValueKey('${uniqueControllerKey}_remarks'),
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
          key: ValueKey(uniqueControllerKey),
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
          key: ValueKey(uniqueControllerKey),
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
      case 'group':
        if (currentValuesMap[fieldName] == null ||
            !(currentValuesMap[fieldName] is Map<String, dynamic>)) {
          currentValuesMap[fieldName] = <String, dynamic>{};
        }
        final Map<String, dynamic> itemValues =
            currentValuesMap[fieldName] as Map<String, dynamic>;
        final String itemPrefix = '${uniqueControllerKey}_item_single';

        return Card(
          margin: const EdgeInsets.symmetric(vertical: 8.0),
          elevation: 1,
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fieldName,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 8),
                if (fieldDef.nestedFields == null ||
                    fieldDef.nestedFields!.isEmpty)
                  Text(
                    'This group has no nested fields defined in its template.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey.shade700,
                    ),
                  )
                else
                  ...fieldDef.nestedFields!.map((nestedField) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: _buildFieldInput(
                        fieldDef: nestedField,
                        currentValuesMap: itemValues,
                        prefix: itemPrefix,
                      ),
                    );
                  }).toList(),
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

  // UPDATED WIDGET: Builds the UI for a user-added custom field with a vertical layout.
  Widget _buildUserAddedFieldInput(int index) {
    final fieldData = _userAddedCustomFields[index];
    final definition = fieldData['definition'] as Map<String, dynamic>;
    final uuid = fieldData['uuid'] as String;

    final String dataType = definition['dataType'];
    final String uniquePrefix = 'user_added_$uuid';

    return Card(
      key: ValueKey(uuid),
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Field Name Input
            TextFormField(
              initialValue: definition['name'],
              decoration: const InputDecoration(
                labelText: 'Field Name',
                border: OutlineInputBorder(),
              ),
              onChanged: (value) => definition['name'] = value,
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Field name is required'
                  : null,
            ),
            const SizedBox(height: 12),
            // Data Type Dropdown
            DropdownButtonFormField<String>(
              value: dataType,
              decoration: const InputDecoration(
                labelText: 'Data Type',
                border: OutlineInputBorder(),
              ),
              items: _dataTypes.map((type) {
                return DropdownMenuItem(value: type, child: Text(type));
              }).toList(),
              onChanged: (value) {
                setState(() {
                  definition['dataType'] = value!;
                  fieldData['value'] = null; // Reset value on type change
                });
              },
            ),
            const SizedBox(height: 12),
            // Input for the field's value
            _buildValueInputForUserAddedField(
              uniquePrefix,
              dataType,
              fieldData,
            ),
            const SizedBox(height: 10),
            // Remove button
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

  // Helper to build the value input part for a user-added field
  Widget _buildValueInputForUserAddedField(
    String prefix,
    String dataType,
    Map<String, dynamic> fieldData,
  ) {
    switch (dataType) {
      case 'text':
      case 'number':
        return TextFormField(
          decoration: InputDecoration(
            labelText: 'Value',
            border: const OutlineInputBorder(),
          ),
          keyboardType: dataType == 'number'
              ? TextInputType.number
              : TextInputType.text,
          onChanged: (value) => fieldData['value'] = value,
          validator: (value) {
            if (dataType == 'number' &&
                value != null &&
                value.isNotEmpty &&
                num.tryParse(value) == null) {
              return 'Please enter a valid number.';
            }
            return null;
          },
        );
      case 'boolean':
        return SwitchListTile(
          title: const Text('Value'),
          value: fieldData['value'] as bool? ?? false,
          onChanged: (newValue) {
            setState(() {
              fieldData['value'] = newValue;
            });
          },
        );
      case 'date':
        return ListTile(
          title: Text(
            fieldData['value'] == null
                ? 'Select Date'
                : 'Date: ${DateFormat('yyyy-MM-dd').format(fieldData['value'] as DateTime)}',
          ),
          trailing: const Icon(Icons.calendar_today),
          onTap: () async {
            final DateTime? picked = await showDatePicker(
              context: context,
              initialDate: (fieldData['value'] as DateTime?) ?? DateTime.now(),
              firstDate: DateTime(1900),
              lastDate: DateTime.now().add(const Duration(days: 36500)),
            );
            if (picked != null) {
              setState(() {
                fieldData['value'] = picked;
              });
            }
          },
        );
      case 'dropdown':
        final definition = fieldData['definition'] as Map<String, dynamic>;
        return Column(
          children: [
            TextFormField(
              decoration: const InputDecoration(
                labelText: 'Dropdown Options (comma-separated)',
                border: OutlineInputBorder(),
              ),
              onChanged: (value) {
                setState(() {
                  definition['options'] = value
                      .split(',')
                      .map((e) => e.trim())
                      .toList();
                });
              },
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(
                labelText: 'Select Value',
                border: OutlineInputBorder(),
              ),
              items:
                  (definition['options'] as List<dynamic>?)
                      ?.map(
                        (option) => DropdownMenuItem(
                          value: option.toString(),
                          child: Text(option.toString()),
                        ),
                      )
                      .toList() ??
                  [],
              onChanged: (value) {
                fieldData['value'] = value;
              },
            ),
          ],
        );
      default:
        return const SizedBox.shrink();
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
                        'Equipment Properties (from Template)',
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
                        ..._selectedTemplate!.equipmentCustomFields.map((
                          field,
                        ) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8.0),
                            child: _buildFieldInput(
                              fieldDef: field,
                              currentValuesMap: _templateCustomFieldValues,
                              prefix: 'template_field',
                            ),
                          );
                        }).toList(),
                      const SizedBox(height: 24),

                      // NEW SECTION: User-added custom fields
                      Text(
                        'Additional Custom Properties',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _userAddedCustomFields.length,
                        itemBuilder: (context, index) {
                          return _buildUserAddedFieldInput(index);
                        },
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _addUserCustomField,
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
                          // "Add Group" is more complex for instance-level, simplified for now
                          // To implement fully, you'd need a nested version of this logic.
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () {
                                SnackBarUtils.showSnackBar(
                                  context,
                                  "Instance-level group fields coming soon!",
                                );
                              },
                              icon: const Icon(Icons.add_box_outlined),
                              label: const Text('Add Group'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Theme.of(
                                  context,
                                ).colorScheme.secondary.withOpacity(0.5),
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

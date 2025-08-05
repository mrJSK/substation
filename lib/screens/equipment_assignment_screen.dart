// lib/screens/equipment_assignment_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../models/equipment_model.dart';
import '../utils/snackbar_utils.dart';
import '../../equipment_icons/transformer_icon.dart';
import '../../equipment_icons/busbar_icon.dart';
import '../../equipment_icons/circuit_breaker_icon.dart';
import '../../equipment_icons/ct_icon.dart';
import '../../equipment_icons/ground_icon.dart';
import '../../equipment_icons/isolator_icon.dart';
import '../../equipment_icons/pt_icon.dart';
import '../../equipment_icons/line_icon.dart';
import '../../equipment_icons/feeder_icon.dart';
import '../models/bay_model.dart'; // Import Bay model (still needed for bay type fetching if required elsewhere)

class EquipmentAssignmentScreen extends StatefulWidget {
  final String bayId;
  final String bayName;
  final String substationId;
  final EquipmentInstance? equipmentToEdit;

  const EquipmentAssignmentScreen({
    super.key,
    required this.bayId,
    required this.bayName,
    required this.substationId,
    this.equipmentToEdit,
  });

  @override
  State<EquipmentAssignmentScreen> createState() =>
      _EquipmentAssignmentScreenState();
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
  bool shouldRepaint(covariant _GenericIconPainter oldDelegate) => false;
}

class _EquipmentAssignmentScreenState extends State<EquipmentAssignmentScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  bool _isLoading = true;
  List<MasterEquipmentTemplate> _equipmentTemplates = [];
  MasterEquipmentTemplate? _selectedTemplate;
  bool _isSavingEquipment = false;

  final TextEditingController _makeController = TextEditingController();
  DateTime? _dateOfManufacturing;
  DateTime? _dateOfCommissioning;

  final Map<String, dynamic> _templateCustomFieldValues = {};
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
    _fetchEquipmentTemplatesAndInitialize();
  }

  @override
  void dispose() {
    _makeController.dispose();
    _textControllers.forEach((key, controller) => controller.dispose());
    super.dispose();
  }

  Future<void> _fetchEquipmentTemplatesAndInitialize() async {
    setState(() {
      _isLoading = true;
    });
    try {
      // No need to fetch bay type or existing transformer for conditional template filtering here.
      // All templates are always available.

      final snapshot = await FirebaseFirestore.instance
          .collection('masterEquipmentTemplates')
          .orderBy('equipmentType')
          .get();

      _equipmentTemplates = snapshot.docs
          .map((doc) => MasterEquipmentTemplate.fromFirestore(doc))
          .toList();

      if (widget.equipmentToEdit != null) {
        _initializeForEdit(widget.equipmentToEdit!);
      }
    } catch (e) {
      print("Error fetching equipment templates: $e");
      if (mounted) {
        SnackBarUtils.showSnackBar(
          context,
          'Failed to load equipment types: $e',
          isError: true,
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _initializeForEdit(EquipmentInstance equipment) {
    _selectedTemplate = _equipmentTemplates.firstWhere(
      (t) => t.id == equipment.templateId,
      orElse: () => _equipmentTemplates.first,
    );

    _makeController.text = equipment.make;
    _dateOfManufacturing = equipment.dateOfManufacturing?.toDate();
    _dateOfCommissioning = equipment.dateOfCommissioning?.toDate();

    _templateCustomFieldValues.addAll(equipment.customFieldValues);
    _initializeCustomFieldValues(
      _selectedTemplate!.equipmentCustomFields,
      _templateCustomFieldValues,
      'template_field',
    );
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
        'template_field',
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
      final dynamic value = currentValuesMap[field.name];

      if (dataType == 'text' || dataType == 'number') {
        _textControllers[uniqueControllerKey] = TextEditingController(
          text: value?.toString() ?? '',
        );
      } else if (dataType == 'boolean') {
        _booleanValues[uniqueControllerKey] =
            (value is Map && value.containsKey('value'))
            ? value['value']
            : false;
        _textControllers['${uniqueControllerKey}_remarks'] =
            TextEditingController(
              text: (value is Map && value.containsKey('description_remarks'))
                  ? value['description_remarks']
                  : '',
            );
      } else if (dataType == 'date') {
        _dateValues[uniqueControllerKey] = (value as Timestamp?)?.toDate();
      } else if (dataType == 'dropdown') {
        _dropdownValues[uniqueControllerKey] = value as String?;
      } else if (dataType == 'group') {
        if (value is Map<String, dynamic> && field.nestedFields != null) {
          _initializeCustomFieldValues(
            field.nestedFields!,
            value,
            '${uniqueControllerKey}_item_single',
          );
        }
      }
    }
  }

  void _addUserCustomField() {
    setState(() {
      final newField = {
        'uuid': _uuid.v4(),
        'definition': {'name': '', 'dataType': 'text'},
        'value': null,
      };
      _userAddedCustomFields.add(newField);
    });
  }

  void _addUserGroupField() {
    setState(() {
      final newField = {
        'uuid': _uuid.v4(),
        'definition': {'name': '', 'dataType': 'group', 'nestedFields': []},
        'value': <String, dynamic>{},
      };
      _userAddedCustomFields.add(newField);
    });
  }

  void _removeUserCustomField(int index) {
    setState(() {
      final removedField = _userAddedCustomFields[index];
      final prefix = 'user_added_${removedField['uuid']}';
      _textControllers.removeWhere((key, value) => key.startsWith(prefix));
      _booleanValues.removeWhere((key, value) => key.startsWith(prefix));
      _dateValues.removeWhere((key, value) => key.startsWith(prefix));
      _dropdownValues.removeWhere((key, value) => key.startsWith(prefix));
      _userAddedCustomFields.removeAt(index);
    });
  }

  void _addNestedFieldToUserAddedGroup(int groupIndex) {
    setState(() {
      final groupField = _userAddedCustomFields[groupIndex];
      final nestedFields = groupField['definition']['nestedFields'] as List;
      nestedFields.add(<String, dynamic>{
        'name': '',
        'dataType': 'text',
        'uuid': _uuid.v4(),
      });
    });
  }

  void _removeNestedFieldFromGroup(int groupIndex, int nestedIndex) {
    setState(() {
      final groupField = _userAddedCustomFields[groupIndex];
      final nestedFieldToRemove =
          (groupField['definition']['nestedFields'] as List)[nestedIndex];
      final groupValues = groupField['value'] as Map<String, dynamic>;
      final fieldUuid = nestedFieldToRemove['uuid'] as String?;
      if (fieldUuid != null) {
        groupValues.remove(fieldUuid);
      }
      (groupField['definition']['nestedFields'] as List).removeAt(nestedIndex);
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

    // No specific validation for Transformer bay type here anymore.
    // That validation is moved to BayEquipmentManagementScreen's save button.

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
      Map<String, dynamic> templateCustomFieldValuesCollected =
          _collectCustomFieldValues(
            _selectedTemplate!.equipmentCustomFields,
            _templateCustomFieldValues,
            'template_field',
          );

      Map<String, dynamic> userAddedFieldsToSave = {};
      for (var userField in _userAddedCustomFields) {
        final definition = userField['definition'] as Map<String, dynamic>;
        final fieldName = definition['name'] as String;

        if (fieldName.trim().isNotEmpty) {
          dynamic fieldValue = userField['value'];

          if (definition['dataType'] == 'group') {
            final groupValueMap = fieldValue as Map<String, dynamic>;
            final transformedGroupValues = <String, dynamic>{};
            final nestedFieldDefs = (definition['nestedFields'] as List)
                .cast<Map<String, dynamic>>();

            for (var nestedDef in nestedFieldDefs) {
              final nestedFieldName = nestedDef['name'] as String?;
              final nestedFieldUuid = nestedDef['uuid'] as String?;
              if (nestedFieldName != null &&
                  nestedFieldName.isNotEmpty &&
                  nestedFieldUuid != null &&
                  groupValueMap.containsKey(nestedFieldUuid)) {
                transformedGroupValues[nestedFieldName] =
                    groupValueMap[nestedFieldUuid];
              }
            }
            fieldValue = transformedGroupValues;
          }

          userAddedFieldsToSave[fieldName] = {
            'definition': definition,
            'value': fieldValue,
          };
        }
      }

      Map<String, dynamic> allCustomFieldValues = {
        ...templateCustomFieldValuesCollected,
        ...userAddedFieldsToSave,
      };

      if (widget.equipmentToEdit != null) {
        // Update existing equipment
        final updatedEquipment = widget.equipmentToEdit!.copyWith(
          make: _makeController.text.trim(),
          dateOfManufacturing: _dateOfManufacturing != null
              ? Timestamp.fromDate(_dateOfManufacturing!)
              : null,
          dateOfCommissioning: _dateOfCommissioning != null
              ? Timestamp.fromDate(_dateOfCommissioning!)
              : null,
          customFieldValues: allCustomFieldValues,
          positionIndex: widget
              .equipmentToEdit!
              .positionIndex, // Preserve existing position index
        );

        await FirebaseFirestore.instance
            .collection('equipmentInstances')
            .doc(updatedEquipment.id)
            .update(updatedEquipment.toFirestore());

        if (mounted) {
          SnackBarUtils.showSnackBar(
            context,
            'Equipment updated successfully!',
          );
          Navigator.of(context).pop();
        }
      } else {
        // Create new equipment
        final newEquipmentInstanceRef = FirebaseFirestore.instance
            .collection('equipmentInstances')
            .doc();

        // Determine a new positionIndex: Fetch current count of equipment in bay and add 1
        final existingEquipmentCount = await FirebaseFirestore.instance
            .collection('equipmentInstances')
            .where('bayId', isEqualTo: widget.bayId)
            .count()
            .get();
        final newPositionIndex = existingEquipmentCount.count ?? 0;

        final newEquipmentInstance = EquipmentInstance(
          id: newEquipmentInstanceRef.id,
          bayId: widget.bayId,
          templateId: _selectedTemplate!.id!,
          equipmentTypeName: _selectedTemplate!.equipmentType,
          symbolKey: _selectedTemplate!.symbolKey,
          createdBy: firebaseUser.uid,
          createdAt: Timestamp.now(),
          customFieldValues: allCustomFieldValues,
          make: _makeController.text.trim(),
          dateOfManufacturing: _dateOfManufacturing != null
              ? Timestamp.fromDate(_dateOfManufacturing!)
              : null,
          dateOfCommissioning: _dateOfCommissioning != null
              ? Timestamp.fromDate(_dateOfCommissioning!)
              : null,
          positionIndex: newPositionIndex, // Assign new position index
        );

        await newEquipmentInstanceRef.set(newEquipmentInstance.toFirestore());

        if (mounted) {
          SnackBarUtils.showSnackBar(
            context,
            '${_selectedTemplate!.equipmentType} added to bay "${widget.bayName}" successfully!',
          );
          Navigator.of(context).pop();
        }
      }
    } catch (e) {
      print('Error saving equipment instance: $e');
      if (mounted) {
        SnackBarUtils.showSnackBar(
          context,
          'Failed to save equipment: $e',
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
      final String uniqueControllerKey = prefix.isEmpty
          ? fieldName
          : '${prefix}_${fieldName}';
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

  Widget _buildFieldInput({
    required CustomField fieldDef,
    required Map<String, dynamic> currentValuesMap,
    required String prefix,
  }) {
    final String fieldName = fieldDef.name;
    final String uniqueControllerKey = prefix.isEmpty
        ? fieldName
        : '${prefix}_${fieldName}';
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
            if (validator != null && validator(value) != null) {
              return validator(value);
            }
            if (value!.isNotEmpty && num.tryParse(value) == null) {
              return 'Enter a valid number for $fieldName';
            }
            return null;
          },
        );
        break;
      case 'boolean':
        final bool currentBooleanValue = _booleanValues.putIfAbsent(
          uniqueControllerKey,
          () =>
              (currentValuesMap[fieldName] is Map &&
                  currentValuesMap[fieldName]['value'] is bool)
              ? currentValuesMap[fieldName]['value']
              : false,
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
                  if (currentValuesMap[fieldName] is! Map) {
                    currentValuesMap[fieldName] = {};
                  }
                  currentValuesMap[fieldName]['value'] = value;
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
                          (currentValuesMap[fieldName] is Map &&
                              currentValuesMap[fieldName]['description_remarks']
                                  is String)
                          ? currentValuesMap[fieldName]['description_remarks']
                          : '',
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
                  onChanged: (value) {
                    if (currentValuesMap[fieldName] is! Map) {
                      currentValuesMap[fieldName] = {};
                    }
                    currentValuesMap[fieldName]['description_remarks'] = value;
                  },
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
        final Map<String, dynamic> itemValues =
            (currentValuesMap[fieldName] is Map<String, dynamic>)
            ? currentValuesMap[fieldName]
            : <String, dynamic>{};
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

  Widget _buildUserAddedFieldInput(int index) {
    final fieldData = _userAddedCustomFields[index];
    final definition = fieldData['definition'] as Map<String, dynamic>;
    final dataType = definition['dataType'] as String;

    if (dataType == 'group') {
      return _buildUserAddedGroupInput(index);
    }

    return Card(
      key: ValueKey(fieldData['uuid']),
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextFormField(
              initialValue: definition['name'],
              decoration: const InputDecoration(labelText: 'Field Name'),
              onChanged: (value) => definition['name'] = value,
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Field name is required'
                  : null,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: dataType,
              decoration: const InputDecoration(labelText: 'Data Type'),
              items: _dataTypes
                  .map(
                    (type) => DropdownMenuItem(value: type, child: Text(type)),
                  )
                  .toList(),
              onChanged: (value) {
                setState(() {
                  definition['dataType'] = value!;
                  fieldData['value'] = null;
                });
              },
            ),
            const SizedBox(height: 12),
            _buildValueInputForUserAddedField(
              dataType: dataType,
              fieldData: fieldData,
              valueKey: 'value',
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

  Widget _buildUserAddedGroupInput(int index) {
    final groupData = _userAddedCustomFields[index];
    final definition = groupData['definition'] as Map<String, dynamic>;
    final nestedFields = definition['nestedFields'] as List;

    return Card(
      key: ValueKey(groupData['uuid']),
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextFormField(
              initialValue: definition['name'],
              decoration: const InputDecoration(labelText: 'Group Name'),
              onChanged: (value) => definition['name'] = value,
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Group name is required'
                  : null,
            ),
            const SizedBox(height: 12),
            const Divider(),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Text(
                'Fields in this Group',
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: nestedFields.length,
              itemBuilder: (context, nestedIndex) {
                final nestedFieldDef =
                    nestedFields[nestedIndex] as Map<String, dynamic>;
                return _buildNestedFieldInput(
                  index,
                  nestedIndex,
                  nestedFieldDef,
                );
              },
            ),
            const SizedBox(height: 10),
            ElevatedButton.icon(
              onPressed: () => _addNestedFieldToUserAddedGroup(index),
              icon: const Icon(Icons.add),
              label: const Text('Add Field to Group'),
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

  Widget _buildNestedFieldInput(
    int groupIndex,
    int nestedIndex,
    Map<String, dynamic> nestedFieldDef,
  ) {
    final groupData = _userAddedCustomFields[groupIndex];

    if (groupData['value'] is! Map<String, dynamic>) {
      groupData['value'] = Map<String, dynamic>.from(groupData['value'] as Map);
    }
    final groupValues = groupData['value'] as Map<String, dynamic>;
    final fieldName = nestedFieldDef['name'] as String? ?? '';
    final fieldUuid = nestedFieldDef['uuid'] as String;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextFormField(
                  initialValue: fieldName,
                  decoration: const InputDecoration(
                    labelText: 'Nested Field Name',
                    isDense: true,
                  ),
                  onChanged: (value) {
                    setState(() {
                      nestedFieldDef['name'] = value;
                    });
                  },
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Name is required'
                      : null,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.remove_circle_outline, size: 22),
                color: Theme.of(context).colorScheme.error,
                padding: const EdgeInsets.all(12),
                constraints: const BoxConstraints(),
                splashRadius: 24,
                onPressed: () =>
                    _removeNestedFieldFromGroup(groupIndex, nestedIndex),
              ),
            ],
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: nestedFieldDef['dataType'] as String? ?? 'text',
            decoration: const InputDecoration(
              labelText: 'Data Type',
              isDense: true,
              border: OutlineInputBorder(),
            ),
            items: _dataTypes
                .where((type) => type != 'group')
                .map((type) => DropdownMenuItem(value: type, child: Text(type)))
                .toList(),
            onChanged: (value) {
              setState(() {
                groupValues.remove(fieldUuid);
                nestedFieldDef['dataType'] = value!;
              });
            },
          ),
          const SizedBox(height: 12),
          _buildValueInputForUserAddedField(
            dataType: nestedFieldDef['dataType'] as String? ?? 'text',
            fieldData: {'definition': nestedFieldDef},
            groupValues: groupValues,
            valueKey: fieldUuid,
          ),
          const Divider(height: 24, thickness: 1),
        ],
      ),
    );
  }

  Widget _buildValueInputForUserAddedField({
    required String dataType,
    required Map<String, dynamic> fieldData,
    required String valueKey,
    Map<String, dynamic>? groupValues,
  }) {
    final definition = fieldData['definition'] as Map<String, dynamic>;
    final valuesMap = groupValues ?? fieldData;

    switch (dataType) {
      case 'text':
      case 'number':
        return TextFormField(
          key: ValueKey(valueKey),
          initialValue: valuesMap[valueKey] as String?,
          decoration: const InputDecoration(
            labelText: 'Value',
            border: OutlineInputBorder(),
          ),
          keyboardType: dataType == 'number'
              ? TextInputType.number
              : TextInputType.text,
          onChanged: (value) => valuesMap[valueKey] = value,
        );
      case 'boolean':
        return SwitchListTile(
          title: const Text('Value'),
          value: valuesMap[valueKey] as bool? ?? false,
          onChanged: (newValue) {
            setState(() {
              valuesMap[valueKey] = newValue;
            });
          },
        );
      case 'date':
        return ListTile(
          title: Text(
            valuesMap[valueKey] == null
                ? 'Select Date'
                : 'Date: ${DateFormat('yyyy-MM-dd').format(valuesMap[valueKey] as DateTime)}',
          ),
          trailing: const Icon(Icons.calendar_today),
          onTap: () async {
            final DateTime? picked = await showDatePicker(
              context: context,
              initialDate: (valuesMap[valueKey] as DateTime?) ?? DateTime.now(),
              firstDate: DateTime(1900),
              lastDate: DateTime.now().add(const Duration(days: 36500)),
            );
            if (picked != null) {
              setState(() {
                valuesMap[valueKey] = picked;
              });
            }
          },
        );
      case 'dropdown':
        return Column(
          children: [
            TextFormField(
              decoration: const InputDecoration(
                labelText: 'Dropdown Options (comma-separated)',
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
              decoration: const InputDecoration(labelText: 'Select Value'),
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
                valuesMap[valueKey] = value;
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
      case 'line':
        return LineIconPainter(
          color: color,
          equipmentSize: equipmentDrawingSize,
          symbolSize: equipmentDrawingSize,
        );
      case 'feeder':
        return FeederIconPainter(
          color: color,
          equipmentSize: equipmentDrawingSize,
          symbolSize: equipmentDrawingSize,
        );
      default:
        return _GenericIconPainter(color: color);
    }
  }

  Widget _buildDatePickerTile({
    required String title,
    required DateTime? selectedDate,
    required void Function(DateTime) onDateSelected,
  }) {
    return ListTile(
      title: Text(
        '$title: ${selectedDate == null ? '' : DateFormat('yyyy-MM-dd').format(selectedDate)}',
      ),
      trailing: const Icon(
        Icons.calendar_today,
        color: Color.fromARGB(255, 11, 35, 179),
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: Colors.grey.shade400),
      ),
      onTap: () async {
        final DateTime? picked = await showDatePicker(
          context: context,
          initialDate: selectedDate ?? DateTime.now(),
          firstDate: DateTime(1950),
          lastDate: DateTime.now().add(const Duration(days: 365 * 20)),
        );
        if (picked != null && picked != selectedDate) {
          onDateSelected(picked);
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Message will not be dynamically set here as the rule is moved to the save button
    String templateSelectionMessage = '';

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.equipmentToEdit == null
              ? 'Add Equipment to Bay: ${widget.bayName}'
              : 'Edit Equipment in Bay: ${widget.bayName}',
        ),
      ),
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
                    if (templateSelectionMessage.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Text(
                          templateSelectionMessage,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.primary,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    const SizedBox(height: 16),
                    if (_equipmentTemplates.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Center(
                          child: Text(
                            'No equipment templates available. Please define them in Admin Dashboard > Master Equipment.',
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
                            // No longer disable items here based on transformer rule,
                            // Validation happens on save.
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
                        onChanged: widget.equipmentToEdit != null
                            ? null // Cannot change template when editing existing equipment
                            : (newValue) {
                                _onTemplateSelected(newValue);
                              },
                        validator: (value) => value == null
                            ? 'Please select an equipment type'
                            : null,
                      ),
                    const SizedBox(height: 24),
                    if (_selectedTemplate != null) ...[
                      Text(
                        'Equipment Properties',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 16.0),
                      Card(
                        elevation: 1,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: Colors.grey.shade300),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              TextFormField(
                                controller: _makeController,
                                decoration: const InputDecoration(
                                  labelText: 'Make *',
                                  border: OutlineInputBorder(),
                                ),
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'Make is required';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16.0),
                              _buildDatePickerTile(
                                title: 'Date of Manufacturing',
                                selectedDate: _dateOfManufacturing,
                                onDateSelected: (date) {
                                  setState(() {
                                    _dateOfManufacturing = date;
                                  });
                                },
                              ),
                              const SizedBox(height: 12.0),
                              _buildDatePickerTile(
                                title: 'Date of Commissioning',
                                selectedDate: _dateOfCommissioning,
                                onDateSelected: (date) {
                                  setState(() {
                                    _dateOfCommissioning = date;
                                  });
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Custom Properties (from Template)',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
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
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _addUserGroupField,
                              icon: const Icon(Icons.add_box_outlined),
                              label: const Text('Add Group'),
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
                                label: Text(
                                  widget.equipmentToEdit == null
                                      ? 'Save Equipment to Bay'
                                      : 'Update Equipment',
                                ),
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

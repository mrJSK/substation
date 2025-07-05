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
  final List<Map<String, dynamic>> _userAddedCustomFieldDefinitions = [];

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
    _userAddedCustomFieldDefinitions.clear();
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
        // MODIFIED: Treat group as a single map, not a list.
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

  // NOTE: User-added fields functionality remains unchanged as the request was about template fields.
  void _addUserCustomFieldDefinition() {
    setState(() {
      final Map<String, dynamic> newFieldDef = {
        'name': '',
        'dataType': CustomFieldDataType.text.toString().split('.').last,
        'isMandatory': false,
        'hasUnits': false,
        'units': '',
        'options': [],
        'hasRemarksField': false,
        'templateRemarkText': '',
        'nestedFields': null,
        'uuid': _uuid.v4(),
      };
      _userAddedCustomFieldDefinitions.add(newFieldDef);
      _initializeCustomFieldValues(
        [CustomField.fromMap(newFieldDef)],
        newFieldDef,
        'user_added_field_${newFieldDef['uuid']}',
      );
    });
  }

  void _addUserGroupFieldDefinition() {
    setState(() {
      final String newUuid = _uuid.v4();
      final Map<String, dynamic> newFieldDef = {
        'name': '',
        'dataType': CustomFieldDataType.group.toString().split('.').last,
        'isMandatory': false,
        'nestedFields': [],
        'hasUnits': false,
        'units': '',
        'options': [],
        'hasRemarksField': false,
        'templateRemarkText': '',
        'uuid': newUuid,
      };
      _userAddedCustomFieldDefinitions.add(newFieldDef);
      _initializeCustomFieldValues(
        [CustomField.fromMap(newFieldDef)],
        newFieldDef,
        'user_added_group_$newUuid',
      );
    });
  }

  void _removeUserCustomFieldDefinition(int index) {
    setState(() {
      final Map<String, dynamic> removedFieldDef =
          _userAddedCustomFieldDefinitions[index];
      final String uniquePrefix =
          (removedFieldDef['dataType'] ==
              CustomFieldDataType.group.toString().split('.').last)
          ? 'user_added_group_${removedFieldDef['uuid']}'
          : 'user_added_field_${removedFieldDef['uuid']}';
      _cleanupControllers(
        [CustomField.fromMap(removedFieldDef)],
        removedFieldDef,
        uniquePrefix,
      );
      _userAddedCustomFieldDefinitions.removeAt(index);
    });
  }

  void _addNestedFieldDefinitionToUserDefinedGroup(
    Map<String, dynamic> groupFieldMap,
  ) {
    setState(() {
      final List<dynamic> nestedFieldsList =
          groupFieldMap['nestedFields'] as List<dynamic>;
      final String newItemUuid = _uuid.v4();
      final Map<String, dynamic> newNestedFieldDef = {
        'name': '',
        'dataType': CustomFieldDataType.text.toString().split('.').last,
        'isMandatory': false,
        'hasUnits': false,
        'units': '',
        'options': [],
        'hasRemarksField': false,
        'templateRemarkText': '',
        'nestedFields': null,
        'uuid': newItemUuid,
      };
      nestedFieldsList.add(newNestedFieldDef);
      final String parentGroupPrefix =
          'user_added_group_${groupFieldMap['uuid']}';
      final String newNestedPrefix = '${parentGroupPrefix}_item_$newItemUuid';
      _initializeCustomFieldValues(
        [CustomField.fromMap(newNestedFieldDef)],
        newNestedFieldDef,
        newNestedPrefix,
      );
    });
  }

  void _removeNestedFieldDefinitionFromUserDefinedGroup(
    List<Map<String, dynamic>> parentNestedList,
    int nestedIndex,
    Map<String, dynamic> parentGroupFieldMap,
  ) {
    setState(() {
      final Map<String, dynamic> removedNestedFieldDef =
          parentNestedList[nestedIndex];
      final String parentGroupPrefix =
          'user_added_group_${parentGroupFieldMap['uuid']}';
      final String removedNestedPrefix =
          '${parentGroupPrefix}_item_${removedNestedFieldDef['uuid']}';
      _cleanupControllers(
        [CustomField.fromMap(removedNestedFieldDef)],
        removedNestedFieldDef,
        removedNestedPrefix,
      );
      parentNestedList.removeAt(nestedIndex);
    });
  }

  void _cleanupControllers(
    List<CustomField> fields,
    Map<String, dynamic> valuesMap,
    String prefix,
  ) {
    for (var field in fields) {
      final String itemIdentifier = valuesMap['uuid'] as String? ?? field.name;
      final String uniqueControllerKey = prefix.isEmpty
          ? itemIdentifier
          : '${prefix}_$itemIdentifier';
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
        // MODIFIED: Logic for user-added groups remains, handles list.
        // The check below handles both the new single-map format and the old list format if needed.
        if (valuesMap[field.name] is List) {
          List<dynamic> nestedList =
              (valuesMap[field.name] as List<dynamic>?) ?? [];
          for (int i = 0; i < nestedList.length; i++) {
            final Map<String, dynamic> nestedItemMap = nestedList[i];
            final String nestedItemUuid =
                nestedItemMap['uuid'] as String? ?? '';
            _cleanupControllers(
              field.nestedFields ?? [],
              nestedItemMap,
              '${uniqueControllerKey}_item_$nestedItemUuid',
            );
          }
        } else if (valuesMap[field.name] is Map) {
          // Handles template fields
          Map<String, dynamic> nestedItemMap =
              (valuesMap[field.name] as Map<String, dynamic>?) ?? {};
          _cleanupControllers(
            field.nestedFields ?? [],
            nestedItemMap,
            '${uniqueControllerKey}_item_single',
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
      if (mounted)
        SnackBarUtils.showSnackBar(
          context,
          'User not authenticated.',
          isError: true,
        );
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
            'template',
          );

      Map<String, dynamic> userAddedCustomFieldValuesCollected = {};
      for (int i = 0; i < _userAddedCustomFieldDefinitions.length; i++) {
        final Map<String, dynamic> fieldDefMap =
            _userAddedCustomFieldDefinitions[i];
        final CustomField userAddedFieldDef = CustomField.fromMap(fieldDefMap);
        final String uniquePrefix =
            (userAddedFieldDef.dataType == CustomFieldDataType.group)
            ? 'user_added_group_${fieldDefMap['uuid']}'
            : 'user_added_field_${fieldDefMap['uuid']}';

        Map<String, dynamic> collectedValueForThisField =
            _collectCustomFieldValues(
              [userAddedFieldDef],
              fieldDefMap,
              uniquePrefix,
            );

        if (collectedValueForThisField.containsKey(userAddedFieldDef.name)) {
          userAddedCustomFieldValuesCollected[userAddedFieldDef.name] =
              collectedValueForThisField[userAddedFieldDef.name];
        }
      }

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
        // MODIFIED: Collect a single map for a group, not a list of maps.
        // The check handles both data structures to support user-added groups vs. template groups.
        if (currentValuesMap[fieldName] is List) {
          // For user-added groups
          List<dynamic> groupItems =
              (currentValuesMap[fieldName] as List<dynamic>?) ?? [];
          List<Map<String, dynamic>> collectedGroupItems = [];
          for (int i = 0; i < groupItems.length; i++) {
            final Map<String, dynamic> groupItemMap =
                groupItems[i] as Map<String, dynamic>;
            collectedGroupItems.add(
              _collectCustomFieldValues(
                fieldDef.nestedFields ?? [],
                groupItemMap,
                '${uniqueControllerKey}_item_${groupItemMap['uuid']}',
              ),
            );
          }
          collectedValues[fieldName] = collectedGroupItems;
        } else {
          // For template-defined groups (now a single instance)
          Map<String, dynamic> groupItemMap =
              (currentValuesMap[fieldName] as Map<String, dynamic>?) ?? {};
          Map<String, dynamic> collectedGroupItem = _collectCustomFieldValues(
            fieldDef.nestedFields ?? [],
            groupItemMap,
            '${uniqueControllerKey}_item_single',
          );
          collectedValues[fieldName] = collectedGroupItem;
        }
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
        // MODIFIED: Renders a single, static group of fields.
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
                  fieldName, // Title without "(Group)"
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
                  // Render nested fields directly without a ListView or add/remove buttons.
                  ...fieldDef.nestedFields!.map((nestedField) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: _buildFieldInput(
                        fieldDef: nestedField,
                        currentValuesMap: itemValues, // Pass the single map
                        prefix: itemPrefix, // Pass the consistent prefix
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

  // The rest of the file remains largely the same, but is included for completeness.

  Widget _buildUserAddedFieldDefinitionInput(
    Map<String, dynamic> fieldDefMap,
    int index,
    List<Map<String, dynamic>> parentList, {
    bool isNestedDefinition = false,
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

    final bool isGroupFieldDefinition =
        dataType == CustomFieldDataType.group.toString().split('.').last;
    final String fieldUuid = fieldDefMap['uuid'] ?? _uuid.v4();
    fieldDefMap['uuid'] = fieldUuid;

    return Card(
      key: ValueKey('user_def_field_${fieldUuid}'),
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
            if (!isGroupFieldDefinition)
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
                    fieldDefMap['dataType'] = value!;
                    fieldDefMap['options'] = [];
                    fieldDefMap['hasUnits'] = false;
                    fieldDefMap['units'] = '';
                    fieldDefMap['hasRemarksField'] = false;
                    fieldDefMap['templateRemarkText'] = '';
                    fieldDefMap['nestedFields'] = null;
                  });
                },
              ),
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
            if (!isGroupFieldDefinition) ...[
              if (dataType == 'dropdown')
                TextFormField(
                  initialValue: options.join(','),
                  decoration: const InputDecoration(
                    labelText: 'Options (comma-separated)',
                    hintText: 'e.g., Option1, Option2',
                    border: OutlineInputBorder(),
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
            ],
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
                    nestedIndex,
                    (fieldDefMap['nestedFields'] as List<dynamic>)
                        .cast<Map<String, dynamic>>(),
                    isNestedDefinition: true,
                  );
                },
              ),
              ElevatedButton.icon(
                onPressed: () =>
                    _addNestedFieldDefinitionToUserDefinedGroup(fieldDefMap),
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
                        'Define Additional Custom Properties (for this instance)',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _userAddedCustomFieldDefinitions.length,
                        itemBuilder: (context, index) {
                          final fieldDefMap =
                              _userAddedCustomFieldDefinitions[index];
                          return _buildUserAddedFieldDefinitionInput(
                            fieldDefMap,
                            index,
                            _userAddedCustomFieldDefinitions,
                          );
                        },
                      ),
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
                              icon: const Icon(Icons.group_add),
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

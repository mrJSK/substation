import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../models/equipment_model.dart';
import '../../utils/snackbar_utils.dart';
import '../../../equipment_icons/transformer_icon.dart';
import '../../../equipment_icons/busbar_icon.dart';
import '../../../equipment_icons/circuit_breaker_icon.dart';
import '../../../equipment_icons/ct_icon.dart';
import '../../../equipment_icons/ground_icon.dart';
import '../../../equipment_icons/isolator_icon.dart';
import '../../../equipment_icons/pt_icon.dart';
import '../../../equipment_icons/line_icon.dart';
import '../../../equipment_icons/feeder_icon.dart';

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

class _EquipmentAssignmentScreenState extends State<EquipmentAssignmentScreen>
    with TickerProviderStateMixin {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
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

  Size _getSymbolPreviewSize(String? symbolKey) {
    switch (symbolKey) {
      case 'transformer':
        return const Size(24, 24);
      case 'busbar':
        return const Size(32, 16);
      case 'circuit_breaker':
        return const Size(24, 24);
      case 'ct':
        return const Size(24, 24);
      case 'ground':
        return const Size(24, 16);
      case 'isolator':
        return const Size(24, 24);
      case 'pt':
        return const Size(24, 24);
      case 'line':
        return const Size(32, 8);
      case 'feeder':
        return const Size(24, 24);
      default:
        return const Size(24, 24); // Fallback for generic icon
    }
  }

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _fetchEquipmentTemplatesAndInitialize();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _makeController.dispose();
    _textControllers.forEach((key, controller) => controller.dispose());
    super.dispose();
  }

  Future<void> _fetchEquipmentTemplatesAndInitialize() async {
    setState(() {
      _isLoading = true;
    });
    try {
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
      _animationController.forward();
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

  CustomPainter _getSymbolPreviewPainter(String? symbolKey, Color color) {
    final symbolSize = _getSymbolPreviewSize(symbolKey);
    switch (symbolKey) {
      case 'transformer':
        return TransformerIconPainter(
          color: color,
          equipmentSize: symbolSize,
          symbolSize: symbolSize,
        );
      case 'busbar':
        return BusbarIconPainter(
          color: color,
          equipmentSize: symbolSize,
          symbolSize: symbolSize,
        );
      case 'circuit_breaker':
        return CircuitBreakerIconPainter(
          color: color,
          equipmentSize: symbolSize,
          symbolSize: symbolSize,
        );
      case 'ct':
        return CurrentTransformerIconPainter(
          color: color,
          equipmentSize: symbolSize,
          symbolSize: symbolSize,
        );
      case 'ground':
        return GroundIconPainter(
          color: color,
          equipmentSize: symbolSize,
          symbolSize: symbolSize,
        );
      case 'isolator':
        return IsolatorIconPainter(
          color: color,
          equipmentSize: symbolSize,
          symbolSize: symbolSize,
        );
      case 'pt':
        return PotentialTransformerIconPainter(
          color: color,
          equipmentSize: symbolSize,
          symbolSize: symbolSize,
        );
      case 'line':
        return LineIconPainter(
          color: color,
          equipmentSize: symbolSize,
          symbolSize: symbolSize,
        );
      case 'feeder':
        return FeederIconPainter(
          color: color,
          equipmentSize: symbolSize,
          symbolSize: symbolSize,
        );
      default:
        return _GenericIconPainter(color: color);
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
        final updatedEquipment = widget.equipmentToEdit!.copyWith(
          make: _makeController.text.trim(),
          dateOfManufacturing: _dateOfManufacturing != null
              ? Timestamp.fromDate(_dateOfManufacturing!)
              : null,
          dateOfCommissioning: _dateOfCommissioning != null
              ? Timestamp.fromDate(_dateOfCommissioning!)
              : null,
          customFieldValues: allCustomFieldValues,
          positionIndex: widget.equipmentToEdit!.positionIndex,
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
        final newEquipmentInstanceRef = FirebaseFirestore.instance
            .collection('equipmentInstances')
            .doc();

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
          positionIndex: newPositionIndex,
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
    bool isNested = false,
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
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

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
            labelStyle: TextStyle(
              color: isDarkMode ? Colors.white70 : Colors.grey[700],
              fontSize: 14,
            ),
            prefixIcon: Icon(
              Icons.text_fields,
              color: theme.colorScheme.primary,
              size: 18,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: BorderSide(
                color: isDarkMode ? Colors.grey[700]! : Colors.grey[300]!,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: BorderSide(
                color: isDarkMode ? Colors.grey[700]! : Colors.grey[300]!,
              ),
            ),
            filled: true,
            fillColor: isDarkMode ? Colors.grey[800] : Colors.grey[100],
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 12,
            ),
            isDense: true,
          ),
          style: TextStyle(
            fontSize: 14,
            color: isDarkMode ? Colors.white : Colors.grey[900],
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
            labelStyle: TextStyle(
              color: isDarkMode ? Colors.white70 : Colors.grey[700],
              fontSize: 14,
            ),
            prefixIcon: Icon(
              Icons.numbers,
              color: theme.colorScheme.secondary,
              size: 18,
            ),
            suffixText: unit,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: BorderSide(
                color: isDarkMode ? Colors.grey[700]! : Colors.grey[300]!,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: BorderSide(
                color: isDarkMode ? Colors.grey[700]! : Colors.grey[300]!,
              ),
            ),
            filled: true,
            fillColor: isDarkMode ? Colors.grey[800] : Colors.grey[100],
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 12,
            ),
            isDense: true,
          ),
          style: TextStyle(
            fontSize: 14,
            color: isDarkMode ? Colors.white : Colors.grey[900],
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
              title: Text(
                fieldName + (isMandatory ? ' *' : ''),
                style: TextStyle(
                  fontSize: 14,
                  color: isDarkMode ? Colors.white : Colors.grey[900],
                ),
              ),
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
              activeColor: theme.colorScheme.primary,
              dense: true,
              visualDensity: VisualDensity.compact,
            ),
            if (hasRemarksField && currentBooleanValue)
              Padding(
                padding: const EdgeInsets.only(
                  left: 16.0,
                  right: 16.0,
                  top: 8.0,
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
                  decoration: InputDecoration(
                    labelText: 'Remarks (Optional)',
                    labelStyle: TextStyle(
                      color: isDarkMode ? Colors.white70 : Colors.grey[700],
                      fontSize: 14,
                    ),
                    prefixIcon: Icon(
                      Icons.note,
                      color: theme.colorScheme.primary,
                      size: 18,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: BorderSide(
                        color: isDarkMode
                            ? Colors.grey[700]!
                            : Colors.grey[300]!,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: BorderSide(
                        color: isDarkMode
                            ? Colors.grey[700]!
                            : Colors.grey[300]!,
                      ),
                    ),
                    filled: true,
                    fillColor: isDarkMode ? Colors.grey[800] : Colors.grey[100],
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                    isDense: true,
                  ),
                  style: TextStyle(
                    fontSize: 14,
                    color: isDarkMode ? Colors.white : Colors.grey[900],
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
                    color: theme.colorScheme.error,
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
        fieldWidget = GestureDetector(
          onTap: () async {
            final DateTime? picked = await showDatePicker(
              context: context,
              initialDate: currentDate ?? DateTime.now(),
              firstDate: DateTime(1900),
              lastDate: DateTime.now().add(const Duration(days: 365 * 100)),
              builder: (context, child) {
                return Theme(
                  data: Theme.of(context).copyWith(
                    colorScheme: Theme.of(context).colorScheme.copyWith(
                      primary: theme.colorScheme.primary,
                      onPrimary: theme.colorScheme.onPrimary,
                      surface: theme.colorScheme.surface,
                      onSurface: theme.colorScheme.onSurface,
                    ),
                    textButtonTheme: TextButtonThemeData(
                      style: TextButton.styleFrom(
                        foregroundColor: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                  child: child!,
                );
              },
            );
            if (picked != null) {
              setState(() {
                _dateValues[uniqueControllerKey] = picked;
                currentValuesMap[fieldName] = Timestamp.fromDate(picked);
              });
            }
          },
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDarkMode ? Colors.grey[800] : Colors.grey[100],
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: isDarkMode ? Colors.grey[700]! : Colors.grey[300]!,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.calendar_today,
                  color: theme.colorScheme.tertiary,
                  size: 18,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        fieldName + (isMandatory ? ' *' : ''),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isDarkMode ? Colors.white : Colors.grey[900],
                        ),
                      ),
                      Text(
                        currentDate == null
                            ? 'Select Date'
                            : DateFormat('yyyy-MM-dd').format(currentDate),
                        style: TextStyle(
                          fontSize: 13,
                          color: theme.colorScheme.tertiary,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.edit_calendar,
                  color: theme.colorScheme.primary,
                  size: 18,
                ),
              ],
            ),
          ),
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
            labelStyle: TextStyle(
              color: isDarkMode ? Colors.white70 : Colors.grey[700],
              fontSize: 14,
            ),
            prefixIcon: Icon(
              Icons.arrow_drop_down_circle,
              color: Colors.teal,
              size: 18,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: BorderSide(
                color: isDarkMode ? Colors.grey[700]! : Colors.grey[300]!,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: BorderSide(
                color: isDarkMode ? Colors.grey[700]! : Colors.grey[300]!,
              ),
            ),
            filled: true,
            fillColor: isDarkMode ? Colors.grey[800] : Colors.grey[100],
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 12,
            ),
            isDense: true,
          ),
          dropdownColor: isDarkMode ? Colors.grey[850] : Colors.white,
          items: options.map((option) {
            return DropdownMenuItem(
              value: option,
              child: Text(
                option,
                style: TextStyle(
                  fontSize: 14,
                  color: isDarkMode ? Colors.white : Colors.grey[900],
                ),
              ),
            );
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

        return AnimatedSize(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDarkMode ? Colors.grey[800] : Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isDarkMode ? Colors.grey[700]! : Colors.grey[300]!,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withOpacity(0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.group,
                        color: theme.colorScheme.primary,
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        fieldName,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isDarkMode ? Colors.white : Colors.grey[900],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (fieldDef.nestedFields == null ||
                    fieldDef.nestedFields!.isEmpty)
                  Text(
                    'This group has no nested fields defined.',
                    style: TextStyle(
                      fontSize: 13,
                      color: isDarkMode ? Colors.white70 : Colors.grey[700],
                    ),
                  )
                else
                  ...fieldDef.nestedFields!.map((nestedField) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 12.0),
                      child: _buildFieldInput(
                        fieldDef: nestedField,
                        currentValuesMap: itemValues,
                        prefix: itemPrefix,
                        isNested: true,
                      ),
                    );
                  }).toList(),
              ],
            ),
          ),
        );
      default:
        return Text(
          'Unsupported data type: $dataType for $fieldName',
          style: TextStyle(fontSize: 13, color: theme.colorScheme.error),
        );
    }

    return Padding(
      padding: EdgeInsets.symmetric(vertical: isNested ? 4.0 : 8.0),
      child: fieldWidget,
    );
  }

  Widget _buildUserAddedFieldInput(int index) {
    final fieldData = _userAddedCustomFields[index];
    final definition = fieldData['definition'] as Map<String, dynamic>;
    final dataType = definition['dataType'] as String;
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    if (dataType == 'group') {
      return _buildUserAddedGroupInput(index);
    }

    return AnimatedSize(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      child: Container(
        key: ValueKey(fieldData['uuid']),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDarkMode ? Colors.grey[800] : Colors.grey[100],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isDarkMode ? Colors.grey[700]! : Colors.grey[300]!,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: _getDataTypeColor(dataType, theme).withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _getDataTypeIcon(dataType),
                    color: _getDataTypeColor(dataType, theme),
                    size: 16,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    definition['name'].isNotEmpty
                        ? definition['name']
                        : 'Unnamed Field',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isDarkMode ? Colors.white : Colors.grey[900],
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => _removeUserCustomField(index),
                  icon: Icon(
                    Icons.delete_outline,
                    color: theme.colorScheme.error,
                    size: 18,
                  ),
                  style: IconButton.styleFrom(
                    backgroundColor: theme.colorScheme.error.withOpacity(0.05),
                    minimumSize: const Size(32, 32),
                    padding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              initialValue: definition['name'],
              decoration: InputDecoration(
                labelText: 'Field Name',
                labelStyle: TextStyle(
                  color: isDarkMode ? Colors.white70 : Colors.grey[700],
                  fontSize: 14,
                ),
                prefixIcon: Icon(
                  Icons.edit,
                  color: theme.colorScheme.primary,
                  size: 18,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: BorderSide(
                    color: isDarkMode ? Colors.grey[700]! : Colors.grey[300]!,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: BorderSide(
                    color: isDarkMode ? Colors.grey[700]! : Colors.grey[300]!,
                  ),
                ),
                filled: true,
                fillColor: isDarkMode ? Colors.grey[800] : Colors.grey[100],
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
                isDense: true,
              ),
              style: TextStyle(
                fontSize: 14,
                color: isDarkMode ? Colors.white : Colors.grey[900],
              ),
              onChanged: (value) => definition['name'] = value,
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Field name is required'
                  : null,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: dataType,
              decoration: InputDecoration(
                labelText: 'Data Type',
                labelStyle: TextStyle(
                  color: isDarkMode ? Colors.white70 : Colors.grey[700],
                  fontSize: 14,
                ),
                prefixIcon: Icon(
                  _getDataTypeIcon(dataType),
                  color: _getDataTypeColor(dataType, theme),
                  size: 18,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: BorderSide(
                    color: isDarkMode ? Colors.grey[700]! : Colors.grey[300]!,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: BorderSide(
                    color: isDarkMode ? Colors.grey[700]! : Colors.grey[300]!,
                  ),
                ),
                filled: true,
                fillColor: isDarkMode ? Colors.grey[800] : Colors.grey[100],
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
                isDense: true,
              ),
              dropdownColor: isDarkMode ? Colors.grey[850] : Colors.white,
              items: _dataTypes
                  .map(
                    (type) => DropdownMenuItem(
                      value: type,
                      child: Row(
                        children: [
                          Icon(
                            _getDataTypeIcon(type),
                            color: _getDataTypeColor(type, theme),
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            type,
                            style: TextStyle(
                              fontSize: 14,
                              color: isDarkMode
                                  ? Colors.white
                                  : Colors.grey[900],
                            ),
                          ),
                        ],
                      ),
                    ),
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
          ],
        ),
      ),
    );
  }

  Widget _buildUserAddedGroupInput(int index) {
    final groupData = _userAddedCustomFields[index];
    final definition = groupData['definition'] as Map<String, dynamic>;
    final nestedFields = definition['nestedFields'] as List;
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return AnimatedSize(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      child: Container(
        key: ValueKey(groupData['uuid']),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDarkMode ? Colors.grey[800] : Colors.grey[100],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isDarkMode ? Colors.grey[700]! : Colors.grey[300]!,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.group,
                    color: theme.colorScheme.primary,
                    size: 16,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    definition['name'].isNotEmpty
                        ? definition['name']
                        : 'Unnamed Group',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isDarkMode ? Colors.white : Colors.grey[900],
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${nestedFields.length} field${nestedFields.length == 1 ? '' : 's'}',
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () => _removeUserCustomField(index),
                  icon: Icon(
                    Icons.delete_outline,
                    color: theme.colorScheme.error,
                    size: 18,
                  ),
                  style: IconButton.styleFrom(
                    backgroundColor: theme.colorScheme.error.withOpacity(0.05),
                    minimumSize: const Size(32, 32),
                    padding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              initialValue: definition['name'],
              decoration: InputDecoration(
                labelText: 'Group Name',
                labelStyle: TextStyle(
                  color: isDarkMode ? Colors.white70 : Colors.grey[700],
                  fontSize: 14,
                ),
                prefixIcon: Icon(
                  Icons.group,
                  color: theme.colorScheme.primary,
                  size: 18,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: BorderSide(
                    color: isDarkMode ? Colors.grey[700]! : Colors.grey[300]!,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: BorderSide(
                    color: isDarkMode ? Colors.grey[700]! : Colors.grey[300]!,
                  ),
                ),
                filled: true,
                fillColor: isDarkMode ? Colors.grey[800] : Colors.grey[100],
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
                isDense: true,
              ),
              style: TextStyle(
                fontSize: 14,
                color: isDarkMode ? Colors.white : Colors.grey[900],
              ),
              onChanged: (value) => definition['name'] = value,
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Group name is required'
                  : null,
            ),
            const SizedBox(height: 12),
            if (nestedFields.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Text(
                  'Fields in this Group',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isDarkMode ? Colors.white : Colors.grey[900],
                  ),
                ),
              ),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: nestedFields.length,
              separatorBuilder: (context, index) => const Divider(height: 24),
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
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _addNestedFieldToUserAddedGroup(index),
                icon: Icon(
                  Icons.add_circle_outline,
                  color: theme.colorScheme.primary,
                  size: 18,
                ),
                label: Text(
                  'Add Field to Group',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.primary,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  side: BorderSide(color: theme.colorScheme.primary),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  backgroundColor: theme.colorScheme.primary.withOpacity(0.05),
                ),
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
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    if (groupData['value'] is! Map<String, dynamic>) {
      groupData['value'] = Map<String, dynamic>.from(groupData['value'] as Map);
    }
    final groupValues = groupData['value'] as Map<String, dynamic>;
    final fieldName = nestedFieldDef['name'] as String? ?? '';
    final fieldUuid = nestedFieldDef['uuid'] as String;

    return AnimatedSize(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDarkMode ? Colors.grey[850] : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isDarkMode ? Colors.grey[700]! : Colors.grey[200]!,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: _getDataTypeColor(
                      nestedFieldDef['dataType'],
                      theme,
                    ).withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _getDataTypeIcon(nestedFieldDef['dataType']),
                    color: _getDataTypeColor(nestedFieldDef['dataType'], theme),
                    size: 16,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    fieldName.isNotEmpty ? fieldName : 'Unnamed Field',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isDarkMode ? Colors.white : Colors.grey[900],
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () =>
                      _removeNestedFieldFromGroup(groupIndex, nestedIndex),
                  icon: Icon(
                    Icons.delete_outline,
                    color: theme.colorScheme.error,
                    size: 18,
                  ),
                  style: IconButton.styleFrom(
                    backgroundColor: theme.colorScheme.error.withOpacity(0.05),
                    minimumSize: const Size(32, 32),
                    padding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              initialValue: fieldName,
              decoration: InputDecoration(
                labelText: 'Nested Field Name',
                labelStyle: TextStyle(
                  color: isDarkMode ? Colors.white70 : Colors.grey[700],
                  fontSize: 14,
                ),
                prefixIcon: Icon(
                  Icons.edit,
                  color: theme.colorScheme.primary,
                  size: 18,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: BorderSide(
                    color: isDarkMode ? Colors.grey[700]! : Colors.grey[300]!,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: BorderSide(
                    color: isDarkMode ? Colors.grey[700]! : Colors.grey[300]!,
                  ),
                ),
                filled: true,
                fillColor: isDarkMode ? Colors.grey[800] : Colors.grey[100],
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
                isDense: true,
              ),
              style: TextStyle(
                fontSize: 14,
                color: isDarkMode ? Colors.white : Colors.grey[900],
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
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: nestedFieldDef['dataType'] as String? ?? 'text',
              decoration: InputDecoration(
                labelText: 'Data Type',
                labelStyle: TextStyle(
                  color: isDarkMode ? Colors.white70 : Colors.grey[700],
                  fontSize: 14,
                ),
                prefixIcon: Icon(
                  _getDataTypeIcon(nestedFieldDef['dataType']),
                  color: _getDataTypeColor(nestedFieldDef['dataType'], theme),
                  size: 18,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: BorderSide(
                    color: isDarkMode ? Colors.grey[700]! : Colors.grey[300]!,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: BorderSide(
                    color: isDarkMode ? Colors.grey[700]! : Colors.grey[300]!,
                  ),
                ),
                filled: true,
                fillColor: isDarkMode ? Colors.grey[800] : Colors.grey[100],
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
                isDense: true,
              ),
              dropdownColor: isDarkMode ? Colors.grey[850] : Colors.white,
              items: _dataTypes.where((type) => type != 'group').map((type) {
                return DropdownMenuItem(
                  value: type,
                  child: Row(
                    children: [
                      Icon(
                        _getDataTypeIcon(type),
                        color: _getDataTypeColor(type, theme),
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        type,
                        style: TextStyle(
                          fontSize: 14,
                          color: isDarkMode ? Colors.white : Colors.grey[900],
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
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
          ],
        ),
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
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    switch (dataType) {
      case 'text':
      case 'number':
        return TextFormField(
          key: ValueKey(valueKey),
          initialValue: valuesMap[valueKey] as String?,
          decoration: InputDecoration(
            labelText: 'Value',
            labelStyle: TextStyle(
              color: isDarkMode ? Colors.white70 : Colors.grey[700],
              fontSize: 14,
            ),
            prefixIcon: Icon(
              dataType == 'text' ? Icons.text_fields : Icons.numbers,
              color: dataType == 'text'
                  ? theme.colorScheme.primary
                  : theme.colorScheme.secondary,
              size: 18,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: BorderSide(
                color: isDarkMode ? Colors.grey[700]! : Colors.grey[300]!,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: BorderSide(
                color: isDarkMode ? Colors.grey[700]! : Colors.grey[300]!,
              ),
            ),
            filled: true,
            fillColor: isDarkMode ? Colors.grey[800] : Colors.grey[100],
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 12,
            ),
            isDense: true,
          ),
          style: TextStyle(
            fontSize: 14,
            color: isDarkMode ? Colors.white : Colors.grey[900],
          ),
          keyboardType: dataType == 'number'
              ? TextInputType.number
              : TextInputType.text,
          onChanged: (value) => valuesMap[valueKey] = value,
        );
      case 'boolean':
        return SwitchListTile(
          title: Text(
            'Value',
            style: TextStyle(
              fontSize: 14,
              color: isDarkMode ? Colors.white : Colors.grey[900],
            ),
          ),
          value: valuesMap[valueKey] as bool? ?? false,
          onChanged: (newValue) {
            setState(() {
              valuesMap[valueKey] = newValue;
            });
          },
          activeColor: theme.colorScheme.primary,
          controlAffinity: ListTileControlAffinity.leading,
          contentPadding: EdgeInsets.zero,
          dense: true,
          visualDensity: VisualDensity.compact,
        );
      case 'date':
        return GestureDetector(
          onTap: () async {
            final DateTime? picked = await showDatePicker(
              context: context,
              initialDate: (valuesMap[valueKey] as DateTime?) ?? DateTime.now(),
              firstDate: DateTime(1900),
              lastDate: DateTime.now().add(const Duration(days: 36500)),
              builder: (context, child) {
                return Theme(
                  data: Theme.of(context).copyWith(
                    colorScheme: Theme.of(context).colorScheme.copyWith(
                      primary: theme.colorScheme.primary,
                      onPrimary: theme.colorScheme.onPrimary,
                      surface: theme.colorScheme.surface,
                      onSurface: theme.colorScheme.onSurface,
                    ),
                    textButtonTheme: TextButtonThemeData(
                      style: TextButton.styleFrom(
                        foregroundColor: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                  child: child!,
                );
              },
            );
            if (picked != null) {
              setState(() {
                valuesMap[valueKey] = picked;
              });
            }
          },
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDarkMode ? Colors.grey[800] : Colors.grey[100],
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: isDarkMode ? Colors.grey[700]! : Colors.grey[300]!,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.calendar_today,
                  color: theme.colorScheme.tertiary,
                  size: 18,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Value',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isDarkMode ? Colors.white : Colors.grey[900],
                        ),
                      ),
                      Text(
                        valuesMap[valueKey] == null
                            ? 'Select Date'
                            : DateFormat(
                                'yyyy-MM-dd',
                              ).format(valuesMap[valueKey] as DateTime),
                        style: TextStyle(
                          fontSize: 13,
                          color: theme.colorScheme.tertiary,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.edit_calendar,
                  color: theme.colorScheme.primary,
                  size: 18,
                ),
              ],
            ),
          ),
        );
      case 'dropdown':
        return Column(
          children: [
            TextFormField(
              decoration: InputDecoration(
                labelText: 'Dropdown Options (comma-separated)',
                labelStyle: TextStyle(
                  color: isDarkMode ? Colors.white70 : Colors.grey[700],
                  fontSize: 14,
                ),
                prefixIcon: Icon(
                  Icons.list,
                  color: theme.colorScheme.primary,
                  size: 18,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: BorderSide(
                    color: isDarkMode ? Colors.grey[700]! : Colors.grey[300]!,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: BorderSide(
                    color: isDarkMode ? Colors.grey[700]! : Colors.grey[300]!,
                  ),
                ),
                filled: true,
                fillColor: isDarkMode ? Colors.grey[800] : Colors.grey[100],
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
                isDense: true,
              ),
              style: TextStyle(
                fontSize: 14,
                color: isDarkMode ? Colors.white : Colors.grey[900],
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
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              decoration: InputDecoration(
                labelText: 'Select Value',
                labelStyle: TextStyle(
                  color: isDarkMode ? Colors.white70 : Colors.grey[700],
                  fontSize: 14,
                ),
                prefixIcon: Icon(
                  Icons.arrow_drop_down_circle,
                  color: Colors.teal,
                  size: 18,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: BorderSide(
                    color: isDarkMode ? Colors.grey[700]! : Colors.grey[300]!,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: BorderSide(
                    color: isDarkMode ? Colors.grey[700]! : Colors.grey[300]!,
                  ),
                ),
                filled: true,
                fillColor: isDarkMode ? Colors.grey[800] : Colors.grey[100],
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
                isDense: true,
              ),
              dropdownColor: isDarkMode ? Colors.grey[850] : Colors.white,
              items:
                  (definition['options'] as List<dynamic>?)
                      ?.map(
                        (option) => DropdownMenuItem(
                          value: option.toString(),
                          child: Text(
                            option.toString(),
                            style: TextStyle(
                              fontSize: 14,
                              color: isDarkMode
                                  ? Colors.white
                                  : Colors.grey[900],
                            ),
                          ),
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

  Widget _buildDatePickerTile({
    required String title,
    required DateTime? selectedDate,
    required void Function(DateTime) onDateSelected,
  }) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return GestureDetector(
      onTap: () async {
        final DateTime? picked = await showDatePicker(
          context: context,
          initialDate: selectedDate ?? DateTime.now(),
          firstDate: DateTime(1950),
          lastDate: DateTime.now().add(const Duration(days: 365 * 20)),
          builder: (context, child) {
            return Theme(
              data: Theme.of(context).copyWith(
                colorScheme: Theme.of(context).colorScheme.copyWith(
                  primary: theme.colorScheme.primary,
                  onPrimary: theme.colorScheme.onPrimary,
                  surface: theme.colorScheme.surface,
                  onSurface: theme.colorScheme.onSurface,
                ),
                textButtonTheme: TextButtonThemeData(
                  style: TextButton.styleFrom(
                    foregroundColor: theme.colorScheme.primary,
                  ),
                ),
              ),
              child: child!,
            );
          },
        );
        if (picked != null && picked != selectedDate) {
          onDateSelected(picked);
        }
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDarkMode ? Colors.grey[800] : Colors.grey[100],
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isDarkMode ? Colors.grey[700]! : Colors.grey[300]!,
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.calendar_today,
              color: theme.colorScheme.tertiary,
              size: 18,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isDarkMode ? Colors.white : Colors.grey[900],
                    ),
                  ),
                  Text(
                    selectedDate == null
                        ? 'Select Date'
                        : DateFormat('yyyy-MM-dd').format(selectedDate),
                    style: TextStyle(
                      fontSize: 13,
                      color: theme.colorScheme.tertiary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.edit_calendar,
              color: theme.colorScheme.primary,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }

  Color _getDataTypeColor(String dataType, ThemeData theme) {
    switch (dataType) {
      case 'text':
        return theme.colorScheme.primary;
      case 'number':
        return theme.colorScheme.secondary;
      case 'boolean':
        return Colors.orange;
      case 'date':
        return theme.colorScheme.tertiary;
      case 'dropdown':
        return Colors.teal;
      case 'group':
        return theme.colorScheme.primary;
      default:
        return Colors.grey;
    }
  }

  IconData _getDataTypeIcon(String dataType) {
    switch (dataType) {
      case 'text':
        return Icons.text_fields;
      case 'number':
        return Icons.numbers;
      case 'boolean':
        return Icons.toggle_on;
      case 'date':
        return Icons.calendar_today;
      case 'dropdown':
        return Icons.arrow_drop_down_circle;
      case 'group':
        return Icons.group;
      default:
        return Icons.help;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    if (_isLoading) {
      return Scaffold(
        backgroundColor: isDarkMode ? Colors.grey[900] : Colors.grey[50],
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation<Color>(
                  theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Loading equipment data...',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: isDarkMode ? Colors.white70 : Colors.grey[700],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: isDarkMode ? Colors.grey[900] : Colors.grey[50],
      appBar: AppBar(
        backgroundColor: isDarkMode ? Colors.grey[900] : Colors.grey[50],
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: theme.colorScheme.primary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.equipmentToEdit == null
                  ? 'Add Equipment'
                  : 'Edit Equipment',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: isDarkMode ? Colors.white : Colors.grey[900],
              ),
            ),
            Text(
              widget.bayName,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: theme.colorScheme.primary,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(
            height: 1,
            color: isDarkMode ? Colors.grey[700] : Colors.grey[200],
          ),
        ),
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isDarkMode ? Colors.grey[850] : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isDarkMode
                              ? Colors.grey[700]!
                              : Colors.grey[200]!,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary.withOpacity(0.2),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.info,
                              color: theme.colorScheme.primary,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Bay Information',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                    color: isDarkMode
                                        ? Colors.white
                                        : Colors.grey[900],
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Bay: ${widget.bayName}',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: isDarkMode
                                        ? Colors.white70
                                        : Colors.grey[700],
                                  ),
                                ),
                                Text(
                                  'Substation ID: ${widget.substationId}',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: isDarkMode
                                        ? Colors.white70
                                        : Colors.grey[700],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isDarkMode ? Colors.grey[850] : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isDarkMode
                              ? Colors.grey[700]!
                              : Colors.grey[200]!,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.primary.withOpacity(
                                    0.15,
                                  ),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.electrical_services,
                                  color: theme.colorScheme.primary,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'Equipment Type',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: isDarkMode
                                      ? Colors.white
                                      : Colors.grey[900],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          if (_equipmentTemplates.isEmpty)
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.error.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.warning_amber,
                                    color: theme.colorScheme.error,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      'No equipment templates available. Create templates in Admin Dashboard.',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                        color: theme.colorScheme.error,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          else
                            DropdownButtonFormField<MasterEquipmentTemplate>(
                              value: _selectedTemplate,
                              decoration: InputDecoration(
                                labelText: 'Equipment Template',
                                labelStyle: TextStyle(
                                  color: isDarkMode
                                      ? Colors.white70
                                      : Colors.grey[700],
                                  fontSize: 14,
                                ),
                                prefixIcon: Icon(
                                  Icons.electrical_services,
                                  color: theme.colorScheme.primary,
                                  size: 20,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(
                                    color: isDarkMode
                                        ? Colors.grey[700]!
                                        : Colors.grey[300]!,
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(
                                    color: isDarkMode
                                        ? Colors.grey[700]!
                                        : Colors.grey[300]!,
                                  ),
                                ),
                                filled: true,
                                fillColor: isDarkMode
                                    ? Colors.grey[800]
                                    : Colors.grey[100],
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 12,
                                ),
                                isDense: true,
                              ),
                              dropdownColor: isDarkMode
                                  ? Colors.grey[850]
                                  : Colors.white,
                              isExpanded: true,
                              items: _equipmentTemplates.map((template) {
                                return DropdownMenuItem<
                                  MasterEquipmentTemplate
                                >(
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
                                        // child: CustomPaint(
                                        //   painter: _getSymbolPreviewPainter(
                                        //     template.symbolKey,
                                        //     isDarkMode
                                        //         ? Colors.white70
                                        //         : Colors.grey[700],
                                        //   ),
                                        // ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              template.equipmentType,
                                              style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600,
                                                color: isDarkMode
                                                    ? Colors.white
                                                    : Colors.grey[900],
                                              ),
                                            ),
                                            Text(
                                              template.id?.substring(0, 8) ??
                                                  'No ID',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: isDarkMode
                                                    ? Colors.white70
                                                    : Colors.grey[600],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                              onChanged: widget.equipmentToEdit != null
                                  ? null
                                  : (newValue) {
                                      _onTemplateSelected(newValue);
                                    },
                              validator: (value) => value == null
                                  ? 'Please select an equipment type'
                                  : null,
                            ),
                        ],
                      ),
                    ),
                  ),
                  if (_selectedTemplate != null) ...[
                    const SizedBox(height: 16),
                    FadeTransition(
                      opacity: _fadeAnimation,
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isDarkMode ? Colors.grey[850] : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isDarkMode
                                ? Colors.grey[700]!
                                : Colors.grey[200]!,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.primary
                                        .withOpacity(0.15),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.settings,
                                    color: theme.colorScheme.primary,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  'Equipment Properties',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                    color: isDarkMode
                                        ? Colors.white
                                        : Colors.grey[900],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _makeController,
                              decoration: InputDecoration(
                                labelText: 'Make *',
                                labelStyle: TextStyle(
                                  color: isDarkMode
                                      ? Colors.white70
                                      : Colors.grey[700],
                                  fontSize: 14,
                                ),
                                prefixIcon: Icon(
                                  Icons.build,
                                  color: theme.colorScheme.primary,
                                  size: 18,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(6),
                                  borderSide: BorderSide(
                                    color: isDarkMode
                                        ? Colors.grey[700]!
                                        : Colors.grey[300]!,
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(6),
                                  borderSide: BorderSide(
                                    color: isDarkMode
                                        ? Colors.grey[700]!
                                        : Colors.grey[300]!,
                                  ),
                                ),
                                filled: true,
                                fillColor: isDarkMode
                                    ? Colors.grey[800]
                                    : Colors.grey[100],
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 12,
                                ),
                                isDense: true,
                              ),
                              style: TextStyle(
                                fontSize: 14,
                                color: isDarkMode
                                    ? Colors.white
                                    : Colors.grey[900],
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Make is required';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 12),
                            _buildDatePickerTile(
                              title: 'Date of Manufacturing',
                              selectedDate: _dateOfManufacturing,
                              onDateSelected: (date) {
                                setState(() {
                                  _dateOfManufacturing = date;
                                });
                              },
                            ),
                            const SizedBox(height: 12),
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
                    const SizedBox(height: 16),
                    FadeTransition(
                      opacity: _fadeAnimation,
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isDarkMode ? Colors.grey[850] : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isDarkMode
                                ? Colors.grey[700]!
                                : Colors.grey[200]!,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.primary
                                        .withOpacity(0.15),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.tune,
                                    color: theme.colorScheme.primary,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  'Custom Properties (from Template)',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                    color: isDarkMode
                                        ? Colors.white
                                        : Colors.grey[900],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.primary
                                        .withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    '${_selectedTemplate!.equipmentCustomFields.length} field${_selectedTemplate!.equipmentCustomFields.length == 1 ? '' : 's'}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: theme.colorScheme.primary,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            if (_selectedTemplate!
                                .equipmentCustomFields
                                .isEmpty)
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.primary.withOpacity(
                                    0.1,
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.info_outline,
                                      color: theme.colorScheme.primary,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        'This template has no custom fields defined.',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: isDarkMode
                                              ? Colors.white70
                                              : Colors.grey[700],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            else
                              ..._selectedTemplate!.equipmentCustomFields.map((
                                field,
                              ) {
                                return Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 8.0,
                                  ),
                                  child: _buildFieldInput(
                                    fieldDef: field,
                                    currentValuesMap:
                                        _templateCustomFieldValues,
                                    prefix: 'template_field',
                                  ),
                                );
                              }).toList(),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    FadeTransition(
                      opacity: _fadeAnimation,
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isDarkMode ? Colors.grey[850] : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isDarkMode
                                ? Colors.grey[700]!
                                : Colors.grey[200]!,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.primary
                                        .withOpacity(0.15),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.add_circle_outline,
                                    color: theme.colorScheme.primary,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  'Additional Custom Properties',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                    color: isDarkMode
                                        ? Colors.white
                                        : Colors.grey[900],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.primary
                                        .withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    '${_userAddedCustomFields.length} field${_userAddedCustomFields.length == 1 ? '' : 's'}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: theme.colorScheme.primary,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            AnimatedSize(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeInOut,
                              child: _userAddedCustomFields.isEmpty
                                  ? Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: theme.colorScheme.primary
                                            .withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.info_outline,
                                            color: theme.colorScheme.primary,
                                            size: 20,
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Text(
                                              'No additional fields added yet.',
                                              style: TextStyle(
                                                fontSize: 14,
                                                color: isDarkMode
                                                    ? Colors.white70
                                                    : Colors.grey[700],
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    )
                                  : ListView.separated(
                                      shrinkWrap: true,
                                      physics:
                                          const NeverScrollableScrollPhysics(),
                                      itemCount: _userAddedCustomFields.length,
                                      separatorBuilder: (context, index) =>
                                          const SizedBox(height: 12),
                                      itemBuilder: (context, index) {
                                        return _buildUserAddedFieldInput(index);
                                      },
                                    ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: _addUserCustomField,
                                    icon: Icon(
                                      Icons.add,
                                      color: theme.colorScheme.primary,
                                      size: 18,
                                    ),
                                    label: Text(
                                      'Add Field',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: theme.colorScheme.primary,
                                      ),
                                    ),
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 12,
                                      ),
                                      side: BorderSide(
                                        color: theme.colorScheme.primary,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      backgroundColor: theme.colorScheme.primary
                                          .withOpacity(0.05),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: _addUserGroupField,
                                    icon: Icon(
                                      Icons.add_box_outlined,
                                      color: theme.colorScheme.primary,
                                      size: 18,
                                    ),
                                    label: Text(
                                      'Add Group',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: theme.colorScheme.primary,
                                      ),
                                    ),
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 12,
                                      ),
                                      side: BorderSide(
                                        color: theme.colorScheme.primary,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      backgroundColor: theme.colorScheme.primary
                                          .withOpacity(0.05),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDarkMode ? Colors.grey[850] : Colors.white,
          border: Border(
            top: BorderSide(
              color: isDarkMode ? Colors.grey[700]! : Colors.grey[200]!,
            ),
          ),
        ),
        child: _isSavingEquipment
            ? Center(
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    theme.colorScheme.primary,
                  ),
                ),
              )
            : ElevatedButton.icon(
                onPressed: _selectedTemplate != null
                    ? _saveEquipmentInstance
                    : null,
                icon: Icon(
                  Icons.save,
                  size: 20,
                  color: theme.colorScheme.onPrimary,
                ),
                label: Text(
                  widget.equipmentToEdit == null
                      ? 'Save Equipment to Bay'
                      : 'Update Equipment',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onPrimary,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: theme.colorScheme.onPrimary,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  elevation: 0,
                ),
              ),
      ),
    );
  }
}

// lib/widgets/reading_field_widgets.dart

import 'package:flutter/material.dart';
import '../models/reading_models.dart';

class ReadingFieldCard extends StatefulWidget {
  final Map<String, dynamic> fieldDef;
  final int index;
  final bool isDefault;
  final bool isEditable;
  final VoidCallback? onRemove;
  final Function(String, dynamic)? onFieldChanged;
  final List<String> dataTypes;
  final List<String> frequencies;

  const ReadingFieldCard({
    Key? key,
    required this.fieldDef,
    required this.index,
    this.isDefault = false,
    this.isEditable = true,
    this.onRemove,
    this.onFieldChanged,
    required this.dataTypes,
    required this.frequencies,
  }) : super(key: key);

  @override
  State<ReadingFieldCard> createState() => _ReadingFieldCardState();
}

class _ReadingFieldCardState extends State<ReadingFieldCard> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final String dataType = widget.fieldDef['dataType'] as String;
    final bool isGroupField = dataType == 'group';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: widget.isDefault
            ? theme.colorScheme.primary.withOpacity(0.05)
            : (isDarkMode ? const Color(0xFF3C3C3E) : Colors.grey.shade50),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: widget.isDefault
              ? theme.colorScheme.primary.withOpacity(0.3)
              : (isDarkMode
                    ? Colors.white.withOpacity(0.1)
                    : Colors.grey.shade200),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildFieldHeader(theme, isDarkMode, dataType),
          const SizedBox(height: 12),
          FieldInputsWidget(
            fieldDef: widget.fieldDef,
            isDefault: widget.isDefault,
            isEditable: widget.isEditable,
            onFieldChanged: widget.onFieldChanged,
            dataTypes: widget.dataTypes,
            frequencies: widget.frequencies,
          ),
          if (isGroupField) ...[
            const SizedBox(height: 16),
            NestedFieldsWidget(
              fieldDef: widget.fieldDef,
              isEditable: widget.isEditable,
              onFieldChanged: widget.onFieldChanged,
              dataTypes: widget.dataTypes,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFieldHeader(ThemeData theme, bool isDarkMode, String dataType) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: _getDataTypeColor(dataType).withOpacity(0.15),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(
            _getDataTypeIcon(dataType),
            size: 16,
            color: _getDataTypeColor(dataType),
          ),
        ),
        const SizedBox(width: 8),
        if (widget.isDefault)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              'DEFAULT',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.primary,
              ),
            ),
          ),
        if (widget.fieldDef['isInteger'] == true)
          Container(
            margin: const EdgeInsets.only(left: 4),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              'INT',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: Colors.orange,
              ),
            ),
          ),
        const Spacer(),
        if (!widget.isDefault && widget.onRemove != null && widget.isEditable)
          IconButton(
            onPressed: widget.onRemove,
            icon: Icon(
              Icons.delete_outline,
              color: theme.colorScheme.error,
              size: 18,
            ),
            style: IconButton.styleFrom(
              backgroundColor: theme.colorScheme.error.withOpacity(0.1),
              minimumSize: const Size(32, 32),
              padding: EdgeInsets.zero,
            ),
          ),
      ],
    );
  }

  Color _getDataTypeColor(String dataType) {
    switch (dataType) {
      case 'text':
        return Colors.blue;
      case 'number':
        return Colors.green;
      case 'boolean':
        return Colors.orange;
      case 'date':
        return Colors.purple;
      case 'dropdown':
        return Colors.teal;
      case 'group':
        return Colors.deepPurple;
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
        return Icons.group_work;
      default:
        return Icons.help;
    }
  }
}

class FieldInputsWidget extends StatefulWidget {
  final Map<String, dynamic> fieldDef;
  final bool isDefault;
  final bool isEditable;
  final Function(String, dynamic)? onFieldChanged;
  final List<String> dataTypes;
  final List<String> frequencies;

  const FieldInputsWidget({
    Key? key,
    required this.fieldDef,
    this.isDefault = false,
    this.isEditable = true,
    this.onFieldChanged,
    required this.dataTypes,
    required this.frequencies,
  }) : super(key: key);

  @override
  State<FieldInputsWidget> createState() => _FieldInputsWidgetState();
}

class _FieldInputsWidgetState extends State<FieldInputsWidget> {
  void _updateField(String key, dynamic value) {
    if (widget.onFieldChanged != null) {
      widget.onFieldChanged!(key, value);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final bool isGroupField = widget.fieldDef['dataType'] == 'group';

    return Column(
      children: [
        // Field Name Input
        TextFormField(
          initialValue: widget.fieldDef['name'],
          decoration: InputDecoration(
            labelText: 'Field Name *',
            prefixIcon: Icon(
              Icons.edit,
              color: theme.colorScheme.primary,
              size: 18,
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            filled: true,
            fillColor: isDarkMode ? const Color(0xFF2C2C2E) : Colors.white,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 12,
            ),
            isDense: true,
          ),
          style: TextStyle(
            color: isDarkMode ? Colors.white : theme.colorScheme.onSurface,
          ),
          onChanged: widget.isDefault || !widget.isEditable
              ? null
              : (value) => _updateField('name', value),
          readOnly: widget.isDefault || !widget.isEditable,
          validator: (value) => value == null || value.trim().isEmpty
              ? 'Field name is required'
              : null,
        ),
        const SizedBox(height: 12),

        if (!isGroupField) ...[
          // Data Type and Frequency Row
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: widget.fieldDef['dataType'],
                  decoration: InputDecoration(
                    labelText: 'Data Type',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    filled: true,
                    fillColor: isDarkMode
                        ? const Color(0xFF2C2C2E)
                        : Colors.white,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                    isDense: true,
                  ),
                  dropdownColor: isDarkMode
                      ? const Color(0xFF2C2C2E)
                      : Colors.white,
                  items: widget.dataTypes
                      .where((type) => type != 'group')
                      .map(
                        (type) => DropdownMenuItem(
                          value: type,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _getDataTypeIcon(type),
                                size: 14,
                                color: _getDataTypeColor(type),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                type,
                                style: TextStyle(
                                  color: isDarkMode
                                      ? Colors.white
                                      : theme.colorScheme.onSurface,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: widget.isDefault || !widget.isEditable
                      ? null
                      : (value) {
                          _updateField('dataType', value!);
                          if (value != 'dropdown') {
                            _updateField('options', []);
                          }
                          if (value != 'number') {
                            _updateField('unit', '');
                            _updateField('minRange', null);
                            _updateField('maxRange', null);
                            _updateField('isInteger', false);
                          }
                          if (value != 'boolean') {
                            _updateField('description_remarks', '');
                          }
                        },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: widget.fieldDef['frequency'],
                  decoration: InputDecoration(
                    labelText: 'Frequency',
                    prefixIcon: Icon(
                      Icons.schedule,
                      color: theme.colorScheme.primary,
                      size: 18,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    filled: true,
                    fillColor: isDarkMode
                        ? const Color(0xFF2C2C2E)
                        : Colors.white,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                    isDense: true,
                  ),
                  dropdownColor: isDarkMode
                      ? const Color(0xFF2C2C2E)
                      : Colors.white,
                  items: widget.frequencies.map((freq) {
                    return DropdownMenuItem(
                      value: freq,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: _getFrequencyColor(freq),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            freq,
                            style: TextStyle(
                              color: isDarkMode
                                  ? Colors.white
                                  : theme.colorScheme.onSurface,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: widget.isDefault || !widget.isEditable
                      ? null
                      : (value) => _updateField('frequency', value!),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Type-specific inputs
          ..._buildTypeSpecificInputs(theme, isDarkMode),
        ] else ...[
          // Group field specific inputs
          _buildGroupFieldInputs(theme, isDarkMode),
        ],

        const SizedBox(height: 12),

        // Mandatory field checkbox
        CheckboxListTile(
          title: Text(
            'Mandatory Field',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: isDarkMode ? Colors.white : theme.colorScheme.onSurface,
            ),
          ),
          subtitle: Text(
            'Users must provide a value for this field',
            style: TextStyle(
              fontSize: 12,
              color: isDarkMode
                  ? Colors.white.withOpacity(0.6)
                  : Colors.grey.shade600,
            ),
          ),
          value: widget.fieldDef['isMandatory'] ?? false,
          onChanged: widget.isDefault || !widget.isEditable
              ? null
              : (value) => _updateField('isMandatory', value ?? false),
          controlAffinity: ListTileControlAffinity.leading,
          contentPadding: EdgeInsets.zero,
          dense: true,
          activeColor: theme.colorScheme.primary,
        ),
      ],
    );
  }

  List<Widget> _buildTypeSpecificInputs(ThemeData theme, bool isDarkMode) {
    List<Widget> widgets = [];

    final String dataType = widget.fieldDef['dataType'] as String;

    if (dataType == 'number') {
      // Unit input
      widgets.add(
        TextFormField(
          initialValue: widget.fieldDef['unit'],
          decoration: InputDecoration(
            labelText: 'Unit',
            hintText: 'e.g., V, A, kW',
            prefixIcon: Icon(
              Icons.straighten,
              color: theme.colorScheme.primary,
              size: 18,
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            filled: true,
            fillColor: isDarkMode ? const Color(0xFF2C2C2E) : Colors.white,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 12,
            ),
            isDense: true,
          ),
          style: TextStyle(
            color: isDarkMode ? Colors.white : theme.colorScheme.onSurface,
          ),
          onChanged: widget.isDefault || !widget.isEditable
              ? null
              : (value) => _updateField('unit', value),
          readOnly: widget.isDefault || !widget.isEditable,
        ),
      );

      widgets.add(const SizedBox(height: 12));

      // Integer checkbox
      widgets.add(
        CheckboxListTile(
          title: Text(
            'Integer Only',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: isDarkMode ? Colors.white : theme.colorScheme.onSurface,
            ),
          ),
          subtitle: Text(
            'Restrict input to whole numbers only (e.g., 1, 2, 3)',
            style: TextStyle(
              fontSize: 12,
              color: isDarkMode
                  ? Colors.white.withOpacity(0.6)
                  : Colors.grey.shade600,
            ),
          ),
          value: widget.fieldDef['isInteger'] ?? false,
          onChanged: widget.isDefault || !widget.isEditable
              ? null
              : (value) => _updateField('isInteger', value ?? false),
          controlAffinity: ListTileControlAffinity.leading,
          contentPadding: EdgeInsets.zero,
          dense: true,
          activeColor: theme.colorScheme.primary,
        ),
      );

      widgets.add(const SizedBox(height: 12));

      // Min/Max range inputs
      widgets.add(
        Row(
          children: [
            Expanded(
              child: TextFormField(
                initialValue: widget.fieldDef['minRange']?.toString() ?? '',
                decoration: InputDecoration(
                  labelText: 'Min Range',
                  hintText: widget.fieldDef['isInteger'] == true
                      ? 'Minimum integer'
                      : 'Minimum value',
                  prefixIcon: Icon(
                    Icons.minimize,
                    color: theme.colorScheme.secondary,
                    size: 18,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  filled: true,
                  fillColor: isDarkMode
                      ? const Color(0xFF2C2C2E)
                      : Colors.white,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                  isDense: true,
                ),
                keyboardType: widget.fieldDef['isInteger'] == true
                    ? TextInputType.number
                    : const TextInputType.numberWithOptions(decimal: true),
                onChanged: widget.isDefault || !widget.isEditable
                    ? null
                    : (value) {
                        final parsedValue = value.isEmpty
                            ? null
                            : (widget.fieldDef['isInteger'] == true
                                  ? int.tryParse(value)?.toDouble()
                                  : double.tryParse(value));
                        _updateField('minRange', parsedValue);
                      },
                readOnly: widget.isDefault || !widget.isEditable,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                initialValue: widget.fieldDef['maxRange']?.toString() ?? '',
                decoration: InputDecoration(
                  labelText: 'Max Range',
                  hintText: widget.fieldDef['isInteger'] == true
                      ? 'Maximum integer'
                      : 'Maximum value',
                  prefixIcon: Icon(
                    Icons.add,
                    color: theme.colorScheme.secondary,
                    size: 18,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  filled: true,
                  fillColor: isDarkMode
                      ? const Color(0xFF2C2C2E)
                      : Colors.white,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                  isDense: true,
                ),
                keyboardType: widget.fieldDef['isInteger'] == true
                    ? TextInputType.number
                    : const TextInputType.numberWithOptions(decimal: true),
                onChanged: widget.isDefault || !widget.isEditable
                    ? null
                    : (value) {
                        final parsedValue = value.isEmpty
                            ? null
                            : (widget.fieldDef['isInteger'] == true
                                  ? int.tryParse(value)?.toDouble()
                                  : double.tryParse(value));
                        _updateField('maxRange', parsedValue);
                      },
                readOnly: widget.isDefault || !widget.isEditable,
              ),
            ),
          ],
        ),
      );
    } else if (dataType == 'dropdown') {
      widgets.add(
        TextFormField(
          initialValue: (widget.fieldDef['options'] as List?)?.join(', '),
          decoration: InputDecoration(
            labelText: 'Options (comma-separated) *',
            hintText: 'Option1, Option2, Option3',
            prefixIcon: Icon(
              Icons.list,
              color: theme.colorScheme.primary,
              size: 18,
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            filled: true,
            fillColor: isDarkMode ? const Color(0xFF2C2C2E) : Colors.white,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 12,
            ),
            isDense: true,
          ),
          style: TextStyle(
            color: isDarkMode ? Colors.white : theme.colorScheme.onSurface,
          ),
          onChanged: widget.isDefault || !widget.isEditable
              ? null
              : (value) {
                  final options = value
                      .split(',')
                      .map((e) => e.trim())
                      .where((e) => e.isNotEmpty)
                      .toList();
                  _updateField('options', options);
                },
          readOnly: widget.isDefault || !widget.isEditable,
          validator: (value) {
            if (widget.fieldDef['dataType'] == 'dropdown' &&
                (value == null || value.trim().isEmpty)) {
              return 'Options are required for dropdown fields';
            }
            return null;
          },
        ),
      );
    } else if (dataType == 'boolean') {
      widgets.add(
        TextFormField(
          initialValue: widget.fieldDef['description_remarks'],
          decoration: InputDecoration(
            labelText: 'Description/Remarks (Optional)',
            hintText: 'Additional context for this boolean field',
            prefixIcon: Icon(
              Icons.notes,
              color: theme.colorScheme.primary,
              size: 18,
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            filled: true,
            fillColor: isDarkMode ? const Color(0xFF2C2C2E) : Colors.white,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 12,
            ),
          ),
          style: TextStyle(
            color: isDarkMode ? Colors.white : theme.colorScheme.onSurface,
          ),
          maxLines: 2,
          onChanged: widget.isDefault || !widget.isEditable
              ? null
              : (value) => _updateField('description_remarks', value),
          readOnly: widget.isDefault || !widget.isEditable,
        ),
      );
    }

    return widgets;
  }

  Widget _buildGroupFieldInputs(ThemeData theme, bool isDarkMode) {
    return Column(
      children: [
        Row(
          children: [
            Icon(
              Icons.group_work,
              color: theme.colorScheme.secondary,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              'Group Field Configuration',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.secondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: widget.fieldDef['frequency'],
          decoration: InputDecoration(
            labelText: 'Frequency',
            prefixIcon: Icon(
              Icons.schedule,
              color: theme.colorScheme.primary,
              size: 18,
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            filled: true,
            fillColor: isDarkMode ? const Color(0xFF2C2C2E) : Colors.white,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 12,
            ),
            isDense: true,
          ),
          dropdownColor: isDarkMode ? const Color(0xFF2C2C2E) : Colors.white,
          items: widget.frequencies.map((freq) {
            return DropdownMenuItem(
              value: freq,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: _getFrequencyColor(freq),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    freq,
                    style: TextStyle(
                      color: isDarkMode
                          ? Colors.white
                          : theme.colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
          onChanged: widget.isDefault || !widget.isEditable
              ? null
              : (value) => _updateField('frequency', value!),
        ),
      ],
    );
  }

  Color _getDataTypeColor(String dataType) {
    switch (dataType) {
      case 'text':
        return Colors.blue;
      case 'number':
        return Colors.green;
      case 'boolean':
        return Colors.orange;
      case 'date':
        return Colors.purple;
      case 'dropdown':
        return Colors.teal;
      case 'group':
        return Colors.deepPurple;
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
        return Icons.group_work;
      default:
        return Icons.help;
    }
  }

  Color _getFrequencyColor(String frequency) {
    switch (frequency.toLowerCase()) {
      case 'hourly':
        return Colors.red;
      case 'daily':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }
}

class NestedFieldsWidget extends StatefulWidget {
  final Map<String, dynamic> fieldDef;
  final bool isEditable;
  final Function(String, dynamic)? onFieldChanged;
  final List<String> dataTypes;

  const NestedFieldsWidget({
    Key? key,
    required this.fieldDef,
    this.isEditable = true,
    this.onFieldChanged,
    required this.dataTypes,
  }) : super(key: key);

  @override
  State<NestedFieldsWidget> createState() => _NestedFieldsWidgetState();
}

class _NestedFieldsWidgetState extends State<NestedFieldsWidget> {
  void _addNestedField() {
    if (!widget.isEditable) return;

    final nestedFields =
        widget.fieldDef['nestedFields'] as List<Map<String, dynamic>>;
    nestedFields.add({
      'name': '',
      'dataType': ReadingFieldDataType.text.toString().split('.').last,
      'unit': '',
      'options': [],
      'isMandatory': false,
      'description_remarks': '',
      'minRange': null,
      'maxRange': null,
      'isInteger': false,
    });

    if (widget.onFieldChanged != null) {
      widget.onFieldChanged!('nestedFields', nestedFields);
    }

    setState(() {});
  }

  void _removeNestedField(int index) {
    if (!widget.isEditable) return;

    final nestedFields =
        widget.fieldDef['nestedFields'] as List<Map<String, dynamic>>;
    nestedFields.removeAt(index);

    if (widget.onFieldChanged != null) {
      widget.onFieldChanged!('nestedFields', nestedFields);
    }

    setState(() {});
  }

  void _updateNestedField(int index, String key, dynamic value) {
    if (!widget.isEditable) return;

    final nestedFields =
        widget.fieldDef['nestedFields'] as List<Map<String, dynamic>>;
    nestedFields[index][key] = value;

    if (widget.onFieldChanged != null) {
      widget.onFieldChanged!('nestedFields', nestedFields);
    }

    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final nestedFields =
        widget.fieldDef['nestedFields'] as List<Map<String, dynamic>>? ?? [];

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondary.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.colorScheme.secondary.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.list, color: theme.colorScheme.secondary, size: 16),
              const SizedBox(width: 8),
              Text(
                'Group Fields',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.secondary,
                ),
              ),
              const Spacer(),
              Text(
                '${nestedFields.length} fields',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: theme.colorScheme.secondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          if (nestedFields.isEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDarkMode
                    ? const Color(0xFF3C3C3E)
                    : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'No fields defined for this group. Add fields below.',
                style: TextStyle(
                  fontSize: 13,
                  color: isDarkMode
                      ? Colors.white.withOpacity(0.4)
                      : Colors.grey.shade600,
                ),
                textAlign: TextAlign.center,
              ),
            )
          else
            Column(
              children: nestedFields.asMap().entries.map((entry) {
                final index = entry.key;
                final nestedField = entry.value;

                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: NestedFieldCard(
                    fieldDef: nestedField,
                    index: index,
                    onRemove: widget.isEditable
                        ? () => _removeNestedField(index)
                        : null,
                    onFieldChanged: widget.isEditable
                        ? (key, value) => _updateNestedField(index, key, value)
                        : null,
                    dataTypes: widget.dataTypes,
                  ),
                );
              }).toList(),
            ),

          if (widget.isEditable) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _addNestedField,
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Add Field to Group'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.secondary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class NestedFieldCard extends StatelessWidget {
  final Map<String, dynamic> fieldDef;
  final int index;
  final VoidCallback? onRemove;
  final Function(String, dynamic)? onFieldChanged;
  final List<String> dataTypes;

  const NestedFieldCard({
    Key? key,
    required this.fieldDef,
    required this.index,
    this.onRemove,
    this.onFieldChanged,
    required this.dataTypes,
  }) : super(key: key);

  void _updateField(String key, dynamic value) {
    if (onFieldChanged != null) {
      onFieldChanged!(key, value);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF2C2C2E) : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDarkMode
              ? Colors.white.withOpacity(0.1)
              : Colors.grey.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: _getDataTypeColor(
                    fieldDef['dataType'],
                  ).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Icon(
                  _getDataTypeIcon(fieldDef['dataType']),
                  size: 12,
                  color: _getDataTypeColor(fieldDef['dataType']),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  fieldDef['name'].isEmpty ? 'Unnamed Field' : fieldDef['name'],
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDarkMode
                        ? Colors.white
                        : theme.colorScheme.onSurface,
                  ),
                ),
              ),
              if (onRemove != null)
                IconButton(
                  onPressed: onRemove,
                  icon: Icon(
                    Icons.remove_circle_outline,
                    color: theme.colorScheme.error,
                    size: 16,
                  ),
                  style: IconButton.styleFrom(
                    backgroundColor: theme.colorScheme.error.withOpacity(0.1),
                    minimumSize: const Size(24, 24),
                    padding: EdgeInsets.zero,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),

          // Field Name
          TextFormField(
            initialValue: fieldDef['name'],
            decoration: InputDecoration(
              labelText: 'Field Name *',
              hintText: 'e.g., Cell Number, Voltage',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
              ),
              filled: true,
              fillColor: isDarkMode
                  ? const Color(0xFF3C3C3E)
                  : Colors.grey.shade50,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 8,
              ),
              isDense: true,
            ),
            style: TextStyle(
              fontSize: 13,
              color: isDarkMode ? Colors.white : theme.colorScheme.onSurface,
            ),
            onChanged: (value) => _updateField('name', value),
            validator: (value) => value == null || value.trim().isEmpty
                ? 'Field name is required'
                : null,
          ),
          const SizedBox(height: 8),

          // Data Type and Unit Row
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: fieldDef['dataType'],
                  decoration: InputDecoration(
                    labelText: 'Type',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                    filled: true,
                    fillColor: isDarkMode
                        ? const Color(0xFF3C3C3E)
                        : Colors.grey.shade50,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 8,
                    ),
                    isDense: true,
                  ),
                  dropdownColor: isDarkMode
                      ? const Color(0xFF2C2C2E)
                      : Colors.white,
                  items: dataTypes
                      .where((type) => type != 'group')
                      .map(
                        (type) => DropdownMenuItem(
                          value: type,
                          child: Text(
                            type,
                            style: TextStyle(
                              fontSize: 13,
                              color: isDarkMode
                                  ? Colors.white
                                  : theme.colorScheme.onSurface,
                            ),
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    _updateField('dataType', value!);
                    if (value != 'dropdown') _updateField('options', []);
                    if (value != 'number') {
                      _updateField('unit', '');
                      _updateField('minRange', null);
                      _updateField('maxRange', null);
                      _updateField('isInteger', false);
                    }
                    if (value != 'boolean')
                      _updateField('description_remarks', '');
                  },
                ),
              ),
              if (fieldDef['dataType'] == 'number') ...[
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    initialValue: fieldDef['unit'],
                    decoration: InputDecoration(
                      labelText: 'Unit',
                      hintText: 'V, A, etc.',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                      filled: true,
                      fillColor: isDarkMode
                          ? const Color(0xFF3C3C3E)
                          : Colors.grey.shade50,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 8,
                      ),
                      isDense: true,
                    ),
                    style: TextStyle(
                      fontSize: 13,
                      color: isDarkMode
                          ? Colors.white
                          : theme.colorScheme.onSurface,
                    ),
                    onChanged: (value) => _updateField('unit', value),
                  ),
                ),
              ],
            ],
          ),

          // Type-specific inputs
          if (fieldDef['dataType'] == 'dropdown') ...[
            const SizedBox(height: 8),
            TextFormField(
              initialValue: (fieldDef['options'] as List?)?.join(', '),
              decoration: InputDecoration(
                labelText: 'Options *',
                hintText: 'Option1, Option2',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
                filled: true,
                fillColor: isDarkMode
                    ? const Color(0xFF3C3C3E)
                    : Colors.grey.shade50,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 8,
                ),
                isDense: true,
              ),
              style: TextStyle(
                fontSize: 13,
                color: isDarkMode ? Colors.white : theme.colorScheme.onSurface,
              ),
              onChanged: (value) {
                final options = value
                    .split(',')
                    .map((e) => e.trim())
                    .where((e) => e.isNotEmpty)
                    .toList();
                _updateField('options', options);
              },
            ),
          ],

          const SizedBox(height: 8),

          // Mandatory checkbox
          CheckboxListTile(
            title: Text(
              'Mandatory',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: isDarkMode ? Colors.white : theme.colorScheme.onSurface,
              ),
            ),
            value: fieldDef['isMandatory'] ?? false,
            onChanged: (value) => _updateField('isMandatory', value ?? false),
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
            dense: true,
            visualDensity: VisualDensity.compact,
            activeColor: theme.colorScheme.primary,
          ),
        ],
      ),
    );
  }

  Color _getDataTypeColor(String dataType) {
    switch (dataType) {
      case 'text':
        return Colors.blue;
      case 'number':
        return Colors.green;
      case 'boolean':
        return Colors.orange;
      case 'date':
        return Colors.purple;
      case 'dropdown':
        return Colors.teal;
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
      default:
        return Icons.help;
    }
  }
}

class FieldListWidget extends StatefulWidget {
  final List<Map<String, dynamic>> fields;
  final bool isEditable;
  final Function(List<Map<String, dynamic>>)? onFieldsChanged;
  final List<String> dataTypes;
  final List<String> frequencies;
  final VoidCallback? onAddField;
  final VoidCallback? onAddGroupField;

  const FieldListWidget({
    Key? key,
    required this.fields,
    this.isEditable = true,
    this.onFieldsChanged,
    required this.dataTypes,
    required this.frequencies,
    this.onAddField,
    this.onAddGroupField,
  }) : super(key: key);

  @override
  State<FieldListWidget> createState() => _FieldListWidgetState();
}

class _FieldListWidgetState extends State<FieldListWidget> {
  void _removeField(int index) {
    if (!widget.isEditable) return;

    final newFields = List<Map<String, dynamic>>.from(widget.fields);
    newFields.removeAt(index);

    if (widget.onFieldsChanged != null) {
      widget.onFieldsChanged!(newFields);
    }
  }

  void _updateField(int index, String key, dynamic value) {
    if (!widget.isEditable) return;

    final newFields = List<Map<String, dynamic>>.from(widget.fields);
    newFields[index][key] = value;

    if (widget.onFieldsChanged != null) {
      widget.onFieldsChanged!(newFields);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return Column(
      children: [
        if (widget.fields.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: isDarkMode ? const Color(0xFF3C3C3E) : Colors.grey.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isDarkMode
                    ? Colors.white.withOpacity(0.1)
                    : Colors.grey.shade200,
              ),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.inbox_outlined,
                  size: 48,
                  color: isDarkMode
                      ? Colors.white.withOpacity(0.4)
                      : Colors.grey.shade400,
                ),
                const SizedBox(height: 16),
                Text(
                  'No Fields Configured',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: isDarkMode
                        ? Colors.white.withOpacity(0.6)
                        : Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Add fields to define the reading parameters',
                  style: TextStyle(
                    fontSize: 14,
                    color: isDarkMode
                        ? Colors.white.withOpacity(0.5)
                        : Colors.grey.shade500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          )
        else
          Column(
            children: widget.fields.asMap().entries.map((entry) {
              final index = entry.key;
              final field = entry.value;
              final bool isDefault = field['isDefault'] ?? false;

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                child: ReadingFieldCard(
                  fieldDef: field,
                  index: index,
                  isDefault: isDefault,
                  isEditable: widget.isEditable,
                  onRemove: !isDefault ? () => _removeField(index) : null,
                  onFieldChanged: (key, value) =>
                      _updateField(index, key, value),
                  dataTypes: widget.dataTypes,
                  frequencies: widget.frequencies,
                ),
              );
            }).toList(),
          ),

        if (widget.isEditable) ...[
          const SizedBox(height: 16),
          Row(
            children: [
              if (widget.onAddField != null)
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: widget.onAddField,
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add Field'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              if (widget.onAddField != null && widget.onAddGroupField != null)
                const SizedBox(width: 12),
              if (widget.onAddGroupField != null)
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: widget.onAddGroupField,
                    icon: const Icon(Icons.group_work, size: 18),
                    label: const Text('Group Field'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.secondary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

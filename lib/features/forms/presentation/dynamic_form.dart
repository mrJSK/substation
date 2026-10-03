import 'package:flutter/material.dart';

import '../../../core/json.dart';
import '../domain/form_schema.dart';

/// Renders any [FormSchema]. Values are a flat map keyed by field key, ready
/// to be written to typed columns or an `extra` JSON column.
///
/// Usage:
///   final key = GlobalKey&lt;DynamicFormState&gt;();
///   DynamicForm(key: key, schema: def.schema);
///   if (key.currentState!.validate()) save(key.currentState!.values);
class DynamicForm extends StatefulWidget {
  const DynamicForm({super.key, required this.schema, this.initialValues = const {}, this.readOnly = false});

  final FormSchema schema;
  final Map<String, Object?> initialValues;
  final bool readOnly;

  @override
  State<DynamicForm> createState() => DynamicFormState();
}

class DynamicFormState extends State<DynamicForm> {
  final _formKey = GlobalKey<FormState>();
  late final Map<String, Object?> _values = {...widget.initialValues};

  /// Only values of fields currently visible.
  Map<String, Object?> get values => {
        for (final f in widget.schema.fields)
          if (_isVisible(f) && _values[f.key] != null) f.key: _values[f.key],
      };

  bool validate() => _formKey.currentState!.validate();

  bool _isVisible(FieldSpec f) => f.visibleIf == null || f.visibleIf!.matches(_values);

  void _set(String key, Object? value) => setState(() => _values[key] = value);

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final section in widget.schema.sections) ...[
            if (section.title.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 16, bottom: 4),
                child: Text(section.title, style: Theme.of(context).textTheme.titleSmall),
              ),
            for (final field in section.fields)
              if (_isVisible(field))
                Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: _buildField(context, field)),
          ],
        ],
      ),
    );
  }

  Widget _buildField(BuildContext context, FieldSpec f) {
    final label = f.unit == null ? f.label : '${f.label} (${f.unit})';
    final decoration = InputDecoration(labelText: f.required ? '$label *' : label, helperText: f.hint, isDense: true);

    switch (f.type) {
      case FieldType.number:
      case FieldType.integer:
        return _NumberField(spec: f, decoration: decoration, initial: _values[f.key] as num?, enabled: !widget.readOnly,
            onChanged: (v) => _set(f.key, v));
      case FieldType.text:
      case FieldType.textarea:
        return TextFormField(
          initialValue: _values[f.key] as String?,
          enabled: !widget.readOnly,
          minLines: f.type == FieldType.textarea ? 2 : 1,
          maxLines: f.type == FieldType.textarea ? 5 : 1,
          decoration: decoration,
          onChanged: (v) => _set(f.key, v.trim().isEmpty ? null : v.trim()),
          validator: (v) => f.required && (v == null || v.trim().isEmpty) ? 'Required' : null,
        );
      case FieldType.select:
        return DropdownButtonFormField<String>(
          initialValue: _values[f.key] as String?,
          decoration: decoration,
          items: [for (final o in f.options) DropdownMenuItem(value: o.value, child: Text(o.label))],
          onChanged: widget.readOnly ? null : (v) => _set(f.key, v),
          validator: (v) => f.required && v == null ? 'Required' : null,
        );
      case FieldType.toggle:
        return SwitchListTile(
          contentPadding: EdgeInsets.zero,
          dense: true,
          title: Text(label),
          value: (_values[f.key] as bool?) ?? false,
          onChanged: widget.readOnly ? null : (v) => _set(f.key, v),
        );
      case FieldType.date:
      case FieldType.datetime:
        return _DateField(spec: f, decoration: decoration, value: _values[f.key] as String?, enabled: !widget.readOnly,
            onChanged: (v) => _set(f.key, v));
      case FieldType.unknown:
        return Text('Unsupported field type for "${f.label}"', style: TextStyle(color: Theme.of(context).colorScheme.error));
    }
  }
}

class _NumberField extends StatefulWidget {
  const _NumberField({required this.spec, required this.decoration, required this.initial, required this.enabled, required this.onChanged});
  final FieldSpec spec;
  final InputDecoration decoration;
  final num? initial;
  final bool enabled;
  final ValueChanged<num?> onChanged;

  @override
  State<_NumberField> createState() => _NumberFieldState();
}

class _NumberFieldState extends State<_NumberField> {
  late num? _value = widget.initial;

  num? _parse(String text) {
    final t = text.trim();
    if (t.isEmpty) return null;
    return widget.spec.type == FieldType.integer ? int.tryParse(t) : double.tryParse(t);
  }

  @override
  Widget build(BuildContext context) {
    final f = widget.spec;
    final status = (_value != null && f.limits != null) ? f.limits!.statusOf(_value!.toDouble()) : LimitStatus.normal;
    final colors = Theme.of(context).colorScheme;
    final (String? note, Color? color) = switch (status) {
      LimitStatus.trip => ('Beyond trip limit', colors.error),
      LimitStatus.alarm => ('Beyond alarm limit', Colors.orange.shade800),
      LimitStatus.normal => (null, null),
    };

    return TextFormField(
      initialValue: widget.initial?.toString(),
      enabled: widget.enabled,
      keyboardType: TextInputType.numberWithOptions(decimal: f.type == FieldType.number, signed: true),
      decoration: widget.decoration.copyWith(
        helperText: note ?? widget.decoration.helperText,
        helperStyle: color == null ? null : TextStyle(color: color, fontWeight: FontWeight.w600),
        enabledBorder: color == null ? null : OutlineInputBorder(borderSide: BorderSide(color: color)),
      ),
      onChanged: (text) {
        setState(() => _value = _parse(text));
        widget.onChanged(_value);
      },
      validator: (text) {
        final v = _parse(text ?? '');
        if ((text ?? '').trim().isEmpty) return f.required ? 'Required' : null;
        if (v == null) return f.type == FieldType.integer ? 'Whole number expected' : 'Number expected';
        if (f.min != null && v < f.min!) return 'Minimum ${f.min}';
        if (f.max != null && v > f.max!) return 'Maximum ${f.max}';
        return null;
      },
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({required this.spec, required this.decoration, required this.value, required this.enabled, required this.onChanged});
  final FieldSpec spec;
  final InputDecoration decoration;
  final String? value;
  final bool enabled;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final parsed = value == null ? null : DateTime.tryParse(value!);
    final local = MaterialLocalizations.of(context);
    final text = parsed == null
        ? ''
        : spec.type == FieldType.date
            ? local.formatMediumDate(parsed)
            : '${local.formatMediumDate(parsed)} ${local.formatTimeOfDay(TimeOfDay.fromDateTime(parsed), alwaysUse24HourFormat: true)}';

    return FormField<String>(
      initialValue: value,
      validator: (_) => spec.required && value == null ? 'Required' : null,
      builder: (state) => InputDecorator(
        decoration: decoration.copyWith(errorText: state.errorText),
        child: Row(
          children: [
            Expanded(child: Text(text)),
            TextButton(
              onPressed: !enabled
                  ? null
                  : () async {
                      final now = DateTime.now();
                      final d = await showDatePicker(
                          context: context, initialDate: parsed ?? now, firstDate: DateTime(now.year - 5), lastDate: DateTime(now.year + 5));
                      if (d == null || !context.mounted) return;
                      if (spec.type == FieldType.date) {
                        onChanged(isoDate(d));
                      } else {
                        final t = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(parsed ?? now));
                        if (t == null) return;
                        onChanged(DateTime(d.year, d.month, d.day, t.hour, t.minute).toIso8601String());
                      }
                    },
              child: const Text('Choose'),
            ),
          ],
        ),
      ),
    );
  }
}

import '../../../core/json.dart';

/// A server-defined form (ui_forms.schema). See the field reference in
/// supabase/migrations/20261003000350_experience.sql.
class FormDefinition {
  const FormDefinition({
    required this.id,
    required this.code,
    required this.version,
    required this.title,
    required this.schema,
    required this.isTenantOverride,
    this.description,
    this.rawSchema = const {},
  });

  final String id;
  final String code;
  final int version;
  final String title;
  final String? description;
  final FormSchema schema;
  final Map<String, dynamic> rawSchema;
  final bool isTenantOverride;

  factory FormDefinition.fromJson(Map<String, dynamic> j) {
    final raw = j.mapOrNull('schema') ?? const <String, dynamic>{};
    return FormDefinition(
      id: j.str('id'),
      code: j.str('code'),
      version: j.intOrNull('version') ?? 1,
      title: j.str('title'),
      description: j.strOrNull('description'),
      schema: FormSchema.fromJson(raw),
      rawSchema: raw,
      isTenantOverride: j.boolOr('is_tenant_override', j['tenant_id'] != null),
    );
  }
}

class FormSchema {
  const FormSchema(this.sections);
  final List<FormSection> sections;

  factory FormSchema.fromJson(Map<String, dynamic> j) => FormSchema(j.mapList('sections').map(FormSection.fromJson).toList());

  Iterable<FieldSpec> get fields => sections.expand((s) => s.fields);
}

class FormSection {
  const FormSection({required this.title, required this.fields});
  final String title;
  final List<FieldSpec> fields;

  factory FormSection.fromJson(Map<String, dynamic> j) =>
      FormSection(title: j.strOrNull('title') ?? '', fields: j.mapList('fields').map(FieldSpec.fromJson).toList());
}

enum FieldType { text, textarea, number, integer, select, toggle, date, datetime, unknown }

class FieldOption {
  const FieldOption(this.value, this.label);
  final String value;
  final String label;
}

class FieldSpec {
  const FieldSpec({
    required this.key,
    required this.label,
    required this.type,
    this.required = false,
    this.unit,
    this.hint,
    this.options = const [],
    this.min,
    this.max,
    this.decimals,
    this.limits,
    this.visibleIf,
  });

  final String key;
  final String label;
  final FieldType type;
  final bool required;
  final String? unit;
  final String? hint;
  final List<FieldOption> options;
  final double? min;
  final double? max;
  final int? decimals;
  final Limits? limits;
  final VisibleIf? visibleIf;

  factory FieldSpec.fromJson(Map<String, dynamic> j) => FieldSpec(
        key: j.str('key'),
        label: j.strOrNull('label') ?? j.str('key'),
        type: FieldType.values.asNameMap()[j.strOrNull('type')] ?? FieldType.unknown,
        required: j.boolOr('required', false),
        unit: j.strOrNull('unit'),
        hint: j.strOrNull('hint'),
        options: ((j['options'] as List?) ?? const []).map((o) {
          if (o is Map) return FieldOption('${o['value']}', '${o['label'] ?? o['value']}');
          return FieldOption('$o', '$o');
        }).toList(),
        min: j.doubleOrNull('min'),
        max: j.doubleOrNull('max'),
        decimals: j.intOrNull('decimals'),
        limits: j.mapOrNull('limits') == null ? null : Limits.fromJson(j.mapOrNull('limits')!),
        visibleIf: j.mapOrNull('visible_if') == null ? null : VisibleIf.fromJson(j.mapOrNull('visible_if')!),
      );
}

enum LimitStatus { normal, alarm, trip }

/// Operating limits for a reading. Exceeding them warns; it never blocks entry,
/// because an abnormal reading is exactly what must be recorded.
class Limits {
  const Limits({this.alarmLow, this.alarmHigh, this.tripLow, this.tripHigh});
  final double? alarmLow;
  final double? alarmHigh;
  final double? tripLow;
  final double? tripHigh;

  factory Limits.fromJson(Map<String, dynamic> j) => Limits(
        alarmLow: j.doubleOrNull('alarm_low'),
        alarmHigh: j.doubleOrNull('alarm_high'),
        tripLow: j.doubleOrNull('trip_low'),
        tripHigh: j.doubleOrNull('trip_high'),
      );

  LimitStatus statusOf(double v) {
    if ((tripHigh != null && v >= tripHigh!) || (tripLow != null && v <= tripLow!)) return LimitStatus.trip;
    if ((alarmHigh != null && v >= alarmHigh!) || (alarmLow != null && v <= alarmLow!)) return LimitStatus.alarm;
    return LimitStatus.normal;
  }
}

class VisibleIf {
  const VisibleIf({required this.field, required this.equals});
  final String field;
  final Object? equals;

  factory VisibleIf.fromJson(Map<String, dynamic> j) => VisibleIf(field: j.str('field'), equals: j['equals']);

  bool matches(Map<String, Object?> values) => values[field] == equals;
}

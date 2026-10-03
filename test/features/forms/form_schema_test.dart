import 'package:flutter_test/flutter_test.dart';
import 'package:suberp/features/forms/domain/form_schema.dart';

void main() {
  final schema = FormSchema.fromJson({
    'sections': [
      {
        'title': 'Temperatures',
        'fields': [
          {'key': 'wti_c', 'label': 'WTI', 'type': 'number', 'unit': '°C', 'required': true,
           'limits': {'alarm_high': 90, 'trip_high': 105}},
          {'key': 'v', 'label': 'DC voltage', 'type': 'number', 'limits': {'alarm_low': 104.5}},
        ],
      },
      {
        'title': 'Status',
        'fields': [
          {'key': 'breaker', 'type': 'select', 'options': ['CLOSED', {'value': 'OPEN', 'label': 'Open'}]},
          {'key': 'has_alarm', 'label': 'Alarm', 'type': 'toggle'},
          {'key': 'alarm_details', 'label': 'Details', 'type': 'textarea', 'visible_if': {'field': 'has_alarm', 'equals': true}},
          {'key': 'mystery', 'type': 'hologram'},
        ],
      },
    ],
  });

  FieldSpec field(String key) => schema.fields.firstWhere((f) => f.key == key);

  test('parses sections, types, units and options', () {
    expect(schema.sections, hasLength(2));
    expect(field('wti_c').type, FieldType.number);
    expect(field('wti_c').unit, '°C');
    expect(field('wti_c').required, isTrue);
    expect(field('breaker').options.map((o) => o.label), ['CLOSED', 'Open']);
    expect(field('breaker').label, 'breaker', reason: 'label falls back to the key');
    expect(field('mystery').type, FieldType.unknown);
  });

  test('limits classify readings as normal, alarm or trip', () {
    final limits = field('wti_c').limits!;
    expect(limits.statusOf(75), LimitStatus.normal);
    expect(limits.statusOf(90), LimitStatus.alarm);
    expect(limits.statusOf(104.9), LimitStatus.alarm);
    expect(limits.statusOf(105), LimitStatus.trip);
    expect(field('v').limits!.statusOf(100), LimitStatus.alarm);
  });

  test('visible_if shows a field only when the condition holds', () {
    final rule = field('alarm_details').visibleIf!;
    expect(rule.matches({'has_alarm': true}), isTrue);
    expect(rule.matches({'has_alarm': false}), isFalse);
    expect(rule.matches({}), isFalse);
  });
}

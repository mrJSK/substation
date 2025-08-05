// lib/constants/app_constants.dart
class AppConstants {
  // Voltage levels used across the app
  static const List<String> voltageLevel = [
    '765kV',
    '400kV',
    '220kV',
    '132kV',
    '66kV',
    '33kV',
    '11kV',
    '400V',
  ];

  // Substation types
  static const List<String> substationTypes = ['Manual', 'SAS'];

  // SAS status options
  static const List<String> sasStatus = ['Working', 'Non Working'];

  // General status options
  static const List<String> generalStatus = [
    'Active',
    'Inactive',
    'Under Maintenance',
    'Decommissioned',
  ];

  // Common SAS makes
  static const List<String> commonSasMakes = [
    'ABB',
    'Siemens',
    'Schneider Electric',
    'GE',
    'Areva',
    'Crompton Greaves',
    'BHEL',
    'L&T',
    'Other',
  ];
}

// // lib/screens/admin/reading_template_management_screen.dart
// import 'package:flutter/material.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'dart:async';
// import '../../models/reading_models.dart';
// import '../../utils/snackbar_utils.dart';
// import 'package:intl/intl.dart';

// enum ReadingTemplateViewMode { list, form }

// class ReadingTemplateManagementScreen extends StatefulWidget {
//   const ReadingTemplateManagementScreen({super.key});

//   @override
//   State<ReadingTemplateManagementScreen> createState() =>
//       _ReadingTemplateManagementScreenState();
// }

// class _ReadingTemplateManagementScreenState
//     extends State<ReadingTemplateManagementScreen>
//     with SingleTickerProviderStateMixin {
//   ReadingTemplateViewMode _viewMode = ReadingTemplateViewMode.list;
//   final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
//   ReadingTemplate? _templateToEdit;
//   List<ReadingTemplate> _templates = [];
//   bool _isLoading = true;
//   bool _isSaving = false;

//   String? _selectedBayType;
//   String? _templateDescription;
//   List<Map<String, dynamic>> _templateReadingFields = [];

//   late AnimationController _animationController;
//   late Animation<double> _fadeAnimation;

//   final List<String> _dataTypes = ReadingFieldDataType.values
//       .map((e) => e.toString().split('.').last)
//       .toList();
//   final List<String> _frequencies = ReadingFrequency.values
//       .map((e) => e.toString().split('.').last)
//       .toList();

//   final List<String> _bayTypes = [
//     'Transformer',
//     'Line',
//     'Feeder',
//     'Capacitor Bank',
//     'Reactor',
//     'Bus Coupler',
//     'Battery',
//     'Busbar',
//   ];

//   final List<ReadingField> _defaultEnergyFields = [
//     ReadingField(
//       name: 'Previous Day Reading (Import)',
//       dataType: ReadingFieldDataType.number,
//       isMandatory: true,
//       unit: 'MWH',
//       frequency: ReadingFrequency.daily,
//     ),
//     ReadingField(
//       name: 'Current Day Reading (Import)',
//       dataType: ReadingFieldDataType.number,
//       isMandatory: true,
//       unit: 'MWH',
//       frequency: ReadingFrequency.daily,
//     ),
//     ReadingField(
//       name: 'Previous Day Reading (Export)',
//       dataType: ReadingFieldDataType.number,
//       isMandatory: true,
//       unit: 'MWH',
//       frequency: ReadingFrequency.daily,
//     ),
//     ReadingField(
//       name: 'Current Day Reading (Export)',
//       dataType: ReadingFieldDataType.number,
//       isMandatory: true,
//       unit: 'MWH',
//       frequency: ReadingFrequency.daily,
//     ),
//   ];

//   final Map<String, List<ReadingField>> _defaultHourlyFields = {
//     'Feeder': [
//       ReadingField(
//         name: 'Current',
//         unit: 'A',
//         dataType: ReadingFieldDataType.number,
//         isMandatory: true,
//         frequency: ReadingFrequency.hourly,
//         minRange: 0.00,
//         maxRange: 5000.000,
//       ),
//     ],
//     'Transformer': [
//       ReadingField(
//         name: 'Current',
//         unit: 'A',
//         dataType: ReadingFieldDataType.number,
//         isMandatory: true,
//         frequency: ReadingFrequency.hourly,
//         minRange: 0.00,
//         maxRange: 5000.00,
//       ),
//       ReadingField(
//         name: 'Power Factor',
//         unit: '',
//         dataType: ReadingFieldDataType.number,
//         isMandatory: true,
//         frequency: ReadingFrequency.hourly,
//         minRange: -1.00,
//         maxRange: 1.00,
//       ),
//       ReadingField(
//         name: 'Real Power (MW)',
//         unit: 'MW',
//         dataType: ReadingFieldDataType.number,
//         isMandatory: true,
//         frequency: ReadingFrequency.hourly,
//         minRange: 0.00,
//         maxRange: 1000.00,
//       ),
//       ReadingField(
//         name: 'Voltage',
//         unit: 'kV',
//         dataType: ReadingFieldDataType.number,
//         isMandatory: true,
//         frequency: ReadingFrequency.hourly,
//         minRange: 10.00,
//         maxRange: 1000.00,
//       ),
//       ReadingField(
//         name: 'Apparent Power (MVAR)',
//         unit: 'MVAR',
//         dataType: ReadingFieldDataType.number,
//         isMandatory: true,
//         frequency: ReadingFrequency.hourly,
//         minRange: 0.00,
//         maxRange: 1000.00,
//       ),
//       ReadingField(
//         name: 'Gas Pressure (SF6)',
//         unit: 'kg/cm2',
//         dataType: ReadingFieldDataType.number,
//         isMandatory: false,
//         frequency: ReadingFrequency.hourly,
//         minRange: 4.0,
//         maxRange: 10.0,
//       ),
//       ReadingField(
//         name: 'Winding Temperature',
//         unit: 'Celsius',
//         dataType: ReadingFieldDataType.number,
//         isMandatory: true,
//         frequency: ReadingFrequency.hourly,
//         minRange: -40.00,
//         maxRange: 120.00,
//       ),
//       ReadingField(
//         name: 'Oil Temperature',
//         unit: 'Celsius',
//         dataType: ReadingFieldDataType.number,
//         isMandatory: true,
//         frequency: ReadingFrequency.hourly,
//         minRange: -40.00,
//         maxRange: 120.00,
//       ),
//       ReadingField(
//         name: 'Tap Position',
//         unit: 'No.',
//         dataType: ReadingFieldDataType.number,
//         isMandatory: true,
//         frequency: ReadingFrequency.hourly,
//         minRange: 1.0,
//         maxRange: 33.0,
//         isInteger: true, // 🔥 Integer-only field
//       ),
//       ReadingField(
//         name: 'Frequency',
//         unit: 'Hz',
//         dataType: ReadingFieldDataType.number,
//         isMandatory: true,
//         frequency: ReadingFrequency.hourly,
//         minRange: 48.0,
//         maxRange: 52.0,
//       ),
//     ],
//     'Line': [
//       ReadingField(
//         name: 'Current',
//         unit: 'A',
//         dataType: ReadingFieldDataType.number,
//         isMandatory: true,
//         frequency: ReadingFrequency.hourly,
//         minRange: 0.00,
//         maxRange: 5000.00,
//       ),
//       ReadingField(
//         name: 'Power Factor',
//         unit: '',
//         dataType: ReadingFieldDataType.number,
//         isMandatory: true,
//         frequency: ReadingFrequency.hourly,
//         minRange: -1.00,
//         maxRange: 1.00,
//       ),
//       ReadingField(
//         name: 'Real Power (MW)',
//         unit: 'MW',
//         dataType: ReadingFieldDataType.number,
//         isMandatory: true,
//         frequency: ReadingFrequency.hourly,
//         minRange: 0.00,
//         maxRange: 1000.00,
//       ),
//       ReadingField(
//         name: 'Voltage',
//         unit: 'kV',
//         dataType: ReadingFieldDataType.number,
//         isMandatory: true,
//         frequency: ReadingFrequency.hourly,
//         minRange: 10.00,
//         maxRange: 1000.00,
//       ),
//       ReadingField(
//         name: 'Apparent Power (MVAR)',
//         unit: 'MVAR',
//         dataType: ReadingFieldDataType.number,
//         isMandatory: true,
//         frequency: ReadingFrequency.hourly,
//         minRange: 0.00,
//         maxRange: 1000.00,
//       ),
//       ReadingField(
//         name: 'Gas Pressure (SF6)',
//         unit: 'kg/cm2',
//         dataType: ReadingFieldDataType.number,
//         isMandatory: false,
//         frequency: ReadingFrequency.hourly,
//         minRange: 4.0,
//         maxRange: 10.0,
//       ),
//     ],
//     'Capacitor Bank': [
//       ReadingField(
//         name: 'Current',
//         unit: 'A',
//         dataType: ReadingFieldDataType.number,
//         isMandatory: true,
//         frequency: ReadingFrequency.hourly,
//         minRange: 0.00,
//         maxRange: 2000.00,
//       ),
//       ReadingField(
//         name: 'Power Factor',
//         unit: '',
//         dataType: ReadingFieldDataType.number,
//         isMandatory: true,
//         frequency: ReadingFrequency.hourly,
//         minRange: -1.00,
//         maxRange: 1.0,
//       ),
//     ],
//     'Battery': [
//       ReadingField(
//         name: 'Voltage',
//         unit: 'V',
//         dataType: ReadingFieldDataType.number,
//         isMandatory: true,
//         frequency: ReadingFrequency.hourly,
//         minRange: 80.00,
//         maxRange: 150.00,
//       ),
//       ReadingField(
//         name: 'Current',
//         unit: 'A',
//         dataType: ReadingFieldDataType.number,
//         isMandatory: true,
//         frequency: ReadingFrequency.hourly,
//         minRange: 0.00,
//         maxRange: 100.00,
//       ),
//     ],
//     'Busbar': [
//       ReadingField(
//         name: 'Voltage',
//         unit: 'kV',
//         dataType: ReadingFieldDataType.number,
//         isMandatory: true,
//         frequency: ReadingFrequency.hourly,
//         minRange: 10.00,
//         maxRange: 1000.00,
//       ),
//     ],
//   };

//   final Map<String, List<ReadingField>> _defaultDailyFields = {
//     'Battery': [
//       ReadingField(
//         name: 'Positive to Earth Voltage',
//         unit: 'V',
//         dataType: ReadingFieldDataType.number,
//         isMandatory: true,
//         frequency: ReadingFrequency.daily,
//         minRange: -300.00,
//         maxRange: 300.00,
//       ),
//       ReadingField(
//         name: 'Negative to Earth Voltage',
//         unit: 'V',
//         dataType: ReadingFieldDataType.number,
//         isMandatory: true,
//         frequency: ReadingFrequency.daily,
//         minRange: -300.00,
//         maxRange: 300.00,
//       ),
//       ReadingField(
//         name: 'Positive to Negative Voltage',
//         unit: 'V',
//         dataType: ReadingFieldDataType.number,
//         isMandatory: true,
//         frequency: ReadingFrequency.daily,
//         minRange: -300.00,
//         maxRange: 300.00,
//       ),
//       ...List.generate(
//         8,
//         (i) => ReadingField(
//           name: 'Cell ${i + 1}',
//           dataType: ReadingFieldDataType.group,
//           isMandatory: true,
//           frequency: ReadingFrequency.daily,
//           nestedFields: [
//             ReadingField(
//               name: 'Cell Number',
//               dataType: ReadingFieldDataType.number,
//               isMandatory: true,
//               minRange: 1.0,
//               maxRange: 8.0,
//               isInteger: true, // 🔥 Cell numbers are integers
//             ),
//             ReadingField(
//               name: 'Voltage',
//               unit: 'V',
//               dataType: ReadingFieldDataType.number,
//               isMandatory: true,
//               minRange: 1.8,
//               maxRange: 2.4,
//             ),
//             ReadingField(
//               name: 'Specific Gravity',
//               unit: '',
//               dataType: ReadingFieldDataType.number,
//               isMandatory: true,
//               minRange: 1000,
//               maxRange: 1300,
//             ),
//           ],
//         ),
//       ),
//     ],
//   };

//   Timer? _debounce;

//   @override
//   void initState() {
//     super.initState();
//     _animationController = AnimationController(
//       vsync: this,
//       duration: const Duration(milliseconds: 300),
//     );
//     _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
//       CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
//     );
//     _fetchReadingTemplates();
//   }

//   @override
//   void dispose() {
//     _debounce?.cancel();
//     _animationController.dispose();
//     super.dispose();
//   }

//   Future<void> _fetchReadingTemplates() async {
//     setState(() => _isLoading = true);
//     try {
//       final snapshot = await FirebaseFirestore.instance
//           .collection('readingTemplates')
//           .orderBy('bayType')
//           .get();
//       _templates = snapshot.docs
//           .map((doc) => ReadingTemplate.fromFirestore(doc))
//           .toList();
//       _animationController.forward();
//     } catch (e) {
//       if (mounted) {
//         SnackBarUtils.showSnackBar(
//           context,
//           'Failed to load reading templates: $e',
//           isError: true,
//         );
//       }
//     } finally {
//       if (mounted) setState(() => _isLoading = false);
//     }
//   }

//   void _showListView() {
//     setState(() {
//       _viewMode = ReadingTemplateViewMode.list;
//       _templateToEdit = null;
//       _selectedBayType = null;
//       _templateDescription = null;
//       _templateReadingFields = [];
//     });
//     _fetchReadingTemplates();
//   }

//   void _showFormForNew() {
//     setState(() {
//       _viewMode = ReadingTemplateViewMode.form;
//       _templateToEdit = null;
//       _selectedBayType = null;
//       _templateDescription = null;
//       _templateReadingFields = [];
//     });
//   }

//   void _showFormForEdit(ReadingTemplate template) {
//     setState(() {
//       _viewMode = ReadingTemplateViewMode.form;
//       _templateToEdit = template;
//       _selectedBayType = template.bayType;
//       _templateDescription = template.description;
//       _templateReadingFields = template.readingFields
//           .map(
//             (field) =>
//                 field.toMap()..['isDefault'] = _isDefaultField(field.name),
//           )
//           .toList();
//     });
//   }

//   bool _isDefaultField(String fieldName) {
//     // List of energy fields that should remain read-only (not editable)
//     final List<String> energyFieldsToKeepReadOnly = [
//       'Previous Day Reading (Import)',
//       'Current Day Reading (Import)',
//       'Previous Day Reading (Export)',
//       'Current Day Reading (Export)',
//       'Previous Month Reading (Import)',
//       'Current Month Reading (Import)',
//       'Previous Month Reading (Export)',
//       'Current Month Reading (Export)',
//     ];

//     // Only these specific energy fields should be treated as default (read-only)
//     if (energyFieldsToKeepReadOnly.contains(fieldName)) {
//       return true; // Keep these as read-only
//     }

//     // All other fields (including other default fields) should be editable
//     return false;
//   }

//   void _onBayTypeSelected(String? newBayType) {
//     setState(() {
//       _selectedBayType = newBayType;

//       // Clear all fields first, then add the appropriate defaults
//       _templateReadingFields.clear();

//       if (newBayType != null) {
//         List<ReadingField> defaultFields = [];

//         // Add energy fields for non-Battery and non-Busbar types
//         if (newBayType != 'Battery' && newBayType != 'Busbar') {
//           defaultFields.addAll(_defaultEnergyFields);
//         }

//         // Add type-specific default fields
//         defaultFields.addAll(_defaultHourlyFields[newBayType] ?? []);
//         defaultFields.addAll(_defaultDailyFields[newBayType] ?? []);

//         // Convert to maps and mark with isDefault flag
//         for (var field in defaultFields) {
//           final fieldMap = field.toMap();
//           fieldMap['isDefault'] = _isDefaultField(field.name);
//           _templateReadingFields.add(fieldMap);
//         }

//         // Debug prints to verify
//         print(
//           'DEBUG: Added ${_templateReadingFields.length} fields for $newBayType',
//         );
//         for (var field in _templateReadingFields) {
//           print('  - ${field['name']} (default: ${field['isDefault']})');
//         }
//       }
//     });
//   }

//   void _addReadingField() {
//     setState(() {
//       _templateReadingFields.add({
//         'name': '',
//         'dataType': ReadingFieldDataType.text.toString().split('.').last,
//         'unit': '',
//         'options': [],
//         'isMandatory': false,
//         'frequency': ReadingFrequency.daily.toString().split('.').last,
//         'description_remarks': '',
//         'isDefault': false,
//         'nestedFields': null,
//         'minRange': null,
//         'maxRange': null,
//         'isInteger': false, // 🔥 Add isInteger flag
//       });
//     });
//   }

//   void _addGroupReadingField() {
//     setState(() {
//       _templateReadingFields.add({
//         'name': '',
//         'dataType': ReadingFieldDataType.group.toString().split('.').last,
//         'unit': '',
//         'options': [],
//         'isMandatory': false,
//         'frequency': ReadingFrequency.daily.toString().split('.').last,
//         'description_remarks': '',
//         'isDefault': false,
//         'nestedFields': <Map<String, dynamic>>[],
//         'minRange': null,
//         'maxRange': null,
//         'isInteger': false, // 🔥 Add isInteger flag
//       });
//     });
//   }

//   void _addNestedReadingField(Map<String, dynamic> groupField) {
//     setState(() {
//       (groupField['nestedFields'] as List<dynamic>).add({
//         'name': '',
//         'dataType': ReadingFieldDataType.text.toString().split('.').last,
//         'unit': '',
//         'options': [],
//         'isMandatory': false,
//         'description_remarks': '',
//         'minRange': null,
//         'maxRange': null,
//         'isInteger': false, // 🔥 Add isInteger flag
//       });
//     });
//   }

//   void _removeReadingField(int index) {
//     setState(() {
//       _templateReadingFields.removeAt(index);
//     });
//   }

//   void _removeNestedReadingField(
//     Map<String, dynamic> groupField,
//     int nestedIndex,
//   ) {
//     setState(() {
//       (groupField['nestedFields'] as List<dynamic>).removeAt(nestedIndex);
//     });
//   }

//   Future<void> _saveTemplate() async {
//     if (!_formKey.currentState!.validate()) return;
//     if (_selectedBayType == null) {
//       SnackBarUtils.showSnackBar(
//         context,
//         'Please select a Bay Type.',
//         isError: true,
//       );
//       return;
//     }

//     setState(() => _isSaving = true);
//     final currentUser = FirebaseAuth.instance.currentUser;
//     if (currentUser == null) {
//       if (mounted) {
//         SnackBarUtils.showSnackBar(
//           context,
//           'Error: User not logged in.',
//           isError: true,
//         );
//       }
//       setState(() => _isSaving = false);
//       return;
//     }

//     try {
//       final List<ReadingField> readingFields = _templateReadingFields
//           .map((fieldMap) => ReadingField.fromMap(fieldMap))
//           .toList();

//       final newTemplate = ReadingTemplate(
//         id: _templateToEdit?.id,
//         bayType: _selectedBayType!,
//         readingFields: readingFields,
//         createdBy: currentUser.uid,
//         createdAt: _templateToEdit?.createdAt ?? Timestamp.now(),
//         description: _templateDescription,
//         isActive: true,
//       );

//       if (_templateToEdit == null) {
//         await FirebaseFirestore.instance
//             .collection('readingTemplates')
//             .add(newTemplate.toFirestore());
//         if (mounted) {
//           SnackBarUtils.showSnackBar(
//             context,
//             'Reading template created successfully!',
//           );
//         }
//       } else {
//         final updatedTemplate = newTemplate.withUpdatedTimestamp();
//         await FirebaseFirestore.instance
//             .collection('readingTemplates')
//             .doc(_templateToEdit!.id)
//             .update(updatedTemplate.toFirestore());
//         if (mounted) {
//           SnackBarUtils.showSnackBar(
//             context,
//             'Reading template updated successfully!',
//           );
//         }
//       }
//       _showListView();
//     } catch (e) {
//       if (mounted) {
//         SnackBarUtils.showSnackBar(
//           context,
//           'Failed to save template: $e',
//           isError: true,
//         );
//       }
//     } finally {
//       if (mounted) setState(() => _isSaving = false);
//     }
//   }

//   Future<void> _deleteTemplate(String? templateId) async {
//     if (templateId == null) return;
//     final bool confirm =
//         await showDialog(
//           context: context,
//           builder: (BuildContext context) {
//             final theme = Theme.of(context);
//             final isDarkMode = theme.brightness == Brightness.dark;
//             return AlertDialog(
//               backgroundColor: isDarkMode
//                   ? const Color(0xFF1C1C1E)
//                   : Colors.white,
//               shape: RoundedRectangleBorder(
//                 borderRadius: BorderRadius.circular(12),
//               ),
//               title: Row(
//                 children: [
//                   Icon(Icons.warning_amber, color: theme.colorScheme.error),
//                   const SizedBox(width: 8),
//                   Text(
//                     'Confirm Deletion',
//                     style: TextStyle(color: isDarkMode ? Colors.white : null),
//                   ),
//                 ],
//               ),
//               content: Text(
//                 'Are you sure you want to delete this reading template? This action cannot be undone and may affect existing bay assignments.',
//                 style: TextStyle(color: isDarkMode ? Colors.white : null),
//               ),
//               actions: <Widget>[
//                 TextButton(
//                   onPressed: () => Navigator.of(context).pop(false),
//                   child: Text(
//                     'Cancel',
//                     style: TextStyle(color: isDarkMode ? Colors.white70 : null),
//                   ),
//                 ),
//                 ElevatedButton(
//                   onPressed: () => Navigator.of(context).pop(true),
//                   style: ElevatedButton.styleFrom(
//                     backgroundColor: theme.colorScheme.error,
//                     foregroundColor: Colors.white,
//                     shape: RoundedRectangleBorder(
//                       borderRadius: BorderRadius.circular(8),
//                     ),
//                   ),
//                   child: const Text('Delete'),
//                 ),
//               ],
//             );
//           },
//         ) ??
//         false;

//     if (confirm) {
//       try {
//         await FirebaseFirestore.instance
//             .collection('readingTemplates')
//             .doc(templateId)
//             .delete();
//         if (mounted) {
//           SnackBarUtils.showSnackBar(
//             context,
//             'Reading template deleted successfully!',
//           );
//         }
//         _fetchReadingTemplates();
//       } catch (e) {
//         if (mounted) {
//           SnackBarUtils.showSnackBar(
//             context,
//             'Failed to delete template: $e',
//             isError: true,
//           );
//         }
//       }
//     }
//   }

//   void _debouncedUpdate(VoidCallback callback) {
//     if (_debounce?.isActive ?? false) _debounce!.cancel();
//     _debounce = Timer(const Duration(milliseconds: 300), () {
//       if (mounted) setState(callback);
//     });
//   }

//   Color _getBayTypeColor(String bayType) {
//     switch (bayType.toLowerCase()) {
//       case 'transformer':
//         return Colors.orange;
//       case 'line':
//         return Colors.blue;
//       case 'feeder':
//         return Colors.green;
//       case 'capacitor bank':
//         return Colors.purple;
//       case 'reactor':
//         return Colors.red;
//       case 'bus coupler':
//         return Colors.teal;
//       case 'battery':
//         return Colors.amber;
//       case 'busbar':
//         return Colors.indigo;
//       default:
//         return Colors.grey;
//     }
//   }

//   IconData _getBayTypeIcon(String bayType) {
//     switch (bayType.toLowerCase()) {
//       case 'transformer':
//         return Icons.electrical_services;
//       case 'line':
//         return Icons.power_input;
//       case 'feeder':
//         return Icons.power;
//       case 'capacitor bank':
//         return Icons.battery_charging_full;
//       case 'reactor':
//         return Icons.device_hub;
//       case 'bus coupler':
//         return Icons.power_settings_new;
//       case 'battery':
//         return Icons.battery_std;
//       case 'busbar':
//         return Icons.horizontal_rule;
//       default:
//         return Icons.electrical_services;
//     }
//   }

//   Color _getFrequencyColor(String frequency) {
//     switch (frequency.toLowerCase()) {
//       case 'hourly':
//         return Colors.red;
//       case 'daily':
//         return Colors.blue;
//       default:
//         return Colors.grey;
//     }
//   }

//   Color _getDataTypeColor(String dataType) {
//     switch (dataType.toLowerCase()) {
//       case 'text':
//         return Colors.blue;
//       case 'number':
//         return Colors.green;
//       case 'boolean':
//         return Colors.orange;
//       case 'date':
//         return Colors.purple;
//       case 'dropdown':
//         return Colors.teal;
//       case 'group':
//         return Colors.deepPurple;
//       default:
//         return Colors.grey;
//     }
//   }

//   IconData _getDataTypeIcon(String dataType) {
//     switch (dataType.toLowerCase()) {
//       case 'text':
//         return Icons.text_fields;
//       case 'number':
//         return Icons.numbers;
//       case 'boolean':
//         return Icons.toggle_on;
//       case 'date':
//         return Icons.calendar_today;
//       case 'dropdown':
//         return Icons.arrow_drop_down_circle;
//       case 'group':
//         return Icons.group_work;
//       default:
//         return Icons.help;
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     final theme = Theme.of(context);
//     final isDarkMode = theme.brightness == Brightness.dark;

//     if (_isLoading) {
//       return Scaffold(
//         backgroundColor: isDarkMode
//             ? const Color(0xFF1C1C1E)
//             : const Color(0xFFF8F9FA),
//         body: Center(
//           child: Column(
//             mainAxisAlignment: MainAxisAlignment.center,
//             children: [
//               SizedBox(
//                 width: 60,
//                 height: 60,
//                 child: CircularProgressIndicator(
//                   strokeWidth: 4,
//                   valueColor: AlwaysStoppedAnimation(theme.colorScheme.primary),
//                 ),
//               ),
//               const SizedBox(height: 24),
//               Text(
//                 'Loading templates...',
//                 style: TextStyle(
//                   fontSize: 16,
//                   fontWeight: FontWeight.w500,
//                   color: isDarkMode
//                       ? Colors.white.withOpacity(0.7)
//                       : theme.colorScheme.onSurface.withOpacity(0.7),
//                 ),
//               ),
//             ],
//           ),
//         ),
//       );
//     }

//     return Scaffold(
//       backgroundColor: isDarkMode
//           ? const Color(0xFF1C1C1E)
//           : const Color(0xFFF8F9FA),
//       appBar: AppBar(
//         backgroundColor: isDarkMode ? const Color(0xFF1C1C1E) : Colors.white,
//         elevation: 0,
//         toolbarHeight: 60,
//         title: Text(
//           _viewMode == ReadingTemplateViewMode.list
//               ? 'Reading Templates'
//               : (_templateToEdit == null
//                     ? 'Create New Template'
//                     : 'Edit Template'),
//           style: TextStyle(
//             color: isDarkMode ? Colors.white : theme.colorScheme.onSurface,
//             fontSize: 20,
//             fontWeight: FontWeight.w600,
//           ),
//         ),
//         leading: _viewMode == ReadingTemplateViewMode.form
//             ? IconButton(
//                 icon: Icon(
//                   Icons.arrow_back_ios,
//                   color: isDarkMode
//                       ? Colors.white
//                       : theme.colorScheme.onSurface,
//                 ),
//                 onPressed: _showListView,
//               )
//             : IconButton(
//                 icon: Icon(
//                   Icons.arrow_back_ios,
//                   color: isDarkMode
//                       ? Colors.white
//                       : theme.colorScheme.onSurface,
//                 ),
//                 onPressed: () => Navigator.pop(context),
//               ),
//       ),
//       body: AnimatedSwitcher(
//         duration: const Duration(milliseconds: 300),
//         child: _viewMode == ReadingTemplateViewMode.list
//             ? _buildListView(theme, isDarkMode)
//             : _buildFormView(theme, isDarkMode),
//       ),
//       floatingActionButton: _viewMode == ReadingTemplateViewMode.list
//           ? FloatingActionButton.extended(
//               onPressed: _showFormForNew,
//               backgroundColor: theme.colorScheme.primary,
//               foregroundColor: Colors.white,
//               elevation: 2,
//               icon: const Icon(Icons.add),
//               label: const Text(
//                 'New Template',
//                 style: TextStyle(fontWeight: FontWeight.w600),
//               ),
//               shape: RoundedRectangleBorder(
//                 borderRadius: BorderRadius.circular(12),
//               ),
//             )
//           : null,
//     );
//   }

//   Widget _buildListView(ThemeData theme, bool isDarkMode) {
//     return FadeTransition(
//       opacity: _fadeAnimation,
//       child: _templates.isEmpty
//           ? Center(
//               child: Container(
//                 margin: const EdgeInsets.all(32),
//                 padding: const EdgeInsets.all(32),
//                 decoration: BoxDecoration(
//                   color: isDarkMode ? const Color(0xFF2C2C2E) : Colors.white,
//                   borderRadius: BorderRadius.circular(16),
//                   boxShadow: [
//                     BoxShadow(
//                       color: isDarkMode
//                           ? Colors.black.withOpacity(0.3)
//                           : Colors.black.withOpacity(0.05),
//                       blurRadius: 16,
//                       offset: const Offset(0, 4),
//                     ),
//                   ],
//                 ),
//                 child: Column(
//                   mainAxisSize: MainAxisSize.min,
//                   children: [
//                     Icon(
//                       Icons.rule_outlined,
//                       size: 80,
//                       color: isDarkMode
//                           ? Colors.white.withOpacity(0.4)
//                           : Colors.grey.shade400,
//                     ),
//                     const SizedBox(height: 24),
//                     Text(
//                       'No Reading Templates',
//                       style: TextStyle(
//                         fontSize: 20,
//                         fontWeight: FontWeight.w600,
//                         color: isDarkMode
//                             ? Colors.white
//                             : theme.colorScheme.onSurface,
//                       ),
//                     ),
//                     const SizedBox(height: 8),
//                     Text(
//                       'Create templates to define reading parameters\nfor different bay types',
//                       textAlign: TextAlign.center,
//                       style: TextStyle(
//                         fontSize: 14,
//                         color: isDarkMode
//                             ? Colors.white.withOpacity(0.6)
//                             : Colors.grey.shade600,
//                       ),
//                     ),
//                     const SizedBox(height: 32),
//                     ElevatedButton.icon(
//                       onPressed: _showFormForNew,
//                       icon: const Icon(Icons.add),
//                       label: const Text('Create First Template'),
//                       style: ElevatedButton.styleFrom(
//                         backgroundColor: theme.colorScheme.primary,
//                         foregroundColor: Colors.white,
//                         padding: const EdgeInsets.symmetric(
//                           horizontal: 24,
//                           vertical: 12,
//                         ),
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//             )
//           : SingleChildScrollView(
//               padding: const EdgeInsets.all(16),
//               child: Column(
//                 children: _templates.map((template) {
//                   return Container(
//                     margin: const EdgeInsets.only(bottom: 12),
//                     decoration: BoxDecoration(
//                       color: isDarkMode
//                           ? const Color(0xFF2C2C2E)
//                           : Colors.white,
//                       borderRadius: BorderRadius.circular(12),
//                       boxShadow: [
//                         BoxShadow(
//                           color: isDarkMode
//                               ? Colors.black.withOpacity(0.3)
//                               : Colors.black.withOpacity(0.05),
//                           blurRadius: 8,
//                           offset: const Offset(0, 2),
//                         ),
//                       ],
//                     ),
//                     child: ListTile(
//                       contentPadding: const EdgeInsets.all(16),
//                       leading: Container(
//                         width: 48,
//                         height: 48,
//                         decoration: BoxDecoration(
//                           color: _getBayTypeColor(
//                             template.bayType,
//                           ).withOpacity(0.1),
//                           borderRadius: BorderRadius.circular(8),
//                         ),
//                         child: Icon(
//                           _getBayTypeIcon(template.bayType),
//                           color: _getBayTypeColor(template.bayType),
//                           size: 24,
//                         ),
//                       ),
//                       title: Text(
//                         template.bayType,
//                         style: TextStyle(
//                           fontSize: 16,
//                           fontWeight: FontWeight.w600,
//                           color: isDarkMode
//                               ? Colors.white
//                               : theme.colorScheme.onSurface,
//                         ),
//                       ),
//                       subtitle: Column(
//                         crossAxisAlignment: CrossAxisAlignment.start,
//                         children: [
//                           const SizedBox(height: 4),
//                           Text(
//                             '${template.totalFieldCount} fields • Created ${DateFormat('MMM dd, yyyy').format(template.createdAt.toDate())}',
//                             style: TextStyle(
//                               fontSize: 13,
//                               color: isDarkMode
//                                   ? Colors.white.withOpacity(0.6)
//                                   : Colors.grey.shade600,
//                             ),
//                           ),
//                           if (template.description != null &&
//                               template.description!.isNotEmpty) ...[
//                             const SizedBox(height: 4),
//                             Text(
//                               template.description!,
//                               style: TextStyle(
//                                 fontSize: 12,
//                                 color: isDarkMode
//                                     ? Colors.white.withOpacity(0.5)
//                                     : Colors.grey.shade500,
//                                 fontStyle: FontStyle.italic,
//                               ),
//                               maxLines: 1,
//                               overflow: TextOverflow.ellipsis,
//                             ),
//                           ],
//                           const SizedBox(height: 8),
//                           Wrap(
//                             spacing: 6,
//                             runSpacing: 4,
//                             children: _frequencies.map((freq) {
//                               final count = template.readingFields
//                                   .where(
//                                     (field) =>
//                                         field.frequency
//                                             .toString()
//                                             .split('.')
//                                             .last ==
//                                         freq,
//                                   )
//                                   .length;
//                               if (count == 0) return const SizedBox.shrink();
//                               return Container(
//                                 padding: const EdgeInsets.symmetric(
//                                   horizontal: 6,
//                                   vertical: 2,
//                                 ),
//                                 decoration: BoxDecoration(
//                                   color: _getFrequencyColor(
//                                     freq,
//                                   ).withOpacity(0.1),
//                                   borderRadius: BorderRadius.circular(4),
//                                   border: Border.all(
//                                     color: _getFrequencyColor(
//                                       freq,
//                                     ).withOpacity(0.3),
//                                   ),
//                                 ),
//                                 child: Text(
//                                   '$freq: $count',
//                                   style: TextStyle(
//                                     fontSize: 10,
//                                     color: _getFrequencyColor(freq),
//                                     fontWeight: FontWeight.w600,
//                                   ),
//                                 ),
//                               );
//                             }).toList(),
//                           ),
//                         ],
//                       ),
//                       trailing: PopupMenuButton<String>(
//                         icon: Icon(
//                           Icons.more_vert,
//                           color: isDarkMode
//                               ? Colors.white.withOpacity(0.7)
//                               : Colors.grey.shade600,
//                         ),
//                         color: isDarkMode
//                             ? const Color(0xFF2C2C2E)
//                             : Colors.white,
//                         onSelected: (String result) {
//                           if (result == 'edit') {
//                             _showFormForEdit(template);
//                           } else if (result == 'delete') {
//                             _deleteTemplate(template.id);
//                           }
//                         },
//                         itemBuilder: (BuildContext context) => [
//                           PopupMenuItem<String>(
//                             value: 'edit',
//                             child: ListTile(
//                               leading: Icon(
//                                 Icons.edit_outlined,
//                                 size: 16,
//                                 color: theme.colorScheme.primary,
//                               ),
//                               title: Text(
//                                 'Edit',
//                                 style: TextStyle(
//                                   color: isDarkMode ? Colors.white : null,
//                                 ),
//                               ),
//                               dense: true,
//                             ),
//                           ),
//                           PopupMenuItem<String>(
//                             value: 'delete',
//                             child: ListTile(
//                               leading: Icon(
//                                 Icons.delete_outline,
//                                 size: 16,
//                                 color: theme.colorScheme.error,
//                               ),
//                               title: Text(
//                                 'Delete',
//                                 style: TextStyle(
//                                   color: theme.colorScheme.error,
//                                 ),
//                               ),
//                               dense: true,
//                             ),
//                           ),
//                         ],
//                       ),
//                     ),
//                   );
//                 }).toList(),
//               ),
//             ),
//     );
//   }

//   Widget _buildFormView(ThemeData theme, bool isDarkMode) {
//     return SingleChildScrollView(
//       child: Column(
//         children: [
//           _buildBasicInfoSection(theme, isDarkMode),
//           const SizedBox(height: 16),
//           _buildBayTypeSection(theme, isDarkMode),
//           const SizedBox(height: 16),
//           _buildReadingFieldsSection(theme, isDarkMode),
//           const SizedBox(height: 16),
//           _buildActionButtons(theme, isDarkMode),
//           const SizedBox(height: 80),
//         ],
//       ),
//     );
//   }

//   Widget _buildBasicInfoSection(ThemeData theme, bool isDarkMode) {
//     return Container(
//       margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
//       padding: const EdgeInsets.all(16),
//       decoration: BoxDecoration(
//         color: isDarkMode ? const Color(0xFF2C2C2E) : Colors.white,
//         borderRadius: BorderRadius.circular(12),
//         boxShadow: [
//           BoxShadow(
//             color: isDarkMode
//                 ? Colors.black.withOpacity(0.3)
//                 : Colors.black.withOpacity(0.05),
//             blurRadius: 8,
//             offset: const Offset(0, 2),
//           ),
//         ],
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Row(
//             children: [
//               Container(
//                 width: 32,
//                 height: 32,
//                 decoration: BoxDecoration(
//                   color: Colors.blue.withOpacity(0.1),
//                   borderRadius: BorderRadius.circular(8),
//                 ),
//                 child: const Icon(
//                   Icons.info_outline,
//                   color: Colors.blue,
//                   size: 16,
//                 ),
//               ),
//               const SizedBox(width: 12),
//               Text(
//                 'Template Information',
//                 style: TextStyle(
//                   fontSize: 18,
//                   fontWeight: FontWeight.w600,
//                   color: isDarkMode
//                       ? Colors.white
//                       : theme.colorScheme.onSurface,
//                 ),
//               ),
//             ],
//           ),
//           const SizedBox(height: 16),
//           TextFormField(
//             initialValue: _templateDescription,
//             decoration: InputDecoration(
//               labelText: 'Description (Optional)',
//               hintText: 'Describe the purpose of this template',
//               prefixIcon: Icon(
//                 Icons.description,
//                 color: theme.colorScheme.primary,
//                 size: 20,
//               ),
//               border: OutlineInputBorder(
//                 borderRadius: BorderRadius.circular(8),
//               ),
//               filled: true,
//               fillColor: isDarkMode
//                   ? const Color(0xFF3C3C3E)
//                   : Colors.grey.shade50,
//             ),
//             style: TextStyle(
//               color: isDarkMode ? Colors.white : theme.colorScheme.onSurface,
//             ),
//             maxLines: 2,
//             onChanged: (value) =>
//                 _templateDescription = value.isEmpty ? null : value,
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildBayTypeSection(ThemeData theme, bool isDarkMode) {
//     return Container(
//       margin: const EdgeInsets.symmetric(horizontal: 16),
//       padding: const EdgeInsets.all(16),
//       decoration: BoxDecoration(
//         color: isDarkMode ? const Color(0xFF2C2C2E) : Colors.white,
//         borderRadius: BorderRadius.circular(12),
//         boxShadow: [
//           BoxShadow(
//             color: isDarkMode
//                 ? Colors.black.withOpacity(0.3)
//                 : Colors.black.withOpacity(0.05),
//             blurRadius: 8,
//             offset: const Offset(0, 2),
//           ),
//         ],
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Row(
//             children: [
//               Container(
//                 width: 32,
//                 height: 32,
//                 decoration: BoxDecoration(
//                   color: Colors.green.withOpacity(0.1),
//                   borderRadius: BorderRadius.circular(8),
//                 ),
//                 child: const Icon(
//                   Icons.category,
//                   color: Colors.green,
//                   size: 16,
//                 ),
//               ),
//               const SizedBox(width: 12),
//               Text(
//                 'Bay Type Configuration',
//                 style: TextStyle(
//                   fontSize: 18,
//                   fontWeight: FontWeight.w600,
//                   color: isDarkMode
//                       ? Colors.white
//                       : theme.colorScheme.onSurface,
//                 ),
//               ),
//             ],
//           ),
//           const SizedBox(height: 16),
//           DropdownButtonFormField<String>(
//             value: _selectedBayType,
//             decoration: InputDecoration(
//               labelText: 'Select Bay Type *',
//               prefixIcon: Icon(
//                 Icons.electrical_services,
//                 color: theme.colorScheme.primary,
//                 size: 20,
//               ),
//               border: OutlineInputBorder(
//                 borderRadius: BorderRadius.circular(8),
//               ),
//               filled: true,
//               fillColor: isDarkMode
//                   ? const Color(0xFF3C3C3E)
//                   : Colors.grey.shade50,
//             ),
//             dropdownColor: isDarkMode ? const Color(0xFF2C2C2E) : Colors.white,
//             items: _bayTypes
//                 .map(
//                   (String type) => DropdownMenuItem<String>(
//                     value: type,
//                     child: Row(
//                       children: [
//                         Container(
//                           width: 24,
//                           height: 24,
//                           decoration: BoxDecoration(
//                             color: _getBayTypeColor(type).withOpacity(0.15),
//                             borderRadius: BorderRadius.circular(4),
//                           ),
//                           child: Icon(
//                             _getBayTypeIcon(type),
//                             color: _getBayTypeColor(type),
//                             size: 14,
//                           ),
//                         ),
//                         const SizedBox(width: 12),
//                         Text(
//                           type,
//                           style: TextStyle(
//                             color: isDarkMode
//                                 ? Colors.white
//                                 : theme.colorScheme.onSurface,
//                           ),
//                         ),
//                       ],
//                     ),
//                   ),
//                 )
//                 .toList(),
//             onChanged: _onBayTypeSelected,
//             validator: (value) =>
//                 value == null ? 'Please select a bay type' : null,
//             style: TextStyle(
//               color: isDarkMode ? Colors.white : theme.colorScheme.onSurface,
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildReadingFieldsSection(ThemeData theme, bool isDarkMode) {
//     return Container(
//       margin: const EdgeInsets.symmetric(horizontal: 16),
//       padding: const EdgeInsets.all(16),
//       decoration: BoxDecoration(
//         color: isDarkMode ? const Color(0xFF2C2C2E) : Colors.white,
//         borderRadius: BorderRadius.circular(12),
//         boxShadow: [
//           BoxShadow(
//             color: isDarkMode
//                 ? Colors.black.withOpacity(0.3)
//                 : Colors.black.withOpacity(0.05),
//             blurRadius: 8,
//             offset: const Offset(0, 2),
//           ),
//         ],
//       ),
//       child: Form(
//         key: _formKey,
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Row(
//               children: [
//                 Container(
//                   width: 32,
//                   height: 32,
//                   decoration: BoxDecoration(
//                     color: Colors.purple.withOpacity(0.1),
//                     borderRadius: BorderRadius.circular(8),
//                   ),
//                   child: const Icon(
//                     Icons.list_alt,
//                     color: Colors.purple,
//                     size: 16,
//                   ),
//                 ),
//                 const SizedBox(width: 12),
//                 Expanded(
//                   child: Text(
//                     'Reading Fields',
//                     style: TextStyle(
//                       fontSize: 18,
//                       fontWeight: FontWeight.w600,
//                       color: isDarkMode
//                           ? Colors.white
//                           : theme.colorScheme.onSurface,
//                     ),
//                   ),
//                 ),
//                 if (_templateReadingFields.isNotEmpty)
//                   Container(
//                     padding: const EdgeInsets.symmetric(
//                       horizontal: 8,
//                       vertical: 4,
//                     ),
//                     decoration: BoxDecoration(
//                       color: theme.colorScheme.primary.withOpacity(0.1),
//                       borderRadius: BorderRadius.circular(6),
//                     ),
//                     child: Text(
//                       '${_templateReadingFields.length}',
//                       style: TextStyle(
//                         fontSize: 12,
//                         fontWeight: FontWeight.w600,
//                         color: theme.colorScheme.primary,
//                       ),
//                     ),
//                   ),
//               ],
//             ),
//             const SizedBox(height: 16),
//             if (_templateReadingFields.isEmpty)
//               Container(
//                 padding: const EdgeInsets.all(24),
//                 decoration: BoxDecoration(
//                   color: isDarkMode
//                       ? const Color(0xFF3C3C3E)
//                       : Colors.grey.shade50,
//                   borderRadius: BorderRadius.circular(8),
//                   border: Border.all(
//                     color: isDarkMode
//                         ? Colors.white.withOpacity(0.1)
//                         : Colors.grey.shade200,
//                   ),
//                 ),
//                 child: Column(
//                   children: [
//                     Icon(
//                       Icons.inbox_outlined,
//                       size: 48,
//                       color: isDarkMode
//                           ? Colors.white.withOpacity(0.4)
//                           : Colors.grey.shade400,
//                     ),
//                     const SizedBox(height: 16),
//                     Text(
//                       'No Fields Configured',
//                       style: TextStyle(
//                         fontSize: 16,
//                         fontWeight: FontWeight.w600,
//                         color: isDarkMode
//                             ? Colors.white.withOpacity(0.6)
//                             : Colors.grey.shade600,
//                       ),
//                     ),
//                     const SizedBox(height: 8),
//                     Text(
//                       'Select a bay type to see default fields or add custom ones',
//                       style: TextStyle(
//                         fontSize: 14,
//                         color: isDarkMode
//                             ? Colors.white.withOpacity(0.5)
//                             : Colors.grey.shade500,
//                       ),
//                       textAlign: TextAlign.center,
//                     ),
//                   ],
//                 ),
//               )
//             else
//               Column(
//                 children: _templateReadingFields.asMap().entries.map((entry) {
//                   final index = entry.key;
//                   final field = entry.value;
//                   final bool isDefault = field['isDefault'] ?? false;
//                   return Container(
//                     margin: const EdgeInsets.only(bottom: 12),
//                     child: _buildReadingFieldCard(
//                       field,
//                       index,
//                       theme,
//                       isDarkMode,
//                       isDefault,
//                     ),
//                   );
//                 }).toList(),
//               ),
//             const SizedBox(height: 16),
//             Row(
//               children: [
//                 Expanded(
//                   child: ElevatedButton.icon(
//                     onPressed: _addReadingField,
//                     icon: const Icon(Icons.add, size: 18),
//                     label: const Text('Add Field'),
//                     style: ElevatedButton.styleFrom(
//                       backgroundColor: theme.colorScheme.primary,
//                       foregroundColor: Colors.white,
//                       padding: const EdgeInsets.symmetric(vertical: 12),
//                       shape: RoundedRectangleBorder(
//                         borderRadius: BorderRadius.circular(8),
//                       ),
//                     ),
//                   ),
//                 ),
//                 const SizedBox(width: 12),
//                 Expanded(
//                   child: ElevatedButton.icon(
//                     onPressed: _addGroupReadingField,
//                     icon: const Icon(Icons.group_work, size: 18),
//                     label: const Text('Group Field'),
//                     style: ElevatedButton.styleFrom(
//                       backgroundColor: theme.colorScheme.secondary,
//                       foregroundColor: Colors.white,
//                       padding: const EdgeInsets.symmetric(vertical: 12),
//                       shape: RoundedRectangleBorder(
//                         borderRadius: BorderRadius.circular(8),
//                       ),
//                     ),
//                   ),
//                 ),
//               ],
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _buildReadingFieldCard(
//     Map<String, dynamic> fieldDef,
//     int index,
//     ThemeData theme,
//     bool isDarkMode,
//     bool isDefault,
//   ) {
//     final String dataType = fieldDef['dataType'] as String;
//     final bool isGroupField = dataType == 'group';

//     return Container(
//       padding: const EdgeInsets.all(16),
//       decoration: BoxDecoration(
//         color: isDefault
//             ? theme.colorScheme.primary.withOpacity(0.05)
//             : (isDarkMode ? const Color(0xFF3C3C3E) : Colors.grey.shade50),
//         borderRadius: BorderRadius.circular(12),
//         border: Border.all(
//           color: isDefault
//               ? theme.colorScheme.primary.withOpacity(0.3)
//               : (isDarkMode
//                     ? Colors.white.withOpacity(0.1)
//                     : Colors.grey.shade200),
//         ),
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Row(
//             children: [
//               Container(
//                 padding: const EdgeInsets.all(6),
//                 decoration: BoxDecoration(
//                   color: _getDataTypeColor(dataType).withOpacity(0.15),
//                   borderRadius: BorderRadius.circular(6),
//                 ),
//                 child: Icon(
//                   _getDataTypeIcon(dataType),
//                   size: 16,
//                   color: _getDataTypeColor(dataType),
//                 ),
//               ),
//               const SizedBox(width: 8),
//               if (isDefault)
//                 Container(
//                   padding: const EdgeInsets.symmetric(
//                     horizontal: 6,
//                     vertical: 2,
//                   ),
//                   decoration: BoxDecoration(
//                     color: theme.colorScheme.primary.withOpacity(0.1),
//                     borderRadius: BorderRadius.circular(4),
//                   ),
//                   child: Text(
//                     'DEFAULT',
//                     style: TextStyle(
//                       fontSize: 10,
//                       fontWeight: FontWeight.w700,
//                       color: theme.colorScheme.primary,
//                     ),
//                   ),
//                 ),
//               // 🔥 Add integer badge for integer fields
//               if (fieldDef['isInteger'] == true)
//                 Container(
//                   margin: const EdgeInsets.only(left: 4),
//                   padding: const EdgeInsets.symmetric(
//                     horizontal: 6,
//                     vertical: 2,
//                   ),
//                   decoration: BoxDecoration(
//                     color: Colors.orange.withOpacity(0.1),
//                     borderRadius: BorderRadius.circular(4),
//                   ),
//                   child: Text(
//                     'INT',
//                     style: TextStyle(
//                       fontSize: 10,
//                       fontWeight: FontWeight.w700,
//                       color: Colors.orange,
//                     ),
//                   ),
//                 ),
//               const Spacer(),
//               if (!isDefault)
//                 IconButton(
//                   onPressed: () => _removeReadingField(index),
//                   icon: Icon(
//                     Icons.delete_outline,
//                     color: theme.colorScheme.error,
//                     size: 18,
//                   ),
//                   style: IconButton.styleFrom(
//                     backgroundColor: theme.colorScheme.error.withOpacity(0.1),
//                     minimumSize: const Size(32, 32),
//                     padding: EdgeInsets.zero,
//                   ),
//                 ),
//             ],
//           ),
//           const SizedBox(height: 12),
//           _buildFieldInputs(
//             fieldDef,
//             theme,
//             isDarkMode,
//             isDefault,
//             isGroupField,
//           ),
//           if (isGroupField) ...[
//             const SizedBox(height: 16),
//             _buildNestedFields(fieldDef, theme, isDarkMode),
//           ],
//         ],
//       ),
//     );
//   }

//   Widget _buildFieldInputs(
//     Map<String, dynamic> fieldDef,
//     ThemeData theme,
//     bool isDarkMode,
//     bool isDefault,
//     bool isGroupField,
//   ) {
//     return Column(
//       children: [
//         TextFormField(
//           initialValue: fieldDef['name'],
//           decoration: InputDecoration(
//             labelText: 'Field Name *',
//             prefixIcon: Icon(
//               Icons.edit,
//               color: theme.colorScheme.primary,
//               size: 18,
//             ),
//             border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
//             filled: true,
//             fillColor: isDarkMode ? const Color(0xFF2C2C2E) : Colors.white,
//             contentPadding: const EdgeInsets.symmetric(
//               horizontal: 12,
//               vertical: 12,
//             ),
//             isDense: true,
//           ),
//           style: TextStyle(
//             color: isDarkMode ? Colors.white : theme.colorScheme.onSurface,
//           ),
//           onChanged: isDefault
//               ? null
//               : (value) => _debouncedUpdate(() => fieldDef['name'] = value),
//           readOnly: isDefault,
//           validator: (value) => value == null || value.trim().isEmpty
//               ? 'Field name is required'
//               : null,
//         ),
//         const SizedBox(height: 12),
//         if (!isGroupField) ...[
//           Row(
//             children: [
//               Expanded(
//                 child: DropdownButtonFormField<String>(
//                   value: fieldDef['dataType'],
//                   decoration: InputDecoration(
//                     labelText: 'Data Type',
//                     border: OutlineInputBorder(
//                       borderRadius: BorderRadius.circular(8),
//                     ),
//                     filled: true,
//                     fillColor: isDarkMode
//                         ? const Color(0xFF2C2C2E)
//                         : Colors.white,
//                     contentPadding: const EdgeInsets.symmetric(
//                       horizontal: 12,
//                       vertical: 12,
//                     ),
//                     isDense: true,
//                   ),
//                   dropdownColor: isDarkMode
//                       ? const Color(0xFF2C2C2E)
//                       : Colors.white,
//                   items: _dataTypes
//                       .where((type) => type != 'group')
//                       .map(
//                         (type) => DropdownMenuItem(
//                           value: type,
//                           child: Row(
//                             mainAxisSize: MainAxisSize.min,
//                             children: [
//                               Icon(
//                                 _getDataTypeIcon(type),
//                                 size: 14,
//                                 color: _getDataTypeColor(type),
//                               ),
//                               const SizedBox(width: 8),
//                               Text(
//                                 type,
//                                 style: TextStyle(
//                                   color: isDarkMode
//                                       ? Colors.white
//                                       : theme.colorScheme.onSurface,
//                                 ),
//                               ),
//                             ],
//                           ),
//                         ),
//                       )
//                       .toList(),
//                   onChanged: isDefault
//                       ? null
//                       : (value) => _debouncedUpdate(() {
//                           fieldDef['dataType'] = value!;
//                           if (value != 'dropdown') fieldDef['options'] = [];
//                           if (value != 'number') {
//                             fieldDef['unit'] = '';
//                             fieldDef['minRange'] = null;
//                             fieldDef['maxRange'] = null;
//                             fieldDef['isInteger'] =
//                                 false; // 🔥 Reset integer flag
//                           }
//                           if (value != 'boolean')
//                             fieldDef['description_remarks'] = '';
//                         }),
//                   style: TextStyle(
//                     color: isDarkMode
//                         ? Colors.white
//                         : theme.colorScheme.onSurface,
//                   ),
//                 ),
//               ),
//               const SizedBox(width: 12),
//               Expanded(
//                 child: DropdownButtonFormField<String>(
//                   value: fieldDef['frequency'],
//                   decoration: InputDecoration(
//                     labelText: 'Frequency',
//                     prefixIcon: Icon(
//                       Icons.schedule,
//                       color: theme.colorScheme.primary,
//                       size: 18,
//                     ),
//                     border: OutlineInputBorder(
//                       borderRadius: BorderRadius.circular(8),
//                     ),
//                     filled: true,
//                     fillColor: isDarkMode
//                         ? const Color(0xFF2C2C2E)
//                         : Colors.white,
//                     contentPadding: const EdgeInsets.symmetric(
//                       horizontal: 12,
//                       vertical: 12,
//                     ),
//                     isDense: true,
//                   ),
//                   dropdownColor: isDarkMode
//                       ? const Color(0xFF2C2C2E)
//                       : Colors.white,
//                   items: _frequencies
//                       .map(
//                         (freq) => DropdownMenuItem(
//                           value: freq,
//                           child: Row(
//                             mainAxisSize: MainAxisSize.min,
//                             children: [
//                               Container(
//                                 width: 8,
//                                 height: 8,
//                                 decoration: BoxDecoration(
//                                   color: _getFrequencyColor(freq),
//                                   shape: BoxShape.circle,
//                                 ),
//                               ),
//                               const SizedBox(width: 8),
//                               Text(
//                                 freq,
//                                 style: TextStyle(
//                                   color: isDarkMode
//                                       ? Colors.white
//                                       : theme.colorScheme.onSurface,
//                                 ),
//                               ),
//                             ],
//                           ),
//                         ),
//                       )
//                       .toList(),
//                   onChanged: isDefault
//                       ? null
//                       : (value) => _debouncedUpdate(
//                           () => fieldDef['frequency'] = value!,
//                         ),
//                   style: TextStyle(
//                     color: isDarkMode
//                         ? Colors.white
//                         : theme.colorScheme.onSurface,
//                   ),
//                 ),
//               ),
//             ],
//           ),
//           const SizedBox(height: 12),
//           if (fieldDef['dataType'] == 'number') ...[
//             Row(
//               children: [
//                 Expanded(
//                   child: TextFormField(
//                     initialValue: fieldDef['unit'],
//                     decoration: InputDecoration(
//                       labelText: 'Unit',
//                       hintText: 'e.g., V, A, kW',
//                       prefixIcon: Icon(
//                         Icons.straighten,
//                         color: theme.colorScheme.primary,
//                         size: 18,
//                       ),
//                       border: OutlineInputBorder(
//                         borderRadius: BorderRadius.circular(8),
//                       ),
//                       filled: true,
//                       fillColor: isDarkMode
//                           ? const Color(0xFF2C2C2E)
//                           : Colors.white,
//                       contentPadding: const EdgeInsets.symmetric(
//                         horizontal: 12,
//                         vertical: 12,
//                       ),
//                       isDense: true,
//                     ),
//                     style: TextStyle(
//                       color: isDarkMode
//                           ? Colors.white
//                           : theme.colorScheme.onSurface,
//                     ),
//                     onChanged: isDefault
//                         ? null
//                         : (value) =>
//                               _debouncedUpdate(() => fieldDef['unit'] = value),
//                     readOnly: isDefault,
//                   ),
//                 ),
//               ],
//             ),
//             const SizedBox(height: 12),

//             // 🔥 Add Integer-only checkbox
//             CheckboxListTile(
//               title: Text(
//                 'Integer Only',
//                 style: TextStyle(
//                   fontSize: 14,
//                   fontWeight: FontWeight.w500,
//                   color: isDarkMode
//                       ? Colors.white
//                       : theme.colorScheme.onSurface,
//                 ),
//               ),
//               subtitle: Text(
//                 'Restrict input to whole numbers only (e.g., 1, 2, 3)',
//                 style: TextStyle(
//                   fontSize: 12,
//                   color: isDarkMode
//                       ? Colors.white.withOpacity(0.6)
//                       : Colors.grey.shade600,
//                 ),
//               ),
//               value: fieldDef['isInteger'] ?? false,
//               onChanged: isDefault
//                   ? null
//                   : (value) => _debouncedUpdate(
//                       () => fieldDef['isInteger'] = value ?? false,
//                     ),
//               controlAffinity: ListTileControlAffinity.leading,
//               contentPadding: EdgeInsets.zero,
//               dense: true,
//               activeColor: theme.colorScheme.primary,
//             ),
//             const SizedBox(height: 12),

//             Row(
//               children: [
//                 Expanded(
//                   child: TextFormField(
//                     initialValue: fieldDef['minRange']?.toString() ?? '',
//                     decoration: InputDecoration(
//                       labelText: 'Min Range',
//                       hintText: fieldDef['isInteger'] == true
//                           ? 'Minimum integer'
//                           : 'Minimum value',
//                       prefixIcon: Icon(
//                         Icons.minimize,
//                         color: theme.colorScheme.secondary,
//                         size: 18,
//                       ),
//                       border: OutlineInputBorder(
//                         borderRadius: BorderRadius.circular(8),
//                       ),
//                       filled: true,
//                       fillColor: isDarkMode
//                           ? const Color(0xFF2C2C2E)
//                           : Colors.white,
//                       contentPadding: const EdgeInsets.symmetric(
//                         horizontal: 12,
//                         vertical: 12,
//                       ),
//                       isDense: true,
//                     ),
//                     style: TextStyle(
//                       color: isDarkMode
//                           ? Colors.white
//                           : theme.colorScheme.onSurface,
//                     ),
//                     // 🔥 Restrict keyboard type based on isInteger flag
//                     keyboardType: fieldDef['isInteger'] == true
//                         ? TextInputType.number
//                         : const TextInputType.numberWithOptions(decimal: true),
//                     onChanged: isDefault
//                         ? null
//                         : (value) => _debouncedUpdate(() {
//                             fieldDef['minRange'] = value.isEmpty
//                                 ? null
//                                 : (fieldDef['isInteger'] == true
//                                       ? int.tryParse(value)?.toDouble()
//                                       : double.tryParse(value));
//                           }),
//                     readOnly: isDefault,
//                     // 🔥 Add validation for integers
//                     validator: (value) {
//                       if (value != null &&
//                           value.isNotEmpty &&
//                           fieldDef['isInteger'] == true) {
//                         final intValue = int.tryParse(value);
//                         if (intValue == null) {
//                           return 'Please enter a valid integer';
//                         }
//                       }
//                       return null;
//                     },
//                   ),
//                 ),
//                 const SizedBox(width: 12),
//                 Expanded(
//                   child: TextFormField(
//                     initialValue: fieldDef['maxRange']?.toString() ?? '',
//                     decoration: InputDecoration(
//                       labelText: 'Max Range',
//                       hintText: fieldDef['isInteger'] == true
//                           ? 'Maximum integer'
//                           : 'Maximum value',
//                       prefixIcon: Icon(
//                         Icons.maximize,
//                         color: theme.colorScheme.secondary,
//                         size: 18,
//                       ),
//                       border: OutlineInputBorder(
//                         borderRadius: BorderRadius.circular(8),
//                       ),
//                       filled: true,
//                       fillColor: isDarkMode
//                           ? const Color(0xFF2C2C2E)
//                           : Colors.white,
//                       contentPadding: const EdgeInsets.symmetric(
//                         horizontal: 12,
//                         vertical: 12,
//                       ),
//                       isDense: true,
//                     ),
//                     style: TextStyle(
//                       color: isDarkMode
//                           ? Colors.white
//                           : theme.colorScheme.onSurface,
//                     ),
//                     // 🔥 Restrict keyboard type based on isInteger flag
//                     keyboardType: fieldDef['isInteger'] == true
//                         ? TextInputType.number
//                         : const TextInputType.numberWithOptions(decimal: true),
//                     onChanged: isDefault
//                         ? null
//                         : (value) => _debouncedUpdate(() {
//                             fieldDef['maxRange'] = value.isEmpty
//                                 ? null
//                                 : (fieldDef['isInteger'] == true
//                                       ? int.tryParse(value)?.toDouble()
//                                       : double.tryParse(value));
//                           }),
//                     readOnly: isDefault,
//                     // 🔥 Add validation for integers
//                     validator: (value) {
//                       if (value != null &&
//                           value.isNotEmpty &&
//                           fieldDef['isInteger'] == true) {
//                         final intValue = int.tryParse(value);
//                         if (intValue == null) {
//                           return 'Please enter a valid integer';
//                         }
//                       }
//                       return null;
//                     },
//                   ),
//                 ),
//               ],
//             ),
//           ],
//           if (fieldDef['dataType'] == 'dropdown') ...[
//             TextFormField(
//               initialValue: (fieldDef['options'] as List<dynamic>?)?.join(', '),
//               decoration: InputDecoration(
//                 labelText: 'Options (comma-separated) *',
//                 hintText: 'Option1, Option2, Option3',
//                 prefixIcon: Icon(
//                   Icons.list,
//                   color: theme.colorScheme.primary,
//                   size: 18,
//                 ),
//                 border: OutlineInputBorder(
//                   borderRadius: BorderRadius.circular(8),
//                 ),
//                 filled: true,
//                 fillColor: isDarkMode ? const Color(0xFF2C2C2E) : Colors.white,
//                 contentPadding: const EdgeInsets.symmetric(
//                   horizontal: 12,
//                   vertical: 12,
//                 ),
//                 isDense: true,
//               ),
//               style: TextStyle(
//                 color: isDarkMode ? Colors.white : theme.colorScheme.onSurface,
//               ),
//               onChanged: isDefault
//                   ? null
//                   : (value) => _debouncedUpdate(
//                       () => fieldDef['options'] = value
//                           .split(',')
//                           .map((e) => e.trim())
//                           .where((e) => e.isNotEmpty)
//                           .toList(),
//                     ),
//               readOnly: isDefault,
//               validator: (value) {
//                 if (fieldDef['dataType'] == 'dropdown' &&
//                     (value == null || value.trim().isEmpty)) {
//                   return 'Options are required for dropdown fields';
//                 }
//                 return null;
//               },
//             ),
//           ],
//           if (fieldDef['dataType'] == 'boolean') ...[
//             TextFormField(
//               initialValue: fieldDef['description_remarks'],
//               decoration: InputDecoration(
//                 labelText: 'Description/Remarks (Optional)',
//                 hintText: 'Additional context for this boolean field',
//                 prefixIcon: Icon(
//                   Icons.notes,
//                   color: theme.colorScheme.primary,
//                   size: 18,
//                 ),
//                 border: OutlineInputBorder(
//                   borderRadius: BorderRadius.circular(8),
//                 ),
//                 filled: true,
//                 fillColor: isDarkMode ? const Color(0xFF2C2C2E) : Colors.white,
//                 contentPadding: const EdgeInsets.symmetric(
//                   horizontal: 12,
//                   vertical: 12,
//                 ),
//               ),
//               style: TextStyle(
//                 color: isDarkMode ? Colors.white : theme.colorScheme.onSurface,
//               ),
//               maxLines: 2,
//               onChanged: isDefault
//                   ? null
//                   : (value) => _debouncedUpdate(
//                       () => fieldDef['description_remarks'] = value,
//                     ),
//               readOnly: isDefault,
//             ),
//           ],
//         ] else ...[
//           Row(
//             children: [
//               Icon(
//                 Icons.group_work,
//                 color: theme.colorScheme.secondary,
//                 size: 20,
//               ),
//               const SizedBox(width: 8),
//               Text(
//                 'Group Field Configuration',
//                 style: TextStyle(
//                   fontSize: 14,
//                   fontWeight: FontWeight.w600,
//                   color: theme.colorScheme.secondary,
//                 ),
//               ),
//             ],
//           ),
//           const SizedBox(height: 8),
//           DropdownButtonFormField<String>(
//             value: fieldDef['frequency'],
//             decoration: InputDecoration(
//               labelText: 'Frequency',
//               prefixIcon: Icon(
//                 Icons.schedule,
//                 color: theme.colorScheme.primary,
//                 size: 18,
//               ),
//               border: OutlineInputBorder(
//                 borderRadius: BorderRadius.circular(8),
//               ),
//               filled: true,
//               fillColor: isDarkMode ? const Color(0xFF2C2C2E) : Colors.white,
//               contentPadding: const EdgeInsets.symmetric(
//                 horizontal: 12,
//                 vertical: 12,
//               ),
//               isDense: true,
//             ),
//             dropdownColor: isDarkMode ? const Color(0xFF2C2C2E) : Colors.white,
//             items: _frequencies
//                 .map(
//                   (freq) => DropdownMenuItem(
//                     value: freq,
//                     child: Row(
//                       mainAxisSize: MainAxisSize.min,
//                       children: [
//                         Container(
//                           width: 8,
//                           height: 8,
//                           decoration: BoxDecoration(
//                             color: _getFrequencyColor(freq),
//                             shape: BoxShape.circle,
//                           ),
//                         ),
//                         const SizedBox(width: 8),
//                         Text(
//                           freq,
//                           style: TextStyle(
//                             color: isDarkMode
//                                 ? Colors.white
//                                 : theme.colorScheme.onSurface,
//                           ),
//                         ),
//                       ],
//                     ),
//                   ),
//                 )
//                 .toList(),
//             onChanged: isDefault
//                 ? null
//                 : (value) =>
//                       _debouncedUpdate(() => fieldDef['frequency'] = value!),
//             style: TextStyle(
//               color: isDarkMode ? Colors.white : theme.colorScheme.onSurface,
//             ),
//           ),
//         ],
//         const SizedBox(height: 12),
//         CheckboxListTile(
//           title: Text(
//             'Mandatory Field',
//             style: TextStyle(
//               fontSize: 14,
//               fontWeight: FontWeight.w500,
//               color: isDarkMode ? Colors.white : theme.colorScheme.onSurface,
//             ),
//           ),
//           subtitle: Text(
//             'Users must provide a value for this field',
//             style: TextStyle(
//               fontSize: 12,
//               color: isDarkMode
//                   ? Colors.white.withOpacity(0.6)
//                   : Colors.grey.shade600,
//             ),
//           ),
//           value: fieldDef['isMandatory'] ?? false,
//           onChanged: isDefault
//               ? null
//               : (value) => _debouncedUpdate(
//                   () => fieldDef['isMandatory'] = value ?? false,
//                 ),
//           controlAffinity: ListTileControlAffinity.leading,
//           contentPadding: EdgeInsets.zero,
//           dense: true,
//           activeColor: theme.colorScheme.primary,
//         ),
//       ],
//     );
//   }

//   Widget _buildNestedFields(
//     Map<String, dynamic> fieldDef,
//     ThemeData theme,
//     bool isDarkMode,
//   ) {
//     final nestedFields = fieldDef['nestedFields'] as List<dynamic>;

//     return Container(
//       padding: const EdgeInsets.all(12),
//       decoration: BoxDecoration(
//         color: theme.colorScheme.secondary.withOpacity(0.05),
//         borderRadius: BorderRadius.circular(8),
//         border: Border.all(color: theme.colorScheme.secondary.withOpacity(0.3)),
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Row(
//             children: [
//               Icon(Icons.list, color: theme.colorScheme.secondary, size: 16),
//               const SizedBox(width: 8),
//               Text(
//                 'Group Fields',
//                 style: TextStyle(
//                   fontSize: 14,
//                   fontWeight: FontWeight.w600,
//                   color: theme.colorScheme.secondary,
//                 ),
//               ),
//               const Spacer(),
//               Text(
//                 '${nestedFields.length} fields',
//                 style: TextStyle(
//                   fontSize: 12,
//                   fontWeight: FontWeight.w500,
//                   color: theme.colorScheme.secondary,
//                 ),
//               ),
//             ],
//           ),
//           const SizedBox(height: 12),
//           if (nestedFields.isEmpty)
//             Container(
//               padding: const EdgeInsets.all(16),
//               decoration: BoxDecoration(
//                 color: isDarkMode
//                     ? const Color(0xFF3C3C3E)
//                     : Colors.grey.shade100,
//                 borderRadius: BorderRadius.circular(6),
//               ),
//               child: Text(
//                 'No fields defined for this group. Add fields below.',
//                 style: TextStyle(
//                   fontSize: 13,
//                   color: isDarkMode
//                       ? Colors.white.withOpacity(0.4)
//                       : Colors.grey.shade600,
//                 ),
//                 textAlign: TextAlign.center,
//               ),
//             )
//           else
//             Column(
//               children: nestedFields.asMap().entries.map((entry) {
//                 final nestedIndex = entry.key;
//                 final nestedField = entry.value;
//                 return Container(
//                   margin: const EdgeInsets.only(bottom: 8),
//                   child: _buildNestedFieldCard(
//                     nestedField,
//                     nestedIndex,
//                     fieldDef,
//                     theme,
//                     isDarkMode,
//                   ),
//                 );
//               }).toList(),
//             ),
//           const SizedBox(height: 12),
//           SizedBox(
//             width: double.infinity,
//             child: ElevatedButton.icon(
//               onPressed: () => _addNestedReadingField(fieldDef),
//               icon: const Icon(Icons.add, size: 16),
//               label: const Text('Add Field to Group'),
//               style: ElevatedButton.styleFrom(
//                 backgroundColor: theme.colorScheme.secondary,
//                 foregroundColor: Colors.white,
//                 padding: const EdgeInsets.symmetric(vertical: 8),
//                 shape: RoundedRectangleBorder(
//                   borderRadius: BorderRadius.circular(6),
//                 ),
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildNestedFieldCard(
//     Map<String, dynamic> nestedField,
//     int nestedIndex,
//     Map<String, dynamic> groupField,
//     ThemeData theme,
//     bool isDarkMode,
//   ) {
//     return Container(
//       padding: const EdgeInsets.all(12),
//       decoration: BoxDecoration(
//         color: isDarkMode ? const Color(0xFF2C2C2E) : Colors.white,
//         borderRadius: BorderRadius.circular(8),
//         border: Border.all(
//           color: isDarkMode
//               ? Colors.white.withOpacity(0.1)
//               : Colors.grey.shade200,
//         ),
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Row(
//             children: [
//               Container(
//                 padding: const EdgeInsets.all(4),
//                 decoration: BoxDecoration(
//                   color: _getDataTypeColor(
//                     nestedField['dataType'],
//                   ).withOpacity(0.15),
//                   borderRadius: BorderRadius.circular(4),
//                 ),
//                 child: Icon(
//                   _getDataTypeIcon(nestedField['dataType']),
//                   size: 12,
//                   color: _getDataTypeColor(nestedField['dataType']),
//                 ),
//               ),
//               const SizedBox(width: 8),
//               Expanded(
//                 child: Text(
//                   nestedField['name'].isEmpty
//                       ? 'Unnamed Field'
//                       : nestedField['name'],
//                   style: TextStyle(
//                     fontSize: 13,
//                     fontWeight: FontWeight.w600,
//                     color: isDarkMode
//                         ? Colors.white
//                         : theme.colorScheme.onSurface,
//                   ),
//                 ),
//               ),
//               // 🔥 Add integer badge for nested integer fields
//               if (nestedField['isInteger'] == true)
//                 Container(
//                   margin: const EdgeInsets.only(right: 8),
//                   padding: const EdgeInsets.symmetric(
//                     horizontal: 4,
//                     vertical: 1,
//                   ),
//                   decoration: BoxDecoration(
//                     color: Colors.orange.withOpacity(0.1),
//                     borderRadius: BorderRadius.circular(3),
//                   ),
//                   child: Text(
//                     'INT',
//                     style: TextStyle(
//                       fontSize: 8,
//                       fontWeight: FontWeight.w700,
//                       color: Colors.orange,
//                     ),
//                   ),
//                 ),
//               IconButton(
//                 onPressed: () =>
//                     _removeNestedReadingField(groupField, nestedIndex),
//                 icon: Icon(
//                   Icons.remove_circle_outline,
//                   color: theme.colorScheme.error,
//                   size: 16,
//                 ),
//                 style: IconButton.styleFrom(
//                   backgroundColor: theme.colorScheme.error.withOpacity(0.1),
//                   minimumSize: const Size(24, 24),
//                   padding: EdgeInsets.zero,
//                 ),
//               ),
//             ],
//           ),
//           const SizedBox(height: 8),
//           TextFormField(
//             initialValue: nestedField['name'],
//             decoration: InputDecoration(
//               labelText: 'Field Name *',
//               hintText: 'e.g., Cell Number, Voltage',
//               border: OutlineInputBorder(
//                 borderRadius: BorderRadius.circular(6),
//               ),
//               filled: true,
//               fillColor: isDarkMode
//                   ? const Color(0xFF3C3C3E)
//                   : Colors.grey.shade50,
//               contentPadding: const EdgeInsets.symmetric(
//                 horizontal: 8,
//                 vertical: 8,
//               ),
//               isDense: true,
//             ),
//             style: TextStyle(
//               fontSize: 13,
//               color: isDarkMode ? Colors.white : theme.colorScheme.onSurface,
//             ),
//             onChanged: (value) =>
//                 _debouncedUpdate(() => nestedField['name'] = value),
//             validator: (value) => value == null || value.trim().isEmpty
//                 ? 'Field name is required'
//                 : null,
//           ),
//           const SizedBox(height: 8),
//           Row(
//             children: [
//               Expanded(
//                 child: DropdownButtonFormField<String>(
//                   value: nestedField['dataType'],
//                   decoration: InputDecoration(
//                     labelText: 'Type',
//                     border: OutlineInputBorder(
//                       borderRadius: BorderRadius.circular(6),
//                     ),
//                     filled: true,
//                     fillColor: isDarkMode
//                         ? const Color(0xFF3C3C3E)
//                         : Colors.grey.shade50,
//                     contentPadding: const EdgeInsets.symmetric(
//                       horizontal: 8,
//                       vertical: 8,
//                     ),
//                     isDense: true,
//                   ),
//                   dropdownColor: isDarkMode
//                       ? const Color(0xFF2C2C2E)
//                       : Colors.white,
//                   items: _dataTypes
//                       .where((type) => type != 'group')
//                       .map(
//                         (type) => DropdownMenuItem(
//                           value: type,
//                           child: Text(
//                             type,
//                             style: TextStyle(
//                               fontSize: 13,
//                               color: isDarkMode
//                                   ? Colors.white
//                                   : theme.colorScheme.onSurface,
//                             ),
//                           ),
//                         ),
//                       )
//                       .toList(),
//                   onChanged: (value) => _debouncedUpdate(() {
//                     nestedField['dataType'] = value!;
//                     if (value != 'dropdown') nestedField['options'] = [];
//                     if (value != 'number') {
//                       nestedField['unit'] = '';
//                       nestedField['minRange'] = null;
//                       nestedField['maxRange'] = null;
//                       nestedField['isInteger'] = false; // 🔥 Reset integer flag
//                     }
//                     if (value != 'boolean')
//                       nestedField['description_remarks'] = '';
//                   }),
//                   style: TextStyle(
//                     fontSize: 13,
//                     color: isDarkMode
//                         ? Colors.white
//                         : theme.colorScheme.onSurface,
//                   ),
//                 ),
//               ),
//               if (nestedField['dataType'] == 'number') ...[
//                 const SizedBox(width: 8),
//                 Expanded(
//                   child: TextFormField(
//                     initialValue: nestedField['unit'],
//                     decoration: InputDecoration(
//                       labelText: 'Unit',
//                       hintText: 'V, A, etc.',
//                       border: OutlineInputBorder(
//                         borderRadius: BorderRadius.circular(6),
//                       ),
//                       filled: true,
//                       fillColor: isDarkMode
//                           ? const Color(0xFF3C3C3E)
//                           : Colors.grey.shade50,
//                       contentPadding: const EdgeInsets.symmetric(
//                         horizontal: 8,
//                         vertical: 8,
//                       ),
//                       isDense: true,
//                     ),
//                     style: TextStyle(
//                       fontSize: 13,
//                       color: isDarkMode
//                           ? Colors.white
//                           : theme.colorScheme.onSurface,
//                     ),
//                     onChanged: (value) =>
//                         _debouncedUpdate(() => nestedField['unit'] = value),
//                   ),
//                 ),
//               ],
//             ],
//           ),

//           // 🔥 Add integer checkbox for nested number fields
//           if (nestedField['dataType'] == 'number') ...[
//             const SizedBox(height: 8),
//             CheckboxListTile(
//               title: Text(
//                 'Integer Only',
//                 style: TextStyle(
//                   fontSize: 11,
//                   fontWeight: FontWeight.w500,
//                   color: isDarkMode
//                       ? Colors.white
//                       : theme.colorScheme.onSurface,
//                 ),
//               ),
//               value: nestedField['isInteger'] ?? false,
//               onChanged: (value) => _debouncedUpdate(
//                 () => nestedField['isInteger'] = value ?? false,
//               ),
//               controlAffinity: ListTileControlAffinity.leading,
//               contentPadding: EdgeInsets.zero,
//               dense: true,
//               visualDensity: VisualDensity.compact,
//               activeColor: theme.colorScheme.primary,
//             ),
//           ],

//           if (nestedField['dataType'] == 'number') ...[
//             const SizedBox(height: 8),
//             Row(
//               children: [
//                 Expanded(
//                   child: TextFormField(
//                     initialValue: nestedField['minRange']?.toString() ?? '',
//                     decoration: InputDecoration(
//                       labelText: 'Min',
//                       hintText: nestedField['isInteger'] == true
//                           ? 'Min int'
//                           : 'Min value',
//                       border: OutlineInputBorder(
//                         borderRadius: BorderRadius.circular(6),
//                       ),
//                       filled: true,
//                       fillColor: isDarkMode
//                           ? const Color(0xFF3C3C3E)
//                           : Colors.grey.shade50,
//                       contentPadding: const EdgeInsets.symmetric(
//                         horizontal: 8,
//                         vertical: 8,
//                       ),
//                       isDense: true,
//                     ),
//                     style: TextStyle(
//                       fontSize: 13,
//                       color: isDarkMode
//                           ? Colors.white
//                           : theme.colorScheme.onSurface,
//                     ),
//                     // 🔥 Restrict keyboard type for nested fields
//                     keyboardType: nestedField['isInteger'] == true
//                         ? TextInputType.number
//                         : const TextInputType.numberWithOptions(decimal: true),
//                     onChanged: (value) => _debouncedUpdate(() {
//                       nestedField['minRange'] = value.isEmpty
//                           ? null
//                           : (nestedField['isInteger'] == true
//                                 ? int.tryParse(value)?.toDouble()
//                                 : double.tryParse(value));
//                     }),
//                     // 🔥 Add validation for nested integer fields
//                     validator: (value) {
//                       if (value != null &&
//                           value.isNotEmpty &&
//                           nestedField['isInteger'] == true) {
//                         final intValue = int.tryParse(value);
//                         if (intValue == null) {
//                           return 'Enter valid integer';
//                         }
//                       }
//                       return null;
//                     },
//                   ),
//                 ),
//                 const SizedBox(width: 8),
//                 Expanded(
//                   child: TextFormField(
//                     initialValue: nestedField['maxRange']?.toString() ?? '',
//                     decoration: InputDecoration(
//                       labelText: 'Max',
//                       hintText: nestedField['isInteger'] == true
//                           ? 'Max int'
//                           : 'Max value',
//                       border: OutlineInputBorder(
//                         borderRadius: BorderRadius.circular(6),
//                       ),
//                       filled: true,
//                       fillColor: isDarkMode
//                           ? const Color(0xFF3C3C3E)
//                           : Colors.grey.shade50,
//                       contentPadding: const EdgeInsets.symmetric(
//                         horizontal: 8,
//                         vertical: 8,
//                       ),
//                       isDense: true,
//                     ),
//                     style: TextStyle(
//                       fontSize: 13,
//                       color: isDarkMode
//                           ? Colors.white
//                           : theme.colorScheme.onSurface,
//                     ),
//                     // 🔥 Restrict keyboard type for nested fields
//                     keyboardType: nestedField['isInteger'] == true
//                         ? TextInputType.number
//                         : const TextInputType.numberWithOptions(decimal: true),
//                     onChanged: (value) => _debouncedUpdate(() {
//                       nestedField['maxRange'] = value.isEmpty
//                           ? null
//                           : (nestedField['isInteger'] == true
//                                 ? int.tryParse(value)?.toDouble()
//                                 : double.tryParse(value));
//                     }),
//                     // 🔥 Add validation for nested integer fields
//                     validator: (value) {
//                       if (value != null &&
//                           value.isNotEmpty &&
//                           nestedField['isInteger'] == true) {
//                         final intValue = int.tryParse(value);
//                         if (intValue == null) {
//                           return 'Enter valid integer';
//                         }
//                       }
//                       return null;
//                     },
//                   ),
//                 ),
//               ],
//             ),
//           ],
//           if (nestedField['dataType'] == 'dropdown') ...[
//             const SizedBox(height: 8),
//             TextFormField(
//               initialValue: (nestedField['options'] as List<dynamic>?)?.join(
//                 ', ',
//               ),
//               decoration: InputDecoration(
//                 labelText: 'Options *',
//                 hintText: 'Option1, Option2',
//                 border: OutlineInputBorder(
//                   borderRadius: BorderRadius.circular(6),
//                 ),
//                 filled: true,
//                 fillColor: isDarkMode
//                     ? const Color(0xFF3C3C3E)
//                     : Colors.grey.shade50,
//                 contentPadding: const EdgeInsets.symmetric(
//                   horizontal: 8,
//                   vertical: 8,
//                 ),
//                 isDense: true,
//               ),
//               style: TextStyle(
//                 fontSize: 13,
//                 color: isDarkMode ? Colors.white : theme.colorScheme.onSurface,
//               ),
//               onChanged: (value) => _debouncedUpdate(
//                 () => nestedField['options'] = value
//                     .split(',')
//                     .map((e) => e.trim())
//                     .where((e) => e.isNotEmpty)
//                     .toList(),
//               ),
//             ),
//           ],
//           const SizedBox(height: 8),
//           CheckboxListTile(
//             title: Text(
//               'Mandatory',
//               style: TextStyle(
//                 fontSize: 12,
//                 fontWeight: FontWeight.w500,
//                 color: isDarkMode ? Colors.white : theme.colorScheme.onSurface,
//               ),
//             ),
//             value: nestedField['isMandatory'] ?? false,
//             onChanged: (value) => _debouncedUpdate(
//               () => nestedField['isMandatory'] = value ?? false,
//             ),
//             controlAffinity: ListTileControlAffinity.leading,
//             contentPadding: EdgeInsets.zero,
//             dense: true,
//             visualDensity: VisualDensity.compact,
//             activeColor: theme.colorScheme.primary,
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildActionButtons(ThemeData theme, bool isDarkMode) {
//     return Container(
//       margin: const EdgeInsets.symmetric(horizontal: 16),
//       child: Row(
//         children: [
//           Expanded(
//             child: OutlinedButton(
//               onPressed: _showListView,
//               style: OutlinedButton.styleFrom(
//                 foregroundColor: isDarkMode
//                     ? Colors.white.withOpacity(0.7)
//                     : Colors.grey.shade700,
//                 padding: const EdgeInsets.symmetric(vertical: 16),
//                 shape: RoundedRectangleBorder(
//                   borderRadius: BorderRadius.circular(8),
//                 ),
//                 side: BorderSide(
//                   color: isDarkMode
//                       ? Colors.white.withOpacity(0.6)
//                       : Colors.grey.shade300,
//                 ),
//               ),
//               child: const Text(
//                 'Cancel',
//                 style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
//               ),
//             ),
//           ),
//           const SizedBox(width: 16),
//           Expanded(
//             child: ElevatedButton(
//               onPressed: _isSaving ? null : _saveTemplate,
//               style: ElevatedButton.styleFrom(
//                 backgroundColor: theme.colorScheme.primary,
//                 foregroundColor: Colors.white,
//                 padding: const EdgeInsets.symmetric(vertical: 16),
//                 shape: RoundedRectangleBorder(
//                   borderRadius: BorderRadius.circular(8),
//                 ),
//                 elevation: 2,
//               ),
//               child: _isSaving
//                   ? const SizedBox(
//                       width: 20,
//                       height: 20,
//                       child: CircularProgressIndicator(
//                         strokeWidth: 2,
//                         color: Colors.white,
//                       ),
//                     )
//                   : Text(
//                       _templateToEdit == null
//                           ? 'Create Template'
//                           : 'Update Template',
//                       style: const TextStyle(
//                         fontSize: 16,
//                         fontWeight: FontWeight.w600,
//                       ),
//                     ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }
// lib/screens/admin/reading_template_management_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import 'package:intl/intl.dart';

import '../../models/reading_models.dart';
import '../../utils/snackbar_utils.dart';

// Reusable field widgets
import '../../widgets/reading_field_widgets.dart';

enum ReadingTemplateViewMode { list, form }

class ReadingTemplateManagementScreen extends StatefulWidget {
  const ReadingTemplateManagementScreen({super.key});

  @override
  State<ReadingTemplateManagementScreen> createState() =>
      _ReadingTemplateManagementScreenState();
}

class _ReadingTemplateManagementScreenState
    extends State<ReadingTemplateManagementScreen>
    with SingleTickerProviderStateMixin {
  ReadingTemplateViewMode _viewMode = ReadingTemplateViewMode.list;
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  ReadingTemplate? _templateToEdit;
  List<ReadingTemplate> _templates = [];

  bool _isLoading = true;
  bool _isSaving = false;

  String? _selectedBayType;
  String? _templateDescription;
  List<Map<String, dynamic>> _templateReadingFields = [];

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  final List<String> _dataTypes = ReadingFieldDataType.values
      .map((e) => e.toString().split('.').last)
      .toList();
  final List<String> _frequencies = ReadingFrequency.values
      .map((e) => e.toString().split('.').last)
      .toList();

  final List<String> _bayTypes = [
    'Transformer',
    'Line',
    'Feeder',
    'Capacitor Bank',
    'Reactor',
    'Bus Coupler',
    'Battery',
    'Busbar',
  ];

  final List<ReadingField> _defaultEnergyFields = [
    ReadingField(
      name: 'Previous Day Reading (Import)',
      dataType: ReadingFieldDataType.number,
      isMandatory: true,
      unit: 'MWH',
      frequency: ReadingFrequency.daily,
    ),
    ReadingField(
      name: 'Current Day Reading (Import)',
      dataType: ReadingFieldDataType.number,
      isMandatory: true,
      unit: 'MWH',
      frequency: ReadingFrequency.daily,
    ),
    ReadingField(
      name: 'Previous Day Reading (Export)',
      dataType: ReadingFieldDataType.number,
      isMandatory: true,
      unit: 'MWH',
      frequency: ReadingFrequency.daily,
    ),
    ReadingField(
      name: 'Current Day Reading (Export)',
      dataType: ReadingFieldDataType.number,
      isMandatory: true,
      unit: 'MWH',
      frequency: ReadingFrequency.daily,
    ),
  ];

  final Map<String, List<ReadingField>> _defaultHourlyFields = {
    'Feeder': [
      ReadingField(
        name: 'Current',
        unit: 'A',
        dataType: ReadingFieldDataType.number,
        isMandatory: true,
        frequency: ReadingFrequency.hourly,
        minRange: 0.00,
        maxRange: 5000.000,
      ),
    ],
    'Transformer': [
      ReadingField(
        name: 'Current',
        unit: 'A',
        dataType: ReadingFieldDataType.number,
        isMandatory: true,
        frequency: ReadingFrequency.hourly,
        minRange: 0.00,
        maxRange: 5000.00,
      ),
      ReadingField(
        name: 'Power Factor',
        unit: '',
        dataType: ReadingFieldDataType.number,
        isMandatory: true,
        frequency: ReadingFrequency.hourly,
        minRange: -1.00,
        maxRange: 1.00,
      ),
      ReadingField(
        name: 'Real Power (MW)',
        unit: 'MW',
        dataType: ReadingFieldDataType.number,
        isMandatory: true,
        frequency: ReadingFrequency.hourly,
        minRange: 0.00,
        maxRange: 1000.00,
      ),
      ReadingField(
        name: 'Voltage',
        unit: 'kV',
        dataType: ReadingFieldDataType.number,
        isMandatory: true,
        frequency: ReadingFrequency.hourly,
        minRange: 10.00,
        maxRange: 1000.00,
      ),
      ReadingField(
        name: 'Apparent Power (MVAR)',
        unit: 'MVAR',
        dataType: ReadingFieldDataType.number,
        isMandatory: true,
        frequency: ReadingFrequency.hourly,
        minRange: 0.00,
        maxRange: 1000.00,
      ),
      ReadingField(
        name: 'Gas Pressure (SF6)',
        unit: 'kg/cm2',
        dataType: ReadingFieldDataType.number,
        isMandatory: false,
        frequency: ReadingFrequency.hourly,
        minRange: 4.0,
        maxRange: 10.0,
      ),
      ReadingField(
        name: 'Winding Temperature',
        unit: 'Celsius',
        dataType: ReadingFieldDataType.number,
        isMandatory: true,
        frequency: ReadingFrequency.hourly,
        minRange: -40.00,
        maxRange: 120.00,
      ),
      ReadingField(
        name: 'Oil Temperature',
        unit: 'Celsius',
        dataType: ReadingFieldDataType.number,
        isMandatory: true,
        frequency: ReadingFrequency.hourly,
        minRange: -40.00,
        maxRange: 120.00,
      ),
      ReadingField(
        name: 'Tap Position',
        unit: 'No.',
        dataType: ReadingFieldDataType.number,
        isMandatory: true,
        frequency: ReadingFrequency.hourly,
        minRange: 1.0,
        maxRange: 33.0,
        isInteger: true,
      ),
      ReadingField(
        name: 'Frequency',
        unit: 'Hz',
        dataType: ReadingFieldDataType.number,
        isMandatory: true,
        frequency: ReadingFrequency.hourly,
        minRange: 48.0,
        maxRange: 52.0,
      ),
    ],
    'Line': [
      ReadingField(
        name: 'Current',
        unit: 'A',
        dataType: ReadingFieldDataType.number,
        isMandatory: true,
        frequency: ReadingFrequency.hourly,
        minRange: 0.00,
        maxRange: 5000.00,
      ),
      ReadingField(
        name: 'Power Factor',
        unit: '',
        dataType: ReadingFieldDataType.number,
        isMandatory: true,
        frequency: ReadingFrequency.hourly,
        minRange: -1.00,
        maxRange: 1.00,
      ),
      ReadingField(
        name: 'Real Power (MW)',
        unit: 'MW',
        dataType: ReadingFieldDataType.number,
        isMandatory: true,
        frequency: ReadingFrequency.hourly,
        minRange: 0.00,
        maxRange: 1000.00,
      ),
      ReadingField(
        name: 'Voltage',
        unit: 'kV',
        dataType: ReadingFieldDataType.number,
        isMandatory: true,
        frequency: ReadingFrequency.hourly,
        minRange: 10.00,
        maxRange: 1000.00,
      ),
      ReadingField(
        name: 'Apparent Power (MVAR)',
        unit: 'MVAR',
        dataType: ReadingFieldDataType.number,
        isMandatory: true,
        frequency: ReadingFrequency.hourly,
        minRange: 0.00,
        maxRange: 1000.00,
      ),
      ReadingField(
        name: 'Gas Pressure (SF6)',
        unit: 'kg/cm2',
        dataType: ReadingFieldDataType.number,
        isMandatory: false,
        frequency: ReadingFrequency.hourly,
        minRange: 4.0,
        maxRange: 10.0,
      ),
    ],
    'Capacitor Bank': [
      ReadingField(
        name: 'Current',
        unit: 'A',
        dataType: ReadingFieldDataType.number,
        isMandatory: true,
        frequency: ReadingFrequency.hourly,
        minRange: 0.00,
        maxRange: 2000.00,
      ),
      ReadingField(
        name: 'Power Factor',
        unit: '',
        dataType: ReadingFieldDataType.number,
        isMandatory: true,
        frequency: ReadingFrequency.hourly,
        minRange: -1.00,
        maxRange: 1.0,
      ),
    ],
    'Battery': [
      ReadingField(
        name: 'Voltage',
        unit: 'V',
        dataType: ReadingFieldDataType.number,
        isMandatory: true,
        frequency: ReadingFrequency.hourly,
        minRange: 80.00,
        maxRange: 150.00,
      ),
      ReadingField(
        name: 'Current',
        unit: 'A',
        dataType: ReadingFieldDataType.number,
        isMandatory: true,
        frequency: ReadingFrequency.hourly,
        minRange: 0.00,
        maxRange: 100.00,
      ),
    ],
    'Busbar': [
      ReadingField(
        name: 'Voltage',
        unit: 'kV',
        dataType: ReadingFieldDataType.number,
        isMandatory: true,
        frequency: ReadingFrequency.hourly,
        minRange: 10.00,
        maxRange: 1000.00,
      ),
    ],
  };

  final Map<String, List<ReadingField>> _defaultDailyFields = {
    'Battery': [
      ReadingField(
        name: 'Positive to Earth Voltage',
        unit: 'V',
        dataType: ReadingFieldDataType.number,
        isMandatory: true,
        frequency: ReadingFrequency.daily,
        minRange: -300.00,
        maxRange: 300.00,
      ),
      ReadingField(
        name: 'Negative to Earth Voltage',
        unit: 'V',
        dataType: ReadingFieldDataType.number,
        isMandatory: true,
        frequency: ReadingFrequency.daily,
        minRange: -300.00,
        maxRange: 300.00,
      ),
      ReadingField(
        name: 'Positive to Negative Voltage',
        unit: 'V',
        dataType: ReadingFieldDataType.number,
        isMandatory: true,
        frequency: ReadingFrequency.daily,
        minRange: -300.00,
        maxRange: 300.00,
      ),
      ...List.generate(
        8,
        (i) => ReadingField(
          name: 'Cell ${i + 1}',
          dataType: ReadingFieldDataType.group,
          isMandatory: true,
          frequency: ReadingFrequency.daily,
          nestedFields: [
            ReadingField(
              name: 'Cell Number',
              dataType: ReadingFieldDataType.number,
              isMandatory: true,
              minRange: 1.0,
              maxRange: 8.0,
              isInteger: true,
            ),
            ReadingField(
              name: 'Voltage',
              unit: 'V',
              dataType: ReadingFieldDataType.number,
              isMandatory: true,
              minRange: 1.8,
              maxRange: 2.4,
            ),
            ReadingField(
              name: 'Specific Gravity',
              unit: '',
              dataType: ReadingFieldDataType.number,
              isMandatory: true,
              minRange: 1000,
              maxRange: 1300,
            ),
          ],
        ),
      ),
    ],
  };

  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );
    _fetchReadingTemplates();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _fetchReadingTemplates() async {
    setState(() => _isLoading = true);
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('readingTemplates')
          .orderBy('bayType')
          .get();
      _templates = snapshot.docs
          .map((doc) => ReadingTemplate.fromFirestore(doc))
          .toList();
      _animationController.forward();
    } catch (e) {
      if (mounted) {
        SnackBarUtils.showSnackBar(
          context,
          'Failed to load reading templates: $e',
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showListView() {
    setState(() {
      _viewMode = ReadingTemplateViewMode.list;
      _templateToEdit = null;
      _selectedBayType = null;
      _templateDescription = null;
      _templateReadingFields = [];
    });
    _fetchReadingTemplates();
  }

  void _showFormForNew() {
    setState(() {
      _viewMode = ReadingTemplateViewMode.form;
      _templateToEdit = null;
      _selectedBayType = null;
      _templateDescription = null;
      _templateReadingFields = [];
    });
  }

  void _showFormForEdit(ReadingTemplate template) {
    setState(() {
      _viewMode = ReadingTemplateViewMode.form;
      _templateToEdit = template;
      _selectedBayType = template.bayType;
      _templateDescription = template.description;
      _templateReadingFields = template.readingFields
          .map(
            (field) =>
                field.toMap()..['isDefault'] = _isDefaultField(field.name),
          )
          .map((m) => Map<String, dynamic>.from(m))
          .toList();
    });
  }

  bool _isDefaultField(String fieldName) {
    final List<String> energyFieldsToKeepReadOnly = [
      'Previous Day Reading (Import)',
      'Current Day Reading (Import)',
      'Previous Day Reading (Export)',
      'Current Day Reading (Export)',
      'Previous Month Reading (Import)',
      'Current Month Reading (Import)',
      'Previous Month Reading (Export)',
      'Current Month Reading (Export)',
    ];
    if (energyFieldsToKeepReadOnly.contains(fieldName)) return true;
    return false;
  }

  void _onBayTypeSelected(String? newBayType) {
    setState(() {
      _selectedBayType = newBayType;
      _templateReadingFields.clear();

      if (newBayType != null) {
        final List<ReadingField> defaults = [
          if (newBayType != 'Battery' && newBayType != 'Busbar')
            ..._defaultEnergyFields,
          ...(_defaultHourlyFields[newBayType] ?? []),
          ...(_defaultDailyFields[newBayType] ?? []),
        ];

        for (final field in defaults) {
          final fieldMap = field.toMap();
          fieldMap['isDefault'] = _isDefaultField(field.name);
          _templateReadingFields.add(fieldMap);
        }

        // Debug
        // ignore: avoid_print
        print(
          'DEBUG: Added ${_templateReadingFields.length} fields for $newBayType',
        );
      }
    });
  }

  void _addReadingField() {
    setState(() {
      _templateReadingFields.add({
        'name': '',
        'dataType': ReadingFieldDataType.text.toString().split('.').last,
        'unit': '',
        'options': <String>[],
        'isMandatory': false,
        'frequency': ReadingFrequency.daily.toString().split('.').last,
        'description_remarks': '',
        'isDefault': false,
        'nestedFields': null,
        'minRange': null,
        'maxRange': null,
        'isInteger': false,
      });
    });
  }

  void _addGroupReadingField() {
    setState(() {
      _templateReadingFields.add({
        'name': '',
        'dataType': ReadingFieldDataType.group.toString().split('.').last,
        'unit': '',
        'options': <String>[],
        'isMandatory': false,
        'frequency': ReadingFrequency.daily.toString().split('.').last,
        'description_remarks': '',
        'isDefault': false,
        'nestedFields': <Map<String, dynamic>>[],
        'minRange': null,
        'maxRange': null,
        'isInteger': false,
      });
    });
  }

  void _removeReadingField(int index) {
    setState(() => _templateReadingFields.removeAt(index));
  }

  Future<void> _saveTemplate() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedBayType == null) {
      SnackBarUtils.showSnackBar(
        context,
        'Please select a Bay Type.',
        isError: true,
      );
      return;
    }

    setState(() => _isSaving = true);
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      if (mounted) {
        SnackBarUtils.showSnackBar(
          context,
          'Error: User not logged in.',
          isError: true,
        );
      }
      setState(() => _isSaving = false);
      return;
    }

    try {
      // Convert to ReadingField models
      final List<ReadingField> readingFields = _templateReadingFields
          .map((fieldMap) => ReadingField.fromMap(fieldMap))
          .toList();

      final newTemplate = ReadingTemplate(
        id: _templateToEdit?.id,
        bayType: _selectedBayType!,
        readingFields: readingFields,
        createdBy: currentUser.uid,
        createdAt: _templateToEdit?.createdAt ?? Timestamp.now(),
        description: _templateDescription,
        isActive: true,
      );

      if (_templateToEdit == null) {
        await FirebaseFirestore.instance
            .collection('readingTemplates')
            .add(newTemplate.toFirestore());
        if (mounted) {
          SnackBarUtils.showSnackBar(
            context,
            'Reading template created successfully!',
          );
        }
      } else {
        final updatedTemplate = newTemplate.withUpdatedTimestamp();
        await FirebaseFirestore.instance
            .collection('readingTemplates')
            .doc(_templateToEdit!.id)
            .update(updatedTemplate.toFirestore());
        if (mounted) {
          SnackBarUtils.showSnackBar(
            context,
            'Reading template updated successfully!',
          );
        }
      }
      _showListView();
    } catch (e) {
      if (mounted) {
        SnackBarUtils.showSnackBar(
          context,
          'Failed to save template: $e',
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _deleteTemplate(String? templateId) async {
    if (templateId == null) return;
    final bool confirm =
        await showDialog<bool>(
          context: context,
          builder: (BuildContext context) {
            final theme = Theme.of(context);
            final isDarkMode = theme.brightness == Brightness.dark;
            return AlertDialog(
              backgroundColor: isDarkMode
                  ? const Color(0xFF1C1C1E)
                  : Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              title: Row(
                children: [
                  Icon(Icons.warning_amber, color: theme.colorScheme.error),
                  const SizedBox(width: 8),
                  Text(
                    'Confirm Deletion',
                    style: TextStyle(color: isDarkMode ? Colors.white : null),
                  ),
                ],
              ),
              content: Text(
                'Are you sure you want to delete this reading template? This action cannot be undone and may affect existing bay assignments.',
                style: TextStyle(color: isDarkMode ? Colors.white : null),
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text(
                    'Cancel',
                    style: TextStyle(color: isDarkMode ? Colors.white70 : null),
                  ),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.error,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('Delete'),
                ),
              ],
            );
          },
        ) ??
        false;

    if (confirm) {
      try {
        await FirebaseFirestore.instance
            .collection('readingTemplates')
            .doc(templateId)
            .delete();
        if (mounted) {
          SnackBarUtils.showSnackBar(
            context,
            'Reading template deleted successfully!',
          );
        }
        _fetchReadingTemplates();
      } catch (e) {
        if (mounted) {
          SnackBarUtils.showSnackBar(
            context,
            'Failed to delete template: $e',
            isError: true,
          );
        }
      }
    }
  }

  void _debouncedUpdate(VoidCallback callback) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) setState(callback);
    });
  }

  Color _getBayTypeColor(String bayType) {
    switch (bayType.toLowerCase()) {
      case 'transformer':
        return Colors.orange;
      case 'line':
        return Colors.blue;
      case 'feeder':
        return Colors.green;
      case 'capacitor bank':
        return Colors.purple;
      case 'reactor':
        return Colors.red;
      case 'bus coupler':
        return Colors.teal;
      case 'battery':
        return Colors.amber;
      case 'busbar':
        return Colors.indigo;
      default:
        return Colors.grey;
    }
  }

  IconData _getBayTypeIcon(String bayType) {
    switch (bayType.toLowerCase()) {
      case 'transformer':
        return Icons.electrical_services;
      case 'line':
        return Icons.power_input;
      case 'feeder':
        return Icons.power;
      case 'capacitor bank':
        return Icons.battery_charging_full;
      case 'reactor':
        return Icons.device_hub;
      case 'bus coupler':
        return Icons.power_settings_new;
      case 'battery':
        return Icons.battery_std;
      case 'busbar':
        return Icons.horizontal_rule;
      default:
        return Icons.electrical_services;
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    if (_isLoading) {
      return Scaffold(
        backgroundColor: isDarkMode
            ? const Color(0xFF1C1C1E)
            : const Color(0xFFF8F9FA),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 60,
                height: 60,
                child: CircularProgressIndicator(
                  strokeWidth: 4,
                  valueColor: AlwaysStoppedAnimation(theme.colorScheme.primary),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Loading templates...',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: isDarkMode
                      ? Colors.white.withOpacity(0.7)
                      : theme.colorScheme.onSurface.withOpacity(0.7),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: isDarkMode
          ? const Color(0xFF1C1C1E)
          : const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: isDarkMode ? const Color(0xFF1C1C1E) : Colors.white,
        elevation: 0,
        toolbarHeight: 60,
        title: Text(
          _viewMode == ReadingTemplateViewMode.list
              ? 'Reading Templates'
              : (_templateToEdit == null
                    ? 'Create New Template'
                    : 'Edit Template'),
          style: TextStyle(
            color: isDarkMode ? Colors.white : theme.colorScheme.onSurface,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        leading: _viewMode == ReadingTemplateViewMode.form
            ? IconButton(
                icon: Icon(
                  Icons.arrow_back_ios,
                  color: isDarkMode
                      ? Colors.white
                      : theme.colorScheme.onSurface,
                ),
                onPressed: _showListView,
              )
            : IconButton(
                icon: Icon(
                  Icons.arrow_back_ios,
                  color: isDarkMode
                      ? Colors.white
                      : theme.colorScheme.onSurface,
                ),
                onPressed: () => Navigator.pop(context),
              ),
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: _viewMode == ReadingTemplateViewMode.list
            ? _buildListView(theme, isDarkMode)
            : _buildFormView(theme, isDarkMode),
      ),
      floatingActionButton: _viewMode == ReadingTemplateViewMode.list
          ? FloatingActionButton.extended(
              onPressed: _showFormForNew,
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: Colors.white,
              elevation: 2,
              icon: const Icon(Icons.add),
              label: const Text(
                'New Template',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            )
          : null,
    );
  }

  Widget _buildListView(ThemeData theme, bool isDarkMode) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: _templates.isEmpty
          ? Center(
              child: Container(
                margin: const EdgeInsets.all(32),
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: isDarkMode ? const Color(0xFF2C2C2E) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: isDarkMode
                          ? Colors.black.withOpacity(0.3)
                          : Colors.black.withOpacity(0.05),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.rule_outlined,
                      size: 80,
                      color: isDarkMode
                          ? Colors.white.withOpacity(0.4)
                          : Colors.grey.shade400,
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'No Reading Templates',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: isDarkMode
                            ? Colors.white
                            : theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Create templates to define reading parameters\nfor different bay types',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: isDarkMode
                            ? Colors.white.withOpacity(0.6)
                            : Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 32),
                    ElevatedButton.icon(
                      onPressed: _showFormForNew,
                      icon: const Icon(Icons.add),
                      label: const Text('Create First Template'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.colorScheme.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: _templates.map((template) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: isDarkMode
                          ? const Color(0xFF2C2C2E)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: isDarkMode
                              ? Colors.black.withOpacity(0.3)
                              : Colors.black.withOpacity(0.05),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(16),
                      leading: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: _getBayTypeColor(
                            template.bayType,
                          ).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          _getBayTypeIcon(template.bayType),
                          color: _getBayTypeColor(template.bayType),
                          size: 24,
                        ),
                      ),
                      title: Text(
                        template.bayType,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: isDarkMode
                              ? Colors.white
                              : theme.colorScheme.onSurface,
                        ),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          Text(
                            '${template.totalFieldCount} fields • Created ${DateFormat('MMM dd, yyyy').format(template.createdAt.toDate())}',
                            style: TextStyle(
                              fontSize: 13,
                              color: isDarkMode
                                  ? Colors.white.withOpacity(0.6)
                                  : Colors.grey.shade600,
                            ),
                          ),
                          if ((template.description ?? '').isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              template.description!,
                              style: TextStyle(
                                fontSize: 12,
                                color: isDarkMode
                                    ? Colors.white.withOpacity(0.5)
                                    : Colors.grey.shade500,
                                fontStyle: FontStyle.italic,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: _frequencies.map((freq) {
                              final count = template.readingFields
                                  .where(
                                    (field) =>
                                        field.frequency
                                            .toString()
                                            .split('.')
                                            .last ==
                                        freq,
                                  )
                                  .length;
                              if (count == 0) return const SizedBox.shrink();
                              return Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: _getFrequencyColor(
                                    freq,
                                  ).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                    color: _getFrequencyColor(
                                      freq,
                                    ).withOpacity(0.3),
                                  ),
                                ),
                                child: Text(
                                  '$freq: $count',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: _getFrequencyColor(freq),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                      trailing: PopupMenuButton<String>(
                        icon: Icon(
                          Icons.more_vert,
                          color: isDarkMode
                              ? Colors.white.withOpacity(0.7)
                              : Colors.grey.shade600,
                        ),
                        color: isDarkMode
                            ? const Color(0xFF2C2C2E)
                            : Colors.white,
                        onSelected: (String result) {
                          if (result == 'edit') {
                            _showFormForEdit(template);
                          } else if (result == 'delete') {
                            _deleteTemplate(template.id);
                          }
                        },
                        itemBuilder: (BuildContext context) => [
                          PopupMenuItem<String>(
                            value: 'edit',
                            child: ListTile(
                              leading: Icon(
                                Icons.edit_outlined,
                                size: 16,
                                color: theme.colorScheme.primary,
                              ),
                              title: Text(
                                'Edit',
                                style: TextStyle(
                                  color: isDarkMode ? Colors.white : null,
                                ),
                              ),
                              dense: true,
                            ),
                          ),
                          PopupMenuItem<String>(
                            value: 'delete',
                            child: ListTile(
                              leading: Icon(
                                Icons.delete_outline,
                                size: 16,
                                color: theme.colorScheme.error,
                              ),
                              title: Text(
                                'Delete',
                                style: TextStyle(
                                  color: theme.colorScheme.error,
                                ),
                              ),
                              dense: true,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
    );
  }

  Widget _buildFormView(ThemeData theme, bool isDarkMode) {
    return SingleChildScrollView(
      child: Column(
        children: [
          _buildBasicInfoSection(theme, isDarkMode),
          const SizedBox(height: 16),
          _buildBayTypeSection(theme, isDarkMode),
          const SizedBox(height: 16),
          _buildReadingFieldsSection(theme, isDarkMode),
          const SizedBox(height: 16),
          _buildActionButtons(theme, isDarkMode),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildBasicInfoSection(ThemeData theme, bool isDarkMode) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF2C2C2E) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: isDarkMode
                ? Colors.black.withOpacity(0.3)
                : Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.info_outline,
                  color: Colors.blue,
                  size: 16,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Template Information',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: isDarkMode
                      ? Colors.white
                      : theme.colorScheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextFormField(
            initialValue: _templateDescription,
            decoration: InputDecoration(
              labelText: 'Description (Optional)',
              hintText: 'Describe the purpose of this template',
              prefixIcon: Icon(
                Icons.description,
                color: theme.colorScheme.primary,
                size: 20,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              filled: true,
              fillColor: isDarkMode
                  ? const Color(0xFF3C3C3E)
                  : Colors.grey.shade50,
            ),
            style: TextStyle(
              color: isDarkMode ? Colors.white : theme.colorScheme.onSurface,
            ),
            maxLines: 2,
            onChanged: (value) =>
                _templateDescription = value.isEmpty ? null : value,
          ),
        ],
      ),
    );
  }

  Widget _buildBayTypeSection(ThemeData theme, bool isDarkMode) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF2C2C2E) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: isDarkMode
                ? Colors.black.withOpacity(0.3)
                : Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.category,
                  color: Colors.green,
                  size: 16,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Bay Type Configuration',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: isDarkMode
                      ? Colors.white
                      : theme.colorScheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: _selectedBayType,
            decoration: InputDecoration(
              labelText: 'Select Bay Type *',
              prefixIcon: Icon(
                Icons.electrical_services,
                color: theme.colorScheme.primary,
                size: 20,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              filled: true,
              fillColor: isDarkMode
                  ? const Color(0xFF3C3C3E)
                  : Colors.grey.shade50,
            ),
            dropdownColor: isDarkMode ? const Color(0xFF2C2C2E) : Colors.white,
            items: _bayTypes
                .map(
                  (type) => DropdownMenuItem<String>(
                    value: type,
                    child: Row(
                      children: [
                        Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: _getBayTypeColor(type).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Icon(
                            _getBayTypeIcon(type),
                            color: _getBayTypeColor(type),
                            size: 14,
                          ),
                        ),
                        const SizedBox(width: 12),
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
            onChanged: _onBayTypeSelected,
            validator: (value) =>
                value == null ? 'Please select a bay type' : null,
            style: TextStyle(
              color: isDarkMode ? Colors.white : theme.colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReadingFieldsSection(ThemeData theme, bool isDarkMode) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF2C2C2E) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: isDarkMode
                ? Colors.black.withOpacity(0.3)
                : Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: Colors.purple.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.list_alt,
                    color: Colors.purple,
                    size: 16,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Reading Fields',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: isDarkMode
                          ? Colors.white
                          : theme.colorScheme.onSurface,
                    ),
                  ),
                ),
                if (_templateReadingFields.isNotEmpty)
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
                      '${_templateReadingFields.length}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),

            // Use shared field list widget
            FieldListWidget(
              fields: _templateReadingFields,
              isEditable: true,
              dataTypes: _dataTypes,
              frequencies: _frequencies,
              onFieldsChanged: (updated) {
                // Keep changes reactive
                setState(() {
                  _templateReadingFields
                    ..clear()
                    ..addAll(updated.map((e) => Map<String, dynamic>.from(e)));
                });
              },
              onAddField: _addReadingField,
              onAddGroupField: _addGroupReadingField,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons(ThemeData theme, bool isDarkMode) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: _showListView,
              style: OutlinedButton.styleFrom(
                foregroundColor: isDarkMode
                    ? Colors.white.withOpacity(0.7)
                    : Colors.grey.shade700,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                side: BorderSide(
                  color: isDarkMode
                      ? Colors.white.withOpacity(0.6)
                      : Colors.grey.shade300,
                ),
              ),
              child: const Text(
                'Cancel',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: ElevatedButton(
              onPressed: _isSaving ? null : _saveTemplate,
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: 2,
              ),
              child: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      _templateToEdit == null
                          ? 'Create Template'
                          : 'Update Template',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

// import 'package:flutter/material.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:intl/intl.dart';
// import '../../models/reading_models.dart';
// import '../../models/user_model.dart';
// import '../../utils/snackbar_utils.dart';

// class BayReadingAssignmentScreen extends StatefulWidget {
//   final String bayId;
//   final String bayName;
//   final AppUser currentUser;

//   const BayReadingAssignmentScreen({
//     super.key,
//     required this.bayId,
//     required this.bayName,
//     required this.currentUser,
//   });

//   @override
//   State<BayReadingAssignmentScreen> createState() =>
//       _BayReadingAssignmentScreenState();
// }

// class _BayReadingAssignmentScreenState extends State<BayReadingAssignmentScreen>
//     with TickerProviderStateMixin {
//   final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
//   late AnimationController _animationController;
//   late Animation<double> _fadeAnimation;

//   bool _isLoading = true;
//   bool _isSaving = false;
//   String? _bayType;
//   List<ReadingTemplate> _availableReadingTemplates = [];
//   ReadingTemplate? _selectedTemplate;
//   String? _selectedTemplateId; // ✅ Use String ID for dropdown
//   String? _existingAssignmentId;
//   DateTime? _readingStartDate;
//   final List<Map<String, dynamic>> _instanceReadingFields = [];

//   // ✅ Controllers for field editing
//   final Map<String, TextEditingController> _textFieldControllers = {};
//   final Map<String, bool> _booleanFieldValues = {};
//   final Map<String, DateTime?> _dateFieldValues = {};
//   final Map<String, String?> _dropdownFieldValues = {};
//   final Map<String, TextEditingController> _booleanDescriptionControllers = {};
//   final Map<String, List<String>> _groupOptions = {};

//   final List<String> _dataTypes = ReadingFieldDataType.values
//       .map((e) => e.toString().split('.').last)
//       .toList();

//   final List<String> _frequencies = ReadingFrequency.values
//       .map((e) => e.toString().split('.').last)
//       .toList();

//   @override
//   void initState() {
//     super.initState();
//     _animationController = AnimationController(
//       duration: const Duration(milliseconds: 800),
//       vsync: this,
//     );
//     _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
//       CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
//     );
//     _initializeScreenData();
//   }

//   @override
//   void dispose() {
//     _animationController.dispose();
//     _textFieldControllers.forEach((key, controller) => controller.dispose());
//     _booleanDescriptionControllers.forEach(
//       (key, controller) => controller.dispose(),
//     );
//     super.dispose();
//   }

//   Future<void> _initializeScreenData() async {
//     setState(() => _isLoading = true);
//     try {
//       // Fetch bay information
//       final bayDoc = await FirebaseFirestore.instance
//           .collection('bays')
//           .doc(widget.bayId)
//           .get();

//       if (bayDoc.exists) {
//         _bayType = (bayDoc.data() as Map<String, dynamic>)['bayType'];
//       } else {
//         if (mounted) {
//           SnackBarUtils.showSnackBar(
//             context,
//             'Error: Bay not found.',
//             isError: true,
//           );
//           Navigator.of(context).pop();
//         }
//         return;
//       }

//       // Fetch available templates
//       final templatesSnapshot = await FirebaseFirestore.instance
//           .collection('readingTemplates')
//           .where('bayType', isEqualTo: _bayType)
//           .where('isActive', isEqualTo: true)
//           .orderBy('createdAt', descending: true)
//           .get();

//       _availableReadingTemplates = templatesSnapshot.docs
//           .map((doc) => ReadingTemplate.fromFirestore(doc))
//           .toList();

//       print(
//         'DEBUG: Fetched ${_availableReadingTemplates.length} templates for $_bayType',
//       );

//       // Check for existing assignment
//       final existingAssignmentSnapshot = await FirebaseFirestore.instance
//           .collection('bayReadingAssignments')
//           .where('bayId', isEqualTo: widget.bayId)
//           .limit(1)
//           .get();

//       if (existingAssignmentSnapshot.docs.isNotEmpty) {
//         final existingDoc = existingAssignmentSnapshot.docs.first;
//         _existingAssignmentId = existingDoc.id;
//         final assignedData = existingDoc.data();

//         // Set reading start date
//         if (assignedData.containsKey('readingStartDate') &&
//             assignedData['readingStartDate'] != null) {
//           _readingStartDate = (assignedData['readingStartDate'] as Timestamp)
//               .toDate();
//         } else {
//           _readingStartDate = DateTime.now();
//         }

//         // Set selected template
//         final existingTemplateId = assignedData['templateId'] as String?;
//         if (existingTemplateId != null) {
//           _selectedTemplateId = existingTemplateId;

//           try {
//             _selectedTemplate = _availableReadingTemplates.firstWhere(
//               (template) => template.id == existingTemplateId,
//             );
//           } catch (e) {
//             if (_availableReadingTemplates.isNotEmpty) {
//               _selectedTemplate = _availableReadingTemplates.first;
//               _selectedTemplateId = _selectedTemplate!.id;
//             } else {
//               _selectedTemplate = null;
//               _selectedTemplateId = null;
//             }
//           }
//         }

//         // Load assigned fields
//         final List<dynamic> assignedFieldsRaw =
//             assignedData['assignedFields'] as List<dynamic>? ?? [];
//         _instanceReadingFields.addAll(
//           assignedFieldsRaw.map((e) => Map<String, dynamic>.from(e)).toList(),
//         );
//         _initializeFieldControllers();
//       } else {
//         // New assignment
//         _readingStartDate = DateTime.now();
//         if (_availableReadingTemplates.isNotEmpty) {
//           _selectedTemplate = _availableReadingTemplates.first;
//           _selectedTemplateId = _selectedTemplate!.id;
//           _loadTemplateFields(_selectedTemplate!);
//         }
//       }

//       // Auto-fill previous readings if not the start date
//       await _autoFillPreviousReadings();

//       print('DEBUG: Selected template ID: $_selectedTemplateId');
//       print(
//         'DEBUG: Available template IDs: ${_availableReadingTemplates.map((t) => t.id).toList()}',
//       );

//       _animationController.forward();
//     } catch (e) {
//       print("Error loading bay reading assignment screen data: $e");
//       if (mounted) {
//         SnackBarUtils.showSnackBar(
//           context,
//           'Failed to load data: $e',
//           isError: true,
//         );
//       }
//     } finally {
//       setState(() => _isLoading = false);
//     }
//   }

//   void _loadTemplateFields(ReadingTemplate template) {
//     _instanceReadingFields.clear();
//     for (var field in template.readingFields) {
//       _addFieldToInstance(field, null);
//     }
//     _initializeFieldControllers();
//   }

//   void _addFieldToInstance(ReadingField field, String? parentGroupName) {
//     Map<String, dynamic> fieldMap = field.toMap();
//     if (parentGroupName != null) {
//       fieldMap['groupName'] = parentGroupName;
//     }

//     // Enhanced field properties for auto-fill functionality
//     fieldMap['isPreviousReading'] = field.name.toLowerCase().contains(
//       'previous',
//     );
//     fieldMap['isCurrentReading'] = field.name.toLowerCase().contains('current');
//     fieldMap['autoFilled'] = false;
//     fieldMap['readingStartDate'] = _readingStartDate;

//     // Link previous and current reading fields
//     if (fieldMap['isPreviousReading'] == true) {
//       String currentFieldName = field.name
//           .replaceAll('previous', 'current')
//           .replaceAll('Previous', 'Current');
//       fieldMap['linkedCurrentField'] = currentFieldName;
//     } else if (fieldMap['isCurrentReading'] == true) {
//       String previousFieldName = field.name
//           .replaceAll('current', 'previous')
//           .replaceAll('Current', 'Previous');
//       fieldMap['linkedPreviousField'] = previousFieldName;
//     }

//     _instanceReadingFields.add(fieldMap);

//     // If this is a group field, add its nested fields
//     if (field.dataType == ReadingFieldDataType.group && field.hasNestedFields) {
//       for (var nestedField in field.nestedFields!) {
//         _addFieldToInstance(nestedField, field.name);
//       }
//     }
//   }

//   Future<void> _autoFillPreviousReadings() async {
//     if (_readingStartDate == null) return;

//     final DateTime today = DateTime.now();
//     final DateTime startDate = DateTime(
//       _readingStartDate!.year,
//       _readingStartDate!.month,
//       _readingStartDate!.day,
//     );
//     final DateTime currentDate = DateTime(today.year, today.month, today.day);

//     // Only auto-fill if current date is after the start date
//     if (currentDate.isAfter(startDate)) {
//       try {
//         // Get yesterday's readings
//         final DateTime yesterday = currentDate.subtract(
//           const Duration(days: 1),
//         );

//         final QuerySnapshot yesterdayReadings = await FirebaseFirestore.instance
//             .collection('bayReadings')
//             .where('bayId', isEqualTo: widget.bayId)
//             .where('readingDate', isEqualTo: Timestamp.fromDate(yesterday))
//             .limit(1)
//             .get();

//         if (yesterdayReadings.docs.isNotEmpty) {
//           final Map<String, dynamic> yesterdayData =
//               yesterdayReadings.docs.first.data() as Map<String, dynamic>;
//           final List<dynamic> yesterdayFields = yesterdayData['readings'] ?? [];

//           // Auto-fill previous readings with yesterday's current readings
//           for (var fieldMap in _instanceReadingFields) {
//             final String fieldName = fieldMap['name'] as String;
//             final bool isPreviousReading =
//                 fieldMap['isPreviousReading'] as bool? ?? false;

//             if (isPreviousReading) {
//               final String? linkedCurrentField =
//                   fieldMap['linkedCurrentField'] as String?;

//               if (linkedCurrentField != null) {
//                 // Find yesterday's current reading value for this field
//                 final yesterdayCurrentReading = yesterdayFields.firstWhere(
//                   (field) => field['name'] == linkedCurrentField,
//                   orElse: () => null,
//                 );

//                 if (yesterdayCurrentReading != null) {
//                   final String dataType = fieldMap['dataType'] as String;

//                   switch (dataType) {
//                     case 'text':
//                     case 'number':
//                       if (_textFieldControllers.containsKey(fieldName)) {
//                         _textFieldControllers[fieldName]?.text =
//                             yesterdayCurrentReading['value']?.toString() ?? '';
//                       }
//                       break;
//                     case 'boolean':
//                       _booleanFieldValues[fieldName] =
//                           yesterdayCurrentReading['value'] as bool? ?? false;
//                       break;
//                     case 'date':
//                       if (yesterdayCurrentReading['value'] != null) {
//                         _dateFieldValues[fieldName] =
//                             (yesterdayCurrentReading['value'] as Timestamp)
//                                 .toDate();
//                       }
//                       break;
//                     case 'dropdown':
//                     case 'group':
//                       _dropdownFieldValues[fieldName] =
//                           yesterdayCurrentReading['value']?.toString();
//                       break;
//                   }

//                   // Mark field as auto-filled and make it read-only
//                   fieldMap['autoFilled'] = true;
//                   fieldMap['value'] = yesterdayCurrentReading['value'];
//                 }
//               }
//             }
//           }

//           setState(() {});
//         }
//       } catch (e) {
//         print("Error auto-filling previous readings: $e");
//       }
//     }
//   }

//   void _initializeFieldControllers() {
//     _textFieldControllers.clear();
//     _booleanFieldValues.clear();
//     _dateFieldValues.clear();
//     _dropdownFieldValues.clear();
//     _booleanDescriptionControllers.clear();
//     _groupOptions.clear();

//     for (var fieldMap in _instanceReadingFields) {
//       final String fieldName = fieldMap['name'] as String;
//       final String dataType = fieldMap['dataType'] as String;

//       switch (dataType) {
//         case 'text':
//         case 'number':
//           _textFieldControllers[fieldName] = TextEditingController();
//           break;
//         case 'boolean':
//           _booleanFieldValues[fieldName] = false;
//           _booleanDescriptionControllers[fieldName] = TextEditingController();
//           break;
//         case 'date':
//           _dateFieldValues[fieldName] = null;
//           break;
//         case 'dropdown':
//           _dropdownFieldValues[fieldName] = null;
//           break;
//         case 'group':
//           final List<String> options = List<String>.from(
//             fieldMap['options'] ?? [],
//           );
//           _groupOptions[fieldName] = options;
//           _dropdownFieldValues[fieldName] = null;
//           break;
//       }
//     }
//   }

//   void _onTemplateSelected(String? templateId) {
//     if (templateId == null) return;

//     // Find template by ID
//     final selectedTemplate = _availableReadingTemplates.firstWhere(
//       (template) => template.id == templateId,
//     );

//     setState(() {
//       _selectedTemplateId = templateId;
//       _selectedTemplate = selectedTemplate;
//       _clearAllControllers();
//       _loadTemplateFields(selectedTemplate);
//     });
//   }

//   void _clearAllControllers() {
//     _textFieldControllers.forEach((key, controller) => controller.dispose());
//     _booleanDescriptionControllers.forEach(
//       (key, controller) => controller.dispose(),
//     );
//     _textFieldControllers.clear();
//     _booleanFieldValues.clear();
//     _dateFieldValues.clear();
//     _dropdownFieldValues.clear();
//     _booleanDescriptionControllers.clear();
//     _groupOptions.clear();
//   }

//   void _addInstanceReadingField() {
//     setState(() {
//       final newField = <String, dynamic>{
//         'name': '',
//         'dataType': ReadingFieldDataType.text.toString().split('.').last,
//         'unit': '',
//         'options': <String>[],
//         'isMandatory': false,
//         'frequency': ReadingFrequency.daily.toString().split('.').last,
//         'description_remarks': '',
//         'nestedFields': null,
//         'groupName': null,
//         'isPreviousReading': false,
//         'isCurrentReading': false,
//         'autoFilled': false,
//         'linkedCurrentField': null,
//         'linkedPreviousField': null,
//       };
//       _instanceReadingFields.add(newField);
//     });
//   }

//   void _removeInstanceReadingField(int index) {
//     if (index < 0 || index >= _instanceReadingFields.length) return;

//     setState(() {
//       final fieldName = _instanceReadingFields[index]['name'] as String;
//       _instanceReadingFields.removeAt(index);

//       // Clean up controllers
//       _textFieldControllers.remove(fieldName)?.dispose();
//       _booleanFieldValues.remove(fieldName);
//       _dateFieldValues.remove(fieldName);
//       _dropdownFieldValues.remove(fieldName);
//       _booleanDescriptionControllers.remove(fieldName)?.dispose();
//       _groupOptions.remove(fieldName);
//     });
//   }

//   Future<void> _saveAssignment() async {
//     if (!_formKey.currentState!.validate()) return;

//     if (_selectedTemplate == null) {
//       SnackBarUtils.showSnackBar(
//         context,
//         'Please select a reading template.',
//         isError: true,
//       );
//       return;
//     }

//     if (_readingStartDate == null) {
//       SnackBarUtils.showSnackBar(
//         context,
//         'Please select a reading start date.',
//         isError: true,
//       );
//       return;
//     }

//     setState(() => _isSaving = true);

//     try {
//       final List<Map<String, dynamic>> finalAssignedFields = [];

//       for (var fieldMap in _instanceReadingFields) {
//         final String fieldName = fieldMap['name'] as String;

//         if (fieldName.trim().isEmpty) continue; // Skip empty field names

//         Map<String, dynamic> currentFieldData = Map<String, dynamic>.from(
//           fieldMap,
//         );

//         // Remove the template-specific values that shouldn't be saved
//         currentFieldData.remove('value');

//         finalAssignedFields.add(currentFieldData);
//       }

//       final Map<String, dynamic> assignmentData = {
//         'bayId': widget.bayId,
//         'bayType': _bayType,
//         'templateId': _selectedTemplate!.id!,
//         'assignedFields': finalAssignedFields,
//         'readingStartDate': Timestamp.fromDate(_readingStartDate!),
//         'recordedBy': widget.currentUser.uid,
//         'recordedAt': FieldValue.serverTimestamp(),
//         'isActive': true,
//         'totalFields': finalAssignedFields.length,
//       };

//       if (_existingAssignmentId == null) {
//         // Create new assignment
//         await FirebaseFirestore.instance
//             .collection('bayReadingAssignments')
//             .add(assignmentData);

//         if (mounted) {
//           SnackBarUtils.showSnackBar(
//             context,
//             'Reading template assigned successfully!',
//           );
//         }
//       } else {
//         // Update existing assignment
//         assignmentData['updatedAt'] = FieldValue.serverTimestamp();
//         await FirebaseFirestore.instance
//             .collection('bayReadingAssignments')
//             .doc(_existingAssignmentId)
//             .update(assignmentData);

//         if (mounted) {
//           SnackBarUtils.showSnackBar(
//             context,
//             'Reading assignment updated successfully!',
//           );
//         }
//       }

//       if (mounted) Navigator.of(context).pop();
//     } catch (e) {
//       print("Error saving bay reading assignment: $e");
//       if (mounted) {
//         SnackBarUtils.showSnackBar(
//           context,
//           'Failed to save assignment: $e',
//           isError: true,
//         );
//       }
//     } finally {
//       setState(() => _isSaving = false);
//     }
//   }

//   Future<void> _selectReadingStartDate(BuildContext context) async {
//     final DateTime? picked = await showDatePicker(
//       context: context,
//       initialDate: _readingStartDate ?? DateTime.now(),
//       firstDate: DateTime(2000),
//       lastDate: DateTime.now().add(const Duration(days: 365)),
//       builder: (context, child) {
//         return Theme(
//           data: Theme.of(context).copyWith(
//             colorScheme: Theme.of(context).colorScheme.copyWith(
//               primary: Theme.of(context).colorScheme.primary,
//               onPrimary: Theme.of(context).colorScheme.onPrimary,
//               surface: Theme.of(context).colorScheme.surface,
//               onSurface: Theme.of(context).colorScheme.onSurface,
//             ),
//             textButtonTheme: TextButtonThemeData(
//               style: TextButton.styleFrom(
//                 foregroundColor: Theme.of(context).colorScheme.primary,
//               ),
//             ),
//           ),
//           child: child!,
//         );
//       },
//     );

//     if (picked != null && picked != _readingStartDate) {
//       setState(() {
//         _readingStartDate = picked;
//       });

//       // Re-run auto-fill logic after date change
//       await _autoFillPreviousReadings();
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
//             : const Color(0xFFFAFAFA),
//         body: Center(
//           child: Column(
//             mainAxisAlignment: MainAxisAlignment.center,
//             children: [
//               CircularProgressIndicator(
//                 strokeWidth: 3,
//                 valueColor: AlwaysStoppedAnimation<Color>(
//                   theme.colorScheme.primary,
//                 ),
//               ),
//               const SizedBox(height: 16),
//               Text(
//                 'Loading assignment data...',
//                 style: TextStyle(
//                   fontSize: 16,
//                   fontWeight: FontWeight.w500,
//                   color: isDarkMode ? Colors.white70 : Colors.grey[700],
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
//           : const Color(0xFFFAFAFA),
//       appBar: _buildAppBar(theme, isDarkMode),
//       body: CustomScrollView(
//         slivers: [
//           SliverToBoxAdapter(
//             child: Padding(
//               padding: const EdgeInsets.all(16.0),
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   _buildHeaderSection(theme, isDarkMode),
//                   const SizedBox(height: 16),
//                   _buildDateSelector(theme, isDarkMode),
//                   const SizedBox(height: 16),
//                   _buildTemplateSelector(theme, isDarkMode),
//                   if (_selectedTemplate != null) ...[
//                     const SizedBox(height: 16),
//                     _buildFieldsSection(theme, isDarkMode),
//                   ],
//                   const SizedBox(
//                     height: 80,
//                   ), // Space for floating action button
//                 ],
//               ),
//             ),
//           ),
//         ],
//       ),
//       floatingActionButton: _buildActionButton(theme, isDarkMode),
//       floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
//     );
//   }

//   PreferredSizeWidget _buildAppBar(ThemeData theme, bool isDarkMode) {
//     return AppBar(
//       backgroundColor: isDarkMode
//           ? const Color(0xFF1C1C1E)
//           : const Color(0xFFFAFAFA),
//       elevation: 0,
//       leading: IconButton(
//         icon: Icon(Icons.arrow_back_ios, color: theme.colorScheme.primary),
//         onPressed: () => Navigator.of(context).pop(),
//       ),
//       title: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Text(
//             'Reading Assignment',
//             style: TextStyle(
//               fontSize: 20,
//               fontWeight: FontWeight.w600,
//               color: isDarkMode ? Colors.white : Colors.grey[900],
//             ),
//           ),
//           Text(
//             widget.bayName,
//             style: TextStyle(
//               fontSize: 14,
//               fontWeight: FontWeight.w500,
//               color: theme.colorScheme.primary,
//             ),
//             overflow: TextOverflow.ellipsis,
//           ),
//         ],
//       ),
//       bottom: PreferredSize(
//         preferredSize: const Size.fromHeight(1),
//         child: Divider(
//           height: 1,
//           color: isDarkMode ? Colors.grey[700] : Colors.grey,
//         ),
//       ),
//     );
//   }

//   Widget _buildHeaderSection(ThemeData theme, bool isDarkMode) {
//     return FadeTransition(
//       opacity: _fadeAnimation,
//       child: Container(
//         padding: const EdgeInsets.all(16),
//         decoration: BoxDecoration(
//           color: isDarkMode ? const Color(0xFF2C2C2E) : Colors.white,
//           borderRadius: BorderRadius.circular(12),
//           boxShadow: [
//             BoxShadow(
//               color: isDarkMode
//                   ? Colors.black.withOpacity(0.3)
//                   : Colors.black.withOpacity(0.05),
//               blurRadius: 8,
//               offset: const Offset(0, 2),
//             ),
//           ],
//         ),
//         child: Row(
//           children: [
//             Container(
//               padding: const EdgeInsets.all(10),
//               decoration: BoxDecoration(
//                 color: theme.colorScheme.primary.withOpacity(0.2),
//                 shape: BoxShape.circle,
//               ),
//               child: Icon(
//                 Icons.electrical_services,
//                 color: theme.colorScheme.primary,
//                 size: 24,
//               ),
//             ),
//             const SizedBox(width: 12),
//             Expanded(
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   Text(
//                     'Bay Information',
//                     style: TextStyle(
//                       fontSize: 18,
//                       fontWeight: FontWeight.w600,
//                       color: isDarkMode ? Colors.white : Colors.grey[900],
//                     ),
//                   ),
//                   const SizedBox(height: 4),
//                   Text(
//                     'Type: ${_bayType ?? 'Unknown'}',
//                     style: TextStyle(
//                       fontSize: 14,
//                       fontWeight: FontWeight.w500,
//                       color: isDarkMode ? Colors.white70 : Colors.grey[700],
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//             if (_existingAssignmentId != null)
//               Container(
//                 padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
//                 decoration: BoxDecoration(
//                   color: theme.colorScheme.secondary.withOpacity(0.1),
//                   borderRadius: BorderRadius.circular(6),
//                 ),
//                 child: Text(
//                   'Updating',
//                   style: TextStyle(
//                     fontSize: 12,
//                     color: theme.colorScheme.secondary,
//                     fontWeight: FontWeight.w600,
//                   ),
//                 ),
//               ),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _buildDateSelector(ThemeData theme, bool isDarkMode) {
//     final DateTime today = DateTime.now();
//     final DateTime? startDate = _readingStartDate;
//     final bool isStartDate =
//         startDate != null &&
//         DateTime(today.year, today.month, today.day).isAtSameMomentAs(
//           DateTime(startDate.year, startDate.month, startDate.day),
//         );

//     return FadeTransition(
//       opacity: _fadeAnimation,
//       child: GestureDetector(
//         onTap: () => _selectReadingStartDate(context),
//         child: Container(
//           padding: const EdgeInsets.all(16),
//           decoration: BoxDecoration(
//             color: isDarkMode ? const Color(0xFF2C2C2E) : Colors.white,
//             borderRadius: BorderRadius.circular(12),
//             boxShadow: [
//               BoxShadow(
//                 color: isDarkMode
//                     ? Colors.black.withOpacity(0.3)
//                     : Colors.black.withOpacity(0.05),
//                 blurRadius: 8,
//                 offset: const Offset(0, 2),
//               ),
//             ],
//           ),
//           child: Column(
//             children: [
//               Row(
//                 children: [
//                   Container(
//                     padding: const EdgeInsets.all(8),
//                     decoration: BoxDecoration(
//                       color: theme.colorScheme.secondary.withOpacity(0.15),
//                       shape: BoxShape.circle,
//                     ),
//                     child: Icon(
//                       Icons.calendar_today,
//                       color: theme.colorScheme.secondary,
//                       size: 20,
//                     ),
//                   ),
//                   const SizedBox(width: 12),
//                   Expanded(
//                     child: Column(
//                       crossAxisAlignment: CrossAxisAlignment.start,
//                       children: [
//                         Text(
//                           'Reading Start Date',
//                           style: TextStyle(
//                             fontSize: 16,
//                             fontWeight: FontWeight.w600,
//                             color: isDarkMode ? Colors.white : Colors.grey[900],
//                           ),
//                         ),
//                         const SizedBox(height: 4),
//                         Text(
//                           DateFormat(
//                             'EEEE, MMM dd, yyyy',
//                           ).format(_readingStartDate ?? DateTime.now()),
//                           style: TextStyle(
//                             fontSize: 14,
//                             color: theme.colorScheme.secondary,
//                             fontWeight: FontWeight.w500,
//                           ),
//                         ),
//                       ],
//                     ),
//                   ),
//                   Icon(
//                     Icons.edit_calendar,
//                     color: theme.colorScheme.primary,
//                     size: 20,
//                   ),
//                 ],
//               ),
//               if (!isStartDate)
//                 Container(
//                   margin: const EdgeInsets.only(top: 12),
//                   padding: const EdgeInsets.all(8),
//                   decoration: BoxDecoration(
//                     color: Colors.orange.withOpacity(0.1),
//                     borderRadius: BorderRadius.circular(6),
//                     border: Border.all(color: Colors.orange.withOpacity(0.3)),
//                   ),
//                   child: Row(
//                     children: [
//                       Icon(Icons.auto_awesome, size: 16, color: Colors.orange),
//                       const SizedBox(width: 8),
//                       Expanded(
//                         child: Text(
//                           'Previous readings will be auto-filled from previous day\'s current readings',
//                           style: TextStyle(
//                             fontSize: 12,
//                             color: Colors.orange[700],
//                             fontWeight: FontWeight.w500,
//                           ),
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }

//   Widget _buildTemplateSelector(ThemeData theme, bool isDarkMode) {
//     return FadeTransition(
//       opacity: _fadeAnimation,
//       child: Container(
//         padding: const EdgeInsets.all(16),
//         decoration: BoxDecoration(
//           color: isDarkMode ? const Color(0xFF2C2C2E) : Colors.white,
//           borderRadius: BorderRadius.circular(12),
//           boxShadow: [
//             BoxShadow(
//               color: isDarkMode
//                   ? Colors.black.withOpacity(0.3)
//                   : Colors.black.withOpacity(0.05),
//               blurRadius: 8,
//               offset: const Offset(0, 2),
//             ),
//           ],
//         ),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Row(
//               children: [
//                 Container(
//                   padding: const EdgeInsets.all(8),
//                   decoration: BoxDecoration(
//                     color: theme.colorScheme.tertiary.withOpacity(0.15),
//                     shape: BoxShape.circle,
//                   ),
//                   child: Icon(
//                     Icons.description,
//                     color: theme.colorScheme.tertiary,
//                     size: 20,
//                   ),
//                 ),
//                 const SizedBox(width: 12),
//                 Expanded(
//                   child: Text(
//                     'Reading Template',
//                     style: TextStyle(
//                       fontSize: 18,
//                       fontWeight: FontWeight.w600,
//                       color: isDarkMode ? Colors.white : Colors.grey[900],
//                     ),
//                   ),
//                 ),
//                 if (_availableReadingTemplates.isNotEmpty)
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
//                       '${_availableReadingTemplates.length} available',
//                       style: TextStyle(
//                         fontSize: 12,
//                         color: theme.colorScheme.primary,
//                         fontWeight: FontWeight.w600,
//                       ),
//                     ),
//                   ),
//               ],
//             ),
//             const SizedBox(height: 12),
//             if (_availableReadingTemplates.isEmpty)
//               Container(
//                 padding: const EdgeInsets.all(12),
//                 decoration: BoxDecoration(
//                   color: theme.colorScheme.error.withOpacity(0.1),
//                   borderRadius: BorderRadius.circular(8),
//                 ),
//                 child: Row(
//                   children: [
//                     Icon(
//                       Icons.warning_amber,
//                       color: theme.colorScheme.error,
//                       size: 20,
//                     ),
//                     const SizedBox(width: 12),
//                     Expanded(
//                       child: Text(
//                         'No reading templates available for "${_bayType ?? 'this bay type'}". Create templates in Admin Dashboard.',
//                         style: TextStyle(
//                           fontSize: 14,
//                           fontWeight: FontWeight.w500,
//                           color: theme.colorScheme.error,
//                         ),
//                       ),
//                     ),
//                   ],
//                 ),
//               )
//             else
//               DropdownButtonFormField<String>(
//                 // ✅ FIX: Use String instead of ReadingTemplate
//                 value: _selectedTemplateId, // ✅ FIX: Use String ID as value
//                 decoration: InputDecoration(
//                   labelText: 'Select Template',
//                   labelStyle: TextStyle(
//                     color: isDarkMode ? Colors.white70 : Colors.grey[700],
//                     fontSize: 14,
//                   ),
//                   prefixIcon: Icon(
//                     Icons.list_alt,
//                     color: theme.colorScheme.primary,
//                     size: 20,
//                   ),
//                   border: OutlineInputBorder(
//                     borderRadius: BorderRadius.circular(8),
//                     borderSide: BorderSide(
//                       color: isDarkMode ? Colors.grey[700]! : Colors.grey!,
//                     ),
//                   ),
//                   enabledBorder: OutlineInputBorder(
//                     borderRadius: BorderRadius.circular(8),
//                     borderSide: BorderSide(
//                       color: isDarkMode ? Colors.grey[700]! : Colors.grey!,
//                     ),
//                   ),
//                   filled: true,
//                   fillColor: isDarkMode
//                       ? const Color(0xFF3C3C3E)
//                       : Colors.grey[12],
//                   contentPadding: const EdgeInsets.symmetric(
//                     horizontal: 12,
//                     vertical: 12,
//                   ),
//                 ),
//                 dropdownColor: isDarkMode
//                     ? const Color(0xFF2C2C2E)
//                     : Colors.white,
//                 isExpanded: true,
//                 items: _availableReadingTemplates.map((template) {
//                   return DropdownMenuItem<String>(
//                     // ✅ FIX: Use String
//                     value: template.id, // ✅ FIX: Use template ID as value
//                     child: Column(
//                       crossAxisAlignment: CrossAxisAlignment.start,
//                       mainAxisSize: MainAxisSize.min,
//                       children: [
//                         Text(
//                           '${template.bayType} - ${template.totalFieldCount} fields',
//                           style: TextStyle(
//                             fontWeight: FontWeight.w600,
//                             fontSize: 14,
//                             color: isDarkMode ? Colors.white : Colors.grey[900],
//                           ),
//                           overflow: TextOverflow.ellipsis,
//                         ),
//                         if (template.description != null &&
//                             template.description!.isNotEmpty)
//                           Text(
//                             template.description!,
//                             style: TextStyle(
//                               fontSize: 12,
//                               color: isDarkMode
//                                   ? Colors.white70
//                                   : Colors.grey[600],
//                             ),
//                             overflow: TextOverflow.ellipsis,
//                           ),
//                       ],
//                     ),
//                   );
//                 }).toList(),
//                 onChanged: _onTemplateSelected, // ✅ FIX: Now accepts String
//                 validator: (value) =>
//                     value == null ? 'Please select a template' : null,
//               ),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _buildFieldsSection(ThemeData theme, bool isDarkMode) {
//     return Container(
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
//                   padding: const EdgeInsets.all(8),
//                   decoration: BoxDecoration(
//                     color: theme.colorScheme.primary.withOpacity(0.15),
//                     shape: BoxShape.circle,
//                   ),
//                   child: Icon(
//                     Icons.settings,
//                     color: theme.colorScheme.primary,
//                     size: 20,
//                   ),
//                 ),
//                 const SizedBox(width: 12),
//                 Expanded(
//                   child: Text(
//                     'Reading Fields Configuration',
//                     style: TextStyle(
//                       fontSize: 18,
//                       fontWeight: FontWeight.w600,
//                       color: isDarkMode ? Colors.white : Colors.grey[900],
//                     ),
//                   ),
//                 ),
//                 if (_instanceReadingFields.isNotEmpty)
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
//                       '${_instanceReadingFields.length} field${_instanceReadingFields.length == 1 ? '' : 's'}',
//                       style: TextStyle(
//                         fontSize: 12,
//                         color: theme.colorScheme.primary,
//                         fontWeight: FontWeight.w500,
//                       ),
//                     ),
//                   ),
//               ],
//             ),
//             const SizedBox(height: 16),
//             if (_instanceReadingFields.isEmpty)
//               Container(
//                 padding: const EdgeInsets.all(16),
//                 decoration: BoxDecoration(
//                   color: isDarkMode ? const Color(0xFF3C3C3E) : Colors.grey[50],
//                   borderRadius: BorderRadius.circular(8),
//                 ),
//                 child: Column(
//                   children: [
//                     Icon(
//                       Icons.inbox,
//                       size: 48,
//                       color: isDarkMode ? Colors.grey[600] : Colors.grey,
//                     ),
//                     const SizedBox(height: 8),
//                     Text(
//                       'No fields configured',
//                       style: TextStyle(
//                         fontSize: 16,
//                         fontWeight: FontWeight.w600,
//                         color: isDarkMode ? Colors.grey[400] : Colors.grey,
//                       ),
//                     ),
//                     Text(
//                       'Select a template to see field configuration',
//                       style: TextStyle(
//                         fontSize: 14,
//                         color: isDarkMode ? Colors.grey[500] : Colors.grey,
//                       ),
//                     ),
//                   ],
//                 ),
//               )
//             else
//               Column(
//                 children: _instanceReadingFields.asMap().entries.map((entry) {
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
//             SizedBox(
//               width: double.infinity,
//               child: OutlinedButton.icon(
//                 onPressed: _addInstanceReadingField,
//                 icon: Icon(
//                   Icons.add_circle_outline,
//                   color: theme.colorScheme.primary,
//                   size: 20,
//                 ),
//                 label: Text(
//                   'Add Custom Field',
//                   style: TextStyle(
//                     fontWeight: FontWeight.w600,
//                     color: theme.colorScheme.primary,
//                   ),
//                 ),
//                 style: OutlinedButton.styleFrom(
//                   padding: const EdgeInsets.symmetric(vertical: 12),
//                   side: BorderSide(color: theme.colorScheme.primary),
//                   shape: RoundedRectangleBorder(
//                     borderRadius: BorderRadius.circular(8),
//                   ),
//                   backgroundColor: theme.colorScheme.primary.withOpacity(0.05),
//                 ),
//               ),
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
//             : (isDarkMode ? const Color(0xFF3C3C3E) : Colors.grey[50]),
//         borderRadius: BorderRadius.circular(12),
//         border: Border.all(
//           color: isDefault
//               ? theme.colorScheme.primary.withOpacity(0.3)
//               : (isDarkMode
//                     ? Colors.white.withOpacity(0.1)
//                     : Colors.grey[200]!),
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
//               const Spacer(),
//               if (!isDefault)
//                 IconButton(
//                   onPressed: () => _removeInstanceReadingField(index),
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
//               : (value) => setState(() => fieldDef['name'] = value),
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
//                       : (value) => setState(() {
//                           fieldDef['dataType'] = value!;
//                           if (value != 'dropdown') fieldDef['options'] = [];
//                           if (value != 'number') {
//                             fieldDef['unit'] = '';
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
//                       : (value) =>
//                             setState(() => fieldDef['frequency'] = value!),
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
//             TextFormField(
//               initialValue: fieldDef['unit'],
//               decoration: InputDecoration(
//                 labelText: 'Unit',
//                 hintText: 'e.g., V, A, kW',
//                 prefixIcon: Icon(
//                   Icons.straighten,
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
//                   : (value) => setState(() => fieldDef['unit'] = value),
//               readOnly: isDefault,
//             ),
//             const SizedBox(height: 12),
//           ],
//           if (fieldDef['dataType'] == 'dropdown') ...[
//             TextFormField(
//               initialValue: (fieldDef['options'] as List?)?.join(', '),
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
//                   : (value) => setState(
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
//             const SizedBox(height: 12),
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
//                   : (value) =>
//                         setState(() => fieldDef['description_remarks'] = value),
//               readOnly: isDefault,
//             ),
//             const SizedBox(height: 12),
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
//                 : (value) => setState(() => fieldDef['frequency'] = value!),
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
//               : (value) =>
//                     setState(() => fieldDef['isMandatory'] = value ?? false),
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
//     final nestedFields = fieldDef['nestedFields'] as List;
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
//             onChanged: (value) => setState(() => nestedField['name'] = value),
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
//                   onChanged: (value) => setState(() {
//                     nestedField['dataType'] = value!;
//                     if (value != 'dropdown') nestedField['options'] = [];
//                     if (value != 'number') {
//                       nestedField['unit'] = '';
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
//                         setState(() => nestedField['unit'] = value),
//                   ),
//                 ),
//               ],
//             ],
//           ),
//           if (nestedField['dataType'] == 'dropdown') ...[
//             const SizedBox(height: 8),
//             TextFormField(
//               initialValue: (nestedField['options'] as List?)?.join(', '),
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
//               onChanged: (value) => setState(
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
//             onChanged: (value) =>
//                 setState(() => nestedField['isMandatory'] = value ?? false),
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

//   void _addNestedReadingField(Map<String, dynamic> groupField) {
//     setState(() {
//       (groupField['nestedFields'] as List).add({
//         'name': '',
//         'dataType': ReadingFieldDataType.text.toString().split('.').last,
//         'unit': '',
//         'options': [],
//         'isMandatory': false,
//         'description_remarks': '',
//       });
//     });
//   }

//   void _removeNestedReadingField(
//     Map<String, dynamic> groupField,
//     int nestedIndex,
//   ) {
//     setState(() {
//       (groupField['nestedFields'] as List).removeAt(nestedIndex);
//     });
//   }

//   Widget _buildActionButton(ThemeData theme, bool isDarkMode) {
//     final bool canSave = _selectedTemplate != null && !_isSaving;

//     return FloatingActionButton.extended(
//       onPressed: canSave ? _saveAssignment : null,
//       backgroundColor: canSave ? theme.colorScheme.primary : Colors.grey[400],
//       elevation: canSave ? 2 : 0,
//       label: Row(
//         mainAxisSize: MainAxisSize.min,
//         children: [
//           if (_isSaving)
//             const SizedBox(
//               width: 16,
//               height: 16,
//               child: CircularProgressIndicator(
//                 strokeWidth: 2,
//                 valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
//               ),
//             )
//           else
//             Icon(
//               _existingAssignmentId == null ? Icons.save : Icons.update,
//               size: 20,
//             ),
//           const SizedBox(width: 8),
//           Text(
//             _isSaving
//                 ? 'Saving...'
//                 : (_existingAssignmentId == null
//                       ? 'Save Assignment'
//                       : 'Update Assignment'),
//             style: const TextStyle(
//               fontSize: 16,
//               fontWeight: FontWeight.w600,
//               color: Colors.white,
//             ),
//           ),
//         ],
//       ),
//       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
//     );
//   }

//   Color _getDataTypeColor(String dataType) {
//     switch (dataType) {
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
//     switch (dataType) {
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
// }
// lib/screens/substation/bay_reading_assignment_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import '../../models/reading_models.dart';
import '../../models/user_model.dart';
import '../../utils/snackbar_utils.dart';

// Common, reusable field UI
import '../../widgets/reading_field_widgets.dart';

class BayReadingAssignmentScreen extends StatefulWidget {
  final String bayId;
  final String bayName;
  final AppUser currentUser;

  const BayReadingAssignmentScreen({
    super.key,
    required this.bayId,
    required this.bayName,
    required this.currentUser,
  });

  @override
  State<BayReadingAssignmentScreen> createState() =>
      _BayReadingAssignmentScreenState();
}

class _BayReadingAssignmentScreenState extends State<BayReadingAssignmentScreen>
    with TickerProviderStateMixin {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  bool _isLoading = true;
  bool _isSaving = false;

  String? _bayType;

  List<ReadingTemplate> _availableReadingTemplates = [];
  ReadingTemplate? _selectedTemplate;
  String? _selectedTemplateId;

  String? _existingAssignmentId;
  DateTime? _readingStartDate;

  // The single source of truth for fields displayed/edited in UI
  final List<Map<String, dynamic>> _instanceReadingFields = [];

  // Local helpers (for auto-fill and editing convenience)
  final Map<String, TextEditingController> _textFieldControllers = {};
  final Map<String, bool> _booleanFieldValues = {};
  final Map<String, DateTime?> _dateFieldValues = {};
  final Map<String, String?> _dropdownFieldValues = {};
  final Map<String, TextEditingController> _booleanDescriptionControllers = {};
  final Map<String, List<String>> _groupOptions = {};

  // Static choices for the common widgets
  final List<String> _dataTypes = ReadingFieldDataType.values
      .map((e) => e.toString().split('.').last)
      .toList();
  final List<String> _frequencies = ReadingFrequency.values
      .map((e) => e.toString().split('.').last)
      .toList();

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
    _initializeScreenData();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _textFieldControllers.forEach((key, controller) => controller.dispose());
    _booleanDescriptionControllers.forEach(
      (key, controller) => controller.dispose(),
    );
    super.dispose();
  }

  Future<void> _initializeScreenData() async {
    setState(() => _isLoading = true);
    try {
      // 1) Fetch bay info
      final bayDoc = await FirebaseFirestore.instance
          .collection('bays')
          .doc(widget.bayId)
          .get();
      if (!bayDoc.exists) {
        if (!mounted) return;
        SnackBarUtils.showSnackBar(
          context,
          'Error: Bay not found.',
          isError: true,
        );
        Navigator.of(context).pop();
        return;
      }
      _bayType = (bayDoc.data() as Map<String, dynamic>)['bayType'] as String?;

      // 2) Fetch templates for this bay type
      final templatesSnapshot = await FirebaseFirestore.instance
          .collection('readingTemplates')
          .where('bayType', isEqualTo: _bayType)
          .where('isActive', isEqualTo: true)
          .orderBy('createdAt', descending: true)
          .get();

      _availableReadingTemplates = templatesSnapshot.docs
          .map((doc) => ReadingTemplate.fromFirestore(doc))
          .toList();

      // 3) Check existing assignment
      final existingAssignmentSnapshot = await FirebaseFirestore.instance
          .collection('bayReadingAssignments')
          .where('bayId', isEqualTo: widget.bayId)
          .limit(1)
          .get();

      if (existingAssignmentSnapshot.docs.isNotEmpty) {
        final existingDoc = existingAssignmentSnapshot.docs.first;
        _existingAssignmentId = existingDoc.id;
        final assignedData = existingDoc.data() as Map<String, dynamic>;

        // reading start date
        if (assignedData.containsKey('readingStartDate') &&
            assignedData['readingStartDate'] != null) {
          _readingStartDate = (assignedData['readingStartDate'] as Timestamp)
              .toDate();
        } else {
          _readingStartDate = DateTime.now();
        }

        // selected template
        final existingTemplateId = assignedData['templateId'] as String?;
        if (existingTemplateId != null) {
          _selectedTemplateId = existingTemplateId;
          try {
            _selectedTemplate = _availableReadingTemplates.firstWhere(
              (t) => t.id == existingTemplateId,
            );
          } catch (_) {
            if (_availableReadingTemplates.isNotEmpty) {
              _selectedTemplate = _availableReadingTemplates.first;
              _selectedTemplateId = _selectedTemplate!.id;
            } else {
              _selectedTemplate = null;
              _selectedTemplateId = null;
            }
          }
        }

        // assigned fields
        final List assignedFieldsRaw =
            assignedData['assignedFields'] as List? ?? [];
        _instanceReadingFields
          ..clear()
          ..addAll(assignedFieldsRaw.map((e) => Map<String, dynamic>.from(e)));

        _initializeFieldControllers();
      } else {
        // New assignment default state
        _readingStartDate = DateTime.now();

        if (_availableReadingTemplates.isNotEmpty) {
          _selectedTemplate = _availableReadingTemplates.first;
          _selectedTemplateId = _selectedTemplate!.id;
          _loadTemplateFields(_selectedTemplate!);

          // Auto-fill "Previous" fields if start date is not today
          await _autoFillPreviousReadings();
        }
      }

      _animationController.forward();
    } catch (e) {
      if (!mounted) return;
      SnackBarUtils.showSnackBar(
        context,
        'Failed to load data: $e',
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _loadTemplateFields(ReadingTemplate template) {
    _instanceReadingFields.clear();
    for (final field in template.readingFields) {
      _addFieldToInstance(field, null);
    }
    _initializeFieldControllers();
  }

  void _addFieldToInstance(ReadingField field, String? parentGroupName) {
    final Map<String, dynamic> fieldMap = field.toMap();

    if (parentGroupName != null) {
      fieldMap['groupName'] = parentGroupName;
    }

    // Augment with auto-fill properties used in assignment screen
    fieldMap['isPreviousReading'] = field.name.toLowerCase().contains(
      'previous',
    );
    fieldMap['isCurrentReading'] = field.name.toLowerCase().contains('current');
    fieldMap['autoFilled'] = false;
    fieldMap['readingStartDate'] = _readingStartDate;

    if (fieldMap['isPreviousReading'] == true) {
      final currentFieldName = field.name
          .replaceAll('previous', 'current')
          .replaceAll('Previous', 'Current');
      fieldMap['linkedCurrentField'] = currentFieldName;
    } else if (fieldMap['isCurrentReading'] == true) {
      final previousFieldName = field.name
          .replaceAll('current', 'previous')
          .replaceAll('Current', 'Previous');
      fieldMap['linkedPreviousField'] = previousFieldName;
    }

    _instanceReadingFields.add(fieldMap);

    // Recurse nested fields for groups
    if (field.dataType == ReadingFieldDataType.group && field.hasNestedFields) {
      for (final nestedField in field.nestedFields!) {
        _addFieldToInstance(nestedField, field.name);
      }
    }
  }

  Future<void> _autoFillPreviousReadings() async {
    if (_readingStartDate == null) return;

    final DateTime today = DateTime.now();
    final DateTime startDate = DateTime(
      _readingStartDate!.year,
      _readingStartDate!.month,
      _readingStartDate!.day,
    );
    final DateTime currentDate = DateTime(today.year, today.month, today.day);

    // Only auto-fill if current date is after the start date (i.e., not the starting day)
    if (!currentDate.isAfter(startDate)) return;

    try {
      final DateTime yesterday = currentDate.subtract(const Duration(days: 1));
      final QuerySnapshot yesterdayReadings = await FirebaseFirestore.instance
          .collection('bayReadings')
          .where('bayId', isEqualTo: widget.bayId)
          .where('readingDate', isEqualTo: Timestamp.fromDate(yesterday))
          .limit(1)
          .get();

      if (yesterdayReadings.docs.isEmpty) return;

      final Map<String, dynamic> yesterdayData =
          yesterdayReadings.docs.first.data() as Map<String, dynamic>;
      final List yesterdayFields = (yesterdayData['readings'] ?? []) as List;

      for (final fieldMap in _instanceReadingFields) {
        final String fieldName = fieldMap['name'] as String;
        final bool isPrevious = fieldMap['isPreviousReading'] as bool? ?? false;

        if (!isPrevious) continue;

        final String? linkedCurrentField =
            fieldMap['linkedCurrentField'] as String?;
        if (linkedCurrentField == null) continue;

        final dynamic yesterdayCurrentReading = yesterdayFields.firstWhere(
          (e) => (e as Map)['name'] == linkedCurrentField,
          orElse: () => null,
        );

        if (yesterdayCurrentReading == null) continue;

        final String dataType = fieldMap['dataType'] as String;
        final dynamic value = (yesterdayCurrentReading as Map)['value'];

        switch (dataType) {
          case 'text':
          case 'number':
            if (_textFieldControllers.containsKey(fieldName)) {
              _textFieldControllers[fieldName]?.text = value?.toString() ?? '';
            }
            break;
          case 'boolean':
            _booleanFieldValues[fieldName] = value as bool? ?? false;
            break;
          case 'date':
            if (value != null) {
              _dateFieldValues[fieldName] = (value as Timestamp).toDate();
            }
            break;
          case 'dropdown':
          case 'group':
            _dropdownFieldValues[fieldName] = value?.toString();
            break;
        }

        fieldMap['autoFilled'] = true;
        fieldMap['value'] = value;
      }

      if (mounted) setState(() {});
    } catch (e) {
      // Non-fatal
      debugPrint('Error auto-filling previous readings: $e');
    }
  }

  void _initializeFieldControllers() {
    _textFieldControllers.clear();
    _booleanFieldValues.clear();
    _dateFieldValues.clear();
    _dropdownFieldValues.clear();
    _booleanDescriptionControllers.clear();
    _groupOptions.clear();

    for (final fieldMap in _instanceReadingFields) {
      final String fieldName = fieldMap['name'] as String? ?? '';
      final String dataType = fieldMap['dataType'] as String? ?? 'text';
      switch (dataType) {
        case 'text':
        case 'number':
          _textFieldControllers[fieldName] = TextEditingController();
          break;
        case 'boolean':
          _booleanFieldValues[fieldName] = false;
          _booleanDescriptionControllers[fieldName] = TextEditingController();
          break;
        case 'date':
          _dateFieldValues[fieldName] = null;
          break;
        case 'dropdown':
          _dropdownFieldValues[fieldName] = null;
          break;
        case 'group':
          final List options = List.from(fieldMap['options'] ?? []);
          _groupOptions[fieldName] = options.map((e) => e.toString()).toList();
          _dropdownFieldValues[fieldName] = null;
          break;
      }
    }
  }

  void _onTemplateSelected(String? templateId) {
    if (templateId == null) return;

    final selectedTemplate = _availableReadingTemplates.firstWhere(
      (t) => t.id == templateId,
    );
    setState(() {
      _selectedTemplateId = templateId;
      _selectedTemplate = selectedTemplate;
      _clearAllControllers();
      _loadTemplateFields(selectedTemplate);
    });
  }

  void _clearAllControllers() {
    _textFieldControllers.forEach((key, controller) => controller.dispose());
    _booleanDescriptionControllers.forEach(
      (key, controller) => controller.dispose(),
    );

    _textFieldControllers.clear();
    _booleanFieldValues.clear();
    _dateFieldValues.clear();
    _dropdownFieldValues.clear();
    _booleanDescriptionControllers.clear();
    _groupOptions.clear();
  }

  void _addInstanceReadingField() {
    setState(() {
      _instanceReadingFields.add({
        'name': '',
        'dataType': ReadingFieldDataType.text.toString().split('.').last,
        'unit': '',
        'options': <String>[],
        'isMandatory': false,
        'frequency': ReadingFrequency.daily.toString().split('.').last,
        'description_remarks': '',
        'nestedFields': null,
        'groupName': null,
        // assignment-only helper flags (safe to store; stripped on save if needed)
        'isPreviousReading': false,
        'isCurrentReading': false,
        'autoFilled': false,
        'linkedCurrentField': null,
        'linkedPreviousField': null,
      });
    });
  }

  void _addInstanceGroupField() {
    setState(() {
      _instanceReadingFields.add({
        'name': '',
        'dataType': ReadingFieldDataType.group.toString().split('.').last,
        'unit': '',
        'options': <String>[],
        'isMandatory': false,
        'frequency': ReadingFrequency.daily.toString().split('.').last,
        'description_remarks': '',
        'nestedFields': <Map<String, dynamic>>[],
        'groupName': null,
        // helpers
        'isPreviousReading': false,
        'isCurrentReading': false,
        'autoFilled': false,
        'linkedCurrentField': null,
        'linkedPreviousField': null,
      });
    });
  }

  Future<void> _saveAssignment() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedTemplate == null) {
      SnackBarUtils.showSnackBar(
        context,
        'Please select a reading template.',
        isError: true,
      );
      return;
    }

    if (_readingStartDate == null) {
      SnackBarUtils.showSnackBar(
        context,
        'Please select a reading start date.',
        isError: true,
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      // Prepare fields for persistence (strip transient UI-only keys if any)
      final List<Map<String, dynamic>> finalAssignedFields = [];
      for (final fieldMap in _instanceReadingFields) {
        final String fieldName = (fieldMap['name'] as String?)?.trim() ?? '';
        if (fieldName.isEmpty) continue;

        final Map<String, dynamic> current = Map<String, dynamic>.from(
          fieldMap,
        );

        // Remove UI/transient values that must not be saved in assignment
        current.remove('value');
        current.remove('autoFilled');
        current.remove('readingStartDate');
        current.remove('isPreviousReading');
        current.remove('isCurrentReading');
        current.remove('linkedCurrentField');
        current.remove('linkedPreviousField');

        finalAssignedFields.add(current);
      }

      final Map<String, dynamic> assignmentData = {
        'bayId': widget.bayId,
        'bayType': _bayType,
        'templateId': _selectedTemplate!.id!,
        'assignedFields': finalAssignedFields,
        'readingStartDate': Timestamp.fromDate(_readingStartDate!),
        'recordedBy': widget.currentUser.uid,
        'recordedAt': FieldValue.serverTimestamp(),
        'isActive': true,
        'totalFields': finalAssignedFields.length,
      };

      if (_existingAssignmentId == null) {
        await FirebaseFirestore.instance
            .collection('bayReadingAssignments')
            .add(assignmentData);
        if (mounted) {
          SnackBarUtils.showSnackBar(
            context,
            'Reading template assigned successfully!',
          );
        }
      } else {
        assignmentData['updatedAt'] = FieldValue.serverTimestamp();
        await FirebaseFirestore.instance
            .collection('bayReadingAssignments')
            .doc(_existingAssignmentId)
            .update(assignmentData);
        if (mounted) {
          SnackBarUtils.showSnackBar(
            context,
            'Reading assignment updated successfully!',
          );
        }
      }

      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        SnackBarUtils.showSnackBar(
          context,
          'Failed to save assignment: $e',
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _selectReadingStartDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _readingStartDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        final theme = Theme.of(context);
        return Theme(
          data: theme.copyWith(
            colorScheme: theme.colorScheme.copyWith(
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
    if (picked != null && picked != _readingStartDate) {
      setState(() {
        _readingStartDate = picked;
      });
      await _autoFillPreviousReadings();
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
            : const Color(0xFFFAFAFA),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation(theme.colorScheme.primary),
              ),
              const SizedBox(height: 16),
              Text(
                'Loading assignment data...',
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
      backgroundColor: isDarkMode
          ? const Color(0xFF1C1C1E)
          : const Color(0xFFFAFAFA),
      appBar: _buildAppBar(theme, isDarkMode),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeaderSection(theme, isDarkMode),
                  const SizedBox(height: 16),
                  _buildDateSelector(theme, isDarkMode),
                  const SizedBox(height: 16),
                  _buildTemplateSelector(theme, isDarkMode),
                  if (_selectedTemplate != null) ...[
                    const SizedBox(height: 16),
                    _buildFieldsSection(theme, isDarkMode),
                  ],
                  const SizedBox(height: 80), // space for FAB
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: _buildActionButton(theme),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  PreferredSizeWidget _buildAppBar(ThemeData theme, bool isDarkMode) {
    return AppBar(
      backgroundColor: isDarkMode
          ? const Color(0xFF1C1C1E)
          : const Color(0xFFFAFAFA),
      elevation: 0,
      leading: IconButton(
        icon: Icon(Icons.arrow_back_ios, color: theme.colorScheme.primary),
        onPressed: () => Navigator.of(context).pop(),
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Reading Assignment',
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
          color: isDarkMode ? Colors.grey[700] : Colors.grey,
        ),
      ),
    );
  }

  Widget _buildHeaderSection(ThemeData theme, bool isDarkMode) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Container(
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
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.electrical_services,
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
                      color: isDarkMode ? Colors.white : Colors.grey[900],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Type: ${_bayType ?? 'Unknown'}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: isDarkMode ? Colors.white70 : Colors.grey[700],
                    ),
                  ),
                ],
              ),
            ),
            if (_existingAssignmentId != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: theme.colorScheme.secondary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Updating',
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.secondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateSelector(ThemeData theme, bool isDarkMode) {
    final DateTime today = DateTime.now();
    final DateTime? startDate = _readingStartDate;
    final bool isStartDate =
        startDate != null &&
        DateTime(today.year, today.month, today.day).isAtSameMomentAs(
          DateTime(startDate.year, startDate.month, startDate.day),
        );

    return FadeTransition(
      opacity: _fadeAnimation,
      child: GestureDetector(
        onTap: () => _selectReadingStartDate(context),
        child: Container(
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
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.secondary.withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.calendar_today,
                      color: theme.colorScheme.secondary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Reading Start Date',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: isDarkMode ? Colors.white : Colors.grey[900],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          DateFormat(
                            'EEEE, MMM dd, yyyy',
                          ).format(_readingStartDate ?? DateTime.now()),
                          style: TextStyle(
                            fontSize: 14,
                            color: theme.colorScheme.secondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.edit_calendar,
                    color: theme.colorScheme.primary,
                    size: 20,
                  ),
                ],
              ),
              if (!isStartDate)
                Container(
                  margin: const EdgeInsets.only(top: 12),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.orange.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.auto_awesome,
                        size: 16,
                        color: Colors.orange,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Previous readings will be auto-filled from previous day\'s current readings',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.orange[700],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTemplateSelector(ThemeData theme, bool isDarkMode) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Container(
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
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.tertiary.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.description,
                    color: theme.colorScheme.tertiary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Reading Template',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: isDarkMode ? Colors.white : Colors.grey[900],
                    ),
                  ),
                ),
                if (_availableReadingTemplates.isNotEmpty)
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
                      '${_availableReadingTemplates.length} available',
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (_availableReadingTemplates.isEmpty)
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
                        'No reading templates available for "${_bayType ?? 'this bay type'}". Create templates in Admin Dashboard.',
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
              DropdownButtonFormField<String>(
                value: _selectedTemplateId,
                decoration: InputDecoration(
                  labelText: 'Select Template',
                  labelStyle: TextStyle(
                    color: isDarkMode ? Colors.white70 : Colors.grey[700],
                    fontSize: 14,
                  ),
                  prefixIcon: Icon(
                    Icons.list_alt,
                    color: theme.colorScheme.primary,
                    size: 20,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: isDarkMode ? Colors.grey! : Colors.grey!,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: isDarkMode ? Colors.grey! : Colors.grey!,
                    ),
                  ),
                  filled: true,
                  fillColor: isDarkMode ? const Color(0xFF3C3C3E) : Colors.grey,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                ),
                dropdownColor: isDarkMode
                    ? const Color(0xFF2C2C2E)
                    : Colors.white,
                isExpanded: true,
                items: _availableReadingTemplates.map((template) {
                  return DropdownMenuItem<String>(
                    value: template.id,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${template.bayType} - ${template.totalFieldCount} fields',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: isDarkMode ? Colors.white : Colors.grey[900],
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        if ((template.description ?? '').isNotEmpty)
                          Text(
                            template.description!,
                            style: TextStyle(
                              fontSize: 12,
                              color: isDarkMode
                                  ? Colors.white70
                                  : Colors.grey[600],
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: _onTemplateSelected,
                validator: (value) =>
                    value == null ? 'Please select a template' : null,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFieldsSection(ThemeData theme, bool isDarkMode) {
    return Container(
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
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.settings,
                    color: theme.colorScheme.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Reading Fields Configuration',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: isDarkMode ? Colors.white : Colors.grey[900],
                    ),
                  ),
                ),
                if (_instanceReadingFields.isNotEmpty)
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
                      '${_instanceReadingFields.length} field${_instanceReadingFields.length == 1 ? '' : 's'}',
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),

            // Reusable field list widget
            FieldListWidget(
              fields: _instanceReadingFields,
              isEditable: true,
              dataTypes: _dataTypes,
              frequencies: _frequencies,
              onFieldsChanged: (updated) {
                setState(() {
                  _instanceReadingFields
                    ..clear()
                    ..addAll(updated.map((e) => Map<String, dynamic>.from(e)));
                });
              },
              onAddField: _addInstanceReadingField,
              onAddGroupField: _addInstanceGroupField,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(ThemeData theme) {
    final bool canSave = _selectedTemplate != null && !_isSaving;
    return FloatingActionButton.extended(
      onPressed: canSave ? _saveAssignment : null,
      backgroundColor: canSave ? theme.colorScheme.primary : Colors.grey[400],
      elevation: canSave ? 2 : 0,
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_isSaving)
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation(Colors.white),
              ),
            )
          else
            Icon(
              _existingAssignmentId == null ? Icons.save : Icons.update,
              size: 20,
            ),
          const SizedBox(width: 8),
          Text(
            _isSaving
                ? 'Saving...'
                : (_existingAssignmentId == null
                      ? 'Save Assignment'
                      : 'Update Assignment'),
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ],
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }
}

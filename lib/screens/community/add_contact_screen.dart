// lib/screens/community/add_contact_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/community_models.dart';
import '../../models/user_model.dart';
import '../../services/community_service.dart';

class AddContactScreen extends StatefulWidget {
  final AppUser currentUser;

  const AddContactScreen({Key? key, required this.currentUser})
    : super(key: key);

  @override
  _AddContactScreenState createState() => _AddContactScreenState();
}

class _AddContactScreenState extends State<AddContactScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _designationController = TextEditingController();
  final TextEditingController _departmentController = TextEditingController();
  final TextEditingController _companyController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _alternatePhoneController =
      TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _alternateEmailController =
      TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _streetController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();
  final TextEditingController _stateController = TextEditingController();
  final TextEditingController _pincodeController = TextEditingController();
  final TextEditingController _landmarkController = TextEditingController();
  final TextEditingController _workingHoursController = TextEditingController();
  final TextEditingController _emergencyHoursController =
      TextEditingController();
  final TextEditingController _experienceController = TextEditingController();
  final TextEditingController _clearanceLevelController =
      TextEditingController();

  ContactType _selectedContactType = ContactType.vendor;
  List<String> _specializations = [];
  List<String> _certifications = [];
  List<String> _serviceAreas = [];
  List<String> _voltageExpertise = [];
  List<String> _equipmentExpertise = [];
  List<String> _serviceTypes = [];
  List<String> _workingDays = [];
  bool _isAvailable = true;
  bool _emergencyAvailable = false;
  bool _hasGovernmentClearance = false;
  bool _isLoading = false;

  final TextEditingController _specializationController =
      TextEditingController();
  final TextEditingController _certificationController =
      TextEditingController();
  final TextEditingController _serviceAreaController = TextEditingController();

  // Predefined options
  final List<String> _voltageOptions = [
    '11kV',
    '33kV',
    '66kV',
    '132kV',
    '220kV',
    '400kV',
  ];
  final List<String> _equipmentOptions = [
    'Transformer',
    'Circuit Breaker',
    'Isolator',
    'Lightning Arrester',
    'Current Transformer',
    'Voltage Transformer',
    'Relay',
    'SCADA System',
    'Protection System',
    'Control Panel',
    'Switchgear',
    'Busbar',
  ];
  final List<String> _serviceTypeOptions = [
    'Installation',
    'Maintenance',
    'Repair',
    'Testing',
    'Commissioning',
    'Emergency Service',
    'Consultation',
    'Training',
    'Supply',
  ];
  final List<String> _weekDays = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  @override
  void initState() {
    super.initState();
    // Set default working hours
    _workingHoursController.text = '9:00 AM - 6:00 PM';
    // Set default working days (Monday to Friday)
    _workingDays = ['monday', 'tuesday', 'wednesday', 'thursday', 'friday'];
  }

  @override
  void dispose() {
    _nameController.dispose();
    _designationController.dispose();
    _departmentController.dispose();
    _companyController.dispose();
    _phoneController.dispose();
    _alternatePhoneController.dispose();
    _emailController.dispose();
    _alternateEmailController.dispose();
    _notesController.dispose();
    _streetController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _pincodeController.dispose();
    _landmarkController.dispose();
    _workingHoursController.dispose();
    _emergencyHoursController.dispose();
    _experienceController.dispose();
    _clearanceLevelController.dispose();
    _specializationController.dispose();
    _certificationController.dispose();
    _serviceAreaController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFFAFAFA),
      appBar: AppBar(
        title: Text(
          'Add Professional Contact',
          style: TextStyle(fontWeight: FontWeight.w600, color: Colors.black87),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.black87),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _saveContact,
            child: Text(
              'Save',
              style: TextStyle(
                color: _isLoading
                    ? Colors.grey
                    : Theme.of(context).primaryColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Contact Type Selection Card
              _buildSectionCard(
                title: 'Contact Type',
                icon: Icons.category,
                children: [
                  Text(
                    'What type of professional contact is this?',
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                  SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: ContactType.values.map((type) {
                      return ChoiceChip(
                        label: Text(_getContactTypeLabel(type)),
                        selected: _selectedContactType == type,
                        onSelected: (selected) {
                          if (selected) {
                            setState(() {
                              _selectedContactType = type;
                            });
                          }
                        },
                        backgroundColor: Colors.grey[200],
                        selectedColor: _getContactTypeColor(type),
                        labelStyle: TextStyle(
                          color: _selectedContactType == type
                              ? Colors.white
                              : Colors.black87,
                          fontWeight: FontWeight.w500,
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),

              SizedBox(height: 16),

              // Basic Information Card
              _buildSectionCard(
                title: 'Basic Information',
                icon: Icons.person,
                children: [
                  _buildTextField(
                    controller: _nameController,
                    label: 'Full Name *',
                    validator: (value) =>
                        value?.isEmpty == true ? 'Name is required' : null,
                    prefixIcon: Icons.person_outline,
                  ),
                  SizedBox(height: 16),
                  _buildTextField(
                    controller: _designationController,
                    label: 'Designation *',
                    validator: (value) => value?.isEmpty == true
                        ? 'Designation is required'
                        : null,
                    prefixIcon: Icons.work_outline,
                  ),
                  SizedBox(height: 16),
                  _buildTextField(
                    controller: _departmentController,
                    label: 'Department *',
                    validator: (value) => value?.isEmpty == true
                        ? 'Department is required'
                        : null,
                    prefixIcon: Icons.business_outlined,
                  ),
                  SizedBox(height: 16),
                  _buildTextField(
                    controller: _companyController,
                    label: 'Company/Organization',
                    prefixIcon: Icons.corporate_fare_outlined,
                  ),
                ],
              ),

              SizedBox(height: 16),

              // Contact Information Card
              _buildSectionCard(
                title: 'Contact Information',
                icon: Icons.contact_phone,
                children: [
                  _buildTextField(
                    controller: _phoneController,
                    label: 'Phone Number *',
                    keyboardType: TextInputType.phone,
                    validator: (value) {
                      if (value?.isEmpty == true)
                        return 'Phone number is required';
                      if (value!.length < 10)
                        return 'Enter a valid phone number';
                      return null;
                    },
                    prefixIcon: Icons.phone_outlined,
                  ),
                  SizedBox(height: 16),
                  _buildTextField(
                    controller: _alternatePhoneController,
                    label: 'Alternate Phone (Optional)',
                    keyboardType: TextInputType.phone,
                    prefixIcon: Icons.phone_android_outlined,
                  ),
                  SizedBox(height: 16),
                  _buildTextField(
                    controller: _emailController,
                    label: 'Email Address *',
                    keyboardType: TextInputType.emailAddress,
                    validator: (value) {
                      if (value?.isEmpty == true) return 'Email is required';
                      if (!RegExp(
                        r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                      ).hasMatch(value!)) {
                        return 'Enter a valid email';
                      }
                      return null;
                    },
                    prefixIcon: Icons.email_outlined,
                  ),
                  SizedBox(height: 16),
                  _buildTextField(
                    controller: _alternateEmailController,
                    label: 'Alternate Email (Optional)',
                    keyboardType: TextInputType.emailAddress,
                    prefixIcon: Icons.alternate_email_outlined,
                  ),
                ],
              ),

              SizedBox(height: 16),

              // Specializations Card
              _buildSectionCard(
                title: 'Specializations',
                icon: Icons.star_outline,
                children: [
                  Text(
                    'Add areas of expertise and specialization',
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                  SizedBox(height: 12),
                  _buildChipInputField(
                    label: 'Add Specialization',
                    controller: _specializationController,
                    chips: _specializations,
                    onAdd: (value) {
                      if (value.isNotEmpty &&
                          !_specializations.contains(value)) {
                        setState(() {
                          _specializations.add(value);
                        });
                      }
                    },
                    onDelete: (value) {
                      setState(() {
                        _specializations.remove(value);
                      });
                    },
                  ),
                ],
              ),

              SizedBox(height: 16),

              // Electrical Expertise Card
              _buildSectionCard(
                title: 'Electrical Expertise',
                icon: Icons.electrical_services,
                children: [
                  _buildMultiSelectField(
                    label: 'Voltage Levels',
                    subtitle: 'Select voltage levels this contact works with',
                    options: _voltageOptions,
                    selectedValues: _voltageExpertise,
                    onChanged: (values) {
                      setState(() {
                        _voltageExpertise = values;
                      });
                    },
                    color: Colors.orange,
                  ),
                  SizedBox(height: 16),
                  _buildMultiSelectField(
                    label: 'Equipment Types',
                    subtitle:
                        'Select equipment types this contact specializes in',
                    options: _equipmentOptions,
                    selectedValues: _equipmentExpertise,
                    onChanged: (values) {
                      setState(() {
                        _equipmentExpertise = values;
                      });
                    },
                    color: Colors.blue,
                  ),
                  SizedBox(height: 16),
                  _buildMultiSelectField(
                    label: 'Service Types',
                    subtitle: 'Select types of services provided',
                    options: _serviceTypeOptions,
                    selectedValues: _serviceTypes,
                    onChanged: (values) {
                      setState(() {
                        _serviceTypes = values;
                      });
                    },
                    color: Colors.green,
                  ),
                  SizedBox(height: 16),
                  _buildTextField(
                    controller: _experienceController,
                    label: 'Years of Experience',
                    keyboardType: TextInputType.number,
                    prefixIcon: Icons.timeline_outlined,
                  ),
                  SizedBox(height: 16),
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[300]!),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: CheckboxListTile(
                      title: Text('Has Government Clearance'),
                      subtitle: Text(
                        'Contact has government security clearance',
                      ),
                      value: _hasGovernmentClearance,
                      onChanged: (value) {
                        setState(() {
                          _hasGovernmentClearance = value!;
                        });
                      },
                      activeColor: Theme.of(context).primaryColor,
                    ),
                  ),
                  if (_hasGovernmentClearance) ...[
                    SizedBox(height: 16),
                    _buildTextField(
                      controller: _clearanceLevelController,
                      label: 'Clearance Level',
                      prefixIcon: Icons.security_outlined,
                    ),
                  ],
                ],
              ),

              SizedBox(height: 16),

              // Availability Card
              _buildSectionCard(
                title: 'Availability',
                icon: Icons.schedule,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[300]!),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: SwitchListTile(
                      title: Text('Currently Available'),
                      subtitle: Text(
                        'Is this contact currently available for work?',
                      ),
                      value: _isAvailable,
                      onChanged: (value) {
                        setState(() {
                          _isAvailable = value;
                        });
                      },
                      activeColor: Theme.of(context).primaryColor,
                    ),
                  ),
                  SizedBox(height: 16),
                  _buildTextField(
                    controller: _workingHoursController,
                    label: 'Working Hours',
                    prefixIcon: Icons.access_time_outlined,
                    hintText: 'e.g., 9:00 AM - 6:00 PM',
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Working Days',
                    style: TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
                  ),
                  SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _weekDays.map((day) {
                      return FilterChip(
                        label: Text(
                          day.substring(0, 3),
                        ), // Show first 3 letters
                        selected: _workingDays.contains(day.toLowerCase()),
                        onSelected: (selected) {
                          setState(() {
                            if (selected) {
                              _workingDays.add(day.toLowerCase());
                            } else {
                              _workingDays.remove(day.toLowerCase());
                            }
                          });
                        },
                        backgroundColor: Colors.grey[200],
                        selectedColor: Theme.of(context).primaryColor,
                        labelStyle: TextStyle(
                          color: _workingDays.contains(day.toLowerCase())
                              ? Colors.white
                              : Colors.black87,
                          fontSize: 12,
                        ),
                      );
                    }).toList(),
                  ),
                  SizedBox(height: 16),
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[300]!),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: SwitchListTile(
                      title: Text('Emergency Available'),
                      subtitle: Text('Available for emergency services?'),
                      value: _emergencyAvailable,
                      onChanged: (value) {
                        setState(() {
                          _emergencyAvailable = value;
                        });
                      },
                      activeColor: Colors.red,
                    ),
                  ),
                  if (_emergencyAvailable) ...[
                    SizedBox(height: 16),
                    _buildTextField(
                      controller: _emergencyHoursController,
                      label: 'Emergency Hours',
                      prefixIcon: Icons.emergency_outlined,
                      hintText: 'e.g., 24/7 or After 6:00 PM',
                    ),
                  ],
                ],
              ),

              SizedBox(height: 16),

              // Address Card
              _buildSectionCard(
                title: 'Address',
                icon: Icons.location_on_outlined,
                children: [
                  _buildTextField(
                    controller: _streetController,
                    label: 'Street Address',
                    prefixIcon: Icons.home_outlined,
                  ),
                  SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _buildTextField(
                          controller: _cityController,
                          label: 'City',
                          prefixIcon: Icons.location_city_outlined,
                        ),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: _buildTextField(
                          controller: _stateController,
                          label: 'State',
                          prefixIcon: Icons.map_outlined,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _buildTextField(
                          controller: _pincodeController,
                          label: 'Pincode',
                          keyboardType: TextInputType.number,
                          prefixIcon: Icons.pin_drop_outlined,
                        ),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: _buildTextField(
                          controller: _landmarkController,
                          label: 'Landmark (Optional)',
                          prefixIcon: Icons.place_outlined,
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              SizedBox(height: 16),

              // Certifications Card
              _buildSectionCard(
                title: 'Certifications',
                icon: Icons.verified_user_outlined,
                children: [
                  Text(
                    'Add professional certifications and licenses',
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                  SizedBox(height: 12),
                  _buildChipInputField(
                    label: 'Add Certification',
                    controller: _certificationController,
                    chips: _certifications,
                    onAdd: (value) {
                      if (value.isNotEmpty &&
                          !_certifications.contains(value)) {
                        setState(() {
                          _certifications.add(value);
                        });
                      }
                    },
                    onDelete: (value) {
                      setState(() {
                        _certifications.remove(value);
                      });
                    },
                  ),
                ],
              ),

              SizedBox(height: 16),

              // Service Areas Card
              _buildSectionCard(
                title: 'Service Areas',
                icon: Icons.map_outlined,
                children: [
                  Text(
                    'Add geographic areas where services are provided',
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                  SizedBox(height: 12),
                  _buildChipInputField(
                    label: 'Add Service Area',
                    controller: _serviceAreaController,
                    chips: _serviceAreas,
                    onAdd: (value) {
                      if (value.isNotEmpty && !_serviceAreas.contains(value)) {
                        setState(() {
                          _serviceAreas.add(value);
                        });
                      }
                    },
                    onDelete: (value) {
                      setState(() {
                        _serviceAreas.remove(value);
                      });
                    },
                  ),
                ],
              ),

              SizedBox(height: 16),

              // Additional Notes Card
              _buildSectionCard(
                title: 'Additional Notes',
                icon: Icons.note_outlined,
                children: [
                  _buildTextField(
                    controller: _notesController,
                    label: 'Notes (Optional)',
                    maxLines: 3,
                    hintText:
                        'Any additional information about this contact...',
                  ),
                ],
              ),

              SizedBox(height: 100), // Space for bottom action bar
            ],
          ),
        ),
      ),
      bottomNavigationBar: Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.3),
              spreadRadius: 1,
              blurRadius: 10,
              offset: Offset(0, -2),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _isLoading ? null : () => Navigator.pop(context),
                child: Text('Cancel'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.grey[600],
                  side: BorderSide(color: Colors.grey[300]!),
                  padding: EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            SizedBox(width: 16),
            Expanded(
              flex: 2,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _saveContact,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: 12),
                ),
                child: _isLoading
                    ? SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : Text('Add Contact'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: Theme.of(context).primaryColor),
                SizedBox(width: 12),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    int maxLines = 1,
    IconData? prefixIcon,
    String? hintText,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        hintText: hintText,
        prefixIcon: prefixIcon != null
            ? Icon(prefixIcon, color: Colors.grey[600])
            : null,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Theme.of(context).primaryColor),
        ),
      ),
    );
  }

  Widget _buildChipInputField({
    required String label,
    required TextEditingController controller,
    required List<String> chips,
    required void Function(String) onAdd,
    required void Function(String) onDelete,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                decoration: InputDecoration(
                  labelText: label,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: Theme.of(context).primaryColor,
                    ),
                  ),
                ),
                onSubmitted: (value) {
                  onAdd(value.trim());
                  controller.clear();
                },
              ),
            ),
            SizedBox(width: 8),
            IconButton(
              onPressed: () {
                if (controller.text.trim().isNotEmpty) {
                  onAdd(controller.text.trim());
                  controller.clear();
                }
              },
              icon: Icon(Icons.add_circle),
              color: Theme.of(context).primaryColor,
            ),
          ],
        ),
        if (chips.isNotEmpty) ...[
          SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: chips.map((chip) {
              return Chip(
                label: Text(chip),
                deleteIcon: Icon(Icons.close, size: 18),
                onDeleted: () => onDelete(chip),
                backgroundColor: Theme.of(
                  context,
                ).primaryColor.withOpacity(0.1),
                labelStyle: TextStyle(color: Theme.of(context).primaryColor),
              );
            }).toList(),
          ),
        ],
      ],
    );
  }

  Widget _buildMultiSelectField({
    required String label,
    required String subtitle,
    required List<String> options,
    required List<String> selectedValues,
    required void Function(List<String>) onChanged,
    required Color color,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
        ),
        SizedBox(height: 4),
        Text(subtitle, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
        SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: options.map((option) {
            return FilterChip(
              label: Text(option),
              selected: selectedValues.contains(option),
              onSelected: (selected) {
                final newValues = List<String>.from(selectedValues);
                if (selected) {
                  newValues.add(option);
                } else {
                  newValues.remove(option);
                }
                onChanged(newValues);
              },
              backgroundColor: Colors.grey[200],
              selectedColor: color,
              labelStyle: TextStyle(
                color: selectedValues.contains(option)
                    ? Colors.white
                    : Colors.black87,
                fontSize: 12,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  String _getContactTypeLabel(ContactType type) {
    switch (type) {
      case ContactType.vendor:
        return 'Vendor';
      case ContactType.engineer:
        return 'Engineer';
      case ContactType.technician:
        return 'Technician';
      case ContactType.contractor:
        return 'Contractor';
      case ContactType.supplier:
        return 'Supplier';
      case ContactType.consultant:
        return 'Consultant';
      case ContactType.emergencyService:
        return 'Emergency';
      case ContactType.other:
        return 'Other';
    }
  }

  Color _getContactTypeColor(ContactType type) {
    switch (type) {
      case ContactType.vendor:
        return Colors.purple;
      case ContactType.engineer:
        return Colors.blue;
      case ContactType.technician:
        return Colors.orange;
      case ContactType.contractor:
        return Colors.green;
      case ContactType.supplier:
        return Colors.teal;
      case ContactType.consultant:
        return Colors.indigo;
      case ContactType.emergencyService:
        return Colors.red;
      case ContactType.other:
        return Colors.grey;
    }
  }

  Future<void> _saveContact() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final contact = ProfessionalContact(
        name: _nameController.text.trim(),
        designation: _designationController.text.trim(),
        department: _departmentController.text.trim(),
        contactType: _selectedContactType,
        companyName: _companyController.text.trim().isEmpty
            ? null
            : _companyController.text.trim(),
        phoneNumber: _phoneController.text.trim(),
        alternatePhone: _alternatePhoneController.text.trim().isEmpty
            ? null
            : _alternatePhoneController.text.trim(),
        email: _emailController.text.trim(),
        alternateEmail: _alternateEmailController.text.trim().isEmpty
            ? null
            : _alternateEmailController.text.trim(),
        specializations: _specializations,
        certifications: _certifications,
        serviceAreas: _serviceAreas,
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
        createdAt: Timestamp.now(),
        addedBy: widget.currentUser.uid!,
        metrics: ContactMetrics(), // Initialize with default values
        availability: ContactAvailability(
          isAvailable: _isAvailable,
          workingDays: _workingDays,
          workingHours: _workingHoursController.text.trim(),
          emergencyAvailable: _emergencyAvailable,
          emergencyHours: _emergencyHoursController.text.trim().isEmpty
              ? null
              : _emergencyHoursController.text.trim(),
        ),
        address:
            _streetController.text.trim().isNotEmpty ||
                _cityController.text.trim().isNotEmpty
            ? ContactAddress(
                street: _streetController.text.trim(),
                city: _cityController.text.trim(),
                state: _stateController.text.trim(),
                pincode: _pincodeController.text.trim(),
                landmark: _landmarkController.text.trim().isEmpty
                    ? null
                    : _landmarkController.text.trim(),
              )
            : null,
        electricalExpertise:
            _voltageExpertise.isNotEmpty ||
                _equipmentExpertise.isNotEmpty ||
                _experienceController.text.trim().isNotEmpty
            ? ContactElectricalExpertise(
                voltageExpertise: _voltageExpertise,
                equipmentExpertise: _equipmentExpertise,
                serviceTypes: _serviceTypes,
                experienceYears:
                    int.tryParse(_experienceController.text.trim()) ?? 0,
                hasGovernmentClearance: _hasGovernmentClearance,
                clearanceLevel: _clearanceLevelController.text.trim().isEmpty
                    ? null
                    : _clearanceLevelController.text.trim(),
              )
            : null,
      );

      await CommunityService.createProfessionalContact(contact);

      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Contact added successfully'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );

      Navigator.pop(context);
    } catch (e) {
      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to add contact: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}

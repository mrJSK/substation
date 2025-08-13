// lib/screens/community/edit_contact_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/community_models.dart';
import '../../models/user_model.dart';
import '../../services/community_service.dart';

class EditContactScreen extends StatefulWidget {
  final ProfessionalContact contact;
  final AppUser currentUser;

  const EditContactScreen({
    Key? key,
    required this.contact,
    required this.currentUser,
  }) : super(key: key);

  @override
  _EditContactScreenState createState() => _EditContactScreenState();
}

class _EditContactScreenState extends State<EditContactScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _designationController;
  late TextEditingController _departmentController;
  late TextEditingController _companyController;
  late TextEditingController _phoneController;
  late TextEditingController _alternatePhoneController;
  late TextEditingController _emailController;
  late TextEditingController _alternateEmailController;
  late TextEditingController _notesController;
  late TextEditingController _streetController;
  late TextEditingController _cityController;
  late TextEditingController _stateController;
  late TextEditingController _pincodeController;
  late TextEditingController _landmarkController;
  late TextEditingController _workingHoursController;
  late TextEditingController _emergencyHoursController;
  late TextEditingController _experienceController;
  late TextEditingController _clearanceLevelController;

  ContactType _selectedContactType = ContactType.other;
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
  ];
  final List<String> _serviceTypeOptions = [
    'Installation',
    'Maintenance',
    'Repair',
    'Testing',
    'Commissioning',
    'Emergency Service',
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
    _initializeControllers();
    _loadContactData();
  }

  void _initializeControllers() {
    _nameController = TextEditingController();
    _designationController = TextEditingController();
    _departmentController = TextEditingController();
    _companyController = TextEditingController();
    _phoneController = TextEditingController();
    _alternatePhoneController = TextEditingController();
    _emailController = TextEditingController();
    _alternateEmailController = TextEditingController();
    _notesController = TextEditingController();
    _streetController = TextEditingController();
    _cityController = TextEditingController();
    _stateController = TextEditingController();
    _pincodeController = TextEditingController();
    _landmarkController = TextEditingController();
    _workingHoursController = TextEditingController();
    _emergencyHoursController = TextEditingController();
    _experienceController = TextEditingController();
    _clearanceLevelController = TextEditingController();
  }

  void _loadContactData() {
    final contact = widget.contact;

    _nameController.text = contact.name;
    _designationController.text = contact.designation;
    _departmentController.text = contact.department;
    _companyController.text = contact.companyName ?? '';
    _phoneController.text = contact.phoneNumber;
    _alternatePhoneController.text = contact.alternatePhone ?? '';
    _emailController.text = contact.email;
    _alternateEmailController.text = contact.alternateEmail ?? '';
    _notesController.text = contact.notes ?? '';

    _selectedContactType = contact.contactType;
    _specializations = List.from(contact.specializations);
    _certifications = List.from(contact.certifications);
    _serviceAreas = List.from(contact.serviceAreas);
    _isAvailable = contact.availability.isAvailable;
    _workingHoursController.text = contact.availability.workingHours;
    _emergencyAvailable = contact.availability.emergencyAvailable;
    _emergencyHoursController.text = contact.availability.emergencyHours ?? '';
    _workingDays = List.from(contact.availability.workingDays);

    if (contact.address != null) {
      _streetController.text = contact.address!.street;
      _cityController.text = contact.address!.city;
      _stateController.text = contact.address!.state;
      _pincodeController.text = contact.address!.pincode;
      _landmarkController.text = contact.address!.landmark ?? '';
    }

    if (contact.electricalExpertise != null) {
      _voltageExpertise = List.from(
        contact.electricalExpertise!.voltageExpertise,
      );
      _equipmentExpertise = List.from(
        contact.electricalExpertise!.equipmentExpertise,
      );
      _serviceTypes = List.from(contact.electricalExpertise!.serviceTypes);
      _experienceController.text = contact.electricalExpertise!.experienceYears
          .toString();
      _hasGovernmentClearance =
          contact.electricalExpertise!.hasGovernmentClearance;
      _clearanceLevelController.text =
          contact.electricalExpertise!.clearanceLevel ?? '';
    }
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
          'Edit Contact',
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
              // Basic Information Card
              _buildSectionCard(
                title: 'Basic Information',
                icon: Icons.person,
                children: [
                  _buildTextField(
                    controller: _nameController,
                    label: 'Full Name',
                    validator: (value) =>
                        value?.isEmpty == true ? 'Name is required' : null,
                  ),
                  SizedBox(height: 16),
                  _buildTextField(
                    controller: _designationController,
                    label: 'Designation',
                    validator: (value) => value?.isEmpty == true
                        ? 'Designation is required'
                        : null,
                  ),
                  SizedBox(height: 16),
                  _buildTextField(
                    controller: _departmentController,
                    label: 'Department',
                    validator: (value) => value?.isEmpty == true
                        ? 'Department is required'
                        : null,
                  ),
                  SizedBox(height: 16),
                  _buildDropdownField(
                    label: 'Contact Type',
                    value: _selectedContactType,
                    items: ContactType.values.map((type) {
                      return DropdownMenuItem(
                        value: type,
                        child: Text(_getContactTypeLabel(type)),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedContactType = value!;
                      });
                    },
                  ),
                  SizedBox(height: 16),
                  _buildTextField(
                    controller: _companyController,
                    label: 'Company/Organization',
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
                    label: 'Phone Number',
                    keyboardType: TextInputType.phone,
                    validator: (value) => value?.isEmpty == true
                        ? 'Phone number is required'
                        : null,
                  ),
                  SizedBox(height: 16),
                  _buildTextField(
                    controller: _alternatePhoneController,
                    label: 'Alternate Phone (Optional)',
                    keyboardType: TextInputType.phone,
                  ),
                  SizedBox(height: 16),
                  _buildTextField(
                    controller: _emailController,
                    label: 'Email Address',
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
                  ),
                  SizedBox(height: 16),
                  _buildTextField(
                    controller: _alternateEmailController,
                    label: 'Alternate Email (Optional)',
                    keyboardType: TextInputType.emailAddress,
                  ),
                ],
              ),

              SizedBox(height: 16),

              // Specializations Card
              _buildSectionCard(
                title: 'Specializations',
                icon: Icons.star,
                children: [
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
                    options: _voltageOptions,
                    selectedValues: _voltageExpertise,
                    onChanged: (values) {
                      setState(() {
                        _voltageExpertise = values;
                      });
                    },
                  ),
                  SizedBox(height: 16),
                  _buildMultiSelectField(
                    label: 'Equipment Types',
                    options: _equipmentOptions,
                    selectedValues: _equipmentExpertise,
                    onChanged: (values) {
                      setState(() {
                        _equipmentExpertise = values;
                      });
                    },
                  ),
                  SizedBox(height: 16),
                  _buildMultiSelectField(
                    label: 'Service Types',
                    options: _serviceTypeOptions,
                    selectedValues: _serviceTypes,
                    onChanged: (values) {
                      setState(() {
                        _serviceTypes = values;
                      });
                    },
                  ),
                  SizedBox(height: 16),
                  _buildTextField(
                    controller: _experienceController,
                    label: 'Years of Experience',
                    keyboardType: TextInputType.number,
                  ),
                  SizedBox(height: 16),
                  CheckboxListTile(
                    title: Text('Has Government Clearance'),
                    value: _hasGovernmentClearance,
                    onChanged: (value) {
                      setState(() {
                        _hasGovernmentClearance = value!;
                      });
                    },
                    activeColor: Theme.of(context).primaryColor,
                  ),
                  if (_hasGovernmentClearance)
                    _buildTextField(
                      controller: _clearanceLevelController,
                      label: 'Clearance Level',
                    ),
                ],
              ),

              SizedBox(height: 16),

              // Availability Card
              _buildSectionCard(
                title: 'Availability',
                icon: Icons.schedule,
                children: [
                  SwitchListTile(
                    title: Text('Currently Available'),
                    value: _isAvailable,
                    onChanged: (value) {
                      setState(() {
                        _isAvailable = value;
                      });
                    },
                    activeColor: Theme.of(context).primaryColor,
                  ),
                  SizedBox(height: 16),
                  _buildTextField(
                    controller: _workingHoursController,
                    label: 'Working Hours (e.g., 9:00 AM - 6:00 PM)',
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Working Days',
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                  SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: _weekDays.map((day) {
                      return FilterChip(
                        label: Text(day),
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
                        ),
                      );
                    }).toList(),
                  ),
                  SizedBox(height: 16),
                  SwitchListTile(
                    title: Text('Emergency Available'),
                    value: _emergencyAvailable,
                    onChanged: (value) {
                      setState(() {
                        _emergencyAvailable = value;
                      });
                    },
                    activeColor: Colors.red,
                  ),
                  if (_emergencyAvailable)
                    _buildTextField(
                      controller: _emergencyHoursController,
                      label: 'Emergency Hours',
                    ),
                ],
              ),

              SizedBox(height: 16),

              // Address Card
              _buildSectionCard(
                title: 'Address',
                icon: Icons.location_on,
                children: [
                  _buildTextField(
                    controller: _streetController,
                    label: 'Street Address',
                  ),
                  SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _buildTextField(
                          controller: _cityController,
                          label: 'City',
                        ),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: _buildTextField(
                          controller: _stateController,
                          label: 'State',
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
                        ),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: _buildTextField(
                          controller: _landmarkController,
                          label: 'Landmark (Optional)',
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
                icon: Icons.verified_user,
                children: [
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
                icon: Icons.map,
                children: [
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
                icon: Icons.note,
                children: [
                  _buildTextField(
                    controller: _notesController,
                    label: 'Notes (Optional)',
                    maxLines: 3,
                  ),
                ],
              ),

              SizedBox(height: 100), // Space for save button
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
                    : Text('Save Changes'),
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
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
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

  Widget _buildDropdownField<T>({
    required String label,
    required T value,
    required List<DropdownMenuItem<T>> items,
    required void Function(T?) onChanged,
  }) {
    return DropdownButtonFormField<T>(
      value: value,
      items: items,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
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
                ),
                onSubmitted: (value) {
                  onAdd(value);
                  controller.clear();
                },
              ),
            ),
            SizedBox(width: 8),
            IconButton(
              onPressed: () {
                onAdd(controller.text);
                controller.clear();
              },
              icon: Icon(Icons.add),
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
    required List<String> options,
    required List<String> selectedValues,
    required void Function(List<String>) onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontWeight: FontWeight.w500)),
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
              selectedColor: Theme.of(context).primaryColor,
              labelStyle: TextStyle(
                color: selectedValues.contains(option)
                    ? Colors.white
                    : Colors.black87,
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
        return 'Emergency Service';
      case ContactType.other:
        return 'Other';
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
      final updatedContact = widget.contact.copyWith(
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
        updatedAt: Timestamp.now(),
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

      await CommunityService.updateProfessionalContact(
        widget.contact.id!,
        updatedContact,
      );

      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Contact updated successfully'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );

      Navigator.pop(context, updatedContact);
    } catch (e) {
      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update contact: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}

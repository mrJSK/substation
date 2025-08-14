// lib/screens/profile/user_profile_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/user_model.dart';
import '../services/user_service.dart';

class UserProfileScreen extends StatefulWidget {
  final AppUser currentUser;

  const UserProfileScreen({Key? key, required this.currentUser})
    : super(key: key);

  @override
  _UserProfileScreenState createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _isEditing = false;

  // Controllers for form fields
  late TextEditingController _nameController;
  late TextEditingController _mobileController;
  late TextEditingController _sapIdController;
  late TextEditingController _highestEducationController;
  late TextEditingController _collegeController;
  late TextEditingController _personalEmailController;

  // Current selections
  Designation? _selectedDesignation;

  @override
  void initState() {
    super.initState();
    _initializeControllers();
  }

  void _initializeControllers() {
    _nameController = TextEditingController(text: widget.currentUser.name);
    _mobileController = TextEditingController(text: widget.currentUser.mobile);
    _sapIdController = TextEditingController(
      text: widget.currentUser.sapId ?? '',
    );
    _highestEducationController = TextEditingController(
      text: widget.currentUser.highestEducation ?? '',
    );
    _collegeController = TextEditingController(
      text: widget.currentUser.college ?? '',
    );
    _personalEmailController = TextEditingController(
      text: widget.currentUser.personalEmail ?? '',
    );

    _selectedDesignation = widget.currentUser.designation;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _mobileController.dispose();
    _sapIdController.dispose();
    _highestEducationController.dispose();
    _collegeController.dispose();
    _personalEmailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        title: const Text(
          'Profile',
          style: TextStyle(fontWeight: FontWeight.w600, color: Colors.black87),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
        actions: [
          if (!_isEditing)
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () {
                setState(() {
                  _isEditing = true;
                });
              },
            ),
          if (_isEditing)
            TextButton(
              onPressed: _isLoading ? null : _saveProfile,
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
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    // Profile Header
                    _buildProfileHeader(),

                    const SizedBox(height: 24),

                    // Basic Information
                    _buildBasicInformationCard(),

                    const SizedBox(height: 16),

                    // Current Posting - UPDATED: Auto-populated based on hierarchy
                    _buildCurrentPostingCard(),

                    const SizedBox(height: 16),

                    // Optional Information
                    _buildOptionalInformationCard(),

                    const SizedBox(
                      height: 80,
                    ), // Space for floating action button
                  ],
                ),
              ),
            ),
      floatingActionButton: _isEditing
          ? FloatingActionButton(
              onPressed: () {
                setState(() {
                  _isEditing = false;
                  _initializeControllers(); // Reset form
                });
              },
              backgroundColor: Colors.grey,
              child: const Icon(Icons.close, color: Colors.white),
            )
          : null,
    );
  }

  Widget _buildProfileHeader() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            colors: [
              Theme.of(context).primaryColor,
              Theme.of(context).primaryColor.withOpacity(0.8),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          children: [
            CircleAvatar(
              radius: 40,
              backgroundColor: Colors.white.withOpacity(0.2),
              child: Text(
                widget.currentUser.name.isNotEmpty
                    ? widget.currentUser.name[0].toUpperCase()
                    : 'U',
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              widget.currentUser.name.isNotEmpty
                  ? widget.currentUser.name
                  : 'User Name',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              widget.currentUser.designationDisplayName,
              style: TextStyle(
                fontSize: 14,
                color: Colors.white.withOpacity(0.9),
              ),
            ),
            if (widget.currentUser.currentPostingDisplay != 'Not assigned') ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  widget.currentUser.currentPostingDisplay,
                  style: const TextStyle(fontSize: 12, color: Colors.white),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBasicInformationCard() {
    return _buildSectionCard(
      title: 'Basic Information',
      icon: Icons.person,
      children: [
        // Email (Non-editable)
        _buildInfoField(
          label: 'Email (Google Account)',
          value: widget.currentUser.email,
          icon: Icons.email_outlined,
          isEditable: false,
        ),

        const SizedBox(height: 16),

        // Name (Mandatory)
        _buildTextField(
          controller: _nameController,
          label: 'Full Name *',
          icon: Icons.person_outline,
          enabled: _isEditing,
          validator: (value) =>
              value?.trim().isEmpty == true ? 'Name is required' : null,
        ),

        const SizedBox(height: 16),

        // Mobile (Mandatory)
        // Mobile (Mandatory) - ENHANCED: With input formatting and length restriction
        TextFormField(
          controller: _mobileController,
          enabled: _isEditing,
          keyboardType: TextInputType.phone,
          maxLength: 10, // Restrict input to 10 characters
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly, // Only allow digits
            LengthLimitingTextInputFormatter(10), // Limit to 10 digits
          ],
          validator: (value) {
            if (value?.trim().isEmpty == true) {
              return 'Mobile number is required';
            }

            if (value!.length != 10) {
              return 'Mobile number must be exactly 10 digits';
            }

            // Optional: Check if it starts with valid digits (6-9)
            if (!RegExp(r'^[6-9][0-9]{9}$').hasMatch(value)) {
              return 'Enter a valid mobile number';
            }

            return null;
          },
          decoration: InputDecoration(
            labelText: 'Mobile Number *',
            prefixIcon: Icon(Icons.phone_outlined, color: Colors.grey[600]),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Theme.of(context).primaryColor),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey[200]!),
            ),
            filled: !_isEditing,
            fillColor: _isEditing ? null : Colors.grey[50],
            counterText: '', // Hide the character counter
            helperText: _isEditing ? 'Enter 10-digit mobile number' : null,
          ),
        ),

        const SizedBox(height: 16),

        // Designation (Mandatory) - UPDATED: Only editable by admins
        _buildDesignationField(),
      ],
    );
  }

  // UPDATED: New method for designation field with role-based editing
  Widget _buildDesignationField() {
    if (widget.currentUser.role == UserRole.admin) {
      // Admin can edit designations
      return _buildDropdownField<Designation>(
        label: 'Designation *',
        value: _selectedDesignation,
        icon: Icons.work_outline,
        enabled: _isEditing,
        items: Designation.values.map((designation) {
          return DropdownMenuItem<Designation>(
            value: designation,
            child: Text(
              _getDesignationDisplayName(designation),
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w400),
            ),
          );
        }).toList(),
        onChanged: _isEditing
            ? (value) {
                if (value != null && value is Designation) {
                  setState(() {
                    _selectedDesignation = value;
                  });
                }
              }
            : null,
      );
    } else {
      // Non-admin users see read-only designation
      return _buildInfoField(
        label: 'Designation',
        value: widget.currentUser.designationDisplayName,
        icon: Icons.work_outline,
        isEditable: false,
      );
    }
  }

  // UPDATED: Completely new current posting card with auto-populated hierarchy
  Widget _buildCurrentPostingCard() {
    return _buildSectionCard(
      title: 'Current Posting',
      icon: Icons.location_city,
      children: [
        // Display current hierarchy path (read-only unless admin)
        FutureBuilder<Map<String, String>>(
          future: _resolveHierarchyNames(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Container(
                padding: const EdgeInsets.all(16),
                child: const Row(
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    SizedBox(width: 12),
                    Text('Loading hierarchy...'),
                  ],
                ),
              );
            }

            if (snapshot.hasError || !snapshot.hasData) {
              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Error loading hierarchy information',
                  style: TextStyle(color: Colors.red.shade700),
                ),
              );
            }

            final hierarchy = snapshot.data!;
            return _buildHierarchyDisplay(hierarchy);
          },
        ),

        const SizedBox(height: 16),

        // Admin can edit user postings
        if (widget.currentUser.role == UserRole.admin) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.admin_panel_settings,
                  color: Colors.blue.shade700,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'As an admin, you can update user postings through the user management screen.',
                    style: TextStyle(fontSize: 12, color: Colors.blue.shade700),
                  ),
                ),
              ],
            ),
          ),
        ] else ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blue.shade700, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Your posting is determined by your role and cannot be changed here. Contact your administrator for updates.',
                    style: TextStyle(fontSize: 12, color: Colors.blue.shade700),
                  ),
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 16),

        // Role information (read-only)
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(
                  Icons.admin_panel_settings,
                  size: 16,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'User Role',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.currentUser.role.toString().split('.').last,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // UPDATED: Build the actual hierarchy display
  Widget _buildHierarchyDisplay(Map<String, String> hierarchy) {
    final theme = Theme.of(context);

    // Define the hierarchy order and their icons
    final hierarchyLevels = [
      {'key': 'company', 'label': 'Company', 'icon': Icons.business},
      {'key': 'state', 'label': 'State', 'icon': Icons.map},
      {'key': 'zone', 'label': 'Zone', 'icon': Icons.location_on},
      {
        'key': 'circle',
        'label': 'Circle',
        'icon': Icons.radio_button_unchecked,
      },
      {'key': 'division', 'label': 'Division', 'icon': Icons.segment},
      {
        'key': 'subdivision',
        'label': 'Subdivision',
        'icon': Icons.account_tree,
      },
      {
        'key': 'substation',
        'label': 'Substation',
        'icon': Icons.electrical_services,
      },
    ];

    final availableLevels = hierarchyLevels.where((level) {
      final value = hierarchy[level['key']];
      return value != null && value.isNotEmpty;
    }).toList();

    if (availableLevels.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.orange.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.orange.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Icon(Icons.warning, color: Colors.orange.shade700, size: 16),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'No posting information available. Contact your administrator.',
                style: TextStyle(fontSize: 12),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: availableLevels.map((level) {
        final value = hierarchy[level['key']]!;

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(
                  level['icon'] as IconData,
                  size: 16,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      level['label'] as String,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      value,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  // UPDATED: Method to resolve hierarchy names from IDs
  Future<Map<String, String>> _resolveHierarchyNames() async {
    final hierarchy = <String, String>{};

    try {
      // Get hierarchy info from user data
      // Note: Adjust these field names based on your actual user model
      if (widget.currentUser.companyId != null) {
        final companyDoc = await FirebaseFirestore.instance
            .collection('companys')
            .doc(widget.currentUser.companyId)
            .get();
        if (companyDoc.exists) {
          hierarchy['company'] =
              companyDoc.data()?['name'] ?? 'Unknown Company';
        }
      }

      if (widget.currentUser.stateId != null) {
        final stateDoc = await FirebaseFirestore.instance
            .collection('states')
            .doc(widget.currentUser.stateId)
            .get();
        if (stateDoc.exists) {
          hierarchy['state'] = stateDoc.data()?['name'] ?? 'Unknown State';
        }
      }

      if (widget.currentUser.zoneId != null) {
        final zoneDoc = await FirebaseFirestore.instance
            .collection('zones')
            .doc(widget.currentUser.zoneId)
            .get();
        if (zoneDoc.exists) {
          hierarchy['zone'] = zoneDoc.data()?['name'] ?? 'Unknown Zone';
        }
      }

      if (widget.currentUser.circleId != null) {
        final circleDoc = await FirebaseFirestore.instance
            .collection('circles')
            .doc(widget.currentUser.circleId)
            .get();
        if (circleDoc.exists) {
          hierarchy['circle'] = circleDoc.data()?['name'] ?? 'Unknown Circle';
        }
      }

      if (widget.currentUser.divisionId != null) {
        final divisionDoc = await FirebaseFirestore.instance
            .collection('divisions')
            .doc(widget.currentUser.divisionId)
            .get();
        if (divisionDoc.exists) {
          hierarchy['division'] =
              divisionDoc.data()?['name'] ?? 'Unknown Division';
        }
      }

      if (widget.currentUser.subdivisionId != null) {
        final subdivisionDoc = await FirebaseFirestore.instance
            .collection('subdivisions')
            .doc(widget.currentUser.subdivisionId)
            .get();
        if (subdivisionDoc.exists) {
          hierarchy['subdivision'] =
              subdivisionDoc.data()?['name'] ?? 'Unknown Subdivision';
        }
      }

      if (widget.currentUser.substationId != null) {
        final substationDoc = await FirebaseFirestore.instance
            .collection('substations')
            .doc(widget.currentUser.substationId)
            .get();
        if (substationDoc.exists) {
          hierarchy['substation'] =
              substationDoc.data()?['name'] ?? 'Unknown Substation';
        }
      }

      return hierarchy;
    } catch (e) {
      print('Error resolving hierarchy names: $e');
      return hierarchy;
    }
  }

  Widget _buildOptionalInformationCard() {
    return _buildSectionCard(
      title: 'Additional Information',
      icon: Icons.info_outline,
      children: [
        _buildTextField(
          controller: _sapIdController,
          label: 'SAP ID',
          icon: Icons.badge_outlined,
          enabled: _isEditing,
        ),

        const SizedBox(height: 16),

        _buildTextField(
          controller: _highestEducationController,
          label: 'Highest Education',
          icon: Icons.school_outlined,
          enabled: _isEditing,
        ),

        const SizedBox(height: 16),

        _buildTextField(
          controller: _collegeController,
          label: 'College/University',
          icon: Icons.account_balance_outlined,
          enabled: _isEditing,
        ),

        const SizedBox(height: 16),

        _buildTextField(
          controller: _personalEmailController,
          label: 'Personal Email',
          icon: Icons.alternate_email_outlined,
          enabled: _isEditing,
          keyboardType: TextInputType.emailAddress,
          validator: (value) {
            if (value != null && value.isNotEmpty) {
              if (!RegExp(
                r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
              ).hasMatch(value)) {
                return 'Enter a valid email address';
              }
            }
            return null;
          },
        ),
      ],
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
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: Theme.of(context).primaryColor),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool enabled = true,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      enabled: enabled,
      keyboardType: keyboardType,
      validator: validator,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: Colors.grey[600]),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Theme.of(context).primaryColor),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey[200]!),
        ),
        filled: !enabled,
        fillColor: enabled ? null : Colors.grey[50],
      ),
    );
  }

  Widget _buildInfoField({
    required String label,
    required String value,
    required IconData icon,
    bool isEditable = true,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isEditable ? null : Colors.grey[50],
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.grey[600]),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value.isEmpty ? 'Not provided' : value,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: value.isEmpty ? Colors.grey[500] : Colors.black87,
                  ),
                ),
              ],
            ),
          ),
          if (!isEditable)
            Icon(Icons.lock_outline, size: 16, color: Colors.grey[500]),
        ],
      ),
    );
  }

  Widget _buildDropdownField<T>({
    required String label,
    required T? value,
    required IconData icon,
    required List<DropdownMenuItem<T>> items,
    required void Function(T?)? onChanged,
    bool enabled = true,
  }) {
    return DropdownButtonFormField<T>(
      value: value,
      items: items,
      onChanged: enabled ? onChanged : null,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: Colors.grey[600]),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Theme.of(context).primaryColor),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey[200]!),
        ),
        filled: !enabled,
        fillColor: enabled ? null : Colors.grey[50],
      ),
    );
  }

  String _getDesignationDisplayName(Designation designation) {
    switch (designation) {
      case Designation.director:
        return 'Director';
      case Designation.chiefEngineer:
        return 'Chief Engineer (CE)';
      case Designation.superintendingEngineer:
        return 'Superintending Engineer (SE)';
      case Designation.executiveEngineer:
        return 'Executive Engineer (EE)';
      case Designation.assistantEngineerSDO:
        return 'Assistant Engineer/SDO (AE/SDO)';
      case Designation.juniorEngineer:
        return 'Junior Engineer (JE)';
      case Designation.technician:
        return 'Technician';
    }
  }

  // UPDATED: Simplified save profile method
  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final updatedUser = widget.currentUser.copyWith(
        name: _nameController.text.trim(),
        mobile: _mobileController.text.trim(),
        designation: _selectedDesignation,
        sapId: _sapIdController.text.trim().isEmpty
            ? null
            : _sapIdController.text.trim(),
        highestEducation: _highestEducationController.text.trim().isEmpty
            ? null
            : _highestEducationController.text.trim(),
        college: _collegeController.text.trim().isEmpty
            ? null
            : _collegeController.text.trim(),
        personalEmail: _personalEmailController.text.trim().isEmpty
            ? null
            : _personalEmailController.text.trim(),
        profileCompleted: true,
        updatedAt: Timestamp.now(),
      );

      await UserService.updateUser(updatedUser);

      setState(() {
        _isLoading = false;
        _isEditing = false;
      });

      _showSuccessSnackBar('Profile updated successfully');
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showErrorSnackBar('Failed to update profile: $e');
    }
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

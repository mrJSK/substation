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
  Designation _selectedDesignation = Designation.technician;
  String? _selectedCompanyId;
  String? _selectedStateId;
  String? _selectedZoneId;
  String? _selectedCircleId;
  String? _selectedDivisionId;
  String? _selectedSubdivisionId;
  String? _selectedSubstationId;

  // Dropdown data
  List<Map<String, String>> _companies = [];
  List<Map<String, String>> _states = [];
  List<Map<String, String>> _zones = [];
  List<Map<String, String>> _circles = [];
  List<Map<String, String>> _divisions = [];
  List<Map<String, String>> _subdivisions = [];
  List<Map<String, String>> _substations = [];

  @override
  void initState() {
    super.initState();
    _initializeControllers();
    _loadHierarchyData();
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
    _selectedCompanyId = widget.currentUser.companyId;
    _selectedStateId = widget.currentUser.stateId;
    _selectedZoneId = widget.currentUser.zoneId;
    _selectedCircleId = widget.currentUser.circleId;
    _selectedDivisionId = widget.currentUser.divisionId;
    _selectedSubdivisionId = widget.currentUser.subdivisionId;
    _selectedSubstationId = widget.currentUser.substationId;
  }

  Future<void> _loadHierarchyData() async {
    try {
      // Load companies
      final companiesSnapshot = await FirebaseFirestore.instance
          .collection('companies')
          .orderBy('name')
          .get();
      _companies = companiesSnapshot.docs
          .map((doc) => {'id': doc.id, 'name': doc['name'] as String})
          .toList();

      // Load other hierarchy data based on selections
      if (_selectedCompanyId != null) {
        await _loadStates();
        if (_selectedStateId != null) {
          await _loadZones();
          if (_selectedZoneId != null) {
            await _loadCircles();
            if (_selectedCircleId != null) {
              await _loadDivisions();
              if (_selectedDivisionId != null) {
                await _loadSubdivisions();
                if (_selectedSubdivisionId != null) {
                  await _loadSubstations();
                }
              }
            }
          }
        }
      }

      setState(() {});
    } catch (e) {
      _showErrorSnackBar('Error loading hierarchy data: $e');
    }
  }

  Future<void> _loadStates() async {
    if (_selectedCompanyId == null) return;

    final statesSnapshot = await FirebaseFirestore.instance
        .collection('states')
        .where('companyId', isEqualTo: _selectedCompanyId)
        .orderBy('name')
        .get();
    _states = statesSnapshot.docs
        .map((doc) => {'id': doc.id, 'name': doc['name'] as String})
        .toList();
  }

  Future<void> _loadZones() async {
    if (_selectedStateId == null) return;

    final zonesSnapshot = await FirebaseFirestore.instance
        .collection('zones')
        .where('stateId', isEqualTo: _selectedStateId)
        .orderBy('name')
        .get();
    _zones = zonesSnapshot.docs
        .map((doc) => {'id': doc.id, 'name': doc['name'] as String})
        .toList();
  }

  Future<void> _loadCircles() async {
    if (_selectedZoneId == null) return;

    final circlesSnapshot = await FirebaseFirestore.instance
        .collection('circles')
        .where('zoneId', isEqualTo: _selectedZoneId)
        .orderBy('name')
        .get();
    _circles = circlesSnapshot.docs
        .map((doc) => {'id': doc.id, 'name': doc['name'] as String})
        .toList();
  }

  Future<void> _loadDivisions() async {
    if (_selectedCircleId == null) return;

    final divisionsSnapshot = await FirebaseFirestore.instance
        .collection('divisions')
        .where('circleId', isEqualTo: _selectedCircleId)
        .orderBy('name')
        .get();
    _divisions = divisionsSnapshot.docs
        .map((doc) => {'id': doc.id, 'name': doc['name'] as String})
        .toList();
  }

  Future<void> _loadSubdivisions() async {
    if (_selectedDivisionId == null) return;

    final subdivisionsSnapshot = await FirebaseFirestore.instance
        .collection('subdivisions')
        .where('divisionId', isEqualTo: _selectedDivisionId)
        .orderBy('name')
        .get();
    _subdivisions = subdivisionsSnapshot.docs
        .map((doc) => {'id': doc.id, 'name': doc['name'] as String})
        .toList();
  }

  Future<void> _loadSubstations() async {
    if (_selectedSubdivisionId == null) return;

    final substationsSnapshot = await FirebaseFirestore.instance
        .collection('substations')
        .where('subdivisionId', isEqualTo: _selectedSubdivisionId)
        .orderBy('name')
        .get();
    _substations = substationsSnapshot.docs
        .map((doc) => {'id': doc.id, 'name': doc['name'] as String})
        .toList();
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
      backgroundColor: Color(0xFFFAFAFA),
      appBar: AppBar(
        title: Text(
          'Profile',
          style: TextStyle(fontWeight: FontWeight.w600, color: Colors.black87),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.black87),
        actions: [
          if (!_isEditing)
            IconButton(
              icon: Icon(Icons.edit),
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
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    // Profile Header
                    _buildProfileHeader(),

                    SizedBox(height: 24),

                    // Basic Information
                    _buildBasicInformationCard(),

                    SizedBox(height: 16),

                    // Current Posting
                    _buildCurrentPostingCard(),

                    SizedBox(height: 16),

                    // Optional Information
                    _buildOptionalInformationCard(),

                    SizedBox(height: 80), // Space for floating action button
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
              child: Icon(Icons.close, color: Colors.white),
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
        padding: EdgeInsets.all(20),
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
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
            SizedBox(height: 16),
            Text(
              widget.currentUser.name.isNotEmpty
                  ? widget.currentUser.name
                  : 'User Name',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            SizedBox(height: 4),
            Text(
              widget.currentUser.designationDisplayName,
              style: TextStyle(
                fontSize: 14,
                color: Colors.white.withOpacity(0.9),
              ),
            ),
            if (widget.currentUser.currentPostingDisplay != 'Not assigned') ...[
              SizedBox(height: 8),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  widget.currentUser.currentPostingDisplay,
                  style: TextStyle(fontSize: 12, color: Colors.white),
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

        SizedBox(height: 16),

        // Name (Mandatory)
        _buildTextField(
          controller: _nameController,
          label: 'Full Name *',
          icon: Icons.person_outline,
          enabled: _isEditing,
          validator: (value) =>
              value?.trim().isEmpty == true ? 'Name is required' : null,
        ),

        SizedBox(height: 16),

        // Mobile (Mandatory)
        _buildTextField(
          controller: _mobileController,
          label: 'Mobile Number *',
          icon: Icons.phone_outlined,
          enabled: _isEditing,
          keyboardType: TextInputType.phone,
          validator: (value) {
            if (value?.trim().isEmpty == true)
              return 'Mobile number is required';
            if (value!.length < 10) return 'Enter a valid mobile number';
            return null;
          },
        ),

        SizedBox(height: 16),

        // Designation (Mandatory)
        _buildDropdownField<Designation>(
          label: 'Designation *',
          value: _selectedDesignation,
          icon: Icons.work_outline,
          enabled: _isEditing,
          items: Designation.values.map((designation) {
            return DropdownMenuItem<Designation>(
              value: designation,
              child: Text(_getDesignationDisplayName(designation)),
            );
          }).toList(),
          onChanged: _isEditing
              ? (value) {
                  if (value != null && value is Designation) {
                    // Safe type check
                    setState(() {
                      _selectedDesignation = value;
                    });
                  }
                }
              : null,
        ),
      ],
    );
  }

  Widget _buildCurrentPostingCard() {
    return _buildSectionCard(
      title: 'Current Posting *',
      icon: Icons.location_city,
      children: [
        Text(
          'Select your current posting in the organizational hierarchy',
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
        SizedBox(height: 16),

        // Company
        _buildHierarchyDropdown(
          label: 'Company *',
          value: _selectedCompanyId,
          items: _companies,
          onChanged: _isEditing
              ? (value) async {
                  setState(() {
                    _selectedCompanyId = value;
                    _selectedStateId = null;
                    _selectedZoneId = null;
                    _selectedCircleId = null;
                    _selectedDivisionId = null;
                    _selectedSubdivisionId = null;
                    _selectedSubstationId = null;
                    _states.clear();
                    _zones.clear();
                    _circles.clear();
                    _divisions.clear();
                    _subdivisions.clear();
                    _substations.clear();
                  });
                  if (value != null) {
                    await _loadStates();
                    setState(() {});
                  }
                }
              : null,
        ),

        if (_states.isNotEmpty) ...[
          SizedBox(height: 16),
          _buildHierarchyDropdown(
            label: 'State *',
            value: _selectedStateId,
            items: _states,
            onChanged: _isEditing
                ? (value) async {
                    setState(() {
                      _selectedStateId = value;
                      _selectedZoneId = null;
                      _selectedCircleId = null;
                      _selectedDivisionId = null;
                      _selectedSubdivisionId = null;
                      _selectedSubstationId = null;
                      _zones.clear();
                      _circles.clear();
                      _divisions.clear();
                      _subdivisions.clear();
                      _substations.clear();
                    });
                    if (value != null) {
                      await _loadZones();
                      setState(() {});
                    }
                  }
                : null,
          ),
        ],

        if (_zones.isNotEmpty) ...[
          SizedBox(height: 16),
          _buildHierarchyDropdown(
            label: 'Zone *',
            value: _selectedZoneId,
            items: _zones,
            onChanged: _isEditing
                ? (value) async {
                    setState(() {
                      _selectedZoneId = value;
                      _selectedCircleId = null;
                      _selectedDivisionId = null;
                      _selectedSubdivisionId = null;
                      _selectedSubstationId = null;
                      _circles.clear();
                      _divisions.clear();
                      _subdivisions.clear();
                      _substations.clear();
                    });
                    if (value != null) {
                      await _loadCircles();
                      setState(() {});
                    }
                  }
                : null,
          ),
        ],

        if (_circles.isNotEmpty) ...[
          SizedBox(height: 16),
          _buildHierarchyDropdown(
            label: 'Circle *',
            value: _selectedCircleId,
            items: _circles,
            onChanged: _isEditing
                ? (value) async {
                    setState(() {
                      _selectedCircleId = value;
                      _selectedDivisionId = null;
                      _selectedSubdivisionId = null;
                      _selectedSubstationId = null;
                      _divisions.clear();
                      _subdivisions.clear();
                      _substations.clear();
                    });
                    if (value != null) {
                      await _loadDivisions();
                      setState(() {});
                    }
                  }
                : null,
          ),
        ],

        if (_divisions.isNotEmpty) ...[
          SizedBox(height: 16),
          _buildHierarchyDropdown(
            label: 'Division *',
            value: _selectedDivisionId,
            items: _divisions,
            onChanged: _isEditing
                ? (value) async {
                    setState(() {
                      _selectedDivisionId = value;
                      _selectedSubdivisionId = null;
                      _selectedSubstationId = null;
                      _subdivisions.clear();
                      _substations.clear();
                    });
                    if (value != null) {
                      await _loadSubdivisions();
                      setState(() {});
                    }
                  }
                : null,
          ),
        ],

        if (_subdivisions.isNotEmpty) ...[
          SizedBox(height: 16),
          _buildHierarchyDropdown(
            label: 'Subdivision *',
            value: _selectedSubdivisionId,
            items: _subdivisions,
            onChanged: _isEditing
                ? (value) async {
                    setState(() {
                      _selectedSubdivisionId = value;
                      _selectedSubstationId = null;
                      _substations.clear();
                    });
                    if (value != null) {
                      await _loadSubstations();
                      setState(() {});
                    }
                  }
                : null,
          ),
        ],

        if (_substations.isNotEmpty) ...[
          SizedBox(height: 16),
          _buildHierarchyDropdown(
            label: 'Substation (Optional)',
            value: _selectedSubstationId,
            items: _substations,
            onChanged: _isEditing
                ? (value) {
                    setState(() {
                      _selectedSubstationId = value;
                    });
                  }
                : null,
          ),
        ],
      ],
    );
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

        SizedBox(height: 16),

        _buildTextField(
          controller: _highestEducationController,
          label: 'Highest Education',
          icon: Icons.school_outlined,
          enabled: _isEditing,
        ),

        SizedBox(height: 16),

        _buildTextField(
          controller: _collegeController,
          label: 'College/University',
          icon: Icons.account_balance_outlined,
          enabled: _isEditing,
        ),

        SizedBox(height: 16),

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
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isEditable ? null : Colors.grey[50],
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.grey[600]),
          SizedBox(width: 12),
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
                SizedBox(height: 4),
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
    required T value,
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

  Widget _buildHierarchyDropdown({
    required String label,
    required String? value,
    required List<Map<String, String>> items,
    required void Function(String?)? onChanged,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      items: [
        DropdownMenuItem<String>(value: null, child: Text('Select $label')),
        ...items.map((item) {
          return DropdownMenuItem<String>(
            value: item['id'],
            child: Text(item['name']!),
          );
        }).toList(),
      ],
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(Icons.location_city_outlined, color: Colors.grey[600]),
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
      validator: label.contains('*')
          ? (value) {
              if (value == null || value.isEmpty) {
                return '$label is required';
              }
              return null;
            }
          : null,
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

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Validate mandatory hierarchy selection
    if (_selectedCompanyId == null || _selectedSubdivisionId == null) {
      _showErrorSnackBar(
        'Please select your current posting up to subdivision level',
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Get names for selected IDs
      String? companyName = _companies.firstWhere(
        (c) => c['id'] == _selectedCompanyId,
        orElse: () => {'name': ''},
      )['name'];
      String? stateName = _states.firstWhere(
        (s) => s['id'] == _selectedStateId,
        orElse: () => {'name': ''},
      )['name'];
      String? zoneName = _zones.firstWhere(
        (z) => z['id'] == _selectedZoneId,
        orElse: () => {'name': ''},
      )['name'];
      String? circleName = _circles.firstWhere(
        (c) => c['id'] == _selectedCircleId,
        orElse: () => {'name': ''},
      )['name'];
      String? divisionName = _divisions.firstWhere(
        (d) => d['id'] == _selectedDivisionId,
        orElse: () => {'name': ''},
      )['name'];
      String? subdivisionName = _subdivisions.firstWhere(
        (s) => s['id'] == _selectedSubdivisionId,
        orElse: () => {'name': ''},
      )['name'];
      String? substationName = _selectedSubstationId != null
          ? _substations.firstWhere(
              (s) => s['id'] == _selectedSubstationId,
              orElse: () => {'name': ''},
            )['name']
          : null;

      final updatedUser = widget.currentUser.copyWith(
        name: _nameController.text.trim(),
        mobile: _mobileController.text.trim(),
        designation: _selectedDesignation,
        companyId: _selectedCompanyId,
        companyName: companyName?.isEmpty == true ? null : companyName,
        stateId: _selectedStateId,
        stateName: stateName?.isEmpty == true ? null : stateName,
        zoneId: _selectedZoneId,
        zoneName: zoneName?.isEmpty == true ? null : zoneName,
        circleId: _selectedCircleId,
        circleName: circleName?.isEmpty == true ? null : circleName,
        divisionId: _selectedDivisionId,
        divisionName: divisionName?.isEmpty == true ? null : divisionName,
        subdivisionId: _selectedSubdivisionId,
        subdivisionName: subdivisionName?.isEmpty == true
            ? null
            : subdivisionName,
        substationId: _selectedSubstationId,
        substationName: substationName?.isEmpty == true ? null : substationName,
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

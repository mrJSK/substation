import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../models/hierarchy_models.dart';
import '../utils/snackbar_utils.dart';

const List<String> DESIGNATION_OPTIONS = ['CE', 'SE', 'EE', 'SDO', 'JE'];

class AddHierarchyDialog extends StatefulWidget {
  final String hierarchyType;
  final String? parentId;
  final String? parentIdFieldName;
  final AppUser currentUser;

  const AddHierarchyDialog({
    super.key,
    required this.hierarchyType,
    this.parentId,
    this.parentIdFieldName,
    required this.currentUser,
  });

  @override
  State<AddHierarchyDialog> createState() => _AddHierarchyDialogState();
}

class _AddHierarchyDialogState extends State<AddHierarchyDialog>
    with TickerProviderStateMixin {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _landmarkController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _contactNumberController =
      TextEditingController();
  final TextEditingController _contactPersonController =
      TextEditingController();

  String? _selectedDesignation;
  bool _isSaving = false;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _scaleAnimation = Tween<double>(begin: 0.95, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _landmarkController.dispose();
    _addressController.dispose();
    _contactNumberController.dispose();
    _contactPersonController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  String get _displayName {
    return widget.hierarchyType.replaceAll('Distribution', 'Dist. ');
  }

  IconData get _hierarchyIcon {
    switch (widget.hierarchyType) {
      case 'DistributionZone':
        return Icons.public;
      case 'DistributionCircle':
        return Icons.radio_button_unchecked;
      case 'DistributionDivision':
        return Icons.account_tree;
      case 'DistributionSubdivision':
        return Icons.location_on;
      default:
        return Icons.folder;
    }
  }

  Future<void> _saveHierarchyItem() async {
    if (_isSaving || !_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final String collectionName;
      Map<String, dynamic> data = {
        'name': _nameController.text.trim(),
        'description': _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        'address': _addressController.text.trim().isEmpty
            ? null
            : _addressController.text.trim(),
        'landmark': _landmarkController.text.trim().isEmpty
            ? null
            : _landmarkController.text.trim(),
        'contactNumber': _contactNumberController.text.trim().isEmpty
            ? null
            : _contactNumberController.text.trim(),
        'contactPerson': _contactPersonController.text.trim().isEmpty
            ? null
            : _contactPersonController.text.trim(),
        'contactDesignation': _selectedDesignation,
        'createdBy': widget.currentUser.uid,
        'createdAt': Timestamp.now(),
      };

      HierarchyItem? newHierarchyItem;

      switch (widget.hierarchyType) {
        case 'DistributionZone':
          collectionName = 'distributionZones';
          data['stateName'] = 'Uttar Pradesh';
          break;
        case 'DistributionCircle':
          collectionName = 'distributionCircles';
          if (widget.parentId == null || widget.parentIdFieldName == null) {
            throw 'Parent Zone ID and field name are required for creating a Distribution Circle.';
          }
          data[widget.parentIdFieldName!] = widget.parentId!;
          break;
        case 'DistributionDivision':
          collectionName = 'distributionDivisions';
          if (widget.parentId == null || widget.parentIdFieldName == null) {
            throw 'Parent Circle ID and field name are required for creating a Distribution Division.';
          }
          data[widget.parentIdFieldName!] = widget.parentId!;
          break;
        case 'DistributionSubdivision':
          collectionName = 'distributionSubdivisions';
          if (widget.parentId == null || widget.parentIdFieldName == null) {
            throw 'Parent Division ID and field name are required for creating a Distribution Subdivision.';
          }
          data[widget.parentIdFieldName!] = widget.parentId!;
          data['substationIds'] = [];
          break;
        default:
          throw 'Unsupported hierarchy type: ${widget.hierarchyType}';
      }

      // Save to Firestore
      final docRef = await FirebaseFirestore.instance
          .collection(collectionName)
          .add(data);

      // Fetch the newly created document
      final newDoc = await docRef.get();
      if (!newDoc.exists) {
        throw 'Failed to retrieve the newly created document.';
      }

      // Create the appropriate model instance
      switch (widget.hierarchyType) {
        case 'DistributionZone':
          newHierarchyItem = DistributionZone.fromFirestore(newDoc);
          break;
        case 'DistributionCircle':
          newHierarchyItem = DistributionCircle.fromFirestore(newDoc);
          break;
        case 'DistributionDivision':
          newHierarchyItem = DistributionDivision.fromFirestore(newDoc);
          break;
        case 'DistributionSubdivision':
          newHierarchyItem = DistributionSubdivision.fromFirestore(newDoc);
          break;
      }

      if (mounted) {
        SnackBarUtils.showSnackBar(
          context,
          '${_displayName} created successfully!',
        );
        Navigator.of(context).pop(newHierarchyItem);
      }
    } on FirebaseException catch (e) {
      if (mounted) {
        String errorMessage;
        switch (e.code) {
          case 'permission-denied':
            errorMessage =
                'You do not have permission to create a ${_displayName}.';
            break;
          case 'unavailable':
            errorMessage =
                'Network error: Please check your internet connection.';
            break;
          default:
            errorMessage = 'Failed to create ${_displayName}: ${e.message}';
        }
        SnackBarUtils.showSnackBar(context, errorMessage, isError: true);
      }
    } catch (e) {
      if (mounted) {
        SnackBarUtils.showSnackBar(
          context,
          'Failed to create ${_displayName}: $e',
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Opacity(
            opacity: _fadeAnimation.value,
            child: Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 8,
              child: Container(
                constraints: const BoxConstraints(
                  maxWidth: 500,
                  maxHeight: 750,
                ),
                decoration: BoxDecoration(
                  color: isDarkMode ? Colors.grey[900] : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildHeader(theme, isDarkMode),
                    Flexible(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(24),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildInfoCard(theme, isDarkMode),
                              const SizedBox(height: 24),
                              _buildBasicInfoSection(theme, isDarkMode),
                              const SizedBox(height: 24),
                              _buildContactInfoSection(theme, isDarkMode),
                              const SizedBox(height: 24),
                              _buildLocationInfoSection(theme, isDarkMode),
                            ],
                          ),
                        ),
                      ),
                    ),
                    _buildActionButtons(theme, isDarkMode),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(ThemeData theme, bool isDarkMode) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.primaryColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Row(
        children: [
          Icon(_hierarchyIcon, color: Colors.white, size: 24),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              'Create ${_displayName}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(ThemeData theme, bool isDarkMode) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.grey[800] : Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: theme.primaryColor, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Enter details for the new ${_displayName.toLowerCase()}. Required fields are marked with an asterisk (*).',
              style: TextStyle(
                color: isDarkMode ? Colors.grey[300] : Colors.grey[700],
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBasicInfoSection(ThemeData theme, bool isDarkMode) {
    return _buildSection(
      title: 'Basic Information',
      icon: Icons.info_outline,
      children: [
        _buildTextField(
          controller: _nameController,
          label: '${_displayName} Name*',
          hint: 'Enter ${_displayName.toLowerCase()} name',
          icon: Icons.drive_file_rename_outline,
          validator: (value) => value!.isEmpty ? 'Name is required' : null,
          theme: theme,
          isDarkMode: isDarkMode,
        ),
        const SizedBox(height: 16),
        _buildTextField(
          controller: _descriptionController,
          label: 'Description',
          hint: 'Enter description',
          icon: Icons.description,
          maxLines: 3,
          theme: theme,
          isDarkMode: isDarkMode,
        ),
      ],
    );
  }

  Widget _buildContactInfoSection(ThemeData theme, bool isDarkMode) {
    return _buildSection(
      title: 'Contact Information',
      icon: Icons.contacts,
      children: [
        _buildTextField(
          controller: _contactPersonController,
          label: 'Contact Person*',
          hint: 'Enter contact person name',
          icon: Icons.person,
          validator: (value) =>
              value!.isEmpty ? 'Contact Person is required' : null,
          theme: theme,
          isDarkMode: isDarkMode,
        ),
        const SizedBox(height: 16),
        _buildDesignationDropdown(theme, isDarkMode),
        const SizedBox(height: 16),
        _buildTextField(
          controller: _contactNumberController,
          label: 'Contact Number',
          hint: 'Enter contact number',
          icon: Icons.phone,
          keyboardType: TextInputType.phone,
          theme: theme,
          isDarkMode: isDarkMode,
        ),
      ],
    );
  }

  Widget _buildLocationInfoSection(ThemeData theme, bool isDarkMode) {
    return _buildSection(
      title: 'Location Information',
      icon: Icons.location_on,
      children: [
        _buildTextField(
          controller: _addressController,
          label: 'Address',
          hint: 'Enter address',
          icon: Icons.home,
          theme: theme,
          isDarkMode: isDarkMode,
        ),
        const SizedBox(height: 16),
        _buildTextField(
          controller: _landmarkController,
          label: 'Landmark',
          hint: 'Enter landmark',
          icon: Icons.flag,
          theme: theme,
          isDarkMode: isDarkMode,
        ),
      ],
    );
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: Theme.of(context).primaryColor, size: 20),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).textTheme.bodyLarge?.color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ...children,
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required ThemeData theme,
    required bool isDarkMode,
    String? Function(String?)? validator,
    int maxLines = 1,
    TextInputType? keyboardType,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      validator: validator,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: theme.primaryColor),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: isDarkMode ? Colors.grey[700]! : Colors.grey[300]!,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: isDarkMode ? Colors.grey[700]! : Colors.grey[300]!,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: theme.primaryColor, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red, width: 2),
        ),
        filled: true,
        fillColor: isDarkMode ? Colors.grey[800] : Colors.grey[100],
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
      ),
    );
  }

  Widget _buildDesignationDropdown(ThemeData theme, bool isDarkMode) {
    return DropdownButtonFormField<String>(
      value: _selectedDesignation,
      decoration: InputDecoration(
        labelText: 'Designation*',
        prefixIcon: Icon(Icons.badge, color: theme.primaryColor),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: isDarkMode ? Colors.grey[700]! : Colors.grey[300]!,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: isDarkMode ? Colors.grey[700]! : Colors.grey[300]!,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: theme.primaryColor, width: 2),
        ),
        filled: true,
        fillColor: isDarkMode ? Colors.grey[800] : Colors.grey[100],
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
      ),
      items: DESIGNATION_OPTIONS.map((designation) {
        return DropdownMenuItem(value: designation, child: Text(designation));
      }).toList(),
      onChanged: _isSaving
          ? null
          : (value) => setState(() => _selectedDesignation = value),
      validator: (value) => value == null ? 'Designation is required' : null,
      dropdownColor: isDarkMode ? Colors.grey[800] : Colors.white,
    );
  }

  Widget _buildActionButtons(ThemeData theme, bool isDarkMode) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                side: BorderSide(
                  color: isDarkMode ? Colors.grey[700]! : Colors.grey[300]!,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'Cancel',
                style: TextStyle(
                  color: isDarkMode ? Colors.grey[300] : Colors.grey[700],
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton(
              onPressed: _isSaving ? null : _saveHierarchyItem,
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: _isSaving
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation(Colors.white),
                          ),
                        ),
                        SizedBox(width: 8),
                        Text('Creating...'),
                      ],
                    )
                  : const Text(
                      'Create',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

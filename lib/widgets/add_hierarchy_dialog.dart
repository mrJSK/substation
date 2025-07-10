// lib/widgets/add_hierarchy_dialog.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../models/hierarchy_models.dart';
import '../utils/snackbar_utils.dart';

// Define the global list of designation options
const List<String> DESIGNATION_OPTIONS = ['CE', 'SE', 'EE', 'SDO', 'JE'];

class AddHierarchyDialog extends StatefulWidget {
  final String
  hierarchyType; // e.g., 'DistributionZone', 'DistributionCircle', 'DistributionDivision', 'DistributionSubdivision'
  final String?
  parentId; // ID of the parent hierarchy item (e.g., zoneId for circle)
  final String?
  parentIdFieldName; // Field name for parent ID (e.g., 'distributionZoneId')
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

class _AddHierarchyDialogState extends State<AddHierarchyDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _landmarkController = TextEditingController();
  final TextEditingController _contactNumberController =
      TextEditingController();
  final TextEditingController _contactPersonController =
      TextEditingController();
  String? _selectedDesignation;
  bool _isSaving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _landmarkController.dispose();
    _contactNumberController.dispose();
    _contactPersonController.dispose();
    super.dispose();
  }

  Future<void> _saveHierarchyItem() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final String collectionName;
      Map<String, dynamic> data = {
        'name': _nameController.text.trim(),
        'description': _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
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
          data['stateName'] =
              'Uttar Pradesh'; // Assuming a default state for now, or fetch from user context
          break;
        case 'DistributionCircle':
          collectionName = 'distributionCircles';
          if (widget.parentId == null || widget.parentIdFieldName == null) {
            throw 'Parent Zone is required for creating a Distribution Circle.';
          }
          data[widget.parentIdFieldName!] = widget.parentId!;
          break;
        case 'DistributionDivision':
          collectionName = 'distributionDivisions';
          if (widget.parentId == null || widget.parentIdFieldName == null) {
            throw 'Parent Circle is required for creating a Distribution Division.';
          }
          data[widget.parentIdFieldName!] = widget.parentId!;
          break;
        case 'DistributionSubdivision': // Handle DistributionSubdivision creation
          collectionName = 'distributionSubdivisions';
          if (widget.parentId == null || widget.parentIdFieldName == null) {
            throw 'Parent Division is required for creating a Distribution Subdivision.';
          }
          data[widget.parentIdFieldName!] = widget.parentId!;
          break;
        default:
          throw 'Unsupported hierarchy type: ${widget.hierarchyType}';
      }

      final docRef = await FirebaseFirestore.instance
          .collection(collectionName)
          .add(data);
      final newDoc = await docRef.get();

      // Convert the new document to the appropriate HierarchyItem subclass
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
          '${widget.hierarchyType} created successfully!',
        );
        Navigator.of(
          context,
        ).pop(newHierarchyItem); // Return the newly created item
      }
    } catch (e) {
      if (mounted) {
        SnackBarUtils.showSnackBar(
          context,
          'Failed to create ${widget.hierarchyType}: $e',
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        'Create New ${widget.hierarchyType.replaceAll('Distribution', 'Dist. ')}',
      ),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText:
                      '${widget.hierarchyType.replaceAll('Distribution', 'Dist. ')} Name',
                  prefixIcon: const Icon(Icons.drive_file_rename_outline),
                ),
                validator: (value) =>
                    value!.isEmpty ? 'Name is required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _contactPersonController,
                decoration: const InputDecoration(
                  labelText: 'Contact Person Name',
                  prefixIcon: Icon(Icons.person),
                ),
                validator: (value) =>
                    value!.isEmpty ? 'Contact Person is required' : null,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedDesignation,
                decoration: const InputDecoration(
                  labelText: 'Designation',
                  prefixIcon: Icon(Icons.badge),
                ),
                items: DESIGNATION_OPTIONS.map((designation) {
                  return DropdownMenuItem(
                    value: designation,
                    child: Text(designation),
                  );
                }).toList(),
                onChanged: (value) =>
                    setState(() => _selectedDesignation = value),
                validator: (value) =>
                    value == null ? 'Designation is required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description (Optional)',
                  prefixIcon: Icon(Icons.description),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _landmarkController,
                decoration: const InputDecoration(
                  labelText: 'Landmark (Optional)',
                  prefixIcon: Icon(Icons.flag),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _contactNumberController,
                decoration: const InputDecoration(
                  labelText: 'Contact Number (Optional)',
                  prefixIcon: Icon(Icons.phone),
                ),
                keyboardType: TextInputType.phone,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(
            context,
          ).pop(), // Close dialog without returning data
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isSaving ? null : _saveHierarchyItem,
          child: _isSaving
              ? const CircularProgressIndicator(strokeWidth: 2)
              : const Text('Create'),
        ),
      ],
    );
  }
}

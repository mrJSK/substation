// lib/screens/bay_equipment_management_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:substation_manager/models/equipment_model.dart';
import 'package:substation_manager/models/user_model.dart';
import '../utils/snackbar_utils.dart';
import 'equipment_assignment_screen.dart'; // For adding and editing equipment

class BayEquipmentManagementScreen extends StatelessWidget {
  final String bayId;
  final String bayName;
  final String substationId; // Added for EquipmentAssignmentScreen context

  const BayEquipmentManagementScreen({
    super.key,
    required this.bayId,
    required this.bayName,
    required this.substationId,
    required AppUser currentUser,
  });

  Future<void> _confirmDeleteEquipment(
    BuildContext context,
    String equipmentId,
    String equipmentName,
  ) async {
    final bool confirm =
        await showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('Confirm Deletion'),
              content: Text(
                'Are you sure you want to delete equipment "$equipmentName"? This action cannot be undone.',
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
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
            .collection('equipmentInstances')
            .doc(equipmentId)
            .delete();
        if (context.mounted) {
          SnackBarUtils.showSnackBar(
            context,
            'Equipment "$equipmentName" deleted successfully!',
          );
        }
      } catch (e) {
        print("Error deleting equipment: $e");
        if (context.mounted) {
          SnackBarUtils.showSnackBar(
            context,
            'Failed to delete equipment "$equipmentName": $e',
            isError: true,
          );
        }
      }
    }
  }

  // Helper method to recursively build the display for custom fields
  Widget _buildCustomFieldsDisplay(
    BuildContext context,
    Map<String, dynamic> customFieldValues, {
    int level = 0,
  }) {
    if (customFieldValues.isEmpty) {
      return Padding(
        padding: EdgeInsets.only(left: level * 8.0),
        child: Text(
          'No custom values defined.',
          style: TextStyle(
            fontStyle: FontStyle.italic,
            color: Colors.grey.shade600,
          ),
        ),
      );
    }

    // Add indentation for nested levels
    final double indentation = level * 16.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: customFieldValues.entries.map((entry) {
        final key = entry.key;
        final value = entry.value;

        if (value is Map<String, dynamic> &&
            value.containsKey('value') &&
            value.containsKey('description_remarks')) {
          // This might be a boolean field with remarks
          return Padding(
            padding: EdgeInsets.only(left: indentation),
            child: Text(
              '$key: ${value['value'] == true ? 'Yes' : 'No'}${value['description_remarks'] != null && value['description_remarks'].isNotEmpty ? ' (${value['description_remarks']})' : ''}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          );
        } else if (value is Map<String, dynamic>) {
          // This is a nested group/section field
          return Padding(
            padding: EdgeInsets.only(left: indentation),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$key (Group):',
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
                _buildCustomFieldsDisplay(context, value, level: level + 1),
              ],
            ),
          );
        } else if (value is List<dynamic>) {
          // This is a list of items (e.g., from a 'group' field with multiple entries)
          return Padding(
            padding: EdgeInsets.only(left: indentation),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$key (List - ${value.length} items):',
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
                if (value.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(left: 8.0),
                    child: Text(
                      'No items in this list.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ...value.asMap().entries.map((itemEntry) {
                  final itemIndex = itemEntry.key;
                  final itemMap = itemEntry
                      .value; // This should be a Map<String, dynamic> for each item
                  if (itemMap is Map<String, dynamic>) {
                    return Padding(
                      padding: const EdgeInsets.only(left: 8.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Item ${itemIndex + 1}:',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          _buildCustomFieldsDisplay(
                            context,
                            itemMap,
                            level: level + 2,
                          ),
                        ],
                      ),
                    );
                  } else {
                    return Padding(
                      padding: const EdgeInsets.only(left: 8.0),
                      child: Text(
                        'Item ${itemIndex + 1}: $itemMap',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    );
                  }
                }).toList(),
              ],
            ),
          );
        } else {
          // Standard key-value pair
          return Padding(
            padding: EdgeInsets.only(left: indentation),
            child: Text(
              '$key: ${value ?? 'N/A'}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          );
        }
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Bay: ${bayName}')),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('equipmentInstances')
            .where('bayId', isEqualTo: bayId)
            .orderBy('equipmentTypeName')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error: ${snapshot.error}',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'No equipment found in bay "${bayName}". Click the "+" button to add some.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontStyle: FontStyle.italic,
                    color: Colors.grey.shade600,
                  ),
                ),
              ),
            );
          }

          final equipmentInstances = snapshot.data!.docs
              .map((doc) => EquipmentInstance.fromFirestore(doc))
              .toList();

          return ListView.builder(
            padding: const EdgeInsets.all(16.0),
            itemCount: equipmentInstances.length,
            itemBuilder: (context, index) {
              final equipment = equipmentInstances[index];
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 8.0),
                elevation: 2,
                child: ExpansionTile(
                  leading: Icon(
                    Icons.device_hub,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  title: Text(equipment.equipmentTypeName),
                  subtitle: Text('Symbol: ${equipment.symbolKey}'),
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Equipment ID: ${equipment.id}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          Text(
                            'Bay ID: ${equipment.bayId}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          Text(
                            'Template ID: ${equipment.templateId}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Custom Field Values:',
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          _buildCustomFieldsDisplay(
                            context,
                            equipment.customFieldValues,
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit),
                                color: Theme.of(context).colorScheme.tertiary,
                                onPressed: () {
                                  // Navigates to the assignment screen in "edit" mode
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          EquipmentAssignmentScreen(
                                            bayId: bayId,
                                            bayName: bayName,
                                            substationId: substationId,
                                            equipmentToEdit: equipment,
                                          ),
                                    ),
                                  );
                                },
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline),
                                color: Theme.of(context).colorScheme.error,
                                onPressed: () => _confirmDeleteEquipment(
                                  context,
                                  equipment.id,
                                  equipment.equipmentTypeName,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          // Navigates to the assignment screen in "add new" mode
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => EquipmentAssignmentScreen(
                bayId: bayId,
                bayName: bayName,
                substationId: substationId,
              ),
            ),
          );
        },
        label: const Text('Add New Equipment'),
        icon: const Icon(Icons.add),
        backgroundColor: Theme.of(context).colorScheme.primary,
      ),
    );
  }
}

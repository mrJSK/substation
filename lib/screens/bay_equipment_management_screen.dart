// lib/screens/bay_equipment_management_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/equipment_instance_model.dart'; // For EquipmentInstance
import '../utils/snackbar_utils.dart';
import 'equipment_assignment_screen.dart'; // For adding new equipment

class BayEquipmentManagementScreen extends StatelessWidget {
  final String bayId;
  final String bayName;
  final String substationId; // Added for EquipmentAssignmentScreen context

  const BayEquipmentManagementScreen({
    super.key,
    required this.bayId,
    required this.bayName,
    required this.substationId,
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
                          if (equipment.customFieldValues.isEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 4.0),
                              child: Text(
                                'No custom values defined.',
                                style: TextStyle(
                                  fontStyle: FontStyle.italic,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            )
                          else
                            ...equipment.customFieldValues.entries.map((entry) {
                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 2.0,
                                ),
                                child: Text(
                                  '${entry.key}: ${entry.value}',
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                              );
                            }).toList(),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit),
                                color: Theme.of(context).colorScheme.tertiary,
                                onPressed: () {
                                  // TODO: Navigate to EquipmentAssignmentScreen in EDIT mode
                                  SnackBarUtils.showSnackBar(
                                    context,
                                    'Edit functionality coming soon!',
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
          // Navigate to EquipmentAssignmentScreen to add new equipment to this bay
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

// lib/screens/bay_selection_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/bay_model.dart';
import '../utils/snackbar_utils.dart';
import 'equipment_assignment_screen.dart'; // Import the equipment assignment screen

class BaySelectionScreen extends StatelessWidget {
  final String substationId;
  final String substationName;

  const BaySelectionScreen({
    super.key,
    required this.substationId,
    required this.substationName,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Select Bay for ${substationName}')),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('bays')
            .where('substationId', isEqualTo: substationId)
            .orderBy('name')
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
                  'No bays found for ${substationName}.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontStyle: FontStyle.italic,
                    color: Colors.grey.shade600,
                  ),
                ),
              ),
            );
          }

          final bays = snapshot.data!.docs
              .map((doc) => Bay.fromFirestore(doc))
              .toList();

          return ListView.builder(
            padding: const EdgeInsets.all(16.0),
            itemCount: bays.length,
            itemBuilder: (context, index) {
              final bay = bays[index];
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 8.0),
                elevation: 2,
                child: ListTile(
                  title: Text(bay.name),
                  subtitle: Text(
                    'Type: ${bay.bayType}, Voltage: ${bay.voltageLevel}',
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => EquipmentAssignmentScreen(
                          bayId: bay.id,
                          bayName: bay.name,
                          substationId: bay.substationId,
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}

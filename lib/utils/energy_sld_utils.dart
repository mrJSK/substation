// lib/utils/energy_sld_utils.dart
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/rendering.dart';
import 'package:intl/intl.dart';

import '../enums/movement_mode.dart';
import '../models/user_model.dart';
import '../models/bay_model.dart';
import '../models/saved_sld_model.dart';
import '../models/assessment_model.dart';
import '../controllers/sld_controller.dart';
import '../utils/snackbar_utils.dart';

class EnergySldUtils {
  static void showBayActions(
    BuildContext context,
    dynamic bay,
    Offset tapPosition,
    SldController sldController,
    bool isViewingSavedSld,
    dynamic energyDataService, // Can be null for now
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      backgroundColor: Colors.white,
      builder: (BuildContext context) {
        return Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Enhanced Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Theme.of(context).colorScheme.primary,
                          Theme.of(
                            context,
                          ).colorScheme.primary.withOpacity(0.8),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      _getBayIcon(bay.bayType),
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          bay.name,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${bay.bayType} • ${bay.voltageLevel}',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isViewingSavedSld)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.orange.withOpacity(0.3),
                        ),
                      ),
                      child: const Text(
                        'READ-ONLY',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange,
                        ),
                      ),
                    ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Action Grid
              if (!isViewingSavedSld) ...[
                GridView.count(
                  shrinkWrap: true,
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 1.2,
                  children: [
                    // Move Bay
                    _buildActionCard(
                      context,
                      icon: Icons.open_with,
                      title: 'Move Bay',
                      subtitle: 'Position',
                      color: Colors.blue,
                      onTap: () {
                        Navigator.of(context).pop();
                        sldController.setSelectedBayForMovement(
                          bay.id,
                          mode: MovementMode.bay,
                        );
                        SnackBarUtils.showSnackBar(
                          context,
                          'Selected ${bay.name} for movement',
                        );
                      },
                    ),

                    // Edit Text
                    _buildActionCard(
                      context,
                      icon: Icons.text_fields,
                      title: 'Edit Text',
                      subtitle: 'Label',
                      color: Colors.green,
                      onTap: () {
                        Navigator.of(context).pop();
                        sldController.setSelectedBayForMovement(
                          bay.id,
                          mode: MovementMode.text,
                        );
                        SnackBarUtils.showSnackBar(
                          context,
                          'Selected ${bay.name} text for editing',
                        );
                      },
                    ),

                    // Energy Readings
                    _buildActionCard(
                      context,
                      icon: Icons.format_list_numbered,
                      title: 'Energy',
                      subtitle: 'Readings',
                      color: Colors.orange,
                      onTap: () {
                        Navigator.of(context).pop();
                        sldController.setSelectedBayForMovement(
                          bay.id,
                          mode: MovementMode.energyText,
                        );
                        SnackBarUtils.showSnackBar(
                          context,
                          'Selected ${bay.name} energy text',
                        );
                      },
                    ),

                    // Bay Details
                    _buildActionCard(
                      context,
                      icon: Icons.info,
                      title: 'Details',
                      subtitle: 'View info',
                      color: Colors.purple,
                      onTap: () {
                        Navigator.of(context).pop();
                        _showBayDetailsDialog(context, bay);
                      },
                    ),
                  ],
                ),

                // Busbar specific actions
                if (bay.bayType == 'Busbar') ...[
                  const SizedBox(height: 20),
                  const Divider(),
                  const SizedBox(height: 16),
                  Text(
                    'Busbar Actions',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.of(context).pop();
                        sldController.setSelectedBayForMovement(bay.id);
                        SnackBarUtils.showSnackBar(
                          context,
                          'Selected ${bay.name} for length adjustment',
                        );
                      },
                      icon: const Icon(Icons.straighten),
                      label: const Text('Adjust Length'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ] else ...[
                // Read-only message
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.lock_outline,
                        color: Colors.grey.shade600,
                        size: 24,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Read-Only Mode',
                              style: TextStyle(
                                color: Colors.grey.shade800,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'This is a saved SLD view. Editing is not available.',
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  static Widget _buildActionCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.3), width: 1),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: color,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(fontSize: 12, color: color.withOpacity(0.8)),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  static IconData _getBayIcon(String bayType) {
    switch (bayType.toLowerCase()) {
      case 'transformer':
        return Icons.electrical_services;
      case 'line':
        return Icons.linear_scale;
      case 'feeder':
        return Icons.cable;
      case 'busbar':
        return Icons.horizontal_rule;
      default:
        return Icons.square;
    }
  }

  static void _showBayDetailsDialog(BuildContext context, dynamic bay) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(
                _getBayIcon(bay.bayType),
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 12),
              Text(bay.name),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailRow('Bay ID', bay.id),
              _buildDetailRow('Type', bay.bayType),
              _buildDetailRow('Voltage Level', bay.voltageLevel),
              if (bay.make != null && bay.make!.isNotEmpty)
                _buildDetailRow('Make', bay.make!),
              _buildDetailRow('Created By', bay.createdBy),
              _buildDetailRow(
                'Created At',
                bay.createdAt.toDate().toLocal().toString().split('.')[0],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  static Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  // Save SLD Functionality
  static void saveSld(
    BuildContext context,
    String substationId,
    String substationName,
    AppUser currentUser,
    DateTime startDate,
    DateTime endDate,
    SldController sldController,
    List<dynamic> assessments, // Empty for now
  ) {
    SnackBarUtils.showSnackBar(context, 'Save SLD feature coming soon');

    // TODO: Implement actual save functionality when models are ready
    // This is a placeholder that matches your current architecture
  }

  // Legacy PDF sharing method - updated to work with current architecture
  static Future<void> shareAsPdf(
    BuildContext context,
    String substationName,
    DateTime startDate,
    DateTime endDate,
    SldController sldController, {
    required Uint8List sldImageBytes,
  }) async {
    try {
      SnackBarUtils.showSnackBar(context, 'PDF generation coming soon');

      // TODO: Implement PDF generation when PdfGenerator is available
      // This is a placeholder that matches your current architecture
    } catch (e) {
      SnackBarUtils.showSnackBar(
        context,
        'PDF generation failed: $e',
        isError: true,
      );
    }
  }
}

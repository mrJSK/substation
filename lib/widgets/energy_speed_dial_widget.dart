// lib/widgets/energy_speed_dial_widget.dart

import 'package:flutter/material.dart';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';

class EnergySpeedDialWidget extends StatelessWidget {
  final bool isViewingSavedSld;
  final bool showTables;
  final VoidCallback onToggleTables;
  final VoidCallback onSaveSld;
  final VoidCallback onSharePdf;
  final VoidCallback onConfigureBusbar;
  final VoidCallback onAddAssessment;

  const EnergySpeedDialWidget({
    super.key,
    required this.isViewingSavedSld,
    required this.showTables,
    required this.onToggleTables,
    required this.onSaveSld,
    required this.onSharePdf,
    required this.onConfigureBusbar,
    required this.onAddAssessment,
  });

  @override
  Widget build(BuildContext context) {
    return SpeedDial(
      icon: Icons.menu,
      activeIcon: Icons.close,
      backgroundColor: Theme.of(context).colorScheme.primary,
      foregroundColor: Colors.white,
      overlayColor: Colors.black,
      overlayOpacity: 0.5,
      spacing: 12,
      spaceBetweenChildren: 12,
      children: [
        SpeedDialChild(
          child: const Icon(Icons.save),
          backgroundColor: isViewingSavedSld ? Colors.grey : Colors.green,
          label: 'Save SLD',
          onTap: isViewingSavedSld ? null : onSaveSld,
        ),
        SpeedDialChild(
          child: const Icon(Icons.share),
          backgroundColor: Colors.blue,
          label: 'Share as PDF',
          onTap: onSharePdf,
        ),
        SpeedDialChild(
          child: Icon(showTables ? Icons.visibility_off : Icons.visibility),
          backgroundColor: Colors.orange,
          label: showTables ? 'Hide Tables' : 'Show Tables',
          onTap: onToggleTables,
        ),
        SpeedDialChild(
          child: const Icon(Icons.settings_input_antenna),
          backgroundColor: Colors.purple,
          label: 'Configure Busbar Energy',
          onTap: isViewingSavedSld ? null : onConfigureBusbar,
        ),
        SpeedDialChild(
          child: const Icon(Icons.assessment),
          backgroundColor: Colors.red,
          label: 'Add Energy Assessment',
          onTap: isViewingSavedSld ? null : onAddAssessment,
        ),
      ],
    );
  }
}

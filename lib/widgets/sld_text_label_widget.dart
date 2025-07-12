// lib/widgets/sld_text_label_widget.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:math'; // For min/max if needed

import '../models/sld_models.dart'; // Import your SLD models
import '../state_management/sld_editor_state.dart'; // Import your SLD editor state
import '../utils/snackbar_utils.dart'; // For showing snackbars

class SldTextLabelWidget extends StatelessWidget {
  final SldTextLabel textLabel;

  const SldTextLabelWidget({Key? key, required this.textLabel})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Listen to changes in SldEditorState for selection and interaction mode
    final sldState = Provider.of<SldEditorState>(context);
    final isSelected =
        sldState.sldData?.selectedElementIds.contains(textLabel.id) ?? false;
    final currentZoom = sldState.sldData?.currentZoom ?? 1.0;

    // Determine text color based on theme for readability
    final Color textColor =
        textLabel.textStyle.color ?? Theme.of(context).colorScheme.onSurface;

    return GestureDetector(
      // Drag gesture for moving the text label
      onPanUpdate: (details) {
        // Allow dragging in select mode or pan mode (if a text label is selected)
        if (sldState.interactionMode == SldInteractionMode.select ||
            sldState.interactionMode == SldInteractionMode.pan ||
            sldState.interactionMode == SldInteractionMode.addText) {
          // addText mode is also used for moving labels
          sldState.updateElementProperties(textLabel.id, {
            'positionX': textLabel.position.dx + details.delta.dx / currentZoom,
            'positionY': textLabel.position.dy + details.delta.dy / currentZoom,
          });
        }
      },
      // Tap gesture for selection
      onTap: () {
        sldState.selectElement(textLabel.id);
      },
      // Long press for context menu (edit text, delete)
      onLongPress: () {
        _showTextLabelContextMenu(context, sldState, textLabel);
      },
      child: Container(
        // Set fixed size for the text label container based on its model,
        // and add padding/decoration for visual feedback.
        width: textLabel.size.width,
        height: textLabel.size.height,
        decoration: BoxDecoration(
          border: isSelected
              ? Border.all(
                  color: Theme.of(context).colorScheme.tertiary,
                  width: 2,
                )
              : null,
          // Optional: slight background to make text readable on busy SLD
          // color: Colors.black.withOpacity(0.05),
        ),
        padding: const EdgeInsets.all(4.0),
        child: FittedBox(
          // Use FittedBox to scale text if it overflows
          fit: BoxFit.contain, // Scale to fit within bounds
          alignment: Alignment.center,
          child: Text(
            textLabel.text,
            textAlign: textLabel.textAlign,
            style: textLabel.textStyle.copyWith(
              color: isSelected
                  ? Theme.of(context).colorScheme.tertiary
                  : textColor,
              // You might want to remove shadows/outlines for clarity in dark mode
              // or ensure they are theme-aware.
            ),
          ),
        ),
      ),
    );
  }

  // --- Context Menu for Text Label Operations ---
  void _showTextLabelContextMenu(
    BuildContext context,
    SldEditorState sldState,
    SldTextLabel textLabel,
  ) {
    showMenu(
      context: context,
      position: RelativeRect.fromLTRB(
        textLabel.position.dx,
        textLabel.position.dy,
        textLabel.position.dx + textLabel.size.width,
        textLabel.position.dy + textLabel.size.height,
      ),
      items: [
        const PopupMenuItem<String>(
          value: 'edit_text',
          child: ListTile(leading: Icon(Icons.edit), title: Text('Edit Text')),
        ),
        const PopupMenuItem<String>(
          value: 'delete',
          child: ListTile(
            leading: Icon(Icons.delete),
            title: Text('Delete Label'),
          ),
        ),
      ],
      elevation: 8.0,
    ).then((value) {
      if (value != null) {
        switch (value) {
          case 'edit_text':
            _showEditTextLabelDialog(context, sldState, textLabel);
            break;
          case 'delete':
            sldState.removeElement(textLabel.id);
            SnackBarUtils.showSnackBar(context, 'Text label deleted.');
            break;
        }
      }
    });
  }

  // --- Dialog for editing text label content ---
  void _showEditTextLabelDialog(
    BuildContext context,
    SldEditorState sldState,
    SldTextLabel textLabel,
  ) {
    final TextEditingController textController = TextEditingController(
      text: textLabel.text,
    );
    final TextEditingController fontSizeController = TextEditingController(
      text: textLabel.textStyle.fontSize?.toString() ?? '14',
    );

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Edit Text Label Properties'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: textController,
                decoration: const InputDecoration(labelText: 'Label Text'),
                maxLines: 3,
                minLines: 1,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: fontSizeController,
                decoration: const InputDecoration(labelText: 'Font Size'),
                keyboardType: TextInputType.number,
              ),
              // You can add more TextStyle properties here (e.g., fontWeight, color, textAlign)
              // This would require more complex UI for selection (e.g., dropdowns for FontWeight.values)
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final double? newFontSize = double.tryParse(
                  fontSizeController.text,
                );
                if (textController.text.trim().isEmpty) {
                  SnackBarUtils.showSnackBar(
                    dialogContext,
                    'Text cannot be empty.',
                    isError: true,
                  );
                  return;
                }
                if (newFontSize == null || newFontSize <= 0) {
                  SnackBarUtils.showSnackBar(
                    dialogContext,
                    'Please enter a valid font size.',
                    isError: true,
                  );
                  return;
                }

                // Create a new TextStyle with updated properties
                final TextStyle updatedTextStyle = textLabel.textStyle.copyWith(
                  fontSize: newFontSize,
                  // Add other properties here
                );

                // Update properties in SldEditorState
                sldState.updateElementProperties(textLabel.id, {
                  'text': textController.text.trim(),
                  'textStyle':
                      updatedTextStyle, // Pass the new TextStyle object
                  // Note: Size might also need recalculation if text changes significantly
                  // For simplicity, we are not recalculating size dynamically based on text content here.
                });
                Navigator.of(dialogContext).pop();
                SnackBarUtils.showSnackBar(context, 'Text label updated.');
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }
}

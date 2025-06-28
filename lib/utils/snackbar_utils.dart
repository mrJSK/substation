// lib/utils/snackbar_utils.dart
// Utility class for easily displaying consistent Snackbars across the application.

import 'package:flutter/material.dart'; // Required for BuildContext, SnackBar, SnackBarAction

class SnackBarUtils {
  // Displays a custom SnackBar with a message, optional error styling, and an action.
  static void showSnackBar(
    BuildContext context,
    String message, {
    bool isError = false,
    SnackBarAction? action,
  }) {
    // Hide any currently visible Snackbars to prevent multiple overlapping.
    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    // Show a new SnackBar.
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message), // The main text content of the SnackBar.
        backgroundColor: isError
            ? Colors
                  .red
                  .shade700 // Red background for error messages.
            : Colors
                  .green
                  .shade700, // Green background for success/info messages.
        behavior: SnackBarBehavior
            .floating, // Makes the SnackBar float above content.
        duration: const Duration(
          seconds: 3,
        ), // Duration for which the SnackBar is visible.
        action: action, // Optional action button on the SnackBar.
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ), // Rounded corners for styling.
        margin: const EdgeInsets.all(16), // Margin around the SnackBar.
      ),
    );
  }
}

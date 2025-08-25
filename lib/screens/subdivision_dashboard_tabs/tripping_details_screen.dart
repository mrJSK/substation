// lib/screens/tripping_details_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/tripping_shutdown_model.dart';

class TrippingDetailsScreen extends StatelessWidget {
  final TrippingShutdownEntry entry;
  final String substationName;

  const TrippingDetailsScreen({
    Key? key,
    required this.entry,
    required this.substationName,
  }) : super(key: key);

  // ✨ NEW: Helper methods for dynamic event labels
  String _getEventTitle(String eventType) {
    switch (eventType) {
      case 'Breakdown':
        return 'Breakdown Event';
      case 'Tripping':
        return 'Tripping Event';
      case 'Shutdown':
        return 'Shutdown Event';
      default:
        return 'System Event';
    }
  }

  String _getEventStartLabel(String eventType) {
    switch (eventType) {
      case 'Breakdown':
        return 'Breakdown Start Time';
      case 'Tripping':
        return 'Trip Start Time';
      case 'Shutdown':
        return 'Shutdown Time';
      default:
        return 'Event Start Time';
    }
  }

  String _getEventEndLabel(String eventType) {
    switch (eventType) {
      case 'Breakdown':
        return 'Breakdown End Time';
      case 'Tripping':
        return 'Trip End Time';
      case 'Shutdown':
        return 'Charging Time';
      default:
        return 'Event End Time';
    }
  }

  String _getDetailsTitle(String eventType) {
    switch (eventType) {
      case 'Breakdown':
        return 'Breakdown Details';
      case 'Tripping':
        return 'Tripping Details';
      case 'Shutdown':
        return 'Shutdown Details';
      default:
        return 'Event Details';
    }
  }

  String _getTimingTitle(String eventType) {
    switch (eventType) {
      case 'Breakdown':
        return 'Breakdown Timing';
      case 'Tripping':
        return 'Trip Timing';
      case 'Shutdown':
        return 'Shutdown Timing';
      default:
        return 'Event Timing';
    }
  }

  // ✨ NEW: Get event type icon
  IconData _getEventTypeIcon(String eventType) {
    switch (eventType) {
      case 'Tripping':
        return Icons.flash_on;
      case 'Shutdown':
        return Icons.power_off;
      case 'Breakdown':
        return Icons.build_circle_outlined;
      default:
        return Icons.warning;
    }
  }

  // ✨ NEW: Get event type color
  Color _getEventTypeColor(String eventType) {
    switch (eventType) {
      case 'Tripping':
        return Colors.red;
      case 'Shutdown':
        return Colors.orange;
      case 'Breakdown':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDarkMode
          ? const Color(0xFF1C1C1E)
          : const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('Event Details'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildEventHeader(isDarkMode),
            const SizedBox(height: 40),
            _buildDetailsSection(isDarkMode),
            const SizedBox(height: 40),
            _buildTimingSection(isDarkMode),
            // ✨ UPDATED: Show reason section for tripping AND breakdown events
            if (entry.eventType == 'Tripping' ||
                entry.eventType == 'Breakdown') ...[
              const SizedBox(height: 40),
              _buildReasonSection(isDarkMode),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEventHeader(bool isDarkMode) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            // ✨ UPDATED: Dynamic icon and color based on event type
            Icon(
              _getEventTypeIcon(entry.eventType),
              color: _getEventTypeColor(entry.eventType),
              size: 32,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _getEventTitle(entry.eventType),
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: isDarkMode ? Colors.white : Colors.black,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: entry.status == 'OPEN'
                    ? _getEventTypeColor(entry.eventType).withOpacity(0.8)
                    : Colors.green,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                entry.status,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          entry.bayName,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w500,
            color: isDarkMode
                ? Colors.white.withOpacity(0.8)
                : Colors.grey[700],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          substationName,
          style: TextStyle(
            fontSize: 16,
            color: isDarkMode ? Colors.white.withOpacity(0.6) : Colors.grey,
          ),
        ),
      ],
    );
  }

  Widget _buildDetailsSection(bool isDarkMode) {
    // Separate FLAGS from the combined flags/cause for display
    String displayFlags = entry.flagsCause;
    if ((entry.eventType == 'Tripping' || entry.eventType == 'Breakdown') &&
        entry.flagsCause.contains('Reason for Tripping:')) {
      // Extract only the FLAGS part (before the reason)
      final parts = entry.flagsCause.split('\nReason for Tripping:');
      if (parts.isNotEmpty) {
        displayFlags = parts.first.trim();
      }
    }

    final details = <Map<String, String>>[];

    // ✨ UPDATED: Add FLAGS for tripping AND breakdown events, only if not empty
    if ((entry.eventType == 'Tripping' || entry.eventType == 'Breakdown') &&
        displayFlags.isNotEmpty) {
      details.add({'label': 'FLAGS', 'value': displayFlags});
    }

    // Add other technical details
    if (entry.hasAutoReclose != null) {
      details.add({
        'label': 'Auto Reclose',
        'value': entry.hasAutoReclose! ? 'Yes' : 'No',
      });
    }

    if (entry.phaseFaults?.isNotEmpty ?? false) {
      details.add({
        'label': 'Phase Faults',
        'value': entry.phaseFaults!.join(', '),
      });
    }

    if (entry.distance?.isNotEmpty ?? false) {
      details.add({
        'label': 'Fault Distance',
        'value': '${entry.distance!} Km',
      });
    }

    // Shutdown-specific details
    if (entry.shutdownType?.isNotEmpty ?? false) {
      details.add({'label': 'Shutdown Type', 'value': entry.shutdownType!});
    }

    if (entry.shutdownPersonName?.isNotEmpty ?? false) {
      details.add({
        'label': 'Shutdown Person',
        'value': entry.shutdownPersonName!,
      });
    }

    if (entry.shutdownPersonDesignation?.isNotEmpty ?? false) {
      details.add({
        'label': 'Person Designation',
        'value': entry.shutdownPersonDesignation!,
      });
    }

    // Only show this section if there are details to display
    if (details.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _getDetailsTitle(entry.eventType),
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: isDarkMode ? Colors.white : Colors.black,
          ),
        ),
        const SizedBox(height: 20),
        ...details.asMap().entries.map((detailEntry) {
          final isLast = detailEntry.key == details.length - 1;
          return _buildDetailRow(
            detailEntry.value['label']!,
            detailEntry.value['value']!,
            isDarkMode,
            showDivider: !isLast,
          );
        }),
      ],
    );
  }

  // ✨ UPDATED: Reason section for tripping AND breakdown events
  Widget _buildReasonSection(bool isDarkMode) {
    String? reasonText;
    String? reasonLabel;

    // Parse reason based on bay type and storage location
    if (entry.flagsCause.contains('Reason for Tripping:')) {
      // Line bay tripping - reason is stored in flagsCause
      final parts = entry.flagsCause.split('Reason for Tripping:');
      if (parts.length > 1) {
        reasonText = parts.last.trim();
        reasonLabel = entry.eventType == 'Tripping'
            ? 'Line Fault Reason'
            : 'Breakdown Fault Reason';
      }
    } else if (entry.reasonForNonFeeder?.isNotEmpty ?? false) {
      // Non-Line bay or breakdown events - reason is stored in reasonForNonFeeder
      reasonText = entry.reasonForNonFeeder!;
      reasonLabel = entry.eventType == 'Tripping'
          ? 'Reason for Tripping'
          : 'Reason for Breakdown';
    }

    // If no reason found, don't show this section
    if (reasonText == null || reasonText.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Reason Details',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: isDarkMode ? Colors.white : Colors.black,
          ),
        ),
        const SizedBox(height: 20),
        _buildDetailRow(
          reasonLabel!,
          reasonText,
          isDarkMode,
          showDivider: false,
        ),
      ],
    );
  }

  Widget _buildTimingSection(bool isDarkMode) {
    final timingDetails = <Map<String, String>>[
      // ✨ UPDATED: Dynamic timing labels based on event type
      {
        'label': _getEventStartLabel(entry.eventType),
        'value': DateFormat(
          'dd MMM yyyy, HH:mm:ss',
        ).format(entry.startTime.toDate()),
      },
      if (entry.endTime != null)
        {
          'label': _getEventEndLabel(entry.eventType),
          'value': DateFormat(
            'dd MMM yyyy, HH:mm:ss',
          ).format(entry.endTime!.toDate()),
        },
      if (entry.endTime != null)
        {
          'label': 'Total Duration',
          'value': _calculateDuration(
            entry.startTime.toDate(),
            entry.endTime!.toDate(),
          ),
        },
      {'label': 'Created By', 'value': entry.createdBy},
      {
        'label': 'Created At',
        'value': DateFormat(
          'dd MMM yyyy, HH:mm:ss',
        ).format(entry.createdAt.toDate()),
      },
      if (entry.closedBy != null)
        {'label': 'Closed By', 'value': entry.closedBy!},
      if (entry.closedAt != null)
        {
          'label': 'Closed At',
          'value': DateFormat(
            'dd MMM yyyy, HH:mm:ss',
          ).format(entry.closedAt!.toDate()),
        },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _getTimingTitle(entry.eventType),
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: isDarkMode ? Colors.white : Colors.black,
          ),
        ),
        const SizedBox(height: 20),
        ...timingDetails.asMap().entries.map((timingEntry) {
          final isLast = timingEntry.key == timingDetails.length - 1;
          return _buildDetailRow(
            timingEntry.value['label']!,
            timingEntry.value['value']!,
            isDarkMode,
            showDivider: !isLast,
          );
        }),
      ],
    );
  }

  Widget _buildDetailRow(
    String label,
    String value,
    bool isDarkMode, {
    bool showDivider = true,
  }) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 120,
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: isDarkMode
                        ? Colors.white.withOpacity(0.7)
                        : Colors.grey[600],
                  ),
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Text(
                  value,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                    color: isDarkMode ? Colors.white : Colors.black,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (showDivider)
          Divider(
            color: isDarkMode
                ? Colors.white.withOpacity(0.1)
                : Colors.grey.withOpacity(0.3),
            height: 1,
          ),
      ],
    );
  }

  String _calculateDuration(DateTime start, DateTime end) {
    final difference = end.difference(start);
    final days = difference.inDays;
    final hours = difference.inHours % 24;
    final minutes = difference.inMinutes % 60;

    if (days > 0) {
      return '${days}d ${hours}h ${minutes}m';
    } else if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else {
      return '${minutes}m';
    }
  }
}

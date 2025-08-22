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
            // 🔧 FIX: Show reason section for tripping events only
            if (entry.eventType == 'Tripping') ...[
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
            Icon(
              entry.eventType == 'Tripping' ? Icons.flash_on : Icons.power_off,
              color: entry.eventType == 'Tripping' ? Colors.red : Colors.orange,
              size: 32,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '${entry.eventType} Event',
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
                color: entry.status == 'OPEN' ? Colors.orange : Colors.green,
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
    // 🔧 FIX: Separate FLAGS from the combined flags/cause for display
    String displayFlags = entry.flagsCause;
    if (entry.eventType == 'Tripping' &&
        entry.flagsCause.contains('Reason for Tripping:')) {
      // Extract only the FLAGS part (before the reason)
      final parts = entry.flagsCause.split('\nReason for Tripping:');
      if (parts.isNotEmpty) {
        displayFlags = parts.first.trim();
      }
    }

    final details = <Map<String, String>>[];

    // 🔧 FIX: Add FLAGS only for tripping events, and only if not empty
    if (entry.eventType == 'Tripping' && displayFlags.isNotEmpty) {
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
          // 🔧 FIX: Updated section title based on event type
          entry.eventType == 'Tripping'
              ? 'Tripping Details'
              : 'Shutdown Details',
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

  // 🔧 FIX: New reason section for tripping events
  Widget _buildReasonSection(bool isDarkMode) {
    String? reasonText;
    String? reasonLabel;

    // Parse reason based on bay type and storage location
    if (entry.flagsCause.contains('Reason for Tripping:')) {
      // Line bay - reason is stored in flagsCause
      final parts = entry.flagsCause.split('Reason for Tripping:');
      if (parts.length > 1) {
        reasonText = parts.last.trim();
        reasonLabel = 'Line Fault Reason';
      }
    } else if (entry.reasonForNonFeeder?.isNotEmpty ?? false) {
      // Non-Line bay - reason is stored in reasonForNonFeeder
      reasonText = entry.reasonForNonFeeder!;
      reasonLabel = 'Reason for Tripping';
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
      {
        // 🔧 FIX: Updated timing labels based on event type
        'label': entry.eventType == 'Tripping'
            ? 'Trip Start Time'
            : 'Shutdown Time',
        'value': DateFormat(
          'dd MMM yyyy, HH:mm:ss',
        ).format(entry.startTime.toDate()),
      },
      if (entry.endTime != null)
        {
          'label': 'Charging Time',
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
          // 🔧 FIX: Updated section title based on event type
          entry.eventType == 'Tripping' ? 'Trip Timing' : 'Shutdown Timing',
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

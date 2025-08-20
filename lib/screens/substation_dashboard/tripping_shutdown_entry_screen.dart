import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:intl/intl.dart';
import 'package:dropdown_search/dropdown_search.dart';
import '../../../models/user_model.dart';
import '../../../models/bay_model.dart';
import '../../../models/tripping_shutdown_model.dart';
import '../../../utils/snackbar_utils.dart';
import 'package:collection/collection.dart';

class TrippingShutdownEntryScreen extends StatefulWidget {
  final String substationId;
  final String substationName;
  final AppUser currentUser;
  final TrippingShutdownEntry? entryToEdit;
  final bool isViewOnly;

  const TrippingShutdownEntryScreen({
    super.key,
    required this.substationId,
    required this.substationName,
    required this.currentUser,
    this.entryToEdit,
    this.isViewOnly = false,
  });

  @override
  State<TrippingShutdownEntryScreen> createState() =>
      _TrippingShutdownEntryScreenState();
}

class _TrippingShutdownEntryScreenState
    extends State<TrippingShutdownEntryScreen>
    with SingleTickerProviderStateMixin {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isClosingEvent = false;
  late AnimationController _animationController;

  List<Bay> _allBays = [];
  Bay? _selectedBay;
  List<Bay> _selectedMultiBays = [];
  Map<String, TextEditingController> _bayFlagsControllers = {};

  String? _selectedEventType;
  final List<String> _eventTypes = ['Tripping', 'Shutdown'];

  DateTime? _startDate;
  TimeOfDay? _startTime;
  DateTime? _endDate;
  TimeOfDay? _endTime;

  final TextEditingController _flagsCauseController = TextEditingController();
  final TextEditingController _reasonForNonFeederController =
      TextEditingController();
  final TextEditingController _distanceController = TextEditingController();

  bool _showReasonForNonFeeder = false;
  bool _showHasAutoReclose = false;
  bool _showPhaseFaults = false;
  bool _showDistance = false;

  bool _hasAutoReclose = false;
  List<String> _selectedPhaseFaults = [];
  final List<String> _phaseFaultOptions = ['Rph', 'Yph', 'Bph'];

  String? _selectedShutdownType;
  final List<String> _shutdownTypes = ['Transmission', 'Distribution'];
  final TextEditingController _shutdownPersonNameController =
      TextEditingController();
  final TextEditingController _shutdownPersonDesignationController =
      TextEditingController();

  int _parseVoltageLevel(String? voltageLevel) {
    if (voltageLevel == null || voltageLevel.isEmpty) return 0;
    final regex = RegExp(r'(\d+)kV');
    final match = regex.firstMatch(voltageLevel);
    if (match != null && match.groupCount > 0) {
      return int.tryParse(match.group(1)!) ?? 0;
    }
    return 0;
  }

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _ensureFCMTokenStored();
    _initializeForm();
  }

  @override
  void dispose() {
    _flagsCauseController.dispose();
    _reasonForNonFeederController.dispose();
    _distanceController.dispose();
    _shutdownPersonNameController.dispose();
    _shutdownPersonDesignationController.dispose();
    _bayFlagsControllers.forEach((key, controller) => controller.dispose());
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _ensureFCMTokenStored() async {
    try {
      final messaging = FirebaseMessaging.instance;

      NotificationSettings settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        String? token = await messaging.getToken();
        if (token != null) {
          await _saveFCMToken(token);
        }

        FirebaseMessaging.instance.onTokenRefresh.listen(_saveFCMToken);
      }
    } catch (e) {
      print('Error initializing FCM: $e');
    }
  }

  Future<void> _saveFCMToken(String token) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      await FirebaseFirestore.instance
          .collection('fcmTokens')
          .doc(user.uid)
          .set({
            'userId': user.uid,
            'token': token,
            'active': true,
            'platform': 'flutter',
            'createdAt': FieldValue.serverTimestamp(),
            'lastUsed': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

      print('✅ FCM Token stored for user: ${user.uid}');
    } catch (e) {
      print('❌ Error saving FCM token: $e');
    }
  }

  Future<void> _initializeForm() async {
    setState(() => _isLoading = true);
    try {
      final baysSnapshot = await FirebaseFirestore.instance
          .collection('bays')
          .where('substationId', isEqualTo: widget.substationId)
          .orderBy('name')
          .get();

      _allBays = baysSnapshot.docs
          .map((doc) => Bay.fromFirestore(doc))
          .toList();

      if (_allBays.isEmpty) {
        if (mounted) {
          SnackBarUtils.showSnackBar(
            context,
            'No bays found for this substation.',
            isError: true,
          );
          Navigator.of(context).pop();
        }
        return;
      }

      if (widget.entryToEdit != null) {
        final entry = widget.entryToEdit!;
        _selectedBay = _allBays.firstWhereOrNull(
          (bay) => bay.id == entry.bayId,
        );
        _selectedMultiBays = _selectedBay != null ? [_selectedBay!] : [];
        _selectedEventType = entry.eventType;
        _startDate = entry.startTime.toDate();
        _startTime = TimeOfDay.fromDateTime(_startDate!);
        _flagsCauseController.text = entry.flagsCause;
        _reasonForNonFeederController.text = entry.reasonForNonFeeder ?? '';
        _distanceController.text = entry.distance ?? '';
        _selectedPhaseFaults = entry.phaseFaults ?? [];
        _hasAutoReclose = entry.hasAutoReclose ?? false;
        _selectedShutdownType = entry.shutdownType;
        _shutdownPersonNameController.text = entry.shutdownPersonName ?? '';
        _shutdownPersonDesignationController.text =
            entry.shutdownPersonDesignation ?? '';

        if (entry.status == 'CLOSED') {
          _endDate = entry.endTime!.toDate();
          _endTime = TimeOfDay.fromDateTime(_endDate!);
        } else {
          _isClosingEvent = true;
          _endDate = DateTime.now();
          _endTime = TimeOfDay.fromDateTime(_endDate!);
        }
      } else {
        _startDate = DateTime.now();
        _startTime = TimeOfDay.fromDateTime(_startDate!);
        _selectedEventType = _eventTypes.first;
        _hasAutoReclose = false;
      }

      _animationController.forward();
    } catch (e) {
      print("Error initializing form: $e");
      if (mounted) {
        SnackBarUtils.showSnackBar(
          context,
          'Failed to load data: $e',
          isError: true,
        );
        Navigator.of(context).pop();
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _updateConditionalFields();
        });
      }
    }
  }

  void _updateConditionalFields() {
    setState(() {
      if (_selectedBay == null && _selectedMultiBays.isEmpty) {
        _showReasonForNonFeeder = false;
        _showHasAutoReclose = false;
        _showPhaseFaults = false;
        _showDistance = false;
      } else {
        _showReasonForNonFeeder =
            _selectedBay != null && _selectedBay!.bayType != 'Feeder';
        _showHasAutoReclose =
            _selectedBay != null &&
            _selectedBay!.bayType == 'Line' &&
            _parseVoltageLevel(_selectedBay!.voltageLevel) >= 220;
        _showPhaseFaults = _selectedEventType == 'Tripping';
        _showDistance =
            _selectedEventType == 'Tripping' &&
            _selectedBay != null &&
            _selectedBay!.bayType == 'Line';
      }

      if (!_showReasonForNonFeeder) _reasonForNonFeederController.clear();
      if (!_showPhaseFaults) _selectedPhaseFaults.clear();
      if (!_showDistance) _distanceController.clear();

      bool isShutdown = _selectedEventType == 'Shutdown';
      if (!isShutdown) {
        _selectedShutdownType = null;
        _shutdownPersonNameController.clear();
        _shutdownPersonDesignationController.clear();
      }
    });
  }

  void _updateClosingEventStatus() {
    setState(() {
      _isClosingEvent =
          widget.entryToEdit != null &&
          widget.entryToEdit!.status == 'OPEN' &&
          _endDate != null &&
          _endTime != null;
    });
  }

  Future<void> _selectDateTime(BuildContext context, bool isStart) async {
    DateTime initialDate = isStart
        ? (_startDate ?? DateTime.now())
        : (_endDate ?? DateTime.now());
    TimeOfDay initialTime = isStart
        ? (_startTime ?? TimeOfDay.now())
        : (_endTime ?? TimeOfDay.now());

    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      builder: (context, child) => Theme(
        data: theme.copyWith(
          colorScheme: theme.colorScheme.copyWith(
            primary: theme.colorScheme.primary,
            onPrimary: theme.colorScheme.onPrimary,
            surface: isDarkMode ? const Color(0xFF2C2C2E) : Colors.white,
            onSurface: isDarkMode ? Colors.white : Colors.black87,
          ),
          dialogBackgroundColor: isDarkMode
              ? const Color(0xFF2C2C2E)
              : Colors.white,
        ),
        child: child!,
      ),
    );

    if (pickedDate != null) {
      final TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: initialTime,
        builder: (context, child) => Theme(
          data: theme.copyWith(
            colorScheme: theme.colorScheme.copyWith(
              primary: theme.colorScheme.primary,
              onPrimary: theme.colorScheme.onPrimary,
              surface: isDarkMode ? const Color(0xFF2C2C2E) : Colors.white,
              onSurface: isDarkMode ? Colors.white : Colors.black87,
            ),
            dialogBackgroundColor: isDarkMode
                ? const Color(0xFF2C2C2E)
                : Colors.white,
          ),
          child: child!,
        ),
      );

      if (pickedTime != null) {
        final DateTime selectedDateTime = DateTime(
          pickedDate.year,
          pickedDate.month,
          pickedDate.day,
          pickedTime.hour,
          pickedTime.minute,
        );

        setState(() {
          if (isStart) {
            _startDate = selectedDateTime;
            _startTime = pickedTime;
            if (_endDate != null && _endDate!.isBefore(_startDate!)) {
              _endDate = _startDate;
              _endTime = _startTime;
            }
          } else {
            _endDate = selectedDateTime;
            _endTime = pickedTime;
            if (_startDate != null && _startDate!.isAfter(_endDate!)) {
              _startDate = _endDate;
              _startTime = _endTime;
            }
          }
          _updateClosingEventStatus();
        });
      }
    }
  }

  Future<void> _saveEvent() async {
    if (!_formKey.currentState!.validate()) return;

    final now = DateTime.now();
    if (_startDate != null && _startDate!.isAfter(now)) {
      SnackBarUtils.showSnackBar(
        context,
        'Start Date cannot be in the future.',
        isError: true,
      );
      return;
    }

    if (_endDate != null && _endDate!.isAfter(now)) {
      SnackBarUtils.showSnackBar(
        context,
        'End Date cannot be in the future.',
        isError: true,
      );
      return;
    }

    if (_isClosingEvent && (_endDate == null || _endTime == null)) {
      SnackBarUtils.showSnackBar(
        context,
        'End Date and Time are required to close the event.',
        isError: true,
      );
      return;
    }

    if (_selectedEventType == 'Shutdown') {
      if (_selectedShutdownType == null) {
        SnackBarUtils.showSnackBar(
          context,
          'Shutdown Type (Transmission/Distribution) is required.',
          isError: true,
        );
        return;
      }

      if (_shutdownPersonNameController.text.trim().isEmpty) {
        SnackBarUtils.showSnackBar(
          context,
          'Name of Person Taking Shutdown is required.',
          isError: true,
        );
        return;
      }

      if (_shutdownPersonDesignationController.text.trim().isEmpty) {
        SnackBarUtils.showSnackBar(
          context,
          'Designation of Person Taking Shutdown is required.',
          isError: true,
        );
        return;
      }
    }

    bool isFlagsCauseMandatoryGlobal =
        _selectedEventType == 'Shutdown' || _isClosingEvent;

    if (widget.entryToEdit == null && isFlagsCauseMandatoryGlobal) {
      for (var bay in _selectedMultiBays) {
        final controller = _bayFlagsControllers[bay.id];
        if (controller == null || controller.text.trim().isEmpty) {
          SnackBarUtils.showSnackBar(
            context,
            'Flags/Cause for ${bay.name} is mandatory.',
            isError: true,
          );
          return;
        }
      }
    }

    if (_showPhaseFaults && _selectedPhaseFaults.isEmpty) {
      SnackBarUtils.showSnackBar(
        context,
        'Please select at least one phase fault for Tripping events.',
        isError: true,
      );
      return;
    }

    if (_showDistance && _distanceController.text.trim().isEmpty) {
      SnackBarUtils.showSnackBar(
        context,
        'Fault Distance is required for Line bay Tripping events.',
        isError: true,
      );
      return;
    }

    setState(() => _isSaving = true);

    if (widget.entryToEdit == null &&
        (_selectedEventType == 'Tripping' ||
            _selectedEventType == 'Shutdown')) {
      await _showNotificationPreview();
    }

    try {
      final String currentUserId = widget.currentUser.uid;
      final Timestamp nowTimestamp = Timestamp.now();

      String status = _endDate != null && _endTime != null ? 'CLOSED' : 'OPEN';
      Timestamp? eventEndTime = _endDate != null && _endTime != null
          ? Timestamp.fromDate(
              DateTime(
                _endDate!.year,
                _endDate!.month,
                _endDate!.day,
                _endTime!.hour,
                _endTime!.minute,
              ),
            )
          : null;

      String? closedBy = _endDate != null && _endTime != null
          ? currentUserId
          : null;
      Timestamp? closedAt = _endDate != null && _endTime != null
          ? nowTimestamp
          : null;

      if (widget.entryToEdit == null) {
        if (_selectedMultiBays.isEmpty) {
          SnackBarUtils.showSnackBar(
            context,
            'Please select at least one bay.',
            isError: true,
          );
          setState(() => _isSaving = false);
          return;
        }

        for (Bay bay in _selectedMultiBays) {
          final String baySpecificFlagsCause =
              _bayFlagsControllers[bay.id]?.text.trim() ?? '';

          final newEntry = TrippingShutdownEntry(
            substationId: widget.substationId,
            bayId: bay.id,
            bayName: bay.name,
            eventType: _selectedEventType!,
            startTime: Timestamp.fromDate(
              DateTime(
                _startDate!.year,
                _startDate!.month,
                _startDate!.day,
                _startTime!.hour,
                _startTime!.minute,
              ),
            ),
            endTime: eventEndTime,
            status: status,
            flagsCause: baySpecificFlagsCause,
            reasonForNonFeeder:
                _reasonForNonFeederController.text.trim().isNotEmpty
                ? _reasonForNonFeederController.text.trim()
                : null,
            hasAutoReclose: _showHasAutoReclose ? _hasAutoReclose : null,
            phaseFaults:
                _selectedEventType == 'Tripping' &&
                    _showPhaseFaults &&
                    _selectedPhaseFaults.isNotEmpty
                ? _selectedPhaseFaults
                : null,
            distance:
                _selectedEventType == 'Tripping' &&
                    _showDistance &&
                    _distanceController.text.trim().isNotEmpty
                ? _distanceController.text.trim()
                : null,
            createdBy: currentUserId,
            createdAt: nowTimestamp,
            closedBy: closedBy,
            closedAt: closedAt,
            shutdownType: _selectedEventType == 'Shutdown'
                ? _selectedShutdownType
                : null,
            shutdownPersonName: _selectedEventType == 'Shutdown'
                ? _shutdownPersonNameController.text.trim()
                : null,
            shutdownPersonDesignation: _selectedEventType == 'Shutdown'
                ? _shutdownPersonDesignationController.text.trim()
                : null,
          );

          await FirebaseFirestore.instance
              .collection('trippingShutdownEntries')
              .add(
                newEntry.toFirestore()
                  ..addAll({'substationName': widget.substationName}),
              );
        }

        if (mounted) {
          SnackBarUtils.showSnackBar(
            context,
            'Event(s) created successfully! ${_selectedEventType == 'Tripping' ? '⚡' : '🔌'} Notifications sent to managers.',
          );
        }
      } else {
        if (widget.currentUser.role == UserRole.substationUser &&
            !_isClosingEvent) {
          SnackBarUtils.showSnackBar(
            context,
            'Substation Users can only close events, not modify them directly.',
            isError: true,
          );
          setState(() => _isSaving = false);
          return;
        }

        final modificationReason = await _showModificationReasonDialog();
        if (widget.currentUser.role == UserRole.subdivisionManager &&
            (modificationReason == null || modificationReason.isEmpty)) {
          SnackBarUtils.showSnackBar(
            context,
            'A reason is required to modify an existing event.',
            isError: true,
          );
          setState(() => _isSaving = false);
          return;
        }

        final updatedEntry = widget.entryToEdit!.copyWith(
          bayId: _selectedBay!.id,
          bayName: _selectedBay!.name,
          eventType: _selectedEventType,
          startTime: Timestamp.fromDate(
            DateTime(
              _startDate!.year,
              _startDate!.month,
              _startDate!.day,
              _startTime!.hour,
              _startTime!.minute,
            ),
          ),
          endTime: eventEndTime,
          status: status,
          flagsCause: _flagsCauseController.text.trim(),
          reasonForNonFeeder:
              _reasonForNonFeederController.text.trim().isNotEmpty
              ? _reasonForNonFeederController.text.trim()
              : null,
          hasAutoReclose: _showHasAutoReclose ? _hasAutoReclose : null,
          phaseFaults:
              _selectedEventType == 'Tripping' &&
                  _showPhaseFaults &&
                  _selectedPhaseFaults.isNotEmpty
              ? _selectedPhaseFaults
              : null,
          distance:
              _selectedEventType == 'Tripping' &&
                  _showDistance &&
                  _distanceController.text.trim().isNotEmpty
              ? _distanceController.text.trim()
              : null,
          closedBy: closedBy,
          closedAt: closedAt,
          shutdownType: _selectedEventType == 'Shutdown'
              ? _selectedShutdownType
              : null,
          shutdownPersonName: _selectedEventType == 'Shutdown'
              ? _shutdownPersonNameController.text.trim()
              : null,
          shutdownPersonDesignation: _selectedEventType == 'Shutdown'
              ? _shutdownPersonDesignationController.text.trim()
              : null,
        );

        await FirebaseFirestore.instance
            .collection('trippingShutdownEntries')
            .doc(updatedEntry.id)
            .update(
              updatedEntry.toFirestore()
                ..addAll({'substationName': widget.substationName}),
            );

        if (widget.currentUser.role == UserRole.subdivisionManager &&
            modificationReason != null &&
            modificationReason.isNotEmpty) {
          await FirebaseFirestore.instance
              .collection('eventModifications')
              .add({
                'eventId': updatedEntry.id,
                'modifiedBy': currentUserId,
                'modifiedAt': nowTimestamp,
                'reason': modificationReason,
                'oldEventData': widget.entryToEdit!.toFirestore(),
                'newEventData': updatedEntry.toFirestore(),
              });
        }

        if (mounted) {
          SnackBarUtils.showSnackBar(
            context,
            'Event updated successfully! ${_isClosingEvent ? 'Closure notifications sent.' : ''}',
          );
        }
      }

      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      print("Error saving event: $e");
      if (mounted) {
        SnackBarUtils.showSnackBar(
          context,
          'Failed to save event: $e',
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _showNotificationPreview() async {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final selectedBay = _selectedMultiBays.first;

    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: isDarkMode ? const Color(0xFF2C2C2E) : Colors.white,
        title: Row(
          children: [
            Icon(
              _selectedEventType == 'Tripping'
                  ? Icons.flash_on
                  : Icons.power_off,
              color: _selectedEventType == 'Tripping'
                  ? Colors.red
                  : Colors.orange,
            ),
            const SizedBox(width: 8),
            Text(
              'Notification Preview',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: isDarkMode ? Colors.white : Colors.black87,
              ),
            ),
          ],
        ),
        content: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color:
                (_selectedEventType == 'Tripping' ? Colors.red : Colors.orange)
                    .withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color:
                  (_selectedEventType == 'Tripping'
                          ? Colors.red
                          : Colors.orange)
                      .withOpacity(0.3),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _selectedEventType == 'Tripping'
                    ? '⚡ Tripping Event Alert'
                    : '🔌 Shutdown Event Alert',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isDarkMode ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${selectedBay.name} at ${widget.substationName} - ${selectedBay.voltageLevel}',
                style: TextStyle(
                  fontSize: 14,
                  color: isDarkMode
                      ? Colors.white.withOpacity(0.8)
                      : Colors.black87,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'This notification will be sent to subdivision managers, division managers, and higher officials in the hierarchy based on their notification preferences.',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDarkMode
                        ? Colors.blue.shade300
                        : Colors.blue.shade700,
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'Continue',
              style: TextStyle(color: theme.colorScheme.primary),
            ),
          ),
        ],
      ),
    );
  }

  Future<String?> _showModificationReasonDialog() async {
    if (widget.currentUser.role != UserRole.subdivisionManager ||
        widget.entryToEdit == null) {
      return "N/A";
    }

    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    TextEditingController reasonController = TextEditingController();

    return await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: isDarkMode ? const Color(0xFF2C2C2E) : Colors.white,
        title: Text(
          'Reason for Modification',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: isDarkMode ? Colors.white : Colors.black87,
          ),
        ),
        content: TextFormField(
          controller: reasonController,
          style: TextStyle(color: isDarkMode ? Colors.white : Colors.black87),
          decoration: InputDecoration(
            hintText: 'Enter reason for modification...',
            hintStyle: TextStyle(
              color: isDarkMode ? Colors.white.withOpacity(0.6) : Colors.grey,
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            filled: true,
            fillColor: isDarkMode
                ? const Color(0xFF3C3C3E)
                : theme.colorScheme.primary.withOpacity(0.05),
          ),
          maxLength: 200,
          maxLines: 3,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: isDarkMode
                    ? Colors.white.withOpacity(0.7)
                    : theme.colorScheme.onSurface,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(reasonController.text),
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: theme.colorScheme.onPrimary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Submit'),
          ),
        ],
      ),
    );
  }

  IconData _getBayTypeIcon(String bayType) {
    switch (bayType.toLowerCase()) {
      case 'transformer':
        return Icons.electrical_services;
      case 'feeder':
        return Icons.power;
      case 'line':
        return Icons.power_input;
      case 'busbar':
        return Icons.horizontal_rule;
      case 'capacitor bank':
        return Icons.battery_charging_full;
      case 'reactor':
        return Icons.device_hub;
      default:
        return Icons.electrical_services;
    }
  }

  Widget _buildFormCard({
    required String title,
    required Widget child,
    IconData? icon,
    Color? iconColor,
  }) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF2C2C2E) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: isDarkMode
                ? Colors.black.withOpacity(0.3)
                : Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (icon != null) ...[
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: (iconColor ?? theme.colorScheme.primary)
                          .withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      icon,
                      color: iconColor ?? theme.colorScheme.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: isDarkMode ? Colors.white : Colors.black87,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }

  Widget _buildDateTimeSelector({
    required String label,
    required DateTime? date,
    required TimeOfDay? time,
    required bool isStart,
    required bool enabled,
    IconData? icon,
  }) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        border: Border.all(
          color: isDarkMode
              ? Colors.grey.shade700
              : theme.colorScheme.outline.withOpacity(0.3),
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: enabled ? () => _selectDateTime(context, isStart) : null,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(
                    icon ?? Icons.schedule,
                    color: enabled
                        ? theme.colorScheme.primary
                        : (isDarkMode ? Colors.grey.shade600 : Colors.grey),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 14,
                          color: isDarkMode
                              ? Colors.white.withOpacity(0.7)
                              : theme.colorScheme.onSurface.withOpacity(0.7),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        date != null && time != null
                            ? '${DateFormat('yyyy-MM-dd').format(date)} at ${time.format(context)}'
                            : 'Select Date & Time',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: enabled
                              ? (isDarkMode ? Colors.white : Colors.black87)
                              : (isDarkMode
                                    ? Colors.grey.shade600
                                    : Colors.grey),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios,
                  color: enabled
                      ? theme.colorScheme.primary
                      : (isDarkMode ? Colors.grey.shade600 : Colors.grey),
                  size: 16,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildChipSelector({
    required String label,
    required List<String> options,
    required List<String> selectedValues,
    required Function(String, bool) onSelectionChanged,
    required bool enabled,
  }) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: isDarkMode ? Colors.white : Colors.black87,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8.0,
          runSpacing: 8.0,
          children: options.map((option) {
            bool isSelected = selectedValues.contains(option);
            return FilterChip(
              label: Text(
                option,
                style: TextStyle(
                  color: isSelected
                      ? theme.colorScheme.primary
                      : (isDarkMode ? Colors.white : Colors.black87),
                ),
              ),
              selected: isSelected,
              onSelected: enabled
                  ? (selected) => onSelectionChanged(option, selected)
                  : null,
              selectedColor: theme.colorScheme.primary.withOpacity(0.2),
              checkmarkColor: theme.colorScheme.primary,
              backgroundColor: isDarkMode
                  ? Colors.grey.shade800
                  : Colors.grey.shade100,
              side: BorderSide(
                color: isSelected
                    ? theme.colorScheme.primary
                    : (isDarkMode
                          ? Colors.grey.shade700
                          : Colors.grey.shade300),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    bool isEditingExisting = widget.entryToEdit != null;
    bool isClosedEvent =
        isEditingExisting && widget.entryToEdit!.status == 'CLOSED';
    bool isReadOnly = widget.isViewOnly || isClosedEvent;
    bool isFormEnabled = !isReadOnly && !_isSaving;
    bool isMultiBaySelectionMode = !isEditingExisting;
    bool isFlagsCauseMandatoryGlobal =
        (_selectedEventType == 'Shutdown') || (_isClosingEvent);

    return Scaffold(
      backgroundColor: isDarkMode
          ? const Color(0xFF1C1C1E)
          : const Color(0xFFFAFAFA),
      appBar: AppBar(
        backgroundColor: isDarkMode ? const Color(0xFF2C2C2E) : Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: theme.colorScheme.onSurface),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          isEditingExisting
              ? isClosedEvent
                    ? 'View Event Details'
                    : _isClosingEvent
                    ? 'Close Event'
                    : 'Edit Event'
              : 'New Event Entry',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.onSurface,
          ),
        ),
        actions: [
          if (!isEditingExisting)
            Container(
              margin: const EdgeInsets.only(right: 8, top: 8, bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.2),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.blue.withOpacity(0.5)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.notifications_active,
                    size: 14,
                    color: isDarkMode
                        ? Colors.blue.shade300
                        : Colors.blue.shade700,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Auto-notify',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: isDarkMode
                          ? Colors.blue.shade300
                          : Colors.blue.shade700,
                    ),
                  ),
                ],
              ),
            ),
          if (isEditingExisting)
            Container(
              margin: const EdgeInsets.only(right: 16, top: 8, bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: (isClosedEvent ? Colors.green : Colors.orange)
                    .withOpacity(0.2),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: (isClosedEvent ? Colors.green : Colors.orange)
                      .withOpacity(0.5),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isClosedEvent ? Icons.check_circle : Icons.pending,
                    size: 16,
                    color: isClosedEvent
                        ? Colors.green.shade700
                        : Colors.orange.shade700,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    isClosedEvent ? 'Closed' : 'Open',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: isClosedEvent
                          ? Colors.green.shade700
                          : Colors.orange.shade700,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
      body: _isLoading
          ? Center(
              child: Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: isDarkMode ? const Color(0xFF2C2C2E) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: isDarkMode
                          ? Colors.black.withOpacity(0.3)
                          : Colors.black.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(
                      color: theme.colorScheme.primary,
                      strokeWidth: 3,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Loading event details...',
                      style: TextStyle(
                        fontSize: 16,
                        color: isDarkMode ? Colors.white : Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
            )
          : Form(
              key: _formKey,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (!isEditingExisting)
                    Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: isDarkMode
                              ? [
                                  Colors.blue.shade800.withOpacity(0.3),
                                  Colors.green.shade800.withOpacity(0.3),
                                ]
                              : [Colors.blue.shade50, Colors.green.shade50],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.blue.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: isDarkMode
                                  ? Colors.blue.shade800.withOpacity(0.5)
                                  : Colors.blue.shade100,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.notifications_active,
                              color: isDarkMode
                                  ? Colors.blue.shade300
                                  : Colors.blue.shade700,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Hierarchical Notifications Enabled',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: isDarkMode
                                        ? Colors.blue.shade300
                                        : Colors.blue.shade700,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Creating this event will automatically send notifications to subdivision, division, circle, zone managers, and admins based on their notification preferences.',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDarkMode
                                        ? Colors.blue.shade300
                                        : Colors.blue.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                  _buildFormCard(
                    title: isMultiBaySelectionMode
                        ? 'Select Bay(s)'
                        : 'Selected Bay',
                    icon: Icons.electrical_services,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (isMultiBaySelectionMode &&
                            _allBays.isNotEmpty &&
                            _selectedMultiBays.isEmpty)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 16.0),
                            child: Text(
                              'Please select at least one bay to proceed.',
                              style: TextStyle(
                                color: theme.colorScheme.error,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                        if (isMultiBaySelectionMode)
                          DropdownSearch<Bay>.multiSelection(
                            items: _allBays,
                            selectedItems: _selectedMultiBays,
                            itemAsString: (Bay bay) =>
                                '${bay.name} (${bay.bayType})',
                            dropdownDecoratorProps: DropDownDecoratorProps(
                              dropdownSearchDecoration: InputDecoration(
                                labelText: 'Select Bay(s)',
                                labelStyle: TextStyle(
                                  color: isDarkMode
                                      ? Colors.white.withOpacity(0.7)
                                      : null,
                                ),
                                border: OutlineInputBorder(),
                                helperText: 'Select one or more bays',
                                helperStyle: TextStyle(
                                  color: isDarkMode
                                      ? Colors.white.withOpacity(0.6)
                                      : null,
                                ),
                                filled: isDarkMode,
                                fillColor: isDarkMode
                                    ? const Color(0xFF2C2C2E)
                                    : null,
                              ),
                            ),
                            enabled: isFormEnabled,
                            onChanged: (List<Bay> newValue) {
                              setState(() {
                                _selectedMultiBays = newValue;
                                _selectedBay = newValue.firstWhereOrNull(
                                  (bay) => true,
                                );

                                final Map<String, TextEditingController>
                                newBayFlagsControllers = {};
                                for (var bay in newValue) {
                                  newBayFlagsControllers[bay.id] =
                                      _bayFlagsControllers[bay.id] ??
                                      TextEditingController();
                                }

                                _bayFlagsControllers.forEach((id, controller) {
                                  if (!newBayFlagsControllers.containsKey(id)) {
                                    controller.dispose();
                                  }
                                });
                                _bayFlagsControllers = newBayFlagsControllers;
                                _updateConditionalFields();
                              });
                            },
                            validator: (selectedItems) {
                              if (selectedItems == null ||
                                  selectedItems.isEmpty) {
                                return 'Please select at least one bay';
                              }
                              return null;
                            },
                          )
                        else
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: isDarkMode
                                    ? Colors.grey.shade700
                                    : Colors.grey.shade300,
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.primary
                                        .withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    _selectedBay != null
                                        ? _getBayTypeIcon(_selectedBay!.bayType)
                                        : Icons.electrical_services,
                                    color: theme.colorScheme.primary,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    _selectedBay != null
                                        ? '${_selectedBay!.name} (${_selectedBay!.bayType})'
                                        : 'No bay selected',
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: isDarkMode
                                          ? Colors.white
                                          : Colors.black87,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),

                  _buildFormCard(
                    title: 'Event Type',
                    icon: Icons.flash_on,
                    iconColor: _selectedEventType == 'Tripping'
                        ? Colors.red
                        : Colors.orange,
                    child: DropdownButtonFormField<String>(
                      decoration: InputDecoration(
                        labelText: 'Event Type',
                        labelStyle: TextStyle(
                          color: isDarkMode
                              ? Colors.white.withOpacity(0.7)
                              : null,
                        ),
                        border: OutlineInputBorder(),
                        filled: isDarkMode,
                        fillColor: isDarkMode ? const Color(0xFF2C2C2E) : null,
                      ),
                      value: _selectedEventType,
                      items: _eventTypes.map((type) {
                        return DropdownMenuItem<String>(
                          value: type,
                          child: Row(
                            children: [
                              Icon(
                                type == 'Tripping'
                                    ? Icons.flash_on
                                    : Icons.power_off,
                                color: type == 'Tripping'
                                    ? Colors.red
                                    : Colors.orange,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                type,
                                style: TextStyle(
                                  color: isDarkMode
                                      ? Colors.white
                                      : Colors.black87,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: isFormEnabled
                          ? (String? newValue) {
                              setState(() {
                                _selectedEventType = newValue;
                                _updateConditionalFields();
                              });
                            }
                          : null,
                      validator: (value) =>
                          value == null ? 'Please select event type' : null,
                      dropdownColor: isDarkMode
                          ? const Color(0xFF2C2C2E)
                          : Colors.white,
                      iconEnabledColor: theme.colorScheme.primary,
                      style: TextStyle(
                        color: isDarkMode ? Colors.white : Colors.black87,
                      ),
                    ),
                  ),

                  _buildFormCard(
                    title: 'Event Timing',
                    icon: Icons.schedule,
                    child: Column(
                      children: [
                        _buildDateTimeSelector(
                          label: 'Start Date & Time',
                          date: _startDate,
                          time: _startTime,
                          isStart: true,
                          enabled: isFormEnabled,
                          icon: Icons.play_arrow,
                        ),
                        if (isEditingExisting && !isClosedEvent) ...[
                          const SizedBox(height: 16),
                          _buildDateTimeSelector(
                            label: 'End Date & Time',
                            date: _endDate,
                            time: _endTime,
                            isStart: false,
                            enabled: isFormEnabled,
                            icon: Icons.stop,
                          ),
                        ],
                      ],
                    ),
                  ),

                  _buildFormCard(
                    title: 'Event Details',
                    icon: Icons.description,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (isMultiBaySelectionMode &&
                            _selectedMultiBays.isNotEmpty)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Flags/Cause of Event (per Bay):',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: isDarkMode
                                      ? Colors.white
                                      : Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 12),
                              ..._selectedMultiBays.map((bay) {
                                if (!_bayFlagsControllers.containsKey(bay.id)) {
                                  _bayFlagsControllers[bay.id] =
                                      TextEditingController(text: '');
                                }
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 16.0),
                                  child: TextFormField(
                                    controller: _bayFlagsControllers[bay.id],
                                    style: TextStyle(
                                      color: isDarkMode
                                          ? Colors.white
                                          : Colors.black87,
                                    ),
                                    decoration: InputDecoration(
                                      labelText: 'Flags/Cause for ${bay.name}',
                                      labelStyle: TextStyle(
                                        color: isDarkMode
                                            ? Colors.white.withOpacity(0.7)
                                            : null,
                                      ),
                                      border: const OutlineInputBorder(),
                                      alignLabelWithHint: true,
                                      filled: isDarkMode,
                                      fillColor: isDarkMode
                                          ? const Color(0xFF2C2C2E)
                                          : null,
                                    ),
                                    maxLines: 3,
                                    enabled: isFormEnabled,
                                    validator: (value) {
                                      if (isFlagsCauseMandatoryGlobal) {
                                        if (value == null ||
                                            value.trim().isEmpty) {
                                          if (_selectedEventType ==
                                              'Shutdown') {
                                            return 'Reason for Shutdown for ${bay.name} is mandatory.';
                                          } else if (_isClosingEvent) {
                                            return 'Reason for closing for ${bay.name} is mandatory.';
                                          }
                                          return 'Flags/Cause for ${bay.name} cannot be empty.';
                                        }
                                      }
                                      return null;
                                    },
                                  ),
                                );
                              }).toList(),
                            ],
                          )
                        else
                          TextFormField(
                            controller: _flagsCauseController,
                            style: TextStyle(
                              color: isDarkMode ? Colors.white : Colors.black87,
                            ),
                            decoration: InputDecoration(
                              labelText: 'Flags/Cause of Event',
                              labelStyle: TextStyle(
                                color: isDarkMode
                                    ? Colors.white.withOpacity(0.7)
                                    : null,
                              ),
                              border: OutlineInputBorder(),
                              alignLabelWithHint: true,
                              filled: isDarkMode,
                              fillColor: isDarkMode
                                  ? const Color(0xFF2C2C2E)
                                  : null,
                            ),
                            maxLines: 3,
                            enabled: isFormEnabled,
                            validator: (value) {
                              if (isFlagsCauseMandatoryGlobal) {
                                if (value == null || value.trim().isEmpty) {
                                  if (_selectedEventType == 'Shutdown') {
                                    return 'Reason for Shutdown is mandatory.';
                                  } else if (_isClosingEvent) {
                                    return 'Reason for closing the event is mandatory.';
                                  }
                                  return 'Flags/Cause cannot be empty.';
                                }
                              }
                              return null;
                            },
                          ),
                      ],
                    ),
                  ),

                  if (_showReasonForNonFeeder)
                    _buildFormCard(
                      title: 'Non-Feeder Bay Reason',
                      icon: Icons.help_outline,
                      iconColor: Colors.blue,
                      child: TextFormField(
                        controller: _reasonForNonFeederController,
                        style: TextStyle(
                          color: isDarkMode ? Colors.white : Colors.black87,
                        ),
                        decoration: InputDecoration(
                          labelText:
                              'Reason for Tripping/Shutdown (Non-Feeder Bay)',
                          labelStyle: TextStyle(
                            color: isDarkMode
                                ? Colors.white.withOpacity(0.7)
                                : null,
                          ),
                          border: OutlineInputBorder(),
                          filled: isDarkMode,
                          fillColor: isDarkMode
                              ? const Color(0xFF2C2C2E)
                              : null,
                        ),
                        maxLines: 2,
                        enabled: isFormEnabled,
                      ),
                    ),

                  if (_showHasAutoReclose)
                    _buildFormCard(
                      title: 'Auto-Reclose Settings',
                      icon: Icons.refresh,
                      iconColor: Colors.green,
                      child: SwitchListTile(
                        title: Text(
                          'Auto-reclose (A/R) occurred',
                          style: TextStyle(
                            color: isDarkMode ? Colors.white : Colors.black87,
                          ),
                        ),
                        value: _hasAutoReclose,
                        onChanged: isFormEnabled
                            ? (bool value) =>
                                  setState(() => _hasAutoReclose = value)
                            : null,
                        secondary: Icon(
                          Icons.power_settings_new,
                          color: Colors.green,
                        ),
                        contentPadding: EdgeInsets.zero,
                        activeColor: Colors.green,
                      ),
                    ),

                  if (_showPhaseFaults)
                    _buildFormCard(
                      title: 'Phase Fault Selection',
                      icon: Icons.flash_on,
                      iconColor: Colors.red,
                      child: _buildChipSelector(
                        label: 'Select Phase Faults:',
                        options: _phaseFaultOptions,
                        selectedValues: _selectedPhaseFaults,
                        onSelectionChanged: (fault, selected) {
                          setState(() {
                            if (selected) {
                              _selectedPhaseFaults.add(fault);
                            } else {
                              _selectedPhaseFaults.remove(fault);
                            }
                          });
                        },
                        enabled: isFormEnabled,
                      ),
                    ),

                  if (_showDistance)
                    _buildFormCard(
                      title: 'Fault Distance',
                      icon: Icons.straighten,
                      iconColor: Colors.purple,
                      child: TextFormField(
                        controller: _distanceController,
                        style: TextStyle(
                          color: isDarkMode ? Colors.white : Colors.black87,
                        ),
                        decoration: InputDecoration(
                          labelText: 'Fault Distance (Km)',
                          labelStyle: TextStyle(
                            color: isDarkMode
                                ? Colors.white.withOpacity(0.7)
                                : null,
                          ),
                          border: OutlineInputBorder(),
                          filled: isDarkMode,
                          fillColor: isDarkMode
                              ? const Color(0xFF2C2C2E)
                              : null,
                        ),
                        keyboardType: TextInputType.number,
                        enabled: isFormEnabled,
                      ),
                    ),

                  if (_selectedEventType == 'Shutdown')
                    _buildFormCard(
                      title: 'Shutdown Details',
                      icon: Icons.power_off,
                      iconColor: Colors.orange,
                      child: Column(
                        children: [
                          DropdownButtonFormField<String>(
                            decoration: InputDecoration(
                              labelText: 'Shutdown Type',
                              labelStyle: TextStyle(
                                color: isDarkMode
                                    ? Colors.white.withOpacity(0.7)
                                    : null,
                              ),
                              border: OutlineInputBorder(),
                              filled: isDarkMode,
                              fillColor: isDarkMode
                                  ? const Color(0xFF2C2C2E)
                                  : null,
                            ),
                            value: _selectedShutdownType,
                            items: _shutdownTypes.map((type) {
                              return DropdownMenuItem<String>(
                                value: type,
                                child: Text(
                                  type,
                                  style: TextStyle(
                                    color: isDarkMode
                                        ? Colors.white
                                        : Colors.black87,
                                  ),
                                ),
                              );
                            }).toList(),
                            onChanged: isFormEnabled
                                ? (String? newValue) => setState(
                                    () => _selectedShutdownType = newValue,
                                  )
                                : null,
                            validator: _selectedEventType == 'Shutdown'
                                ? (value) => value == null
                                      ? 'Please select shutdown type'
                                      : null
                                : null,
                            dropdownColor: isDarkMode
                                ? const Color(0xFF2C2C2E)
                                : Colors.white,
                            iconEnabledColor: theme.colorScheme.primary,
                            style: TextStyle(
                              color: isDarkMode ? Colors.white : Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _shutdownPersonNameController,
                            style: TextStyle(
                              color: isDarkMode ? Colors.white : Colors.black87,
                            ),
                            decoration: InputDecoration(
                              labelText: 'Name of Person Taking Shutdown',
                              labelStyle: TextStyle(
                                color: isDarkMode
                                    ? Colors.white.withOpacity(0.7)
                                    : null,
                              ),
                              border: OutlineInputBorder(),
                              filled: isDarkMode,
                              fillColor: isDarkMode
                                  ? const Color(0xFF2C2C2E)
                                  : null,
                            ),
                            enabled: isFormEnabled,
                            validator: _selectedEventType == 'Shutdown'
                                ? (value) =>
                                      value == null || value.trim().isEmpty
                                      ? 'Name is required'
                                      : null
                                : null,
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _shutdownPersonDesignationController,
                            style: TextStyle(
                              color: isDarkMode ? Colors.white : Colors.black87,
                            ),
                            decoration: InputDecoration(
                              labelText:
                                  'Designation of Person Taking Shutdown',
                              labelStyle: TextStyle(
                                color: isDarkMode
                                    ? Colors.white.withOpacity(0.7)
                                    : null,
                              ),
                              border: OutlineInputBorder(),
                              filled: isDarkMode,
                              fillColor: isDarkMode
                                  ? const Color(0xFF2C2C2E)
                                  : null,
                            ),
                            enabled: isFormEnabled,
                            validator: _selectedEventType == 'Shutdown'
                                ? (value) =>
                                      value == null || value.trim().isEmpty
                                      ? 'Designation is required'
                                      : null
                                : null,
                          ),
                        ],
                      ),
                    ),

                  if (isReadOnly)
                    Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isDarkMode
                            ? Colors.blue.shade800.withOpacity(0.3)
                            : Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.blue.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: isDarkMode
                                ? Colors.blue.shade300
                                : Colors.blue.shade700,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              widget.isViewOnly
                                  ? 'This event is in view-only mode.'
                                  : 'This event is already closed.',
                              style: TextStyle(
                                fontSize: 14,
                                color: isDarkMode
                                    ? Colors.blue.shade300
                                    : Colors.blue.shade700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                  const SizedBox(height: 100),
                ],
              ),
            ),
      floatingActionButton: !isReadOnly
          ? FloatingActionButton.extended(
              onPressed: _isSaving ? null : _saveEvent,
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: theme.colorScheme.onPrimary,
              elevation: 4,
              icon: _isSaving
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: theme.colorScheme.onPrimary,
                      ),
                    )
                  : Icon(
                      isEditingExisting && !isClosedEvent
                          ? Icons.check_circle_outline
                          : Icons.notification_add,
                    ),
              label: Text(
                _isSaving
                    ? 'Saving...'
                    : isEditingExisting && !isClosedEvent
                    ? 'Close Event'
                    : 'Create & Notify',
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
            )
          : null,
    );
  }
}

extension ListExtension<T> on List<T> {
  T? firstWhereOrNull(bool Function(T element) test) {
    for (var element in this) {
      if (test(element)) return element;
    }
    return null;
  }
}

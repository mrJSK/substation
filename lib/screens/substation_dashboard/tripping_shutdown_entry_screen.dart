import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:intl/intl.dart';
import 'package:dropdown_search/dropdown_search.dart';
import '../../../models/user_model.dart';
import '../../../models/bay_model.dart';
import '../../../models/tripping_shutdown_model.dart';
import '../../../services/comprehensive_cache_service.dart';
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
  final ComprehensiveCacheService _cache = ComprehensiveCacheService();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  bool _isLoading = true;
  bool _isSaving = false;
  bool _isClosingEvent = false;
  late AnimationController _animationController;

  bool _cacheHealthy = false;
  String? _cacheError;

  List<Bay> _allBays = [];
  Bay? _selectedBay;
  List<Bay> _selectedMultiBays = [];
  Map<String, TextEditingController> _bayFlagsControllers = {};
  // 🔧 FIX: Add reason controllers for ALL bay types
  Map<String, TextEditingController> _bayReasonControllers = {};

  String? _selectedEventType;
  final List<String> _eventTypes = ['Tripping', 'Shutdown'];

  // 🔧 FIX: Line reasons for Line bay tripping events only
  final List<String> _lineReasons = [
    'Bird Nest',
    'Kite Thread',
    'Polymer Flash',
    'Disc Puncture',
    'Tree',
    'Other',
  ];
  String? _selectedLineReason;
  String? _lineReasonDetails;

  DateTime? _startDate;
  TimeOfDay? _startTime;
  DateTime? _endDate;
  TimeOfDay? _endTime;

  final TextEditingController _flagsCauseController = TextEditingController();
  final TextEditingController _reasonController = TextEditingController();
  final TextEditingController _distanceController = TextEditingController();

  // 🔧 FIX: Updated conditional fields
  bool _showHasAutoReclose = false;
  bool _showPhaseFaults = false;
  bool _showDistance = false;
  bool _showLineReason =
      false; // Show pre-filled reason selection for Line bays only
  bool _showFlags = false; // Show flags field for tripping events
  bool _showReason = false; // 🔧 FIX: Show reason field for ALL tripping events

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
    _reasonController.dispose();
    _distanceController.dispose();
    _shutdownPersonNameController.dispose();
    _shutdownPersonDesignationController.dispose();
    _bayFlagsControllers.forEach((key, controller) => controller.dispose());
    _bayReasonControllers.forEach((key, controller) => controller.dispose());
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
    setState(() {
      _isLoading = true;
      _cacheError = null;
    });

    try {
      if (!_cache.isInitialized) {
        throw Exception('Cache not initialized - please restart the app');
      }

      if (!_cache.validateCache()) {
        throw Exception('Cache validation failed - data may be stale');
      }

      final substationData = _cache.substationData!;
      _allBays = substationData.bays.map((bayData) => bayData.bay).toList();
      _cacheHealthy = true;

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
        _distanceController.text = entry.distance ?? '';
        _selectedPhaseFaults = entry.phaseFaults ?? [];
        _hasAutoReclose = entry.hasAutoReclose ?? false;
        _selectedShutdownType = entry.shutdownType;
        _shutdownPersonNameController.text = entry.shutdownPersonName ?? '';
        _shutdownPersonDesignationController.text =
            entry.shutdownPersonDesignation ?? '';

        // 🔧 FIX: Parse stored reason - for Line bays from flags, for others from reasonForNonFeeder
        if (entry.eventType == 'Tripping') {
          if (_selectedBay?.bayType == 'Line' && entry.flagsCause.isNotEmpty) {
            _parseStoredLineReason(entry.flagsCause);
          } else if (entry.reasonForNonFeeder != null &&
              entry.reasonForNonFeeder!.isNotEmpty) {
            _reasonController.text = entry.reasonForNonFeeder!;
          }
        }

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

      print(
        '✅ Tripping entry form initialized from cache with ${_allBays.length} bays',
      );
      _animationController.forward();
    } catch (e) {
      print("❌ Error initializing form from cache: $e");
      setState(() {
        _cacheHealthy = false;
        _cacheError = e.toString();
      });

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

  // 🔧 FIX: Parse line reason from stored flags for Line bays
  void _parseStoredLineReason(String flagsCause) {
    for (String reason in _lineReasons) {
      if (flagsCause.contains('Reason for Tripping: $reason')) {
        _selectedLineReason = reason;
        final parts = flagsCause.split('Reason for Tripping: $reason:');
        if (parts.length > 1) {
          final details = parts.last.trim();
          if (details.isNotEmpty) {
            _lineReasonDetails = details;
          }
        }
        break;
      }
    }
  }

  // 🔧 FIX: Updated conditional field logic
  void _updateConditionalFields() {
    setState(() {
      if (_selectedBay == null && _selectedMultiBays.isEmpty) {
        _showHasAutoReclose = false;
        _showPhaseFaults = false;
        _showDistance = false;
        _showLineReason = false;
        _showFlags = false;
        _showReason = false;
      } else {
        // 🔧 FIX: FLAGS and REASON are mandatory for ALL tripping events
        _showFlags = _selectedEventType == 'Tripping';
        _showReason = _selectedEventType == 'Tripping';

        _showHasAutoReclose =
            _selectedBay != null &&
            _selectedBay!.bayType == 'Line' &&
            _parseVoltageLevel(_selectedBay!.voltageLevel) >= 220 &&
            _selectedEventType == 'Tripping';

        _showPhaseFaults = _selectedEventType == 'Tripping';

        _showDistance =
            _selectedEventType == 'Tripping' &&
            _selectedBay != null &&
            _selectedBay!.bayType == 'Line';

        // 🔧 FIX: Show pre-filled reason selection ONLY for Line bay tripping events
        _showLineReason =
            _selectedEventType == 'Tripping' &&
            _selectedBay != null &&
            _selectedBay!.bayType == 'Line';
      }

      if (!_showPhaseFaults) _selectedPhaseFaults.clear();
      if (!_showDistance) _distanceController.clear();
      if (!_showLineReason) {
        _selectedLineReason = null;
        _lineReasonDetails = null;
      }
      if (!_showReason) _reasonController.clear();

      // Clear shutdown fields for tripping events
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

  bool _canCreateEvents() {
    return [
      UserRole.admin,
      UserRole.substationUser,
      UserRole.subdivisionManager,
    ].contains(widget.currentUser.role);
  }

  bool _canEditEvent(TrippingShutdownEntry? entry) {
    if (entry == null) return _canCreateEvents();

    if (entry.status == 'CLOSED') {
      return [
        UserRole.admin,
        UserRole.subdivisionManager,
      ].contains(widget.currentUser.role);
    }

    return [
      UserRole.admin,
      UserRole.substationUser,
      UserRole.subdivisionManager,
    ].contains(widget.currentUser.role);
  }

  // 🔧 FIX: Line reason dialog for Line bays only
  Future<void> _showLineReasonDialog() async {
    String? selectedReason = await showDialog<String>(
      context: context,
      builder: (context) => _LineReasonSelectionDialog(
        initialReason: _selectedLineReason,
        reasons: _lineReasons,
      ),
    );

    if (selectedReason != null) {
      String? details;
      if (selectedReason != 'Other') {
        details = await _showTowerNumberDialog(selectedReason);
      } else {
        details = await _showTextInputDialog('Enter other reason');
      }

      if (details != null && details.isNotEmpty) {
        setState(() {
          _selectedLineReason = selectedReason;
          _lineReasonDetails = details;
        });
      }
    }
  }

  // 🔧 FIX: Tower number dialog with numeric keypad
  Future<String?> _showTowerNumberDialog(String reason) async {
    return showDialog<String>(
      context: context,
      builder: (context) => _TowerNumberDialog(reason: reason),
    );
  }

  // 🔧 FIX: Text input dialog for "Other" reason
  Future<String?> _showTextInputDialog(String title) async {
    return showDialog<String>(
      context: context,
      builder: (context) => _TextInputDialog(title: title),
    );
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

  // 🔧 FIX: Updated save logic with proper flags and reason handling
  Future<void> _saveEvent() async {
    if (!_formKey.currentState!.validate()) return;

    if (widget.entryToEdit == null && !_canCreateEvents()) {
      SnackBarUtils.showSnackBar(
        context,
        'You do not have permission to create events.',
        isError: true,
      );
      return;
    }

    if (widget.entryToEdit != null && !_canEditEvent(widget.entryToEdit!)) {
      SnackBarUtils.showSnackBar(
        context,
        'You do not have permission to edit this event.',
        isError: true,
      );
      return;
    }

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

    // 🔧 FIX: Validation for Line bay pre-filled reason
    if (_showLineReason &&
        (_selectedLineReason == null || _lineReasonDetails == null)) {
      SnackBarUtils.showSnackBar(
        context,
        'Please select a reason for the line tripping event.',
        isError: true,
      );
      return;
    }

    // 🔧 FIX: Shutdown validations
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

    // 🔧 FIX: FLAGS validation for ALL tripping events
    if (_selectedEventType == 'Tripping') {
      if (widget.entryToEdit == null) {
        // For new events, check bay-specific flags
        for (var bay in _selectedMultiBays) {
          final flagsController = _bayFlagsControllers[bay.id];
          if (flagsController == null || flagsController.text.trim().isEmpty) {
            SnackBarUtils.showSnackBar(
              context,
              'FLAGS are mandatory for ${bay.name} tripping event.',
              isError: true,
            );
            return;
          }

          // 🔧 FIX: Check reason for ALL bay types
          if (bay.bayType == 'Line') {
            // Line bays use pre-filled reason selection
            if (_selectedLineReason == null || _lineReasonDetails == null) {
              SnackBarUtils.showSnackBar(
                context,
                'Reason is mandatory for ${bay.name} tripping event.',
                isError: true,
              );
              return;
            }
          } else {
            // Non-Line bays use free-text reason
            final reasonController = _bayReasonControllers[bay.id];
            if (reasonController == null ||
                reasonController.text.trim().isEmpty) {
              SnackBarUtils.showSnackBar(
                context,
                'Reason is mandatory for ${bay.name} tripping event.',
                isError: true,
              );
              return;
            }
          }
        }
      } else {
        // For editing existing events
        if (_flagsCauseController.text.trim().isEmpty && !_isClosingEvent) {
          SnackBarUtils.showSnackBar(
            context,
            'FLAGS are mandatory for tripping events.',
            isError: true,
          );
          return;
        }

        // 🔧 FIX: Check reason for existing events
        if (_selectedBay?.bayType == 'Line') {
          if (_selectedLineReason == null || _lineReasonDetails == null) {
            SnackBarUtils.showSnackBar(
              context,
              'Reason is mandatory for line tripping events.',
              isError: true,
            );
            return;
          }
        } else {
          if (_reasonController.text.trim().isEmpty && !_isClosingEvent) {
            SnackBarUtils.showSnackBar(
              context,
              'Reason is mandatory for tripping events.',
              isError: true,
            );
            return;
          }
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

    if (widget.entryToEdit == null) {
      final hasDuplicateEvent = await _checkForDuplicateEvent();
      if (hasDuplicateEvent) {
        setState(() => _isSaving = false);
        return;
      }
    }

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
          // 🔧 FIX: Build flags/cause and reason based on event type and bay type
          String baySpecificFlagsCause = '';
          String? reasonForNonFeeder;

          if (_selectedEventType == 'Tripping') {
            // Get basic flags
            baySpecificFlagsCause =
                _bayFlagsControllers[bay.id]?.text.trim() ?? '';

            if (bay.bayType == 'Line') {
              // For Line bays, append the selected reason to flags
              if (_selectedLineReason != null && _lineReasonDetails != null) {
                if (baySpecificFlagsCause.isNotEmpty) {
                  baySpecificFlagsCause += '\n';
                }
                baySpecificFlagsCause +=
                    'Reason for Tripping: $_selectedLineReason: $_lineReasonDetails';
              }
            } else {
              // For non-Line bays, store reason in reasonForNonFeeder field
              reasonForNonFeeder = _bayReasonControllers[bay.id]?.text.trim();
            }
          }
          // For shutdown events, FLAGS field is not used (empty)

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
                reasonForNonFeeder, // 🔧 FIX: Store reason for non-Line bays
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

          final docRef = await FirebaseFirestore.instance
              .collection('trippingShutdownEntries')
              .add(
                newEntry.toFirestore()
                  ..addAll({'substationName': widget.substationName}),
              );

          final savedEntry = newEntry.copyWith(id: docRef.id);
          _cache.addTrippingEvent(savedEntry);
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

        // 🔧 FIX: Build updated flags/cause and reason for editing
        String updatedFlagsCause = '';
        String? updatedReasonForNonFeeder;

        if (_selectedEventType == 'Tripping') {
          updatedFlagsCause = _flagsCauseController.text.trim();

          if (_selectedBay?.bayType == 'Line') {
            // For Line bays, append the selected reason to flags
            if (_selectedLineReason != null && _lineReasonDetails != null) {
              if (updatedFlagsCause.isNotEmpty) {
                updatedFlagsCause += '\n';
              }
              updatedFlagsCause +=
                  'Reason for Tripping: $_selectedLineReason: $_lineReasonDetails';
            }
          } else {
            // For non-Line bays, store reason in reasonForNonFeeder field
            updatedReasonForNonFeeder = _reasonController.text.trim();
          }
        }
        // For shutdown events, FLAGS field is not used (empty)

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
          flagsCause: updatedFlagsCause,
          reasonForNonFeeder:
              updatedReasonForNonFeeder, // 🔧 FIX: Update reason for non-Line bays
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

        _cache.updateTrippingEvent(updatedEntry);

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

      await _cache.forceRefresh();

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

  Future<bool> _checkForDuplicateEvent() async {
    try {
      final oneHourAgo = DateTime.now().subtract(const Duration(hours: 1));

      for (var bay in _selectedMultiBays) {
        final existingEvents = await FirebaseFirestore.instance
            .collection('trippingShutdownEntries')
            .where('bayId', isEqualTo: bay.id)
            .where('eventType', isEqualTo: _selectedEventType)
            .where('startTime', isGreaterThan: Timestamp.fromDate(oneHourAgo))
            .where('status', isEqualTo: 'OPEN')
            .get();

        if (existingEvents.docs.isNotEmpty) {
          final shouldProceed = await _showDuplicateEventDialog(bay.name);
          if (!shouldProceed) {
            return true;
          }
        }
      }
      return false;
    } catch (e) {
      print('Error checking for duplicate events: $e');
      return false;
    }
  }

  Future<bool> _showDuplicateEventDialog(String bayName) async {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            backgroundColor: isDarkMode
                ? const Color(0xFF2C2C2E)
                : Colors.white,
            title: Row(
              children: [
                Icon(Icons.warning, color: Colors.orange),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Duplicate Event Warning',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: isDarkMode ? Colors.white : Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'A similar ${_selectedEventType?.toLowerCase()} event for $bayName already exists within the last hour.',
                  style: TextStyle(
                    fontSize: 14,
                    color: isDarkMode
                        ? Colors.white.withOpacity(0.8)
                        : Colors.black87,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.withOpacity(0.3)),
                  ),
                  child: Text(
                    'Are you sure you want to create another event for the same bay?',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.orange.shade700,
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(
                  'Cancel',
                  style: TextStyle(
                    color: isDarkMode ? Colors.white70 : Colors.grey.shade600,
                  ),
                ),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text('Proceed Anyway'),
              ),
            ],
          ),
        ) ??
        false;
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
    bool isReadOnly =
        widget.isViewOnly ||
        isClosedEvent ||
        !_canEditEvent(widget.entryToEdit);
    bool isFormEnabled = !isReadOnly && !_isSaving;
    bool isMultiBaySelectionMode = !isEditingExisting;

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
        title: Row(
          children: [
            Text(
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
          ],
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
                      'Loading from cache...',
                      style: TextStyle(
                        fontSize: 16,
                        color: isDarkMode ? Colors.white : Colors.black87,
                      ),
                    ),
                    if (_cacheError != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        _cacheError!,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.red,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
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

                                // Initialize controllers for FLAGS
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

                                // 🔧 FIX: Initialize controllers for REASON (non-Line bays only)
                                final Map<String, TextEditingController>
                                newBayReasonControllers = {};
                                for (var bay in newValue) {
                                  if (bay.bayType != 'Line') {
                                    newBayReasonControllers[bay.id] =
                                        _bayReasonControllers[bay.id] ??
                                        TextEditingController();
                                  }
                                }

                                _bayReasonControllers.forEach((id, controller) {
                                  if (!newBayReasonControllers.containsKey(
                                    id,
                                  )) {
                                    controller.dispose();
                                  }
                                });
                                _bayReasonControllers = newBayReasonControllers;

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

                  // Updated timing section with proper titles
                  _buildFormCard(
                    title: _selectedEventType == 'Tripping'
                        ? 'Trip Timing'
                        : 'Shutdown Timing',
                    icon: Icons.schedule,
                    child: Column(
                      children: [
                        _buildDateTimeSelector(
                          label: _selectedEventType == 'Tripping'
                              ? 'Trip Start Time'
                              : 'Shutdown Time',
                          date: _startDate,
                          time: _startTime,
                          isStart: true,
                          enabled: isFormEnabled,
                          icon: Icons.play_arrow,
                        ),
                        if (isEditingExisting && !isClosedEvent) ...[
                          const SizedBox(height: 16),
                          _buildDateTimeSelector(
                            label: 'Charging Time',
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

                  // 🔧 FIX: FLAGS section - MANDATORY for ALL tripping events
                  if (_showFlags)
                    _buildFormCard(
                      title: 'FLAGS (Mandatory)',
                      icon: Icons.flag,
                      iconColor: Colors.red,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (isMultiBaySelectionMode &&
                              _selectedMultiBays.isNotEmpty)
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                ..._selectedMultiBays.map((bay) {
                                  if (!_bayFlagsControllers.containsKey(
                                    bay.id,
                                  )) {
                                    _bayFlagsControllers[bay.id] =
                                        TextEditingController(text: '');
                                  }
                                  return Padding(
                                    padding: const EdgeInsets.only(
                                      bottom: 16.0,
                                    ),
                                    child: TextFormField(
                                      controller: _bayFlagsControllers[bay.id],
                                      style: TextStyle(
                                        color: isDarkMode
                                            ? Colors.white
                                            : Colors.black87,
                                      ),
                                      decoration: InputDecoration(
                                        labelText: 'FLAGS for ${bay.name}',
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
                                        if (value == null ||
                                            value.trim().isEmpty) {
                                          return 'FLAGS are mandatory for ${bay.name}';
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
                                color: isDarkMode
                                    ? Colors.white
                                    : Colors.black87,
                              ),
                              decoration: InputDecoration(
                                labelText: 'FLAGS for Tripping Event',
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
                                if (value == null || value.trim().isEmpty) {
                                  return 'FLAGS are mandatory for tripping events.';
                                }
                                return null;
                              },
                            ),
                        ],
                      ),
                    ),

                  // 🔧 FIX: REASON section - MANDATORY for ALL tripping events
                  if (_showReason)
                    _buildFormCard(
                      title: 'Reason for Tripping (Mandatory)',
                      icon: Icons.report_problem,
                      iconColor: Colors.amber,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 🔧 FIX: For Line bays, show pre-filled reason selection
                          if (_showLineReason)
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
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
                                  child: InkWell(
                                    onTap: isFormEnabled
                                        ? _showLineReasonDialog
                                        : null,
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.list_alt,
                                          color: theme.colorScheme.primary,
                                          size: 20,
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'Select Pre-filled Reason for Line',
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  color: isDarkMode
                                                      ? Colors.white
                                                            .withOpacity(0.7)
                                                      : theme
                                                            .colorScheme
                                                            .onSurface
                                                            .withOpacity(0.7),
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                _selectedLineReason != null &&
                                                        _lineReasonDetails !=
                                                            null
                                                    ? '$_selectedLineReason: $_lineReasonDetails'
                                                    : 'Tap to select reason',
                                                style: TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w500,
                                                  color:
                                                      _selectedLineReason !=
                                                          null
                                                      ? (isDarkMode
                                                            ? Colors.white
                                                            : Colors.black87)
                                                      : (isDarkMode
                                                            ? Colors
                                                                  .grey
                                                                  .shade600
                                                            : Colors.grey),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Icon(
                                          Icons.arrow_forward_ios,
                                          color: theme.colorScheme.primary,
                                          size: 16,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                if (_selectedLineReason != null &&
                                    _lineReasonDetails != null) ...[
                                  const SizedBox(height: 12),
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.green.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: Colors.green.withOpacity(0.3),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.check_circle,
                                          color: Colors.green,
                                          size: 16,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            'Selected: $_selectedLineReason: $_lineReasonDetails',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.green.shade700,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            )
                          // 🔧 FIX: For multi-bay selection (new events), show reason fields per bay
                          else if (isMultiBaySelectionMode &&
                              _selectedMultiBays.isNotEmpty)
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                ..._selectedMultiBays
                                    .where((bay) => bay.bayType != 'Line')
                                    .map((bay) {
                                      if (!_bayReasonControllers.containsKey(
                                        bay.id,
                                      )) {
                                        _bayReasonControllers[bay.id] =
                                            TextEditingController(text: '');
                                      }
                                      return Padding(
                                        padding: const EdgeInsets.only(
                                          bottom: 16.0,
                                        ),
                                        child: TextFormField(
                                          controller:
                                              _bayReasonControllers[bay.id],
                                          style: TextStyle(
                                            color: isDarkMode
                                                ? Colors.white
                                                : Colors.black87,
                                          ),
                                          decoration: InputDecoration(
                                            labelText:
                                                'Reason for ${bay.name} (${bay.bayType})',
                                            labelStyle: TextStyle(
                                              color: isDarkMode
                                                  ? Colors.white.withOpacity(
                                                      0.7,
                                                    )
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
                                            if (value == null ||
                                                value.trim().isEmpty) {
                                              return 'Reason is mandatory for ${bay.name}';
                                            }
                                            return null;
                                          },
                                        ),
                                      );
                                    })
                                    .toList(),
                              ],
                            )
                          // 🔧 FIX: For single bay editing (non-Line bays), show single reason field
                          else
                            TextFormField(
                              controller: _reasonController,
                              style: TextStyle(
                                color: isDarkMode
                                    ? Colors.white
                                    : Colors.black87,
                              ),
                              decoration: InputDecoration(
                                labelText: 'Reason for Tripping',
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
                                if (value == null || value.trim().isEmpty) {
                                  return 'Reason is mandatory for tripping events.';
                                }
                                return null;
                              },
                            ),
                        ],
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
                      title: 'Shutdown Additional Details',
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
                                  : isClosedEvent
                                  ? 'This event is already closed.'
                                  : 'You do not have permission to edit this event.',
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

// Tower Number Dialog with custom keyboard that allows hyphen
class _TowerNumberDialog extends StatefulWidget {
  final String reason;

  const _TowerNumberDialog({required this.reason});

  @override
  State<_TowerNumberDialog> createState() => _TowerNumberDialogState();
}

class _TowerNumberDialogState extends State<_TowerNumberDialog> {
  final TextEditingController _controller = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      backgroundColor: isDarkMode ? const Color(0xFF2C2C2E) : Colors.white,
      title: Text(
        '${widget.reason} - Tower Number',
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: isDarkMode ? Colors.white : Colors.black87,
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Enter tower number or span range (e.g., 147 or 147-148):',
            style: TextStyle(
              fontSize: 14,
              color: isDarkMode
                  ? Colors.white.withOpacity(0.7)
                  : Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _controller,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: isDarkMode ? Colors.white : Colors.black87,
            ),
            decoration: InputDecoration(
              hintText: 'e.g., 147 or 147-148',
              hintStyle: TextStyle(
                color: isDarkMode ? Colors.white.withOpacity(0.5) : Colors.grey,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              filled: true,
              fillColor: isDarkMode
                  ? const Color(0xFF3C3C3E)
                  : Colors.grey.shade50,
              prefixIcon: Icon(
                Icons.cell_tower,
                color: theme.colorScheme.primary,
              ),
            ),
            keyboardType: TextInputType.text,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9\-]')),
              LengthLimitingTextInputFormatter(10),
            ],
            autofocus: true,
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              'Use hyphen (-) for span ranges between towers',
              style: TextStyle(
                fontSize: 12,
                color: Colors.blue.shade700,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
          const SizedBox(height: 16),
          _buildCustomNumberPad(),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            'Cancel',
            style: TextStyle(
              color: isDarkMode ? Colors.white70 : Colors.grey.shade600,
            ),
          ),
        ),
        ElevatedButton(
          onPressed: () {
            final value = _controller.text.trim();
            if (value.isNotEmpty) {
              Navigator.of(context).pop(value);
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: theme.colorScheme.primary,
            foregroundColor: theme.colorScheme.onPrimary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: const Text('Confirm'),
        ),
      ],
    );
  }

  Widget _buildCustomNumberPad() {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.grey.shade800 : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(
            'Quick Input Pad',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: isDarkMode ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildNumberButton('1'),
              _buildNumberButton('2'),
              _buildNumberButton('3'),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildNumberButton('4'),
              _buildNumberButton('5'),
              _buildNumberButton('6'),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildNumberButton('7'),
              _buildNumberButton('8'),
              _buildNumberButton('9'),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildSpecialButton('-', Icons.remove),
              _buildNumberButton('0'),
              _buildSpecialButton('⌫', Icons.backspace, isBackspace: true),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNumberButton(String number) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return Container(
      width: 50,
      height: 40,
      child: ElevatedButton(
        onPressed: () {
          final currentText = _controller.text;
          final newText = currentText + number;
          _controller.text = newText;
          _controller.selection = TextSelection.fromPosition(
            TextPosition(offset: newText.length),
          );
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: isDarkMode ? Colors.grey.shade700 : Colors.white,
          foregroundColor: isDarkMode ? Colors.white : Colors.black87,
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        ),
        child: Text(
          number,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),
      ),
    );
  }

  Widget _buildSpecialButton(
    String label,
    IconData icon, {
    bool isBackspace = false,
  }) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return Container(
      width: 50,
      height: 40,
      child: ElevatedButton(
        onPressed: () {
          if (isBackspace) {
            final currentText = _controller.text;
            if (currentText.isNotEmpty) {
              final newText = currentText.substring(0, currentText.length - 1);
              _controller.text = newText;
              _controller.selection = TextSelection.fromPosition(
                TextPosition(offset: newText.length),
              );
            }
          } else {
            final currentText = _controller.text;
            final newText = currentText + label;
            _controller.text = newText;
            _controller.selection = TextSelection.fromPosition(
              TextPosition(offset: newText.length),
            );
          }
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: isDarkMode
              ? Colors.blue.shade700
              : Colors.blue.shade100,
          foregroundColor: isDarkMode ? Colors.white : Colors.blue.shade700,
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        ),
        child: Icon(icon, size: 18),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}

// Line Reason Selection Dialog
class _LineReasonSelectionDialog extends StatelessWidget {
  final String? initialReason;
  final List<String> reasons;

  const _LineReasonSelectionDialog({
    required this.initialReason,
    required this.reasons,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      backgroundColor: isDarkMode ? const Color(0xFF2C2C2E) : Colors.white,
      title: Text(
        'Select Reason for Line Tripping',
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: isDarkMode ? Colors.white : Colors.black87,
        ),
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: reasons.length,
          itemBuilder: (context, index) {
            final reason = reasons[index];
            final isSelected = reason == initialReason;

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: isSelected
                    ? theme.colorScheme.primary.withOpacity(0.1)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isSelected
                      ? theme.colorScheme.primary
                      : (isDarkMode
                            ? Colors.grey.shade700
                            : Colors.grey.shade300),
                ),
              ),
              child: ListTile(
                leading: Icon(
                  reason == 'Other' ? Icons.edit : Icons.report_problem,
                  color: isSelected
                      ? theme.colorScheme.primary
                      : (isDarkMode ? Colors.white : Colors.black87),
                ),
                title: Text(
                  reason,
                  style: TextStyle(
                    color: isSelected
                        ? theme.colorScheme.primary
                        : (isDarkMode ? Colors.white : Colors.black87),
                    fontWeight: isSelected
                        ? FontWeight.w600
                        : FontWeight.normal,
                  ),
                ),
                onTap: () => Navigator.of(context).pop(reason),
              ),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            'Cancel',
            style: TextStyle(
              color: isDarkMode ? Colors.white70 : Colors.grey.shade600,
            ),
          ),
        ),
      ],
    );
  }
}

// Text Input Dialog for "Other" reason
class _TextInputDialog extends StatefulWidget {
  final String title;

  const _TextInputDialog({required this.title});

  @override
  State<_TextInputDialog> createState() => _TextInputDialogState();
}

class _TextInputDialogState extends State<_TextInputDialog> {
  final TextEditingController _controller = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      backgroundColor: isDarkMode ? const Color(0xFF2C2C2E) : Colors.white,
      title: Text(
        widget.title,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: isDarkMode ? Colors.white : Colors.black87,
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextFormField(
            controller: _controller,
            style: TextStyle(color: isDarkMode ? Colors.white : Colors.black87),
            decoration: InputDecoration(
              hintText: 'Enter other reason details...',
              hintStyle: TextStyle(
                color: isDarkMode ? Colors.white.withOpacity(0.5) : Colors.grey,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              filled: true,
              fillColor: isDarkMode
                  ? const Color(0xFF3C3C3E)
                  : Colors.grey.shade50,
            ),
            maxLines: 3,
            maxLength: 200,
            autofocus: true,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            'Cancel',
            style: TextStyle(
              color: isDarkMode ? Colors.white70 : Colors.grey.shade600,
            ),
          ),
        ),
        ElevatedButton(
          onPressed: () {
            final value = _controller.text.trim();
            if (value.isNotEmpty) {
              Navigator.of(context).pop(value);
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: theme.colorScheme.primary,
            foregroundColor: theme.colorScheme.onPrimary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: const Text('Confirm'),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
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

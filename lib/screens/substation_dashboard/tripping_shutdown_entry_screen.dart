import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:dropdown_search/dropdown_search.dart';
import '../../../models/user_model.dart';
import '../../../models/bay_model.dart';
import '../../../models/tripping_shutdown_model.dart';
import '../../../utils/snackbar_utils.dart';
import 'package:collection/collection.dart'; // For firstWhereOrNull

class TrippingShutdownEntryScreen extends StatefulWidget {
  final String substationId;
  final AppUser currentUser;
  final TrippingShutdownEntry? entryToEdit;
  final bool isViewOnly;

  const TrippingShutdownEntryScreen({
    super.key,
    required this.substationId,
    required this.currentUser,
    this.entryToEdit,
    this.isViewOnly = false,
  });

  @override
  State<TrippingShutdownEntryScreen> createState() =>
      _TrippingShutdownEntryScreenState();
}

class _TrippingShutdownEntryScreenState
    extends State<TrippingShutdownEntryScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isClosingEvent = false;

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
    super.dispose();
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

    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );

    if (pickedDate != null) {
      final TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: initialTime,
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
    try {
      final String currentUserId = widget.currentUser.uid;
      final Timestamp now = Timestamp.now();
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
      Timestamp? closedAt = _endDate != null && _endTime != null ? now : null;

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
            createdAt: now,
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
              .add(newEntry.toFirestore());
        }
        if (mounted)
          SnackBarUtils.showSnackBar(context, 'Event(s) created successfully!');
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
            modificationReason!.isEmpty) {
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
            .update(updatedEntry.toFirestore());

        if (widget.currentUser.role == UserRole.subdivisionManager &&
            modificationReason!.isNotEmpty) {
          await FirebaseFirestore.instance
              .collection('eventModifications')
              .add({
                'eventId': updatedEntry.id,
                'modifiedBy': currentUserId,
                'modifiedAt': now,
                'reason': modificationReason,
                'oldEventData': widget.entryToEdit!.toFirestore(),
                'newEventData': updatedEntry.toFirestore(),
              });
        }

        if (mounted)
          SnackBarUtils.showSnackBar(context, 'Event updated successfully!');
      }

      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      print("Error saving event: $e");
      if (mounted)
        SnackBarUtils.showSnackBar(
          context,
          'Failed to save event: $e',
          isError: true,
        );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<String?> _showModificationReasonDialog() async {
    if (widget.currentUser.role != UserRole.subdivisionManager ||
        widget.entryToEdit == null) {
      return "N/A";
    }

    TextEditingController reasonController = TextEditingController();
    return await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reason for Modification'),
        content: TextField(
          controller: reasonController,
          decoration: const InputDecoration(
            hintText: "Enter reason for modifying this event...",
          ),
          autofocus: true,
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(reasonController.text),
            child: const Text('Submit'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    bool isEditingExisting = widget.entryToEdit != null;
    bool isClosedEvent =
        isEditingExisting && widget.entryToEdit!.status == 'CLOSED';
    bool isReadOnly = widget.isViewOnly || isClosedEvent;
    bool isFormEnabled = !isReadOnly && !_isSaving;
    bool isMultiBaySelectionMode = !isEditingExisting;
    bool isFlagsCauseMandatoryGlobal =
        (_selectedEventType == 'Shutdown') || (_isClosingEvent);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isEditingExisting
              ? isClosedEvent
                    ? 'View Event Details'
                    : _isClosingEvent
                    ? 'Close Event'
                    : 'Edit Event'
              : 'New Event Entry',
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                autovalidateMode: AutovalidateMode.onUserInteraction,
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
                            color: Theme.of(context).colorScheme.error,
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
                        dropdownDecoratorProps: const DropDownDecoratorProps(
                          dropdownSearchDecoration: InputDecoration(
                            labelText: 'Select Bay(s)',
                            border: OutlineInputBorder(),
                            helperText: 'Select one or more bays',
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
                          if (selectedItems == null || selectedItems.isEmpty) {
                            return 'Please select at least one bay';
                          }
                          return null;
                        },
                      )
                    else
                      DropdownSearch<Bay>(
                        items: _allBays,
                        selectedItem: _selectedBay,
                        itemAsString: (Bay bay) =>
                            '${bay.name} (${bay.bayType})',
                        dropdownDecoratorProps: const DropDownDecoratorProps(
                          dropdownSearchDecoration: InputDecoration(
                            labelText: 'Selected Bay',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        enabled: false,
                        onChanged: (Bay? newValue) {},
                        popupProps: const PopupProps.menu(showSearchBox: true),
                      ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                        labelText: 'Event Type',
                        border: OutlineInputBorder(),
                      ),
                      value: _selectedEventType,
                      items: _eventTypes.map((type) {
                        return DropdownMenuItem(value: type, child: Text(type));
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
                    ),
                    const SizedBox(height: 16),
                    ListTile(
                      title: Text(
                        'Start Date: ${_startDate != null ? DateFormat('yyyy-MM-dd').format(_startDate!) : 'Select Date'}',
                      ),
                      trailing: const Icon(Icons.calendar_today),
                      onTap: isFormEnabled
                          ? () => _selectDateTime(context, true)
                          : null,
                    ),
                    ListTile(
                      title: Text(
                        'Start Time: ${_startTime != null ? _startTime!.format(context) : 'Select Time'}',
                      ),
                      trailing: const Icon(Icons.access_time),
                      onTap: isFormEnabled
                          ? () => _selectDateTime(context, true)
                          : null,
                    ),
                    const SizedBox(height: 16),
                    if (isMultiBaySelectionMode &&
                        _selectedMultiBays.isNotEmpty)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Flags/Cause of Event (per Bay):',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          ..._selectedMultiBays.map((bay) {
                            if (!_bayFlagsControllers.containsKey(bay.id)) {
                              _bayFlagsControllers[bay.id] =
                                  TextEditingController(text: '');
                            }
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 16.0),
                              child: TextFormField(
                                controller: _bayFlagsControllers[bay.id],
                                decoration: InputDecoration(
                                  labelText: 'Flags/Cause for ${bay.name}',
                                  border: const OutlineInputBorder(),
                                  alignLabelWithHint: true,
                                ),
                                maxLines: 3,
                                enabled: isFormEnabled,
                                validator: (value) {
                                  if (isFlagsCauseMandatoryGlobal) {
                                    if (value == null || value.trim().isEmpty) {
                                      if (_selectedEventType == 'Shutdown') {
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
                        decoration: const InputDecoration(
                          labelText: 'Flags/Cause of Event',
                          border: OutlineInputBorder(),
                          alignLabelWithHint: true,
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
                    const SizedBox(height: 16),
                    Visibility(
                      visible: _showReasonForNonFeeder,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 16.0),
                        child: TextFormField(
                          controller: _reasonForNonFeederController,
                          decoration: const InputDecoration(
                            labelText:
                                'Reason for Tripping/Shutdown (Non-Feeder Bay)',
                            border: OutlineInputBorder(),
                          ),
                          maxLines: 2,
                          enabled: isFormEnabled,
                        ),
                      ),
                    ),
                    Visibility(
                      visible: _showHasAutoReclose,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 16.0),
                        child: SwitchListTile(
                          title: const Text('Auto-reclose (A/R) occurred'),
                          value: _hasAutoReclose,
                          onChanged: isFormEnabled
                              ? (bool value) =>
                                    setState(() => _hasAutoReclose = value)
                              : null,
                          secondary: const Icon(Icons.power_settings_new),
                        ),
                      ),
                    ),
                    Visibility(
                      visible: _showPhaseFaults,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Phase Faults:'),
                            Wrap(
                              spacing: 8.0,
                              children: _phaseFaultOptions.map((fault) {
                                bool isSelected = _selectedPhaseFaults.contains(
                                  fault,
                                );
                                return ChoiceChip(
                                  label: Text(fault),
                                  selected: isSelected,
                                  onSelected: isFormEnabled
                                      ? (selected) {
                                          setState(() {
                                            if (selected) {
                                              _selectedPhaseFaults.add(fault);
                                            } else {
                                              _selectedPhaseFaults.remove(
                                                fault,
                                              );
                                            }
                                          });
                                        }
                                      : null,
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Visibility(
                      visible: _showDistance,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 16.0),
                        child: TextFormField(
                          controller: _distanceController,
                          decoration: const InputDecoration(
                            labelText: 'Fault Distance (Km)',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.number,
                          enabled: isFormEnabled,
                        ),
                      ),
                    ),
                    Visibility(
                      visible: _selectedEventType == 'Shutdown',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          DropdownButtonFormField<String>(
                            decoration: const InputDecoration(
                              labelText: 'Shutdown Type',
                              border: OutlineInputBorder(),
                            ),
                            value: _selectedShutdownType,
                            items: _shutdownTypes.map((type) {
                              return DropdownMenuItem(
                                value: type,
                                child: Text(type),
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
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _shutdownPersonNameController,
                            decoration: const InputDecoration(
                              labelText: 'Name of Person Taking Shutdown',
                              border: OutlineInputBorder(),
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
                            decoration: const InputDecoration(
                              labelText:
                                  'Designation of Person Taking Shutdown',
                              border: OutlineInputBorder(),
                            ),
                            enabled: isFormEnabled,
                            validator: _selectedEventType == 'Shutdown'
                                ? (value) =>
                                      value == null || value.trim().isEmpty
                                      ? 'Designation is required'
                                      : null
                                : null,
                          ),
                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                    if (isEditingExisting && !isClosedEvent)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Divider(height: 32, thickness: 1),
                          Text(
                            'Close Event Details',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 16),
                          ListTile(
                            title: Text(
                              'End Date: ${_endDate != null ? DateFormat('yyyy-MM-dd').format(_endDate!) : 'Select Date'}',
                            ),
                            trailing: const Icon(Icons.calendar_today),
                            onTap: isFormEnabled
                                ? () => _selectDateTime(context, false)
                                : null,
                          ),
                          ListTile(
                            title: Text(
                              'End Time: ${_endTime != null ? _endTime!.format(context) : 'Select Time'}',
                            ),
                            trailing: const Icon(Icons.access_time),
                            onTap: isFormEnabled
                                ? () => _selectDateTime(context, false)
                                : null,
                          ),
                          const SizedBox(height: 16),
                        ],
                      ),
                    if (!isReadOnly)
                      Center(
                        child: _isSaving
                            ? const CircularProgressIndicator()
                            : ElevatedButton.icon(
                                onPressed: _saveEvent,
                                icon: Icon(
                                  isEditingExisting && !isClosedEvent
                                      ? Icons.check_circle_outline
                                      : Icons.save,
                                ),
                                label: Text(
                                  isEditingExisting && !isClosedEvent
                                      ? 'Close Event'
                                      : 'Create Event',
                                ),
                                style: ElevatedButton.styleFrom(
                                  minimumSize: const Size(double.infinity, 50),
                                ),
                              ),
                      ),
                    if (widget.isViewOnly || isClosedEvent)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Text(
                            widget.isViewOnly
                                ? 'This event is in view-only mode.'
                                : 'This event is already closed.',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  fontStyle: FontStyle.italic,
                                  color: Colors.grey.shade700,
                                ),
                          ),
                        ),
                      ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
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

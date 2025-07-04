// lib/screens/tripping_shutdown_entry_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:dropdown_search/dropdown_search.dart';

import '../../models/user_model.dart';
import '../../models/bay_model.dart';
import '../../models/tripping_shutdown_model.dart';
import '../../utils/snackbar_utils.dart';

class TrippingShutdownEntryScreen extends StatefulWidget {
  final String substationId;
  final AppUser currentUser;
  final TrippingShutdownEntry? entryToEdit;
  final bool isViewOnly; // This parameter determines view-only mode

  const TrippingShutdownEntryScreen({
    super.key,
    required this.substationId,
    required this.currentUser,
    this.entryToEdit,
    this.isViewOnly =
        false, // Default to false, allowing editing unless explicitly set true
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
  bool _isClosingEvent =
      false; // True if editing an existing OPEN entry to close it

  // Form Fields
  List<Bay> _selectedBays = []; // Now a list for multi-selection
  List<Bay> _baysInSubstation = []; // All bays available for selection
  String? _selectedEventType; // 'Tripping' or 'Shutdown'
  final TextEditingController _flagsCauseController = TextEditingController();
  final TextEditingController _reasonForNonFeederController =
      TextEditingController(); // Controller for the reason field
  DateTime? _startDate;
  TimeOfDay? _startTime;
  bool _hasAutoReclose = false;
  List<String> _selectedPhaseFaults = [];
  final TextEditingController _distanceController = TextEditingController();

  // For Closing Event
  DateTime? _endDate;
  TimeOfDay? _endTime;

  // Conditional field visibility flags based on selected bay properties
  bool _showAutoReclose = false;
  bool _showPhaseFaults = false;
  bool _showDistance = false;
  bool _showReasonForNonFeeder = false; // Flag for reason field visibility

  // Phase fault options
  final List<String> _phaseFaultOptions = ['Rph', 'Yph', 'Bph'];

  @override
  void initState() {
    super.initState();
    // Determine if we are in "closing an existing event" mode
    _isClosingEvent = widget.entryToEdit != null;
    _initializeForm();
  }

  @override
  void dispose() {
    _flagsCauseController.dispose();
    _reasonForNonFeederController.dispose();
    _distanceController.dispose();
    super.dispose();
  }

  Future<void> _initializeForm() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Fetch bays for the dropdown
      final baysSnapshot = await FirebaseFirestore.instance
          .collection('bays')
          .where('substationId', isEqualTo: widget.substationId)
          .orderBy('name')
          .get();
      _baysInSubstation = baysSnapshot.docs
          .map((doc) => Bay.fromFirestore(doc))
          .toList();

      if (_isClosingEvent) {
        // Populate form for existing entry (for closing or view-only)
        final entry = widget.entryToEdit!;
        // For closing/viewing, _selectedBays will only contain the specific bay of the entry
        _selectedBays = [
          _baysInSubstation.firstWhere((bay) => bay.id == entry.bayId),
        ];
        _selectedEventType = entry.eventType;
        _flagsCauseController.text = entry.flagsCause;
        _reasonForNonFeederController.text =
            entry.reasonForNonFeeder ?? ''; // Populate reason if it exists
        _startDate = entry.startTime.toDate();
        _startTime = TimeOfDay.fromDateTime(entry.startTime.toDate());
        _hasAutoReclose = entry.hasAutoReclose ?? false;
        _selectedPhaseFaults = entry.phaseFaults ?? [];
        _distanceController.text = entry.distance ?? '';

        // Only set end date/time if event is already closed (for view-only)
        if (entry.status == 'CLOSED') {
          _endDate = entry.endTime!.toDate();
          _endTime = TimeOfDay.fromDateTime(entry.endTime!.toDate());
        } else {
          // Default end time to now for closing mode (not view-only)
          _endDate = DateTime.now();
          _endTime = TimeOfDay.now();
        }

        // Update conditional visibility based on the loaded bay(s)
        _updateConditionalFields(_selectedBays);
      } else {
        // Default values for new entry
        _startDate = DateTime.now();
        _startTime = TimeOfDay.now();
        _selectedEventType = 'Tripping'; // Default event type
      }
    } catch (e) {
      print("Error initializing tripping/shutdown form: $e");
      if (mounted) {
        SnackBarUtils.showSnackBar(
          context,
          'Failed to load form data: $e',
          isError: true,
        );
        Navigator.of(context).pop(); // Go back if data fails to load
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // UPDATED: Logic for _showReasonForNonFeeder has changed here
  void _updateConditionalFields(List<Bay>? bays) {
    setState(() {
      _showAutoReclose = false;
      _showPhaseFaults = false;
      _showDistance = false;
      // _showReasonForNonFeeder will be determined by !widget.isViewOnly below

      if (bays != null && bays.isNotEmpty) {
        _showAutoReclose = bays.any((bay) {
          final voltageLevel =
              int.tryParse(bay.voltageLevel.replaceAll('kV', '')) ?? 0;
          return voltageLevel >= 220;
        });

        if (_selectedEventType == 'Tripping') {
          _showPhaseFaults = true;
        }

        _showDistance = bays.any((bay) => bay.bayType == 'Line');
      }

      // **CRITICAL CHANGE HERE:** Make the "Reason" field visible whenever the screen is not in view-only mode.
      _showReasonForNonFeeder = !widget.isViewOnly;
    });
  }

  Future<void> _selectDate(BuildContext context, bool isStart) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isStart
          ? (_startDate ?? DateTime.now())
          : (_endDate ?? DateTime.now()),
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(
        const Duration(days: 30),
      ), // Allow slight future for now
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
        } else {
          _endDate = picked;
        }
      });
    }
  }

  Future<void> _selectTime(BuildContext context, bool isStart) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: isStart
          ? (_startTime ?? TimeOfDay.now())
          : (_endTime ?? TimeOfDay.now()),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startTime = picked;
        } else {
          _endTime = picked;
        }
      });
    }
  }

  Future<void> _saveEvent() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedBays.isEmpty) {
      SnackBarUtils.showSnackBar(
        context,
        'Please select at least one Bay.',
        isError: true,
      );
      return;
    }
    if (_selectedEventType == null) {
      SnackBarUtils.showSnackBar(
        context,
        'Please select an Event Type.',
        isError: true,
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final String currentUserId = FirebaseAuth.instance.currentUser!.uid;
      Timestamp startTimestamp = Timestamp.fromDate(
        DateTime(
          _startDate!.year,
          _startDate!.month,
          _startDate!.day,
          _startTime!.hour,
          _startTime!.minute,
        ),
      );

      if (!widget.isViewOnly && widget.entryToEdit == null) {
        // Create New Event Mode
        for (Bay bay in _selectedBays) {
          // Reason is now generally mandatory if the field is visible/editable.
          if (_showReasonForNonFeeder &&
              _reasonForNonFeederController.text.trim().isEmpty) {
            SnackBarUtils.showSnackBar(
              context,
              'Reason is mandatory.', // Simplified message
              isError: true,
            );
            setState(() => _isSaving = false);
            return;
          }

          final newEntry = TrippingShutdownEntry(
            substationId: widget.substationId,
            bayId: bay.id, // Specific bay ID
            bayName: bay.name, // Specific bay name
            eventType: _selectedEventType!,
            startTime: startTimestamp,
            endTime: null, // Always null for new OPEN events
            status: 'OPEN',
            flagsCause: _flagsCauseController.text.trim(),
            // Save reason if field is visible (i.e., not view-only)
            reasonForNonFeeder:
                _showReasonForNonFeeder &&
                    _reasonForNonFeederController.text.trim().isNotEmpty
                ? _reasonForNonFeederController.text.trim()
                : null,
            hasAutoReclose: _showAutoReclose ? _hasAutoReclose : null,
            phaseFaults: _showPhaseFaults ? _selectedPhaseFaults : null,
            distance: _showDistance ? _distanceController.text.trim() : null,
            createdBy: currentUserId,
            createdAt: Timestamp.now(),
          );
          await FirebaseFirestore.instance
              .collection('trippingShutdownEntries')
              .add(newEntry.toFirestore());
        }
        if (mounted) {
          SnackBarUtils.showSnackBar(
            context,
            'New ${_selectedEventType} event(s) created successfully!',
          );
          Navigator.of(context).pop();
        }
      } else if (!widget.isViewOnly && widget.entryToEdit != null) {
        // Close/Edit Existing Event Mode
        if (_endDate == null || _endTime == null) {
          SnackBarUtils.showSnackBar(
            context,
            'Please select End Date and Time to close the event.',
            isError: true,
          );
          setState(() => _isSaving = false);
          return;
        }
        Timestamp endTimestamp = Timestamp.fromDate(
          DateTime(
            _endDate!.year,
            _endDate!.month,
            _endDate!.day,
            _endTime!.hour,
            _endTime!.minute,
          ),
        );

        if (endTimestamp.toDate().isBefore(startTimestamp.toDate())) {
          SnackBarUtils.showSnackBar(
            context,
            'End time cannot be before Start time.',
            isError: true,
          );
          setState(() => _isSaving = false);
          return;
        }

        // Reason is now generally mandatory if the field is visible/editable.
        if (_showReasonForNonFeeder &&
            _reasonForNonFeederController.text.trim().isEmpty) {
          SnackBarUtils.showSnackBar(
            context,
            'Reason is mandatory.', // Simplified message
            isError: true,
          );
          setState(() => _isSaving = false);
          return;
        }

        final updatedEntry = widget.entryToEdit!.copyWith(
          endTime: endTimestamp,
          status: 'CLOSED',
          closedBy: currentUserId,
          closedAt: Timestamp.now(),
          // Save reason if field is visible (i.e., not view-only)
          reasonForNonFeeder:
              _showReasonForNonFeeder &&
                  _reasonForNonFeederController.text.trim().isNotEmpty
              ? _reasonForNonFeederController.text.trim()
              : null,
        );
        await FirebaseFirestore.instance
            .collection('trippingShutdownEntries')
            .doc(updatedEntry.id)
            .update(updatedEntry.toFirestore());
        if (mounted) {
          SnackBarUtils.showSnackBar(
            context,
            '${updatedEntry.eventType} event closed successfully!',
          );
          Navigator.of(context).pop();
        }
      } else if (widget.isViewOnly && widget.entryToEdit != null) {
        // View Only Mode (no save operation)
        if (mounted) {
          Navigator.of(context).pop();
        }
      }
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
      setState(() {
        _isSaving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    String appBarTitle = 'New Tripping/Shutdown Event';
    if (widget.isViewOnly) {
      appBarTitle = 'Event Details';
    } else if (widget.entryToEdit != null) {
      appBarTitle = 'Close ${widget.entryToEdit!.eventType} Event';
    }

    return Scaffold(
      appBar: AppBar(title: Text(appBarTitle)),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Bay Selector (Read-only if viewOnly or closing event)
                    AbsorbPointer(
                      absorbing: widget.isViewOnly || _isClosingEvent,
                      child: DropdownSearch<Bay>.multiSelection(
                        popupProps: PopupPropsMultiSelection.menu(
                          showSearchBox: true,
                          menuProps: MenuProps(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          searchFieldProps: TextFieldProps(
                            decoration: InputDecoration(
                              labelText: 'Search Bay',
                              prefixIcon: const Icon(Icons.search),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ),
                        dropdownDecoratorProps: DropDownDecoratorProps(
                          dropdownSearchDecoration: InputDecoration(
                            labelText: 'Select Bay(s)',
                            hintText: 'Choose bay(s) for the event',
                            prefixIcon: const Icon(Icons.grid_on),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            filled: widget.isViewOnly || _isClosingEvent,
                            fillColor: (widget.isViewOnly || _isClosingEvent)
                                ? Colors.grey.shade100
                                : Theme.of(
                                    context,
                                  ).inputDecorationTheme.fillColor,
                          ),
                        ),
                        itemAsString: (Bay b) =>
                            '${b.name} (${b.voltageLevel})',
                        selectedItems: _selectedBays,
                        items: _baysInSubstation,
                        onChanged: (List<Bay> newValues) {
                          setState(() {
                            _selectedBays = newValues;
                            _updateConditionalFields(_selectedBays);
                          });
                        },
                        validator: (value) => value == null || value.isEmpty
                            ? 'Please select at least one Bay'
                            : null,
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Event Type (Read-only if viewOnly or closing event)
                    AbsorbPointer(
                      absorbing: widget.isViewOnly || _isClosingEvent,
                      child: DropdownButtonFormField<String>(
                        value: _selectedEventType,
                        decoration: InputDecoration(
                          labelText: 'Event Type',
                          prefixIcon: const Icon(Icons.event_note),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          filled: widget.isViewOnly || _isClosingEvent,
                          fillColor: (widget.isViewOnly || _isClosingEvent)
                              ? Colors.grey.shade100
                              : Theme.of(
                                  context,
                                ).inputDecorationTheme.fillColor,
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'Tripping',
                            child: Text('Tripping'),
                          ),
                          DropdownMenuItem(
                            value: 'Shutdown',
                            child: Text('Shutdown'),
                          ),
                        ],
                        onChanged: (newValue) {
                          setState(() {
                            _selectedEventType = newValue;
                            _updateConditionalFields(_selectedBays);
                          });
                        },
                        validator: (value) => value == null
                            ? 'Please select an Event Type'
                            : null,
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Start Date & Time (Read-only if viewOnly or closing event)
                    Text(
                      'Start Time & Date',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    AbsorbPointer(
                      absorbing: widget.isViewOnly || _isClosingEvent,
                      child: Column(
                        children: [
                          ListTile(
                            title: Text(
                              _startDate == null
                                  ? 'Select Start Date'
                                  : 'Date: ${DateFormat('yyyy-MM-dd').format(_startDate!)}',
                            ),
                            trailing: const Icon(Icons.calendar_today),
                            onTap: () => _selectDate(context, true),
                          ),
                          ListTile(
                            title: Text(
                              _startTime == null
                                  ? 'Select Start Time'
                                  : 'Time: ${_startTime!.format(context)}',
                            ),
                            trailing: const Icon(Icons.access_time),
                            onTap: () => _selectTime(context, true),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _flagsCauseController,
                      decoration: InputDecoration(
                        labelText: 'Flags / Cause',
                        hintText: 'Enter description, flags, cause of event',
                        prefixIcon: const Icon(Icons.flag),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        filled: widget.isViewOnly || _isClosingEvent,
                        fillColor: (widget.isViewOnly || _isClosingEvent)
                            ? Colors.grey.shade100
                            : Theme.of(context).inputDecorationTheme.fillColor,
                      ),
                      maxLines: 3,
                      readOnly: widget.isViewOnly || _isClosingEvent,
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                          ? 'Flags/Cause is mandatory'
                          : null,
                    ),
                    const SizedBox(height: 16),

                    // Conditional fields (Auto-reclose, Phase Faults, Distance)
                    if (_showAutoReclose)
                      AbsorbPointer(
                        absorbing: widget.isViewOnly || _isClosingEvent,
                        child: SwitchListTile(
                          title: const Text('Auto-reclose'),
                          value: _hasAutoReclose,
                          onChanged: (value) {
                            setState(() {
                              _hasAutoReclose = value;
                            });
                          },
                          secondary: const Icon(Icons.autorenew),
                        ),
                      ),
                    if (_showPhaseFaults)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Phase Faults',
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          const SizedBox(height: 8),
                          AbsorbPointer(
                            absorbing: widget.isViewOnly || _isClosingEvent,
                            child: Wrap(
                              spacing: 8.0,
                              children: _phaseFaultOptions.map((fault) {
                                return ChoiceChip(
                                  label: Text(fault),
                                  selected: _selectedPhaseFaults.contains(
                                    fault,
                                  ),
                                  onSelected: (selected) {
                                    setState(() {
                                      if (selected) {
                                        _selectedPhaseFaults.add(fault);
                                      } else {
                                        _selectedPhaseFaults.remove(fault);
                                      }
                                    });
                                  },
                                );
                              }).toList(),
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                      ),
                    if (_showDistance)
                      TextFormField(
                        controller: _distanceController,
                        decoration: InputDecoration(
                          labelText: 'Distance (in Km)',
                          hintText: 'Enter fault distance if applicable',
                          prefixIcon: const Icon(Icons.straighten),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          filled: widget.isViewOnly || _isClosingEvent,
                          fillColor: (widget.isViewOnly || _isClosingEvent)
                              ? Colors.grey.shade100
                              : Theme.of(
                                  context,
                                ).inputDecorationTheme.fillColor,
                        ),
                        keyboardType: TextInputType.number,
                        readOnly: widget.isViewOnly || _isClosingEvent,
                      ),
                    const SizedBox(height: 32),

                    // --- Closing Event Fields ---
                    if (_isClosingEvent || widget.isViewOnly) ...[
                      // Show end time if closing or view-only
                      Text(
                        'End Time & Date',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      AbsorbPointer(
                        absorbing:
                            widget.isViewOnly ||
                            (widget.entryToEdit != null &&
                                widget.entryToEdit!.status ==
                                    'CLOSED'), // Absorb if view only or already closed
                        child: Column(
                          children: [
                            ListTile(
                              title: Text(
                                widget.entryToEdit!.status == 'CLOSED'
                                    ? 'Date: ${DateFormat('yyyy-MM-dd').format(widget.entryToEdit!.endTime!.toDate())}'
                                    : (_endDate == null
                                          ? 'Select End Date'
                                          : 'Date: ${DateFormat('yyyy-MM-dd').format(_endDate!)}'),
                              ),
                              trailing: const Icon(Icons.calendar_today),
                              onTap: () => _selectDate(context, false),
                            ),
                            ListTile(
                              title: Text(
                                widget.entryToEdit!.status == 'CLOSED'
                                    ? 'Time: ${TimeOfDay.fromDateTime(widget.entryToEdit!.endTime!.toDate()).format(context)}'
                                    : (_endTime == null
                                          ? 'Select End Time'
                                          : 'Time: ${_endTime!.format(context)}'),
                              ),
                              trailing: const Icon(Icons.access_time),
                              onTap: () => _selectTime(context, false),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16), // Added spacing
                      // **MOVED & UPDATED:** Reason for Tripping/Shutdown Text Field - New position
                      if (_showReasonForNonFeeder) // This will now be true if not in view-only mode
                        Padding(
                          // Add padding around the field if needed for spacing
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          child: TextFormField(
                            controller: _reasonForNonFeederController,
                            decoration: InputDecoration(
                              labelText: 'Reason for Tripping/Shutdown',
                              hintText: 'Enter reason for the event',
                              prefixIcon: const Icon(Icons.info_outline),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              // Field will be filled and read-only if in view-only mode or event is already CLOSED
                              filled:
                                  widget.isViewOnly ||
                                  (widget.entryToEdit != null &&
                                      widget.entryToEdit!.status == 'CLOSED'),
                              fillColor:
                                  (widget.isViewOnly ||
                                      (widget.entryToEdit != null &&
                                          widget.entryToEdit!.status ==
                                              'CLOSED'))
                                  ? Colors.grey.shade100
                                  : Theme.of(
                                      context,
                                    ).inputDecorationTheme.fillColor,
                            ),
                            maxLines: 3,
                            // Field will be read-only if in view-only mode or event is already CLOSED
                            readOnly:
                                widget.isViewOnly ||
                                (widget.entryToEdit != null &&
                                    widget.entryToEdit!.status == 'CLOSED'),
                            validator: (value) {
                              // Validator runs ONLY if the field is NOT read-only
                              if (!(widget.isViewOnly ||
                                      (widget.entryToEdit != null &&
                                          widget.entryToEdit!.status ==
                                              'CLOSED')) &&
                                  (value == null || value.trim().isEmpty)) {
                                return 'Reason is mandatory.'; // Simplified message for all cases
                              }
                              return null;
                            },
                          ),
                        ),
                      const SizedBox(height: 32),
                    ],

                    // Only show save button if not in view-only mode and not already closed
                    if (!widget.isViewOnly &&
                        !(widget.entryToEdit != null &&
                            widget.entryToEdit!.status == 'CLOSED'))
                      Center(
                        child: _isSaving
                            ? const CircularProgressIndicator()
                            : ElevatedButton.icon(
                                onPressed: _saveEvent,
                                icon: Icon(
                                  _isClosingEvent ? Icons.flash_on : Icons.add,
                                ),
                                label: Text(
                                  _isClosingEvent
                                      ? 'Close Event'
                                      : 'Create Event',
                                ),
                                style: ElevatedButton.styleFrom(
                                  minimumSize: const Size(double.infinity, 50),
                                ),
                              ),
                      ),
                    // Message for view-only or already closed events
                    if (widget.isViewOnly ||
                        (widget.entryToEdit != null &&
                            widget.entryToEdit!.status == 'CLOSED'))
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

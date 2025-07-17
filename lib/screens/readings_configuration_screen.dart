// lib/screens/readings_configuration_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dropdown_search/dropdown_search.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';
import '../models/bay_model.dart';
import '../models/hierarchy_models.dart';
import '../utils/snackbar_utils.dart';
import '../models/user_readings_config_model.dart'; // Correct import for UserReadingsConfig
import '../models/reading_models.dart'; // Import ReadingField and ReadingTemplate

class ReadingConfigurationScreen extends StatefulWidget {
  // Corrected class name
  final AppUser currentUser;
  final String subdivisionId;

  const ReadingConfigurationScreen({
    Key? key,
    required this.currentUser,
    required this.subdivisionId,
  }) : super(key: key);

  @override
  State<ReadingConfigurationScreen>
  createState() => // Corrected state class name
      _ReadingConfigurationScreenState();
}

class _ReadingConfigurationScreenState
    extends State<ReadingConfigurationScreen> {
  bool _isLoading = true;
  bool _isSaving = false;

  final TextEditingController _durationValueController =
      TextEditingController();
  String _selectedDurationUnit = 'hours'; // Default unit
  final List<String> _durationUnits = ['hours', 'days', 'weeks', 'months'];

  List<ConfiguredBayReading> _configuredReadings = [];
  List<Substation> _substationsInSubdivision = [];
  List<Bay> _baysInSelectedSubstations = [];

  Map<String, List<String>> _bayToAvailableReadingFields = {};

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  @override
  void dispose() {
    _durationValueController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      // 1. Fetch available substations in this subdivision
      final substationsSnapshot = await FirebaseFirestore.instance
          .collection('substations')
          .where('subdivisionId', isEqualTo: widget.subdivisionId)
          .orderBy('name')
          .get();
      _substationsInSubdivision = substationsSnapshot.docs
          .map((doc) => Substation.fromFirestore(doc))
          .toList();

      // 2. Load existing user configuration
      final configDoc = await FirebaseFirestore.instance
          .collection('userReadingsConfigurations')
          .doc(widget.currentUser.uid)
          .get();

      if (configDoc.exists) {
        final existingConfig = UserReadingsConfig.fromFirestore(configDoc);
        _durationValueController.text = existingConfig.durationValue.toString();
        _selectedDurationUnit = existingConfig.durationUnit;
        _configuredReadings = existingConfig.configuredReadings;

        final preConfiguredBayIds = _configuredReadings
            .map((e) => e.bayId)
            .toSet()
            .toList();
        if (preConfiguredBayIds.isNotEmpty) {
          List<Bay> initialBays = [];
          for (int i = 0; i < preConfiguredBayIds.length; i += 10) {
            final chunk = preConfiguredBayIds.sublist(
              i,
              i + 10 > preConfiguredBayIds.length
                  ? preConfiguredBayIds.length
                  : i + 10,
            );
            if (chunk.isEmpty) continue;
            final baysSnapshot = await FirebaseFirestore.instance
                .collection('bays')
                .where(FieldPath.documentId, whereIn: chunk)
                .get();
            initialBays.addAll(
              baysSnapshot.docs.map((doc) => Bay.fromFirestore(doc)).toList(),
            );
          }
          _baysInSelectedSubstations = initialBays;
          await _fetchReadingFieldsForBays(_baysInSelectedSubstations);
        }
      } else {
        // Default values for new configuration
        _durationValueController.text = ''; // No default value
        _selectedDurationUnit = 'hours'; // Default unit
        _configuredReadings = [];
      }
    } catch (e) {
      print("Error loading readings configuration: $e");
      if (mounted) {
        SnackBarUtils.showSnackBar(
          context,
          'Failed to load configuration: $e',
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchReadingFieldsForBays(List<Bay> bays) async {
    Map<String, List<String>> tempBayToAvailableReadingFields = {};
    for (Bay bay in bays) {
      final assignmentSnapshot = await FirebaseFirestore.instance
          .collection('bayReadingAssignments')
          .where('bayId', isEqualTo: bay.id)
          .limit(1)
          .get();

      if (assignmentSnapshot.docs.isNotEmpty) {
        // Assuming BayReadingAssignment is defined elsewhere and has a readingTemplateId
        final assignment =
            assignmentSnapshot.docs.first.data() as Map<String, dynamic>;
        final String templateId = assignment['templateId'] as String;

        final templateDoc = await FirebaseFirestore.instance
            .collection('readingTemplates')
            .doc(templateId)
            .get();

        if (templateDoc.exists) {
          final readingTemplate = ReadingTemplate.fromFirestore(templateDoc);
          tempBayToAvailableReadingFields[bay.id] = readingTemplate
              .readingFields
              .map((field) => field.name)
              .toList();
        } else {
          print(
            "Warning: ReadingTemplate not found for bay ${bay.id} and template ID $templateId",
          );
          tempBayToAvailableReadingFields[bay.id] = [];
        }
      } else {
        print("Warning: No BayReadingAssignment found for bay ${bay.id}");
        tempBayToAvailableReadingFields[bay.id] = [];
      }
    }
    if (mounted) {
      setState(() {
        _bayToAvailableReadingFields = tempBayToAvailableReadingFields;
      });
    }
  }

  Future<void> _saveConfiguration() async {
    if (_durationValueController.text.isEmpty ||
        int.tryParse(_durationValueController.text) == null) {
      SnackBarUtils.showSnackBar(
        context,
        'Please enter a valid duration value.',
        isError: true,
      );
      return;
    }
    int durationValue = int.parse(_durationValueController.text);

    setState(() => _isSaving = true);
    try {
      final String userId = widget.currentUser.uid;
      final configRef = FirebaseFirestore.instance
          .collection('userReadingsConfigurations')
          .doc(userId);

      String inferredReadingGranularity;
      if (_selectedDurationUnit == 'hours') {
        inferredReadingGranularity = 'hourly';
      } else {
        inferredReadingGranularity = 'daily';
      }

      final newConfig = UserReadingsConfig(
        userId: userId,
        readingGranularity: inferredReadingGranularity,
        durationValue: durationValue,
        durationUnit: _selectedDurationUnit,
        configuredReadings: _configuredReadings,
        createdAt: (await configRef.get()).exists
            ? (await configRef.get()).data()!['createdAt'] ?? Timestamp.now()
            : Timestamp.now(),
        updatedAt: Timestamp.now(),
      );

      await configRef.set(newConfig.toFirestore());

      if (mounted) {
        SnackBarUtils.showSnackBar(
          context,
          'Readings configuration saved successfully!',
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      print("Error saving readings configuration: $e");
      if (mounted) {
        SnackBarUtils.showSnackBar(
          context,
          'Failed to save configuration: $e',
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _fetchBaysForSubstations(List<String> substationIds) async {
    if (!mounted) return;

    if (substationIds.isEmpty) {
      setState(() {
        _baysInSelectedSubstations = [];
        _configuredReadings = [];
        _bayToAvailableReadingFields = {};
      });
      return;
    }

    List<Bay> fetchedBays = [];
    for (int i = 0; i < substationIds.length; i += 10) {
      final chunk = substationIds.sublist(
        i,
        i + 10 > substationIds.length ? substationIds.length : i + 10,
      );
      if (chunk.isEmpty) continue;

      final baysSnapshot = await FirebaseFirestore.instance
          .collection('bays')
          .where('substationId', whereIn: chunk)
          .get();
      fetchedBays.addAll(
        baysSnapshot.docs.map((doc) => Bay.fromFirestore(doc)).toList(),
      );
    }

    if (mounted) {
      setState(() {
        _baysInSelectedSubstations = fetchedBays;
        _configuredReadings.retainWhere(
          (cbr) => fetchedBays.any((bay) => bay.id == cbr.bayId),
        );
      });
      await _fetchReadingFieldsForBays(fetchedBays);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Readings Configuration')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Data Duration',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: TextFormField(
                          controller: _durationValueController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'Back duration',
                            hintText: 'e.g., 48',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          validator: (value) {
                            if (value == null ||
                                value.isEmpty ||
                                int.tryParse(value) == null) {
                              return 'Enter a number';
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 3,
                        child: DropdownButtonFormField<String>(
                          value: _selectedDurationUnit,
                          decoration: InputDecoration(
                            labelText: 'Unit',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          items: _durationUnits.map((String unit) {
                            return DropdownMenuItem<String>(
                              value: unit,
                              child: Text(unit),
                            );
                          }).toList(),
                          onChanged: (String? newValue) {
                            setState(() {
                              _selectedDurationUnit = newValue!;
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                  const Divider(),
                  const SizedBox(height: 16),

                  Text(
                    'Select Substations & Bays',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  DropdownSearch<Substation>.multiSelection(
                    popupProps: PopupPropsMultiSelection.menu(
                      showSearchBox: true,
                      menuProps: MenuProps(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    dropdownDecoratorProps: DropDownDecoratorProps(
                      dropdownSearchDecoration: InputDecoration(
                        labelText: 'Select Substation(s)',
                        hintText: 'Choose substations to view bays from',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    itemAsString: (Substation s) => s.name,
                    selectedItems: _substationsInSubdivision
                        .where(
                          (s) => _configuredReadings.any(
                            (cbr) => cbr.substationId == s.id,
                          ),
                        )
                        .toList(),
                    items: _substationsInSubdivision,
                    onChanged: (List<Substation> selectedSubstations) {
                      _fetchBaysForSubstations(
                        selectedSubstations.map((s) => s.id).toList(),
                      );
                    },
                    validator: (value) => value == null || value.isEmpty
                        ? 'Please select at least one Substation'
                        : null,
                  ),
                  const SizedBox(height: 16),

                  if (_baysInSelectedSubstations.isNotEmpty)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: _baysInSelectedSubstations.map((bay) {
                        // Find existing configuration for this bay
                        ConfiguredBayReading? currentConfig =
                            _configuredReadings.firstWhereOrNull(
                              (cbr) => cbr.bayId == bay.id,
                            );
                        List<String> availableFieldsForBay =
                            _bayToAvailableReadingFields[bay.id] ?? [];

                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 8.0),
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Bay: ${bay.name} (${bay.voltageLevel})',
                                  style: Theme.of(context).textTheme.titleSmall,
                                ),
                                if (availableFieldsForBay.isEmpty)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 8.0,
                                    ),
                                    child: Text(
                                      'No reading template fields found for this bay. Please assign one via Bay Reading Assignment Screen.',
                                      style: TextStyle(
                                        fontStyle: FontStyle.italic,
                                        color: Colors.red[700],
                                      ),
                                    ),
                                  ),
                                if (availableFieldsForBay.isNotEmpty)
                                  DropdownSearch<String>.multiSelection(
                                    popupProps: PopupPropsMultiSelection.menu(
                                      showSearchBox: true,
                                      menuProps: MenuProps(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    ),
                                    dropdownDecoratorProps: DropDownDecoratorProps(
                                      dropdownSearchDecoration: InputDecoration(
                                        labelText:
                                            'Select Readings for ${bay.name}',
                                        hintText: 'Choose reading parameters',
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                      ),
                                    ),
                                    itemAsString: (String s) => s,
                                    selectedItems:
                                        currentConfig?.readingFields ?? [],
                                    items: availableFieldsForBay,
                                    onChanged: (List<String> selectedFields) {
                                      setState(() {
                                        if (selectedFields.isEmpty) {
                                          _configuredReadings.removeWhere(
                                            (cbr) => cbr.bayId == bay.id,
                                          );
                                        } else {
                                          final newConfig =
                                              ConfiguredBayReading(
                                                bayId: bay.id,
                                                bayName: bay.name,
                                                substationId: bay.substationId,
                                                substationName:
                                                    _substationsInSubdivision
                                                        .firstWhere(
                                                          (s) =>
                                                              s.id ==
                                                              bay.substationId,
                                                        )
                                                        .name,
                                                readingFields: selectedFields,
                                              );
                                          int existingIndex =
                                              _configuredReadings.indexWhere(
                                                (cbr) => cbr.bayId == bay.id,
                                              );
                                          if (existingIndex != -1) {
                                            _configuredReadings[existingIndex] =
                                                newConfig;
                                          } else {
                                            _configuredReadings.add(newConfig);
                                          }
                                        }
                                      });
                                    },
                                  ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  const SizedBox(height: 32),

                  Center(
                    child: _isSaving
                        ? const CircularProgressIndicator()
                        : ElevatedButton.icon(
                            onPressed: _saveConfiguration,
                            icon: const Icon(Icons.save),
                            label: const Text('Save Configuration'),
                            style: ElevatedButton.styleFrom(
                              minimumSize: const Size(double.infinity, 50),
                            ),
                          ),
                  ),
                ],
              ),
            ),
    );
  }
}

// Extension to help find firstWhereOrNull for List (Moved from previous readings_configuration_screen.dart content)
extension ListExtension<T> on List<T> {
  T? firstWhereOrNull(bool Function(T element) test) {
    for (var element in this) {
      if (test(element)) return element;
    }
    return null;
  }
}

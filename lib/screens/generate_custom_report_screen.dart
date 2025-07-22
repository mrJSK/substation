// lib/screens/generate_custom_report_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:open_filex/open_filex.dart';

import '../models/app_state_data.dart'; // Ensure correct path
import '../models/report_template_model.dart'; // Ensure correct path
import '../models/logsheet_models.dart'; // Ensure correct path
import '../models/bay_model.dart'; // Ensure correct path
import '../models/reading_models.dart'; // Ensure correct path
import '../models/user_model.dart'; // Ensure correct path
import '../utils/snackbar_utils.dart'; // Ensure correct path

class GenerateCustomReportScreen extends StatefulWidget {
  static const routeName = '/generate-custom-report';

  const GenerateCustomReportScreen({super.key});

  @override
  State<GenerateCustomReportScreen> createState() =>
      _GenerateCustomReportScreenState();
}

class _GenerateCustomReportScreenState
    extends State<GenerateCustomReportScreen> {
  List<ReportTemplate> _availableTemplates = [];
  ReportTemplate? _selectedTemplate;
  bool _isLoading = false;

  ReportFrequency _selectedPeriodType = ReportFrequency.daily;
  DateTime _fromDate = DateTime.now().subtract(const Duration(days: 7));
  DateTime _toDate = DateTime.now();

  List<ReadingField> _availableReadingFields = [];

  @override
  void initState() {
    super.initState();
    _fetchInitialData();
  }

  Future<void> _fetchInitialData() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final appState = Provider.of<AppStateData>(context, listen: false);
      final currentUserUid = appState.currentUser?.uid;
      final selectedSubstationId = appState.selectedSubstation?.id;

      if (currentUserUid == null || selectedSubstationId == null) {
        if (mounted)
          SnackBarUtils.showSnackBar(
            context,
            'User not logged in or no substation selected. Please log in and select a substation from the dashboard.',
          );
        setState(() {
          _isLoading = false;
        });
        return;
      }

      // Fetch Report Templates
      final templateQuerySnapshot = await FirebaseFirestore.instance
          .collection('reportTemplates')
          .where('createdByUid', isEqualTo: currentUserUid)
          .where('substationId', isEqualTo: selectedSubstationId)
          .get();

      // FIX: Use ReportTemplate.fromFirestore
      _availableTemplates = templateQuerySnapshot.docs
          .map((doc) => ReportTemplate.fromFirestore(doc))
          .toList();

      if (_availableTemplates.isNotEmpty) {
        _selectedTemplate = _availableTemplates.first;
        _selectedPeriodType = _selectedTemplate!.frequency;
      }

      // Fetch all Reading Templates and extract unique ReadingFields
      final readingTemplateDocs = await FirebaseFirestore.instance
          .collection('readingTemplates')
          .get();
      List<ReadingTemplate> allReadingTemplates = readingTemplateDocs.docs
          .map((doc) => ReadingTemplate.fromFirestore(doc))
          .toList();

      Set<ReadingField> uniqueReadingFields = {};
      for (var template in allReadingTemplates) {
        for (var field in template.readingFields) {
          // Use 'name' for identifying unique fields, and check if it's not empty
          if (field.name.isNotEmpty && field.dataType != null) {
            uniqueReadingFields.add(field);
          }
        }
      }
      _availableReadingFields = uniqueReadingFields.toList();
      // FIX: Sort by 'name' as 'fieldName' doesn't exist
      _availableReadingFields.sort((a, b) => a.name.compareTo(b.name));
    } catch (e) {
      if (mounted)
        SnackBarUtils.showSnackBar(context, 'Error fetching data: $e');
      print('Error fetching initial data for GenerateCustomReportScreen: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _selectDate(BuildContext context, bool isFrom) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isFrom ? _fromDate : _toDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    if (picked != null) {
      if (!mounted) return;
      setState(() {
        if (isFrom) {
          _fromDate = picked;
        } else {
          _toDate = picked;
        }
      });
    }
  }

  // --- Core Excel Generation Logic ---
  Future<void> _generateExcelReport() async {
    if (_selectedTemplate == null) {
      SnackBarUtils.showSnackBar(context, 'Please select a report template.');
      return;
    }
    if (_selectedPeriodType == ReportFrequency.custom &&
        _fromDate.isAfter(_toDate)) {
      SnackBarUtils.showSnackBar(
        context,
        'From Date cannot be after To Date for custom period.',
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final appState = Provider.of<AppStateData>(context, listen: false);
      final selectedSubstation = appState.selectedSubstation;
      if (selectedSubstation == null) {
        SnackBarUtils.showSnackBar(
          context,
          'No substation selected. Cannot generate report.',
        );
        return;
      }

      // 1. Fetch Bay details for selected bays
      Map<String, Bay> baysMap = {};
      if (_selectedTemplate!.selectedBayIds.isNotEmpty) {
        for (int i = 0; i < _selectedTemplate!.selectedBayIds.length; i += 10) {
          final chunk = _selectedTemplate!.selectedBayIds.sublist(
            i,
            i + 10 > _selectedTemplate!.selectedBayIds.length
                ? _selectedTemplate!.selectedBayIds.length
                : i + 10,
          );
          final bayDocs = await FirebaseFirestore.instance
              .collection('bays')
              .where(FieldPath.documentId, whereIn: chunk)
              .get();
          for (var doc in bayDocs.docs) {
            // FIX: Use fromFirestore constructor for Bay
            baysMap[doc.id] = Bay.fromFirestore(doc);
          }
        }
      } else {
        SnackBarUtils.showSnackBar(
          context,
          'Selected template has no bays. Please edit the template to include bays.',
        );
        return;
      }

      // 2. Determine date range for logsheet query based on selected period type
      DateTime queryStartDate = _fromDate;
      DateTime queryEndDate = _toDate;

      // Adjust dates to cover entire period
      if (_selectedPeriodType == ReportFrequency.hourly) {
        queryStartDate = DateTime(
          queryStartDate.year,
          queryStartDate.month,
          queryStartDate.day,
          queryStartDate.hour,
        );
        queryEndDate = DateTime(
          queryEndDate.year,
          queryEndDate.month,
          queryEndDate.day,
          queryEndDate.hour,
          59,
          59,
        );
      } else {
        // Daily or Custom
        queryStartDate = DateTime(
          queryStartDate.year,
          queryStartDate.month,
          queryStartDate.day,
        );
        queryEndDate = DateTime(
          queryEndDate.year,
          queryEndDate.month,
          queryEndDate.day,
          23,
          59,
          59,
        );
      }

      // 3. Fetch all relevant LogsheetEntries
      List<LogsheetEntry> allReadings = [];
      final List<String> bayIdsToQuery = _selectedTemplate!.selectedBayIds;

      if (bayIdsToQuery.isNotEmpty) {
        for (int i = 0; i < bayIdsToQuery.length; i += 10) {
          // Firebase whereIn limit
          final chunk = bayIdsToQuery.sublist(
            i,
            i + 10 > bayIdsToQuery.length ? bayIdsToQuery.length : i + 10,
          );

          final logsheetSnapshot = await FirebaseFirestore.instance
              .collection('logsheetEntries')
              .where('bayId', whereIn: chunk)
              .where(
                'frequency',
                isEqualTo: _selectedTemplate!.frequency.toShortString(),
              ) // Use template's frequency for fetching
              .where(
                'readingTimestamp',
                isGreaterThanOrEqualTo: Timestamp.fromDate(queryStartDate),
              )
              .where(
                'readingTimestamp',
                isLessThanOrEqualTo: Timestamp.fromDate(queryEndDate),
              ) // Corrected to use queryEndDate directly after adjustment
              .orderBy('readingTimestamp')
              .get();

          allReadings.addAll(
            logsheetSnapshot.docs
                .map((doc) => LogsheetEntry.fromFirestore(doc))
                .toList(),
          );
        }
      } else {
        SnackBarUtils.showSnackBar(
          context,
          'No bays selected in the template for data retrieval.',
        );
        return;
      }

      // Sort all readings by timestamp and then by bay name for consistent reporting
      allReadings.sort((a, b) {
        int timestampCompare = a.readingTimestamp.compareTo(b.readingTimestamp);
        if (timestampCompare != 0) return timestampCompare;
        final bayA = baysMap[a.bayId]?.name ?? '';
        final bayB = baysMap[b.bayId]?.name ?? '';
        return bayA.compareTo(bayB);
      });

      // 4. Group data for aggregation (if needed based on frequency)
      Map<String, Map<String, List<LogsheetEntry>>> groupedData =
          {}; // Key: "YYYY-MM-DD" or "YYYY-MM-DD HH", Value: {BayId: List<LogsheetEntry>}
      for (var entry in allReadings) {
        String periodKey;
        if (_selectedPeriodType == ReportFrequency.hourly) {
          periodKey = DateFormat(
            'yyyy-MM-dd HH',
          ).format(entry.readingTimestamp.toDate());
        } else {
          periodKey = DateFormat(
            'yyyy-MM-dd',
          ).format(entry.readingTimestamp.toDate());
        }
        groupedData.putIfAbsent(periodKey, () => {});
        groupedData[periodKey]!.putIfAbsent(entry.bayId, () => []).add(entry);
      }

      // 5. Prepare Excel workbook and sheet
      var excel = Excel.createExcel();
      Sheet sheetObject = excel['Report for ${selectedSubstation.name}'];

      // Construct Header Row - FIX: Convert to TextCellValue
      List<CellValue> headerCells = [
        TextCellValue('Date/Time'),
        TextCellValue('Bay Name'),
      ];
      for (var fieldName in _selectedTemplate!.selectedReadingFieldIds) {
        final fieldDef = _availableReadingFields.firstWhere(
          (f) => f.name == fieldName, // Use 'name' here
          orElse: () => ReadingField(
            name: fieldName,
            dataType: ReadingFieldDataType.text,
          ), // Fallback with name
        );
        headerCells.add(
          TextCellValue(
            '${fieldDef.name} ${fieldDef.unit != null && fieldDef.unit!.isNotEmpty ? '(${fieldDef.unit})' : ''}',
          ),
        );
      }
      for (var customCol in _selectedTemplate!.customColumns) {
        headerCells.add(TextCellValue(customCol.columnName));
      }
      sheetObject.appendRow(headerCells); // Append the list of CellValue

      // 6. Populate Data Rows
      List<String> sortedPeriodKeys = groupedData.keys.toList()..sort();

      for (String periodKey in sortedPeriodKeys) {
        List<String> sortedBayIds = groupedData[periodKey]!.keys.toList()
          ..sort(
            (a, b) =>
                (baysMap[a]?.name ?? '').compareTo(baysMap[b]?.name ?? ''),
          );

        for (String bayId in sortedBayIds) {
          final entriesForPeriodBay = groupedData[periodKey]![bayId]!;
          final currentBay = baysMap[bayId];

          // FIX: Convert data to CellValue for each cell
          List<CellValue> rowCells = [
            TextCellValue(periodKey),
            TextCellValue(currentBay?.name ?? 'Unknown Bay'),
          ];

          for (var fieldName in _selectedTemplate!.selectedReadingFieldIds) {
            dynamic value;
            List<double> numericValues = entriesForPeriodBay
                .map(
                  (e) => double.tryParse(e.values[fieldName]?.toString() ?? ''),
                )
                .whereType<double>()
                .toList();

            if (numericValues.isNotEmpty) {
              if (_selectedPeriodType == ReportFrequency.hourly) {
                value = numericValues.first;
              } else {
                value =
                    numericValues.reduce((a, b) => a + b) /
                    numericValues.length;
              }
            } else {
              value = null;
            }
            // Use DoubleCellValue for numbers, TextCellValue for others or null
            if (value is double) {
              rowCells.add(
                DoubleCellValue(double.parse(value.toStringAsFixed(2))),
              ); // Round and convert to DoubleCellValue
            } else {
              rowCells.add(TextCellValue(value?.toString() ?? ''));
            }
          }

          for (var customCol in _selectedTemplate!.customColumns) {
            double? calculatedValue;

            final baseReadingFieldDef = _availableReadingFields.firstWhere(
              (field) => field.name == customCol.baseReadingFieldId,
              orElse: () => ReadingField(
                name: customCol.baseReadingFieldId,
                dataType: ReadingFieldDataType.text,
              ),
            );

            final secondaryReadingFieldDef =
                customCol.secondaryReadingFieldId != null
                ? _availableReadingFields.firstWhere(
                    (field) => field.name == customCol.secondaryReadingFieldId,
                    orElse: () => ReadingField(
                      name: customCol.secondaryReadingFieldId!,
                      dataType: ReadingFieldDataType.text,
                    ),
                  )
                : null;

            if (baseReadingFieldDef.dataType == ReadingFieldDataType.number) {
              List<double> baseValues = entriesForPeriodBay
                  .map(
                    (e) => double.tryParse(
                      e.values[customCol.baseReadingFieldId]?.toString() ?? '',
                    ),
                  )
                  .whereType<double>()
                  .toList();

              List<double> secondaryValues = [];
              if (secondaryReadingFieldDef != null &&
                  secondaryReadingFieldDef.dataType ==
                      ReadingFieldDataType.number) {
                secondaryValues = entriesForPeriodBay
                    .map(
                      (e) => double.tryParse(
                        e.values[customCol.secondaryReadingFieldId!]
                                ?.toString() ??
                            '',
                      ),
                    )
                    .whereType<double>()
                    .toList();
              }

              double? operandValue;
              if (customCol.operandValue != null) {
                operandValue = double.tryParse(customCol.operandValue!);
              }

              double? aggregatedBaseValue;
              if (baseValues.isNotEmpty) {
                if (_selectedPeriodType == ReportFrequency.hourly) {
                  aggregatedBaseValue = baseValues.first;
                } else {
                  aggregatedBaseValue =
                      baseValues.reduce((a, b) => a + b) / baseValues.length;
                }
              }

              double? aggregatedSecondaryValue;
              if (secondaryValues.isNotEmpty) {
                if (_selectedPeriodType == ReportFrequency.hourly) {
                  aggregatedSecondaryValue = secondaryValues.first;
                } else {
                  aggregatedSecondaryValue =
                      secondaryValues.reduce((a, b) => a + b) /
                      secondaryValues.length;
                }
              }

              if (aggregatedBaseValue != null) {
                switch (customCol.operation) {
                  case MathOperation.max:
                    calculatedValue = baseValues.reduce(
                      (curr, next) => curr > next ? curr : next,
                    );
                    break;
                  case MathOperation.min:
                    calculatedValue = baseValues.reduce(
                      (curr, next) => curr < next ? curr : next,
                    );
                    break;
                  case MathOperation.sum:
                    calculatedValue = baseValues.reduce(
                      (curr, next) => curr + next,
                    );
                    break;
                  case MathOperation.average:
                    calculatedValue =
                        baseValues.reduce((curr, next) => curr + next) /
                        baseValues.length;
                    break;
                  case MathOperation.add:
                    if (aggregatedSecondaryValue != null) {
                      calculatedValue =
                          aggregatedBaseValue + aggregatedSecondaryValue;
                    } else if (operandValue != null) {
                      calculatedValue = aggregatedBaseValue + operandValue;
                    }
                    break;
                  case MathOperation.subtract:
                    if (aggregatedSecondaryValue != null) {
                      calculatedValue =
                          aggregatedBaseValue - aggregatedSecondaryValue;
                    } else if (operandValue != null) {
                      calculatedValue = aggregatedBaseValue - operandValue;
                    }
                    break;
                  case MathOperation.multiply:
                    if (aggregatedSecondaryValue != null) {
                      calculatedValue =
                          aggregatedBaseValue * aggregatedSecondaryValue;
                    } else if (operandValue != null) {
                      calculatedValue = aggregatedBaseValue * operandValue;
                    }
                    break;
                  case MathOperation.divide:
                    if (aggregatedSecondaryValue != null &&
                        aggregatedSecondaryValue != 0) {
                      calculatedValue =
                          aggregatedBaseValue / aggregatedSecondaryValue;
                    } else if (operandValue != null && operandValue != 0) {
                      calculatedValue = aggregatedBaseValue / operandValue;
                    } else {
                      calculatedValue = double.nan; // Division by zero
                    }
                    break;
                  case MathOperation.none:
                  default:
                    calculatedValue = aggregatedBaseValue;
                    break;
                }
              }
            }
            // Use DoubleCellValue for numbers, TextCellValue for others or null
            if (calculatedValue != null &&
                !calculatedValue.isNaN &&
                !calculatedValue.isInfinite) {
              rowCells.add(
                DoubleCellValue(
                  double.parse(calculatedValue.toStringAsFixed(2)),
                ),
              );
            } else {
              rowCells.add(
                TextCellValue('N/A'),
              ); // Indicate non-numeric or error
            }
          }
          sheetObject.appendRow(rowCells); // Append the list of CellValue
        }
      }

      final directory = await getApplicationDocumentsDirectory();
      final String fileName =
          'SubstationReport_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.xlsx';
      final String filePath = '${directory.path}/$fileName';
      final File file = File(filePath);
      List<int>? excelBytes = excel.encode();
      if (excelBytes != null) {
        await file.writeAsBytes(excelBytes);
        if (mounted) {
          SnackBarUtils.showSnackBar(
            context,
            'Report generated and saved to: ${file.path}',
          );
          await OpenFilex.open(filePath);
        }
      } else {
        if (mounted)
          SnackBarUtils.showSnackBar(context, 'Failed to encode Excel file.');
      }
    } catch (e) {
      if (mounted)
        SnackBarUtils.showSnackBar(context, 'Error generating report: $e');
      print('Error generating Excel report: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Generate Custom Report')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _availableTemplates.isEmpty || _availableReadingFields.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  'No report templates or reading fields available for the current substation. Please ensure you have created templates and selected a substation on the dashboard.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontStyle: FontStyle.italic,
                    color: Colors.grey,
                  ),
                ),
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DropdownButtonFormField<ReportTemplate>(
                    decoration: const InputDecoration(
                      labelText: 'Select Report Template',
                      border: OutlineInputBorder(),
                    ),
                    value: _selectedTemplate,
                    onChanged: (template) {
                      setState(() {
                        _selectedTemplate = template;
                        _selectedPeriodType = template!.frequency;
                      });
                    },
                    items: _availableTemplates.map((template) {
                      return DropdownMenuItem(
                        value: template,
                        child: Text(template.templateName),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Report Period Type:',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Row(
                    children: ReportFrequency.values.map((freq) {
                      return Expanded(
                        child: RadioListTile<ReportFrequency>(
                          title: Text(freq.toShortString().capitalize()),
                          value: freq,
                          groupValue: _selectedPeriodType,
                          onChanged: (ReportFrequency? value) {
                            setState(() {
                              _selectedPeriodType = value!;
                            });
                          },
                        ),
                      );
                    }).toList(),
                  ),
                  if (_selectedPeriodType == ReportFrequency.custom) ...[
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: ListTile(
                            title: Text(
                              'From: ${DateFormat('yyyy-MM-dd').format(_fromDate)}',
                            ),
                            trailing: const Icon(Icons.calendar_today),
                            onTap: () => _selectDate(context, true),
                          ),
                        ),
                        Expanded(
                          child: ListTile(
                            title: Text(
                              'To: ${DateFormat('yyyy-MM-dd').format(_toDate)}',
                            ),
                            trailing: const Icon(Icons.calendar_today),
                            onTap: () => _selectDate(context, false),
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 30),
                  Center(
                    child: ElevatedButton.icon(
                      onPressed: _isLoading ? null : _generateExcelReport,
                      icon: _isLoading
                          ? const CircularProgressIndicator()
                          : const Icon(Icons.download),
                      label: Text(
                        _isLoading ? 'Generating...' : 'Generate Excel Report',
                      ),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 40,
                          vertical: 15,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

// Helper extension for capitalizing strings
extension StringCapitalizeExtension on String {
  String capitalize() {
    if (isEmpty) return '';
    return "${this[0].toUpperCase()}${substring(1)}";
  }
}

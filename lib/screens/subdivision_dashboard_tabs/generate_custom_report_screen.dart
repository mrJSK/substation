// lib/screens/generate_custom_report_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:excel/excel.dart' hide Border;
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:open_filex/open_filex.dart';

import '../../models/app_state_data.dart';
import '../../models/report_template_model.dart';
import '../../models/logsheet_models.dart';
import '../../models/bay_model.dart';
import '../../models/reading_models.dart';
import '../../models/user_model.dart';
import '../../utils/snackbar_utils.dart';

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
  bool _isGenerating = false;
  ReportFrequency _selectedPeriodType = ReportFrequency.daily;
  DateTime _fromDate = DateTime.now().subtract(const Duration(days: 7));
  DateTime _toDate = DateTime.now();
  List<ReadingField> _availableReadingFields = [];

  @override
  void initState() {
    super.initState();
    _fetchInitialData();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: _buildAppBar(theme),
      body: _isLoading
          ? _buildLoadingState()
          : _availableTemplates.isEmpty
          ? _buildEmptyState(theme)
          : _buildMainContent(theme),
    );
  }

  PreferredSizeWidget _buildAppBar(ThemeData theme) {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      title: Text(
        'Generate Custom Report',
        style: TextStyle(
          color: theme.colorScheme.onSurface,
          fontSize: 18,
          fontWeight: FontWeight.w500,
        ),
      ),
      leading: IconButton(
        icon: Icon(Icons.arrow_back, color: theme.colorScheme.onSurface),
        onPressed: () => Navigator.pop(context),
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Loading report templates...'),
        ],
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.description_outlined,
              size: 64,
              color: theme.colorScheme.onSurface.withOpacity(0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'No Report Templates Found',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: theme.colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Create a report template first to generate custom reports.',
              style: TextStyle(
                fontSize: 14,
                color: theme.colorScheme.onSurface.withOpacity(0.5),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainContent(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTemplateSelection(theme),
          const SizedBox(height: 24),
          _buildPeriodTypeSelection(theme),
          const SizedBox(height: 24),
          if (_selectedPeriodType == ReportFrequency.custom)
            _buildDateRangeSelection(theme),
          const SizedBox(height: 32),
          _buildGenerateButton(theme),
        ],
      ),
    );
  }

  Widget _buildTemplateSelection(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(
                  Icons.description,
                  color: theme.colorScheme.primary,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Report Template',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<ReportTemplate>(
            value: _selectedTemplate,
            decoration: InputDecoration(
              labelText: 'Select Template',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
            ),
            items: _availableTemplates
                .map(
                  (template) => DropdownMenuItem(
                    value: template,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          template.templateName,
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                        Text(
                          '${template.selectedBayIds.length} bays, ${template.selectedReadingFieldIds.length} fields',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
                .toList(),
            onChanged: (template) {
              setState(() {
                _selectedTemplate = template;
                _selectedPeriodType = template!.frequency;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodTypeSelection(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(
                  Icons.schedule,
                  color: Colors.orange,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Report Period',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Column(
            children: ReportFrequency.values
                .map(
                  (freq) => RadioListTile<ReportFrequency>(
                    title: Text(freq.toShortString().capitalize()),
                    subtitle: Text(_getFrequencyDescription(freq)),
                    value: freq,
                    groupValue: _selectedPeriodType,
                    onChanged: (value) =>
                        setState(() => _selectedPeriodType = value!),
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildDateRangeSelection(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(
                  Icons.date_range,
                  color: Colors.blue,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Date Range',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildDateField(
                  label: 'From Date',
                  date: _fromDate,
                  onTap: () => _selectDate(true),
                  icon: Icons.calendar_today,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildDateField(
                  label: 'To Date',
                  date: _toDate,
                  onTap: () => _selectDate(false),
                  icon: Icons.calendar_today,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Add a quick date range selector
          _buildQuickDateRanges(theme),
        ],
      ),
    );
  }

  Widget _buildDateField({
    required String label,
    required DateTime date,
    required VoidCallback onTap,
    required IconData icon,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: Colors.grey.shade600),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 2),
                Text(
                  DateFormat('MMM dd, yyyy').format(date),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickDateRanges(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Select',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildQuickDateChip('Last 7 days', 7),
            _buildQuickDateChip('Last 15 days', 15),
            _buildQuickDateChip('Last 30 days', 30),
            _buildQuickDateChip('This month', 0, isThisMonth: true),
          ],
        ),
      ],
    );
  }

  Widget _buildQuickDateChip(
    String label,
    int days, {
    bool isThisMonth = false,
  }) {
    return InkWell(
      onTap: () {
        setState(() {
          if (isThisMonth) {
            final now = DateTime.now();
            _fromDate = DateTime(now.year, now.month, 1);
            _toDate = DateTime(now.year, now.month + 1, 0);
          } else {
            _toDate = DateTime.now();
            _fromDate = _toDate.subtract(Duration(days: days));
          }
        });
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.blue.shade50,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.blue.shade200),
        ),
        child: Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.blue.shade700),
        ),
      ),
    );
  }

  Widget _buildGenerateButton(ThemeData theme) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton.icon(
        onPressed: _isGenerating || _selectedTemplate == null
            ? null
            : _generateExcelReport,
        style: ElevatedButton.styleFrom(
          backgroundColor: theme.colorScheme.primary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        icon: _isGenerating
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.download),
        label: Text(
          _isGenerating ? 'Generating Report...' : 'Generate Excel Report',
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
      ),
    );
  }

  String _getFrequencyDescription(ReportFrequency freq) {
    switch (freq) {
      case ReportFrequency.hourly:
        return 'Generate report with hourly data points';
      case ReportFrequency.daily:
        return 'Generate report with daily aggregated data';
      case ReportFrequency.monthly:
        return 'Generate report with monthly aggregated data';
      case ReportFrequency.custom:
        return 'Select custom date range for the report';
      default:
        return '';
    }
  }

  Future<void> _selectDate(bool isFrom) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isFrom ? _fromDate : _toDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: Theme.of(context).colorScheme.primary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        if (isFrom) {
          _fromDate = picked;
          // Ensure to date is not before from date
          if (_toDate.isBefore(_fromDate)) {
            _toDate = _fromDate;
          }
        } else {
          _toDate = picked;
          // Ensure from date is not after to date
          if (_fromDate.isAfter(_toDate)) {
            _fromDate = _toDate;
          }
        }
      });
    }
  }

  Future<void> _fetchInitialData() async {
    setState(() => _isLoading = true);

    try {
      final appState = Provider.of<AppStateData>(context, listen: false);
      final currentUserUid = appState.currentUser?.uid;
      final selectedSubstationId = appState.selectedSubstation?.id;

      if (currentUserUid == null || selectedSubstationId == null) {
        if (mounted) {
          SnackBarUtils.showSnackBar(
            context,
            'Please log in and select a substation first.',
            isError: true,
          );
        }
        return;
      }

      // Fetch Report Templates
      final templateQuerySnapshot = await FirebaseFirestore.instance
          .collection('reportTemplates')
          .where('createdByUid', isEqualTo: currentUserUid)
          .where('substationId', isEqualTo: selectedSubstationId)
          .get();

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

      final allReadingTemplates = readingTemplateDocs.docs
          .map((doc) => ReadingTemplate.fromFirestore(doc))
          .toList();

      final Set<ReadingField> uniqueReadingFields = {};
      for (var template in allReadingTemplates) {
        for (var field in template.readingFields) {
          if (field.name.isNotEmpty && field.dataType != null) {
            uniqueReadingFields.add(field);
          }
        }
      }

      _availableReadingFields = uniqueReadingFields.toList();
      _availableReadingFields.sort((a, b) => a.name.compareTo(b.name));
    } catch (e) {
      if (mounted) {
        SnackBarUtils.showSnackBar(
          context,
          'Error loading data: $e',
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _generateExcelReport() async {
    if (_selectedTemplate == null) {
      SnackBarUtils.showSnackBar(context, 'Please select a report template.');
      return;
    }

    if (_selectedPeriodType == ReportFrequency.custom &&
        _fromDate.isAfter(_toDate)) {
      SnackBarUtils.showSnackBar(
        context,
        'From Date cannot be after To Date.',
        isError: true,
      );
      return;
    }

    setState(() => _isGenerating = true);

    try {
      await _performExcelGeneration();

      if (mounted) {
        SnackBarUtils.showSnackBar(context, 'Report generated successfully!');
      }
    } catch (e) {
      if (mounted) {
        SnackBarUtils.showSnackBar(
          context,
          'Failed to generate report: $e',
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  Future<void> _performExcelGeneration() async {
    final appState = Provider.of<AppStateData>(context, listen: false);
    final selectedSubstation = appState.selectedSubstation;

    if (selectedSubstation == null) {
      SnackBarUtils.showSnackBar(
        context,
        'No substation selected. Cannot generate report.',
        isError: true,
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
          baysMap[doc.id] = Bay.fromFirestore(doc);
        }
      }
    } else {
      SnackBarUtils.showSnackBar(
        context,
        'Selected template has no bays. Please edit the template to include bays.',
        isError: true,
      );
      return;
    }

    // 2. Determine date range for logsheet query
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
            )
            .where(
              'readingTimestamp',
              isGreaterThanOrEqualTo: Timestamp.fromDate(queryStartDate),
            )
            .where(
              'readingTimestamp',
              isLessThanOrEqualTo: Timestamp.fromDate(queryEndDate),
            )
            .orderBy('readingTimestamp')
            .get();

        allReadings.addAll(
          logsheetSnapshot.docs
              .map((doc) => LogsheetEntry.fromFirestore(doc))
              .toList(),
        );
      }
    }

    // Sort readings by timestamp and bay name
    allReadings.sort((a, b) {
      int timestampCompare = a.readingTimestamp.compareTo(b.readingTimestamp);
      if (timestampCompare != 0) return timestampCompare;
      final bayA = baysMap[a.bayId]?.name ?? '';
      final bayB = baysMap[b.bayId]?.name ?? '';
      return bayA.compareTo(bayB);
    });

    // 4. Create Excel workbook
    var excel = Excel.createExcel();
    Sheet sheetObject = excel['Report for ${selectedSubstation.name}'];

    // 5. Create header row
    List<CellValue> headerCells = [
      TextCellValue('Date/Time'),
      TextCellValue('Bay Name'),
    ];

    for (var fieldName in _selectedTemplate!.selectedReadingFieldIds) {
      final fieldDef = _availableReadingFields.firstWhere(
        (f) => f.name == fieldName,
        orElse: () =>
            ReadingField(name: fieldName, dataType: ReadingFieldDataType.text),
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

    sheetObject.appendRow(headerCells);

    // 6. Add data rows
    for (var entry in allReadings) {
      final currentBay = baysMap[entry.bayId];

      List<CellValue> rowCells = [
        TextCellValue(
          DateFormat(
            'yyyy-MM-dd HH:mm',
          ).format(entry.readingTimestamp.toDate()),
        ),
        TextCellValue(currentBay?.name ?? 'Unknown Bay'),
      ];

      // Add reading field values
      for (var fieldName in _selectedTemplate!.selectedReadingFieldIds) {
        final value = entry.values[fieldName];
        if (value != null && double.tryParse(value.toString()) != null) {
          rowCells.add(DoubleCellValue(double.parse(value.toString())));
        } else {
          rowCells.add(TextCellValue(value?.toString() ?? ''));
        }
      }

      // Add custom column values (simplified calculation)
      for (var customCol in _selectedTemplate!.customColumns) {
        final baseValue = entry.values[customCol.baseReadingFieldId];
        if (baseValue != null &&
            double.tryParse(baseValue.toString()) != null) {
          double calculatedValue = double.parse(baseValue.toString());

          // Apply operation if specified
          if (customCol.operandValue != null) {
            final operand = double.tryParse(customCol.operandValue!);
            if (operand != null) {
              switch (customCol.operation) {
                case MathOperation.add:
                  calculatedValue += operand;
                  break;
                case MathOperation.subtract:
                  calculatedValue -= operand;
                  break;
                case MathOperation.multiply:
                  calculatedValue *= operand;
                  break;
                case MathOperation.divide:
                  if (operand != 0) calculatedValue /= operand;
                  break;
                default:
                  break;
              }
            }
          }

          rowCells.add(DoubleCellValue(calculatedValue));
        } else {
          rowCells.add(TextCellValue('N/A'));
        }
      }

      sheetObject.appendRow(rowCells);
    }

    // 7. Save file
    final directory = await getApplicationDocumentsDirectory();
    final String fileName =
        'SubstationReport_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.xlsx';
    final String filePath = '${directory.path}/$fileName';
    final File file = File(filePath);

    List<int>? excelBytes = excel.encode();
    if (excelBytes != null) {
      await file.writeAsBytes(excelBytes);
      if (mounted) {
        SnackBarUtils.showSnackBar(context, 'Report saved to: ${file.path}');
        await OpenFilex.open(filePath);
      }
    } else {
      if (mounted) {
        SnackBarUtils.showSnackBar(
          context,
          'Failed to generate Excel file.',
          isError: true,
        );
      }
    }
  }
}

extension StringCapitalizeExtension on String {
  String capitalize() {
    if (isEmpty) return '';
    return "${this[0].toUpperCase()}${substring(1)}";
  }
}

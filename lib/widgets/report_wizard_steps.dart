// lib/widgets/report_wizard_steps.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../models/report_builder_models.dart';
import '../models/hierarchy_models.dart';
import '../models/user_model.dart';
import '../services/report_builder_service.dart';

// Step 1: Report Metadata
class ReportMetadataStep extends StatefulWidget {
  final ReportConfiguration config;
  final Function(ReportConfiguration) onConfigChanged;

  const ReportMetadataStep({
    super.key,
    required this.config,
    required this.onConfigChanged,
  });

  @override
  State<ReportMetadataStep> createState() => _ReportMetadataStepState();
}

class _ReportMetadataStepState extends State<ReportMetadataStep> {
  late TextEditingController _titleController;
  late TextEditingController _subtitleController;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.config.title);
    _subtitleController = TextEditingController(
      text: widget.config.subtitle ?? '',
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _subtitleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStepHeader(theme),
          const SizedBox(height: 32),
          _buildBasicInfo(theme),
          const SizedBox(height: 24),
          _buildReportType(theme),
          const SizedBox(height: 24),
          _buildLayoutOptions(theme),
        ],
      ),
    );
  }

  Widget _buildStepHeader(ThemeData theme) {
    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            Icons.info_outline,
            color: theme.colorScheme.primary,
            size: 24,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Report Information',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Define the basic details and structure of your report',
                style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBasicInfo(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Basic Information',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _titleController,
            decoration: InputDecoration(
              labelText: 'Report Title *',
              hintText: 'e.g., Daily Max Load Report - Ghaziabad Division',
              prefixIcon: const Icon(Icons.title),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              filled: true,
              fillColor: Colors.grey.shade50,
            ),
            onChanged: (value) {
              widget.config.title = value;
              widget.onConfigChanged(widget.config);
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _subtitleController,
            decoration: InputDecoration(
              labelText: 'Subtitle (Optional)',
              hintText: 'Additional description or period information',
              prefixIcon: const Icon(Icons.subtitles),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              filled: true,
              fillColor: Colors.grey.shade50,
            ),
            maxLines: 2,
            onChanged: (value) {
              widget.config.subtitle = value.isEmpty ? null : value;
              widget.onConfigChanged(widget.config);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildReportType(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Report Type',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 16,
            children: ReportType.values.map((type) {
              return ChoiceChip(
                label: Text(type.name.toUpperCase()),
                selected: widget.config.type == type,
                selectedColor: theme.colorScheme.primary.withOpacity(0.2),
                onSelected: (selected) {
                  if (selected) {
                    setState(() {
                      widget.config.type = type;
                      widget.onConfigChanged(widget.config);
                    });
                  }
                },
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildLayoutOptions(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Layout Options',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<LayoutOrientation>(
                  value: widget.config.orientation,
                  decoration: InputDecoration(
                    labelText: 'Orientation',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                  ),
                  items: LayoutOrientation.values.map((orientation) {
                    return DropdownMenuItem(
                      value: orientation,
                      child: Text(orientation.name.toUpperCase()),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      widget.config.orientation = value!;
                      widget.onConfigChanged(widget.config);
                    });
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: DropdownButtonFormField<ReportFrequency>(
                  value: widget.config.frequency,
                  decoration: InputDecoration(
                    labelText: 'Frequency',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                  ),
                  items: ReportFrequency.values.map((frequency) {
                    return DropdownMenuItem(
                      value: frequency,
                      child: Text(frequency.name.toUpperCase()),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      widget.config.frequency = value!;
                      widget.onConfigChanged(widget.config);
                    });
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// Step 2: Substation Selection
class SubstationSelectionStep extends StatefulWidget {
  final ReportConfiguration config;
  final Function(ReportConfiguration) onConfigChanged;
  final AppUser currentUser;

  const SubstationSelectionStep({
    super.key,
    required this.config,
    required this.onConfigChanged,
    required this.currentUser,
  });

  @override
  State<SubstationSelectionStep> createState() =>
      _SubstationSelectionStepState();
}

class _SubstationSelectionStepState extends State<SubstationSelectionStep> {
  List<Substation> _availableSubstations = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadSubstations();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStepHeader(theme),
          const SizedBox(height: 32),
          _buildDateRange(theme),
          const SizedBox(height: 24),
          _buildSubstationList(theme),
        ],
      ),
    );
  }

  Widget _buildStepHeader(ThemeData theme) {
    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: Colors.orange.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.location_on, color: Colors.orange, size: 24),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Scope Selection',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Choose substations and date range for your report',
                style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDateRange(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Date Range',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () => _selectDate(true),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                      color: Colors.grey.shade50,
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today, size: 20),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Start Date',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            Text(
                              DateFormat(
                                'MMM dd, yyyy',
                              ).format(widget.config.startDate),
                              style: const TextStyle(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: InkWell(
                  onTap: () => _selectDate(false),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                      color: Colors.grey.shade50,
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today, size: 20),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'End Date',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            Text(
                              DateFormat(
                                'MMM dd, yyyy',
                              ).format(widget.config.endDate),
                              style: const TextStyle(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSubstationList(ThemeData theme) {
    if (_isLoading) {
      return const Center(
        child: Column(
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading substations...'),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Substations (${widget.config.substationIds.length} selected)',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              Row(
                children: [
                  TextButton(
                    onPressed: _selectAll,
                    child: const Text('Select All'),
                  ),
                  TextButton(
                    onPressed: _clearAll,
                    child: const Text('Clear All'),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: theme.colorScheme.primary.withOpacity(0.3),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.info, color: theme.colorScheme.primary, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _getUserScopeMessage(),
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.primary.withOpacity(0.8),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 300,
            child: _availableSubstations.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.location_off,
                          size: 48,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No substations available',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Contact your administrator for access',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: _availableSubstations.length,
                    itemBuilder: (context, index) {
                      final substation = _availableSubstations[index];
                      final isSelected = widget.config.substationIds.contains(
                        substation.id,
                      );

                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? theme.colorScheme.primary.withOpacity(0.1)
                              : Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isSelected
                                ? theme.colorScheme.primary.withOpacity(0.3)
                                : Colors.grey.shade300,
                          ),
                        ),
                        child: CheckboxListTile(
                          value: isSelected,
                          onChanged: (bool? value) =>
                              _toggleSubstation(substation.id, value ?? false),
                          title: Text(
                            substation.name,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(_getSubstationSubtitle(substation)),
                          activeColor: theme.colorScheme.primary,
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  String _getUserScopeMessage() {
    final currentUser = widget.currentUser;

    switch (currentUser.role) {
      case 'subdivision':
        return 'Showing substations in your subdivision';
      case 'division':
        return 'Showing substations in your division';
      case 'circle':
      case 'admin':
        return 'Showing all available substations';
      default:
        return 'Showing available substations based on your access';
    }
  }

  String _getSubstationSubtitle(Substation substation) {
    try {
      final divisionName =
          (substation as dynamic).divisionName ?? 'Unknown Division';
      final circleName = (substation as dynamic).circleName ?? 'Unknown Circle';
      return '$divisionName • $circleName';
    } catch (e) {
      if (substation.address != null && substation.address!.isNotEmpty) {
        return substation.address!;
      } else if (substation.subdivisionId.isNotEmpty) {
        return 'Subdivision: ${substation.subdivisionId}';
      } else {
        return 'No location info';
      }
    }
  }

  Future<void> _loadSubstations() async {
    setState(() => _isLoading = true);

    try {
      final currentUser = widget.currentUser;

      Query query = FirebaseFirestore.instance
          .collection('substations')
          .orderBy('name');

      // Apply hierarchy-based filtering
      switch (currentUser.role) {
        case 'subdivision':
          query = query.where(
            'subdivisionId',
            isEqualTo: currentUser.subdivisionId,
          );
          break;

        case 'division':
          final subdivisionSnapshot = await FirebaseFirestore.instance
              .collection('subdivisions')
              .where('divisionId', isEqualTo: currentUser.divisionId)
              .get();

          final subdivisionIds = subdivisionSnapshot.docs
              .map((doc) => doc.id)
              .toList();

          if (subdivisionIds.isNotEmpty) {
            query = query.where('subdivisionId', whereIn: subdivisionIds);
          } else {
            setState(() {
              _availableSubstations = [];
            });
            return;
          }
          break;

        case 'circle':
          final divisionSnapshot = await FirebaseFirestore.instance
              .collection('divisions')
              .where('circleId', isEqualTo: currentUser.circleId)
              .get();

          final divisionIds = divisionSnapshot.docs
              .map((doc) => doc.id)
              .toList();

          if (divisionIds.isNotEmpty) {
            final subdivisionSnapshot = await FirebaseFirestore.instance
                .collection('subdivisions')
                .where('divisionId', whereIn: divisionIds)
                .get();

            final subdivisionIds = subdivisionSnapshot.docs
                .map((doc) => doc.id)
                .toList();

            if (subdivisionIds.isNotEmpty) {
              query = query.where('subdivisionId', whereIn: subdivisionIds);
            } else {
              setState(() {
                _availableSubstations = [];
              });
              return;
            }
          } else {
            setState(() {
              _availableSubstations = [];
            });
            return;
          }
          break;

        case 'admin':
        default:
          break;
      }

      final snapshot = await query.get();

      setState(() {
        _availableSubstations = snapshot.docs
            .map((doc) => Substation.fromFirestore(doc))
            .toList();
      });
    } catch (e) {
      print('Error loading substations: $e');
      setState(() {
        _availableSubstations = [];
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _toggleSubstation(String substationId, bool isSelected) {
    setState(() {
      if (isSelected) {
        widget.config.addSubstationId(substationId);
      } else {
        widget.config.removeSubstationId(substationId);
      }
      widget.onConfigChanged(widget.config);
    });
  }

  void _selectAll() {
    setState(() {
      widget.config.setSubstationIds(
        _availableSubstations.map((s) => s.id).toList(),
      );
      widget.onConfigChanged(widget.config);
    });
  }

  void _clearAll() {
    setState(() {
      widget.config.clearSubstationIds();
      widget.onConfigChanged(widget.config);
    });
  }

  Future<void> _selectDate(bool isStartDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isStartDate
          ? widget.config.startDate
          : widget.config.endDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (picked != null) {
      setState(() {
        if (isStartDate) {
          widget.config.startDate = picked;
          if (widget.config.endDate.isBefore(picked)) {
            widget.config.endDate = picked;
          }
        } else {
          widget.config.endDate = picked;
          if (widget.config.startDate.isAfter(picked)) {
            widget.config.startDate = picked;
          }
        }
        widget.onConfigChanged(widget.config);
      });
    }
  }
}

// Step 3: Data Source Selection
class DataSourceSelectionStep extends StatefulWidget {
  final ReportConfiguration config;
  final Function(ReportConfiguration) onConfigChanged;

  const DataSourceSelectionStep({
    super.key,
    required this.config,
    required this.onConfigChanged,
  });

  @override
  State<DataSourceSelectionStep> createState() =>
      _DataSourceSelectionStepState();
}

class _DataSourceSelectionStepState extends State<DataSourceSelectionStep> {
  List<DataSourceConfig> _availableDataSources = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadDataSources();
  }

  Future<void> _loadDataSources() async {
    setState(() => _isLoading = true);

    try {
      final dataSources = await ReportBuilderService.getAvailableDataSources(
        substationIds: widget.config.substationIds,
      );

      setState(() {
        _availableDataSources = dataSources;
        widget.config.dataSources = dataSources;
        widget.onConfigChanged(widget.config);
      });
    } catch (e) {
      print('Error loading data sources: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading available data sources...'),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStepHeader(theme),
          const SizedBox(height: 32),
          _buildDataSourceList(theme),
        ],
      ),
    );
  }

  Widget _buildStepHeader(ThemeData theme) {
    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: Colors.green.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.data_array, color: Colors.green, size: 24),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Data Sources',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Select the data sources for your report',
                style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDataSourceList(ThemeData theme) {
    if (_availableDataSources.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(40),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.grey.shade300,
            style: BorderStyle.solid,
          ),
        ),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.data_array, size: 48, color: Colors.grey.shade400),
              const SizedBox(height: 16),
              Text(
                'No data sources available',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Please select substations first to load available data sources',
                style: TextStyle(color: Colors.grey.shade500),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: _availableDataSources.map((dataSource) {
        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: dataSource.isEnabled
                  ? _getDataSourceColor(dataSource.type).withOpacity(0.3)
                  : Colors.grey.shade200,
            ),
          ),
          child: ExpansionTile(
            leading: Checkbox(
              value: dataSource.isEnabled,
              onChanged: (bool? value) {
                setState(() {
                  dataSource.isEnabled = value ?? false;
                  widget.onConfigChanged(widget.config);
                });
              },
              activeColor: _getDataSourceColor(dataSource.type),
            ),
            title: Row(
              children: [
                Icon(
                  _getDataSourceIcon(dataSource.type),
                  color: _getDataSourceColor(dataSource.type),
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  dataSource.sourceName,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            subtitle: Text(
              '${dataSource.fields.length} fields available',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Available Fields:',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: _getDataSourceColor(
                          dataSource.type,
                        ).withOpacity(0.8),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: dataSource.fields.map((field) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: _getDataSourceColor(
                              dataSource.type,
                            ).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _getDataSourceColor(
                                dataSource.type,
                              ).withOpacity(0.3),
                            ),
                          ),
                          child: Text(
                            field.displayName,
                            style: TextStyle(
                              fontSize: 10,
                              color: _getDataSourceColor(
                                dataSource.type,
                              ).withOpacity(0.8),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Color _getDataSourceColor(DataSourceType type) {
    switch (type) {
      case DataSourceType.core:
        return Colors.blue;
      case DataSourceType.customField:
        return Colors.purple;
      case DataSourceType.customGroup:
        return Colors.teal;
    }
  }

  IconData _getDataSourceIcon(DataSourceType type) {
    switch (type) {
      case DataSourceType.core:
        return Icons.storage;
      case DataSourceType.customField:
        return Icons.extension;
      case DataSourceType.customGroup:
        return Icons.group_work;
    }
  }
}

class ColumnMappingStep extends StatefulWidget {
  final ReportConfiguration config;
  final Function(ReportConfiguration) onConfigChanged;

  const ColumnMappingStep({
    super.key,
    required this.config,
    required this.onConfigChanged,
  });

  @override
  State<ColumnMappingStep> createState() => _ColumnMappingStepState();
}

class _ColumnMappingStepState extends State<ColumnMappingStep> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: constraints.maxWidth > 600 ? 32 : 16,
            vertical: 24,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildStepHeader(theme),
                SizedBox(height: constraints.maxWidth > 600 ? 24 : 16),
                _buildDataSourceValidation(theme),
                SizedBox(height: constraints.maxWidth > 600 ? 24 : 16),
                _buildColumnList(theme),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStepHeader(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.purple.shade400, Colors.purple.shade600],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.purple.withOpacity(0.2),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(
                Icons.view_column,
                color: Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Column Mapping',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Define columns and map them to data sources with advanced formula builder',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          children: [
            _buildActionButton(
              onPressed: _canAddColumns() ? _addColumn : null,
              icon: Icons.add_circle_outline,
              label: 'Add Column',
              color: theme.colorScheme.primary,
            ),
            _buildActionButton(
              onPressed: _canAddColumns() ? _addGroupHeader : null,
              icon: Icons.folder_outlined,
              label: 'Add Group',
              color: Colors.purple,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required VoidCallback? onPressed,
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        elevation: 1,
      ),
    );
  }

  Widget _buildDataSourceValidation(ThemeData theme) {
    final enabledSources = widget.config.dataSources
        .where((ds) => ds.isEnabled)
        .toList();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: enabledSources.isEmpty
            ? Colors.orange.withOpacity(0.08)
            : Colors.green.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: enabledSources.isEmpty
              ? Colors.orange.withOpacity(0.2)
              : Colors.green.withOpacity(0.2),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: enabledSources.isEmpty
                  ? Colors.orange.withOpacity(0.1)
                  : Colors.green.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(
              enabledSources.isEmpty ? Icons.warning_amber : Icons.check_circle,
              color: enabledSources.isEmpty ? Colors.orange : Colors.green,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  enabledSources.isEmpty
                      ? 'No Data Sources Selected'
                      : '${enabledSources.length} Data Source(s) Available',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: enabledSources.isEmpty
                        ? Colors.orange.shade800
                        : Colors.green.shade800,
                  ),
                ),
                if (enabledSources.isEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Please go back to Step 3 and select at least one data source before adding columns.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.orange.shade700,
                    ),
                  ),
                ] else ...[
                  const SizedBox(height: 4),
                  Text(
                    '${_getTotalFieldCount()} fields ready for mapping',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.green.shade700,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  int _getTotalFieldCount() {
    return widget.config.dataSources
        .where((ds) => ds.isEnabled)
        .map((ds) => ds.fields.length)
        .fold(0, (sum, count) => sum + count);
  }

  Widget _buildColumnList(ThemeData theme) {
    if (widget.config.columns.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.grey.shade200,
            style: BorderStyle.solid,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.view_column, size: 40, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'No columns added yet',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Start by adding columns to define your report structure.',
              style: TextStyle(
                color: Colors.grey.shade500,
                fontSize: 14,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Column(
      children: widget.config.columns.asMap().entries.map((entry) {
        final index = entry.key;
        final column = entry.value;
        return Container(
          key: ValueKey(column.id),
          margin: const EdgeInsets.only(bottom: 16),
          child: _buildColumnItem(theme, column, index),
        );
      }).toList(),
    );
  }

  Widget _buildColumnItem(ThemeData theme, ColumnConfig column, int index) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: column.isGroupHeader
              ? Colors.blue.withOpacity(0.2)
              : Colors.grey.shade200,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: column.isGroupHeader
                  ? Colors.blue.withOpacity(0.05)
                  : Colors.grey.shade50,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.drag_handle, color: Colors.grey.shade400, size: 20),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: column.isGroupHeader
                          ? [Colors.blue.shade300, Colors.blue.shade500]
                          : [Colors.green.shade300, Colors.green.shade500],
                    ),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        column.isGroupHeader ? Icons.folder : Icons.table_chart,
                        color: Colors.white,
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        column.isGroupHeader ? 'GROUP HEADER' : 'COLUMN',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                PopupMenuButton<String>(
                  onSelected: (value) => _handleColumnAction(value, index),
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'duplicate',
                      child: Row(
                        children: [
                          Icon(Icons.content_copy, size: 16),
                          SizedBox(width: 8),
                          Text('Duplicate'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete, size: 16, color: Colors.red),
                          SizedBox(width: 8),
                          Text('Delete', style: TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
                  ],
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(
                      Icons.more_vert,
                      color: Colors.grey.shade600,
                      size: 16,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextFormField(
              decoration: InputDecoration(
                hintText: column.isGroupHeader
                    ? 'Group header name (e.g., Energy Readings)'
                    : 'Column header (e.g., Date, Max Load)',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey.shade200),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: theme.colorScheme.primary,
                    width: 1.5,
                  ),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
                filled: true,
                fillColor: Colors.white,
              ),
              initialValue: column.header,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              onChanged: (value) {
                column.header = value;
                widget.onConfigChanged(widget.config);
              },
            ),
          ),
          if (!column.isGroupHeader) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.settings,
                        color: Colors.grey.shade600,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Column Configuration',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      return Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          SizedBox(
                            width: constraints.maxWidth > 400
                                ? (constraints.maxWidth - 12) / 2
                                : constraints.maxWidth,
                            child: _buildEnhancedDropdown(
                              label: 'Data Source',
                              value: column.dataSourceId.isEmpty
                                  ? null
                                  : column.dataSourceId,
                              items: widget.config.dataSources
                                  .where((ds) => ds.isEnabled)
                                  .map(
                                    (ds) => DropdownMenuItem(
                                      value: ds.sourceId,
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 6,
                                            height: 6,
                                            decoration: BoxDecoration(
                                              color: _getDataSourceColor(
                                                ds.type,
                                              ),
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(ds.sourceName),
                                        ],
                                      ),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (value) {
                                setState(() {
                                  column.dataSourceId = value ?? '';
                                  column.fieldPath = '';
                                  widget.onConfigChanged(widget.config);
                                });
                              },
                              hint: 'Select data source',
                              icon: Icons.storage,
                            ),
                          ),
                          SizedBox(
                            width: constraints.maxWidth > 400
                                ? (constraints.maxWidth - 12) / 2
                                : constraints.maxWidth,
                            child: _buildEnhancedDropdown(
                              label: 'Field',
                              value: column.fieldPath.isEmpty
                                  ? null
                                  : column.fieldPath,
                              items:
                                  _getFieldsForDataSource(column.dataSourceId)
                                      .map(
                                        (field) => DropdownMenuItem(
                                          value: field.path,
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                field.displayName,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                              Text(
                                                field.type.toUpperCase(),
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  color: Colors.grey.shade600,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      )
                                      .toList(),
                              onChanged: (value) {
                                setState(() {
                                  column.fieldPath = value ?? '';
                                  widget.onConfigChanged(widget.config);
                                });
                              },
                              hint: 'Select field',
                              icon: Icons.data_object,
                            ),
                          ),
                          SizedBox(
                            width: constraints.maxWidth > 400
                                ? (constraints.maxWidth - 12) / 2
                                : constraints.maxWidth,
                            child: _buildEnhancedDropdown(
                              label: 'Data Type',
                              value: column.dataType,
                              items: ColumnDataType.values
                                  .map(
                                    (type) => DropdownMenuItem(
                                      value: type,
                                      child: Row(
                                        children: [
                                          Icon(
                                            _getDataTypeIcon(type),
                                            size: 14,
                                            color: _getDataTypeColor(type),
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            type.name.toUpperCase(),
                                            style: const TextStyle(
                                              fontSize: 11,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (value) {
                                setState(() {
                                  column.dataType = value!;
                                  widget.onConfigChanged(widget.config);
                                });
                              },
                              icon: Icons.category,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  if (column.dataType == ColumnDataType.computed) ...[
                    const SizedBox(height: 12),
                    _buildFormulaBuilder(column),
                  ],
                ],
              ),
            ),
          ],
          if (column.isGroupHeader && column.subColumns != null) ...[
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.withOpacity(0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.subdirectory_arrow_right,
                            color: Colors.blue,
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Sub-columns (${column.subColumns!.length})',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              color: Colors.blue.shade700,
                            ),
                          ),
                        ],
                      ),
                      ElevatedButton.icon(
                        onPressed: () => _addSubColumn(column),
                        icon: const Icon(Icons.add, size: 14),
                        label: const Text('Add Sub-column'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (column.subColumns!.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    ...column.subColumns!.asMap().entries.map((entry) {
                      final subIndex = entry.key;
                      final subColumn = entry.value;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: _buildSubColumnItem(
                          theme,
                          subColumn,
                          index,
                          subIndex,
                        ),
                      );
                    }),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFormulaBuilder(ColumnConfig column) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.amber.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.amber.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.amber.shade300, Colors.amber.shade500],
                      ),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(
                      Icons.functions,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Formula Builder',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.amber.shade800,
                    ),
                  ),
                ],
              ),
              TextButton.icon(
                onPressed: () => _showEnhancedFormulaHelp(context),
                icon: Icon(
                  Icons.help_outline,
                  size: 16,
                  color: Colors.amber.shade600,
                ),
                label: Text(
                  'Help',
                  style: TextStyle(color: Colors.amber.shade600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Current Formula:',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade700,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Text(
                    column.formula?.isEmpty == true
                        ? 'No formula defined'
                        : column.formula ?? 'No formula defined',
                    style: TextStyle(
                      fontSize: 12,
                      fontFamily: 'monospace',
                      color: column.formula?.isEmpty == true
                          ? Colors.grey.shade500
                          : Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  SizedBox(
                    width: constraints.maxWidth > 600
                        ? (constraints.maxWidth - 16) / 3
                        : constraints.maxWidth,
                    child: _buildFormulaDropdown(
                      label: 'Function',
                      items: _getMathFunctions(),
                      onSelected: (value) => _addToFormula(column, value),
                      icon: Icons.functions,
                      color: Colors.blue,
                    ),
                  ),
                  SizedBox(
                    width: constraints.maxWidth > 600
                        ? (constraints.maxWidth - 16) / 3
                        : constraints.maxWidth,
                    child: _buildFormulaDropdown(
                      label: 'Field',
                      items: _getAllAvailableFields(),
                      onSelected: (value) => _addToFormula(column, value),
                      icon: Icons.data_object,
                      color: Colors.green,
                    ),
                  ),
                  SizedBox(
                    width: constraints.maxWidth > 600
                        ? (constraints.maxWidth - 16) / 3
                        : constraints.maxWidth,
                    child: _buildFormulaDropdown(
                      label: 'Operator',
                      items: _getMathOperators(),
                      onSelected: (value) => _addToFormula(column, value),
                      icon: Icons.calculate,
                      color: Colors.purple,
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _clearFormula(column),
                  icon: const Icon(Icons.clear, size: 16),
                  label: const Text('Clear'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade400,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _validateFormula(column),
                  icon: const Icon(Icons.check_circle, size: 16),
                  label: const Text('Validate'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade400,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFormulaDropdown({
    required String label,
    required List<FormulaItem> items,
    required Function(String) onSelected,
    required IconData icon,
    required Color color,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade700,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withOpacity(0.2)),
          ),
          child: DropdownButtonFormField<String>(
            decoration: InputDecoration(
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 8,
              ),
              prefixIcon: Icon(icon, size: 14, color: color),
            ),
            hint: Text(
              'Select ${label.toLowerCase()}',
              style: TextStyle(fontSize: 12),
            ),
            items: items
                .map(
                  (item) => DropdownMenuItem(
                    value: item.value,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          item.label,
                          style: const TextStyle(
                            fontWeight: FontWeight.w500,
                            fontSize: 12,
                          ),
                        ),
                        if (item.description != null)
                          Text(
                            item.description!,
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey.shade600,
                            ),
                          ),
                      ],
                    ),
                  ),
                )
                .toList(),
            onChanged: (value) {
              if (value != null) onSelected(value);
            },
            isExpanded: true,
          ),
        ),
      ],
    );
  }

  Widget _buildSubColumnItem(
    ThemeData theme,
    ColumnConfig subColumn,
    int parentIndex,
    int subIndex,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  decoration: InputDecoration(
                    hintText: 'Sub-column header',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.grey.shade200),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                  ),
                  initialValue: subColumn.header,
                  style: const TextStyle(fontSize: 14),
                  onChanged: (value) {
                    subColumn.header = value;
                    widget.onConfigChanged(widget.config);
                  },
                ),
              ),
              const SizedBox(width: 12),
              IconButton(
                icon: Icon(Icons.delete, color: Colors.red.shade600, size: 20),
                onPressed: () => _removeSubColumn(parentIndex, subIndex),
                tooltip: 'Remove sub-column',
              ),
            ],
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              return Row(
                children: [
                  Expanded(
                    child: _buildEnhancedDropdown(
                      label: 'Data Source',
                      value: subColumn.dataSourceId.isEmpty
                          ? null
                          : subColumn.dataSourceId,
                      items: widget.config.dataSources
                          .where((ds) => ds.isEnabled)
                          .map(
                            (ds) => DropdownMenuItem(
                              value: ds.sourceId,
                              child: Row(
                                children: [
                                  Container(
                                    width: 6,
                                    height: 6,
                                    decoration: BoxDecoration(
                                      color: _getDataSourceColor(ds.type),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    ds.sourceName,
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        setState(() {
                          subColumn.dataSourceId = value ?? '';
                          subColumn.fieldPath = '';
                          widget.onConfigChanged(widget.config);
                        });
                      },
                      hint: 'Select source',
                      icon: Icons.storage,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildEnhancedDropdown(
                      label: 'Field',
                      value: subColumn.fieldPath.isEmpty
                          ? null
                          : subColumn.fieldPath,
                      items: _getFieldsForDataSource(subColumn.dataSourceId)
                          .map(
                            (field) => DropdownMenuItem(
                              value: field.path,
                              child: Text(
                                field.displayName,
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        setState(() {
                          subColumn.fieldPath = value ?? '';
                          widget.onConfigChanged(widget.config);
                        });
                      },
                      hint: 'Select field',
                      icon: Icons.data_object,
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildEnhancedDropdown<T>({
    required String label,
    required T? value,
    required List<DropdownMenuItem<T>> items,
    required void Function(T?) onChanged,
    String? hint,
    required IconData icon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: Colors.grey.shade600),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        DropdownButtonFormField<T>(
          value: value,
          decoration: InputDecoration(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade200),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: Theme.of(context).colorScheme.primary,
                width: 1.5,
              ),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
            filled: true,
            fillColor: Colors.white,
          ),
          hint: hint != null
              ? Text(
                  hint,
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                )
              : null,
          items: items,
          onChanged: onChanged,
          isExpanded: true,
        ),
      ],
    );
  }

  void _showEnhancedFormulaHelp(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.blue.shade300,
                              Colors.purple.shade400,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Icon(
                          Icons.help,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Formula Builder Help',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Colors.grey.shade800,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close, size: 20),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildHelpSection(
                    'Mathematical Functions',
                    [
                      'MAX(field) - Returns the maximum value',
                      'MIN(field) - Returns the minimum value',
                      'AVG(field) - Returns the average value',
                      'SUM(field) - Returns the sum of all values',
                      'COUNT(source) - Counts the number of records',
                      'ROUND(value, decimals) - Rounds to specified decimal places',
                      'ABS(value) - Returns absolute value',
                      'SQRT(value) - Returns square root',
                    ],
                    Icons.functions,
                    Colors.blue,
                  ),
                  _buildHelpSection(
                    'Field References',
                    [
                      'energy.importConsumed - Energy import reading',
                      'energy.exportConsumed - Energy export reading',
                      'bays.name - Bay name',
                      'tripping.startTime - Trip start time',
                      'operations.frequency - Operation frequency',
                    ],
                    Icons.data_object,
                    Colors.green,
                  ),
                  _buildHelpSection(
                    'Operators',
                    [
                      '+ Addition',
                      '- Subtraction',
                      '* Multiplication',
                      '/ Division',
                      '% Modulo (remainder)',
                      '( ) Parentheses for grouping',
                    ],
                    Icons.calculate,
                    Colors.purple,
                  ),
                  _buildHelpSection(
                    'Example Formulas',
                    [
                      'MAX(energy.importConsumed) - Highest energy import',
                      'SUM(energy.importConsumed + energy.exportConsumed) - Total energy',
                      'ROUND(AVG(energy.importConsumed), 2) - Average import rounded to 2 decimals',
                    ],
                    Icons.lightbulb,
                    Colors.orange,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHelpSection(
    String title,
    List<String> items,
    IconData icon,
    Color color,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 4,
                    height: 4,
                    margin: const EdgeInsets.only(top: 6, right: 8),
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      item,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade700,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<FormulaItem> _getMathFunctions() {
    return [
      FormulaItem('MAX({field})', 'MAX', 'Maximum value from field'),
      FormulaItem('MIN({field})', 'MIN', 'Minimum value from field'),
      FormulaItem('AVG({field})', 'AVG', 'Average of field values'),
      FormulaItem('SUM({field})', 'SUM', 'Sum of field values'),
      FormulaItem('COUNT({source})', 'COUNT', 'Count records from source'),
      FormulaItem(
        'ROUND({value}, {decimals})',
        'ROUND',
        'Round to decimal places',
      ),
      FormulaItem('ABS({value})', 'ABS', 'Absolute value'),
      FormulaItem('SQRT({value})', 'SQRT', 'Square root'),
      FormulaItem('POWER({base}, {exponent})', 'POWER', 'Raise to power'),
    ];
  }

  List<FormulaItem> _getAllAvailableFields() {
    List<FormulaItem> fields = [];
    for (var dataSource in widget.config.dataSources.where(
      (ds) => ds.isEnabled,
    )) {
      for (var field in dataSource.fields) {
        fields.add(
          FormulaItem(
            '${dataSource.sourceId}.${field.name}',
            field.displayName,
            '${dataSource.sourceName} • ${field.type}',
          ),
        );
      }
    }
    return fields;
  }

  List<FormulaItem> _getMathOperators() {
    return [
      FormulaItem(' + ', 'Add (+)', 'Addition operator'),
      FormulaItem(' - ', 'Subtract (-)', 'Subtraction operator'),
      FormulaItem(' * ', 'Multiply (×)', 'Multiplication operator'),
      FormulaItem(' / ', 'Divide (÷)', 'Division operator'),
      FormulaItem(' % ', 'Modulo (%)', 'Remainder operator'),
      FormulaItem(' ( ', 'Open Parenthesis', 'Group operations'),
      FormulaItem(' ) ', 'Close Parenthesis', 'End grouping'),
      FormulaItem(' , ', 'Comma', 'Separate parameters'),
    ];
  }

  void _addToFormula(ColumnConfig column, String value) {
    setState(() {
      String currentFormula = column.formula ?? '';
      if (value.contains('{field}')) {
        _showFieldSelectionDialog(column, value);
        return;
      }
      column.formula = currentFormula + value;
      widget.onConfigChanged(widget.config);
    });
  }

  void _showFieldSelectionDialog(ColumnConfig column, String functionTemplate) {
    // Extract function name properly
    String functionName = functionTemplate.contains('(')
        ? functionTemplate.split('(')[0]
        : functionTemplate;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: 400,
          constraints: const BoxConstraints(maxWidth: 450, maxHeight: 600),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Enhanced Header
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Theme.of(context).colorScheme.primary.withOpacity(0.1),
                      Theme.of(context).colorScheme.primary.withOpacity(0.05),
                    ],
                  ),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.functions,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Select Field for $functionName',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Choose the field to use in your formula',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(Icons.close, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),

              // Search Bar
              Padding(
                padding: const EdgeInsets.all(16),
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Search fields...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                  ),
                  onChanged: (value) {
                    // You can implement search functionality here if needed
                    setState(() {
                      // Filter fields based on search
                    });
                  },
                ),
              ),

              // Fields List
              Flexible(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: _getAllAvailableFields().length,
                    separatorBuilder: (context, index) =>
                        Divider(height: 1, color: Colors.grey.shade200),
                    itemBuilder: (context, index) {
                      final field = _getAllAvailableFields()[index];
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        leading: Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: _getFieldTypeColor(field.description ?? ''),
                            shape: BoxShape.circle,
                          ),
                        ),
                        title: Text(
                          field.label,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        subtitle:
                            field.description != null &&
                                field.description!.isNotEmpty
                            ? Text(
                                field.description!,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                              )
                            : null,
                        trailing: Icon(
                          Icons.arrow_forward_ios,
                          size: 14,
                          color: Colors.grey.shade400,
                        ),
                        onTap: () {
                          _selectField(column, functionTemplate, field);
                          Navigator.pop(context);
                        },
                        hoverColor: Theme.of(
                          context,
                        ).colorScheme.primary.withOpacity(0.1),
                      );
                    },
                  ),
                ),
              ),

              // Footer with Cancel Button
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Helper method to handle field selection
  void _selectField(
    ColumnConfig column,
    String functionTemplate,
    FormulaItem field,
  ) {
    setState(() {
      String formula = functionTemplate.replaceAll('{field}', field.value);
      String currentFormula = column.formula ?? '';

      // Add space before the formula if there's already content
      if (currentFormula.isNotEmpty && !currentFormula.endsWith(' ')) {
        currentFormula += ' ';
      }

      column.formula = currentFormula + formula;
      widget.onConfigChanged(widget.config);
    });

    // Show success feedback
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Text('Added ${field.label} to formula'),
          ],
        ),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // Helper method to get color based on field type
  Color _getFieldTypeColor(String description) {
    if (description.toLowerCase().contains('number') ||
        description.toLowerCase().contains('decimal')) {
      return Colors.blue;
    } else if (description.toLowerCase().contains('text') ||
        description.toLowerCase().contains('string')) {
      return Colors.green;
    } else if (description.toLowerCase().contains('date') ||
        description.toLowerCase().contains('time')) {
      return Colors.purple;
    } else {
      return Colors.orange;
    }
  }

  void _clearFormula(ColumnConfig column) {
    setState(() {
      column.formula = '';
      widget.onConfigChanged(widget.config);
    });
  }

  void _validateFormula(ColumnConfig column) {
    String formula = column.formula ?? '';
    if (formula.isEmpty) {
      _showValidationResult('Formula is empty', false);
      return;
    }
    int openCount = '('.allMatches(formula).length;
    int closeCount = ')'.allMatches(formula).length;
    if (openCount != closeCount) {
      _showValidationResult('Unbalanced parentheses', false);
      return;
    }
    List<String> validFunctions = [
      'MAX',
      'MIN',
      'AVG',
      'SUM',
      'COUNT',
      'ROUND',
      'ABS',
      'SQRT',
      'POWER',
    ];
    bool hasValidFunction = validFunctions.any(
      (func) => formula.toUpperCase().contains(func),
    );
    if (!hasValidFunction) {
      _showValidationResult('No valid function found', false);
      return;
    }
    _showValidationResult('Formula syntax is valid', true);
  }

  void _showValidationResult(String message, bool isValid) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isValid ? Icons.check_circle : Icons.error,
              color: Colors.white,
              size: 16,
            ),
            const SizedBox(width: 8),
            Text(message, style: const TextStyle(fontSize: 12)),
          ],
        ),
        backgroundColor: isValid ? Colors.green : Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  List<AvailableField> _getFieldsForDataSource(String dataSourceId) {
    if (dataSourceId.isEmpty) return [];
    final dataSource = widget.config.dataSources
        .where((ds) => ds.sourceId == dataSourceId)
        .firstOrNull;
    return dataSource?.fields ?? [];
  }

  Color _getDataSourceColor(DataSourceType type) {
    switch (type) {
      case DataSourceType.core:
        return Colors.blue;
      case DataSourceType.customField:
        return Colors.purple;
      case DataSourceType.customGroup:
        return Colors.teal;
    }
  }

  IconData _getDataSourceIcon(DataSourceType type) {
    switch (type) {
      case DataSourceType.core:
        return Icons.storage;
      case DataSourceType.customField:
        return Icons.extension;
      case DataSourceType.customGroup:
        return Icons.group_work;
    }
  }

  IconData _getDataTypeIcon(ColumnDataType type) {
    switch (type) {
      case ColumnDataType.text:
        return Icons.text_fields;
      case ColumnDataType.number:
        return Icons.numbers;
      case ColumnDataType.decimal:
        return Icons.calculate;
      case ColumnDataType.percentage:
        return Icons.percent;
      case ColumnDataType.date:
        return Icons.calendar_today;
      case ColumnDataType.time:
        return Icons.access_time;
      case ColumnDataType.datetime:
        return Icons.event;
      case ColumnDataType.computed:
        return Icons.functions;
    }
  }

  Color _getDataTypeColor(ColumnDataType type) {
    switch (type) {
      case ColumnDataType.text:
        return Colors.green;
      case ColumnDataType.number:
      case ColumnDataType.decimal:
        return Colors.blue;
      case ColumnDataType.percentage:
        return Colors.orange;
      case ColumnDataType.date:
      case ColumnDataType.time:
      case ColumnDataType.datetime:
        return Colors.purple;
      case ColumnDataType.computed:
        return Colors.red;
    }
  }

  bool _canAddColumns() {
    return widget.config.dataSources.any((ds) => ds.isEnabled);
  }

  void _addColumn() {
    setState(() {
      widget.config.columns.add(
        ColumnConfig(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          header: '',
          dataSourceId: '',
          fieldPath: '',
          dataType: ColumnDataType.text,
        ),
      );
      widget.onConfigChanged(widget.config);
    });
  }

  void _addGroupHeader() {
    setState(() {
      widget.config.columns.add(
        ColumnConfig(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          header: '',
          dataSourceId: '',
          fieldPath: '',
          dataType: ColumnDataType.text,
          isGroupHeader: true,
          subColumns: [],
        ),
      );
      widget.onConfigChanged(widget.config);
    });
  }

  void _addSubColumn(ColumnConfig parentColumn) {
    setState(() {
      parentColumn.subColumns ??= [];
      final subColumn = ColumnConfig(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        header: '',
        dataSourceId: '',
        fieldPath: '',
        dataType: ColumnDataType.text,
        parentColumn: parentColumn,
        level: parentColumn.level + 1,
      );
      parentColumn.subColumns!.add(subColumn);
      widget.onConfigChanged(widget.config);
    });
  }

  void _removeSubColumn(int parentIndex, int subIndex) {
    setState(() {
      widget.config.columns[parentIndex].subColumns!.removeAt(subIndex);
      widget.onConfigChanged(widget.config);
    });
  }

  void _handleColumnAction(String action, int index) {
    switch (action) {
      case 'duplicate':
        setState(() {
          final originalColumn = widget.config.columns[index];
          final duplicatedColumn = ColumnConfig.fromJson(
            originalColumn.toJson(),
          );
          duplicatedColumn.id = DateTime.now().millisecondsSinceEpoch
              .toString();
          duplicatedColumn.header = '${originalColumn.header} (Copy)';
          widget.config.columns.insert(index + 1, duplicatedColumn);
          widget.onConfigChanged(widget.config);
        });
        break;
      case 'delete':
        setState(() {
          widget.config.columns.removeAt(index);
          widget.onConfigChanged(widget.config);
        });
        break;
    }
  }
}

class FormulaItem {
  final String value;
  final String label;
  final String? description;

  FormulaItem(this.value, this.label, [this.description]);
}

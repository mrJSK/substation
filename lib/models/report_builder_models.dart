// lib/models/report_builder_models.dart

import 'package:cloud_firestore/cloud_firestore.dart';

enum ReportType { tabular, summary, analytical }

enum LayoutOrientation { portrait, landscape }

enum ReportFrequency { hourly, daily, monthly }

enum DataSourceType { core, customField, customGroup }

enum ColumnDataType {
  text,
  number,
  decimal,
  percentage,
  date,
  time,
  datetime,
  computed,
}

class ReportConfiguration {
  // Step 1: Metadata
  String title;
  String? subtitle;
  ReportType type;
  LayoutOrientation orientation;

  // Step 2: Scope
  List<String> substationIds;
  DateTime startDate;
  DateTime endDate;
  ReportFrequency frequency;
  Map<String, dynamic> filters;

  // Step 3: Data Sources
  List<DataSourceConfig> dataSources;
  List<CustomFieldConfig> customFields;

  // Step 4: Columns
  List<ColumnConfig> columns;

  // Step 5: Rows
  RowConfiguration rowConfig;

  // Step 6-7: Output
  PreviewData? preview;
  TemplateMetadata? templateInfo;

  ReportConfiguration({
    this.title = '',
    this.subtitle,
    this.type = ReportType.tabular,
    this.orientation = LayoutOrientation.portrait,
    List<String>? substationIds, // Made nullable parameter
    DateTime? startDate,
    DateTime? endDate,
    this.frequency = ReportFrequency.daily,
    Map<String, dynamic>? filters, // Made nullable parameter
    List<DataSourceConfig>? dataSources, // Made nullable parameter
    List<CustomFieldConfig>? customFields, // Made nullable parameter
    List<ColumnConfig>? columns, // Made nullable parameter
    RowConfiguration? rowConfig,
    this.preview,
    this.templateInfo,
  }) : // Create mutable lists/maps instead of const ones
       substationIds = List<String>.from(substationIds ?? []),
       startDate =
           startDate ?? DateTime.now().subtract(const Duration(days: 7)),
       endDate = endDate ?? DateTime.now(),
       filters = Map<String, dynamic>.from(filters ?? {}),
       dataSources = List<DataSourceConfig>.from(dataSources ?? []),
       customFields = List<CustomFieldConfig>.from(customFields ?? []),
       columns = List<ColumnConfig>.from(columns ?? []),
       rowConfig = rowConfig ?? RowConfiguration();

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'subtitle': subtitle,
      'type': type.index,
      'orientation': orientation.index,
      'substationIds': substationIds,
      'startDate': Timestamp.fromDate(startDate),
      'endDate': Timestamp.fromDate(endDate),
      'frequency': frequency.index,
      'filters': filters,
      'dataSources': dataSources.map((ds) => ds.toJson()).toList(),
      'customFields': customFields.map((cf) => cf.toJson()).toList(),
      'columns': columns.map((col) => col.toJson()).toList(),
      'rowConfig': rowConfig.toJson(),
      'templateInfo': templateInfo?.toJson(),
    };
  }

  factory ReportConfiguration.fromJson(Map<String, dynamic> json) {
    return ReportConfiguration(
      title: json['title'] ?? '',
      subtitle: json['subtitle'],
      type: ReportType.values[json['type'] ?? 0],
      orientation: LayoutOrientation.values[json['orientation'] ?? 0],
      substationIds: List<String>.from(json['substationIds'] ?? []),
      startDate: (json['startDate'] as Timestamp).toDate(),
      endDate: (json['endDate'] as Timestamp).toDate(),
      frequency: ReportFrequency.values[json['frequency'] ?? 0],
      filters: Map<String, dynamic>.from(json['filters'] ?? {}),
      dataSources: (json['dataSources'] as List? ?? [])
          .map((ds) => DataSourceConfig.fromJson(ds))
          .toList(),
      customFields: (json['customFields'] as List? ?? [])
          .map((cf) => CustomFieldConfig.fromJson(cf))
          .toList(),
      columns: (json['columns'] as List? ?? [])
          .map((col) => ColumnConfig.fromJson(col))
          .toList(),
      rowConfig: json['rowConfig'] != null
          ? RowConfiguration.fromJson(json['rowConfig'])
          : RowConfiguration(),
      templateInfo: json['templateInfo'] != null
          ? TemplateMetadata.fromJson(json['templateInfo'])
          : null,
    );
  }

  // Additional helper methods for better list management
  void addSubstationId(String id) {
    if (!substationIds.contains(id)) {
      substationIds.add(id);
    }
  }

  void removeSubstationId(String id) {
    substationIds.remove(id);
  }

  void clearSubstationIds() {
    substationIds.clear();
  }

  void setSubstationIds(List<String> ids) {
    substationIds.clear();
    substationIds.addAll(ids);
  }

  void addDataSource(DataSourceConfig dataSource) {
    if (!dataSources.any((ds) => ds.sourceId == dataSource.sourceId)) {
      dataSources.add(dataSource);
    }
  }

  void removeDataSource(String sourceId) {
    dataSources.removeWhere((ds) => ds.sourceId == sourceId);
  }

  void addColumn(ColumnConfig column) {
    columns.add(column);
  }

  void removeColumn(String columnId) {
    columns.removeWhere((col) => col.id == columnId);
  }

  void reorderColumns(int oldIndex, int newIndex) {
    if (newIndex > oldIndex) newIndex -= 1;
    final column = columns.removeAt(oldIndex);
    columns.insert(newIndex, column);
  }

  // Validation helpers
  bool get isValid {
    return title.isNotEmpty &&
        substationIds.isNotEmpty &&
        dataSources.any((ds) => ds.isEnabled) &&
        columns.isNotEmpty;
  }

  List<String> get validationErrors {
    List<String> errors = [];

    if (title.trim().isEmpty) {
      errors.add('Report title is required');
    }

    if (substationIds.isEmpty) {
      errors.add('At least one substation must be selected');
    }

    if (!dataSources.any((ds) => ds.isEnabled)) {
      errors.add('At least one data source must be enabled');
    }

    if (columns.isEmpty) {
      errors.add('At least one column must be configured');
    }

    return errors;
  }

  // Copy method for creating modified instances
  ReportConfiguration copyWith({
    String? title,
    String? subtitle,
    ReportType? type,
    LayoutOrientation? orientation,
    List<String>? substationIds,
    DateTime? startDate,
    DateTime? endDate,
    ReportFrequency? frequency,
    Map<String, dynamic>? filters,
    List<DataSourceConfig>? dataSources,
    List<CustomFieldConfig>? customFields,
    List<ColumnConfig>? columns,
    RowConfiguration? rowConfig,
    PreviewData? preview,
    TemplateMetadata? templateInfo,
  }) {
    return ReportConfiguration(
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      type: type ?? this.type,
      orientation: orientation ?? this.orientation,
      substationIds: substationIds ?? List<String>.from(this.substationIds),
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      frequency: frequency ?? this.frequency,
      filters: filters ?? Map<String, dynamic>.from(this.filters),
      dataSources: dataSources ?? List<DataSourceConfig>.from(this.dataSources),
      customFields:
          customFields ?? List<CustomFieldConfig>.from(this.customFields),
      columns: columns ?? List<ColumnConfig>.from(this.columns),
      rowConfig: rowConfig ?? this.rowConfig,
      preview: preview ?? this.preview,
      templateInfo: templateInfo ?? this.templateInfo,
    );
  }
}

class DataSourceConfig {
  String sourceId;
  String sourceName;
  DataSourceType type;
  bool isEnabled;
  Map<String, dynamic> sourceSpecificConfig;
  List<AvailableField> fields;

  DataSourceConfig({
    required this.sourceId,
    required this.sourceName,
    required this.type,
    this.isEnabled = false,
    this.sourceSpecificConfig = const {},
    this.fields = const [],
  });

  Map<String, dynamic> toJson() {
    return {
      'sourceId': sourceId,
      'sourceName': sourceName,
      'type': type.index,
      'isEnabled': isEnabled,
      'sourceSpecificConfig': sourceSpecificConfig,
      'fields': fields.map((f) => f.toJson()).toList(),
    };
  }

  factory DataSourceConfig.fromJson(Map<String, dynamic> json) {
    return DataSourceConfig(
      sourceId: json['sourceId'] ?? '',
      sourceName: json['sourceName'] ?? '',
      type: DataSourceType.values[json['type'] ?? 0],
      isEnabled: json['isEnabled'] ?? false,
      sourceSpecificConfig: Map<String, dynamic>.from(
        json['sourceSpecificConfig'] ?? {},
      ),
      fields: (json['fields'] as List? ?? [])
          .map((f) => AvailableField.fromJson(f))
          .toList(),
    );
  }
}

class ColumnConfig {
  String id;
  String header;
  String dataSourceId;
  String fieldPath;
  ColumnDataType dataType;
  String? formula;
  int width;
  bool isGroupHeader;
  List<ColumnConfig>? subColumns;
  ColumnConfig? parentColumn;
  int level;
  DisplayFormat format;

  ColumnConfig({
    required this.id,
    required this.header,
    required this.dataSourceId,
    required this.fieldPath,
    required this.dataType,
    this.formula,
    this.width = 10,
    this.isGroupHeader = false,
    this.subColumns,
    this.parentColumn,
    this.level = 0,
    DisplayFormat? format,
  }) : format = format ?? DisplayFormat();

  String getColumnKey() {
    if (parentColumn != null) {
      return '${parentColumn!.header}_$header';
    }
    return header;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'header': header,
      'dataSourceId': dataSourceId,
      'fieldPath': fieldPath,
      'dataType': dataType.index,
      'formula': formula,
      'width': width,
      'isGroupHeader': isGroupHeader,
      'level': level,
      'format': format.toJson(),
      'subColumns': subColumns?.map((col) => col.toJson()).toList(),
    };
  }

  factory ColumnConfig.fromJson(Map<String, dynamic> json) {
    final column = ColumnConfig(
      id: json['id'] ?? '',
      header: json['header'] ?? '',
      dataSourceId: json['dataSourceId'] ?? '',
      fieldPath: json['fieldPath'] ?? '',
      dataType: ColumnDataType.values[json['dataType'] ?? 0],
      formula: json['formula'],
      width: json['width'] ?? 10,
      isGroupHeader: json['isGroupHeader'] ?? false,
      level: json['level'] ?? 0,
      format: json['format'] != null
          ? DisplayFormat.fromJson(json['format'])
          : DisplayFormat(),
    );

    if (json['subColumns'] != null) {
      column.subColumns = (json['subColumns'] as List)
          .map((subJson) => ColumnConfig.fromJson(subJson))
          .toList();

      for (var subColumn in column.subColumns!) {
        subColumn.parentColumn = column;
      }
    }

    return column;
  }
}

class RowConfiguration {
  String primaryDataSource;
  List<GroupingRule> groupingRules;
  List<FilterRule> filterRules;
  List<SortRule> sortRules;
  AggregationConfig aggregationConfig;

  RowConfiguration({
    this.primaryDataSource = '',
    this.groupingRules = const [],
    this.filterRules = const [],
    this.sortRules = const [],
    AggregationConfig? aggregationConfig,
  }) : aggregationConfig = aggregationConfig ?? AggregationConfig();

  Map<String, dynamic> toJson() {
    return {
      'primaryDataSource': primaryDataSource,
      'groupingRules': groupingRules.map((gr) => gr.toJson()).toList(),
      'filterRules': filterRules.map((fr) => fr.toJson()).toList(),
      'sortRules': sortRules.map((sr) => sr.toJson()).toList(),
      'aggregationConfig': aggregationConfig.toJson(),
    };
  }

  factory RowConfiguration.fromJson(Map<String, dynamic> json) {
    return RowConfiguration(
      primaryDataSource: json['primaryDataSource'] ?? '',
      groupingRules: (json['groupingRules'] as List? ?? [])
          .map((gr) => GroupingRule.fromJson(gr))
          .toList(),
      filterRules: (json['filterRules'] as List? ?? [])
          .map((fr) => FilterRule.fromJson(fr))
          .toList(),
      sortRules: (json['sortRules'] as List? ?? [])
          .map((sr) => SortRule.fromJson(sr))
          .toList(),
      aggregationConfig: json['aggregationConfig'] != null
          ? AggregationConfig.fromJson(json['aggregationConfig'])
          : AggregationConfig(),
    );
  }
}

class AvailableField {
  String name;
  String displayName;
  String type;
  String path;
  String dataSourceId;

  AvailableField({
    required this.name,
    required this.displayName,
    required this.type,
    required this.path,
    required this.dataSourceId,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'displayName': displayName,
      'type': type,
      'path': path,
      'dataSourceId': dataSourceId,
    };
  }

  factory AvailableField.fromJson(Map<String, dynamic> json) {
    return AvailableField(
      name: json['name'] ?? '',
      displayName: json['displayName'] ?? '',
      type: json['type'] ?? '',
      path: json['path'] ?? '',
      dataSourceId: json['dataSourceId'] ?? '',
    );
  }
}

class CustomFieldConfig {
  String id;
  String name;
  String displayName;
  String formula;
  ColumnDataType dataType;

  CustomFieldConfig({
    required this.id,
    required this.name,
    required this.displayName,
    required this.formula,
    required this.dataType,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'displayName': displayName,
      'formula': formula,
      'dataType': dataType.index,
    };
  }

  factory CustomFieldConfig.fromJson(Map<String, dynamic> json) {
    return CustomFieldConfig(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      displayName: json['displayName'] ?? '',
      formula: json['formula'] ?? '',
      dataType: ColumnDataType.values[json['dataType'] ?? 0],
    );
  }
}

class DisplayFormat {
  String? numberFormat;
  String? dateFormat;
  String? prefix;
  String? suffix;
  int? decimalPlaces;

  DisplayFormat({
    this.numberFormat,
    this.dateFormat,
    this.prefix,
    this.suffix,
    this.decimalPlaces,
  });

  Map<String, dynamic> toJson() {
    return {
      'numberFormat': numberFormat,
      'dateFormat': dateFormat,
      'prefix': prefix,
      'suffix': suffix,
      'decimalPlaces': decimalPlaces,
    };
  }

  factory DisplayFormat.fromJson(Map<String, dynamic> json) {
    return DisplayFormat(
      numberFormat: json['numberFormat'],
      dateFormat: json['dateFormat'],
      prefix: json['prefix'],
      suffix: json['suffix'],
      decimalPlaces: json['decimalPlaces'],
    );
  }
}

class GroupingRule {
  String fieldPath;
  String groupType;

  GroupingRule({required this.fieldPath, required this.groupType});

  Map<String, dynamic> toJson() => {
    'fieldPath': fieldPath,
    'groupType': groupType,
  };
  factory GroupingRule.fromJson(Map<String, dynamic> json) => GroupingRule(
    fieldPath: json['fieldPath'] ?? '',
    groupType: json['groupType'] ?? '',
  );
}

class FilterRule {
  String fieldPath;
  String operator;
  dynamic value;

  FilterRule({
    required this.fieldPath,
    required this.operator,
    required this.value,
  });

  Map<String, dynamic> toJson() => {
    'fieldPath': fieldPath,
    'operator': operator,
    'value': value,
  };
  factory FilterRule.fromJson(Map<String, dynamic> json) => FilterRule(
    fieldPath: json['fieldPath'] ?? '',
    operator: json['operator'] ?? '',
    value: json['value'],
  );
}

class SortRule {
  String fieldPath;
  bool ascending;

  SortRule({required this.fieldPath, this.ascending = true});

  Map<String, dynamic> toJson() => {
    'fieldPath': fieldPath,
    'ascending': ascending,
  };
  factory SortRule.fromJson(Map<String, dynamic> json) => SortRule(
    fieldPath: json['fieldPath'] ?? '',
    ascending: json['ascending'] ?? true,
  );
}

class AggregationConfig {
  bool enableSubtotals;
  bool enableGrandTotal;
  List<String> aggregationFields;

  AggregationConfig({
    this.enableSubtotals = false,
    this.enableGrandTotal = false,
    this.aggregationFields = const [],
  });

  Map<String, dynamic> toJson() {
    return {
      'enableSubtotals': enableSubtotals,
      'enableGrandTotal': enableGrandTotal,
      'aggregationFields': aggregationFields,
    };
  }

  factory AggregationConfig.fromJson(Map<String, dynamic> json) {
    return AggregationConfig(
      enableSubtotals: json['enableSubtotals'] ?? false,
      enableGrandTotal: json['enableGrandTotal'] ?? false,
      aggregationFields: List<String>.from(json['aggregationFields'] ?? []),
    );
  }
}

class PreviewData {
  List<Map<String, dynamic>> sampleRows;
  int totalEstimatedRows;
  DateTime generatedAt;

  PreviewData({
    required this.sampleRows,
    required this.totalEstimatedRows,
    required this.generatedAt,
  });
}

class TemplateMetadata {
  String name;
  String? description;
  String createdBy;
  DateTime createdAt;
  List<String> tags;

  TemplateMetadata({
    required this.name,
    this.description,
    required this.createdBy,
    required this.createdAt,
    this.tags = const [],
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'description': description,
      'createdBy': createdBy,
      'createdAt': Timestamp.fromDate(createdAt),
      'tags': tags,
    };
  }

  factory TemplateMetadata.fromJson(Map<String, dynamic> json) {
    return TemplateMetadata(
      name: json['name'] ?? '',
      description: json['description'],
      createdBy: json['createdBy'] ?? '',
      createdAt: (json['createdAt'] as Timestamp).toDate(),
      tags: List<String>.from(json['tags'] ?? []),
    );
  }
}

class ValidationResult {
  bool isValid;
  String? errorMessage;
  List<String> warnings;

  ValidationResult({
    required this.isValid,
    this.errorMessage,
    this.warnings = const [],
  });

  factory ValidationResult.success() => ValidationResult(isValid: true);
  factory ValidationResult.error(String message) =>
      ValidationResult(isValid: false, errorMessage: message);
  factory ValidationResult.warning(String message) =>
      ValidationResult(isValid: true, warnings: [message]);
}

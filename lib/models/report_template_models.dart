// lib/models/report_template_models.dart

import 'package:cloud_firestore/cloud_firestore.dart';

class ReportTemplate {
  String id;
  String name;
  String description;
  DateTime createdAt;
  String createdBy;
  List<DataSource> dataSources;
  List<HeaderLevel> headerLevels;
  Map<String, DynamicFieldMapping> fieldMappings;
  List<ComputedColumn> computedColumns;
  ReportFormatting formatting;
  PeriodConfiguration periodConfig;
  bool isPublic;
  List<String> sharedWith;

  ReportTemplate({
    required this.id,
    required this.name,
    required this.description,
    required this.createdAt,
    required this.createdBy,
    required this.dataSources,
    required this.headerLevels,
    required this.fieldMappings,
    required this.computedColumns,
    required this.formatting,
    required this.periodConfig,
    this.isPublic = false,
    this.sharedWith = const [],
  });

  factory ReportTemplate.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ReportTemplate(
      id: doc.id,
      name: data['name'] ?? '',
      description: data['description'] ?? '',
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      createdBy: data['createdBy'] ?? '',
      dataSources: (data['dataSources'] as List<dynamic>? ?? [])
          .map((item) => DataSource.fromMap(item as Map<String, dynamic>))
          .toList(),
      headerLevels: (data['headerLevels'] as List<dynamic>? ?? [])
          .map((item) => HeaderLevel.fromMap(item as Map<String, dynamic>))
          .toList(),
      fieldMappings: Map<String, DynamicFieldMapping>.from(
        (data['fieldMappings'] as Map<String, dynamic>? ?? {}).map(
          (key, value) => MapEntry(
            key,
            DynamicFieldMapping.fromMap(value as Map<String, dynamic>),
          ),
        ),
      ),
      computedColumns: (data['computedColumns'] as List<dynamic>? ?? [])
          .map((item) => ComputedColumn.fromMap(item as Map<String, dynamic>))
          .toList(),
      formatting: ReportFormatting.fromMap(
        data['formatting'] as Map<String, dynamic>? ?? {},
      ),
      periodConfig: PeriodConfiguration.fromMap(
        data['periodConfig'] as Map<String, dynamic>? ?? {},
      ),
      isPublic: data['isPublic'] ?? false,
      sharedWith: List<String>.from(data['sharedWith'] ?? []),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'description': description,
      'createdAt': Timestamp.fromDate(createdAt),
      'createdBy': createdBy,
      'dataSources': dataSources.map((item) => item.toMap()).toList(),
      'headerLevels': headerLevels.map((item) => item.toMap()).toList(),
      'fieldMappings': fieldMappings.map(
        (key, value) => MapEntry(key, value.toMap()),
      ),
      'computedColumns': computedColumns.map((item) => item.toMap()).toList(),
      'formatting': formatting.toMap(),
      'periodConfig': periodConfig.toMap(),
      'isPublic': isPublic,
      'sharedWith': sharedWith,
    };
  }

  ReportTemplate copyWith({
    String? id,
    String? name,
    String? description,
    DateTime? createdAt,
    String? createdBy,
    List<DataSource>? dataSources,
    List<HeaderLevel>? headerLevels,
    Map<String, DynamicFieldMapping>? fieldMappings,
    List<ComputedColumn>? computedColumns,
    ReportFormatting? formatting,
    PeriodConfiguration? periodConfig,
    bool? isPublic,
    List<String>? sharedWith,
  }) {
    return ReportTemplate(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
      createdBy: createdBy ?? this.createdBy,
      dataSources: dataSources ?? this.dataSources,
      headerLevels: headerLevels ?? this.headerLevels,
      fieldMappings: fieldMappings ?? this.fieldMappings,
      computedColumns: computedColumns ?? this.computedColumns,
      formatting: formatting ?? this.formatting,
      periodConfig: periodConfig ?? this.periodConfig,
      isPublic: isPublic ?? this.isPublic,
      sharedWith: sharedWith ?? this.sharedWith,
    );
  }
}

class DataSource {
  String id;
  DataSourceType type;
  String displayName;
  List<AvailableField> availableFields;
  Map<String, dynamic> filters;
  String? joinCondition;

  DataSource({
    required this.id,
    required this.type,
    required this.displayName,
    required this.availableFields,
    required this.filters,
    this.joinCondition,
  });

  factory DataSource.fromMap(Map<String, dynamic> map) {
    return DataSource(
      id: map['id'] ?? '',
      type: DataSourceType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => DataSourceType.substations,
      ),
      displayName: map['displayName'] ?? '',
      availableFields: (map['availableFields'] as List<dynamic>? ?? [])
          .map((item) => AvailableField.fromMap(item as Map<String, dynamic>))
          .toList(),
      filters: Map<String, dynamic>.from(map['filters'] ?? {}),
      joinCondition: map['joinCondition'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type.name,
      'displayName': displayName,
      'availableFields': availableFields.map((item) => item.toMap()).toList(),
      'filters': filters,
      'joinCondition': joinCondition,
    };
  }
}

enum DataSourceType {
  substations,
  bays,
  equipments,
  logsheetEntries,
  assessments,
  customCollections,
}

class AvailableField {
  String id;
  String name;
  String path;
  DataType type;
  FieldOrigin origin;
  String? description;
  List<String>? enumValues;
  bool isRequired;
  dynamic defaultValue;

  AvailableField({
    required this.id,
    required this.name,
    required this.path,
    required this.type,
    required this.origin,
    this.description,
    this.enumValues,
    this.isRequired = false,
    this.defaultValue,
  });

  factory AvailableField.fromMap(Map<String, dynamic> map) {
    return AvailableField(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      path: map['path'] ?? '',
      type: DataType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => DataType.string,
      ),
      origin: FieldOrigin.values.firstWhere(
        (e) => e.name == map['origin'],
        orElse: () => FieldOrigin.standard,
      ),
      description: map['description'],
      enumValues: map['enumValues'] != null
          ? List<String>.from(map['enumValues'])
          : null,
      isRequired: map['isRequired'] ?? false,
      defaultValue: map['defaultValue'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'path': path,
      'type': type.name,
      'origin': origin.name,
      'description': description,
      'enumValues': enumValues,
      'isRequired': isRequired,
      'defaultValue': defaultValue,
    };
  }
}

enum DataType { string, number, boolean, date, enum_, object }

enum FieldOrigin { standard, custom, computed }

class HeaderLevel {
  int level;
  List<HeaderCell> cells;
  double height;

  HeaderLevel({required this.level, required this.cells, this.height = 30.0});

  factory HeaderLevel.fromMap(Map<String, dynamic> map) {
    return HeaderLevel(
      level: map['level'] ?? 0,
      cells: (map['cells'] as List<dynamic>? ?? [])
          .map((item) => HeaderCell.fromMap(item as Map<String, dynamic>))
          .toList(),
      height: (map['height'] ?? 30.0).toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'level': level,
      'cells': cells.map((item) => item.toMap()).toList(),
      'height': height,
    };
  }
}

class HeaderCell {
  String id;
  String text;
  int colspan;
  int rowspan;
  String? parentId;
  HeaderCellStyle style;
  int columnIndex;
  int rowIndex;

  HeaderCell({
    required this.id,
    required this.text,
    required this.colspan,
    required this.rowspan,
    this.parentId,
    required this.style,
    required this.columnIndex,
    required this.rowIndex,
  });

  factory HeaderCell.fromMap(Map<String, dynamic> map) {
    return HeaderCell(
      id: map['id'] ?? '',
      text: map['text'] ?? '',
      colspan: map['colspan'] ?? 1,
      rowspan: map['rowspan'] ?? 1,
      parentId: map['parentId'],
      style: HeaderCellStyle.fromMap(
        map['style'] as Map<String, dynamic>? ?? {},
      ),
      columnIndex: map['columnIndex'] ?? 0,
      rowIndex: map['rowIndex'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'text': text,
      'colspan': colspan,
      'rowspan': rowspan,
      'parentId': parentId,
      'style': style.toMap(),
      'columnIndex': columnIndex,
      'rowIndex': rowIndex,
    };
  }
}

class HeaderCellStyle {
  String backgroundColor;
  String textColor;
  String fontFamily;
  double fontSize;
  bool bold;
  bool italic;
  String alignment;
  String borderStyle;
  String borderColor;

  HeaderCellStyle({
    this.backgroundColor = '#FFFFFF',
    this.textColor = '#000000',
    this.fontFamily = 'Arial',
    this.fontSize = 12,
    this.bold = false,
    this.italic = false,
    this.alignment = 'center',
    this.borderStyle = 'thin',
    this.borderColor = '#000000',
  });

  factory HeaderCellStyle.fromMap(Map<String, dynamic> map) {
    return HeaderCellStyle(
      backgroundColor: map['backgroundColor'] ?? '#FFFFFF',
      textColor: map['textColor'] ?? '#000000',
      fontFamily: map['fontFamily'] ?? 'Arial',
      fontSize: (map['fontSize'] ?? 12).toDouble(),
      bold: map['bold'] ?? false,
      italic: map['italic'] ?? false,
      alignment: map['alignment'] ?? 'center',
      borderStyle: map['borderStyle'] ?? 'thin',
      borderColor: map['borderColor'] ?? '#000000',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'backgroundColor': backgroundColor,
      'textColor': textColor,
      'fontFamily': fontFamily,
      'fontSize': fontSize,
      'bold': bold,
      'italic': italic,
      'alignment': alignment,
      'borderStyle': borderStyle,
      'borderColor': borderColor,
    };
  }
}

class DynamicFieldMapping {
  String fieldId;
  String displayName;
  String sourcePath;
  DataType dataType;
  String? formula;
  FieldOrigin origin;
  String format;
  String? aggregationType;
  int columnIndex;
  bool isVisible;

  DynamicFieldMapping({
    required this.fieldId,
    required this.displayName,
    required this.sourcePath,
    required this.dataType,
    this.formula,
    required this.origin,
    required this.format,
    this.aggregationType,
    required this.columnIndex,
    this.isVisible = true,
  });

  factory DynamicFieldMapping.fromMap(Map<String, dynamic> map) {
    return DynamicFieldMapping(
      fieldId: map['fieldId'] ?? '',
      displayName: map['displayName'] ?? '',
      sourcePath: map['sourcePath'] ?? '',
      dataType: DataType.values.firstWhere(
        (e) => e.name == map['dataType'],
        orElse: () => DataType.string,
      ),
      formula: map['formula'],
      origin: FieldOrigin.values.firstWhere(
        (e) => e.name == map['origin'],
        orElse: () => FieldOrigin.standard,
      ),
      format: map['format'] ?? '',
      aggregationType: map['aggregationType'],
      columnIndex: map['columnIndex'] ?? 0,
      isVisible: map['isVisible'] ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'fieldId': fieldId,
      'displayName': displayName,
      'sourcePath': sourcePath,
      'dataType': dataType.name,
      'formula': formula,
      'origin': origin.name,
      'format': format,
      'aggregationType': aggregationType,
      'columnIndex': columnIndex,
      'isVisible': isVisible,
    };
  }
}

class ComputedColumn {
  String id;
  String name;
  String formula;
  List<String> dependencies;
  DataType resultType;
  String format;
  int columnIndex;

  ComputedColumn({
    required this.id,
    required this.name,
    required this.formula,
    required this.dependencies,
    required this.resultType,
    required this.format,
    required this.columnIndex,
  });

  factory ComputedColumn.fromMap(Map<String, dynamic> map) {
    return ComputedColumn(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      formula: map['formula'] ?? '',
      dependencies: List<String>.from(map['dependencies'] ?? []),
      resultType: DataType.values.firstWhere(
        (e) => e.name == map['resultType'],
        orElse: () => DataType.string,
      ),
      format: map['format'] ?? '',
      columnIndex: map['columnIndex'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'formula': formula,
      'dependencies': dependencies,
      'resultType': resultType.name,
      'format': format,
      'columnIndex': columnIndex,
    };
  }
}

class ReportFormatting {
  String fontFamily;
  double fontSize;
  String backgroundColor;
  String textColor;
  bool alternateRowColors;
  String alternateColor;
  bool showGridLines;
  String gridLineColor;
  double rowHeight;

  ReportFormatting({
    this.fontFamily = 'Arial',
    this.fontSize = 10,
    this.backgroundColor = '#FFFFFF',
    this.textColor = '#000000',
    this.alternateRowColors = true,
    this.alternateColor = '#F8F9FA',
    this.showGridLines = true,
    this.gridLineColor = '#CCCCCC',
    this.rowHeight = 20.0,
  });

  factory ReportFormatting.fromMap(Map<String, dynamic> map) {
    return ReportFormatting(
      fontFamily: map['fontFamily'] ?? 'Arial',
      fontSize: (map['fontSize'] ?? 10).toDouble(),
      backgroundColor: map['backgroundColor'] ?? '#FFFFFF',
      textColor: map['textColor'] ?? '#000000',
      alternateRowColors: map['alternateRowColors'] ?? true,
      alternateColor: map['alternateColor'] ?? '#F8F9FA',
      showGridLines: map['showGridLines'] ?? true,
      gridLineColor: map['gridLineColor'] ?? '#CCCCCC',
      rowHeight: (map['rowHeight'] ?? 20.0).toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'fontFamily': fontFamily,
      'fontSize': fontSize,
      'backgroundColor': backgroundColor,
      'textColor': textColor,
      'alternateRowColors': alternateRowColors,
      'alternateColor': alternateColor,
      'showGridLines': showGridLines,
      'gridLineColor': gridLineColor,
      'rowHeight': rowHeight,
    };
  }
}

class PeriodConfiguration {
  String defaultPeriod;
  bool allowCustomRange;
  List<String> availablePeriods;
  DateTime? fixedStartDate;
  DateTime? fixedEndDate;

  PeriodConfiguration({
    this.defaultPeriod = 'monthly',
    this.allowCustomRange = true,
    this.availablePeriods = const [
      'daily',
      'weekly',
      'monthly',
      'quarterly',
      'yearly',
    ],
    this.fixedStartDate,
    this.fixedEndDate,
  });

  factory PeriodConfiguration.fromMap(Map<String, dynamic> map) {
    return PeriodConfiguration(
      defaultPeriod: map['defaultPeriod'] ?? 'monthly',
      allowCustomRange: map['allowCustomRange'] ?? true,
      availablePeriods: List<String>.from(
        map['availablePeriods'] ??
            ['daily', 'weekly', 'monthly', 'quarterly', 'yearly'],
      ),
      fixedStartDate: map['fixedStartDate'] != null
          ? (map['fixedStartDate'] as Timestamp).toDate()
          : null,
      fixedEndDate: map['fixedEndDate'] != null
          ? (map['fixedEndDate'] as Timestamp).toDate()
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'defaultPeriod': defaultPeriod,
      'allowCustomRange': allowCustomRange,
      'availablePeriods': availablePeriods,
      'fixedStartDate': fixedStartDate != null
          ? Timestamp.fromDate(fixedStartDate!)
          : null,
      'fixedEndDate': fixedEndDate != null
          ? Timestamp.fromDate(fixedEndDate!)
          : null,
    };
  }
}

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ==================== ENUMS & EXTENSIONS ====================

enum MergeTableAlignment {
  centerLeft,
  centerRight,
  bottomLeft,
  bottomRight,
  topLeft,
  topRight,
  center,
}

extension MergeTableAlignmentExtension on MergeTableAlignment {
  Alignment get geometry {
    switch (this) {
      case MergeTableAlignment.centerLeft:
        return Alignment.centerLeft;
      case MergeTableAlignment.centerRight:
        return Alignment.centerRight;
      case MergeTableAlignment.bottomLeft:
        return Alignment.bottomLeft;
      case MergeTableAlignment.bottomRight:
        return Alignment.bottomRight;
      case MergeTableAlignment.topLeft:
        return Alignment.topLeft;
      case MergeTableAlignment.topRight:
        return Alignment.topRight;
      case MergeTableAlignment.center:
        return Alignment.center;
    }
  }

  TableCellVerticalAlignment get tableAlignment {
    switch (this) {
      case MergeTableAlignment.centerLeft:
      case MergeTableAlignment.centerRight:
      case MergeTableAlignment.center:
        return TableCellVerticalAlignment.middle;
      case MergeTableAlignment.bottomLeft:
      case MergeTableAlignment.bottomRight:
        return TableCellVerticalAlignment.bottom;
      case MergeTableAlignment.topRight:
      case MergeTableAlignment.topLeft:
        return TableCellVerticalAlignment.top;
    }
  }
}

// ==================== BASE COLUMN CLASSES ====================

abstract class BaseMColumn {
  final String header;
  final List<String>? columns;
  bool get isMergedColumn => columns != null;

  BaseMColumn({required this.header, this.columns});
}

class MColumn extends BaseMColumn {
  MColumn({required String header}) : super(header: header, columns: null);
}

class MMergedColumns extends BaseMColumn {
  @override
  List<String> get columns => super.columns!;

  MMergedColumns({required String header, required List<String> columns})
    : super(columns: columns, header: header);
}

// ==================== BASE ROW CLASSES ====================

abstract class BaseMRow {
  final List<Widget> inlineRow;
  BaseMRow(this.inlineRow);
}

class MRow extends BaseMRow {
  MRow(Widget rowValue) : super([rowValue]);
}

class MMergedRows extends BaseMRow {
  MMergedRows(List<Widget> mergedRowValues) : super(mergedRowValues);
}

// ==================== HELPER CLASSES ====================

class CellFormat {
  double width;
  double height;
  double fontSize;
  bool textWrap;

  CellFormat({
    this.width = 100.0,
    this.height = 40.0,
    this.fontSize = 14.0,
    this.textWrap = false,
  });

  Map<String, dynamic> toMap() => {
    'width': width,
    'height': height,
    'fontSize': fontSize,
    'textWrap': textWrap,
  };

  static CellFormat fromMap(Map<String, dynamic> map) => CellFormat(
    width: map['width'] ?? 100.0,
    height: map['height'] ?? 40.0,
    fontSize: map['fontSize'] ?? 14.0,
    textWrap: map['textWrap'] ?? false,
  );
}

class MergeInfo {
  final int row1, col1, row2, col2;

  MergeInfo({
    required this.row1,
    required this.col1,
    required this.row2,
    required this.col2,
  });

  Map<String, dynamic> toMap() => {
    'row1': row1,
    'col1': col1,
    'row2': row2,
    'col2': col2,
  };

  static MergeInfo fromMap(Map<String, dynamic> m) => MergeInfo(
    row1: m['row1'] ?? 0,
    col1: m['col1'] ?? 0,
    row2: m['row2'] ?? 0,
    col2: m['col2'] ?? 0,
  );

  bool overlaps(MergeInfo other) {
    return !(row2 < other.row1 ||
        row1 > other.row2 ||
        col2 < other.col1 ||
        col1 > other.col2);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MergeInfo &&
          row1 == other.row1 &&
          col1 == other.col1 &&
          row2 == other.row2 &&
          col2 == other.col2;

  @override
  int get hashCode =>
      row1.hashCode ^ col1.hashCode ^ row2.hashCode ^ col2.hashCode;
}

// ==================== ORIGINAL MERGE TABLE ====================

class MergeTable extends StatelessWidget {
  MergeTable({
    Key? key,
    required this.rows,
    required this.columns,
    required this.borderColor,
    this.rowHeight,
    this.alignment = MergeTableAlignment.center,
  }) : super(key: key) {
    columnWidths = fetchColumnWidths(columns);
    assert(columns.isNotEmpty);
    assert(rows.isNotEmpty);
    for (List<BaseMRow> row in rows) {
      assert(row.length == columns.length);
    }
  }

  final Color borderColor;
  final List<BaseMColumn> columns;
  final List<List<BaseMRow>> rows;
  final MergeTableAlignment alignment;
  final double? rowHeight;
  late final Map<int, TableColumnWidth> columnWidths;

  TableCellVerticalAlignment get defaultVerticalAlignment =>
      alignment.tableAlignment;
  AlignmentGeometry get alignmentGeometry => alignment.geometry;

  @override
  Widget build(BuildContext context) {
    return Table(
      border: TableBorder.all(color: borderColor),
      columnWidths: columnWidths,
      defaultVerticalAlignment: defaultVerticalAlignment,
      children: [buildHeader(), ...buildRows()],
    );
  }

  TableRow buildHeader() {
    return TableRow(
      children: List.generate(columns.length, (index) {
        BaseMColumn column = columns[index];
        if (column.columns != null) {
          return buildMergedColumn(column);
        } else {
          return buildSingleColumn(column.header);
        }
      }),
    );
  }

  List<TableRow> buildRows() {
    return List.generate(rows.length, (index) {
      List<BaseMRow> values = rows[index];
      return TableRow(
        children: List.generate(values.length, (index) {
          BaseMRow item = values[index];
          bool isMergedColumn = item.inlineRow.length > 1;
          if (isMergedColumn) {
            return buildMutiColumns(item.inlineRow);
          } else {
            return buildAlign(item.inlineRow.first);
          }
        }),
      );
    });
  }

  Widget buildMergedColumn(BaseMColumn column) {
    return Column(
      children: [
        buildSingleColumn(column.header),
        Divider(color: borderColor, height: 1, thickness: 1),
        buildMutiColumns(
          List.generate(column.columns!.length, (index) {
            return buildSingleColumn(column.columns![index]);
          }),
        ),
      ],
    );
  }

  Widget buildMutiColumns(List<Widget> values) {
    return LayoutBuilder(
      builder: (context, constraint) {
        List<Widget> children = List.generate(values.length, (index) {
          Widget value = values[index];
          double spaceForBorder = (values.length - 1) / values.length;
          return SizedBox(
            width: constraint.maxWidth / values.length - spaceForBorder,
            child: buildAlign(value),
          );
        });
        return Container(
          height: rowHeight,
          child: IntrinsicHeight(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (Widget child in children.take(children.length - 1)) ...[
                  child,
                  VerticalDivider(width: 1, color: borderColor, thickness: 1),
                ],
                children.last,
              ],
            ),
          ),
        );
      },
    );
  }

  Widget buildSingleColumn(String title) {
    return buildAlign(Text(title));
  }

  Widget buildAlign(Widget child) {
    return Container(alignment: alignmentGeometry, child: child);
  }

  Map<int, TableColumnWidth> fetchColumnWidths(List<BaseMColumn> columns) {
    Map<int, TableColumnWidth> columnWidths = {};
    double flexPerColumn = 1 / columns.length;
    for (int i = 0; i < columns.length; i++) {
      BaseMColumn column = columns[i];
      if (column.isMergedColumn) {
        columnWidths[i] = FlexColumnWidth(
          flexPerColumn * column.columns!.length,
        );
      } else {
        columnWidths[i] = FlexColumnWidth(flexPerColumn);
      }
    }
    return columnWidths;
  }
}

// ==================== ENHANCED MERGE TABLE FOR EXCEL BUILDER (FIXED) ====================

class EnhancedMergeTable extends StatelessWidget {
  final int rows;
  final int columns;
  final List<List<TextEditingController>> controllers;
  final List<List<CellFormat>> cellFormats;
  final List<MergeInfo> merges;
  final bool showHeaders;
  final Color borderColor;
  final Function(int row, int col)? onCellTap;
  final bool editable;

  const EnhancedMergeTable({
    Key? key,
    required this.rows,
    required this.columns,
    required this.controllers,
    required this.cellFormats,
    required this.merges,
    this.showHeaders = true,
    this.borderColor = Colors.grey,
    this.onCellTap,
    this.editable = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Base grid structure
        _buildBaseGrid(),
        // Merged cells overlay
        ..._buildMergedCellsOverlay(),
      ],
    );
  }

  Widget _buildBaseGrid() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Column headers
        if (showHeaders) _buildColumnHeaders(),

        // Base table rows
        ..._buildBaseRows(),
      ],
    );
  }

  Widget _buildColumnHeaders() {
    return Row(
      children: [
        // Corner cell
        Container(
          width: 40,
          height: 30,
          decoration: BoxDecoration(
            color: Colors.grey[200],
            border: Border.all(color: borderColor),
          ),
        ),
        // Column headers (A, B, C...)
        ...List.generate(
          columns,
          (j) => Container(
            width: cellFormats[0][j].width,
            height: 30,
            decoration: BoxDecoration(
              color: Colors.grey[200],
              border: Border.all(color: borderColor),
            ),
            child: Center(
              child: Text(
                _getColumnName(j),
                style: GoogleFonts.lora(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  List<Widget> _buildBaseRows() {
    return List.generate(rows, (i) => _buildBaseRow(i));
  }

  Widget _buildBaseRow(int rowIndex) {
    return Row(
      children: [
        // Row header
        if (showHeaders)
          Container(
            width: 40,
            height: cellFormats[rowIndex][0].height,
            decoration: BoxDecoration(
              color: Colors.grey,
              border: Border.all(color: borderColor),
            ),
            child: Center(
              child: Text(
                '${rowIndex + 1}',
                style: GoogleFonts.lora(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ),
          ),
        // Base cells
        ...List.generate(
          columns,
          (j) => Container(
            width: cellFormats[rowIndex][j].width,
            height: cellFormats[rowIndex][j].height,
            decoration: BoxDecoration(
              color: _isCellPartOfMerge(rowIndex, j)
                  ? Colors.transparent
                  : (rowIndex == 0 && showHeaders
                        ? Colors.grey[50]
                        : Colors.white),
              border: Border.all(
                color: _isCellPartOfMerge(rowIndex, j)
                    ? Colors.transparent
                    : borderColor,
              ),
            ),
            child: _isCellPartOfMerge(rowIndex, j)
                ? null // Empty for merged cells
                : Padding(
                    padding: const EdgeInsets.all(4),
                    child: TextField(
                      controller: controllers[rowIndex][j],
                      enabled: editable,
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                      ),
                      style: GoogleFonts.lora(
                        fontSize: cellFormats[rowIndex][j].fontSize,
                        fontWeight: rowIndex == 0 && showHeaders
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: cellFormats[rowIndex][j].textWrap ? null : 1,
                      onTap: onCellTap != null
                          ? () => onCellTap!(rowIndex, j)
                          : null,
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  List<Widget> _buildMergedCellsOverlay() {
    return merges.map((merge) => _buildMergedCellOverlay(merge)).toList();
  }

  Widget _buildMergedCellOverlay(MergeInfo merge) {
    // Calculate position
    double left = showHeaders ? 40 : 0; // Row header width
    double top = showHeaders ? 30 : 0; // Column header height

    // Add widths of columns before merge start
    for (int c = 0; c < merge.col1; c++) {
      left += cellFormats[0][c].width;
    }

    // Add heights of rows before merge start
    for (int r = 0; r < merge.row1; r++) {
      top += cellFormats[r][0].height;
    }

    // Calculate merged cell dimensions
    double width = 0;
    double height = 0;

    for (int c = merge.col1; c <= merge.col2; c++) {
      width += cellFormats[0][c].width;
    }

    for (int r = merge.row1; r <= merge.row2; r++) {
      height += cellFormats[r][0].height;
    }

    return Positioned(
      left: left,
      top: top,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.blue[50],
          border: Border.all(color: Colors.blue!, width: 2),
        ),
        child: Stack(
          children: [
            // Content - always use top-left cell controller
            Padding(
              padding: const EdgeInsets.all(4),
              child: TextField(
                controller: controllers[merge.row1][merge.col1],
                enabled: editable,
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                ),
                style: GoogleFonts.lora(
                  fontSize: cellFormats[merge.row1][merge.col1].fontSize,
                  fontWeight: merge.row1 == 0 && showHeaders
                      ? FontWeight.w600
                      : FontWeight.normal,
                ),
                textAlign: TextAlign.center,
                maxLines: cellFormats[merge.row1][merge.col1].textWrap
                    ? null
                    : 1,
                onTap: onCellTap != null
                    ? () => onCellTap!(merge.row1, merge.col1)
                    : null,
              ),
            ),
            // Merge indicator
            Positioned(
              top: 2,
              right: 2,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                decoration: BoxDecoration(
                  color: Colors.blue[100],
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${merge.row2 - merge.row1 + 1}×${merge.col2 - merge.col1 + 1}',
                  style: GoogleFonts.lora(
                    fontSize: 8,
                    color: Colors.blue[700],
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  MergeInfo? _findMergeForCell(int row, int col) {
    for (MergeInfo merge in merges) {
      if (row >= merge.row1 &&
          row <= merge.row2 &&
          col >= merge.col1 &&
          col <= merge.col2) {
        return merge;
      }
    }
    return null;
  }

  bool _isCellPartOfMerge(int row, int col) {
    return _findMergeForCell(row, col) != null;
  }

  String _getColumnName(int index) {
    String result = '';
    int temp = index;
    while (temp >= 0) {
      result = String.fromCharCode(65 + (temp % 26)) + result;
      temp = (temp ~/ 26) - 1;
    }
    return result;
  }
}

// ==================== SIMPLE MERGE TABLE BUILDER ====================

class SimpleMergeTableBuilder {
  static Widget buildBasicTable({
    required List<List<String>> data,
    List<String>? headers,
    Color borderColor = Colors.grey,
    MergeTableAlignment alignment = MergeTableAlignment.center,
  }) {
    List<BaseMColumn> columns = [];

    if (headers != null) {
      columns = headers.map((header) => MColumn(header: header)).toList();
    } else {
      columns = List.generate(
        data.isNotEmpty ? data[0].length : 0,
        (index) => MColumn(header: 'Column ${index + 1}'),
      );
    }

    List<List<BaseMRow>> rows = data
        .map((row) => row.map((cell) => MRow(Text(cell))).toList())
        .toList();

    return MergeTable(
      borderColor: borderColor,
      alignment: alignment,
      columns: columns,
      rows: rows,
    );
  }
}

// ==================== ALTERNATIVE: EXCEL-LIKE TABLE (for comparison) ====================

class ExcelLikeTable extends StatelessWidget {
  final int rows;
  final int columns;
  final List<List<TextEditingController>> controllers;
  final List<List<CellFormat>> cellFormats;
  final List<MergeInfo> merges;
  final bool showHeaders;
  final Color borderColor;

  const ExcelLikeTable({
    Key? key,
    required this.rows,
    required this.columns,
    required this.controllers,
    required this.cellFormats,
    required this.merges,
    this.showHeaders = true,
    this.borderColor = Colors.grey,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(border: Border.all(color: borderColor)),
      child: Column(
        children: [if (showHeaders) _buildHeaders(), ..._buildRows()],
      ),
    );
  }

  Widget _buildHeaders() {
    return Row(
      children: [
        // Corner
        _buildCell('', 40, 30, isHeader: true),
        // Column headers
        ...List.generate(
          columns,
          (j) => _buildCell(
            _getColumnName(j),
            cellFormats[0][j].width,
            30,
            isHeader: true,
          ),
        ),
      ],
    );
  }

  List<Widget> _buildRows() {
    return List.generate(
      rows,
      (i) => Row(
        children: [
          // Row header
          if (showHeaders)
            _buildCell(
              '${i + 1}',
              40,
              cellFormats[i][0].height,
              isHeader: true,
            ),
          // Data cells
          ...List.generate(columns, (j) => _buildDataCell(i, j)),
        ],
      ),
    );
  }

  Widget _buildDataCell(int row, int col) {
    MergeInfo? merge = _findMergeForCell(row, col);

    if (merge != null && merge.row1 == row && merge.col1 == col) {
      // Top-left of merge
      double width = 0;
      double height = 0;

      for (int c = merge.col1; c <= merge.col2; c++) {
        width += cellFormats[0][c].width;
      }
      for (int r = merge.row1; r <= merge.row2; r++) {
        height += cellFormats[r][0].height;
      }

      return Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.blue[50],
          border: Border.all(color: Colors.blue!, width: 2),
        ),
        child: TextField(
          controller: controllers[row][col],
          decoration: const InputDecoration(border: InputBorder.none),
          textAlign: TextAlign.center,
        ),
      );
    } else if (_isCellPartOfMerge(row, col)) {
      // Part of merge, but not top-left - invisible
      return Container(
        width: cellFormats[row][col].width,
        height: cellFormats[row][col].height,
        color: Colors.transparent,
      );
    } else {
      // Regular cell
      return _buildCell(
        '',
        cellFormats[row][col].width,
        cellFormats[row][col].height,
        controller: controllers[row][col],
      );
    }
  }

  Widget _buildCell(
    String text,
    double width,
    double height, {
    bool isHeader = false,
    TextEditingController? controller,
  }) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: isHeader ? Colors.grey[200] : Colors.white,
        border: Border.all(color: borderColor),
      ),
      child: controller != null
          ? TextField(
              controller: controller,
              decoration: const InputDecoration(border: InputBorder.none),
              textAlign: TextAlign.center,
            )
          : Center(
              child: Text(
                text,
                style: GoogleFonts.lora(
                  fontWeight: isHeader ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ),
    );
  }

  MergeInfo? _findMergeForCell(int row, int col) {
    return merges
                .firstWhere(
                  (merge) =>
                      row >= merge.row1 &&
                      row <= merge.row2 &&
                      col >= merge.col1 &&
                      col <= merge.col2,
                  orElse: () =>
                      MergeInfo(row1: -1, col1: -1, row2: -1, col2: -1),
                )
                .row1 ==
            -1
        ? null
        : merges.firstWhere(
            (merge) =>
                row >= merge.row1 &&
                row <= merge.row2 &&
                col >= merge.col1 &&
                col <= merge.col2,
          );
  }

  bool _isCellPartOfMerge(int row, int col) {
    return _findMergeForCell(row, col) != null;
  }

  String _getColumnName(int index) {
    String result = '';
    int temp = index;
    while (temp >= 0) {
      result = String.fromCharCode(65 + (temp % 26)) + result;
      temp = (temp ~/ 26) - 1;
    }
    return result;
  }
}

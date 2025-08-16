import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ExcelTableBuilderScreen extends StatefulWidget {
  final Map<String, dynamic>? existingData;
  const ExcelTableBuilderScreen({Key? key, this.existingData})
    : super(key: key);

  @override
  State<ExcelTableBuilderScreen> createState() =>
      _ExcelTableBuilderScreenState();
}

class _ExcelTableBuilderScreenState extends State<ExcelTableBuilderScreen> {
  late int _rows;
  late int _columns;
  late List<List<TextEditingController>> _controllers;
  late List<List<CellFormat>> _cellFormats;
  late List<MergeInfo> _merges;
  late TextEditingController _titleController;
  String? _statusMessage;
  String _selectedTool = 'select';

  @override
  void initState() {
    super.initState();
    _initFromData();
  }

  void _initFromData() {
    if (widget.existingData != null) {
      _rows = widget.existingData!['rows'] ?? 5;
      _columns = widget.existingData!['columns'] ?? 5;
      _titleController = TextEditingController(
        text: widget.existingData!['title'] ?? 'Excel Table',
      );
      final dynData = widget.existingData!['data'] as List<dynamic>? ?? [];
      _merges =
          ((widget.existingData!['merged'] as List?)
              ?.map((e) => MergeInfo.fromMap(Map<String, dynamic>.from(e)))
              .toList()) ??
          [];

      _controllers = List.generate(
        _rows,
        (i) => List.generate(
          _columns,
          (j) => TextEditingController(
            text: (i < dynData.length && j < (dynData[i] as List).length)
                ? (dynData[i] as List)[j].toString()
                : '',
          ),
        ),
      );
    } else {
      _rows = 5;
      _columns = 5;
      _titleController = TextEditingController(text: 'Excel Table');
      _controllers = List.generate(
        _rows,
        (i) => List.generate(_columns, (j) => TextEditingController()),
      );
      _merges = [];
    }

    // Initialize cell formats
    _cellFormats = List.generate(
      _rows,
      (i) => List.generate(_columns, (j) => CellFormat()),
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    for (var row in _controllers) {
      for (var ctrl in row) {
        ctrl.dispose();
      }
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Excel Table Builder',
          style: GoogleFonts.lora(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        actions: [
          IconButton(
            tooltip: "Save Table",
            icon: const Icon(Icons.check, color: Colors.black87),
            onPressed: _onSave,
          ),
        ],
      ),
      body: Column(
        children: [
          // Title input
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              controller: _titleController,
              decoration: InputDecoration(
                labelText: 'Table Title',
                labelStyle: GoogleFonts.lora(color: Colors.grey[600]),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
              ),
              style: GoogleFonts.lora(fontSize: 14),
            ),
          ),

          // Ribbon toolbar
          _buildRibbon(),

          // Table section with headers
          Expanded(
            child: SingleChildScrollView(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: _buildTableWithHeaders(),
                ),
              ),
            ),
          ),

          // Status message
          if (_statusMessage != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              color: Colors.blue[50],
              child: Text(
                _statusMessage!,
                style: GoogleFonts.lora(color: Colors.blue[700], fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRibbon() {
    return Container(
      height: 70, // Reduced height
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 4,
      ), // Reduced vertical padding
      decoration: BoxDecoration(
        color: Colors.grey[50],
        border: Border(bottom: BorderSide(color: Colors.grey!)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            // Table size group
            _buildRibbonGroup('Table Size', [
              _buildRibbonButton(Icons.add_box, 'Add Row', () => _addRow()),
              _buildRibbonButton(
                Icons.remove_circle_outline,
                'Remove Row',
                () => _removeRow(),
              ),
              _buildRibbonButton(
                Icons.view_column,
                'Add Column',
                () => _addColumn(),
              ),
              _buildRibbonButton(
                Icons.view_column,
                'Remove Col',
                () => _removeColumn(),
              ),
            ]),

            const VerticalDivider(),

            // Merge group
            _buildRibbonGroup('Merge', [
              _buildRibbonButton(
                Icons.call_merge,
                'Merge Cells',
                () => _showMergeDialog(),
              ),
              _buildRibbonButton(
                Icons.call_split,
                'Unmerge',
                () => _showUnmergeDialog(),
              ),
            ]),

            const VerticalDivider(),

            // Format group
            _buildRibbonGroup('Format', [
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 1),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => _showCellWidthDialog(),
                    borderRadius: BorderRadius.circular(4),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Transform.rotate(
                            angle: 1.5708, // 90 degrees (π/2 radians)
                            child: Icon(
                              Icons.height,
                              size: 16,
                              color: Colors.grey[700],
                            ),
                          ),
                          const SizedBox(height: 1),
                          Flexible(
                            child: Text(
                              'Cell Width',
                              style: GoogleFonts.lora(
                                fontSize: 7,
                                color: Colors.grey[600],
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              _buildRibbonButton(
                Icons.height,
                'Cell Height',
                () => _showCellHeightDialog(),
              ),
              _buildRibbonButton(
                Icons.wrap_text,
                'Text Wrap',
                () => _toggleTextWrap(),
              ),
            ]),

            const VerticalDivider(),

            // Quick actions
            _buildRibbonGroup('Quick', [
              _buildRibbonButton(
                Icons.clear_all,
                'Clear All',
                () => _clearAllCells(),
              ),
              _buildRibbonButton(Icons.refresh, 'Reset', () => _resetTable()),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _buildRibbonGroup(String title, List<Widget> buttons) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min, // Add this to prevent overflow
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.lora(
              fontSize: 9, // Reduced font size
              fontWeight: FontWeight.w500,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 2), // Reduced spacing
          Expanded(
            // Wrap buttons in Expanded
            child: Row(children: buttons),
          ),
        ],
      ),
    );
  }

  Widget _buildRibbonButton(
    IconData icon,
    String tooltip,
    VoidCallback onPressed,
  ) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 1), // Reduced margin
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(4),
          child: Container(
            padding: const EdgeInsets.all(4), // Reduced padding
            child: Column(
              mainAxisSize: MainAxisSize.min, // Add this
              children: [
                Icon(
                  icon,
                  size: 16,
                  color: Colors.grey[700],
                ), // Reduced icon size
                const SizedBox(height: 1), // Reduced spacing
                Flexible(
                  // Wrap text in Flexible
                  child: Text(
                    tooltip,
                    style: GoogleFonts.lora(
                      fontSize: 7, // Reduced font size
                      color: Colors.grey[600],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTableWithHeaders() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Column headers (A, B, C, ...)
        Row(
          children: [
            // Empty corner cell
            Container(
              width: 40,
              height: 30,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                border: Border.all(color: Colors.grey!),
              ),
            ),
            // Column headers
            ...List.generate(
              _columns,
              (j) => Container(
                width: _cellFormats[0][j].width,
                height: 30,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  border: Border.all(color: Colors.grey!),
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
        ),

        // Table rows with row numbers
        ...List.generate(
          _rows,
          (i) => Row(
            children: [
              // Row header (1, 2, 3, ...)
              Container(
                width: 40,
                height: _cellFormats[i][0].height,
                decoration: BoxDecoration(
                  color: Colors.grey,
                  border: Border.all(color: Colors.grey!),
                ),
                child: Center(
                  child: Text(
                    '${i + 1}',
                    style: GoogleFonts.lora(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                ),
              ),
              // Table cells
              ...List.generate(
                _columns,
                (j) => Container(
                  width: _cellFormats[i][j].width,
                  height: _cellFormats[i][j].height,
                  decoration: BoxDecoration(
                    color: i == 0 ? Colors.grey[50] : Colors.white,
                    border: Border.all(color: Colors.grey!),
                  ),
                  child: TextField(
                    controller: _controllers[i][j],
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.all(4),
                    ),
                    style: GoogleFonts.lora(
                      fontSize: _cellFormats[i][j].fontSize,
                      fontWeight: i == 0 ? FontWeight.w600 : FontWeight.normal,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: _cellFormats[i][j].textWrap ? null : 1,
                    minLines: _cellFormats[i][j].textWrap ? 1 : null,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
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

  String _getCellReference(int row, int col) {
    return '${_getColumnName(col)}${row + 1}';
  }

  void _addRow() {
    setState(() {
      _rows++;
      _controllers.add(List.generate(_columns, (j) => TextEditingController()));
      _cellFormats.add(List.generate(_columns, (j) => CellFormat()));
      _statusMessage = 'Row added. Table is now ${_rows}×${_columns}';
    });
    _clearStatusAfterDelay();
  }

  void _removeRow() {
    if (_rows > 1) {
      setState(() {
        _rows--;
        final removedRow = _controllers.removeLast();
        for (var ctrl in removedRow) {
          ctrl.dispose();
        }
        _cellFormats.removeLast();
        _merges.removeWhere((m) => m.row1 >= _rows || m.row2 >= _rows);
        _statusMessage = 'Row removed. Table is now ${_rows}×${_columns}';
      });
      _clearStatusAfterDelay();
    }
  }

  void _addColumn() {
    setState(() {
      _columns++;
      for (int i = 0; i < _rows; i++) {
        _controllers[i].add(TextEditingController());
        _cellFormats[i].add(CellFormat());
      }
      _statusMessage = 'Column added. Table is now ${_rows}×${_columns}';
    });
    _clearStatusAfterDelay();
  }

  void _removeColumn() {
    if (_columns > 1) {
      setState(() {
        _columns--;
        for (int i = 0; i < _rows; i++) {
          _controllers[i].removeLast().dispose();
          _cellFormats[i].removeLast();
        }
        _merges.removeWhere((m) => m.col1 >= _columns || m.col2 >= _columns);
        _statusMessage = 'Column removed. Table is now ${_rows}×${_columns}';
      });
      _clearStatusAfterDelay();
    }
  }

  void _showMergeDialog() {
    final fromCellCtrl = TextEditingController();
    final toCellCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text(
          'Merge Cells',
          style: GoogleFonts.lora(fontWeight: FontWeight.w600),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Enter cell range to merge (e.g., A1 to C3)',
              style: GoogleFonts.lora(fontSize: 13, color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: fromCellCtrl,
              decoration: InputDecoration(
                labelText: 'From Cell (e.g., A1)',
                labelStyle: GoogleFonts.lora(),
                border: const OutlineInputBorder(),
              ),
              style: GoogleFonts.lora(),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: toCellCtrl,
              decoration: InputDecoration(
                labelText: 'To Cell (e.g., C3)',
                labelStyle: GoogleFonts.lora(),
                border: const OutlineInputBorder(),
              ),
              style: GoogleFonts.lora(),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: GoogleFonts.lora()),
          ),
          ElevatedButton(
            onPressed: () {
              final fromCell = _parseCellReference(
                fromCellCtrl.text.toUpperCase(),
              );
              final toCell = _parseCellReference(toCellCtrl.text.toUpperCase());

              if (fromCell != null && toCell != null) {
                final merge = MergeInfo(
                  row1: fromCell['row']!,
                  col1: fromCell['col']!,
                  row2: toCell['row']!,
                  col2: toCell['col']!,
                );

                if (!_merges.any((m) => m.overlaps(merge))) {
                  setState(() {
                    _merges.add(merge);
                    _statusMessage =
                        'Merged ${fromCellCtrl.text}:${toCellCtrl.text}';
                  });
                  Navigator.pop(ctx);
                  _clearStatusAfterDelay();
                } else {
                  setState(
                    () => _statusMessage = 'Merge overlaps with existing merge',
                  );
                }
              } else {
                setState(() => _statusMessage = 'Invalid cell references');
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue[600],
              foregroundColor: Colors.white,
            ),
            child: Text('Merge', style: GoogleFonts.lora()),
          ),
        ],
      ),
    );
  }

  void _showUnmergeDialog() {
    if (_merges.isEmpty) {
      setState(() => _statusMessage = 'No merges to remove');
      _clearStatusAfterDelay();
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text(
          'Unmerge Cells',
          style: GoogleFonts.lora(fontWeight: FontWeight.w600),
        ),
        content: SizedBox(
          width: 300,
          height: 200,
          child: ListView.builder(
            itemCount: _merges.length,
            itemBuilder: (context, index) {
              final merge = _merges[index];
              return ListTile(
                title: Text(
                  '${_getCellReference(merge.row1, merge.col1)}:${_getCellReference(merge.row2, merge.col2)}',
                  style: GoogleFonts.lora(),
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () {
                    setState(() {
                      _merges.removeAt(index);
                      _statusMessage = 'Merge removed';
                    });
                    Navigator.pop(ctx);
                    _clearStatusAfterDelay();
                  },
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Close', style: GoogleFonts.lora()),
          ),
        ],
      ),
    );
  }

  void _showCellWidthDialog() {
    final widthCtrl = TextEditingController(text: '100');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Set Cell Width',
          style: GoogleFonts.lora(fontWeight: FontWeight.w600),
        ),
        content: TextField(
          controller: widthCtrl,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: 'Width (pixels)',
            labelStyle: GoogleFonts.lora(),
            border: const OutlineInputBorder(),
          ),
          style: GoogleFonts.lora(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: GoogleFonts.lora()),
          ),
          ElevatedButton(
            onPressed: () {
              final width = double.tryParse(widthCtrl.text) ?? 100.0;
              setState(() {
                for (int i = 0; i < _rows; i++) {
                  for (int j = 0; j < _columns; j++) {
                    _cellFormats[i][j].width = width;
                  }
                }
                _statusMessage = 'Cell width set to ${width.toInt()}px';
              });
              Navigator.pop(ctx);
              _clearStatusAfterDelay();
            },
            child: Text('Apply', style: GoogleFonts.lora()),
          ),
        ],
      ),
    );
  }

  void _showCellHeightDialog() {
    final heightCtrl = TextEditingController(text: '40');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Set Cell Height',
          style: GoogleFonts.lora(fontWeight: FontWeight.w600),
        ),
        content: TextField(
          controller: heightCtrl,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: 'Height (pixels)',
            labelStyle: GoogleFonts.lora(),
            border: const OutlineInputBorder(),
          ),
          style: GoogleFonts.lora(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: GoogleFonts.lora()),
          ),
          ElevatedButton(
            onPressed: () {
              final height = double.tryParse(heightCtrl.text) ?? 40.0;
              setState(() {
                for (int i = 0; i < _rows; i++) {
                  for (int j = 0; j < _columns; j++) {
                    _cellFormats[i][j].height = height;
                  }
                }
                _statusMessage = 'Cell height set to ${height.toInt()}px';
              });
              Navigator.pop(ctx);
              _clearStatusAfterDelay();
            },
            child: Text('Apply', style: GoogleFonts.lora()),
          ),
        ],
      ),
    );
  }

  void _toggleTextWrap() {
    setState(() {
      final shouldWrap = !_cellFormats[0][0].textWrap;
      for (int i = 0; i < _rows; i++) {
        for (int j = 0; j < _columns; j++) {
          _cellFormats[i][j].textWrap = shouldWrap;
        }
      }
      _statusMessage = 'Text wrap ${shouldWrap ? 'enabled' : 'disabled'}';
    });
    _clearStatusAfterDelay();
  }

  void _clearAllCells() {
    setState(() {
      for (int i = 0; i < _rows; i++) {
        for (int j = 0; j < _columns; j++) {
          _controllers[i][j].clear();
        }
      }
      _statusMessage = 'All cells cleared';
    });
    _clearStatusAfterDelay();
  }

  void _resetTable() {
    setState(() {
      _rows = 5;
      _columns = 5;
      // Dispose old controllers
      for (var row in _controllers) {
        for (var ctrl in row) {
          ctrl.dispose();
        }
      }
      _controllers = List.generate(
        _rows,
        (i) => List.generate(_columns, (j) => TextEditingController()),
      );
      _cellFormats = List.generate(
        _rows,
        (i) => List.generate(_columns, (j) => CellFormat()),
      );
      _merges.clear();
      _statusMessage = 'Table reset to 5×5';
    });
    _clearStatusAfterDelay();
  }

  Map<String, int>? _parseCellReference(String cellRef) {
    final RegExp cellRegex = RegExp(r'^([A-Z]+)(\d+)$');
    final match = cellRegex.firstMatch(cellRef);

    if (match != null) {
      final colStr = match.group(1)!;
      final rowStr = match.group(2)!;

      int col = 0;
      for (int i = 0; i < colStr.length; i++) {
        col = col * 26 + (colStr.codeUnitAt(i) - 64);
      }
      col -= 1; // Convert to 0-based

      final row = int.parse(rowStr) - 1; // Convert to 0-based

      if (row >= 0 && row < _rows && col >= 0 && col < _columns) {
        return {'row': row, 'col': col};
      }
    }
    return null;
  }

  void _clearStatusAfterDelay() {
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) setState(() => _statusMessage = null);
    });
  }

  void _onSave() {
    final data = List.generate(
      _rows,
      (i) => List.generate(_columns, (j) => _controllers[i][j].text),
    );

    final Map<String, dynamic> result = {
      'rows': _rows,
      'columns': _columns,
      'title': _titleController.text.trim().isEmpty
          ? 'Excel Table'
          : _titleController.text.trim(),
      'data': data,
      'merged': _merges.map((m) => m.toMap()).toList(),
      'cellFormats': _cellFormats
          .map((row) => row.map((format) => format.toMap()).toList())
          .toList(),
    };
    Navigator.pop(context, result);
  }
}

// Cell format class
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

// Merge info class
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

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../widgets/merged_table.dart';

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

      final cellFormatsData =
          widget.existingData!['cellFormats'] as List? ?? [];
      _cellFormats = List.generate(
        _rows,
        (i) => List.generate(
          _columns,
          (j) =>
              (i < cellFormatsData.length &&
                  j < (cellFormatsData[i] as List).length)
              ? CellFormat.fromMap(
                  Map<String, dynamic>.from((cellFormatsData[i] as List)[j]),
                )
              : CellFormat(),
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
      _cellFormats = List.generate(
        _rows,
        (i) => List.generate(_columns, (j) => CellFormat()),
      );
    }
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
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDarkMode ? const Color(0xFF1C1C1E) : Colors.white,
      appBar: AppBar(
        backgroundColor: isDarkMode ? const Color(0xFF2C2C2E) : Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.close,
            color: isDarkMode ? Colors.white : Colors.black87,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Excel Table Builder',
          style: GoogleFonts.lora(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: isDarkMode ? Colors.white : Colors.black87,
          ),
        ),
        actions: [
          IconButton(
            tooltip: "Save Table",
            icon: Icon(
              Icons.check,
              color: isDarkMode ? Colors.white : Colors.black87,
            ),
            onPressed: _onSave,
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              controller: _titleController,
              style: GoogleFonts.lora(
                fontSize: 14,
                color: isDarkMode ? Colors.white : null,
              ),
              decoration: InputDecoration(
                labelText: 'Table Title',
                labelStyle: GoogleFonts.lora(
                  color: isDarkMode
                      ? Colors.white.withOpacity(0.7)
                      : Colors.grey[600],
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: isDarkMode
                        ? Colors.white.withOpacity(0.3)
                        : Colors.grey.shade300,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: isDarkMode
                        ? Colors.white.withOpacity(0.3)
                        : Colors.grey.shade300,
                  ),
                ),
                filled: true,
                fillColor: isDarkMode ? const Color(0xFF3C3C3E) : null,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
              ),
            ),
          ),

          _buildRibbon(),

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

          if (_statusMessage != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              color: isDarkMode
                  ? Colors.blue.shade900.withOpacity(0.3)
                  : Colors.blue[50],
              child: Text(
                _statusMessage!,
                style: GoogleFonts.lora(
                  color: isDarkMode ? Colors.blue[100] : Colors.blue[700],
                  fontSize: 12,
                ),
                textAlign: TextAlign.center,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRibbon() {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return Container(
      height: 70,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF2C2C2E) : Colors.grey[50],
        border: Border(
          bottom: BorderSide(
            color: isDarkMode
                ? Colors.white.withOpacity(0.1)
                : Colors.grey.shade300,
          ),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
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

            VerticalDivider(
              color: isDarkMode ? Colors.white.withOpacity(0.2) : null,
            ),

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

            VerticalDivider(
              color: isDarkMode ? Colors.white.withOpacity(0.2) : null,
            ),

            _buildRibbonGroup('Format', [
              _buildRibbonButton(
                Icons.width_wide,
                'Cell Width',
                () => _showCellWidthDialog(),
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

            VerticalDivider(
              color: isDarkMode ? Colors.white.withOpacity(0.2) : null,
            ),

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
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.lora(
              fontSize: 9,
              fontWeight: FontWeight.w500,
              color: isDarkMode
                  ? Colors.white.withOpacity(0.6)
                  : Colors.grey[600],
            ),
          ),
          const SizedBox(height: 2),
          Expanded(child: Row(children: buttons)),
        ],
      ),
    );
  }

  Widget _buildRibbonButton(
    IconData icon,
    String tooltip,
    VoidCallback onPressed,
  ) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 1),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(4),
          child: Container(
            padding: const EdgeInsets.all(4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 16,
                  color: isDarkMode
                      ? Colors.white.withOpacity(0.7)
                      : Colors.grey[700],
                ),
                const SizedBox(height: 1),
                Flexible(
                  child: Text(
                    tooltip,
                    style: GoogleFonts.lora(
                      fontSize: 7,
                      color: isDarkMode
                          ? Colors.white.withOpacity(0.6)
                          : Colors.grey[600],
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
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return EnhancedMergeTable(
      rows: _rows,
      columns: _columns,
      controllers: _controllers,
      cellFormats: _cellFormats,
      merges: _merges,
      showHeaders: true,
      borderColor: isDarkMode
          ? Colors.white.withOpacity(0.3)
          : Colors.grey[300]!,
      onCellTap: (row, col) {
        print('Tapped cell: $row, $col');
      },
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
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final fromCellCtrl = TextEditingController();
    final toCellCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDarkMode ? const Color(0xFF1C1C1E) : null,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text(
          'Merge Cells',
          style: GoogleFonts.lora(
            fontWeight: FontWeight.w600,
            color: isDarkMode ? Colors.white : null,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Enter cell range to merge (e.g., A1 to C3)',
              style: GoogleFonts.lora(
                fontSize: 13,
                color: isDarkMode
                    ? Colors.white.withOpacity(0.6)
                    : Colors.grey[600],
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: fromCellCtrl,
              style: GoogleFonts.lora(color: isDarkMode ? Colors.white : null),
              decoration: InputDecoration(
                labelText: 'From Cell (e.g., A1)',
                labelStyle: GoogleFonts.lora(
                  color: isDarkMode ? Colors.white.withOpacity(0.7) : null,
                ),
                border: OutlineInputBorder(
                  borderSide: BorderSide(
                    color: isDarkMode
                        ? Colors.white.withOpacity(0.3)
                        : Colors.grey.shade300,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(
                    color: isDarkMode
                        ? Colors.white.withOpacity(0.3)
                        : Colors.grey.shade300,
                  ),
                ),
                filled: true,
                fillColor: isDarkMode ? const Color(0xFF3C3C3E) : null,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: toCellCtrl,
              style: GoogleFonts.lora(color: isDarkMode ? Colors.white : null),
              decoration: InputDecoration(
                labelText: 'To Cell (e.g., C3)',
                labelStyle: GoogleFonts.lora(
                  color: isDarkMode ? Colors.white.withOpacity(0.7) : null,
                ),
                border: OutlineInputBorder(
                  borderSide: BorderSide(
                    color: isDarkMode
                        ? Colors.white.withOpacity(0.3)
                        : Colors.grey.shade300,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(
                    color: isDarkMode
                        ? Colors.white.withOpacity(0.3)
                        : Colors.grey.shade300,
                  ),
                ),
                filled: true,
                fillColor: isDarkMode ? const Color(0xFF3C3C3E) : null,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: GoogleFonts.lora(color: isDarkMode ? Colors.white : null),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              final fromCell = _parseCellReference(
                fromCellCtrl.text.toUpperCase(),
              );
              final toCell = _parseCellReference(toCellCtrl.text.toUpperCase());

              if (fromCell != null && toCell != null) {
                final merge = MergeInfo(
                  row1: fromCell['row']! < toCell['row']!
                      ? fromCell['row']!
                      : toCell['row']!,
                  col1: fromCell['col']! < toCell['col']!
                      ? fromCell['col']!
                      : toCell['col']!,
                  row2: fromCell['row']! > toCell['row']!
                      ? fromCell['row']!
                      : toCell['row']!,
                  col2: fromCell['col']! > toCell['col']!
                      ? fromCell['col']!
                      : toCell['col']!,
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
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    if (_merges.isEmpty) {
      setState(() => _statusMessage = 'No merges to remove');
      _clearStatusAfterDelay();
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDarkMode ? const Color(0xFF1C1C1E) : null,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text(
          'Unmerge Cells',
          style: GoogleFonts.lora(
            fontWeight: FontWeight.w600,
            color: isDarkMode ? Colors.white : null,
          ),
        ),
        content: Container(
          color: isDarkMode ? const Color(0xFF2C2C2E) : null,
          width: 300,
          height: 200,
          child: ListView.builder(
            itemCount: _merges.length,
            itemBuilder: (context, index) {
              final merge = _merges[index];
              return ListTile(
                title: Text(
                  '${_getCellReference(merge.row1, merge.col1)}:${_getCellReference(merge.row2, merge.col2)}',
                  style: GoogleFonts.lora(
                    color: isDarkMode ? Colors.white : null,
                  ),
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
            child: Text(
              'Close',
              style: GoogleFonts.lora(color: isDarkMode ? Colors.white : null),
            ),
          ),
        ],
      ),
    );
  }

  void _showCellWidthDialog() {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final widthCtrl = TextEditingController(text: '100');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDarkMode ? const Color(0xFF1C1C1E) : null,
        title: Text(
          'Set Cell Width',
          style: GoogleFonts.lora(
            fontWeight: FontWeight.w600,
            color: isDarkMode ? Colors.white : null,
          ),
        ),
        content: TextField(
          controller: widthCtrl,
          keyboardType: TextInputType.number,
          style: GoogleFonts.lora(color: isDarkMode ? Colors.white : null),
          decoration: InputDecoration(
            labelText: 'Width (pixels)',
            labelStyle: GoogleFonts.lora(
              color: isDarkMode ? Colors.white.withOpacity(0.7) : null,
            ),
            border: OutlineInputBorder(
              borderSide: BorderSide(
                color: isDarkMode
                    ? Colors.white.withOpacity(0.3)
                    : Colors.grey.shade300,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderSide: BorderSide(
                color: isDarkMode
                    ? Colors.white.withOpacity(0.3)
                    : Colors.grey.shade300,
              ),
            ),
            filled: true,
            fillColor: isDarkMode ? const Color(0xFF3C3C3E) : null,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: GoogleFonts.lora(color: isDarkMode ? Colors.white : null),
            ),
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
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final heightCtrl = TextEditingController(text: '40');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDarkMode ? const Color(0xFF1C1C1E) : null,
        title: Text(
          'Set Cell Height',
          style: GoogleFonts.lora(
            fontWeight: FontWeight.w600,
            color: isDarkMode ? Colors.white : null,
          ),
        ),
        content: TextField(
          controller: heightCtrl,
          keyboardType: TextInputType.number,
          style: GoogleFonts.lora(color: isDarkMode ? Colors.white : null),
          decoration: InputDecoration(
            labelText: 'Height (pixels)',
            labelStyle: GoogleFonts.lora(
              color: isDarkMode ? Colors.white.withOpacity(0.7) : null,
            ),
            border: OutlineInputBorder(
              borderSide: BorderSide(
                color: isDarkMode
                    ? Colors.white.withOpacity(0.3)
                    : Colors.grey.shade300,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderSide: BorderSide(
                color: isDarkMode
                    ? Colors.white.withOpacity(0.3)
                    : Colors.grey.shade300,
              ),
            ),
            filled: true,
            fillColor: isDarkMode ? const Color(0xFF3C3C3E) : null,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: GoogleFonts.lora(color: isDarkMode ? Colors.white : null),
            ),
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
      col -= 1;

      final row = int.parse(rowStr) - 1;

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

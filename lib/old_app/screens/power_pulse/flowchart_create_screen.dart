// lib/screens/flowchart_create_screen.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:graphite/graphite.dart';

class FlowchartCreateScreen extends StatefulWidget {
  final Map<String, dynamic>? existingFlowchart;

  const FlowchartCreateScreen({Key? key, this.existingFlowchart})
    : super(key: key);

  @override
  State<FlowchartCreateScreen> createState() => _FlowchartCreateScreenState();
}

class _FlowchartCreateScreenState extends State<FlowchartCreateScreen> {
  late List<NodeInput> _nodes;
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  String? _selectedNodeId;
  bool _isModified = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController();
    _descriptionController = TextEditingController();

    if (widget.existingFlowchart != null) {
      _loadExistingFlowchart();
    } else {
      _initializeDefaultFlowchart();
    }
  }

  void _loadExistingFlowchart() {
    final flowchart = widget.existingFlowchart!;
    _titleController.text = flowchart['title'] ?? '';
    _descriptionController.text = flowchart['description'] ?? '';

    if (flowchart['nodes'] != null) {
      final nodesList = flowchart['nodes'] as String;
      _nodes = nodeInputFromJson(nodesList);
    } else {
      _initializeDefaultFlowchart();
    }
  }

  void _initializeDefaultFlowchart() {
    _nodes = [
      NodeInput(
        id: "Start",
        next: [EdgeInput(outcome: "Step1")],
      ),
      NodeInput(
        id: "Step1",
        next: [EdgeInput(outcome: "End")],
      ),
      NodeInput(id: "End", next: []),
    ];
    _titleController.text = "New Flowchart";
    _descriptionController.text = "Describe your flowchart process here";
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDarkMode ? const Color(0xFF1C1C1E) : Colors.white,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          _buildHeader(),
          Expanded(child: _buildFlowchartCanvas()),
          _buildBottomActions(),
        ],
      ),
      floatingActionButton: _buildFAB(),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return AppBar(
      backgroundColor: isDarkMode ? const Color(0xFF2C2C2E) : Colors.white,
      elevation: 1,
      leading: IconButton(
        icon: Icon(
          Icons.close,
          color: isDarkMode ? Colors.white : Colors.black87,
        ),
        onPressed: _handleBack,
      ),
      title: Text(
        'Create Flowchart',
        style: GoogleFonts.lora(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: isDarkMode ? Colors.white : Colors.black87,
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isModified ? _previewFlowchart : null,
          child: Text(
            'Preview',
            style: GoogleFonts.lora(
              color: _isModified
                  ? (isDarkMode ? Colors.blue[200] : Colors.blue[600])
                  : (isDarkMode ? Colors.white54 : Colors.grey),
            ),
          ),
        ),
        TextButton(
          onPressed: _isModified ? _saveFlowchart : null,
          child: Text(
            'Save',
            style: GoogleFonts.lora(
              color: _isModified
                  ? (isDarkMode ? Colors.blue[200] : Colors.blue)
                  : (isDarkMode ? Colors.white54 : Colors.grey),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(16),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _titleController,
            style: GoogleFonts.lora(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: isDarkMode ? Colors.white : null,
            ),
            decoration: InputDecoration(
              labelText: 'Flowchart Title',
              labelStyle: TextStyle(
                color: isDarkMode ? Colors.white.withOpacity(0.7) : null,
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
              contentPadding: const EdgeInsets.all(12),
            ),
            onChanged: (_) => _setModified(),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _descriptionController,
            style: GoogleFonts.lora(
              fontSize: 14,
              color: isDarkMode ? Colors.white : null,
            ),
            decoration: InputDecoration(
              labelText: 'Description',
              labelStyle: TextStyle(
                color: isDarkMode ? Colors.white.withOpacity(0.7) : null,
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
              contentPadding: const EdgeInsets.all(12),
            ),
            maxLines: 2,
            onChanged: (_) => _setModified(),
          ),
        ],
      ),
    );
  }

  Widget _buildFlowchartCanvas() {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return Container(
      color: isDarkMode ? const Color(0xFF1C1C1E) : Colors.white,
      child: InteractiveViewer(
        constrained: false,
        child: SizedBox(
          width: 800,
          height: 600,
          child: _nodes.isNotEmpty
              ? DirectGraph(
                  list: _nodes,
                  defaultCellSize: const Size(120, 60),
                  cellPadding: const EdgeInsets.all(20),
                  orientation: MatrixOrientation.Vertical,
                  nodeBuilder: (context, node) => _buildFlowchartNode(node),
                  centered: true,
                )
              : Container(
                  width: 800,
                  height: 600,
                  color: isDarkMode
                      ? const Color(0xFF2C2C2E)
                      : Colors.grey[100],
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.add_chart,
                          size: 64,
                          color: isDarkMode
                              ? Colors.white.withOpacity(0.4)
                              : Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No nodes available',
                          style: TextStyle(
                            fontSize: 18,
                            color: isDarkMode
                                ? Colors.white.withOpacity(0.6)
                                : Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Add a node to start building your flowchart',
                          style: TextStyle(
                            fontSize: 14,
                            color: isDarkMode
                                ? Colors.white.withOpacity(0.5)
                                : Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildFAB() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        FloatingActionButton(
          onPressed: _resetFlowchart,
          backgroundColor: Colors.orange[600],
          heroTag: "reset",
          child: const Icon(Icons.refresh, color: Colors.white),
        ),
        const SizedBox(height: 10),
        FloatingActionButton(
          onPressed: _addNode,
          backgroundColor: Colors.blue[600],
          heroTag: "add",
          child: const Icon(Icons.add, color: Colors.white),
        ),
      ],
    );
  }

  Widget _buildFlowchartNode(NodeInput node) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final isSelected = _selectedNodeId == node.id;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedNodeId = node.id;
        });
      },
      onLongPress: () => _showNodeContextMenu(node),
      child: Container(
        decoration: BoxDecoration(
          color: isSelected
              ? (isDarkMode
                    ? Colors.blue[800]?.withOpacity(0.3)
                    : Colors.blue[50])
              : (isDarkMode ? const Color(0xFF2C2C2E) : Colors.white),
          border: Border.all(
            color: isSelected
                ? (isDarkMode ? Colors.blue[400]! : Colors.blue!)
                : (isDarkMode
                      ? Colors.white.withOpacity(0.3)
                      : Colors.grey.shade300),
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: isDarkMode
                  ? Colors.black.withOpacity(0.3)
                  : Colors.black.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Text(
              node.id,
              style: GoogleFonts.lora(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isSelected
                    ? (isDarkMode ? Colors.blue[200] : Colors.blue[800])
                    : (isDarkMode ? Colors.white : Colors.black87),
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }

  void _showNodeContextMenu(NodeInput node) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: isDarkMode ? const Color(0xFF1C1C1E) : null,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: isDarkMode
                    ? Colors.white.withOpacity(0.3)
                    : Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              node.id,
              style: GoogleFonts.lora(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: isDarkMode ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 20),
            _buildContextMenuItem(
              icon: Icons.link,
              label: 'Add Connection',
              onTap: () {
                Navigator.pop(context);
                setState(() {
                  _selectedNodeId = node.id;
                });
                _showAddConnectionDialog();
              },
            ),
            _buildContextMenuItem(
              icon: Icons.edit,
              label: 'Edit Node',
              onTap: () {
                Navigator.pop(context);
                setState(() {
                  _selectedNodeId = node.id;
                });
                _editSelectedNode();
              },
            ),
            _buildContextMenuItem(
              icon: Icons.delete_outline,
              label: 'Delete Node',
              onTap: () {
                Navigator.pop(context);
                setState(() {
                  _selectedNodeId = node.id;
                });
                _deleteSelectedNode();
              },
              isDestructive: true,
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildContextMenuItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return ListTile(
      leading: Icon(
        icon,
        color: isDestructive
            ? Colors.red[600]
            : (isDarkMode ? Colors.white : Colors.black87),
        size: 24,
      ),
      title: Text(
        label,
        style: GoogleFonts.lora(
          fontSize: 16,
          color: isDestructive
              ? Colors.red[600]
              : (isDarkMode ? Colors.white : Colors.black87),
        ),
      ),
      onTap: onTap,
    );
  }

  Widget _buildBottomActions() {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF2C2C2E) : Colors.white,
        border: Border(
          top: BorderSide(
            color: isDarkMode
                ? Colors.white.withOpacity(0.1)
                : Colors.grey[200]!,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: isDarkMode
                ? Colors.black.withOpacity(0.3)
                : Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Nodes: ${_nodes.length}',
            style: GoogleFonts.lora(
              fontSize: 14,
              color: isDarkMode
                  ? Colors.white.withOpacity(0.6)
                  : Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  void _setModified() {
    if (!_isModified) {
      setState(() {
        _isModified = true;
      });
    }
  }

  void _addNode() {
    showDialog(context: context, builder: (context) => _buildAddNodeDialog());
  }

  Widget _buildAddNodeDialog() {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final controller = TextEditingController();

    return AlertDialog(
      backgroundColor: isDarkMode ? const Color(0xFF1C1C1E) : null,
      title: Text(
        'Add New Node',
        style: GoogleFonts.lora(
          fontSize: 18,
          color: isDarkMode ? Colors.white : null,
        ),
      ),
      content: TextField(
        controller: controller,
        style: TextStyle(color: isDarkMode ? Colors.white : null),
        decoration: InputDecoration(
          labelText: 'Node Name',
          labelStyle: TextStyle(
            color: isDarkMode ? Colors.white.withOpacity(0.7) : null,
          ),
          hintText: 'Enter node name...',
          hintStyle: TextStyle(
            color: isDarkMode ? Colors.white.withOpacity(0.5) : null,
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
        autofocus: true,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            'Cancel',
            style: GoogleFonts.lora(color: isDarkMode ? Colors.white : null),
          ),
        ),
        ElevatedButton(
          onPressed: () {
            if (controller.text.trim().isNotEmpty) {
              _addNewNode(controller.text.trim());
              Navigator.pop(context);
            }
          },
          child: Text('Add', style: GoogleFonts.lora()),
        ),
      ],
    );
  }

  void _addNewNode(String nodeName) {
    if (_nodes.any((node) => node.id == nodeName)) {
      _showSnackBar('Node "$nodeName" already exists');
      return;
    }

    setState(() {
      _nodes.add(NodeInput(id: nodeName, next: []));
      _isModified = true;
    });
  }

  void _deleteSelectedNode() {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    if (_selectedNodeId == null) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDarkMode ? const Color(0xFF1C1C1E) : null,
        title: Text(
          'Delete Node',
          style: GoogleFonts.lora(
            fontSize: 18,
            color: isDarkMode ? Colors.white : null,
          ),
        ),
        content: Text(
          'Are you sure you want to delete "$_selectedNodeId"? This will also remove all connections to this node.',
          style: GoogleFonts.lora(color: isDarkMode ? Colors.white : null),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: GoogleFonts.lora(color: isDarkMode ? Colors.white : null),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              _deleteNode(_selectedNodeId!);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('Delete', style: GoogleFonts.lora()),
          ),
        ],
      ),
    );
  }

  void _deleteNode(String nodeId) {
    setState(() {
      _nodes.removeWhere((node) => node.id == nodeId);

      for (var node in _nodes) {
        node.next.removeWhere((edge) => edge.outcome == nodeId);
      }

      _selectedNodeId = null;
      _isModified = true;
    });
  }

  void _showAddConnectionDialog() {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    if (_selectedNodeId == null) return;

    final availableNodes = _nodes
        .where((node) => node.id != _selectedNodeId)
        .map((node) => node.id)
        .toList();

    if (availableNodes.isEmpty) {
      _showSnackBar('No available nodes to connect to');
      return;
    }

    String? selectedTarget;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDarkMode ? const Color(0xFF1C1C1E) : null,
        title: Text(
          'Add Connection',
          style: GoogleFonts.lora(
            fontSize: 18,
            color: isDarkMode ? Colors.white : null,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'From: $_selectedNodeId',
              style: GoogleFonts.lora(
                fontWeight: FontWeight.w600,
                color: isDarkMode ? Colors.white : null,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'To:',
              style: GoogleFonts.lora(color: isDarkMode ? Colors.white : null),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              dropdownColor: isDarkMode ? const Color(0xFF2C2C2E) : null,
              decoration: InputDecoration(
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
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
              ),
              items: availableNodes.map((nodeId) {
                return DropdownMenuItem(
                  value: nodeId,
                  child: Text(
                    nodeId,
                    style: GoogleFonts.lora(
                      color: isDarkMode ? Colors.white : null,
                    ),
                  ),
                );
              }).toList(),
              onChanged: (value) {
                selectedTarget = value;
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: GoogleFonts.lora(color: isDarkMode ? Colors.white : null),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              if (selectedTarget != null) {
                _addConnection(_selectedNodeId!, selectedTarget!);
                Navigator.pop(context);
              }
            },
            child: Text('Connect', style: GoogleFonts.lora()),
          ),
        ],
      ),
    );
  }

  void _addConnection(String fromId, String toId) {
    final fromNode = _nodes.firstWhere((node) => node.id == fromId);

    if (fromNode.next.any((edge) => edge.outcome == toId)) {
      _showSnackBar('Connection already exists');
      return;
    }

    setState(() {
      fromNode.next.add(EdgeInput(outcome: toId));
      _isModified = true;
    });
  }

  void _editSelectedNode() {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    if (_selectedNodeId == null) return;

    final controller = TextEditingController(text: _selectedNodeId);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDarkMode ? const Color(0xFF1C1C1E) : null,
        title: Text(
          'Edit Node',
          style: GoogleFonts.lora(
            fontSize: 18,
            color: isDarkMode ? Colors.white : null,
          ),
        ),
        content: TextField(
          controller: controller,
          style: TextStyle(color: isDarkMode ? Colors.white : null),
          decoration: InputDecoration(
            labelText: 'Node Name',
            labelStyle: TextStyle(
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
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: GoogleFonts.lora(color: isDarkMode ? Colors.white : null),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                _renameNode(_selectedNodeId!, controller.text.trim());
                Navigator.pop(context);
              }
            },
            child: Text('Save', style: GoogleFonts.lora()),
          ),
        ],
      ),
    );
  }

  void _renameNode(String oldId, String newId) {
    if (oldId == newId) return;

    if (_nodes.any((node) => node.id == newId)) {
      _showSnackBar('Node "$newId" already exists');
      return;
    }

    setState(() {
      final node = _nodes.firstWhere((node) => node.id == oldId);
      final updatedNode = NodeInput(id: newId, next: node.next);
      final nodeIndex = _nodes.indexOf(node);
      _nodes[nodeIndex] = updatedNode;

      for (var n in _nodes) {
        for (var edge in n.next) {
          if (edge.outcome == oldId) {
            final edgeIndex = n.next.indexOf(edge);
            n.next[edgeIndex] = EdgeInput(outcome: newId);
          }
        }
      }

      _selectedNodeId = newId;
      _isModified = true;
    });
  }

  void _resetFlowchart() {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDarkMode ? const Color(0xFF1C1C1E) : null,
        title: Text(
          'Reset Flowchart',
          style: GoogleFonts.lora(
            fontSize: 18,
            color: isDarkMode ? Colors.white : null,
          ),
        ),
        content: Text(
          'Are you sure you want to reset the flowchart? This will remove all your changes.',
          style: GoogleFonts.lora(color: isDarkMode ? Colors.white : null),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: GoogleFonts.lora(color: isDarkMode ? Colors.white : null),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              _initializeDefaultFlowchart();
              setState(() {
                _selectedNodeId = null;
                _isModified = true;
              });
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: Text('Reset', style: GoogleFonts.lora()),
          ),
        ],
      ),
    );
  }

  void _previewFlowchart() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FlowchartPreviewScreen(
          title: _titleController.text,
          description: _descriptionController.text,
          nodes: _nodes,
        ),
      ),
    );
  }

  void _saveFlowchart() {
    if (_titleController.text.trim().isEmpty) {
      _showSnackBar('Please enter a flowchart title');
      return;
    }

    final flowchartData = {
      'title': _titleController.text.trim(),
      'description': _descriptionController.text.trim(),
      'nodes': nodeInputToJson(_nodes),
      'nodeCount': _nodes.length,
      'createdAt': DateTime.now().toIso8601String(),
    };

    Navigator.pop(context, flowchartData);
  }

  void _handleBack() {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    if (_isModified) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: isDarkMode ? const Color(0xFF1C1C1E) : null,
          title: Text(
            'Unsaved Changes',
            style: GoogleFonts.lora(
              fontSize: 18,
              color: isDarkMode ? Colors.white : null,
            ),
          ),
          content: Text(
            'You have unsaved changes. Do you want to discard them?',
            style: GoogleFonts.lora(color: isDarkMode ? Colors.white : null),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Cancel',
                style: GoogleFonts.lora(
                  color: isDarkMode ? Colors.white : null,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: Text('Discard', style: GoogleFonts.lora()),
            ),
          ],
        ),
      );
    } else {
      Navigator.pop(context);
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.lora()),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

class FlowchartPreviewScreen extends StatelessWidget {
  final String title;
  final String description;
  final List<NodeInput> nodes;

  const FlowchartPreviewScreen({
    Key? key,
    required this.title,
    required this.description,
    required this.nodes,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDarkMode ? const Color(0xFF1C1C1E) : Colors.white,
      appBar: AppBar(
        backgroundColor: isDarkMode ? const Color(0xFF2C2C2E) : Colors.white,
        elevation: 1,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: isDarkMode ? Colors.white : Colors.black87,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Flowchart Preview',
          style: GoogleFonts.lora(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: isDarkMode ? Colors.white : Colors.black87,
          ),
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.lora(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: isDarkMode ? Colors.white : Colors.black87,
                  ),
                ),
                if (description.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    description,
                    style: GoogleFonts.lora(
                      fontSize: 14,
                      color: isDarkMode
                          ? Colors.white.withOpacity(0.7)
                          : Colors.grey[700],
                    ),
                  ),
                ],
              ],
            ),
          ),
          Expanded(
            child: InteractiveViewer(
              constrained: false,
              child: Container(
                width: 800,
                height: 600,
                child: nodes.isNotEmpty
                    ? DirectGraph(
                        list: nodes,
                        defaultCellSize: const Size(120, 60),
                        cellPadding: const EdgeInsets.all(20),
                        orientation: MatrixOrientation.Vertical,
                        nodeBuilder: (context, node) => Container(
                          decoration: BoxDecoration(
                            color: isDarkMode
                                ? Colors.blue[800]?.withOpacity(0.3)
                                : Colors.blue[50],
                            border: Border.all(
                              color: isDarkMode
                                  ? Colors.blue[400]!
                                  : Colors.blue!,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Center(
                            child: Padding(
                              padding: const EdgeInsets.all(8),
                              child: Text(
                                node.id,
                                style: GoogleFonts.lora(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: isDarkMode
                                      ? Colors.blue[200]
                                      : Colors.blue[800],
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                        ),
                      )
                    : Container(
                        width: 800,
                        height: 600,
                        color: isDarkMode
                            ? const Color(0xFF2C2C2E)
                            : Colors.grey[100],
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.info_outline,
                                size: 64,
                                color: isDarkMode
                                    ? Colors.white.withOpacity(0.4)
                                    : Colors.grey[400],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No flowchart data available',
                                style: TextStyle(
                                  fontSize: 18,
                                  color: isDarkMode
                                      ? Colors.white.withOpacity(0.6)
                                      : Colors.grey[600],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

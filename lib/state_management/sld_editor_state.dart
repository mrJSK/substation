// lib/state_management/sld_editor_state.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart'; // For generating unique IDs
import 'package:flutter/foundation.dart'
    show
        kIsWeb; // For conditional imports if needed for platform-specific features

import '../models/sld_models.dart'; // Import your new SLD models
import '../utils/snackbar_utils.dart'; // For showing messages

// You'll need to add uuid to your pubspec.yaml if not already added:
// dependencies:
//   uuid: ^4.3.3

const Uuid _uuid = Uuid();

class SldEditorState with ChangeNotifier {
  final String substationId;
  SldData? _sldData;
  bool _isLoading = false;
  String? _error;
  bool _isDirty = false; // Tracks if there are unsaved changes
  SldInteractionMode _interactionMode = SldInteractionMode.select;

  // For Undo/Redo history
  final List<SldData> _undoStack = [];
  final List<SldData> _redoStack = [];
  static const int _maxHistorySize =
      50; // Limit history to prevent excessive memory usage

  // For connection drawing
  String? _drawingSourceNodeId;
  String? _drawingSourceConnectionPointId;

  // Firebase instance
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Store a BuildContext reference for SnackBarUtils.
  // This is a common pattern when a non-widget class needs to show UI feedback.
  // Make sure to set this context when the SldEditorState is provided.
  BuildContext? _context;

  SldEditorState({required this.substationId});

  // Method to set the BuildContext for SnackBarUtils
  void setContext(BuildContext context) {
    _context = context;
  }

  // --- Getters for UI to consume ---
  SldData? get sldData => _sldData;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isDirty => _isDirty;
  SldInteractionMode get interactionMode => _interactionMode;
  bool get canUndo => _undoStack.isNotEmpty;
  bool get canRedo => _redoStack.isNotEmpty;

  // Getters for connection drawing state
  String? get drawingSourceNodeId => _drawingSourceNodeId;
  String? get drawingSourceConnectionPointId => _drawingSourceConnectionPointId;

  // --- Core State Management ---

  /// Sets the current SLD data and updates dirty state.
  void _setSldData(
    SldData newData, {
    bool addToHistory = true,
    bool markDirty = true,
  }) {
    if (_sldData != null && addToHistory) {
      // Deep copy the current state before adding to history
      _undoStack.add(SldData.fromJson(_sldData!.toJson()));
      if (_undoStack.length > _maxHistorySize) {
        _undoStack.removeAt(0); // Trim oldest history
      }
      _redoStack.clear(); // Clear redo stack on new action
    }
    _sldData = newData;
    _isDirty = markDirty;
    notifyListeners();
  }

  /// Changes the current interaction mode.
  void setInteractionMode(SldInteractionMode mode) {
    _interactionMode = mode;
    // Clear any pending connection drawing if mode changes
    _drawingSourceNodeId = null;
    _drawingSourceConnectionPointId = null;
    notifyListeners();
  }

  // --- Data Loading and Saving ---

  /// Loads the SLD data for the given substation from Firestore.
  Future<void> loadSld() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final sldDoc = await _firestore
          .collection('substationSlds')
          .doc(substationId)
          .get();
      if (sldDoc.exists && sldDoc.data() != null) {
        final loadedData = SldData.fromJson(sldDoc.data()!);
        _setSldData(loadedData, addToHistory: false, markDirty: false);
        debugPrint('SLD for $substationId loaded successfully.');
      } else {
        _sldData = SldData(
          substationId: substationId,
          elements: {},
          currentZoom: 1.0,
          currentPanOffset: Offset.zero,
          interactionMode: SldInteractionMode.select,
        );
        _isDirty = true; // New SLD, needs initial save
        debugPrint('No SLD found for $substationId. Initializing new SLD.');
      }
    } catch (e) {
      _error = 'Failed to load SLD: $e';
      debugPrint('Error loading SLD: $e');
      if (_context != null) {
        // Pass context to SnackBarUtils
        SnackBarUtils.showSnackBar(
          _context!,
          'Error loading SLD: ${e.toString()}',
          isError: true,
        );
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Saves the current SLD data to Firestore.
  Future<void> saveSld() async {
    if (_sldData == null || !_isDirty) {
      if (_context != null) {
        // Pass context to SnackBarUtils
        SnackBarUtils.showSnackBar(
          _context!,
          'No changes to save.',
          isError: false,
        );
      }
      return;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _firestore
          .collection('substationSlds')
          .doc(substationId)
          .set(_sldData!.toJson());
      _isDirty = false; // Successfully saved
      if (_context != null) {
        // Pass context to SnackBarUtils
        SnackBarUtils.showSnackBar(_context!, 'SLD saved successfully!');
      }
      debugPrint('SLD for $substationId saved successfully.');
    } catch (e) {
      _error = 'Failed to save SLD: $e';
      if (_context != null) {
        // Pass context to SnackBarUtils
        SnackBarUtils.showSnackBar(
          _context!,
          'Failed to save SLD: ${e.toString()}',
          isError: true,
        );
      }
      debugPrint('Error saving SLD: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // --- Interaction Methods (Offline Changes) ---

  /// Adds a new element (node, edge, text label) to the SLD.
  void addElement(SldElement element) {
    if (_sldData == null) return;
    _sldData!.lastZIndex++; // Increment zIndex for new element
    element.zIndex = _sldData!.lastZIndex; // Assign to new element

    _setSldData(
      SldData.fromJson(_sldData!.toJson()) // Deep copy current state
        ..elements[element.id] = element, // Add new element
    );
    debugPrint('Added element: ${element.id} (${element.type.name})');
  }

  /// Removes an element from the SLD.
  void removeElement(String elementId) {
    if (_sldData == null) return;
    final SldData newData = SldData.fromJson(_sldData!.toJson());

    // If it's a node, also remove connected edges
    if (newData.elements.containsKey(elementId) &&
        newData.elements[elementId]!.type == SldElementType.node) {
      newData.elements.remove(elementId);
      newData.elements.removeWhere((key, value) {
        return value.type == SldElementType.edge &&
            ((value as SldEdge).sourceNodeId == elementId ||
                (value as SldEdge).targetNodeId == elementId);
      });
    } else {
      newData.elements.remove(elementId);
    }

    newData.selectedElementIds.remove(elementId); // Deselect if removed
    _setSldData(newData);
    debugPrint('Removed element: $elementId');
  }

  /// Moves an SLD Node.
  void moveNode(String nodeId, Offset newPosition) {
    if (_sldData == null || !_sldData!.elements.containsKey(nodeId)) return;
    final SldData newData = SldData.fromJson(_sldData!.toJson());
    (newData.elements[nodeId] as SldNode).position = newPosition;
    _setSldData(newData);
    // debugPrint('Moved node $nodeId to $newPosition'); // Commented for performance during drag
  }

  /// Updates properties of an SLD element.
  void updateElementProperties(String elementId, Map<String, dynamic> updates) {
    if (_sldData == null || !_sldData!.elements.containsKey(elementId)) return;
    final SldData newData = SldData.fromJson(_sldData!.toJson());
    // Update generic properties
    newData.elements[elementId]!.properties.addAll(updates);

    // Handle specific field updates if the element has them directly (e.g., SldEdge.isDashed)
    if (newData.elements[elementId]!.type == SldElementType.edge) {
      final SldEdge edge = newData.elements[elementId] as SldEdge;
      if (updates.containsKey('isDashed')) {
        edge.isDashed = updates['isDashed'] as bool;
      }
      if (updates.containsKey('lineColor')) {
        edge.lineColor = updates['lineColor'] as Color;
      }
      if (updates.containsKey('lineWidth')) {
        edge.lineWidth = (updates['lineWidth'] as num).toDouble();
      }
      if (updates.containsKey('lineJoin')) {
        edge.lineJoin = updates['lineJoin'] as SldLineJoin;
      }
      // Add other specific fields if they exist and are updated
    } else if (newData.elements[elementId]!.type == SldElementType.node) {
      final SldNode node = newData.elements[elementId] as SldNode;
      if (updates.containsKey('position')) {
        node.position = updates['position'] as Offset;
      }
      if (updates.containsKey('size')) {
        node.size = updates['size'] as Size;
      }
      if (updates.containsKey('fillColor')) {
        node.fillColor = updates['fillColor'] as Color;
      }
      if (updates.containsKey('strokeColor')) {
        node.strokeColor = updates['strokeColor'] as Color;
      }
      // Add other specific fields if they exist and are updated
    } else if (newData.elements[elementId]!.type == SldElementType.textLabel) {
      final SldTextLabel textLabel =
          newData.elements[elementId] as SldTextLabel;
      if (updates.containsKey('text')) {
        textLabel.text = updates['text'] as String;
      }
      if (updates.containsKey('textStyle')) {
        textLabel.textStyle = updates['textStyle'] as TextStyle;
      }
      if (updates.containsKey('textAlign')) {
        textLabel.textAlign = updates['textAlign'] as TextAlign;
      }
    }

    _setSldData(newData);
    debugPrint('Updated properties for element: $elementId');
  }

  /// Selects a single element.
  void selectElement(String elementId) {
    if (_sldData == null) return;
    if (_sldData!.selectedElementIds.contains(elementId) &&
        _sldData!.selectedElementIds.length == 1) {
      // Already selected and only one selected, do nothing
      return;
    }
    final SldData newData = SldData.fromJson(_sldData!.toJson());
    newData.selectedElementIds.clear();
    newData.selectedElementIds.add(elementId);
    _setSldData(newData);
    debugPrint('Selected element: $elementId');
  }

  /// Adds an element to current selection (for multi-selection).
  void addElementToSelection(String elementId) {
    if (_sldData == null) return;
    final SldData newData = SldData.fromJson(_sldData!.toJson());
    newData.selectedElementIds.add(elementId);
    _setSldData(newData);
    debugPrint('Added $elementId to selection.');
  }

  /// Removes an element from current selection.
  void removeElementFromSelection(String elementId) {
    if (_sldData == null) return;
    final SldData newData = SldData.fromJson(_sldData!.toJson());
    newData.selectedElementIds.remove(elementId);
    _setSldData(newData);
    debugPrint('Removed $elementId from selection.');
  }

  /// Clears all selections.
  void clearSelection() {
    if (_sldData == null || _sldData!.selectedElementIds.isEmpty) return;
    final SldData newData = SldData.fromJson(_sldData!.toJson());
    newData.selectedElementIds.clear();
    _setSldData(newData);
    debugPrint('Selection cleared.');
  }

  /// Initiates the connection drawing process.
  void startDrawingConnection(
    String sourceNodeId,
    String sourceConnectionPointId,
  ) {
    _drawingSourceNodeId = sourceNodeId;
    _drawingSourceConnectionPointId = sourceConnectionPointId;
    setInteractionMode(SldInteractionMode.drawConnection);
    if (_context != null) {
      // Pass context to SnackBarUtils
      SnackBarUtils.showSnackBar(
        _context!,
        'Select target node to complete connection.',
      );
    }
    debugPrint(
      'Started drawing connection from node $sourceNodeId, point $sourceConnectionPointId',
    );
  }

  /// Completes the connection drawing process by adding an SldEdge.
  void completeDrawingConnection(
    String targetNodeId,
    String targetConnectionPointId,
  ) {
    if (_drawingSourceNodeId == null ||
        _drawingSourceConnectionPointId == null) {
      if (_context != null) {
        // Pass context to SnackBarUtils
        SnackBarUtils.showSnackBar(
          _context!,
          'Connection drawing not initiated.',
          isError: true,
        );
      }
      return;
    }
    if (_sldData == null) return;

    final newEdge = SldEdge(
      id: _uuid.v4(),
      sourceNodeId: _drawingSourceNodeId!,
      sourceConnectionPointId: _drawingSourceConnectionPointId!,
      targetNodeId: targetNodeId,
      targetConnectionPointId: targetConnectionPointId,
      lineColor: Colors.blue, // Default connection color
      lineWidth: 2.0,
      lineJoin: SldLineJoin.round, // Use SldLineJoin
      isDashed: false,
      properties: {'voltageLevel': 'KV'}, // Example property
    );

    addElement(newEdge); // Use addElement to handle history and dirty state
    setInteractionMode(SldInteractionMode.select); // Reset mode
    _drawingSourceNodeId = null;
    _drawingSourceConnectionPointId = null;
    if (_context != null) {
      // Pass context to SnackBarUtils
      SnackBarUtils.showSnackBar(_context!, 'Connection added successfully!');
    }
    debugPrint('Completed drawing connection: ${newEdge.id}');
  }

  /// Cancels the connection drawing process.
  void cancelDrawingConnection() {
    _drawingSourceNodeId = null;
    _drawingSourceConnectionPointId = null;
    setInteractionMode(SldInteractionMode.select); // Reset mode
    if (_context != null) {
      // Pass context to SnackBarUtils
      SnackBarUtils.showSnackBar(_context!, 'Connection drawing cancelled.');
    }
    debugPrint('Connection drawing cancelled.');
  }

  /// Updates the canvas zoom and pan offset.
  void updateCanvasTransform(double scale, Offset offset) {
    if (_sldData == null) return;
    // Only update if actual change occurs to prevent excessive dirty marking
    if (_sldData!.currentZoom != scale ||
        _sldData!.currentPanOffset != offset) {
      final SldData newData = SldData.fromJson(_sldData!.toJson()); // Deep copy
      newData.currentZoom = scale;
      newData.currentPanOffset = offset;
      _setSldData(newData); // Mark dirty for persistence of canvas state
      debugPrint('Canvas transform updated: Zoom=$scale, Pan=$offset');
    }
  }

  // --- Undo/Redo Functionality ---

  void undo() {
    if (_undoStack.isNotEmpty) {
      _redoStack.add(
        SldData.fromJson(_sldData!.toJson()),
      ); // Add current state to redo
      final previousState = _undoStack.removeLast();
      _setSldData(
        previousState,
        addToHistory: false,
        markDirty: true,
      ); // Don't add to undo history again
      if (_context != null) {
        // Pass context to SnackBarUtils
        SnackBarUtils.showSnackBar(_context!, 'Undo successful.');
      }
      debugPrint(
        'Undo: Reverted to previous state. Undo stack size: ${_undoStack.length}',
      );
    } else {
      if (_context != null) {
        // Pass context to SnackBarUtils
        SnackBarUtils.showSnackBar(
          _context!,
          'Nothing to undo.',
          isError: false,
        );
      }
      debugPrint('Undo: Undo stack is empty.');
    }
  }

  void redo() {
    if (_redoStack.isNotEmpty) {
      _undoStack.add(
        SldData.fromJson(_sldData!.toJson()),
      ); // Add current state to undo
      final nextState = _redoStack.removeLast();
      _setSldData(
        nextState,
        addToHistory: false,
        markDirty: true,
      ); // Don't add to undo history again
      if (_context != null) {
        // Pass context to SnackBarUtils
        SnackBarUtils.showSnackBar(_context!, 'Redo successful.');
      }
      debugPrint(
        'Redo: Applied next state. Redo stack size: ${_redoStack.length}',
      );
    } else {
      if (_context != null) {
        // Pass context to SnackBarUtils
        SnackBarUtils.showSnackBar(
          _context!,
          'Nothing to redo.',
          isError: false,
        );
      }
      debugPrint('Redo: Redo stack is empty.');
    }
  }

  @override
  void dispose() {
    _context = null; // Clear context reference on dispose
    super.dispose();
    debugPrint('SldEditorState disposed.');
  }

  void setSldData(
    SldData newData, {
    bool addToHistory = true,
    bool markDirty = true,
  }) {
    if (_sldData != null && addToHistory) {
      // Deep copy the current state before adding to history
      _undoStack.add(SldData.fromJson(_sldData!.toJson()));
      if (_undoStack.length > _maxHistorySize) {
        _undoStack.removeAt(0); // Trim oldest history
      }
      _redoStack.clear(); // Clear redo stack on new action
    }
    _sldData = newData;
    _isDirty = markDirty;
    notifyListeners();
  }
}

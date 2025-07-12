// lib/models/sld_models.dart
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart'; // For generating unique IDs

// You'll need to add uuid to your pubspec.yaml:
// dependencies:
//   uuid: ^4.3.3

const Uuid _uuid = Uuid();

/// Enum to define the type of SLD element (Node, Edge, TextLabel, etc.)
enum SldElementType {
  node,
  edge,
  textLabel,
  group,
  // Add more types as needed (e.g., comment, image)
}

/// Enum to define the shape/visual representation of an SLD Node
enum SldNodeShape {
  rectangle,
  circle,
  custom, // For equipment icons
  busbar, // Specific shape for busbars
  // Add more predefined shapes
}

/// Enum to define the direction of a connection point on a node
enum ConnectionDirection {
  north,
  south,
  east,
  west,
  any, // Can connect from any direction
}

// NEW: Define an enum for line join styles, as LineJoin is not a global enum.
enum SldLineJoin { miter, round, bevel }

/// Enum to define the current interaction mode in the SLD editor
enum SldInteractionMode {
  /// Default mode, allows selection and dragging of elements
  select,

  /// Drawing a new connection between nodes
  drawConnection,

  /// Adding a new node (e.g., a new bay)
  addNode,

  /// Adding a new text label
  addText,

  /// Pan the canvas without selecting/moving elements
  pan,

  /// Zoom in/out without other interactions
  zoom,
  // Add more modes (e.g., delete, resize, group)
}

/// Represents a point on an SldNode where an SldEdge can connect.
class SldConnectionPoint {
  final String id;
  final Offset localOffset; // Offset relative to the node's top-left (0,0)
  final ConnectionDirection direction; // Preferred direction for routing

  SldConnectionPoint({
    required this.id,
    required this.localOffset,
    required this.direction,
  });

  // Factory constructor for deserialization from JSON
  factory SldConnectionPoint.fromJson(Map<String, dynamic> json) {
    return SldConnectionPoint(
      id: json['id'] as String,
      localOffset: Offset(
        (json['dx'] as num).toDouble(),
        (json['dy'] as num).toDouble(),
      ),
      direction: ConnectionDirection.values.byName(json['direction'] as String),
    );
  }

  // Method for serialization to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'dx': localOffset.dx,
      'dy': localOffset.dy,
      'direction': direction.name,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SldConnectionPoint &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          localOffset == other.localOffset &&
          direction == other.direction;

  @override
  int get hashCode => id.hashCode ^ localOffset.hashCode ^ direction.hashCode;
}

/// Base class for all elements on the SLD canvas.
abstract class SldElement {
  final String id;
  Offset position; // Top-left corner of the element on the canvas
  Size size; // Dimensions of the element
  int zIndex; // Controls rendering order (higher zIndex means on top)
  Map<String, dynamic> properties; // Flexible map for custom properties
  SldElementType type; // Type of the element (node, edge, textLabel)

  SldElement({
    String? id,
    required this.position,
    required this.size,
    this.zIndex = 0,
    Map<String, dynamic>? properties,
    required this.type,
  }) : id = id ?? _uuid.v4(), // Generate ID if not provided
       properties = properties ?? {};

  // Factory constructor for deserialization (to be implemented by subclasses)
  factory SldElement.fromJson(Map<String, dynamic> json) {
    final type = SldElementType.values.byName(json['type'] as String);
    switch (type) {
      case SldElementType.node:
        return SldNode.fromJson(json);
      case SldElementType.edge:
        return SldEdge.fromJson(json);
      case SldElementType.textLabel:
        return SldTextLabel.fromJson(json);
      // Add cases for other types here
      default:
        throw ArgumentError('Unknown SldElementType: ${json['type']}');
    }
  }

  // Method for serialization to JSON (to be implemented by subclasses)
  Map<String, dynamic> toJson();
}

/// Represents a drawable node (e.g., a bay, an equipment, or a custom shape) on the SLD.
class SldNode extends SldElement {
  SldNodeShape nodeShape; // Visual shape of the node
  double rotationAngle; // Rotation in radians
  Color? fillColor;
  Color? strokeColor;
  double strokeWidth;
  String? associatedBayId; // Link to the original BayModel if applicable
  String?
  associatedEquipmentId; // Link to the original EquipmentInstance if applicable
  Map<String, SldConnectionPoint> connectionPoints; // Named connection points

  SldNode({
    super.id,
    required super.position,
    required super.size,
    super.zIndex,
    super.properties,
    this.nodeShape = SldNodeShape.rectangle,
    this.rotationAngle = 0.0,
    this.fillColor,
    this.strokeColor,
    this.strokeWidth = 2.0,
    this.associatedBayId,
    this.associatedEquipmentId,
    Map<String, SldConnectionPoint>? connectionPoints,
    required String bayId,
  }) : connectionPoints = connectionPoints ?? {},
       super(type: SldElementType.node);

  factory SldNode.fromJson(Map<String, dynamic> json) {
    return SldNode(
      id: json['id'] as String,
      position: Offset(
        (json['positionX'] as num).toDouble(),
        (json['positionY'] as num).toDouble(),
      ),
      size: Size(
        (json['width'] as num).toDouble(),
        (json['height'] as num).toDouble(),
      ),
      zIndex: json['zIndex'] as int? ?? 0,
      properties: (json['properties'] as Map<String, dynamic>? ?? {})
          .cast<String, dynamic>(),
      nodeShape: SldNodeShape.values.byName(json['nodeShape'] as String),
      rotationAngle: (json['rotationAngle'] as num).toDouble(),
      fillColor: json['fillColor'] != null
          ? Color(json['fillColor'] as int)
          : null,
      strokeColor: json['strokeColor'] != null
          ? Color(json['strokeColor'] as int)
          : null,
      strokeWidth: (json['strokeWidth'] as num?)?.toDouble() ?? 2.0,
      associatedBayId: json['associatedBayId'] as String?,
      associatedEquipmentId: json['associatedEquipmentId'] as String?,
      connectionPoints:
          (json['connectionPoints'] as Map<String, dynamic>? ?? {}).map(
            (key, value) => MapEntry(
              key,
              SldConnectionPoint.fromJson(value as Map<String, dynamic>),
            ),
          ),
      bayId: json['bayId'] as String? ?? '',
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.name,
      'positionX': position.dx,
      'positionY': position.dy,
      'width': size.width,
      'height': size.height,
      'zIndex': zIndex,
      'properties': properties,
      'nodeShape': nodeShape.name,
      'rotationAngle': rotationAngle,
      'fillColor': fillColor?.value,
      'strokeColor': strokeColor?.value,
      'strokeWidth': strokeWidth,
      'associatedBayId': associatedBayId,
      'associatedEquipmentId': associatedEquipmentId,
      'connectionPoints': connectionPoints.map(
        (key, value) => MapEntry(key, value.toJson()),
      ),
    };
  }

  // Helper to create common connection points for a rectangle node
  static Map<String, SldConnectionPoint> createRectConnectionPoints(Size size) {
    return {
      'top': SldConnectionPoint(
        id: 'top',
        localOffset: Offset(size.width / 2, 0),
        direction: ConnectionDirection.north,
      ),
      'bottom': SldConnectionPoint(
        id: 'bottom',
        localOffset: Offset(size.width / 2, size.height),
        direction: ConnectionDirection.south,
      ),
      'left': SldConnectionPoint(
        id: 'left',
        localOffset: Offset(0, size.height / 2),
        direction: ConnectionDirection.west,
      ),
      'right': SldConnectionPoint(
        id: 'right',
        localOffset: Offset(size.width, size.height / 2),
        direction: ConnectionDirection.east,
      ),
    };
  }
}

/// Represents a connection line between two SldNodes.
class SldEdge extends SldElement {
  String sourceNodeId;
  String sourceConnectionPointId; // ID of the connection point on source node
  String targetNodeId;
  String targetConnectionPointId; // ID of the connection point on target node
  List<Offset> pathPoints; // Optional intermediate points for routing
  Color lineColor;
  double lineWidth;
  SldLineJoin lineJoin; // How lines segments join (miter, round, bevel)
  bool isDashed; // For dashed lines (e.g., control circuits)
  Map<String, dynamic> metadata; // For connection specific data

  SldEdge({
    super.id,
    required this.sourceNodeId,
    required this.sourceConnectionPointId,
    required this.targetNodeId,
    required this.targetConnectionPointId,
    this.pathPoints = const [], // Default to straight line
    this.lineColor = Colors.black,
    this.lineWidth = 2.0,
    this.lineJoin = SldLineJoin.round, // Use the new SldLineJoin enum
    this.isDashed = false,
    Map<String, dynamic>? metadata,
    super.properties,
  }) : metadata = metadata ?? {},
       // Edges don't have a visible size/position of their own in the same way nodes do,
       // their size/position is derived from connected nodes. Using dummy values.
       super(position: Offset.zero, size: Size.zero, type: SldElementType.edge);

  factory SldEdge.fromJson(Map<String, dynamic> json) {
    return SldEdge(
      id: json['id'] as String,
      sourceNodeId: json['sourceNodeId'] as String,
      sourceConnectionPointId: json['sourceConnectionPointId'] as String,
      targetNodeId: json['targetNodeId'] as String,
      targetConnectionPointId: json['targetConnectionPointId'] as String,
      pathPoints:
          (json['pathPoints'] as List<dynamic>?)
              ?.map(
                (p) => Offset(
                  (p['dx'] as num).toDouble(),
                  (p['dy'] as num).toDouble(),
                ),
              )
              .toList() ??
          [],
      lineColor: Color(json['lineColor'] as int),
      lineWidth: (json['lineWidth'] as num).toDouble(),
      lineJoin: SldLineJoin.values.byName(
        json['lineJoin'] as String,
      ), // Use new SldLineJoin enum
      isDashed: json['isDashed'] as bool? ?? false,
      metadata: (json['metadata'] as Map<String, dynamic>? ?? {})
          .cast<String, dynamic>(),
      properties: (json['properties'] as Map<String, dynamic>? ?? {})
          .cast<String, dynamic>(),
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.name,
      'sourceNodeId': sourceNodeId,
      'sourceConnectionPointId': sourceConnectionPointId,
      'targetNodeId': targetNodeId,
      'targetConnectionPointId': targetConnectionPointId,
      'pathPoints': pathPoints.map((p) => {'dx': p.dx, 'dy': p.dy}).toList(),
      'lineColor': lineColor.value,
      'lineWidth': lineWidth,
      'lineJoin': lineJoin.name, // Use new SldLineJoin enum
      'isDashed': isDashed,
      'metadata': metadata,
      'properties': properties,
      // position and size are dummy for edges as they are derived.
      'positionX': position.dx,
      'positionY': position.dy,
      'width': size.width,
      'height': size.height,
      'zIndex': zIndex,
    };
  }
}

/// Represents a simple text label on the SLD.
class SldTextLabel extends SldElement {
  String text;
  TextStyle textStyle;
  TextAlign textAlign;

  SldTextLabel({
    super.id,
    required super.position,
    required super.size, // Size is typically based on text layout
    super.zIndex,
    super.properties,
    required this.text,
    TextStyle? textStyle,
    this.textAlign = TextAlign.center,
  }) : textStyle =
           textStyle ?? const TextStyle(color: Colors.black, fontSize: 12),
       super(type: SldElementType.textLabel);

  factory SldTextLabel.fromJson(Map<String, dynamic> json) {
    return SldTextLabel(
      id: json['id'] as String,
      position: Offset(
        (json['positionX'] as num).toDouble(),
        (json['positionY'] as num).toDouble(),
      ),
      size: Size(
        (json['width'] as num).toDouble(),
        (json['height'] as num).toDouble(),
      ),
      zIndex: json['zIndex'] as int? ?? 0,
      properties: (json['properties'] as Map<String, dynamic>? ?? {})
          .cast<String, dynamic>(),
      text: json['text'] as String,
      // FIX: Correctly deserialize TextStyle properties
      textStyle: TextStyle(
        color: json['textStyle']?['color'] != null
            ? Color(json['textStyle']['color'] as int)
            : null,
        fontSize: (json['textStyle']?['fontSize'] as num?)?.toDouble(),
        fontWeight: json['textStyle']?['fontWeight'] != null
            ? FontWeight.values.firstWhere(
                (e) =>
                    e.toString() ==
                    'FontWeight.${json['textStyle']['fontWeight']}',
                orElse: () => FontWeight.normal, // Default if not found
              )
            : null,
        fontStyle: json['textStyle']?['fontStyle'] != null
            ? FontStyle.values.firstWhere(
                (e) =>
                    e.toString() ==
                    'FontStyle.${json['textStyle']['fontStyle']}',
                orElse: () => FontStyle.normal, // Default if not found
              )
            : null,
        // Add more TextStyle properties as needed
      ),
      textAlign: TextAlign.values.byName(
        json['textAlign'] as String? ?? 'center',
      ),
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.name,
      'positionX': position.dx,
      'positionY': position.dy,
      'width': size.width,
      'height': size.height,
      'zIndex': zIndex,
      'properties': properties,
      'text': text,
      // FIX: Serialize TextStyle properties correctly
      'textStyle': {
        'color': textStyle.color?.value,
        'fontSize': textStyle.fontSize,
        'fontWeight': textStyle.fontWeight
            ?.toString()
            .split('.')
            .last, // Store enum name
        'fontStyle': textStyle.fontStyle
            ?.toString()
            .split('.')
            .last, // Store enum name
      },
      'textAlign': textAlign.name,
    };
  }
}

/// Represents the entire state of a Single Line Diagram for a substation.
class SldData {
  final String substationId;
  Map<String, SldElement> elements; // All nodes, edges, text labels etc.
  double currentZoom;
  Offset currentPanOffset;
  Set<String> selectedElementIds; // IDs of currently selected elements
  SldInteractionMode interactionMode; // Current mode of interaction
  int lastZIndex; // To assign unique Z-index for new elements

  SldData({
    required this.substationId,
    Map<String, SldElement>? elements,
    this.currentZoom = 1.0,
    this.currentPanOffset = Offset.zero,
    Set<String>? selectedElementIds,
    this.interactionMode = SldInteractionMode.select,
    int? lastZIndex,
  }) : elements = elements ?? {},
       selectedElementIds = selectedElementIds ?? {},
       lastZIndex = lastZIndex ?? 0;

  // Factory constructor for deserialization from JSON
  factory SldData.fromJson(Map<String, dynamic> json) {
    final Map<String, SldElement> loadedElements = {};
    if (json['elements'] is Map) {
      (json['elements'] as Map<String, dynamic>).forEach((key, value) {
        loadedElements[key] = SldElement.fromJson(
          value as Map<String, dynamic>,
        );
      });
    }

    return SldData(
      substationId: json['substationId'] as String,
      elements: loadedElements,
      currentZoom: (json['currentZoom'] as num?)?.toDouble() ?? 1.0,
      currentPanOffset: Offset(
        (json['panDx'] as num?)?.toDouble() ?? 0.0,
        (json['panDy'] as num?)?.toDouble() ?? 0.0,
      ),
      selectedElementIds:
          (json['selectedElementIds'] as List<dynamic>?)
              ?.cast<String>()
              .toSet() ??
          {},
      interactionMode: SldInteractionMode.values.byName(
        json['interactionMode'] as String? ?? SldInteractionMode.select.name,
      ),
      lastZIndex: json['lastZIndex'] as int? ?? 0,
    );
  }

  // Method for serialization to JSON
  Map<String, dynamic> toJson() {
    return {
      'substationId': substationId,
      'elements': elements.map((key, value) => MapEntry(key, value.toJson())),
      'currentZoom': currentZoom,
      'panDx': currentPanOffset.dx,
      'panDy': currentPanOffset.dy,
      'selectedElementIds': selectedElementIds.toList(),
      'interactionMode': interactionMode.name,
      'lastZIndex': lastZIndex,
    };
  }

  // Helper method to get nodes specifically
  Map<String, SldNode> get nodes => elements.values
      .whereType<SldNode>()
      .map((e) => MapEntry(e.id, e))
      .fold(
        <String, SldNode>{},
        (map, entry) => map..[entry.key] = entry.value,
      );

  // Helper method to get edges specifically
  Map<String, SldEdge> get edges => elements.values
      .whereType<SldEdge>()
      .map((e) => MapEntry(e.id, e))
      .fold(
        <String, SldEdge>{},
        (map, entry) => map..[entry.key] = entry.value,
      );

  // Helper method to get text labels specifically
  Map<String, SldTextLabel> get textLabels => elements.values
      .whereType<SldTextLabel>()
      .map((e) => MapEntry(e.id, e))
      .fold(
        <String, SldTextLabel>{},
        (map, entry) => map..[entry.key] = entry.value,
      );
}

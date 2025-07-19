// lib/models/state_model.dart

class StateModel {
  final double id; // Matches SQL DOUBLE type for ID
  final String name; // Matches SQL VARCHAR type for name

  const StateModel({required this.id, required this.name});

  // Factory constructor to create a StateModel from a map (e.g., from JSON or Firestore data if applicable)
  factory StateModel.fromJson(Map<String, dynamic> json) {
    return StateModel(
      id: (json['id'] as num).toDouble(), // Ensure it's a double
      name: json['name'] as String,
    );
  }

  // Method to convert a StateModel to a map
  Map<String, dynamic> toJson() {
    return {'id': id, 'name': name};
  }

  // For easy comparison if needed
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StateModel && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'StateModel(id: $id, name: $name)';
  }
}

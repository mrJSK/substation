// lib/models/city_model.dart

class CityModel {
  final double id; // Matches SQL DOUBLE type for ID
  final String name; // Matches SQL VARCHAR type for name
  final double stateId; // Matches SQL DOUBLE type for state_id

  const CityModel({
    required this.id,
    required this.name,
    required this.stateId,
  });

  // Factory constructor to create a CityModel from a map
  factory CityModel.fromJson(Map<String, dynamic> json) {
    return CityModel(
      id: (json['id'] as num).toDouble(), // Ensure it's a double
      name: json['name'] as String,
      stateId: (json['state_id'] as num).toDouble(), // Ensure it's a double
    );
  }

  // Method to convert a CityModel to a map
  Map<String, dynamic> toJson() {
    return {'id': id, 'name': name, 'state_id': stateId};
  }

  // For easy comparison if needed
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CityModel &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          stateId == other.stateId;

  @override
  int get hashCode => id.hashCode ^ name.hashCode ^ stateId.hashCode;

  @override
  String toString() {
    return 'CityModel(id: $id, name: $name, stateId: $stateId)';
  }
}

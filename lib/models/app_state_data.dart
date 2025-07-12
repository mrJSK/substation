// lib/models/app_state_data.dart
import 'package:flutter/material.dart';

// State Model directly in AppStateData
class StateModel {
  final double id;
  final String name;

  StateModel({required this.id, required this.name});

  factory StateModel.fromMap(Map<String, dynamic> map) {
    return StateModel(id: map['id'] as double, name: map['name'] as String);
  }

  Map<String, dynamic> toMap() {
    return {'id': id, 'name': name};
  }
}

// City Model directly in AppStateData
class CityModel {
  final double id;
  final String name;
  final double stateId; // Links to StateModel.id

  CityModel({required this.id, required this.name, required this.stateId});

  factory CityModel.fromMap(Map<String, dynamic> map) {
    return CityModel(
      id: map['id'] as double,
      name: map['name'] as String,
      stateId: map['state_id'] as double,
    );
  }

  Map<String, dynamic> toMap() {
    return {'id': id, 'name': name, 'state_id': stateId};
  }
}

class AppStateData extends ChangeNotifier {
  // Singleton instance
  static final AppStateData _instance = AppStateData._internal();
  ThemeMode _themeMode = ThemeMode.light; // Default to light mode

  ThemeMode get themeMode => _themeMode;

  void toggleTheme() {
    _themeMode = _themeMode == ThemeMode.light
        ? ThemeMode.dark
        : ThemeMode.light;
    notifyListeners(); // Notify listeners that the theme has changed
  }

  factory AppStateData() {
    return _instance;
  }

  AppStateData._internal(); // Private constructor for the singleton pattern

  // Public in-memory storage for states and cities
  List<StateModel> allStateModels = [];
  List<CityModel> allCityModels = [];

  // Expose states as a list of names for dropdowns
  List<String> get states => allStateModels.map((s) => s.name).toList();

  // Setters for state and city models
  void setAllStateModels(List<StateModel> states) {
    allStateModels = states;
    notifyListeners();
  }

  void setAllCityModels(List<CityModel> cities) {
    allCityModels = cities;
    notifyListeners();
  }

  // Method to get city models for a specific state name
  List<CityModel> getCitiesForStateName(String stateName) {
    try {
      final stateId = allStateModels
          .firstWhere((state) => state.name == stateName)
          .id;
      return allCityModels.where((city) => city.stateId == stateId).toList();
    } catch (e) {
      print('Error getting cities for state $stateName: $e');
      return [];
    }
  }
}

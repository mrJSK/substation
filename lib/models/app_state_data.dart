// lib/models/app_state_data.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart'; // NEW: Import shared_preferences

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

  // Private constructor for the singleton pattern
  AppStateData._internal() {
    _loadThemeFromPrefs(); // NEW: Load theme when instance is created
  }

  factory AppStateData() {
    return _instance;
  }

  // NEW: Method to load theme from SharedPreferences
  Future<void> _loadThemeFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final String? savedTheme = prefs.getString('themeMode');
    if (savedTheme == 'dark') {
      _themeMode = ThemeMode.dark;
    } else {
      _themeMode = ThemeMode.light;
    }
    notifyListeners(); // Notify listeners after loading
    print('DEBUG: AppStateData: Loaded theme from prefs: $_themeMode');
  }

  // Modified toggleTheme to save preference
  void toggleTheme() {
    _themeMode = _themeMode == ThemeMode.light
        ? ThemeMode.dark
        : ThemeMode.light;
    _saveThemeToPrefs(_themeMode); // NEW: Save theme after toggling
    notifyListeners(); // Notify listeners that the theme has changed
    print('DEBUG: AppStateData: Theme toggled to $_themeMode'); // Debug print
  }

  // NEW: Method to save theme to SharedPreferences
  Future<void> _saveThemeToPrefs(ThemeMode themeMode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'themeMode',
      themeMode == ThemeMode.dark ? 'dark' : 'light',
    );
    print(
      'DEBUG: AppStateData: Saved theme to prefs: ${themeMode == ThemeMode.dark ? 'dark' : 'light'}',
    );
  }

  // Public in-memory storage for states and cities
  List<StateModel> allStateModels = [];
  List<CityModel> allCityModels = [];

  // NEW: Loading state flag
  bool _isDataLoaded = false;
  bool get isDataLoaded => _isDataLoaded;

  // Expose states as a list of names for dropdowns
  List<String> get states {
    print(
      'DEBUG: AppStateData: Getting states, count: ${allStateModels.length}',
    ); // Debug print
    return allStateModels.map((s) => s.name).toList();
  }

  // Setters for state and city models
  void setAllStateModels(List<StateModel> states) {
    allStateModels = states;
    print(
      'DEBUG: AppStateData: All state models set. Total: ${allStateModels.length}',
    ); // Debug print
    _checkAndSetLoaded();
  }

  void setAllCityModels(List<CityModel> cities) {
    allCityModels = cities;
    print(
      'DEBUG: AppStateData: All city models set. Total: ${allCityModels.length}',
    ); // Debug print
    _checkAndSetLoaded();
  }

  // NEW: Check if both datasets are loaded and set flag
  void _checkAndSetLoaded() {
    if (allStateModels.isNotEmpty && allCityModels.isNotEmpty) {
      _isDataLoaded = true;
      notifyListeners();
      print('DEBUG: AppStateData: Data fully loaded and flag set to true.');
    }
  }

  // Method to get city models for a specific state name
  List<CityModel> getCitiesForStateName(String stateName) {
    print(
      'DEBUG: AppStateData: Attempting to get cities for state: $stateName',
    ); // Debug print
    try {
      final stateId = allStateModels
          .firstWhere((state) => state.name == stateName)
          .id;
      final filteredCities = allCityModels
          .where((city) => city.stateId == stateId)
          .toList();
      print(
        'DEBUG: AppStateData: Found ${filteredCities.length} cities for state: $stateName (ID: $stateId)',
      ); // Debug print
      return filteredCities;
    } catch (e) {
      print(
        'ERROR: AppStateData: Error getting cities for state $stateName: $e',
      ); // Debug print
      return [];
    }
  }
}

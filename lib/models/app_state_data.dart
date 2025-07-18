// lib/models/app_state_data.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

class CityModel {
  final double id;
  final String name;
  final double stateId;

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
  static final AppStateData _instance = AppStateData._internal();
  ThemeMode _themeMode = ThemeMode.light; // Default to light until loaded

  ThemeMode get themeMode => _themeMode;

  AppStateData._internal() {
    // Load theme synchronously with a default fallback
    _loadThemeFromPrefs();
  }

  factory AppStateData() {
    return _instance;
  }

  Future<void> _loadThemeFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? savedTheme = prefs.getString('themeMode');
      _themeMode = savedTheme == 'dark' ? ThemeMode.dark : ThemeMode.light;
      print('DEBUG: AppStateData: Loaded theme from prefs: $_themeMode');
    } catch (e) {
      print('ERROR: AppStateData: Failed to load theme: $e');
      _themeMode = ThemeMode.light; // Fallback to light theme
    }
    notifyListeners();
  }

  Future<void> toggleTheme() async {
    _themeMode = _themeMode == ThemeMode.light
        ? ThemeMode.dark
        : ThemeMode.light;
    print('DEBUG: AppStateData: Theme toggled to $_themeMode');
    await _saveThemeToPrefs(_themeMode);
    notifyListeners();
  }

  Future<void> _saveThemeToPrefs(ThemeMode themeMode) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'themeMode',
        themeMode == ThemeMode.dark ? 'dark' : 'light',
      );
      print(
        'DEBUG: AppStateData: Saved theme to prefs: ${themeMode == ThemeMode.dark ? 'dark' : 'light'}',
      );
    } catch (e) {
      print('ERROR: AppStateData: Failed to save theme: $e');
    }
  }

  List<StateModel> allStateModels = [];
  List<CityModel> allCityModels = [];

  bool _isDataLoaded = false;
  bool get isDataLoaded => _isDataLoaded;

  List<String> get states {
    print(
      'DEBUG: AppStateData: Getting states, count: ${allStateModels.length}',
    );
    return allStateModels.map((s) => s.name).toList();
  }

  void setAllStateModels(List<StateModel> states) {
    allStateModels = states;
    print(
      'DEBUG: AppStateData: All state models set. Total: ${allStateModels.length}',
    );
    _checkAndSetLoaded();
  }

  void setAllCityModels(List<CityModel> cities) {
    allCityModels = cities;
    print(
      'DEBUG: AppStateData: All city models set. Total: ${allCityModels.length}',
    );
    _checkAndSetLoaded();
  }

  void _checkAndSetLoaded() {
    if (allStateModels.isNotEmpty && allCityModels.isNotEmpty) {
      _isDataLoaded = true;
      notifyListeners();
      print('DEBUG: AppStateData: Data fully loaded and flag set to true.');
    }
  }

  List<CityModel> getCitiesForStateName(String stateName) {
    print(
      'DEBUG: AppStateData: Attempting to get cities for state: $stateName',
    );
    try {
      final stateId = allStateModels
          .firstWhere((state) => state.name == stateName)
          .id;
      final filteredCities = allCityModels
          .where((city) => city.stateId == stateId)
          .toList();
      print(
        'DEBUG: AppStateData: Found ${filteredCities.length} cities for state: $stateName (ID: $stateId)',
      );
      return filteredCities;
    } catch (e) {
      print(
        'ERROR: AppStateData: Error getting cities for state $stateName: $e',
      );
      return [];
    }
  }
}

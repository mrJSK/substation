// lib/models/app_state_data.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'user_model.dart'; // Ensure this import is correct
import 'hierarchy_models.dart'; // Ensure this import is correct for Substation class

// Your provided StateModel class
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

// Your provided CityModel class
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

class AppStateData extends ChangeNotifier {
  // Singleton pattern for AppStateData
  static final AppStateData _instance = AppStateData._internal();

  // Private fields for state
  ThemeMode _themeMode = ThemeMode.light; // Default to light
  bool _isThemeLoaded = false;
  List<StateModel> _allStateModels = [];
  List<CityModel> _allCityModels = [];
  bool _isStaticDataLoaded = false; // Renamed for clarity
  AppUser? _currentUser; // To store the authenticated AppUser
  bool _isAuthStatusChecked =
      false; // Flag to indicate if auth status has been initially checked

  // NEW: Add selectedSubstation property
  Substation? _selectedSubstation;

  // Public getters for state
  ThemeMode get themeMode => _themeMode;
  bool get isThemeLoaded => _isThemeLoaded;
  List<StateModel> get allStateModels => List.unmodifiable(_allStateModels);
  List<CityModel> get allCityModels => List.unmodifiable(_allCityModels);
  bool get isStaticDataLoaded => _isStaticDataLoaded; // Renamed getter
  AppUser? get currentUser => _currentUser;
  bool get isAuthStatusChecked => _isAuthStatusChecked;
  // NEW: Add getter for selectedSubstation
  Substation? get selectedSubstation => _selectedSubstation;

  // Combined readiness flag for initial app setup
  bool get isInitialized =>
      _isThemeLoaded && _isStaticDataLoaded && _isAuthStatusChecked;

  // Factory constructor to return the singleton instance
  factory AppStateData() {
    return _instance;
  }

  // Private constructor for the singleton
  AppStateData._internal() {
    _initialize(); // Start initialization process
    _setupAuthListener(); // Set up Firebase Auth listener
  }

  // --- Initialization Methods ---

  // Main initialization method to load all necessary data concurrently
  Future<void> _initialize() async {
    try {
      // Load theme and static data concurrently
      await Future.wait([_loadThemeFromPrefs(), _loadStaticData()]);
      print(
        'DEBUG: AppStateData: Core initialization (theme, static data) complete.',
      );
    } catch (e) {
      print('ERROR: AppStateData: Core initialization failed: $e');
      // Ensure flags are set even on error to prevent indefinite loading state
      _isThemeLoaded = true;
      _isStaticDataLoaded = true;
      notifyListeners(); // Notify to potentially unblock UI
    }
  }

  // Loads theme preference from SharedPreferences
  Future<void> _loadThemeFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? savedTheme = prefs.getString('themeMode');
      _themeMode = savedTheme == 'dark' ? ThemeMode.dark : ThemeMode.light;
      print('DEBUG: AppStateData: Loaded theme from prefs: $_themeMode');
    } catch (e) {
      print('ERROR: AppStateData: Failed to load theme from prefs: $e');
      _themeMode = ThemeMode.light; // Fallback
    } finally {
      _isThemeLoaded = true;
      notifyListeners(); // Notify listeners after theme is loaded
    }
  }

  // Toggles the theme mode and saves it to SharedPreferences
  Future<void> toggleTheme() async {
    _themeMode = _themeMode == ThemeMode.light
        ? ThemeMode.dark
        : ThemeMode.light;
    print('DEBUG: AppStateData: Theme toggled to $_themeMode');
    await _saveThemeToPrefs(_themeMode);
    notifyListeners();
  }

  // Saves the current theme mode to SharedPreferences
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
      print('ERROR: AppStateData: Failed to save theme to prefs: $e');
    }
  }

  // Loads static data (states and cities)
  Future<void> _loadStaticData() async {
    print('DEBUG: AppStateData: Starting static data load.');
    // Simulate network delay if needed for testing splash screen
    // await Future.delayed(const Duration(seconds: 2));

    _allStateModels = [
      StateModel(id: 1, name: 'Andaman Nicobar'),
      StateModel(id: 2, name: 'Andhra Pradesh'),
      StateModel(id: 3, name: 'Arunachal Pradesh'),
      StateModel(id: 4, name: 'Assam'),
      StateModel(id: 5, name: 'Bihar'),
      StateModel(id: 6, name: 'Chandigarh'),
      StateModel(id: 7, name: 'Chhattisgarh'),
      StateModel(id: 8, name: 'DadraNagarHaveli and DamanDiu'),
      StateModel(id: 9, name: 'Delhi'),
      StateModel(id: 10, name: 'Goa'),
      StateModel(id: 11, name: 'Gujarat'),
      StateModel(id: 12, name: 'Haryana'),
      StateModel(id: 13, name: 'Himachal Pradesh'),
      StateModel(id: 14, name: 'Jammu Kashmir'),
      StateModel(id: 15, name: 'Jharkhand'),
      StateModel(id: 16, name: 'Karnataka'),
      StateModel(id: 17, name: 'Kerala'),
      StateModel(id: 18, name: 'Ladakh'),
      StateModel(id: 19, name: 'Lakshadweep'),
      StateModel(id: 20, name: 'Madhya Pradesh'),
      StateModel(id: 21, name: 'Maharashtra'),
      StateModel(id: 22, name: 'Manipur'),
      StateModel(id: 23, name: 'Meghalaya'),
      StateModel(id: 24, name: 'Mizoram'),
      StateModel(id: 25, name: 'Nagaland'),
      StateModel(id: 26, name: 'Odisha'),
      StateModel(id: 27, name: 'Puducherry'),
      StateModel(id: 28, name: 'Punjab'),
      StateModel(id: 29, name: 'Rajasthan'),
      StateModel(id: 30, name: 'Sikkim'),
      StateModel(id: 31, name: 'Tamil Nadu'),
      StateModel(id: 32, name: 'Telangana'),
      StateModel(id: 33, name: 'Tripura'),
      StateModel(id: 34, name: 'Uttar Pradesh'),
      StateModel(id: 35, name: 'Uttarakhand'),
      StateModel(id: 36, name: 'West Bengal'),
      StateModel(id: 0, name: ''),
    ];

    _allCityModels = [
      CityModel(id: 1, name: 'Nicobar', stateId: 1),
      CityModel(id: 2, name: 'North Middle Andaman', stateId: 1),
      CityModel(id: 3, name: 'South Andaman', stateId: 1),
      CityModel(id: 4, name: 'Anantapur', stateId: 2),
      CityModel(id: 5, name: 'Chittoor', stateId: 2),
      CityModel(id: 6, name: 'East Godavari', stateId: 2),
      CityModel(id: 7, name: 'Alluri Sitarama Raju', stateId: 2),
      CityModel(id: 8, name: 'Anakapalli', stateId: 2),
      CityModel(id: 9, name: 'Annamaya', stateId: 2),
      CityModel(id: 10, name: 'Bapatla', stateId: 2),
      CityModel(id: 11, name: 'Eluru', stateId: 2),
      CityModel(id: 12, name: 'Guntur', stateId: 2),
      CityModel(id: 13, name: 'Kadapa', stateId: 2),
      CityModel(id: 14, name: 'Kakinada ', stateId: 2),
      CityModel(id: 15, name: 'Konaseema', stateId: 2),
      CityModel(id: 16, name: 'Krishna', stateId: 2),
      CityModel(id: 17, name: 'Kurnool', stateId: 2),
      CityModel(id: 18, name: 'Manyam', stateId: 2),
      CityModel(id: 19, name: 'N T Rama Rao', stateId: 2),
      CityModel(id: 20, name: 'Nandyal', stateId: 2),
      CityModel(id: 21, name: 'Nellore', stateId: 2),
      CityModel(id: 22, name: 'Palnadu', stateId: 2),
      CityModel(id: 23, name: 'Prakasam', stateId: 2),
      CityModel(id: 24, name: 'Sri Balaji', stateId: 2),
      CityModel(id: 25, name: 'Sri Satya Sai', stateId: 2),
      CityModel(id: 26, name: 'Srikakulam', stateId: 2),
      CityModel(id: 27, name: 'Visakhapatnam', stateId: 2),
      CityModel(id: 28, name: 'Vizianagaram', stateId: 2),
      CityModel(id: 29, name: 'West Godavari', stateId: 2),
      CityModel(id: 30, name: 'Anjaw', stateId: 3),
      CityModel(id: 31, name: 'Central Siang', stateId: 3),
      CityModel(id: 32, name: 'Changlang', stateId: 3),
      CityModel(id: 33, name: 'Dibang Valley', stateId: 3),
      CityModel(id: 34, name: 'East Kameng', stateId: 3),
      CityModel(id: 35, name: 'East Siang', stateId: 3),
      CityModel(id: 36, name: 'Kamle', stateId: 3),
      CityModel(id: 37, name: 'Kra Daadi', stateId: 3),
      CityModel(id: 38, name: 'Kurung Kumey', stateId: 3),
      CityModel(id: 39, name: 'Lepa Rada', stateId: 3),
      CityModel(id: 40, name: 'Lohit', stateId: 3),
      CityModel(id: 41, name: 'Longding', stateId: 3),
      CityModel(id: 42, name: 'Lower Dibang Valley', stateId: 3),
      CityModel(id: 43, name: 'Lower Siang', stateId: 3),
      CityModel(id: 44, name: 'Lower Subansiri', stateId: 3),
      CityModel(id: 45, name: 'Namsai', stateId: 3),
      CityModel(id: 46, name: 'Pakke Kessang', stateId: 3),
      CityModel(id: 47, name: 'Papum Pare', stateId: 3),
      CityModel(id: 48, name: 'Shi Yomi', stateId: 3),
      CityModel(id: 49, name: 'Tawang', stateId: 3),
      CityModel(id: 50, name: 'Tirap', stateId: 3),
      CityModel(id: 51, name: 'Upper Siang', stateId: 3),
      CityModel(id: 52, name: 'Upper Subansiri', stateId: 3),
      CityModel(id: 53, name: 'West Kameng', stateId: 3),
      CityModel(id: 54, name: 'West Siang', stateId: 3),
      CityModel(id: 55, name: 'Bajali', stateId: 4),
      CityModel(id: 56, name: 'Baksa', stateId: 4),
      CityModel(id: 57, name: 'Barpeta', stateId: 4),
      CityModel(id: 58, name: 'Biswanath', stateId: 4),
      CityModel(id: 59, name: 'Bongaigaon', stateId: 4),
      CityModel(id: 60, name: 'Cachar', stateId: 4),
      CityModel(id: 61, name: 'Charaideo', stateId: 4),
      CityModel(id: 62, name: 'Chirang', stateId: 4),
      CityModel(id: 63, name: 'Darrang', stateId: 4),
      CityModel(id: 64, name: 'Dhemaji', stateId: 4),
      CityModel(id: 65, name: 'Dhubri', stateId: 4),
      CityModel(id: 66, name: 'Dibrugarh', stateId: 4),
      CityModel(id: 67, name: 'Dima Hasao', stateId: 4),
      CityModel(id: 68, name: 'Goalpara', stateId: 4),
      CityModel(id: 69, name: 'Golaghat', stateId: 4),
      CityModel(id: 70, name: 'Hailakandi', stateId: 4),
      CityModel(id: 71, name: 'Hojai', stateId: 4),
      CityModel(id: 72, name: 'Jorhat', stateId: 4),
      CityModel(id: 73, name: 'Kamrup', stateId: 4),
      CityModel(id: 74, name: 'Kamrup Metropolitan', stateId: 4),
      CityModel(id: 75, name: 'Karbi Anglong', stateId: 4),
      CityModel(id: 76, name: 'Karimganj', stateId: 4),
      CityModel(id: 77, name: 'Kokrajhar', stateId: 4),
      CityModel(id: 78, name: 'Lakhimpur', stateId: 4),
      CityModel(id: 79, name: 'Majuli', stateId: 4),
      CityModel(id: 80, name: 'Morigaon', stateId: 4),
      CityModel(id: 81, name: 'Nagaon', stateId: 4),
      CityModel(id: 82, name: 'Nalbari', stateId: 4),
      CityModel(id: 83, name: 'Sivasagar', stateId: 4),
      CityModel(id: 84, name: 'Sonitpur', stateId: 4),
      CityModel(id: 85, name: 'South Salmara-Mankachar', stateId: 4),
      CityModel(id: 86, name: 'Tinsukia', stateId: 4),
      CityModel(id: 87, name: 'Udalguri', stateId: 4),
      CityModel(id: 88, name: 'West Karbi Anglong', stateId: 4),
      CityModel(id: 89, name: 'Araria', stateId: 5),
      CityModel(id: 90, name: 'Arwal', stateId: 5),
      CityModel(id: 91, name: 'Aurangabad', stateId: 5),
      CityModel(id: 92, name: 'Banka', stateId: 5),
      CityModel(id: 93, name: 'Begusarai', stateId: 5),
      CityModel(id: 94, name: 'Bhagalpur', stateId: 5),
      CityModel(id: 95, name: 'Bhojpur', stateId: 5),
      CityModel(id: 96, name: 'Buxar', stateId: 5),
      CityModel(id: 97, name: 'Darbhanga', stateId: 5),
      CityModel(id: 98, name: 'East Champaran', stateId: 5),
      CityModel(id: 99, name: 'Gaya', stateId: 5),
      CityModel(id: 100, name: 'Gopalganj', stateId: 5),
      CityModel(id: 101, name: 'Jamui', stateId: 5),
      CityModel(id: 102, name: 'Jehanabad', stateId: 5),
      CityModel(id: 103, name: 'Kaimur', stateId: 5),
      CityModel(id: 104, name: 'Katihar', stateId: 5),
      CityModel(id: 105, name: 'Khagaria', stateId: 5),
      CityModel(id: 106, name: 'Kishanganj', stateId: 5),
      CityModel(id: 107, name: 'Lakhisarai', stateId: 5),
      CityModel(id: 108, name: 'Madhepura', stateId: 5),
      CityModel(id: 109, name: 'Madhubani', stateId: 5),
      CityModel(id: 110, name: 'Munger', stateId: 5),
      CityModel(id: 111, name: 'Muzaffarpur', stateId: 5),
      CityModel(id: 112, name: 'Nalanda', stateId: 5),
      CityModel(id: 113, name: 'Nawada', stateId: 5),
      CityModel(id: 114, name: 'Patna', stateId: 5),
      CityModel(id: 115, name: 'Purnia', stateId: 5),
      CityModel(id: 116, name: 'Rohtas', stateId: 5),
      CityModel(id: 117, name: 'Saharsa', stateId: 5),
      CityModel(id: 118, name: 'Samastipur', stateId: 5),
      CityModel(id: 119, name: 'Saran', stateId: 5),
      CityModel(id: 120, name: 'Sheikhpura', stateId: 5),
      CityModel(id: 121, name: 'Sheohar', stateId: 5),
      CityModel(id: 122, name: 'Sitamarhi', stateId: 5),
      CityModel(id: 123, name: 'Siwan', stateId: 5),
      CityModel(id: 124, name: 'Supaul', stateId: 5),
      CityModel(id: 125, name: 'Vaishali', stateId: 5),
      CityModel(id: 126, name: 'West Champaran', stateId: 5),
      CityModel(id: 127, name: 'Chandigarh', stateId: 6),
      CityModel(id: 128, name: 'Balod', stateId: 7),
      CityModel(id: 129, name: 'Baloda Bazar', stateId: 7),
      CityModel(id: 130, name: 'Balrampur', stateId: 7),
      CityModel(id: 131, name: 'Bastar', stateId: 7),
      CityModel(id: 132, name: 'Bemetara', stateId: 7),
      CityModel(id: 133, name: 'Bijapur', stateId: 7),
      CityModel(id: 134, name: 'Bilaspur', stateId: 7),
      CityModel(id: 135, name: 'Dantewada', stateId: 7),
      CityModel(id: 136, name: 'Dhamtari', stateId: 7),
      CityModel(id: 137, name: 'Durg', stateId: 7),
      CityModel(id: 138, name: 'Gariaband', stateId: 7),
      CityModel(id: 139, name: 'Gaurela Pendra Marwahi', stateId: 7),
      CityModel(id: 140, name: 'Janjgir Champa', stateId: 7),
      CityModel(id: 141, name: 'Jashpur', stateId: 7),
      CityModel(id: 142, name: 'Kabirdham', stateId: 7),
      CityModel(id: 143, name: 'Kanker', stateId: 7),
      CityModel(id: 144, name: 'Kondagaon', stateId: 7),
      CityModel(id: 145, name: 'Korba', stateId: 7),
      CityModel(id: 146, name: 'Koriya', stateId: 7),
      CityModel(id: 147, name: 'Mahasamund', stateId: 7),
      CityModel(id: 148, name: 'Manendragarh', stateId: 7),
      CityModel(id: 149, name: 'Mohla Manpur', stateId: 7),
      CityModel(id: 150, name: 'Mungeli', stateId: 7),
      CityModel(id: 151, name: 'Narayanpur', stateId: 7),
      CityModel(id: 152, name: 'Raigarh', stateId: 7),
      CityModel(id: 153, name: 'Raipur', stateId: 7),
      CityModel(id: 154, name: 'Rajnandgaon', stateId: 7),
      CityModel(id: 155, name: 'Sakti', stateId: 7),
      CityModel(id: 156, name: 'Sarangarh Bilaigarh', stateId: 7),
      CityModel(id: 157, name: 'Sukma', stateId: 7),
      CityModel(id: 158, name: 'Surajpur', stateId: 7),
      CityModel(id: 159, name: 'Surguja', stateId: 7),
      CityModel(id: 160, name: 'Dadra and Nagar Haveli', stateId: 8),
      CityModel(id: 161, name: 'Daman', stateId: 8),
      CityModel(id: 162, name: 'Diu', stateId: 8),
      CityModel(id: 163, name: 'Central Delhi', stateId: 9),
      CityModel(id: 164, name: 'East Delhi', stateId: 9),
      CityModel(id: 165, name: 'New Delhi', stateId: 9),
      CityModel(id: 166, name: 'North Delhi', stateId: 9),
      CityModel(id: 167, name: 'North East Delhi', stateId: 9),
      CityModel(id: 168, name: 'North West Delhi', stateId: 9),
      CityModel(id: 169, name: 'Shahdara', stateId: 9),
      CityModel(id: 170, name: 'South Delhi', stateId: 9),
      CityModel(id: 171, name: 'South East Delhi', stateId: 9),
      CityModel(id: 172, name: 'South West Delhi', stateId: 9),
      CityModel(id: 173, name: 'West Delhi', stateId: 9),
      CityModel(id: 174, name: 'North Goa', stateId: 10),
      CityModel(id: 175, name: 'South Goa', stateId: 10),
      CityModel(id: 176, name: 'Ahmedabad', stateId: 11),
      CityModel(id: 177, name: 'Amreli', stateId: 11),
      CityModel(id: 178, name: 'Anand', stateId: 11),
      CityModel(id: 179, name: 'Aravalli', stateId: 11),
      CityModel(id: 180, name: 'Banaskantha', stateId: 11),
      CityModel(id: 181, name: 'Bharuch', stateId: 11),
      CityModel(id: 182, name: 'Bhavnagar', stateId: 11),
      CityModel(id: 183, name: 'Botad', stateId: 11),
      CityModel(id: 184, name: 'Chhota Udaipur', stateId: 11),
      CityModel(id: 185, name: 'Dahod', stateId: 11),
      CityModel(id: 186, name: 'Dang', stateId: 11),
      CityModel(id: 187, name: 'Devbhoomi Dwarka', stateId: 11),
      CityModel(id: 188, name: 'Gandhinagar', stateId: 11),
      CityModel(id: 189, name: 'Gir Somnath', stateId: 11),
      CityModel(id: 190, name: 'Jamnagar', stateId: 11),
      CityModel(id: 191, name: 'Junagadh', stateId: 11),
      CityModel(id: 192, name: 'Kheda', stateId: 11),
      CityModel(id: 193, name: 'Kutch', stateId: 11),
      CityModel(id: 194, name: 'Mahisagar', stateId: 11),
      CityModel(id: 195, name: 'Mehsana', stateId: 11),
      CityModel(id: 196, name: 'Morbi', stateId: 11),
      CityModel(id: 197, name: 'Narmada', stateId: 11),
      CityModel(id: 198, name: 'Navsari', stateId: 11),
      CityModel(id: 199, name: 'Panchmahal', stateId: 11),
      CityModel(id: 200, name: 'Patan', stateId: 11),
      CityModel(id: 201, name: 'Porbandar', stateId: 11),
      CityModel(id: 202, name: 'Rajkot', stateId: 11),
      CityModel(id: 203, name: 'Sabarkantha', stateId: 11),
      CityModel(id: 204, name: 'Surat', stateId: 11),
      CityModel(id: 205, name: 'Surendranagar', stateId: 11),
      CityModel(id: 206, name: 'Tapi', stateId: 11),
      CityModel(id: 207, name: 'Vadodara', stateId: 11),
      CityModel(id: 208, name: 'Valsad', stateId: 11),
      CityModel(id: 209, name: 'Ambala', stateId: 12),
      CityModel(id: 210, name: 'Bhiwani', stateId: 12),
      CityModel(id: 211, name: 'Charkhi Dadri', stateId: 12),
      CityModel(id: 212, name: 'Faridabad', stateId: 12),
      CityModel(id: 213, name: 'Fatehabad', stateId: 12),
      CityModel(id: 214, name: 'Gurugram', stateId: 12),
      CityModel(id: 215, name: 'Hisar', stateId: 12),
      CityModel(id: 216, name: 'Jhajjar', stateId: 12),
      CityModel(id: 217, name: 'Jind', stateId: 12),
      CityModel(id: 218, name: 'Kaithal', stateId: 12),
      CityModel(id: 219, name: 'Karnal', stateId: 12),
      CityModel(id: 220, name: 'Kurukshetra', stateId: 12),
      CityModel(id: 221, name: 'Mahendragarh', stateId: 12),
      CityModel(id: 222, name: 'Mewat', stateId: 12),
      CityModel(id: 223, name: 'Palwal', stateId: 12),
      CityModel(id: 224, name: 'Panchkula', stateId: 12),
      CityModel(id: 225, name: 'Panipat', stateId: 12),
      CityModel(id: 226, name: 'Rewari', stateId: 12),
      CityModel(id: 227, name: 'Rohtak', stateId: 12),
      CityModel(id: 228, name: 'Sirsa', stateId: 12),
      CityModel(id: 229, name: 'Sonipat', stateId: 12),
      CityModel(id: 230, name: 'Yamunanagar', stateId: 12),
      CityModel(id: 231, name: 'Bilaspur', stateId: 13),
      CityModel(id: 232, name: 'Chamba', stateId: 13),
      CityModel(id: 233, name: 'Hamirpur', stateId: 13),
      CityModel(id: 234, name: 'Kangra', stateId: 13),
      CityModel(id: 235, name: 'Kinnaur', stateId: 13),
      CityModel(id: 236, name: 'Kullu', stateId: 13),
      CityModel(id: 237, name: 'Lahaul Spiti', stateId: 13),
      CityModel(id: 238, name: 'Mandi', stateId: 13),
      CityModel(id: 239, name: 'Shimla', stateId: 13),
      CityModel(id: 240, name: 'Sirmaur', stateId: 13),
      CityModel(id: 241, name: 'Solan', stateId: 13),
      CityModel(id: 242, name: 'Una', stateId: 13),
      CityModel(id: 243, name: 'Anantnag', stateId: 14),
      CityModel(id: 244, name: 'Bandipora', stateId: 14),
      CityModel(id: 245, name: 'Baramulla', stateId: 14),
      CityModel(id: 246, name: 'Budgam', stateId: 14),
      CityModel(id: 247, name: 'Doda', stateId: 14),
      CityModel(id: 248, name: 'Ganderbal', stateId: 14),
      CityModel(id: 249, name: 'Jammu', stateId: 14),
      CityModel(id: 250, name: 'Kathua', stateId: 14),
      CityModel(id: 251, name: 'Kishtwar', stateId: 14),
      CityModel(id: 252, name: 'Kulgam', stateId: 14),
      CityModel(id: 253, name: 'Kupwara', stateId: 14),
      CityModel(id: 254, name: 'Poonch', stateId: 14),
      CityModel(id: 255, name: 'Pulwama', stateId: 14),
      CityModel(id: 256, name: 'Rajouri', stateId: 14),
      CityModel(id: 257, name: 'Ramban', stateId: 14),
      CityModel(id: 258, name: 'Reasi', stateId: 14),
      CityModel(id: 259, name: 'Samba', stateId: 14),
      CityModel(id: 260, name: 'Shopian', stateId: 14),
      CityModel(id: 261, name: 'Srinagar', stateId: 14),
      CityModel(id: 262, name: 'Udhampur', stateId: 14),
      CityModel(id: 263, name: 'Bokaro', stateId: 15),
      CityModel(id: 264, name: 'Chatra', stateId: 15),
      CityModel(id: 265, name: 'Deoghar', stateId: 15),
      CityModel(id: 266, name: 'Dhanbad', stateId: 15),
      CityModel(id: 267, name: 'Dumka', stateId: 15),
      CityModel(id: 268, name: 'East Singhbhum', stateId: 15),
      CityModel(id: 269, name: 'Garhwa', stateId: 15),
      CityModel(id: 270, name: 'Giridih', stateId: 15),
      CityModel(id: 271, name: 'Godda', stateId: 15),
      CityModel(id: 272, name: 'Gumla', stateId: 15),
      CityModel(id: 273, name: 'Hazaribagh', stateId: 15),
      CityModel(id: 274, name: 'Jamtara', stateId: 15),
      CityModel(id: 275, name: 'Khunti', stateId: 15),
      CityModel(id: 276, name: 'Koderma', stateId: 15),
      CityModel(id: 277, name: 'Latehar', stateId: 15),
      CityModel(id: 278, name: 'Lohardaga', stateId: 15),
      CityModel(id: 279, name: 'Pakur', stateId: 15),
      CityModel(id: 280, name: 'Palamu', stateId: 15),
      CityModel(id: 281, name: 'Ramgarh', stateId: 15),
      CityModel(id: 282, name: 'Ranchi', stateId: 15),
      CityModel(id: 283, name: 'Sahebganj', stateId: 15),
      CityModel(id: 284, name: 'Seraikela Kharsawan', stateId: 15),
      CityModel(id: 285, name: 'Simdega', stateId: 15),
      CityModel(id: 286, name: 'West Singhbhum', stateId: 15),
      CityModel(id: 287, name: 'Bagalkot', stateId: 16),
      CityModel(id: 288, name: 'Bangalore Rural', stateId: 16),
      CityModel(id: 289, name: 'Bangalore Urban', stateId: 16),
      CityModel(id: 290, name: 'Belgaum', stateId: 16),
      CityModel(id: 291, name: 'Bellary', stateId: 16),
      CityModel(id: 292, name: 'Bidar', stateId: 16),
      CityModel(id: 293, name: 'Chamarajanagar', stateId: 16),
      CityModel(id: 294, name: 'Chikkaballapur', stateId: 16),
      CityModel(id: 295, name: 'Chikkamagaluru', stateId: 16),
      CityModel(id: 296, name: 'Chitradurga', stateId: 16),
      CityModel(id: 297, name: 'Dakshina Kannada', stateId: 16),
      CityModel(id: 298, name: 'Davanagere', stateId: 16),
      CityModel(id: 299, name: 'Dharwad', stateId: 16),
      CityModel(id: 300, name: 'Gadag', stateId: 16),
      CityModel(id: 301, name: 'Gulbarga', stateId: 16),
      CityModel(id: 302, name: 'Hassan', stateId: 16),
      CityModel(id: 303, name: 'Haveri', stateId: 16),
      CityModel(id: 304, name: 'Kodagu', stateId: 16),
      CityModel(id: 305, name: 'Kolar', stateId: 16),
      CityModel(id: 306, name: 'Koppal', stateId: 16),
      CityModel(id: 307, name: 'Mandya', stateId: 16),
      CityModel(id: 308, name: 'Mysore', stateId: 16),
      CityModel(id: 309, name: 'Raichur', stateId: 16),
      CityModel(id: 310, name: 'Ramanagara', stateId: 16),
      CityModel(id: 311, name: 'Shimoga', stateId: 16),
      CityModel(id: 312, name: 'Tumkur', stateId: 16),
      CityModel(id: 313, name: 'Udupi', stateId: 16),
      CityModel(id: 314, name: 'Uttara Kannada', stateId: 16),
      CityModel(id: 315, name: 'Vijayanagara', stateId: 16),
      CityModel(id: 316, name: 'Vijayapura ', stateId: 16),
      CityModel(id: 317, name: 'Yadgir', stateId: 16),
      CityModel(id: 318, name: 'Alappuzha', stateId: 17),
      CityModel(id: 319, name: 'Ernakulam', stateId: 17),
      CityModel(id: 320, name: 'Idukki', stateId: 17),
      CityModel(id: 321, name: 'Kannur', stateId: 17),
      CityModel(id: 322, name: 'Kasaragod', stateId: 17),
      CityModel(id: 323, name: 'Kollam', stateId: 17),
      CityModel(id: 324, name: 'Kottayam', stateId: 17),
      CityModel(id: 325, name: 'Kozhikode', stateId: 17),
      CityModel(id: 326, name: 'Malappuram', stateId: 17),
      CityModel(id: 327, name: 'Palakkad', stateId: 17),
      CityModel(id: 328, name: 'Pathanamthitta', stateId: 17),
      CityModel(id: 329, name: 'Thiruvananthapuram', stateId: 17),
      CityModel(id: 330, name: 'Thrissur', stateId: 17),
      CityModel(id: 331, name: 'Wayanad', stateId: 17),
      CityModel(id: 332, name: 'Kargil', stateId: 18),
      CityModel(id: 333, name: 'Leh', stateId: 19),
      CityModel(id: 334, name: 'Lakshadweep', stateId: 20),
      CityModel(id: 335, name: 'Agar Malwa', stateId: 20),
      CityModel(id: 336, name: 'Alirajpur', stateId: 20),
      CityModel(id: 337, name: 'Anuppur', stateId: 20),
      CityModel(id: 338, name: 'Ashoknagar', stateId: 20),
      CityModel(id: 339, name: 'Balaghat', stateId: 20),
      CityModel(id: 340, name: 'Barwani', stateId: 20),
      CityModel(id: 341, name: 'Betul', stateId: 20),
      CityModel(id: 342, name: 'Bhind', stateId: 20),
      CityModel(id: 343, name: 'Bhopal', stateId: 20),
      CityModel(id: 344, name: 'Burhanpur', stateId: 20),
      CityModel(id: 345, name: 'Chachaura', stateId: 20),
      CityModel(id: 346, name: 'Chhatarpur', stateId: 20),
      CityModel(id: 347, name: 'Chhindwara', stateId: 20),
      CityModel(id: 348, name: 'Damoh', stateId: 20),
      CityModel(id: 349, name: 'Datia', stateId: 20),
      CityModel(id: 350, name: 'Dewas', stateId: 20),
      CityModel(id: 351, name: 'Dhar', stateId: 20),
      CityModel(id: 352, name: 'Dindori', stateId: 20),
      CityModel(id: 353, name: 'Guna', stateId: 20),
      CityModel(id: 354, name: 'Gwalior', stateId: 20),
      CityModel(id: 355, name: 'Harda', stateId: 20),
      CityModel(id: 356, name: 'Hoshangabad', stateId: 20),
      CityModel(id: 357, name: 'Indore', stateId: 20),
      CityModel(id: 358, name: 'Jabalpur', stateId: 20),
      CityModel(id: 359, name: 'Jhabua', stateId: 20),
      CityModel(id: 360, name: 'Katni', stateId: 20),
      CityModel(id: 361, name: 'Khandwa', stateId: 20),
      CityModel(id: 362, name: 'Khargone', stateId: 20),
      CityModel(id: 363, name: 'Maihar', stateId: 20),
      CityModel(id: 364, name: 'Mandla', stateId: 20),
      CityModel(id: 365, name: 'Mandsaur', stateId: 20),
      CityModel(id: 366, name: 'Morena', stateId: 20),
      CityModel(id: 367, name: 'Nagda', stateId: 20),
      CityModel(id: 368, name: 'Narsinghpur', stateId: 20),
      CityModel(id: 369, name: 'Neemuch', stateId: 20),
      CityModel(id: 370, name: 'Niwari', stateId: 20),
      CityModel(id: 371, name: 'Panna', stateId: 20),
      CityModel(id: 372, name: 'Raisen', stateId: 20),
      CityModel(id: 373, name: 'Rajgarh', stateId: 20),
      CityModel(id: 374, name: 'Ratlam', stateId: 20),
      CityModel(id: 375, name: 'Rewa', stateId: 20),
      CityModel(id: 376, name: 'Sagar', stateId: 20),
      CityModel(id: 377, name: 'Satna', stateId: 20),
      CityModel(id: 378, name: 'Sehore', stateId: 20),
      CityModel(id: 379, name: 'Seoni', stateId: 20),
      CityModel(id: 380, name: 'Shahdol', stateId: 20),
      CityModel(id: 381, name: 'Shajapur', stateId: 20),
      CityModel(id: 382, name: 'Sheopur', stateId: 20),
      CityModel(id: 383, name: 'Shivpuri', stateId: 20),
      CityModel(id: 384, name: 'Sidhi', stateId: 20),
      CityModel(id: 385, name: 'Singrauli', stateId: 20),
      CityModel(id: 386, name: 'Tikamgarh', stateId: 20),
      CityModel(id: 387, name: 'Ujjain', stateId: 20),
      CityModel(id: 388, name: 'Umaria', stateId: 20),
      CityModel(id: 389, name: 'Vidisha', stateId: 20),
      CityModel(id: 390, name: 'Ahmednagar', stateId: 21),
      CityModel(id: 391, name: 'Akola', stateId: 21),
      CityModel(id: 392, name: 'Amravati', stateId: 21),
      CityModel(id: 393, name: 'Aurangabad', stateId: 21),
      CityModel(id: 394, name: 'Beed', stateId: 21),
      CityModel(id: 395, name: 'Bhandara', stateId: 21),
      CityModel(id: 396, name: 'Buldhana', stateId: 21),
      CityModel(id: 397, name: 'Chandrapur', stateId: 21),
      CityModel(id: 398, name: 'Dhule', stateId: 21),
      CityModel(id: 399, name: 'Gadchiroli', stateId: 21),
      CityModel(id: 400, name: 'Gondia', stateId: 21),
      CityModel(id: 401, name: 'Hingoli', stateId: 21),
      CityModel(id: 402, name: 'Jalgaon', stateId: 21),
      CityModel(id: 403, name: 'Jalna', stateId: 21),
      CityModel(id: 404, name: 'Kolhapur', stateId: 21),
      CityModel(id: 405, name: 'Latur', stateId: 21),
      CityModel(id: 406, name: 'Mumbai City', stateId: 21),
      CityModel(id: 407, name: 'Mumbai Suburban', stateId: 21),
      CityModel(id: 408, name: 'Nagpur', stateId: 21),
      CityModel(id: 409, name: 'Nanded', stateId: 21),
      CityModel(id: 410, name: 'Nandurbar', stateId: 21),
      CityModel(id: 411, name: 'Nashik', stateId: 21),
      CityModel(id: 412, name: 'Osmanabad', stateId: 21),
      CityModel(id: 413, name: 'Palghar', stateId: 21),
      CityModel(id: 414, name: 'Parbhani', stateId: 21),
      CityModel(id: 415, name: 'Pune', stateId: 21),
      CityModel(id: 416, name: 'Raigad', stateId: 21),
      CityModel(id: 417, name: 'Ratnagiri', stateId: 21),
      CityModel(id: 418, name: 'Sangli', stateId: 21),
      CityModel(id: 419, name: 'Satara', stateId: 21),
      CityModel(id: 420, name: 'Sindhudurg', stateId: 21),
      CityModel(id: 421, name: 'Solapur', stateId: 21),
      CityModel(id: 422, name: 'Thane', stateId: 21),
      CityModel(id: 423, name: 'Wardha', stateId: 21),
      CityModel(id: 424, name: 'Washim', stateId: 21),
      CityModel(id: 425, name: 'Yavatmal', stateId: 21),
      CityModel(id: 426, name: 'Bishnupur', stateId: 22),
      CityModel(id: 427, name: 'Chandel', stateId: 22),
      CityModel(id: 428, name: 'Churachandpur', stateId: 22),
      CityModel(id: 429, name: 'Imphal East', stateId: 22),
      CityModel(id: 430, name: 'Imphal West', stateId: 22),
      CityModel(id: 431, name: 'Jiribam', stateId: 22),
      CityModel(id: 432, name: 'Kakching', stateId: 22),
      CityModel(id: 433, name: 'Kamjong', stateId: 22),
      CityModel(id: 434, name: 'Kangpokpi', stateId: 22),
      CityModel(id: 435, name: 'Noney', stateId: 22),
      CityModel(id: 436, name: 'Pherzawl', stateId: 22),
      CityModel(id: 437, name: 'Senapati', stateId: 22),
      CityModel(id: 438, name: 'Tamenglong', stateId: 22),
      CityModel(id: 439, name: 'Tengnoupal', stateId: 22),
      CityModel(id: 440, name: 'Thoubal', stateId: 22),
      CityModel(id: 441, name: 'Ukhrul', stateId: 22),
      CityModel(id: 442, name: 'East Garo Hills', stateId: 23),
      CityModel(id: 443, name: 'East Jaintia Hills', stateId: 23),
      CityModel(id: 444, name: 'East Khasi Hills', stateId: 23),
      CityModel(id: 445, name: 'Mairang', stateId: 23),
      CityModel(id: 446, name: 'North Garo Hills', stateId: 23),
      CityModel(id: 447, name: 'Ri Bhoi', stateId: 23),
      CityModel(id: 448, name: 'South Garo Hills', stateId: 23),
      CityModel(id: 449, name: 'South West Garo Hills', stateId: 23),
      CityModel(id: 450, name: 'South West Khasi Hills', stateId: 23),
      CityModel(id: 451, name: 'West Garo Hills', stateId: 23),
      CityModel(id: 452, name: 'West Jaintia Hills', stateId: 23),
      CityModel(id: 453, name: 'West Khasi Hills', stateId: 23),
      CityModel(id: 454, name: 'Aizawl', stateId: 24),
      CityModel(id: 455, name: 'Champhai', stateId: 24),
      CityModel(id: 456, name: 'Hnahthial', stateId: 24),
      CityModel(id: 457, name: 'Kolasib', stateId: 24),
      CityModel(id: 458, name: 'Khawzawl', stateId: 24),
      CityModel(id: 459, name: 'Lawngtlai', stateId: 24),
      CityModel(id: 460, name: 'Lunglei', stateId: 24),
      CityModel(id: 461, name: 'Mamit', stateId: 24),
      CityModel(id: 462, name: 'Saiha', stateId: 24),
      CityModel(id: 463, name: 'Serchhip', stateId: 24),
      CityModel(id: 464, name: 'Saitual', stateId: 24),
      CityModel(id: 465, name: 'Chumukedima', stateId: 25),
      CityModel(id: 466, name: 'Dimapur', stateId: 25),
      CityModel(id: 467, name: 'Kiphire', stateId: 25),
      CityModel(id: 468, name: 'Kohima', stateId: 25),
      CityModel(id: 469, name: 'Longleng', stateId: 25),
      CityModel(id: 470, name: 'Mokokchung', stateId: 25),
      CityModel(id: 471, name: 'Mon', stateId: 25),
      CityModel(id: 472, name: 'Niuland', stateId: 25),
      CityModel(id: 473, name: 'Noklak', stateId: 25),
      CityModel(id: 474, name: 'Peren', stateId: 25),
      CityModel(id: 475, name: 'Phek', stateId: 25),
      CityModel(id: 476, name: 'Tseminyu', stateId: 25),
      CityModel(id: 477, name: 'Tuensang', stateId: 25),
      CityModel(id: 478, name: 'Wokha', stateId: 25),
      CityModel(id: 479, name: 'Zunheboto', stateId: 25),
      CityModel(id: 480, name: 'Angul', stateId: 26),
      CityModel(id: 481, name: 'Balangir', stateId: 26),
      CityModel(id: 482, name: 'Balasore', stateId: 26),
      CityModel(id: 483, name: 'Bargarh', stateId: 26),
      CityModel(id: 484, name: 'Bhadrak', stateId: 26),
      CityModel(id: 485, name: 'Boudh', stateId: 26),
      CityModel(id: 486, name: 'Cuttack', stateId: 26),
      CityModel(id: 487, name: 'Debagarh', stateId: 26),
      CityModel(id: 488, name: 'Dhenkanal', stateId: 26),
      CityModel(id: 489, name: 'Gajapati', stateId: 26),
      CityModel(id: 490, name: 'Ganjam', stateId: 26),
      CityModel(id: 491, name: 'Jagatsinghpur', stateId: 26),
      CityModel(id: 492, name: 'Jajpur', stateId: 26),
      CityModel(id: 493, name: 'Jharsuguda', stateId: 26),
      CityModel(id: 494, name: 'Kalahandi', stateId: 26),
      CityModel(id: 495, name: 'Kandhamal', stateId: 26),
      CityModel(id: 496, name: 'Kendrapara', stateId: 26),
      CityModel(id: 497, name: 'Kendujhar', stateId: 26),
      CityModel(id: 498, name: 'Khordha', stateId: 26),
      CityModel(id: 499, name: 'Koraput', stateId: 26),
      CityModel(id: 500, name: 'Malkangiri', stateId: 26),
      CityModel(id: 501, name: 'Mayurbhanj', stateId: 26),
      CityModel(id: 502, name: 'Nabarangpur', stateId: 26),
      CityModel(id: 503, name: 'Nayagarh', stateId: 26),
      CityModel(id: 504, name: 'Nuapada', stateId: 26),
      CityModel(id: 505, name: 'Puri', stateId: 26),
      CityModel(id: 506, name: 'Rayagada', stateId: 26),
      CityModel(id: 507, name: 'Sambalpur', stateId: 26),
      CityModel(id: 508, name: 'Subarnapur', stateId: 26),
      CityModel(id: 509, name: 'Sundergarh', stateId: 26),
      CityModel(id: 510, name: 'Karaikal', stateId: 27),
      CityModel(id: 511, name: 'Mahe', stateId: 27),
      CityModel(id: 512, name: 'Puducherry', stateId: 27),
      CityModel(id: 513, name: 'Yanam', stateId: 27),
      CityModel(id: 514, name: 'Amritsar', stateId: 28),
      CityModel(id: 515, name: 'Barnala', stateId: 28),
      CityModel(id: 516, name: 'Bathinda', stateId: 28),
      CityModel(id: 517, name: 'Faridkot', stateId: 28),
      CityModel(id: 518, name: 'Fatehgarh Sahib', stateId: 28),
      CityModel(id: 519, name: 'Fazilka', stateId: 28),
      CityModel(id: 520, name: 'Firozpur', stateId: 28),
      CityModel(id: 521, name: 'Gurdaspur', stateId: 28),
      CityModel(id: 522, name: 'Hoshiarpur', stateId: 28),
      CityModel(id: 523, name: 'Jalandhar', stateId: 28),
      CityModel(id: 524, name: 'Kapurthala', stateId: 28),
      CityModel(id: 525, name: 'Ludhiana', stateId: 28),
      CityModel(id: 526, name: 'Malerkotla', stateId: 28),
      CityModel(id: 527, name: 'Mansa', stateId: 28),
      CityModel(id: 528, name: 'Moga', stateId: 28),
      CityModel(id: 529, name: 'Mohali', stateId: 28),
      CityModel(id: 530, name: 'Muktsar', stateId: 28),
      CityModel(id: 531, name: 'Pathankot', stateId: 28),
      CityModel(id: 532, name: 'Patiala', stateId: 28),
      CityModel(id: 533, name: 'Rupnagar', stateId: 28),
      CityModel(id: 534, name: 'Sangrur', stateId: 28),
      CityModel(id: 535, name: 'Shaheed Bhagat Singh Nagar', stateId: 28),
      CityModel(id: 536, name: 'Tarn Taran', stateId: 28),
      CityModel(id: 537, name: 'Ajmer', stateId: 29),
      CityModel(id: 538, name: 'Alwar', stateId: 29),
      CityModel(id: 539, name: 'Banswara', stateId: 29),
      CityModel(id: 540, name: 'Baran', stateId: 29),
      CityModel(id: 541, name: 'Barmer', stateId: 29),
      CityModel(id: 542, name: 'Bharatpur', stateId: 29),
      CityModel(id: 543, name: 'Bhilwara', stateId: 29),
      CityModel(id: 544, name: 'Bikaner', stateId: 29),
      CityModel(id: 545, name: 'Bundi', stateId: 29),
      CityModel(id: 546, name: 'Chittorgarh', stateId: 29),
      CityModel(id: 547, name: 'Churu', stateId: 29),
      CityModel(id: 548, name: 'Dausa', stateId: 29),
      CityModel(id: 549, name: 'Dholpur', stateId: 29),
      CityModel(id: 550, name: 'Dungarpur', stateId: 29),
      CityModel(id: 551, name: 'Hanumangarh', stateId: 29),
      CityModel(id: 552, name: 'Jaipur', stateId: 29),
      CityModel(id: 553, name: 'Jaisalmer', stateId: 29),
      CityModel(id: 554, name: 'Jalore', stateId: 29),
      CityModel(id: 555, name: 'Jhalawar', stateId: 29),
      CityModel(id: 556, name: 'Jhunjhunu', stateId: 29),
      CityModel(id: 557, name: 'Jodhpur', stateId: 29),
      CityModel(id: 558, name: 'Karauli', stateId: 29),
      CityModel(id: 559, name: 'Kota', stateId: 29),
      CityModel(id: 560, name: 'Nagaur', stateId: 29),
      CityModel(id: 561, name: 'Pali', stateId: 29),
      CityModel(id: 562, name: 'Pratapgarh', stateId: 29),
      CityModel(id: 563, name: 'Rajsamand', stateId: 29),
      CityModel(id: 564, name: 'Sawai Madhopur', stateId: 29),
      CityModel(id: 565, name: 'Sikar', stateId: 29),
      CityModel(id: 566, name: 'Sirohi', stateId: 29),
      CityModel(id: 567, name: 'Sri Ganganagar', stateId: 29),
      CityModel(id: 568, name: 'Tonk', stateId: 29),
      CityModel(id: 569, name: 'Udaipur', stateId: 29),
      CityModel(id: 570, name: 'East Sikkim', stateId: 30),
      CityModel(id: 571, name: 'North Sikkim', stateId: 30),
      CityModel(id: 572, name: 'Pakyong', stateId: 30),
      CityModel(id: 573, name: 'Soreng', stateId: 30),
      CityModel(id: 574, name: 'South Sikkim', stateId: 30),
      CityModel(id: 575, name: 'West Sikkim', stateId: 30),
      CityModel(id: 576, name: 'Ariyalur', stateId: 31),
      CityModel(id: 577, name: 'Chengalpattu', stateId: 31),
      CityModel(id: 578, name: 'Chennai', stateId: 31),
      CityModel(id: 579, name: 'Coimbatore', stateId: 31),
      CityModel(id: 580, name: 'Cuddalore', stateId: 31),
      CityModel(id: 581, name: 'Dharmapuri', stateId: 31),
      CityModel(id: 582, name: 'Dindigul', stateId: 31),
      CityModel(id: 583, name: 'Erode', stateId: 31),
      CityModel(id: 584, name: 'Kallakurichi', stateId: 31),
      CityModel(id: 585, name: 'Kanchipuram', stateId: 31),
      CityModel(id: 586, name: 'Kanyakumari', stateId: 31),
      CityModel(id: 587, name: 'Karur', stateId: 31),
      CityModel(id: 588, name: 'Krishnagiri', stateId: 31),
      CityModel(id: 589, name: 'Madurai', stateId: 31),
      CityModel(id: 590, name: 'Mayiladuthurai ', stateId: 31),
      CityModel(id: 591, name: 'Nagapattinam', stateId: 31),
      CityModel(id: 592, name: 'Namakkal', stateId: 31),
      CityModel(id: 593, name: 'Nilgiris', stateId: 31),
      CityModel(id: 594, name: 'Perambalur', stateId: 31),
      CityModel(id: 595, name: 'Pudukkottai', stateId: 31),
      CityModel(id: 596, name: 'Ramanathapuram', stateId: 31),
      CityModel(id: 597, name: 'Ranipet', stateId: 31),
      CityModel(id: 598, name: 'Salem', stateId: 31),
      CityModel(id: 599, name: 'Sivaganga', stateId: 31),
      CityModel(id: 600, name: 'Tenkasi', stateId: 31),
      CityModel(id: 601, name: 'Thanjavur', stateId: 31),
      CityModel(id: 602, name: 'Theni', stateId: 31),
      CityModel(id: 603, name: 'Thoothukudi', stateId: 31),
      CityModel(id: 604, name: 'Tiruchirappalli', stateId: 31),
      CityModel(id: 605, name: 'Tirunelveli', stateId: 31),
      CityModel(id: 606, name: 'Tirupattur', stateId: 31),
      CityModel(id: 607, name: 'Tiruppur', stateId: 31),
      CityModel(id: 608, name: 'Tiruvallur', stateId: 31),
      CityModel(id: 609, name: 'Tiruvannamalai', stateId: 31),
      CityModel(id: 610, name: 'Tiruvarur', stateId: 31),
      CityModel(id: 611, name: 'Vellore', stateId: 31),
      CityModel(id: 612, name: 'Viluppuram', stateId: 31),
      CityModel(id: 613, name: 'Virudhunagar', stateId: 31),
      CityModel(id: 614, name: 'Adilabad', stateId: 32),
      CityModel(id: 615, name: 'Bhadradri Kothagudem', stateId: 32),
      CityModel(id: 616, name: 'Hyderabad', stateId: 32),
      CityModel(id: 617, name: 'Jagtial', stateId: 32),
      CityModel(id: 618, name: 'Jangaon', stateId: 32),
      CityModel(id: 619, name: 'Jayashankar', stateId: 32),
      CityModel(id: 620, name: 'Jogulamba', stateId: 32),
      CityModel(id: 621, name: 'Kamareddy', stateId: 32),
      CityModel(id: 622, name: 'Karimnagar', stateId: 32),
      CityModel(id: 623, name: 'Khammam', stateId: 32),
      CityModel(id: 624, name: 'Komaram Bheem', stateId: 32),
      CityModel(id: 625, name: 'Mahabubabad', stateId: 32),
      CityModel(id: 626, name: 'Mahbubnagar', stateId: 32),
      CityModel(id: 627, name: 'Mancherial', stateId: 32),
      CityModel(id: 628, name: 'Medak', stateId: 32),
      CityModel(id: 629, name: 'Medchal', stateId: 32),
      CityModel(id: 630, name: 'Mulugu', stateId: 32),
      CityModel(id: 631, name: 'Nagarkurnool', stateId: 32),
      CityModel(id: 632, name: 'Nalgonda', stateId: 32),
      CityModel(id: 633, name: 'Narayanpet', stateId: 32),
      CityModel(id: 634, name: 'Nirmal', stateId: 32),
      CityModel(id: 635, name: 'Nizamabad', stateId: 32),
      CityModel(id: 636, name: 'Peddapalli', stateId: 32),
      CityModel(id: 637, name: 'Rajanna Sircilla', stateId: 32),
      CityModel(id: 638, name: 'Ranga Reddy', stateId: 32),
      CityModel(id: 639, name: 'Sangareddy', stateId: 32),
      CityModel(id: 640, name: 'Siddipet', stateId: 32),
      CityModel(id: 641, name: 'Suryapet', stateId: 32),
      CityModel(id: 642, name: 'Vikarabad', stateId: 32),
      CityModel(id: 643, name: 'Wanaparthy', stateId: 32),
      CityModel(id: 644, name: 'Warangal', stateId: 32),
      CityModel(id: 645, name: 'Hanamkonda', stateId: 32),
      CityModel(id: 646, name: 'Yadadri Bhuvanagiri', stateId: 32),
      CityModel(id: 647, name: 'Dhalai', stateId: 33),
      CityModel(id: 648, name: 'Gomati', stateId: 33),
      CityModel(id: 649, name: 'Khowai', stateId: 33),
      CityModel(id: 650, name: 'North Tripura', stateId: 33),
      CityModel(id: 651, name: 'Sepahijala', stateId: 33),
      CityModel(id: 652, name: 'South Tripura', stateId: 33),
      CityModel(id: 653, name: 'Unakoti', stateId: 33),
      CityModel(id: 654, name: 'West Tripura', stateId: 33),
      CityModel(id: 655, name: 'Agra', stateId: 34),
      CityModel(id: 656, name: 'Aligarh', stateId: 34),
      CityModel(id: 657, name: 'Ambedkar Nagar', stateId: 34),
      CityModel(id: 658, name: 'Amethi', stateId: 34),
      CityModel(id: 659, name: 'Amroha', stateId: 34),
      CityModel(id: 660, name: 'Auraiya', stateId: 34),
      CityModel(id: 661, name: 'Ayodhya', stateId: 34),
      CityModel(id: 662, name: 'Azamgarh', stateId: 34),
      CityModel(id: 663, name: 'Baghpat', stateId: 34),
      CityModel(id: 664, name: 'Bahraich', stateId: 34),
      CityModel(id: 665, name: 'Ballia', stateId: 34),
      CityModel(id: 666, name: 'Balrampur', stateId: 34),
      CityModel(id: 667, name: 'Banda', stateId: 34),
      CityModel(id: 668, name: 'Barabanki', stateId: 34),
      CityModel(id: 669, name: 'Bareilly', stateId: 34),
      CityModel(id: 670, name: 'Basti', stateId: 34),
      CityModel(id: 671, name: 'Bhadohi', stateId: 34),
      CityModel(id: 672, name: 'Bijnor', stateId: 34),
      CityModel(id: 673, name: 'Budaun', stateId: 34),
      CityModel(id: 674, name: 'Bulandshahr', stateId: 34),
      CityModel(id: 675, name: 'Chandauli', stateId: 34),
      CityModel(id: 676, name: 'Chitrakoot', stateId: 34),
      CityModel(id: 677, name: 'Deoria', stateId: 34),
      CityModel(id: 678, name: 'Etah', stateId: 34),
      CityModel(id: 679, name: 'Etawah', stateId: 34),
      CityModel(id: 680, name: 'Farrukhabad', stateId: 34),
      CityModel(id: 681, name: 'Fatehpur', stateId: 34),
      CityModel(id: 682, name: 'Firozabad', stateId: 34),
      CityModel(id: 683, name: 'Gautam Buddha Nagar', stateId: 34),
      CityModel(id: 684, name: 'Ghaziabad', stateId: 34),
      CityModel(id: 685, name: 'Ghazipur', stateId: 34),
      CityModel(id: 686, name: 'Gonda', stateId: 34),
      CityModel(id: 687, name: 'Gorakhpur', stateId: 34),
      CityModel(id: 688, name: 'Hamirpur', stateId: 34),
      CityModel(id: 689, name: 'Hapur', stateId: 34),
      CityModel(id: 690, name: 'Hardoi', stateId: 34),
      CityModel(id: 691, name: 'Hathras', stateId: 34),
      CityModel(id: 692, name: 'Jalaun', stateId: 34),
      CityModel(id: 693, name: 'Jaunpur', stateId: 34),
      CityModel(id: 694, name: 'Jhansi', stateId: 34),
      CityModel(id: 695, name: 'Kannauj', stateId: 34),
      CityModel(id: 696, name: 'Kanpur Dehat', stateId: 34),
      CityModel(id: 697, name: 'Kanpur Nagar', stateId: 34),
      CityModel(id: 698, name: 'Kasganj', stateId: 34),
      CityModel(id: 699, name: 'Kaushambi', stateId: 34),
      CityModel(id: 700, name: 'Kheri', stateId: 34),
      CityModel(id: 701, name: 'Kushinagar', stateId: 34),
      CityModel(id: 702, name: 'Lalitpur', stateId: 34),
      CityModel(id: 703, name: 'Lucknow', stateId: 34),
      CityModel(id: 704, name: 'Maharajganj', stateId: 34),
      CityModel(id: 705, name: 'Mahoba', stateId: 34),
      CityModel(id: 706, name: 'Mainpuri', stateId: 34),
      CityModel(id: 707, name: 'Mathura', stateId: 34),
      CityModel(id: 708, name: 'Mau', stateId: 34),
      CityModel(id: 709, name: 'Meerut', stateId: 34),
      CityModel(id: 710, name: 'Mirzapur', stateId: 34),
      CityModel(id: 711, name: 'Moradabad', stateId: 34),
      CityModel(id: 712, name: 'Muzaffarnagar', stateId: 34),
      CityModel(id: 713, name: 'Pilibhit', stateId: 34),
      CityModel(id: 714, name: 'Pratapgarh', stateId: 34),
      CityModel(id: 715, name: 'Prayagraj', stateId: 34),
      CityModel(id: 716, name: 'Raebareli', stateId: 34),
      CityModel(id: 717, name: 'Rampur', stateId: 34),
      CityModel(id: 718, name: 'Saharanpur', stateId: 34),
      CityModel(id: 719, name: 'Sambhal', stateId: 34),
      CityModel(id: 720, name: 'Sant Kabir Nagar', stateId: 34),
      CityModel(id: 721, name: 'Shahjahanpur', stateId: 34),
      CityModel(id: 722, name: 'Shamli', stateId: 34),
      CityModel(id: 723, name: 'Shravasti', stateId: 34),
      CityModel(id: 724, name: 'Siddharthnagar', stateId: 34),
      CityModel(id: 725, name: 'Sitapur', stateId: 34),
      CityModel(id: 726, name: 'Sonbhadra', stateId: 34),
      CityModel(id: 727, name: 'Sultanpur', stateId: 34),
      CityModel(id: 728, name: 'Unnao', stateId: 34),
      CityModel(id: 729, name: 'Varanasi', stateId: 34),
      CityModel(id: 730, name: 'Almora', stateId: 35),
      CityModel(id: 731, name: 'Bageshwar', stateId: 35),
      CityModel(id: 732, name: 'Chamoli', stateId: 35),
      CityModel(id: 733, name: 'Champawat', stateId: 35),
      CityModel(id: 734, name: 'Dehradun', stateId: 35),
      CityModel(id: 735, name: 'Haridwar', stateId: 35),
      CityModel(id: 736, name: 'Nainital', stateId: 35),
      CityModel(id: 737, name: 'Pauri', stateId: 35),
      CityModel(id: 738, name: 'Pithoragarh', stateId: 35),
      CityModel(id: 739, name: 'Rudraprayag', stateId: 35),
      CityModel(id: 740, name: 'Tehri', stateId: 35),
      CityModel(id: 741, name: 'Udham Singh Nagar', stateId: 35),
      CityModel(id: 742, name: 'Uttarkashi', stateId: 35),
      CityModel(id: 743, name: 'Alipurduar', stateId: 36),
      CityModel(id: 744, name: 'Bankura', stateId: 36),
      CityModel(id: 745, name: 'Birbhum', stateId: 36),
      CityModel(id: 746, name: 'Cooch Behar', stateId: 36),
      CityModel(id: 747, name: 'Dakshin Dinajpur', stateId: 36),
      CityModel(id: 748, name: 'Darjeeling', stateId: 36),
      CityModel(id: 749, name: 'Hooghly', stateId: 36),
      CityModel(id: 750, name: 'Howrah', stateId: 36),
      CityModel(id: 751, name: 'Jalpaiguri', stateId: 36),
      CityModel(id: 752, name: 'Jhargram', stateId: 36),
      CityModel(id: 753, name: 'Kalimpong', stateId: 36),
      CityModel(id: 754, name: 'Kolkata', stateId: 36),
      CityModel(id: 755, name: 'Malda', stateId: 36),
      CityModel(id: 756, name: 'Murshidabad', stateId: 36),
      CityModel(id: 757, name: 'Nadia', stateId: 36),
      CityModel(id: 758, name: 'North 24 Parganas', stateId: 36),
      CityModel(id: 759, name: 'Paschim Bardhaman', stateId: 36),
      CityModel(id: 760, name: 'Paschim Medinipur', stateId: 36),
      CityModel(id: 761, name: 'Purba Bardhaman', stateId: 36),
      CityModel(id: 762, name: 'Purba Medinipur', stateId: 36),
      CityModel(id: 763, name: 'Purulia', stateId: 36),
      CityModel(id: 764, name: 'South 24 Parganas', stateId: 36),
      CityModel(id: 765, name: 'Uttar Dinajpur', stateId: 36),
    ];

    print(
      'DEBUG: AppStateData: Static data loaded. States: ${_allStateModels.length}, Cities: ${_allCityModels.length}',
    );
    _isStaticDataLoaded = true; // Set flag
    notifyListeners(); // Notify listeners
  }

  // Sets up a listener for Firebase Authentication state changes
  void _setupAuthListener() {
    FirebaseAuth.instance.authStateChanges().listen((user) async {
      print('DEBUG: AppStateData: Auth state changed. User: ${user?.email}');
      if (user == null) {
        _currentUser = null;
        _selectedSubstation = null; // NEW: Clear selected substation on logout
      } else {
        // Fetch or update AppUser from Firestore
        try {
          final userDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .get();
          if (userDoc.exists) {
            _currentUser = AppUser.fromFirestore(userDoc);
            print(
              'DEBUG: AppStateData: Fetched AppUser: ${_currentUser?.email}, Role: ${_currentUser?.role}',
            );
            // NEW: If a subdivision manager, attempt to fetch and set a default substation
            if (_currentUser?.role == UserRole.subdivisionManager &&
                _currentUser?.assignedLevels?['subdivisionId'] != null) {
              await _fetchAndSetDefaultSubstation(
                _currentUser!.assignedLevels!['subdivisionId']!,
              );
            }
          } else {
            // This case should ideally be handled during sign-up.
            // If a Firebase user exists but no Firestore doc, it's an inconsistent state.
            // Consider logging them out or creating a pending user doc.
            print(
              'WARNING: AppStateData: Firebase user exists but no Firestore document. Logging out.',
            );
            await FirebaseAuth.instance.signOut();
            _currentUser = null;
            _selectedSubstation =
                null; // NEW: Clear selected substation on forced logout
          }
        } catch (e) {
          print(
            'ERROR: AppStateData: Failed to fetch AppUser from Firestore: $e',
          );
          _currentUser = null; // Clear user on error
          _selectedSubstation = null; // NEW: Clear selected substation on error
        }
      }
      _isAuthStatusChecked =
          true; // Mark that initial auth status has been checked
      notifyListeners(); // Notify UI about user change
    });
  }

  // NEW: Method to fetch and set a default substation based on subdivisionId
  Future<void> _fetchAndSetDefaultSubstation(String subdivisionId) async {
    try {
      final substationDocs = await FirebaseFirestore.instance
          .collection('substations')
          .where('subdivisionId', isEqualTo: subdivisionId)
          .limit(1) // Fetch just one to set as default if available
          .get();
      if (substationDocs.docs.isNotEmpty) {
        _selectedSubstation = Substation.fromFirestore(
          substationDocs.docs.first,
        );
        print(
          'DEBUG: AppStateData: Default substation set: ${_selectedSubstation?.name}',
        );
      } else {
        _selectedSubstation = null;
        print(
          'DEBUG: AppStateData: No default substation found for subdivision: $subdivisionId',
        );
      }
    } catch (e) {
      print('ERROR: AppStateData: Error fetching default substation: $e');
      _selectedSubstation = null;
    }
  }

  // NEW: Method to explicitly set the selected substation
  void setSelectedSubstation(Substation substation) {
    if (_selectedSubstation?.id != substation.id) {
      _selectedSubstation = substation;
      notifyListeners();
      print(
        'DEBUG: AppStateData: Selected substation updated to: ${substation.name}',
      );
    }
  }

  // Getters for convenience, if still needed by other parts for just names
  List<String> get states {
    return _allStateModels.map((s) => s.name).toList();
  }

  List<CityModel> getCitiesForStateId(String stateId) {
    return allCityModels
        .where((city) => city.stateId.toString() == stateId)
        .toList();
  }

  List<CityModel> getCitiesForStateName(String stateName) {
    print(
      'DEBUG: AppStateData: Attempting to get cities for state: $stateName',
    );
    try {
      final stateId = _allStateModels
          .firstWhere((state) => state.name == stateName)
          .id;
      final filteredCities = _allCityModels
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

  // NEW: Added signOut method as it might have been in your original AppStateData in main.dart context
  Future<void> signOut() async {
    await FirebaseAuth.instance.signOut();
    _currentUser = null;
    _selectedSubstation = null; // Clear on sign out
    notifyListeners();
  }
}

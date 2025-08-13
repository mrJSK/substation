// lib/screens/community/contact_search_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/community_models.dart';
import '../../models/user_model.dart';
import '../../services/community_service.dart';
import 'contact_detail_screen.dart';
import 'add_contact_screen.dart';

class ContactSearchScreen extends StatefulWidget {
  final AppUser currentUser;
  final String? initialQuery;

  const ContactSearchScreen({
    Key? key,
    required this.currentUser,
    this.initialQuery,
  }) : super(key: key);

  @override
  _ContactSearchScreenState createState() => _ContactSearchScreenState();
}

class _ContactSearchScreenState extends State<ContactSearchScreen>
    with TickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  List<ProfessionalContact> _searchResults = [];
  List<ProfessionalContact> _recentContacts = [];
  List<String> _recentSearches = [];
  bool _isLoading = false;
  bool _hasSearched = false;
  String _currentQuery = '';

  // Filter variables
  ContactType? _selectedContactType;
  bool? _showVerifiedOnly;
  List<String> _selectedVoltagelevels = [];
  List<String> _selectedSpecializations = [];
  List<String> _selectedServiceAreas = [];

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  // Predefined filter options
  final List<String> _voltageOptions = [
    '11kV',
    '33kV',
    '66kV',
    '132kV',
    '220kV',
    '400kV',
  ];
  final List<String> _commonSpecializations = [
    'Maintenance',
    'Installation',
    'Repair',
    'Testing',
    'Emergency Service',
    'Protection Systems',
    'SCADA',
    'Transformers',
    'Circuit Breakers',
  ];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );

    if (widget.initialQuery != null && widget.initialQuery!.isNotEmpty) {
      _searchController.text = widget.initialQuery!;
      _currentQuery = widget.initialQuery!;
      _performSearch();
    }

    _loadRecentContacts();
    _loadRecentSearches();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadRecentContacts() async {
    try {
      // Load recently viewed contacts (you can implement this in your service)
      final contacts = await CommunityService.getProfessionalContacts(
        limit: 5,
        filter: CommunitySearchFilter(sortBy: SortType.latest),
      );
      setState(() {
        _recentContacts = contacts;
      });
    } catch (e) {
      print('Error loading recent contacts: $e');
    }
  }

  Future<void> _loadRecentSearches() async {
    // Load from SharedPreferences or local storage
    // For now, using dummy data
    setState(() {
      _recentSearches = [
        'electrical engineer',
        'transformer maintenance',
        '11kV specialist',
        'emergency service',
      ];
    });
  }

  Future<void> _performSearch() async {
    if (_currentQuery.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _hasSearched = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _hasSearched = true;
    });

    try {
      final filter = CommunitySearchFilter(
        keyword: _currentQuery,
        contactType: _selectedContactType,
        isVerified: _showVerifiedOnly,
        voltagelevels: _selectedVoltagelevels,
        limit: 50,
      );

      final results = await CommunityService.searchContacts(
        _currentQuery,
        filter: filter,
      );

      // Apply additional filtering for specializations and service areas
      final filteredResults = results.where((contact) {
        if (_selectedSpecializations.isNotEmpty) {
          bool hasSpecialization = _selectedSpecializations.any(
            (spec) => contact.specializations.any(
              (contactSpec) =>
                  contactSpec.toLowerCase().contains(spec.toLowerCase()),
            ),
          );
          if (!hasSpecialization) return false;
        }

        if (_selectedServiceAreas.isNotEmpty) {
          bool hasServiceArea = _selectedServiceAreas.any(
            (area) => contact.serviceAreas.any(
              (contactArea) =>
                  contactArea.toLowerCase().contains(area.toLowerCase()),
            ),
          );
          if (!hasServiceArea) return false;
        }

        return true;
      }).toList();

      setState(() {
        _searchResults = filteredResults;
        _isLoading = false;
      });

      _animationController.forward();
      _saveSearchQuery(_currentQuery);
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showErrorSnackBar('Search failed: $e');
    }
  }

  void _saveSearchQuery(String query) {
    if (!_recentSearches.contains(query)) {
      setState(() {
        _recentSearches.insert(0, query);
        if (_recentSearches.length > 10) {
          _recentSearches.removeLast();
        }
      });
      // Save to SharedPreferences here
    }
  }

  void _onSearchChanged(String query) {
    setState(() {
      _currentQuery = query;
    });

    // Debounce search
    Future.delayed(Duration(milliseconds: 500), () {
      if (_currentQuery == query && query.isNotEmpty) {
        _performSearch();
      }
    });
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() {
      _currentQuery = '';
      _searchResults = [];
      _hasSearched = false;
    });
    _animationController.reset();
  }

  void _showAdvancedFilters() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Color(0xFFFAFAFA),
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _buildAdvancedFiltersSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFFAFAFA),
      appBar: AppBar(
        title: Text(
          'Search Contacts',
          style: TextStyle(fontWeight: FontWeight.w600, color: Colors.black87),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.black87),
        actions: [
          IconButton(
            icon: Icon(Icons.filter_list),
            onPressed: _showAdvancedFilters,
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Container(
            color: Colors.white,
            padding: EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Color(0xFFF5F5F5),
                      borderRadius: BorderRadius.circular(25),
                    ),
                    child: TextField(
                      controller: _searchController,
                      onChanged: _onSearchChanged,
                      onSubmitted: (query) {
                        _currentQuery = query;
                        _performSearch();
                      },
                      decoration: InputDecoration(
                        hintText:
                            'Search by name, designation, specialization...',
                        prefixIcon: Icon(Icons.search, color: Colors.grey[600]),
                        suffixIcon: _currentQuery.isNotEmpty
                            ? IconButton(
                                icon: Icon(
                                  Icons.clear,
                                  color: Colors.grey[600],
                                ),
                                onPressed: _clearSearch,
                              )
                            : null,
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 15,
                        ),
                      ),
                    ),
                  ),
                ),
                if (_hasActiveFilters()) ...[
                  SizedBox(width: 10),
                  Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).primaryColor,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: IconButton(
                      icon: Icon(Icons.filter_list, color: Colors.white),
                      onPressed: _showAdvancedFilters,
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Active Filters Display
          if (_hasActiveFilters()) _buildActiveFiltersBar(),

          // Search Results or Initial State
          Expanded(child: _buildSearchContent()),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _navigateToAddContact,
        backgroundColor: Theme.of(context).primaryColor,
        icon: Icon(Icons.add, color: Colors.white),
        label: Text(
          'Add Contact',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Widget _buildActiveFiltersBar() {
    List<Widget> filterChips = [];

    if (_selectedContactType != null) {
      filterChips.add(
        _buildFilterChip(
          _getContactTypeLabel(_selectedContactType!),
          () => setState(() => _selectedContactType = null),
        ),
      );
    }

    if (_showVerifiedOnly == true) {
      filterChips.add(
        _buildFilterChip(
          'Verified Only',
          () => setState(() => _showVerifiedOnly = null),
        ),
      );
    }

    for (String voltage in _selectedVoltagelevels) {
      filterChips.add(
        _buildFilterChip(
          voltage,
          () => setState(() => _selectedVoltagelevels.remove(voltage)),
        ),
      );
    }

    for (String spec in _selectedSpecializations) {
      filterChips.add(
        _buildFilterChip(
          spec,
          () => setState(() => _selectedSpecializations.remove(spec)),
        ),
      );
    }

    return Container(
      color: Colors.white,
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: filterChips),
            ),
          ),
          TextButton(onPressed: _clearAllFilters, child: Text('Clear All')),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, VoidCallback onRemove) {
    return Container(
      margin: EdgeInsets.only(right: 8),
      child: Chip(
        label: Text(label),
        deleteIcon: Icon(Icons.close, size: 16),
        onDeleted: onRemove,
        backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
        labelStyle: TextStyle(color: Theme.of(context).primaryColor),
      ),
    );
  }

  Widget _buildSearchContent() {
    if (!_hasSearched) {
      return _buildInitialState();
    }

    if (_isLoading) {
      return _buildLoadingState();
    }

    if (_searchResults.isEmpty) {
      return _buildEmptyState();
    }

    return _buildSearchResults();
  }

  Widget _buildInitialState() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Search Suggestions
          if (_recentSearches.isNotEmpty) ...[
            Text(
              'Recent Searches',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _recentSearches.take(6).map((search) {
                return ActionChip(
                  label: Text(search),
                  onPressed: () {
                    _searchController.text = search;
                    _currentQuery = search;
                    _performSearch();
                  },
                  backgroundColor: Colors.grey[100],
                );
              }).toList(),
            ),
            SizedBox(height: 24),
          ],

          // Recent Contacts
          if (_recentContacts.isNotEmpty) ...[
            Text(
              'Recent Contacts',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            SizedBox(height: 12),
            ...(_recentContacts
                .map((contact) => _buildContactCard(contact))
                .toList()),
          ],

          // Quick Search Categories
          SizedBox(height: 24),
          Text(
            'Quick Search',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 2.5,
            children: [
              _buildQuickSearchCard(
                'Engineers',
                Icons.engineering,
                ContactType.engineer,
              ),
              _buildQuickSearchCard('Vendors', Icons.store, ContactType.vendor),
              _buildQuickSearchCard(
                'Contractors',
                Icons.construction,
                ContactType.contractor,
              ),
              _buildQuickSearchCard(
                'Emergency',
                Icons.emergency,
                ContactType.emergencyService,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickSearchCard(String title, IconData icon, ContactType type) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedContactType = type;
            _currentQuery = '';
            _hasSearched = true;
          });
          _performSearch();
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: EdgeInsets.all(12),
          child: Row(
            children: [
              Icon(icon, color: _getContactTypeColor(type)),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color: Colors.black87,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(
              Theme.of(context).primaryColor,
            ),
          ),
          SizedBox(height: 20),
          Text(
            'Searching contacts...',
            style: TextStyle(color: Colors.grey[600], fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off, size: 80, color: Colors.grey[400]),
          SizedBox(height: 20),
          Text(
            'No contacts found',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey[600],
            ),
          ),
          SizedBox(height: 10),
          Text(
            'Try adjusting your search terms or filters',
            style: TextStyle(color: Colors.grey[500], fontSize: 14),
          ),
          SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _navigateToAddContact,
            icon: Icon(Icons.add),
            label: Text('Add New Contact'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).primaryColor,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResults() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Column(
        children: [
          // Results Header
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: Colors.white,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${_searchResults.length} contacts found',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                DropdownButton<SortType>(
                  value: SortType.latest,
                  underline: SizedBox(),
                  items: [
                    DropdownMenuItem(
                      value: SortType.latest,
                      child: Text('Latest'),
                    ),
                    DropdownMenuItem(
                      value: SortType.alphabetical,
                      child: Text('Name A-Z'),
                    ),
                    DropdownMenuItem(
                      value: SortType.rating,
                      child: Text('Highest Rated'),
                    ),
                  ],
                  onChanged: (value) {
                    // Implement sorting
                  },
                ),
              ],
            ),
          ),

          // Results List
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.all(16),
              itemCount: _searchResults.length,
              itemBuilder: (context, index) {
                return _buildContactCard(_searchResults[index]);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactCard(ProfessionalContact contact) {
    return Card(
      margin: EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _navigateToContactDetail(contact),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 25,
                    backgroundColor: _getContactTypeColor(
                      contact.contactType,
                    ).withOpacity(0.1),
                    child: Text(
                      contact.name.isNotEmpty
                          ? contact.name[0].toUpperCase()
                          : 'U',
                      style: TextStyle(
                        color: _getContactTypeColor(contact.contactType),
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                contact.name,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black87,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            SizedBox(width: 8),
                            if (contact.isVerified)
                              Icon(
                                Icons.verified,
                                color: Colors.green,
                                size: 16,
                              ),
                          ],
                        ),
                        Text(
                          '${contact.designation} - ${contact.department}',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    children: [
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: _getContactTypeColor(
                            contact.contactType,
                          ).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          _getContactTypeLabel(contact.contactType),
                          style: TextStyle(
                            color: _getContactTypeColor(contact.contactType),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (contact.metrics.rating > 0) ...[
                        SizedBox(height: 4),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.star, color: Colors.amber, size: 14),
                            Text(
                              contact.metrics.rating.toStringAsFixed(1),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ],
              ),

              if (contact.specializations.isNotEmpty) ...[
                SizedBox(height: 12),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: contact.specializations.take(3).map((spec) {
                    return Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Text(
                        spec,
                        style: TextStyle(fontSize: 11, color: Colors.grey[700]),
                      ),
                    );
                  }).toList(),
                ),
              ],

              SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.phone, size: 16, color: Colors.grey[600]),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      contact.phoneNumber,
                      style: TextStyle(color: Colors.grey[700], fontSize: 13),
                    ),
                  ),
                  Icon(Icons.email, size: 16, color: Colors.grey[600]),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      contact.email,
                      style: TextStyle(color: Colors.grey[700], fontSize: 13),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAdvancedFiltersSheet() {
    return StatefulBuilder(
      builder: (context, setModalState) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.8,
          padding: EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Advanced Filters',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      setModalState(() {
                        _selectedContactType = null;
                        _showVerifiedOnly = null;
                        _selectedVoltagelevels.clear();
                        _selectedSpecializations.clear();
                        _selectedServiceAreas.clear();
                      });
                    },
                    child: Text('Clear All'),
                  ),
                ],
              ),
              SizedBox(height: 20),

              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Contact Type Filter
                      _buildFilterSection(
                        'Contact Type',
                        Wrap(
                          spacing: 8,
                          children: ContactType.values.map((type) {
                            return FilterChip(
                              label: Text(_getContactTypeLabel(type)),
                              selected: _selectedContactType == type,
                              onSelected: (selected) {
                                setModalState(() {
                                  _selectedContactType = selected ? type : null;
                                });
                              },
                              backgroundColor: Colors.grey[200],
                              selectedColor: _getContactTypeColor(type),
                              labelStyle: TextStyle(
                                color: _selectedContactType == type
                                    ? Colors.white
                                    : Colors.black87,
                              ),
                            );
                          }).toList(),
                        ),
                      ),

                      SizedBox(height: 20),

                      // Verification Status
                      _buildFilterSection(
                        'Verification Status',
                        Row(
                          children: [
                            FilterChip(
                              label: Text('Verified Only'),
                              selected: _showVerifiedOnly == true,
                              onSelected: (selected) {
                                setModalState(() {
                                  _showVerifiedOnly = selected ? true : null;
                                });
                              },
                              backgroundColor: Colors.grey[200],
                              selectedColor: Colors.green,
                              labelStyle: TextStyle(
                                color: _showVerifiedOnly == true
                                    ? Colors.white
                                    : Colors.black87,
                              ),
                            ),
                          ],
                        ),
                      ),

                      SizedBox(height: 20),

                      // Voltage Levels
                      _buildFilterSection(
                        'Voltage Levels',
                        Wrap(
                          spacing: 8,
                          children: _voltageOptions.map((voltage) {
                            return FilterChip(
                              label: Text(voltage),
                              selected: _selectedVoltagelevels.contains(
                                voltage,
                              ),
                              onSelected: (selected) {
                                setModalState(() {
                                  if (selected) {
                                    _selectedVoltagelevels.add(voltage);
                                  } else {
                                    _selectedVoltagelevels.remove(voltage);
                                  }
                                });
                              },
                              backgroundColor: Colors.grey[200],
                              selectedColor: Colors.orange,
                              labelStyle: TextStyle(
                                color: _selectedVoltagelevels.contains(voltage)
                                    ? Colors.white
                                    : Colors.black87,
                              ),
                            );
                          }).toList(),
                        ),
                      ),

                      SizedBox(height: 20),

                      // Specializations
                      _buildFilterSection(
                        'Specializations',
                        Wrap(
                          spacing: 8,
                          children: _commonSpecializations.map((spec) {
                            return FilterChip(
                              label: Text(spec),
                              selected: _selectedSpecializations.contains(spec),
                              onSelected: (selected) {
                                setModalState(() {
                                  if (selected) {
                                    _selectedSpecializations.add(spec);
                                  } else {
                                    _selectedSpecializations.remove(spec);
                                  }
                                });
                              },
                              backgroundColor: Colors.grey[200],
                              selectedColor: Theme.of(context).primaryColor,
                              labelStyle: TextStyle(
                                color: _selectedSpecializations.contains(spec)
                                    ? Colors.white
                                    : Colors.black87,
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              SizedBox(height: 20),

              // Apply Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _performSearch();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    padding: EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: Text(
                    'Apply Filters',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFilterSection(String title, Widget content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
        SizedBox(height: 10),
        content,
      ],
    );
  }

  // Helper Methods
  bool _hasActiveFilters() {
    return _selectedContactType != null ||
        _showVerifiedOnly != null ||
        _selectedVoltagelevels.isNotEmpty ||
        _selectedSpecializations.isNotEmpty ||
        _selectedServiceAreas.isNotEmpty;
  }

  void _clearAllFilters() {
    setState(() {
      _selectedContactType = null;
      _showVerifiedOnly = null;
      _selectedVoltagelevels.clear();
      _selectedSpecializations.clear();
      _selectedServiceAreas.clear();
    });
    _performSearch();
  }

  String _getContactTypeLabel(ContactType type) {
    switch (type) {
      case ContactType.vendor:
        return 'Vendor';
      case ContactType.engineer:
        return 'Engineer';
      case ContactType.technician:
        return 'Technician';
      case ContactType.contractor:
        return 'Contractor';
      case ContactType.supplier:
        return 'Supplier';
      case ContactType.consultant:
        return 'Consultant';
      case ContactType.emergencyService:
        return 'Emergency';
      case ContactType.other:
        return 'Other';
    }
  }

  Color _getContactTypeColor(ContactType type) {
    switch (type) {
      case ContactType.vendor:
        return Colors.purple;
      case ContactType.engineer:
        return Colors.blue;
      case ContactType.technician:
        return Colors.orange;
      case ContactType.contractor:
        return Colors.green;
      case ContactType.supplier:
        return Colors.teal;
      case ContactType.consultant:
        return Colors.indigo;
      case ContactType.emergencyService:
        return Colors.red;
      case ContactType.other:
        return Colors.grey;
    }
  }

  void _navigateToContactDetail(ProfessionalContact contact) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ContactDetailScreen(
          contact: contact,
          currentUser: widget.currentUser,
        ),
      ),
    );
  }

  void _navigateToAddContact() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddContactScreen(currentUser: widget.currentUser),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

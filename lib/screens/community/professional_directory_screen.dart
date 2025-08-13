// lib/screens/community/professional_directory_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../models/community_models.dart';
import '../../../models/user_model.dart';
import '../../../services/community_service.dart';
import 'add_contact_screen.dart';
import 'contact_detail_screen.dart';

class ProfessionalDirectoryScreen extends StatefulWidget {
  final AppUser currentUser;

  const ProfessionalDirectoryScreen({Key? key, required this.currentUser})
    : super(key: key);

  @override
  _ProfessionalDirectoryScreenState createState() =>
      _ProfessionalDirectoryScreenState();
}

class _ProfessionalDirectoryScreenState
    extends State<ProfessionalDirectoryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<ProfessionalContact> _contacts = [];
  List<ProfessionalContact> _filteredContacts = [];
  bool _isLoading = true;
  String _searchQuery = '';
  ContactType? _selectedContactType;
  bool? _showVerifiedOnly;
  DocumentSnapshot? _lastDocument;
  bool _hasMoreData = true;
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _scrollController.addListener(_onScroll);
    _loadContacts();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels ==
        _scrollController.position.maxScrollExtent) {
      if (_hasMoreData && !_isLoading) {
        _loadMoreContacts();
      }
    }
  }

  Future<void> _loadContacts() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final filter = CommunitySearchFilter(
        contactType: _selectedContactType,
        isVerified: _showVerifiedOnly,
        limit: 20,
      );

      final contacts = await CommunityService.getProfessionalContacts(
        filter: filter,
        limit: 20,
      );

      setState(() {
        _contacts = contacts;
        _filteredContacts = contacts;
        _isLoading = false;
        _hasMoreData = contacts.length == 20;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showErrorSnackBar('Failed to load contacts: $e');
    }
  }

  Future<void> _loadMoreContacts() async {
    if (_contacts.isEmpty) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final filter = CommunitySearchFilter(
        contactType: _selectedContactType,
        isVerified: _showVerifiedOnly,
        limit: 20,
      );

      final contacts = await CommunityService.getProfessionalContacts(
        filter: filter,
        limit: 20,
        lastDocument: _lastDocument,
      );

      setState(() {
        _contacts.addAll(contacts);
        _filteredContacts = _contacts;
        _isLoading = false;
        _hasMoreData = contacts.length == 20;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showErrorSnackBar('Failed to load more contacts: $e');
    }
  }

  void _searchContacts(String query) {
    setState(() {
      _searchQuery = query;
      if (query.isEmpty) {
        _filteredContacts = _contacts;
      } else {
        _filteredContacts = _contacts.where((contact) {
          return contact.name.toLowerCase().contains(query.toLowerCase()) ||
              contact.designation.toLowerCase().contains(query.toLowerCase()) ||
              contact.department.toLowerCase().contains(query.toLowerCase()) ||
              contact.specializations.any(
                (spec) => spec.toLowerCase().contains(query.toLowerCase()),
              );
        }).toList();
      }
    });
  }

  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Color(0xFFFAFAFA),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _buildFilterSheet(),
    );
  }

  Widget _buildFilterSheet() {
    return StatefulBuilder(
      builder: (context, setModalState) {
        return Container(
          padding: EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Filter Contacts',
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
                      });
                    },
                    child: Text('Clear All'),
                  ),
                ],
              ),
              SizedBox(height: 20),

              // Contact Type Filter
              Text(
                'Contact Type',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              SizedBox(height: 10),
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
                    selectedColor: Theme.of(context).primaryColor,
                    labelStyle: TextStyle(
                      color: _selectedContactType == type
                          ? Colors.white
                          : Colors.black87,
                    ),
                  );
                }).toList(),
              ),

              SizedBox(height: 20),

              // Verification Filter
              Text(
                'Verification Status',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              SizedBox(height: 10),
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
                  SizedBox(width: 10),
                  FilterChip(
                    label: Text('All Contacts'),
                    selected: _showVerifiedOnly == null,
                    onSelected: (selected) {
                      setModalState(() {
                        _showVerifiedOnly = null;
                      });
                    },
                    backgroundColor: Colors.grey[200],
                    selectedColor: Theme.of(context).primaryColor,
                  ),
                ],
              ),

              SizedBox(height: 30),

              // Apply Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _loadContacts();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFFAFAFA),
      appBar: AppBar(
        title: Text(
          'Professional Directory',
          style: TextStyle(fontWeight: FontWeight.w600, color: Colors.black87),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.black87),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Theme.of(context).primaryColor,
          unselectedLabelColor: Colors.grey[600],
          indicatorColor: Theme.of(context).primaryColor,
          tabs: [
            Tab(text: 'All'),
            Tab(text: 'Engineers'),
            Tab(text: 'Vendors'),
            Tab(text: 'Contractors'),
          ],
        ),
      ),
      body: Column(
        children: [
          // Search and Filter Bar
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
                      onChanged: _searchContacts,
                      decoration: InputDecoration(
                        hintText: 'Search contacts...',
                        prefixIcon: Icon(Icons.search, color: Colors.grey[600]),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 15,
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 10),
                Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor,
                    borderRadius: BorderRadius.circular(25),
                  ),
                  child: IconButton(
                    icon: Icon(Icons.filter_list, color: Colors.white),
                    onPressed: _showFilterSheet,
                  ),
                ),
              ],
            ),
          ),

          // Contact List
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildContactList(_filteredContacts),
                _buildContactList(
                  _filteredContacts
                      .where((c) => c.contactType == ContactType.engineer)
                      .toList(),
                ),
                _buildContactList(
                  _filteredContacts
                      .where((c) => c.contactType == ContactType.vendor)
                      .toList(),
                ),
                _buildContactList(
                  _filteredContacts
                      .where((c) => c.contactType == ContactType.contractor)
                      .toList(),
                ),
              ],
            ),
          ),
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

  Widget _buildContactList(List<ProfessionalContact> contacts) {
    if (_isLoading && contacts.isEmpty) {
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
              'Loading contacts...',
              style: TextStyle(color: Colors.grey[600], fontSize: 16),
            ),
          ],
        ),
      );
    }

    if (contacts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.contacts, size: 80, color: Colors.grey[400]),
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
              'Be the first to add a professional contact!',
              style: TextStyle(color: Colors.grey[500], fontSize: 14),
            ),
            SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _navigateToAddContact,
              icon: Icon(Icons.add),
              label: Text('Add Contact'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).primaryColor,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadContacts,
      color: Theme.of(context).primaryColor,
      child: ListView.builder(
        controller: _scrollController,
        padding: EdgeInsets.all(16),
        itemCount: contacts.length + (_hasMoreData ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == contacts.length) {
            return _buildLoadingIndicator();
          }
          return _buildContactCard(contacts[index]);
        },
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

  Widget _buildLoadingIndicator() {
    return Container(
      padding: EdgeInsets.all(20),
      child: Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(
            Theme.of(context).primaryColor,
          ),
        ),
      ),
    );
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

  void _navigateToAddContact() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddContactScreen(currentUser: widget.currentUser),
      ),
    ).then((_) => _loadContacts());
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

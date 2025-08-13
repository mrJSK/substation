// lib/screens/community/contact_detail_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/community_models.dart';
import '../../models/user_model.dart';
import '../../services/community_service.dart';
import 'edit_contact_screen.dart';
import 'add_review_screen.dart';

class ContactDetailScreen extends StatefulWidget {
  final ProfessionalContact contact;
  final AppUser currentUser;

  const ContactDetailScreen({
    Key? key,
    required this.contact,
    required this.currentUser,
  }) : super(key: key);

  @override
  _ContactDetailScreenState createState() => _ContactDetailScreenState();
}

class _ContactDetailScreenState extends State<ContactDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late ProfessionalContact _contact;
  List<ContactReview> _reviews = [];
  bool _isLoading = false;
  bool _isLoadingReviews = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _contact = widget.contact;
    _loadReviews();
    _incrementViewCount();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadReviews() async {
    setState(() {
      _isLoadingReviews = true;
    });

    try {
      final reviews = await CommunityService.getContactReviews(_contact.id!);
      setState(() {
        _reviews = reviews;
        _isLoadingReviews = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingReviews = false;
      });
      _showErrorSnackBar('Failed to load reviews: $e');
    }
  }

  Future<void> _incrementViewCount() async {
    try {
      // Increment view count in background
      await CommunityService.incrementContactViews(_contact.id!);
    } catch (e) {
      // Silently fail for view count
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFFAFAFA),
      body: CustomScrollView(
        slivers: [
          // App Bar with Contact Header
          SliverAppBar(
            expandedHeight: 280,
            pinned: true,
            backgroundColor: _getContactTypeColor(_contact.contactType),
            leading: IconButton(
              icon: Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              if (_canEditContact())
                IconButton(
                  icon: Icon(Icons.edit, color: Colors.white),
                  onPressed: _navigateToEditContact,
                ),
              PopupMenuButton<String>(
                icon: Icon(Icons.more_vert, color: Colors.white),
                onSelected: _handleMenuAction,
                itemBuilder: (context) => [
                  if (_canVerifyContact())
                    PopupMenuItem(
                      value: 'verify',
                      child: Row(
                        children: [
                          Icon(Icons.verified, color: Colors.green),
                          SizedBox(width: 8),
                          Text('Verify Contact'),
                        ],
                      ),
                    ),
                  PopupMenuItem(
                    value: 'share',
                    child: Row(
                      children: [
                        Icon(Icons.share, color: Colors.blue),
                        SizedBox(width: 8),
                        Text('Share Contact'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'report',
                    child: Row(
                      children: [
                        Icon(Icons.flag, color: Colors.orange),
                        SizedBox(width: 8),
                        Text('Report Contact'),
                      ],
                    ),
                  ),
                ],
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      _getContactTypeColor(_contact.contactType),
                      _getContactTypeColor(
                        _contact.contactType,
                      ).withOpacity(0.8),
                    ],
                  ),
                ),
                child: _buildContactHeader(),
              ),
            ),
          ),

          // Tab Bar
          SliverPersistentHeader(
            pinned: true,
            delegate: _TabBarDelegate(
              TabBar(
                controller: _tabController,
                labelColor: Theme.of(context).primaryColor,
                unselectedLabelColor: Colors.grey[600],
                indicatorColor: Theme.of(context).primaryColor,
                // backgroundColor: Colors.white,
                tabs: [
                  Tab(text: 'Details'),
                  Tab(text: 'Reviews (${_reviews.length})'),
                  Tab(text: 'Projects'),
                ],
              ),
            ),
          ),

          // Tab Content
          SliverFillRemaining(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildDetailsTab(),
                _buildReviewsTab(),
                _buildProjectsTab(),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomActionBar(),
    );
  }

  Widget _buildContactHeader() {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 40,
                  backgroundColor: Colors.white.withOpacity(0.2),
                  child: Text(
                    _contact.name.isNotEmpty
                        ? _contact.name[0].toUpperCase()
                        : 'U',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 28,
                    ),
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              _contact.name,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          SizedBox(width: 8),
                          if (_contact.isVerified)
                            Container(
                              padding: EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Colors.green,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                Icons.verified,
                                color: Colors.white,
                                size: 16,
                              ),
                            ),
                        ],
                      ),
                      Text(
                        _contact.designation,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        _contact.department,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            Row(
              children: [
                if (_contact.metrics.rating > 0) ...[
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.star, color: Colors.amber, size: 16),
                        SizedBox(width: 4),
                        Text(
                          _contact.metrics.rating.toStringAsFixed(1),
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          ' (${_contact.metrics.totalReviews})',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: 12),
                ],
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _getContactTypeLabel(_contact.contactType),
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailsTab() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Contact Information Card
          _buildInfoCard(
            title: 'Contact Information',
            icon: Icons.contact_phone,
            children: [
              _buildInfoRow(
                'Phone',
                _contact.phoneNumber,
                Icons.phone,
                onTap: () => _launchPhone(_contact.phoneNumber),
              ),
              if (_contact.alternatePhone != null)
                _buildInfoRow(
                  'Alternate Phone',
                  _contact.alternatePhone!,
                  Icons.phone_android,
                  onTap: () => _launchPhone(_contact.alternatePhone!),
                ),
              _buildInfoRow(
                'Email',
                _contact.email,
                Icons.email,
                onTap: () => _launchEmail(_contact.email),
              ),
              if (_contact.alternateEmail != null)
                _buildInfoRow(
                  'Alternate Email',
                  _contact.alternateEmail!,
                  Icons.alternate_email,
                  onTap: () => _launchEmail(_contact.alternateEmail!),
                ),
            ],
          ),

          SizedBox(height: 16),

          // Company Information Card
          if (_contact.companyName != null)
            _buildInfoCard(
              title: 'Company Information',
              icon: Icons.business,
              children: [
                _buildInfoRow('Company', _contact.companyName!, Icons.business),
                _buildInfoRow('Department', _contact.department, Icons.group),
              ],
            ),

          SizedBox(height: 16),

          // Specializations Card
          if (_contact.specializations.isNotEmpty)
            _buildInfoCard(
              title: 'Specializations',
              icon: Icons.star,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _contact.specializations.map((spec) {
                    return Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(context).primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Theme.of(
                            context,
                          ).primaryColor.withOpacity(0.3),
                        ),
                      ),
                      child: Text(
                        spec,
                        style: TextStyle(
                          color: Theme.of(context).primaryColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),

          SizedBox(height: 16),

          // Electrical Expertise Card
          if (_contact.electricalExpertise != null)
            _buildElectricalExpertiseCard(),

          SizedBox(height: 16),

          // Service Areas Card
          if (_contact.serviceAreas.isNotEmpty)
            _buildInfoCard(
              title: 'Service Areas',
              icon: Icons.location_on,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _contact.serviceAreas.map((area) {
                    return Chip(
                      label: Text(area),
                      backgroundColor: Colors.grey[100],
                    );
                  }).toList(),
                ),
              ],
            ),

          SizedBox(height: 16),

          // Availability Card
          _buildAvailabilityCard(),

          SizedBox(height: 16),

          // Certifications Card
          if (_contact.certifications.isNotEmpty)
            _buildInfoCard(
              title: 'Certifications',
              icon: Icons.verified_user,
              children: [
                Column(
                  children: _contact.certifications.map((cert) {
                    return Container(
                      margin: EdgeInsets.only(bottom: 8),
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.green.withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.verified, color: Colors.green, size: 20),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              cert,
                              style: TextStyle(
                                fontWeight: FontWeight.w500,
                                color: Colors.green[800],
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),

          SizedBox(height: 16),

          // Address Card
          if (_contact.address != null) _buildAddressCard(),

          SizedBox(height: 100), // Space for bottom action bar
        ],
      ),
    );
  }

  Widget _buildReviewsTab() {
    if (_isLoadingReviews) {
      return Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(
            Theme.of(context).primaryColor,
          ),
        ),
      );
    }

    if (_reviews.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.rate_review, size: 80, color: Colors.grey[400]),
            SizedBox(height: 20),
            Text(
              'No reviews yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey[600],
              ),
            ),
            SizedBox(height: 10),
            Text(
              'Be the first to review this contact!',
              style: TextStyle(color: Colors.grey[500], fontSize: 14),
            ),
            SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _navigateToAddReview,
              icon: Icon(Icons.rate_review),
              label: Text('Write Review'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).primaryColor,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: _reviews.length,
      itemBuilder: (context, index) {
        return _buildReviewCard(_reviews[index]);
      },
    );
  }

  Widget _buildProjectsTab() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.work, size: 80, color: Colors.grey[400]),
          SizedBox(height: 20),
          Text(
            'Project History',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey[600],
            ),
          ),
          SizedBox(height: 10),
          Text(
            'Project history will be available soon',
            style: TextStyle(color: Colors.grey[500], fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: Theme.of(context).primaryColor),
                SizedBox(width: 12),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(
    String label,
    String value,
    IconData icon, {
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Row(
          children: [
            Icon(icon, size: 20, color: Colors.grey[600]),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.black87,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            if (onTap != null)
              Icon(Icons.open_in_new, size: 16, color: Colors.grey[500]),
          ],
        ),
      ),
    );
  }

  Widget _buildElectricalExpertiseCard() {
    final expertise = _contact.electricalExpertise!;
    return _buildInfoCard(
      title: 'Electrical Expertise',
      icon: Icons.electrical_services,
      children: [
        if (expertise.voltageExpertise.isNotEmpty) ...[
          Text(
            'Voltage Levels',
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: Colors.grey[700],
            ),
          ),
          SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: expertise.voltageExpertise.map((voltage) {
              return Container(
                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: Colors.orange.withOpacity(0.3)),
                ),
                child: Text(
                  voltage,
                  style: TextStyle(
                    color: Colors.orange[800],
                    fontWeight: FontWeight.w500,
                    fontSize: 12,
                  ),
                ),
              );
            }).toList(),
          ),
          SizedBox(height: 16),
        ],
        if (expertise.equipmentExpertise.isNotEmpty) ...[
          Text(
            'Equipment Types',
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: Colors.grey[700],
            ),
          ),
          SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: expertise.equipmentExpertise.map((equipment) {
              return Container(
                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: Colors.blue.withOpacity(0.3)),
                ),
                child: Text(
                  equipment,
                  style: TextStyle(
                    color: Colors.blue[800],
                    fontWeight: FontWeight.w500,
                    fontSize: 12,
                  ),
                ),
              );
            }).toList(),
          ),
          SizedBox(height: 16),
        ],
        Row(
          children: [
            Expanded(
              child: _buildStatItem(
                'Experience',
                '${expertise.experienceYears} years',
                Icons.work,
              ),
            ),
            if (expertise.hasGovernmentClearance)
              Expanded(
                child: _buildStatItem(
                  'Clearance',
                  expertise.clearanceLevel ?? 'Approved',
                  Icons.security,
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildAvailabilityCard() {
    final availability = _contact.availability;
    return _buildInfoCard(
      title: 'Availability',
      icon: Icons.schedule,
      children: [
        Row(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: availability.isAvailable ? Colors.green : Colors.red,
                shape: BoxShape.circle,
              ),
            ),
            SizedBox(width: 8),
            Text(
              availability.isAvailable ? 'Available' : 'Not Available',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: availability.isAvailable ? Colors.green : Colors.red,
              ),
            ),
          ],
        ),
        if (availability.workingHours.isNotEmpty) ...[
          SizedBox(height: 12),
          _buildInfoRow(
            'Working Hours',
            availability.workingHours,
            Icons.access_time,
          ),
        ],
        if (availability.emergencyAvailable) ...[
          SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.emergency, color: Colors.red, size: 20),
              SizedBox(width: 12),
              Text(
                'Emergency Available',
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          if (availability.emergencyHours != null)
            Text(
              availability.emergencyHours!,
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
        ],
      ],
    );
  }

  Widget _buildAddressCard() {
    final address = _contact.address!;
    return _buildInfoCard(
      title: 'Address',
      icon: Icons.location_on,
      children: [
        Text(
          '${address.street}\n${address.city}, ${address.state} ${address.pincode}',
          style: TextStyle(fontSize: 14, color: Colors.black87),
        ),
        if (address.landmark != null) ...[
          SizedBox(height: 8),
          Text(
            'Landmark: ${address.landmark}',
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
        ],
        if (address.latitude != null && address.longitude != null) ...[
          SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: () => _openMap(address.latitude!, address.longitude!),
            icon: Icon(Icons.map),
            label: Text('Open in Maps'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).primaryColor,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildReviewCard(ContactReview review) {
    return Card(
      margin: EdgeInsets.only(bottom: 12),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: Theme.of(
                    context,
                  ).primaryColor.withOpacity(0.1),
                  child: Text(
                    review.reviewerName.isNotEmpty
                        ? review.reviewerName[0].toUpperCase()
                        : 'U',
                    style: TextStyle(
                      color: Theme.of(context).primaryColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        review.reviewerName,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      Text(
                        _formatDate(review.createdAt.toDate()),
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Row(
                  children: List.generate(5, (index) {
                    return Icon(
                      index < review.rating ? Icons.star : Icons.star_border,
                      color: Colors.amber,
                      size: 16,
                    );
                  }),
                ),
              ],
            ),
            if (review.review != null && review.review!.isNotEmpty) ...[
              SizedBox(height: 12),
              Text(
                review.review!,
                style: TextStyle(color: Colors.black87, height: 1.4),
              ),
            ],
            SizedBox(height: 8),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                review.projectType,
                style: TextStyle(fontSize: 12, color: Colors.grey[700]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Icon(icon, color: Theme.of(context).primaryColor, size: 20),
          SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
        ],
      ),
    );
  }

  Widget _buildBottomActionBar() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.3),
            spreadRadius: 1,
            blurRadius: 10,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => _launchPhone(_contact.phoneNumber),
              icon: Icon(Icons.phone),
              label: Text('Call'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Theme.of(context).primaryColor,
                side: BorderSide(color: Theme.of(context).primaryColor),
                padding: EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => _launchEmail(_contact.email),
              icon: Icon(Icons.email),
              label: Text('Email'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Theme.of(context).primaryColor,
                side: BorderSide(color: Theme.of(context).primaryColor),
                padding: EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _navigateToAddReview,
              icon: Icon(Icons.rate_review),
              label: Text('Review'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).primaryColor,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Helper Methods
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

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'Today';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  bool _canEditContact() {
    // ignore: unrelated_type_equality_checks
    return _contact.addedBy == widget.currentUser ||
        widget.currentUser.role == UserRole.admin ||
        widget.currentUser.role == UserRole.superAdmin;
  }

  bool _canVerifyContact() {
    return !_contact.isVerified &&
        (widget.currentUser.role == UserRole.admin ||
            widget.currentUser.role == UserRole.superAdmin ||
            widget.currentUser.role == UserRole.divisionManager ||
            widget.currentUser.role == UserRole.subdivisionManager);
  }

  // Action Methods
  void _handleMenuAction(String action) {
    switch (action) {
      case 'verify':
        _verifyContact();
        break;
      case 'share':
        _shareContact();
        break;
      case 'report':
        _reportContact();
        break;
    }
  }

  void _verifyContact() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Verify Contact'),
        content: Text(
          'Are you sure you want to verify this contact? This action will make it visible to all users.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await CommunityService.verifyContact(
                  _contact.id!,
                  widget.currentUser.uid!,
                  widget.currentUser.email,
                );
                setState(() {
                  _contact = _contact.copyWith(
                    isVerified: true,
                    verifiedBy: widget.currentUser.uid,
                    verifiedByName: widget.currentUser.email,
                  );
                });
                _showSuccessSnackBar('Contact verified successfully');
              } catch (e) {
                _showErrorSnackBar('Failed to verify contact: $e');
              }
            },
            child: Text('Verify'),
          ),
        ],
      ),
    );
  }

  void _shareContact() {
    final contactInfo =
        '''
${_contact.name}
${_contact.designation} - ${_contact.department}
Phone: ${_contact.phoneNumber}
Email: ${_contact.email}
''';

    Clipboard.setData(ClipboardData(text: contactInfo));
    _showSuccessSnackBar('Contact information copied to clipboard');
  }

  void _reportContact() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Report Contact'),
        content: Text(
          'Please report any inappropriate or incorrect contact information to the administrators.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _showSuccessSnackBar(
                'Contact reported. Administrators will review it.',
              );
            },
            child: Text('Report'),
          ),
        ],
      ),
    );
  }

  void _navigateToEditContact() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditContactScreen(
          contact: _contact,
          currentUser: widget.currentUser,
        ),
      ),
    ).then((updatedContact) {
      if (updatedContact != null) {
        setState(() {
          _contact = updatedContact;
        });
      }
    });
  }

  void _navigateToAddReview() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            AddReviewScreen(contact: _contact, currentUser: widget.currentUser),
      ),
    ).then((_) => _loadReviews());
  }

  // Launch Methods
  void _launchPhone(String phoneNumber) async {
    final uri = Uri.parse('tel:$phoneNumber');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  void _launchEmail(String email) async {
    final uri = Uri.parse('mailto:$email');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  void _openMap(double latitude, double longitude) async {
    final uri = Uri.parse('https://maps.google.com/?q=$latitude,$longitude');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
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

// Custom TabBar Delegate for SliverPersistentHeader
class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;

  _TabBarDelegate(this.tabBar);

  @override
  double get minExtent => tabBar.preferredSize.height;

  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(color: Colors.white, child: tabBar);
  }

  @override
  bool shouldRebuild(covariant SliverPersistentHeaderDelegate oldDelegate) {
    return false;
  }
}

// lib/screens/community/add_review_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/community_models.dart';
import '../../models/user_model.dart';
import '../../services/community_service.dart';

class AddReviewScreen extends StatefulWidget {
  final ProfessionalContact contact;
  final AppUser currentUser;

  const AddReviewScreen({
    Key? key,
    required this.contact,
    required this.currentUser,
  }) : super(key: key);

  @override
  _AddReviewScreenState createState() => _AddReviewScreenState();
}

class _AddReviewScreenState extends State<AddReviewScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _reviewController = TextEditingController();
  final TextEditingController _projectTypeController = TextEditingController();

  double _rating = 5.0;
  List<String> _selectedTags = [];
  bool _isLoading = false;

  final List<String> _predefinedTags = [
    'Professional',
    'Punctual',
    'Skilled',
    'Reliable',
    'Responsive',
    'Quality Work',
    'Good Communication',
    'Cost Effective',
    'Emergency Support',
    'Technical Expert',
    'Government Approved',
    'Experienced',
  ];

  final List<String> _projectTypes = [
    'Maintenance Work',
    'Installation',
    'Repair Service',
    'Emergency Service',
    'Consultation',
    'Testing & Commissioning',
    'Upgrade Work',
    'Training',
    'Supply',
    'Other',
  ];

  @override
  void dispose() {
    _reviewController.dispose();
    _projectTypeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFFAFAFA),
      appBar: AppBar(
        title: Text(
          'Write Review',
          style: TextStyle(fontWeight: FontWeight.w600, color: Colors.black87),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.black87),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _submitReview,
            child: Text(
              'Submit',
              style: TextStyle(
                color: _isLoading
                    ? Colors.grey
                    : Theme.of(context).primaryColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Contact Information Card
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 30,
                        backgroundColor: _getContactTypeColor(
                          widget.contact.contactType,
                        ).withOpacity(0.1),
                        child: Text(
                          widget.contact.name.isNotEmpty
                              ? widget.contact.name[0].toUpperCase()
                              : 'U',
                          style: TextStyle(
                            color: _getContactTypeColor(
                              widget.contact.contactType,
                            ),
                            fontWeight: FontWeight.bold,
                            fontSize: 20,
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
                                    widget.contact.name,
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.black87,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (widget.contact.isVerified) ...[
                                  SizedBox(width: 8),
                                  Icon(
                                    Icons.verified,
                                    color: Colors.green,
                                    size: 18,
                                  ),
                                ],
                              ],
                            ),
                            Text(
                              '${widget.contact.designation} - ${widget.contact.department}',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 14,
                              ),
                            ),
                            Container(
                              margin: EdgeInsets.only(top: 4),
                              padding: EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: _getContactTypeColor(
                                  widget.contact.contactType,
                                ).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                _getContactTypeLabel(
                                  widget.contact.contactType,
                                ),
                                style: TextStyle(
                                  color: _getContactTypeColor(
                                    widget.contact.contactType,
                                  ),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              SizedBox(height: 20),

              // Rating Section
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.star_rate, color: Colors.amber),
                          SizedBox(width: 8),
                          Text(
                            'Rating',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 20),
                      Center(
                        child: Column(
                          children: [
                            Text(
                              _rating.toStringAsFixed(1),
                              style: TextStyle(
                                fontSize: 48,
                                fontWeight: FontWeight.bold,
                                color: Colors.amber[700],
                              ),
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: List.generate(5, (index) {
                                return GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      _rating = index + 1.0;
                                    });
                                  },
                                  child: Container(
                                    padding: EdgeInsets.all(4),
                                    child: Icon(
                                      index < _rating
                                          ? Icons.star
                                          : Icons.star_border,
                                      color: Colors.amber,
                                      size: 32,
                                    ),
                                  ),
                                );
                              }),
                            ),
                            SizedBox(height: 8),
                            Text(
                              _getRatingText(_rating),
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: Colors.grey[700],
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 20),
                      Slider(
                        value: _rating,
                        min: 1.0,
                        max: 5.0,
                        divisions: 8, // 0.5 increments
                        onChanged: (value) {
                          setState(() {
                            _rating = value;
                          });
                        },
                        activeColor: Colors.amber,
                        inactiveColor: Colors.amber.withOpacity(0.3),
                      ),
                    ],
                  ),
                ),
              ),

              SizedBox(height: 20),

              // Project Type Section
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.work,
                            color: Theme.of(context).primaryColor,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Project Type',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        decoration: InputDecoration(
                          labelText: 'Select Project Type',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: Colors.grey[300]!),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(
                              color: Theme.of(context).primaryColor,
                            ),
                          ),
                        ),
                        items: _projectTypes.map((type) {
                          return DropdownMenuItem(
                            value: type,
                            child: Text(type),
                          );
                        }).toList(),
                        onChanged: (value) {
                          _projectTypeController.text = value!;
                        },
                        validator: (value) => value?.isEmpty == true
                            ? 'Please select project type'
                            : null,
                      ),
                      if (_projectTypeController.text == 'Other') ...[
                        SizedBox(height: 16),
                        TextFormField(
                          controller: _projectTypeController,
                          decoration: InputDecoration(
                            labelText: 'Specify Project Type',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          validator: (value) => value?.isEmpty == true
                              ? 'Please specify project type'
                              : null,
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              SizedBox(height: 20),

              // Tags Section
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.label,
                            color: Theme.of(context).primaryColor,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Tags',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Select tags that describe this contact (optional)',
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                      SizedBox(height: 16),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _predefinedTags.map((tag) {
                          return FilterChip(
                            label: Text(tag),
                            selected: _selectedTags.contains(tag),
                            onSelected: (selected) {
                              setState(() {
                                if (selected) {
                                  _selectedTags.add(tag);
                                } else {
                                  _selectedTags.remove(tag);
                                }
                              });
                            },
                            backgroundColor: Colors.grey[200],
                            selectedColor: Theme.of(context).primaryColor,
                            labelStyle: TextStyle(
                              color: _selectedTags.contains(tag)
                                  ? Colors.white
                                  : Colors.black87,
                              fontSize: 12,
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              ),

              SizedBox(height: 20),

              // Review Text Section
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.rate_review,
                            color: Theme.of(context).primaryColor,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Review',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Share your experience with this professional (optional)',
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                      SizedBox(height: 16),
                      TextFormField(
                        controller: _reviewController,
                        decoration: InputDecoration(
                          hintText: 'Write your review here...',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: Colors.grey[300]!),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(
                              color: Theme.of(context).primaryColor,
                            ),
                          ),
                          alignLabelWithHint: true,
                        ),
                        maxLines: 5,
                        textInputAction: TextInputAction.newline,
                      ),
                      SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          '${_reviewController.text.length}/500',
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              SizedBox(height: 100), // Space for bottom button
            ],
          ),
        ),
      ),
      bottomNavigationBar: Container(
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
              child: OutlinedButton(
                onPressed: _isLoading ? null : () => Navigator.pop(context),
                child: Text('Cancel'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.grey[600],
                  side: BorderSide(color: Colors.grey[300]!),
                  padding: EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            SizedBox(width: 16),
            Expanded(
              flex: 2,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _submitReview,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: 12),
                ),
                child: _isLoading
                    ? SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : Text('Submit Review'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getRatingText(double rating) {
    if (rating >= 4.5) return 'Excellent';
    if (rating >= 4.0) return 'Very Good';
    if (rating >= 3.0) return 'Good';
    if (rating >= 2.0) return 'Fair';
    return 'Poor';
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

  Future<void> _submitReview() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_projectTypeController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please select a project type'),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final review = ContactReview(
        contactId: widget.contact.id!,
        reviewerId: widget.currentUser.uid!,
        reviewerName: widget.currentUser.email,
        rating: _rating,
        review: _reviewController.text.trim().isEmpty
            ? null
            : _reviewController.text.trim(),
        projectType: _projectTypeController.text.trim(),
        createdAt: Timestamp.now(),
        tags: _selectedTags,
      );

      await CommunityService.addContactReview(review);

      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Review submitted successfully'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );

      Navigator.pop(context);
    } catch (e) {
      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to submit review: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}

// lib/screens/community/blog_article_screen.dart

import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/community_models.dart';
import '../../models/user_model.dart';
import '../../services/community_service.dart';

class BlogArticleScreen extends StatefulWidget {
  final AppUser currentUser;
  final KnowledgePost? existingPost; // For editing

  const BlogArticleScreen({
    Key? key,
    required this.currentUser,
    this.existingPost,
  }) : super(key: key);

  @override
  _BlogArticleScreenState createState() => _BlogArticleScreenState();
}

class _BlogArticleScreenState extends State<BlogArticleScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();
  final TextEditingController _summaryController = TextEditingController();
  final TextEditingController _tagController = TextEditingController();

  String _selectedCategory = 'technical';
  PostVisibility _selectedVisibility = PostVisibility.public;
  List<String> _tags = [];
  List<PostAttachment> _attachments = [];
  bool _isLoading = false;
  bool _allowComments = true;
  int _priority = 2;

  // File upload constraints
  static const int maxFileSize = 1024 * 1024; // 1MB
  static const List<String> allowedExtensions = [
    'xlsx',
    'xls',
    'docx',
    'doc',
    'pdf',
  ];

  final List<String> _categories = [
    'technical',
    'safety',
    'maintenance',
    'news',
    'training',
    'policy',
    'general',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.existingPost != null) {
      _initializeForEditing();
    }
  }

  void _initializeForEditing() {
    final post = widget.existingPost!;
    _titleController.text = post.title;
    _contentController.text = post.content;
    _summaryController.text = post.summary;
    _selectedCategory = post.category;
    _selectedVisibility = post.visibility;
    _tags = List.from(post.tags);
    _attachments = List.from(post.attachments);
    _allowComments = post.allowComments;
    _priority = post.priority;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _summaryController.dispose();
    _tagController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFFAFAFA),
      appBar: AppBar(
        title: Text(
          widget.existingPost != null ? 'Edit Article' : 'Create Article',
          style: TextStyle(fontWeight: FontWeight.w600, color: Colors.black87),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.black87),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : () => _saveArticle(PostStatus.draft),
            child: Text(
              'Save Draft',
              style: TextStyle(
                color: _isLoading ? Colors.grey : Colors.orange,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          TextButton(
            onPressed: _isLoading
                ? null
                : () => _saveArticle(PostStatus.pending),
            child: Text(
              'Publish',
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
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: SingleChildScrollView(
                padding: EdgeInsets.all(16),
                child: Column(
                  children: [
                    // Basic Information Card
                    _buildSectionCard(
                      title: 'Article Information',
                      icon: Icons.article,
                      children: [
                        _buildTextField(
                          controller: _titleController,
                          label: 'Title *',
                          hintText: 'Enter article title...',
                          validator: (value) => value?.trim().isEmpty == true
                              ? 'Title is required'
                              : null,
                        ),
                        SizedBox(height: 16),
                        _buildTextField(
                          controller: _summaryController,
                          label: 'Summary *',
                          hintText: 'Brief description of the article...',
                          maxLines: 2,
                          validator: (value) => value?.trim().isEmpty == true
                              ? 'Summary is required'
                              : null,
                        ),
                        SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: _buildDropdownField(
                                label: 'Category *',
                                value: _selectedCategory,
                                items: _categories.map((category) {
                                  return DropdownMenuItem(
                                    value: category,
                                    child: Text(
                                      _getCategoryDisplayName(category),
                                    ),
                                  );
                                }).toList(),
                                onChanged: (value) {
                                  setState(() {
                                    _selectedCategory = value!;
                                  });
                                },
                              ),
                            ),
                            SizedBox(width: 16),
                            Expanded(
                              child: _buildDropdownField(
                                label: 'Visibility *',
                                value: _selectedVisibility,
                                items: PostVisibility.values.map((visibility) {
                                  return DropdownMenuItem(
                                    value: visibility,
                                    child: Text(
                                      _getVisibilityDisplayName(visibility),
                                    ),
                                  );
                                }).toList(),
                                onChanged: (value) {
                                  setState(() {
                                    _selectedVisibility = value!;
                                  });
                                },
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),

                    SizedBox(height: 16),

                    // Content Card
                    _buildSectionCard(
                      title: 'Content',
                      icon: Icons.edit_note,
                      children: [
                        _buildTextField(
                          controller: _contentController,
                          label: 'Article Content *',
                          hintText: 'Write your article content here...',
                          maxLines: 15,
                          validator: (value) => value?.trim().isEmpty == true
                              ? 'Content is required'
                              : null,
                        ),
                      ],
                    ),

                    SizedBox(height: 16),

                    // Tags Card
                    _buildSectionCard(
                      title: 'Tags',
                      icon: Icons.local_offer,
                      children: [_buildTagInputField()],
                    ),

                    SizedBox(height: 16),

                    // Attachments Card
                    _buildSectionCard(
                      title: 'Attachments',
                      icon: Icons.attach_file,
                      children: [_buildAttachmentsSection()],
                    ),

                    SizedBox(height: 16),

                    // Settings Card
                    _buildSectionCard(
                      title: 'Settings',
                      icon: Icons.settings,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: _buildDropdownField(
                                label: 'Priority',
                                value: _priority,
                                items: [
                                  DropdownMenuItem(
                                    value: 1,
                                    child: Text('Low'),
                                  ),
                                  DropdownMenuItem(
                                    value: 2,
                                    child: Text('Medium'),
                                  ),
                                  DropdownMenuItem(
                                    value: 3,
                                    child: Text('High'),
                                  ),
                                  DropdownMenuItem(
                                    value: 4,
                                    child: Text('Critical'),
                                  ),
                                ],
                                onChanged: (value) {
                                  setState(() {
                                    _priority = value!;
                                  });
                                },
                              ),
                            ),
                            SizedBox(width: 16),
                            Expanded(
                              child: Container(
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey[300]!),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: SwitchListTile(
                                  title: Text('Allow Comments'),
                                  value: _allowComments,
                                  onChanged: (value) {
                                    setState(() {
                                      _allowComments = value;
                                    });
                                  },
                                  activeColor: Theme.of(context).primaryColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),

                    SizedBox(height: 80), // Space for bottom action bar
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
              child: ElevatedButton(
                onPressed: _isLoading
                    ? null
                    : () => _saveArticle(PostStatus.draft),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: 12),
                ),
                child: Text('Save Draft'),
              ),
            ),
            SizedBox(width: 16),
            Expanded(
              child: ElevatedButton(
                onPressed: _isLoading
                    ? null
                    : () => _saveArticle(PostStatus.pending),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: 12),
                ),
                child: Text('Publish'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionCard({
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

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    String? hintText,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        hintText: hintText,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Theme.of(context).primaryColor),
        ),
      ),
    );
  }

  Widget _buildDropdownField<T>({
    required String label,
    required T value,
    required List<DropdownMenuItem<T>> items,
    required void Function(T?) onChanged,
  }) {
    return DropdownButtonFormField<T>(
      value: value,
      items: items,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Theme.of(context).primaryColor),
        ),
      ),
    );
  }

  Widget _buildTagInputField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _tagController,
                decoration: InputDecoration(
                  labelText: 'Add Tag',
                  hintText: 'Enter tag and press add...',
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
                onSubmitted: _addTag,
              ),
            ),
            SizedBox(width: 8),
            IconButton(
              onPressed: () => _addTag(_tagController.text),
              icon: Icon(Icons.add_circle),
              color: Theme.of(context).primaryColor,
            ),
          ],
        ),
        if (_tags.isNotEmpty) ...[
          SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _tags.map((tag) {
              return Chip(
                label: Text(tag),
                deleteIcon: Icon(Icons.close, size: 18),
                onDeleted: () => _removeTag(tag),
                backgroundColor: Theme.of(
                  context,
                ).primaryColor.withOpacity(0.1),
                labelStyle: TextStyle(color: Theme.of(context).primaryColor),
              );
            }).toList(),
          ),
        ],
      ],
    );
  }

  Widget _buildAttachmentsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Supported formats: ${allowedExtensions.join(', ').toUpperCase()} (Max 1MB each)',
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
        SizedBox(height: 12),
        ElevatedButton.icon(
          onPressed: _pickFiles,
          icon: Icon(Icons.upload_file),
          label: Text('Upload Files'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).primaryColor,
            foregroundColor: Colors.white,
          ),
        ),
        if (_attachments.isNotEmpty) ...[
          SizedBox(height: 16),
          ...(_attachments
              .map((attachment) => _buildAttachmentTile(attachment))
              .toList()),
        ],
      ],
    );
  }

  Widget _buildAttachmentTile(PostAttachment attachment) {
    return Card(
      margin: EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(_getFileIcon(attachment.fileType)),
        title: Text(attachment.fileName),
        subtitle: Text(_formatFileSize(attachment.fileSizeBytes)),
        trailing: IconButton(
          icon: Icon(Icons.delete, color: Colors.red),
          onPressed: () => _removeAttachment(attachment),
        ),
      ),
    );
  }

  void _addTag(String tag) {
    final trimmedTag = tag.trim();
    if (trimmedTag.isNotEmpty && !_tags.contains(trimmedTag)) {
      setState(() {
        _tags.add(trimmedTag);
        _tagController.clear();
      });
    }
  }

  void _removeTag(String tag) {
    setState(() {
      _tags.remove(tag);
    });
  }

  Future<void> _pickFiles() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: allowedExtensions,
        allowMultiple: true,
      );

      if (result != null) {
        for (PlatformFile file in result.files) {
          // Check file size
          if (file.size > maxFileSize) {
            _showErrorSnackBar(
              'File ${file.name} is too large. Max size is 1MB.',
            );
            continue;
          }

          // Check if already added
          if (_attachments.any((att) => att.fileName == file.name)) {
            _showErrorSnackBar('File ${file.name} is already added.');
            continue;
          }

          // Add to attachments (we'll upload when saving)
          setState(() {
            _attachments.add(
              PostAttachment(
                fileName: file.name,
                fileUrl: '', // Will be set after upload
                fileType: _getFileType(file.extension ?? ''),
                fileSizeBytes: file.size,
                uploadedAt: Timestamp.now(),
                description: null,
              ),
            );
          });
        }
      }
    } catch (e) {
      _showErrorSnackBar('Error picking files: $e');
    }
  }

  void _removeAttachment(PostAttachment attachment) {
    setState(() {
      _attachments.remove(attachment);
    });
  }

  Future<void> _saveArticle(PostStatus status) async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Upload attachments if any
      List<PostAttachment> uploadedAttachments = [];
      if (_attachments.isNotEmpty) {
        uploadedAttachments = await CommunityService.uploadPostAttachments(
          _attachments
              .map(
                (att) => PlatformFile(
                  name: att.fileName,
                  size: att.fileSizeBytes,
                  bytes: Uint8List(
                    0,
                  ), // This would need to be the actual file bytes
                ),
              )
              .toList(),
        );
      }

      final post = KnowledgePost(
        id: widget.existingPost?.id,
        title: _titleController.text.trim(),
        content: _contentController.text.trim(),
        summary: _summaryController.text.trim(),
        authorId: widget.currentUser.uid,
        authorName: widget.currentUser.name,
        authorDesignation: widget.currentUser.designationDisplayName,
        category: _selectedCategory,
        tags: _tags,
        attachments: uploadedAttachments,
        status: status,
        visibility: _selectedVisibility,
        allowComments: _allowComments,
        priority: _priority,
        createdAt: widget.existingPost?.createdAt ?? Timestamp.now(),
        metrics: widget.existingPost?.metrics ?? PostMetrics(),
      );

      if (widget.existingPost != null) {
        await CommunityService.updateKnowledgePost(
          widget.existingPost!.id!,
          post,
        );
        _showSuccessSnackBar('Article updated successfully');
      } else {
        await CommunityService.createKnowledgePost(post);
        _showSuccessSnackBar(
          'Article ${status == PostStatus.draft ? 'saved as draft' : 'submitted for approval'}',
        );
      }

      Navigator.pop(context);
    } catch (e) {
      _showErrorSnackBar('Failed to save article: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  String _getCategoryDisplayName(String category) {
    switch (category) {
      case 'technical':
        return 'Technical';
      case 'safety':
        return 'Safety';
      case 'maintenance':
        return 'Maintenance';
      case 'news':
        return 'News & Updates';
      case 'training':
        return 'Training';
      case 'policy':
        return 'Policy';
      case 'general':
        return 'General';
      default:
        return category;
    }
  }

  String _getVisibilityDisplayName(PostVisibility visibility) {
    switch (visibility) {
      case PostVisibility.public:
        return 'Public';
      case PostVisibility.department:
        return 'Department Only';
      case PostVisibility.circle:
        return 'Circle Only';
      case PostVisibility.zone:
        return 'Zone Only';
      case PostVisibility.private:
        return 'Private';
    }
  }

  String _getFileType(String extension) {
    switch (extension.toLowerCase()) {
      case 'xlsx':
      case 'xls':
        return 'excel';
      case 'docx':
      case 'doc':
        return 'doc';
      case 'pdf':
        return 'pdf';
      default:
        return 'other';
    }
  }

  IconData _getFileIcon(String fileType) {
    switch (fileType.toLowerCase()) {
      case 'excel':
        return Icons.table_chart;
      case 'doc':
        return Icons.description;
      case 'pdf':
        return Icons.picture_as_pdf;
      default:
        return Icons.attach_file;
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) {
      return '${bytes} B';
    } else if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    } else {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
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

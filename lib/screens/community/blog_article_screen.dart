import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/community_models.dart';
import '../../models/user_model.dart';
import '../../services/community_service.dart';

// Modern theme constants (matching the list screen)
class MediumTheme {
  static const Color primaryText = Color(0xFF1A1A1A);
  static const Color secondaryText = Color(0xFF6B6B6B);
  static const Color lightGray = Color(0xFFF5F5F5);
  static const Color mediumGray = Color(0xFFE8E8E8);
  static const Color accent = Color(0xFF2E7D32);
  static const Color background = Color(0xFFFFFFFF);
  static const Color cardBackground = Color(0xFFFFFFFF);
}

class BlogArticleScreen extends StatefulWidget {
  final AppUser currentUser;
  final KnowledgePost? existingPost;

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

  static const int maxFileSize = 1024 * 1024;
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
      backgroundColor: MediumTheme.background,
      appBar: _buildAppBar(),
      body: _isLoading
          ? _buildLoadingState()
          : Form(
              key: _formKey,
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(),
                    SizedBox(height: 40),
                    _buildTitleSection(),
                    SizedBox(height: 32),
                    _buildSummarySection(),
                    SizedBox(height: 32),
                    _buildCategorySection(),
                    SizedBox(height: 40),
                    _buildContentSection(),
                    SizedBox(height: 40),
                    _buildTagsSection(),
                    SizedBox(height: 40),
                    _buildAttachmentsSection(),
                    SizedBox(height: 40),
                    _buildSettingsSection(),
                    SizedBox(height: 120),
                  ],
                ),
              ),
            ),
      floatingActionButton: _buildFloatingActions(),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: MediumTheme.background,
      elevation: 0,
      surfaceTintColor: MediumTheme.background,
      leading: IconButton(
        icon: Icon(
          Icons.close_outlined,
          color: MediumTheme.primaryText,
          size: 24,
        ),
        onPressed: () => Navigator.pop(context),
      ),
      title: Text(
        widget.existingPost != null ? 'Edit Story' : 'New Story',
        style: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w600,
          color: MediumTheme.primaryText,
          letterSpacing: -0.5,
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => _saveArticle(PostStatus.draft),
          child: Text(
            'Save Draft',
            style: TextStyle(
              color: _isLoading
                  ? MediumTheme.secondaryText
                  : MediumTheme.accent,
              fontWeight: FontWeight.w600,
              fontSize: 16,
            ),
          ),
        ),
        SizedBox(width: 16),
      ],
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: MediumTheme.accent, strokeWidth: 3),
          SizedBox(height: 24),
          Text(
            'Saving your story...',
            style: TextStyle(
              color: MediumTheme.secondaryText,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        CircleAvatar(
          radius: 24,
          backgroundColor: MediumTheme.lightGray,
          child: Text(
            widget.currentUser.name.isNotEmpty
                ? widget.currentUser.name[0].toUpperCase()
                : 'U',
            style: TextStyle(
              color: MediumTheme.primaryText,
              fontWeight: FontWeight.w600,
              fontSize: 18,
            ),
          ),
        ),
        SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.currentUser.name,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: MediumTheme.primaryText,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Draft in ${_getCategoryDisplayName(_selectedCategory)}',
                style: TextStyle(
                  fontSize: 14,
                  color: MediumTheme.secondaryText,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTitleSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: _titleController,
          validator: (value) =>
              value?.trim().isEmpty == true ? 'Title is required' : null,
          style: TextStyle(
            fontSize: 36,
            fontWeight: FontWeight.w700,
            color: MediumTheme.primaryText,
            height: 1.2,
            letterSpacing: -1,
          ),
          decoration: InputDecoration(
            hintText: 'Your story title...',
            hintStyle: TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.w700,
              color: MediumTheme.secondaryText.withOpacity(0.4),
              height: 1.2,
              letterSpacing: -1,
            ),
            border: InputBorder.none,
            contentPadding: EdgeInsets.zero,
          ),
          maxLines: null,
        ),
      ],
    );
  }

  Widget _buildSummarySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Summary',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: MediumTheme.primaryText,
          ),
        ),
        SizedBox(height: 12),
        TextFormField(
          controller: _summaryController,
          validator: (value) =>
              value?.trim().isEmpty == true ? 'Summary is required' : null,
          style: TextStyle(
            fontSize: 16,
            color: MediumTheme.primaryText,
            height: 1.6,
            letterSpacing: -0.2,
          ),
          decoration: InputDecoration(
            hintText: 'A brief summary of your story...',
            hintStyle: TextStyle(
              fontSize: 16,
              color: MediumTheme.secondaryText.withOpacity(0.6),
              height: 1.6,
              letterSpacing: -0.2,
            ),
            border: InputBorder.none,
            contentPadding: EdgeInsets.symmetric(vertical: 12),
          ),
          maxLines: 4,
        ),
      ],
    );
  }

  Widget _buildCategorySection() {
    return Container(
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: MediumTheme.cardBackground,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Category',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: MediumTheme.primaryText,
            ),
          ),
          SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: _categories.map((category) {
              final isSelected = _selectedCategory == category;
              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedCategory = category;
                  });
                },
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? MediumTheme.accent
                        : MediumTheme.lightGray,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: isSelected
                          ? MediumTheme.accent
                          : MediumTheme.mediumGray,
                      width: 1.5,
                    ),
                  ),
                  child: Text(
                    _getCategoryDisplayName(category),
                    style: TextStyle(
                      color: isSelected
                          ? Colors.white
                          : MediumTheme.primaryText,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildContentSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Your Story',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: MediumTheme.primaryText,
          ),
        ),
        SizedBox(height: 16),
        TextFormField(
          controller: _contentController,
          validator: (value) =>
              value?.trim().isEmpty == true ? 'Content is required' : null,
          style: TextStyle(
            fontSize: 16,
            color: MediumTheme.primaryText,
            height: 1.7,
            letterSpacing: -0.2,
          ),
          decoration: InputDecoration(
            hintText: 'Write your story here...',
            hintStyle: TextStyle(
              fontSize: 16,
              color: MediumTheme.secondaryText.withOpacity(0.6),
              height: 1.7,
              letterSpacing: -0.2,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: MediumTheme.lightGray, width: 1.5),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: MediumTheme.lightGray, width: 1.5),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: MediumTheme.accent, width: 2),
            ),
            contentPadding: EdgeInsets.all(24),
            filled: true,
            fillColor: MediumTheme.cardBackground,
          ),
          maxLines: 16,
          minLines: 10,
        ),
      ],
    );
  }

  Widget _buildTagsSection() {
    return Container(
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: MediumTheme.cardBackground,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.local_offer_outlined,
                color: MediumTheme.accent,
                size: 22,
              ),
              SizedBox(width: 12),
              Text(
                'Tags',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: MediumTheme.primaryText,
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _tagController,
                  style: TextStyle(
                    color: MediumTheme.primaryText,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Add a tag...',
                    hintStyle: TextStyle(
                      color: MediumTheme.secondaryText.withOpacity(0.6),
                      fontSize: 15,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: MediumTheme.lightGray,
                        width: 1.5,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: MediumTheme.lightGray,
                        width: 1.5,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: MediumTheme.accent,
                        width: 2,
                      ),
                    ),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                  onSubmitted: _addTag,
                ),
              ),
              SizedBox(width: 16),
              Container(
                height: 48,
                width: 48,
                decoration: BoxDecoration(
                  color: MediumTheme.accent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: IconButton(
                  onPressed: () => _addTag(_tagController.text),
                  icon: Icon(Icons.add, color: Colors.white, size: 24),
                ),
              ),
            ],
          ),
          if (_tags.isNotEmpty) ...[
            SizedBox(height: 20),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: _tags.map((tag) {
                return Container(
                  padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: MediumTheme.accent.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: MediumTheme.accent.withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        tag,
                        style: TextStyle(
                          color: MediumTheme.accent,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      SizedBox(width: 8),
                      GestureDetector(
                        onTap: () => _removeTag(tag),
                        child: Icon(
                          Icons.close,
                          size: 18,
                          color: MediumTheme.accent,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAttachmentsSection() {
    return Container(
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: MediumTheme.cardBackground,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.attach_file_outlined,
                color: MediumTheme.accent,
                size: 22,
              ),
              SizedBox(width: 12),
              Text(
                'Attachments',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: MediumTheme.primaryText,
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          Text(
            'Supported: ${allowedExtensions.join(', ').toUpperCase()} (Max 1MB each)',
            style: TextStyle(
              fontSize: 14,
              color: MediumTheme.secondaryText,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 20),
          InkWell(
            onTap: _pickFiles,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: double.infinity,
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                border: Border.all(
                  color: MediumTheme.lightGray,
                  style: BorderStyle.solid,
                  width: 1.5,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.cloud_upload_outlined,
                    size: 40,
                    color: MediumTheme.accent,
                  ),
                  SizedBox(height: 12),
                  Text(
                    'Upload Files',
                    style: TextStyle(
                      color: MediumTheme.primaryText,
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_attachments.isNotEmpty) ...[
            SizedBox(height: 20),
            ..._attachments.map(
              (attachment) => _buildAttachmentTile(attachment),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAttachmentTile(PostAttachment attachment) {
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: MediumTheme.lightGray,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            _getFileIcon(attachment.fileType),
            color: MediumTheme.accent,
            size: 24,
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  attachment.fileName,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: MediumTheme.primaryText,
                    fontSize: 15,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  _formatFileSize(attachment.fileSizeBytes),
                  style: TextStyle(
                    fontSize: 13,
                    color: MediumTheme.secondaryText,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => _removeAttachment(attachment),
            icon: Icon(Icons.delete_outline, color: Colors.red[400], size: 24),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsSection() {
    return Container(
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: MediumTheme.cardBackground,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.settings_outlined,
                color: MediumTheme.accent,
                size: 22,
              ),
              SizedBox(width: 12),
              Text(
                'Publishing Settings',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: MediumTheme.primaryText,
                ),
              ),
            ],
          ),
          SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Priority Level',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: MediumTheme.primaryText,
                        fontSize: 15,
                      ),
                    ),
                    SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: MediumTheme.lightGray,
                          width: 1.5,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: DropdownButton<int>(
                        value: _priority,
                        isExpanded: true,
                        underline: SizedBox(),
                        style: TextStyle(
                          color: MediumTheme.primaryText,
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                        items: [
                          DropdownMenuItem(value: 1, child: Text('Low')),
                          DropdownMenuItem(value: 2, child: Text('Medium')),
                          DropdownMenuItem(value: 3, child: Text('High')),
                          DropdownMenuItem(value: 4, child: Text('Critical')),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _priority = value!;
                          });
                        },
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 24),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Allow Comments',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: MediumTheme.primaryText,
                      fontSize: 15,
                    ),
                  ),
                  SizedBox(height: 12),
                  Switch(
                    value: _allowComments,
                    onChanged: (value) {
                      setState(() {
                        _allowComments = value;
                      });
                    },
                    activeColor: MediumTheme.accent,
                    trackOutlineColor: MaterialStateProperty.all(
                      MediumTheme.lightGray,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFloatingActions() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 56,
              child: OutlinedButton(
                onPressed: _isLoading ? null : () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: MediumTheme.mediumGray, width: 1.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  foregroundColor: MediumTheme.primaryText,
                ),
                child: Text(
                  'Cancel',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                ),
              ),
            ),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Container(
              height: 56,
              child: ElevatedButton(
                onPressed: _isLoading
                    ? null
                    : () => _saveArticle(PostStatus.pending),
                style: ElevatedButton.styleFrom(
                  backgroundColor: MediumTheme.accent,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.publish_outlined, size: 22),
                    SizedBox(width: 8),
                    Text(
                      'Publish',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Helper Methods (unchanged)
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
          if (file.size > maxFileSize) {
            _showErrorSnackBar(
              'File ${file.name} is too large. Max size is 1MB.',
            );
            continue;
          }

          if (_attachments.any((att) => att.fileName == file.name)) {
            _showErrorSnackBar('File ${file.name} is already added.');
            continue;
          }

          setState(() {
            _attachments.add(
              PostAttachment(
                fileName: file.name,
                fileUrl: '',
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
      List<PostAttachment> uploadedAttachments = [];
      if (_attachments.isNotEmpty) {
        uploadedAttachments = await CommunityService.uploadPostAttachments(
          _attachments
              .map(
                (att) => PlatformFile(
                  name: att.fileName,
                  size: att.fileSizeBytes,
                  bytes: Uint8List(0),
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
        _showSuccessSnackBar('Story updated successfully');
      } else {
        await CommunityService.createKnowledgePost(post);
        _showSuccessSnackBar(
          'Story ${status == PostStatus.draft ? 'saved as draft' : 'submitted for review'}',
        );
      }

      Navigator.pop(context);
    } catch (e) {
      _showErrorSnackBar('Failed to save story: $e');
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
        return Icons.table_chart_outlined;
      case 'doc':
        return Icons.description_outlined;
      case 'pdf':
        return Icons.picture_as_pdf_outlined;
      default:
        return Icons.attach_file_outlined;
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024)
      return '${bytes} B';
    else if (bytes < 1024 * 1024)
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    else
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: MediumTheme.accent,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: EdgeInsets.all(16),
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red[400],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: EdgeInsets.all(16),
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }
}

// lib/screens/post_create_screen.dart
import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:collection/collection.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:graphite/graphite.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/hierarchy_models.dart';
import '../../models/power_pulse/powerpulse_models.dart';
import '../../services/power_pulse_service/powerpulse_services.dart';
import 'flowchart_create_screen.dart';

class PostCreateScreen extends StatefulWidget {
  final Post? editingPost;
  const PostCreateScreen({Key? key, this.editingPost}) : super(key: key);

  @override
  State<PostCreateScreen> createState() => _PostCreateScreenState();
}

class _PostCreateScreenState extends State<PostCreateScreen> {
  late TextEditingController _titleController;
  late TextEditingController _summaryController;

  final List<ContentBlock> _contentBlocks = [];

  final FocusNode _titleFocusNode = FocusNode();
  final FocusNode _summaryFocusNode = FocusNode();

  bool _isLoading = false;
  bool _isPreviewMode = false;

  PostScope _selectedScope = PostScope.public();
  Zone? _selectedZone;
  Flair? _selectedFlair;
  List<Zone> _zones = [];
  String? _existingImageUrl;

  final List<Flair> _availableFlairs = [
    Flair(name: 'Urgent', emoji: '🚨'),
    Flair(name: 'Question', emoji: '❓'),
    Flair(name: 'Announcement', emoji: '📢'),
    Flair(name: 'Discussion', emoji: '💬'),
  ];

  // ──────────────────────────────────────────────────────────────────────────────
  // Lifecycle
  // ──────────────────────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _initControllers();
    _loadZones();
    _loadDraft();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _summaryController.dispose();
    for (final block in _contentBlocks) {
      block.dispose();
    }
    _titleFocusNode.dispose();
    _summaryFocusNode.dispose();
    super.dispose();
  }

  // ──────────────────────────────────────────────────────────────────────────────
  // Initialisation helpers
  // ──────────────────────────────────────────────────────────────────────────────
  void _initControllers() {
    if (widget.editingPost != null) {
      final post = widget.editingPost!;
      _titleController = TextEditingController(text: post.title);
      _summaryController = TextEditingController(text: post.bodyPlain);
      _selectedScope = post.scope;
      _selectedFlair = post.flair;
      _existingImageUrl = post.imageUrl;

      if (post.bodyDelta.startsWith('[')) {
        try {
          final json = jsonDecode(post.bodyDelta) as List<dynamic>;
          _contentBlocks.addAll(
            json.map((e) => ContentBlock.fromJson(e)).toList(),
          );
        } catch (e) {
          debugPrint('Error decoding content blocks: $e');
        }
      }
    } else {
      _titleController = TextEditingController();
      _summaryController = TextEditingController();
    }
  }

  // ──────────────────────────────────────────────────────────────────────────────
  // Draft & zone helpers
  // ──────────────────────────────────────────────────────────────────────────────
  Future<void> _loadZones() async {
    try {
      final zones = await HierarchyService.getZones();
      setState(() {
        _zones = zones;
        if (_selectedScope.isZone && _selectedScope.zoneId != null) {
          _selectedZone = zones.firstWhereOrNull(
            (z) => z.id == _selectedScope.zoneId,
          );
        }
        _selectedZone ??= zones.isNotEmpty ? zones.first : null;
      });
    } catch (e) {
      if (mounted) _showSnackBar('Failed to load zones');
    }
  }

  Future<void> _loadDraft() async {
    final prefs = await SharedPreferences.getInstance();
    final draftJson = prefs.getString('post_draft');
    if (draftJson != null && widget.editingPost == null) {
      try {
        final draft = jsonDecode(draftJson) as Map<String, dynamic>;
        setState(() {
          _titleController.text = draft['title'] ?? '';
          _summaryController.text = draft['summary'] ?? '';
          _selectedScope = PostScope.fromJson(draft['scope'] ?? {});
          _selectedFlair = draft['flair'] != null
              ? Flair.fromJson(draft['flair'])
              : null;
          _existingImageUrl = draft['imageUrl'];
          _contentBlocks.addAll(
            (draft['contentBlocks'] as List<dynamic>? ?? [])
                .map((e) => ContentBlock.fromJson(e))
                .toList(),
          );
        });
      } catch (e) {
        debugPrint('Error loading draft: $e');
      }
    }
  }

  Future<void> _saveDraft() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Create a serializable version of the draft without FieldValue instances
      final draft = {
        'title': _titleController.text,
        'summary': _summaryController.text,
        'scope': _selectedScope.toJson(),
        'flair': _selectedFlair?.toJson(),
        'imageUrl': _existingImageUrl,
        'contentBlocks': _contentBlocks.map((b) => b.toJson()).toList(),
        // Add timestamp as milliseconds instead of FieldValue
        'lastSaved': DateTime.now().millisecondsSinceEpoch,
      };

      await prefs.setString('post_draft', jsonEncode(draft));
    } catch (e) {
      debugPrint('Error saving draft: $e');
      // Don't show error to user for draft saving failures
    }
  }

  // ──────────────────────────────────────────────────────────────────────────────
  // Content-block add / remove helpers
  // ──────────────────────────────────────────────────────────────────────────────
  void _addHeading() {
    setState(() {
      _contentBlocks.add(
        ContentBlock(ContentBlockType.heading, text: 'Heading'),
      );
      _saveDraft();
    });
  }

  void _addSubHeading() {
    setState(() {
      _contentBlocks.add(
        ContentBlock(ContentBlockType.subHeading, text: 'Sub-heading'),
      );
      _saveDraft();
    });
  }

  void _addParagraph() {
    setState(() {
      _contentBlocks.add(
        ContentBlock(ContentBlockType.paragraph, text: 'Paragraph text…'),
      );
      _saveDraft();
    });
  }

  void _addBulletedList() {
    setState(() {
      _contentBlocks.add(
        ContentBlock(ContentBlockType.bulletedList, listItems: ['']),
      );
      _saveDraft();
    });
  }

  void _addNumberedList() {
    setState(() {
      _contentBlocks.add(
        ContentBlock(ContentBlockType.numberedList, listItems: ['']),
      );
      _saveDraft();
    });
  }

  void _addFlowchart() async {
    // Navigate to FlowchartCreateScreen and wait for result
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const FlowchartCreateScreen()),
    );

    // If user saved a flowchart, add it to content blocks
    if (result != null) {
      setState(() {
        _contentBlocks.add(
          ContentBlock(
            ContentBlockType.flowchart,
            flowchartData: result, // This contains the flowchart data
            text: result['title'] ?? 'Flowchart', // Use title as display text
          ),
        );
        _saveDraft();
      });
    }
  }

  void _addListItem(ContentBlock block) {
    setState(() {
      block.listItems.add('');
      block.listControllers.add(TextEditingController());
      _saveDraft();
    });
  }

  void _removeListItem(ContentBlock block, int index) {
    if (block.listItems.length > 1) {
      setState(() {
        block.listItems.removeAt(index);
        block.listControllers[index].dispose();
        block.listControllers.removeAt(index);
        _saveDraft();
      });
    }
  }

  void _addLink() {
    setState(() {
      _contentBlocks.add(
        ContentBlock(
          ContentBlockType.link,
          text: 'Link text',
          url: 'https://example.com',
        ),
      );
      _saveDraft();
    });
  }

  // ──────────────────────────────────────────────────────────────────────────────
  // Media upload helpers
  // ──────────────────────────────────────────────────────────────────────────────
  Future<void> _uploadImage() async {
    final picker = ImagePicker();
    final XFile? picked = await picker.pickImage(source: ImageSource.gallery);

    if (picked == null) return;

    final file = File(picked.path);
    final sizeInBytes = await file.length();

    if (sizeInBytes > 1 * 1024 * 1024) {
      _showSnackBar('Image must be under 1 MB');
      return;
    }
    if (![
      '.jpg',
      '.jpeg',
      '.png',
    ].contains(p.extension(file.path).toLowerCase())) {
      _showSnackBar('Only JPG or PNG images are allowed');
      return;
    }

    setState(() {
      _existingImageUrl = null;
      _contentBlocks.add(ContentBlock(ContentBlockType.image, file: file));
      _saveDraft();
    });
  }

  Future<void> _uploadFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'xls', 'xlsx', 'doc', 'docx'],
    );
    if (result == null) return;

    final picked = result.files.first;
    if (picked.size > 1 * 1024 * 1024) {
      _showSnackBar('File must be under 1 MB');
      return;
    }

    final file = File(picked.path!);
    setState(() {
      _contentBlocks.add(
        ContentBlock(ContentBlockType.file, file: file, text: picked.name),
      );
      _saveDraft();
    });
  }

  // ──────────────────────────────────────────────────────────────────────────────
  // Scaffold
  // ──────────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: _buildAppBar(),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                if (!_isPreviewMode) _buildScopeAndFlairSelector(),
                Expanded(
                  child: _isPreviewMode ? _buildPreview() : _buildEditor(),
                ),
                if (!_isPreviewMode) _buildBottomBar(),
              ],
            ),
      floatingActionButton: _isPreviewMode
          ? null
          : FloatingActionButton(
              onPressed: _showContentMenu,
              backgroundColor: Colors.black87,
              child: const Icon(Icons.add, color: Colors.white),
            ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.close, color: Colors.black87),
        onPressed: _handleBack,
      ),
      title: Text(
        widget.editingPost == null ? 'New Post' : 'Edit Post',
        style: GoogleFonts.lora(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: Colors.black87,
        ),
      ),
      actions: [
        IconButton(
          icon: Icon(
            _isPreviewMode ? Icons.edit : Icons.visibility,
            color: Colors.black87,
          ),
          onPressed: () => setState(() => _isPreviewMode = !_isPreviewMode),
        ),
        IconButton(
          icon: const Icon(Icons.save, color: Colors.black87),
          onPressed: _isLoading ? null : _savePost,
        ),
      ],
    );
  }

  // ──────────────────────────────────────────────────────────────────────────────
  // Scope & flair
  // ──────────────────────────────────────────────────────────────────────────────
  Widget _buildScopeAndFlairSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          // Scope button
          ElevatedButton.icon(
            onPressed: _zones.isNotEmpty ? _showZonePicker : null,
            icon: Icon(
              _selectedScope.isPublic ? Icons.public : Icons.location_on,
              size: 16,
            ),
            label: Text(
              _selectedScope.isPublic
                  ? 'Public'
                  : (_selectedZone?.name ?? 'Select zone'),
              style: GoogleFonts.montserrat(fontSize: 14),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: _selectedScope.isPublic
                  ? Colors.blue[50]
                  : Colors.orange[50],
              foregroundColor: _selectedScope.isPublic
                  ? Colors.blue
                  : Colors.orange,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Flair button
          ElevatedButton.icon(
            onPressed: _showFlairPicker,
            icon: Icon(
              Icons.label_outline,
              size: 16,
              color: _selectedFlair != null
                  ? _getFlairColor(_selectedFlair!)
                  : Colors.grey[600],
            ),
            label: Text(
              _selectedFlair?.name ?? 'Add flair',
              style: GoogleFonts.montserrat(
                fontSize: 14,
                color: _selectedFlair != null
                    ? _getFlairColor(_selectedFlair!)
                    : Colors.grey,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: _selectedFlair != null
                  ? _getFlairColor(_selectedFlair!).withOpacity(0.1)
                  : Colors.grey,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          if (!_selectedScope.isPublic)
            TextButton(
              onPressed: () {
                setState(() {
                  _selectedScope = PostScope.public();
                  _saveDraft();
                });
              },
              child: Text(
                'Make public',
                style: GoogleFonts.montserrat(
                  fontSize: 12,
                  color: Colors.blue[600],
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _showFlairPicker() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Select flair',
              style: GoogleFonts.lora(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 20),
            ..._availableFlairs.map(
              (flair) => ListTile(
                leading: Text(
                  flair.emoji ?? '🏷️',
                  style: const TextStyle(fontSize: 20),
                ),
                title: Text(
                  flair.name,
                  style: GoogleFonts.montserrat(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87,
                  ),
                ),
                selected: _selectedFlair?.name == flair.name,
                onTap: () {
                  setState(() {
                    _selectedFlair = flair;
                    _saveDraft();
                  });
                  Navigator.pop(context);
                },
              ),
            ),
            ListTile(
              title: Text(
                'No flair',
                style: GoogleFonts.montserrat(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: Colors.black87,
                ),
              ),
              onTap: () {
                setState(() {
                  _selectedFlair = null;
                  _saveDraft();
                });
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────────
  // Content menu
  // ──────────────────────────────────────────────────────────────────────────────
  void _showContentMenu() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.75,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Add content',
              style: GoogleFonts.lora(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    _contentOption(
                      Icons.title,
                      'Heading',
                      'Large bold title',
                      _addHeading,
                    ),
                    _contentOption(
                      Icons.subtitles,
                      'Sub-heading',
                      'Medium title',
                      _addSubHeading,
                    ),
                    _contentOption(
                      Icons.text_fields,
                      'Paragraph',
                      'Main body text',
                      _addParagraph,
                    ),
                    _contentOption(
                      Icons.format_list_bulleted,
                      'Bulleted list',
                      'List with bullets',
                      _addBulletedList,
                    ),
                    _contentOption(
                      Icons.format_list_numbered,
                      'Numbered list',
                      'List with numbers',
                      _addNumberedList,
                    ),
                    _contentOption(
                      Icons.account_tree,
                      'Flowchart',
                      'Add a flow-chart description',
                      _addFlowchart,
                    ),
                    _contentOption(
                      Icons.image,
                      'Image',
                      'Upload image (≤1 MB)',
                      _uploadImage,
                    ),
                    _contentOption(
                      Icons.link,
                      'Link',
                      'Add a web link',
                      _addLink,
                    ),
                    _contentOption(
                      Icons.attach_file,
                      'File',
                      'PDF/Word/Excel ≤1 MB',
                      _uploadFile,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  ListTile _contentOption(
    IconData icon,
    String title,
    String subtitle,
    VoidCallback onTap,
  ) {
    return ListTile(
      leading: Icon(icon, color: Colors.black54),
      title: Text(
        title,
        style: GoogleFonts.lora(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: Colors.black87,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: GoogleFonts.lora(fontSize: 13, color: Colors.black54),
      ),
      onTap: () {
        Navigator.pop(context);
        onTap();
      },
    );
  }

  // ──────────────────────────────────────────────────────────────────────────────
  // Editor view
  // ──────────────────────────────────────────────────────────────────────────────
  Widget _buildEditor() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title
          TextField(
            controller: _titleController,
            focusNode: _titleFocusNode,
            maxLines: null,
            decoration: InputDecoration(
              hintText: 'Enter your title…',
              hintStyle: GoogleFonts.lora(
                fontSize: 24,
                fontWeight: FontWeight.w500,
                color: Colors.grey[400],
              ),
              border: InputBorder.none,
            ),
            style: GoogleFonts.lora(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: Colors.black87,
            ),
            textCapitalization: TextCapitalization.sentences,
            onChanged: (_) => _saveDraft(),
          ),
          const SizedBox(height: 16),
          // Summary
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.summarize,
                      size: 16,
                      color: Colors.black54,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Summary',
                      style: GoogleFonts.lora(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${_summaryController.text.length}/200',
                      style: GoogleFonts.lora(
                        fontSize: 11,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ),
                TextField(
                  controller: _summaryController,
                  focusNode: _summaryFocusNode,
                  maxLines: 3,
                  maxLength: 200,
                  decoration: InputDecoration(
                    hintText: 'Brief summary for post previews…',
                    hintStyle: GoogleFonts.lora(
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      color: Colors.grey[400],
                    ),
                    border: InputBorder.none,
                  ),
                  style: GoogleFonts.lora(
                    fontSize: 14,
                    height: 1.5,
                    color: Colors.black87,
                  ),
                  textCapitalization: TextCapitalization.sentences,
                  onChanged: (_) => _saveDraft(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Content blocks
          _contentBlocks.isEmpty
              ? Column(
                  children: [
                    Icon(
                      Icons.article_outlined,
                      size: 60,
                      color: Colors.grey[300],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Add content using the + button',
                      style: GoogleFonts.lora(fontSize: 14, color: Colors.grey),
                    ),
                  ],
                )
              : ReorderableListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _contentBlocks.length,
                  onReorder: (oldIdx, newIdx) {
                    setState(() {
                      if (oldIdx < newIdx) newIdx -= 1;
                      final block = _contentBlocks.removeAt(oldIdx);
                      _contentBlocks.insert(newIdx, block);
                      _saveDraft();
                    });
                  },
                  itemBuilder: (context, index) {
                    final block = _contentBlocks[index];
                    return Dismissible(
                      key: ValueKey(block),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        color: Colors.red,
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 16),
                        child: const Icon(Icons.delete, color: Colors.white),
                      ),
                      confirmDismiss: (direction) async {
                        // Show confirmation dialog
                        return await _showDeleteConfirmationDialog(block);
                      },
                      onDismissed: (_) {
                        setState(() {
                          block.dispose();
                          _contentBlocks.removeAt(index);
                          _saveDraft();
                        });
                        _showSnackBar('Block removed');
                      },
                      child: _blockEditor(block),
                    );
                  },
                ),
        ],
      ),
    );
  }

  Future<bool?> _showDeleteConfirmationDialog(ContentBlock block) async {
    // Get block type name for the dialog
    String blockTypeName;
    switch (block.type) {
      case ContentBlockType.heading:
        blockTypeName = 'Heading';
        break;
      case ContentBlockType.subHeading:
        blockTypeName = 'Sub-heading';
        break;
      case ContentBlockType.paragraph:
        blockTypeName = 'Paragraph';
        break;
      case ContentBlockType.bulletedList:
        blockTypeName = 'Bulleted list';
        break;
      case ContentBlockType.numberedList:
        blockTypeName = 'Numbered list';
        break;
      case ContentBlockType.image:
        blockTypeName = 'Image';
        break;
      case ContentBlockType.link:
        blockTypeName = 'Link';
        break;
      case ContentBlockType.file:
        blockTypeName = 'File';
        break;
      case ContentBlockType.flowchart:
        blockTypeName = 'Flowchart';
        break;
    }

    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Row(
          children: [
            Icon(Icons.delete_outline, color: Colors.red[600], size: 24),
            const SizedBox(width: 8),
            Text(
              'Delete $blockTypeName?',
              style: GoogleFonts.lora(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to delete this $blockTypeName? This action cannot be undone.',
          style: GoogleFonts.lora(fontSize: 14, color: Colors.grey[700]),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              'Cancel',
              style: GoogleFonts.lora(fontSize: 14, color: Colors.grey[600]),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red[600],
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              'Delete',
              style: GoogleFonts.lora(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────────
  // Block editor widgets
  // ──────────────────────────────────────────────────────────────────────────────
  Widget _blockEditor(ContentBlock block) {
    switch (block.type) {
      case ContentBlockType.heading:
        return _headingField(block, fontSize: 20, hint: 'Enter heading…');
      case ContentBlockType.subHeading:
        return _headingField(block, fontSize: 17, hint: 'Enter sub-heading…');
      case ContentBlockType.paragraph:
        return _paragraphField(block);
      case ContentBlockType.bulletedList:
      case ContentBlockType.numberedList:
        return _listField(block);
      case ContentBlockType.image:
        return _imageField(block);
      case ContentBlockType.link:
        return _linkField(block);
      case ContentBlockType.file:
        return _fileField(block);
      case ContentBlockType.flowchart:
        return _flowchartField(block);
    }
  }

  // Individual block builders ---------------------------------------------------
  Widget _headingField(
    ContentBlock block, {
    required double fontSize,
    required String hint,
  }) {
    return _blockShell(
      TextField(
        controller: block.controller,
        decoration: InputDecoration(border: InputBorder.none, hintText: hint),
        style: GoogleFonts.lora(
          fontSize: fontSize,
          fontWeight: FontWeight.w700,
          color: Colors.black87,
        ),
        onChanged: (_) => _saveDraft(),
      ),
    );
  }

  Widget _paragraphField(ContentBlock block) {
    return _blockShell(
      TextField(
        controller: block.controller,
        maxLines: null,
        decoration: const InputDecoration(
          border: InputBorder.none,
          hintText: 'Paragraph…',
        ),
        style: GoogleFonts.lora(
          fontSize: 15,
          height: 1.5,
          color: Colors.black87,
        ),
        onChanged: (_) => _saveDraft(),
      ),
    );
  }

  Widget _listField(ContentBlock block) {
    return _blockShell(
      Column(
        children: [
          ...List.generate(block.listItems.length, (i) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 6, right: 8),
                    child: Text(
                      block.type == ContentBlockType.bulletedList
                          ? '•'
                          : '${i + 1}.',
                      style: const TextStyle(fontSize: 15),
                    ),
                  ),
                  Expanded(
                    child: TextField(
                      controller: block.listControllers[i],
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        hintText: 'List item…',
                      ),
                      style: GoogleFonts.lora(
                        fontSize: 15,
                        height: 1.5,
                        color: Colors.black87,
                      ),
                      onChanged: (_) => _saveDraft(),
                    ),
                  ),
                  if (block.listItems.length > 1)
                    IconButton(
                      icon: const Icon(
                        Icons.remove_circle_outline,
                        color: Colors.red,
                        size: 18,
                      ),
                      onPressed: () => _removeListItem(block, i),
                    ),
                ],
              ),
            );
          }),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => _addListItem(block),
              icon: const Icon(Icons.add, size: 16, color: Colors.blue),
              label: Text(
                'Add item',
                style: GoogleFonts.lora(fontSize: 12, color: Colors.blue),
              ),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _imageField(ContentBlock block) {
    final img = block.file != null
        ? Image.file(block.file!, height: 150, fit: BoxFit.cover)
        : (block.url != null
              ? Image.network(block.url!, height: 150, fit: BoxFit.cover)
              : Container(
                  height: 150,
                  color: Colors.grey[200],
                  child: const Center(child: Text('Image unavailable')),
                ));
    return _blockShell(
      Column(
        children: [
          img,
          const SizedBox(height: 6),
          Text(
            'Image',
            style: GoogleFonts.lora(fontSize: 11, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _linkField(ContentBlock block) {
    return _blockShell(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: block.controller,
            decoration: const InputDecoration(
              border: InputBorder.none,
              hintText: 'Link text…',
            ),
            style: GoogleFonts.lora(
              fontSize: 15,
              color: Colors.blue[700],
              decoration: TextDecoration.underline,
            ),
            onChanged: (_) => _saveDraft(),
          ),
          TextField(
            decoration: const InputDecoration(
              border: InputBorder.none,
              hintText: 'https://…',
            ),
            style: GoogleFonts.lora(fontSize: 13, color: Colors.grey),
            onChanged: (v) {
              block.url = v;
              _saveDraft();
            },
          ),
        ],
      ),
    );
  }

  Widget _fileField(ContentBlock block) {
    return _blockShell(
      Row(
        children: [
          const Icon(Icons.attach_file, color: Colors.black54, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  block.text,
                  style: GoogleFonts.lora(fontSize: 15, color: Colors.black87),
                ),
                Text(
                  block.file != null
                      ? p.extension(block.file!.path).toUpperCase()
                      : 'FILE',
                  style: GoogleFonts.lora(
                    fontSize: 11,
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _editFlowchart(ContentBlock block) async {
    // Navigate to FlowchartCreateScreen with existing flowchart data for editing
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            FlowchartCreateScreen(existingFlowchart: block.flowchartData),
      ),
    );

    // If user saved changes, update the content block
    if (result != null) {
      setState(() {
        block.flowchartData = result;
        block.text = result['title'] ?? 'Flowchart';
        _saveDraft();
      });
    }
  }

  Widget _flowchartField(ContentBlock block) {
    final flowchartData = block.flowchartData ?? {};
    final title = flowchartData['title'] ?? 'Untitled Flowchart';
    final description = flowchartData['description'] ?? '';
    final nodeCount = flowchartData['nodeCount'] ?? 0;

    return _blockShell(
      InkWell(
        onTap: () => _editFlowchart(block),
        child: Container(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.account_tree, color: Colors.blue, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.lora(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    if (description.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        description,
                        style: GoogleFonts.lora(
                          fontSize: 13,
                          color: Colors.grey[600],
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 4),
                    Text(
                      '$nodeCount nodes',
                      style: GoogleFonts.lora(
                        fontSize: 12,
                        color: Colors.blue[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.edit, color: Colors.grey, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _blockShell(Widget child) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
      boxShadow: [
        BoxShadow(
          color: Colors.grey.withOpacity(0.08),
          blurRadius: 4,
          offset: const Offset(0, 2),
        ),
      ],
    ),
    child: ListTile(
      title: child,
      contentPadding: const EdgeInsets.all(12),
      trailing: const Icon(Icons.drag_handle, color: Colors.grey, size: 20),
    ),
  );

  // ──────────────────────────────────────────────────────────────────────────────
  // Preview view
  // ──────────────────────────────────────────────────────────────────────────────
  Widget _buildPreview() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 80),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _titleController.text.isEmpty
                ? 'Your title…'
                : _titleController.text,
            style: GoogleFonts.lora(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          if (_selectedFlair != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: _getFlairColor(_selectedFlair!).withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: _getFlairColor(_selectedFlair!),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_selectedFlair!.emoji != null)
                    Text(
                      _selectedFlair!.emoji!,
                      style: const TextStyle(fontSize: 12),
                    ),
                  const SizedBox(width: 4),
                  Text(
                    _selectedFlair!.name,
                    style: GoogleFonts.montserrat(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: _getFlairColor(_selectedFlair!),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 20),
          if (_summaryController.text.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _summaryController.text,
                style: GoogleFonts.lora(fontSize: 15, height: 1.5),
              ),
            ),
            const SizedBox(height: 24),
          ],
          Row(
            children: [
              CircleAvatar(
                backgroundColor: Colors.blue[100],
                radius: 18,
                child: Text(
                  (AuthService.currentUser?.displayName ?? 'U').characters.first
                      .toUpperCase(),
                  style: GoogleFonts.montserrat(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.blue,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AuthService.currentUser?.displayName ?? 'You',
                    style: GoogleFonts.montserrat(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  Text(
                    'Just now • ${_getReadingTime()} min read',
                    style: GoogleFonts.montserrat(
                      fontSize: 11,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          ..._contentBlocks.map(_blockPreview),
        ],
      ),
    );
  }

  Widget _blockPreview(ContentBlock block) {
    switch (block.type) {
      case ContentBlockType.heading:
        return _pv(
          text: block.controller.text,
          size: 20,
          weight: FontWeight.w700,
        );
      case ContentBlockType.subHeading:
        return _pv(
          text: block.controller.text,
          size: 17,
          weight: FontWeight.w600,
        );
      case ContentBlockType.paragraph:
        return _pv(text: block.controller.text, size: 15);
      case ContentBlockType.bulletedList:
      case ContentBlockType.numberedList:
        final isBulleted = block.type == ContentBlockType.bulletedList;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: block.listControllers.asMap().entries.map((entry) {
              final idx = entry.key;
              final ctrl = entry.value;
              return Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isBulleted ? '• ' : '${idx + 1}. ',
                      style: const TextStyle(fontSize: 15),
                    ),
                    Expanded(
                      child: Text(
                        ctrl.text,
                        style: GoogleFonts.lora(
                          fontSize: 15,
                          height: 1.5,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        );
      case ContentBlockType.image:
        final img = block.file != null
            ? Image.file(block.file!, fit: BoxFit.cover)
            : (block.url != null
                  ? Image.network(block.url!, fit: BoxFit.cover)
                  : Container(
                      height: 150,
                      color: Colors.grey[200],
                      child: const Center(child: Text('Image unavailable')),
                    ));
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: img,
        );
      case ContentBlockType.link:
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Text(
            block.controller.text,
            style: GoogleFonts.lora(
              fontSize: 15,
              color: Colors.blue[700],
              decoration: TextDecoration.underline,
            ),
          ),
        );
      case ContentBlockType.file:
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              const Icon(Icons.attach_file, size: 18, color: Colors.black54),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      block.text,
                      style: GoogleFonts.lora(
                        fontSize: 15,
                        color: Colors.black87,
                      ),
                    ),
                    Text(
                      block.file != null
                          ? p.extension(block.file!.path).toUpperCase()
                          : 'FILE',
                      style: GoogleFonts.lora(
                        fontSize: 11,
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      case ContentBlockType.flowchart:
        final flowchartData = block.flowchartData ?? {};
        final title = flowchartData['title'] ?? 'Flowchart';
        final description = flowchartData['description'] ?? '';
        final nodeCount = flowchartData['nodeCount'] ?? 0;

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue!),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Icon(Icons.account_tree, color: Colors.blue, size: 24),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        title,
                        style: GoogleFonts.lora(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  ],
                ),

                // Description
                if (description.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    description,
                    style: GoogleFonts.lora(
                      fontSize: 14,
                      color: Colors.grey[700],
                    ),
                  ),
                ],

                const SizedBox(height: 16),

                // Actual flowchart preview
                Container(
                  height: 200,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey!),
                  ),
                  child: _buildFlowchartPreview(block.flowchartData),
                ),

                const SizedBox(height: 12),

                // Footer info
                Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      'Preview mode - Tap to edit flowchart',
                      style: GoogleFonts.lora(
                        fontSize: 12,
                        color: Colors.blue,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '$nodeCount nodes',
                      style: GoogleFonts.lora(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
    }
  }

  Widget _buildFlowchartPreview(Map<String, dynamic>? flowchartData) {
    if (flowchartData == null) {
      return Center(
        child: Text(
          'No flowchart data available',
          style: GoogleFonts.lora(fontSize: 14, color: Colors.grey),
        ),
      );
    }

    if (flowchartData['nodes'] == null) {
      return Center(
        child: Text(
          'No flowchart nodes available',
          style: GoogleFonts.lora(fontSize: 14, color: Colors.grey),
        ),
      );
    }

    try {
      final nodesList = flowchartData['nodes'] as String;
      final nodes = nodeInputFromJson(nodesList);

      if (nodes.isEmpty) {
        return Center(
          child: Text(
            'No nodes to display',
            style: GoogleFonts.lora(fontSize: 14, color: Colors.grey),
          ),
        );
      }

      return InteractiveViewer(
        minScale: 0.5,
        maxScale: 2.0,
        constrained: false,
        child: SizedBox(
          width: double.infinity,
          height: 180, // Smaller height for preview mode
          child: DirectGraph(
            list: nodes,
            defaultCellSize: const Size(100, 50),
            cellPadding: const EdgeInsets.all(16),
            orientation: MatrixOrientation.Vertical,
            centered: true,
            nodeBuilder: (context, node) => Container(
              decoration: BoxDecoration(
                color: Colors.blue[50],
                border: Border.all(color: Colors.blue!),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: Text(
                    node.id,
                    style: GoogleFonts.lora(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: Colors.blue,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    } catch (e) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error, color: Colors.red, size: 24),
            const SizedBox(height: 8),
            Text(
              'Error displaying flowchart',
              style: GoogleFonts.lora(fontSize: 14, color: Colors.red),
            ),
          ],
        ),
      );
    }
  }

  Widget _pv({
    required String text,
    required double size,
    FontWeight weight = FontWeight.w400,
  }) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Text(
      text,
      style: GoogleFonts.lora(
        fontSize: size,
        fontWeight: weight,
        color: Colors.black87,
      ),
    ),
  );

  // ──────────────────────────────────────────────────────────────────────────────
  // Bottom bar
  // ──────────────────────────────────────────────────────────────────────────────
  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey[200]!)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text(
            '${_getWordCount()} words • ${_getReadingTime()} min read',
            style: GoogleFonts.montserrat(fontSize: 12, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────────
  // Zone picker
  // ──────────────────────────────────────────────────────────────────────────────
  void _showZonePicker() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Select zone',
              style: GoogleFonts.lora(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 20),
            if (_zones.isEmpty)
              const Center(child: CircularProgressIndicator())
            else
              ..._zones.map(
                (zone) => ListTile(
                  leading: Icon(
                    Icons.location_on,
                    color: _selectedZone?.id == zone.id
                        ? Colors.black87
                        : Colors.grey[500],
                    size: 20,
                  ),
                  title: Text(
                    zone.name,
                    style: GoogleFonts.montserrat(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: Colors.black87,
                    ),
                  ),
                  selected: _selectedZone?.id == zone.id,
                  onTap: () {
                    setState(() {
                      _selectedZone = zone;
                      _selectedScope = PostScope.zone(zone.id, zone.name);
                      _saveDraft();
                    });
                    Navigator.pop(context);
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────────
  // Save post
  // ──────────────────────────────────────────────────────────────────────────────
  Future<void> _savePost() async {
    if (_titleController.text.trim().isEmpty) {
      _showSnackBar('Please enter a title');
      return;
    }
    if (_summaryController.text.trim().isEmpty) {
      _showSnackBar('Please enter a summary');
      return;
    }
    if (_contentBlocks.isEmpty) {
      _showSnackBar('Please add some content');
      return;
    }
    if (_selectedScope.isZone && (_zones.isEmpty || _selectedZone == null)) {
      _showSnackBar('No zones available, select Public or contact admin');
      return;
    }

    setState(() => _isLoading = true);

    try {
      String? imageUrl = _existingImageUrl;

      // Process content blocks and update their text/data
      for (final block in _contentBlocks) {
        if (block.type == ContentBlockType.image && block.file != null) {
          try {
            imageUrl = await StorageService.uploadPostImage(block.file!);
            block.url = imageUrl; // Update the block with the uploaded URL
          } catch (e) {
            debugPrint('Failed to upload image: $e');
            _showSnackBar('Failed to upload image: $e');
            return;
          }
        } else if (block.type == ContentBlockType.bulletedList ||
            block.type == ContentBlockType.numberedList) {
          block.listItems = block.listControllers
              .map((c) => c.text.trim())
              .where((text) => text.isNotEmpty) // Filter out empty items
              .toList();
        } else if (block.type == ContentBlockType.flowchart) {
          // ✅ FIXED: Don't overwrite flowchartData - keep the full data from FlowchartCreateScreen
          // The flowchartData already contains title, description, nodes, nodeCount, createdAt
          if (block.flowchartData != null) {
            block.text = block.flowchartData!['title'] ?? 'Flowchart';
          }
          // Add debug print to verify flowchart data
          debugPrint('Flowchart data being saved: ${block.flowchartData}');
        } else if (block.type == ContentBlockType.link) {
          // Handle link blocks properly
          block.text = block.controller.text.trim();
          // URL is already set from the link field
        } else {
          // For heading, subheading, paragraph, file blocks
          block.text = block.controller.text.trim();
        }
      }

      // Create JSON-serializable version of content blocks
      final bodyBlocksJson = _contentBlocks.map((block) {
        final json = <String, dynamic>{
          'type': block.type.index,
          'text': block.text,
        };

        // Add type-specific data
        switch (block.type) {
          case ContentBlockType.bulletedList:
          case ContentBlockType.numberedList:
            json['listItems'] = block.listItems;
            break;
          case ContentBlockType.image:
            if (block.url != null) json['url'] = block.url;
            break;
          case ContentBlockType.link:
            json['url'] = block.url ?? '';
            break;
          case ContentBlockType.file:
            // For files, just store the name and type info
            if (block.file != null) {
              json['fileName'] = block.text;
              json['fileExtension'] = p.extension(block.file!.path);
            }
            break;
          case ContentBlockType.flowchart:
            // ✅ FIXED: Use the complete flowchartData
            json['flowchartData'] = block.flowchartData ?? {'description': ''};
            break;
          default:
            break;
        }

        return json;
      }).toList();

      // Add debug print to verify complete data structure
      debugPrint('Complete bodyBlocksJson being saved: $bodyBlocksJson');

      final input = CreatePostInput(
        title: _titleController.text.trim(),
        bodyDelta: jsonEncode(bodyBlocksJson),
        bodyPlain: _summaryController.text.trim(),
        scope: _selectedScope,
        flair: _selectedFlair,
        imageUrl: imageUrl,
      );

      String postId;
      if (widget.editingPost == null) {
        postId = await PostService.createPost(input);
        await AnalyticsService.logPostCreated(
          postId,
          _selectedScope.type.name,
          flair: _selectedFlair?.name,
        );
      } else {
        await PostService.updatePost(widget.editingPost!.id, input);
        postId = widget.editingPost!.id;
        await AnalyticsService.logPostCreated(
          postId,
          'updated',
          flair: _selectedFlair?.name,
        );
      }

      // Clear draft on successful save
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('post_draft');

      if (mounted) {
        Navigator.of(context).pop(true);
        _showSnackBar(
          widget.editingPost == null ? 'Post published!' : 'Post updated!',
        );
      }
    } catch (e) {
      debugPrint('Error saving post: $e');
      _showSnackBar('Failed to save post: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ──────────────────────────────────────────────────────────────────────────────
  // Navigation & back
  // ──────────────────────────────────────────────────────────────────────────────
  void _handleBack() {
    if (_hasUnsavedChanges()) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(
            'Discard changes?',
            style: GoogleFonts.lora(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          content: Text(
            'You have unsaved changes. Leave anyway?',
            style: GoogleFonts.lora(fontSize: 14),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel', style: GoogleFonts.lora()),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pop(context);
              },
              child: Text(
                'Discard',
                style: GoogleFonts.lora(color: Colors.red),
              ),
            ),
          ],
        ),
      );
    } else {
      Navigator.pop(context);
    }
  }

  bool _hasUnsavedChanges() =>
      _titleController.text.isNotEmpty ||
      _summaryController.text.isNotEmpty ||
      _contentBlocks.isNotEmpty ||
      _selectedFlair != null ||
      _existingImageUrl != null;

  // ──────────────────────────────────────────────────────────────────────────────
  // Misc helpers
  // ──────────────────────────────────────────────────────────────────────────────
  int _getWordCount() => _contentBlocks.fold(0, (sum, b) => sum + b.wordCount);

  int _getReadingTime() =>
      _getWordCount() == 0 ? 1 : (_getWordCount() / 200).ceil();

  void _showSnackBar(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: GoogleFonts.lora()),
        backgroundColor: Colors.black87,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Color _getFlairColor(Flair flair) {
    switch (flair.name.toLowerCase()) {
      case 'urgent':
        return Colors.red[700]!;
      case 'question':
        return Colors.blue!;
      case 'announcement':
        return Colors.green!;
      default:
        return Colors.purple!;
    }
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Content-block model used only by this screen
// ──────────────────────────────────────────────────────────────────────────────
enum ContentBlockType {
  heading,
  subHeading,
  paragraph,
  bulletedList,
  numberedList,
  image,
  link,
  file,
  flowchart,
}

class ContentBlock {
  final ContentBlockType type;

  // UI controllers
  TextEditingController controller;
  List<TextEditingController> listControllers = [];

  // Data
  List<String> listItems;
  File? file;
  String text;
  String? url;
  Map<String, dynamic>? flowchartData;

  ContentBlock(
    this.type, {
    this.text = '',
    this.listItems = const [],
    this.file,
    this.url,
    this.flowchartData,
  }) : controller = TextEditingController(text: text) {
    listControllers = listItems
        .map((e) => TextEditingController(text: e))
        .toList();
    if (type == ContentBlockType.flowchart) {
      controller.text = flowchartData?['description'] ?? '';
    }
  }

  // Word-count helper
  int get wordCount {
    switch (type) {
      case ContentBlockType.heading:
      case ContentBlockType.subHeading:
      case ContentBlockType.paragraph:
      case ContentBlockType.link:
      case ContentBlockType.flowchart:
        return _countWords(controller.text);
      case ContentBlockType.bulletedList:
      case ContentBlockType.numberedList:
        return listItems.fold(0, (s, i) => s + _countWords(i));
      default:
        return 0;
    }
  }

  int _countWords(String s) =>
      s.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;

  // Serialisation - Make sure this doesn't include FieldValue instances
  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{'type': type.index, 'text': text};

    if (listItems.isNotEmpty) {
      json['listItems'] = listItems;
    }

    if (url != null) {
      json['url'] = url;
    }

    if (file != null) {
      json['filePath'] = file!.path;
    }

    if (flowchartData != null) {
      json['flowchartData'] = flowchartData;
    }

    return json;
  }

  static ContentBlock fromJson(Map<String, dynamic> json) {
    final type = ContentBlockType.values[json['type'] as int];
    final block = ContentBlock(
      type,
      text: json['text'] as String? ?? '',
      listItems: List<String>.from(json['listItems'] ?? []),
      url: json['url'] as String?,
      flowchartData: json['flowchartData'] as Map<String, dynamic>?,
    );
    if (json['filePath'] != null) {
      block.file = File(json['filePath']);
    }
    return block;
  }

  void dispose() {
    controller.dispose();
    for (final c in listControllers) c.dispose();
  }
}

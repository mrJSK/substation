import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:collection/collection.dart'; // Added for firstWhereOrNull
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;
import '../../models/hierarchy_models.dart';
import '../../models/power_pulse/powerpulse_models.dart';
import '../../services/power_pulse_service/powerpulse_services.dart';

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
  List<Zone> _zones = [];
  String? _existingImageUrl;

  @override
  void initState() {
    super.initState();
    _initializeControllers();
    _loadZones();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _summaryController.dispose();
    for (var block in _contentBlocks) {
      block.dispose();
    }
    _titleFocusNode.dispose();
    _summaryFocusNode.dispose();
    super.dispose();
  }

  void _initializeControllers() {
    if (widget.editingPost != null) {
      final post = widget.editingPost!;
      _titleController = TextEditingController(text: post.title);
      _summaryController = TextEditingController(text: post.excerpt);
      _selectedScope = post.scope;
      _existingImageUrl = post.imageUrl;

      if (post.bodyPlain.isNotEmpty && post.bodyPlain.startsWith('[')) {
        try {
          final json = jsonDecode(post.bodyPlain) as List<dynamic>;
          _contentBlocks.addAll(
            json.map((e) => ContentBlock.fromJson(e)).toList(),
          );
        } catch (e) {
          print('Error loading content blocks: $e');
        }
      }
    } else {
      _titleController = TextEditingController();
      _summaryController = TextEditingController();
    }
  }

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
        if (_selectedZone == null && zones.isNotEmpty) {
          _selectedZone = zones.first;
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Failed to load zones')));
      }
    }
  }

  void _addHeading() {
    setState(() {
      _contentBlocks.add(
        ContentBlock(ContentBlockType.heading, text: 'Heading'),
      );
    });
  }

  void _addSubHeading() {
    setState(() {
      _contentBlocks.add(
        ContentBlock(ContentBlockType.subHeading, text: 'Sub-Heading'),
      );
    });
  }

  void _addParagraph() {
    setState(() {
      _contentBlocks.add(
        ContentBlock(ContentBlockType.paragraph, text: 'Paragraph text...'),
      );
    });
  }

  void _addBulletedList() {
    setState(() {
      _contentBlocks.add(
        ContentBlock(ContentBlockType.bulletedList, listItems: ['']),
      );
    });
  }

  void _addNumberedList() {
    setState(() {
      _contentBlocks.add(
        ContentBlock(ContentBlockType.numberedList, listItems: ['']),
      );
    });
  }

  void _addListItem(ContentBlock block) {
    setState(() {
      block.listItems.add('');
      block.listControllers.add(TextEditingController());
    });
  }

  void _removeListItem(ContentBlock block, int index) {
    if (block.listItems.length > 1) {
      setState(() {
        block.listItems.removeAt(index);
        block.listControllers[index].dispose();
        block.listControllers.removeAt(index);
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
    });
  }

  Future<void> _uploadImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
    );

    if (pickedFile != null) {
      final file = File(pickedFile.path);
      final size = await file.length();

      if (size > 1024 * 1024) {
        _showSnackBar('Image must be under 1MB');
        return;
      }

      if (![
        '.jpg',
        '.jpeg',
        '.png',
      ].contains(path.extension(file.path).toLowerCase())) {
        _showSnackBar('Only JPG/PNG images allowed');
        return;
      }

      setState(() {
        _contentBlocks.add(ContentBlock(ContentBlockType.image, file: file));
      });
    }
  }

  Future<void> _uploadFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'xls', 'xlsx', 'doc', 'docx'],
    );

    if (result != null) {
      final platformFile = result.files.first;
      if (platformFile.size > 1024 * 1024) {
        _showSnackBar('File must be under 1MB');
        return;
      }

      final file = File(platformFile.path!);
      setState(() {
        _contentBlocks.add(
          ContentBlock(
            ContentBlockType.file,
            file: file,
            text: platformFile.name,
          ),
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: _buildAppBar(),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                if (!_isPreviewMode) _buildScopeSelector(),
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

  void _showContentMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true, // Allow the sheet to expand
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        constraints: BoxConstraints(
          maxHeight:
              MediaQuery.of(context).size.height *
              0.75, // Increased size to 75% of screen
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Add Content',
              style: GoogleFonts.lora(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 20),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    _buildContentOption(
                      icon: Icons.title,
                      title: 'Heading',
                      subtitle: 'Large, bold title text',
                      onTap: () {
                        Navigator.pop(context);
                        _addHeading();
                      },
                    ),
                    _buildContentOption(
                      icon: Icons.subtitles,
                      title: 'Sub-Heading',
                      subtitle: 'Medium title text',
                      onTap: () {
                        Navigator.pop(context);
                        _addSubHeading();
                      },
                    ),
                    _buildContentOption(
                      icon: Icons.text_fields,
                      title: 'Paragraph',
                      subtitle: 'Main body text',
                      onTap: () {
                        Navigator.pop(context);
                        _addParagraph();
                      },
                    ),
                    _buildContentOption(
                      icon: Icons.format_list_bulleted,
                      title: 'Bulleted List',
                      subtitle: 'List with bullet points',
                      onTap: () {
                        Navigator.pop(context);
                        _addBulletedList();
                      },
                    ),
                    _buildContentOption(
                      icon: Icons.format_list_numbered,
                      title: 'Numbered List',
                      subtitle: 'List with numbers',
                      onTap: () {
                        Navigator.pop(context);
                        _addNumberedList();
                      },
                    ),
                    _buildContentOption(
                      icon: Icons.image,
                      title: 'Image',
                      subtitle: 'Upload image (max 1MB)',
                      onTap: () {
                        Navigator.pop(context);
                        _uploadImage();
                      },
                    ),
                    _buildContentOption(
                      icon: Icons.link,
                      title: 'Link',
                      subtitle: 'Add a web link',
                      onTap: () {
                        Navigator.pop(context);
                        _addLink();
                      },
                    ),
                    _buildContentOption(
                      icon: Icons.attach_file,
                      title: 'File',
                      subtitle: 'PDF, Word, Excel (max 1MB)',
                      onTap: () {
                        Navigator.pop(context);
                        _uploadFile();
                      },
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

  Widget _buildContentOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 0,
        vertical: 4,
      ), // Increased vertical padding
      leading: Icon(icon, color: Colors.black54, size: 22),
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
      onTap: onTap,
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
          onPressed: () {
            setState(() {
              _isPreviewMode = !_isPreviewMode;
            });
          },
        ),
        IconButton(
          icon: const Icon(Icons.save, color: Colors.black87),
          onPressed: _isLoading ? null : _savePost,
        ),
      ],
    );
  }

  Widget _buildScopeSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          ElevatedButton.icon(
            onPressed: _zones.isNotEmpty ? _showZonePicker : null,
            icon: Icon(
              _selectedScope.isPublic ? Icons.public : Icons.location_on,
              size: 16,
            ),
            label: Text(
              _selectedScope.isPublic
                  ? 'Public'
                  : (_selectedZone?.name ?? 'Select Zone'),
              style: GoogleFonts.lora(fontSize: 14),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: _selectedScope.isPublic
                  ? Colors.blue[50]
                  : Colors.grey,
              foregroundColor: _selectedScope.isPublic
                  ? Colors.blue
                  : Colors.black87,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          const SizedBox(width: 12),
          if (!_selectedScope.isPublic)
            TextButton(
              onPressed: () {
                setState(() {
                  _selectedScope = PostScope.public();
                });
              },
              child: Text(
                'Make Public',
                style: GoogleFonts.lora(fontSize: 12, color: Colors.blue[600]),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEditor() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _titleController,
              focusNode: _titleFocusNode,
              decoration: InputDecoration(
                hintText: 'Enter your title...',
                hintStyle: GoogleFonts.lora(
                  fontSize: 24,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[400],
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
              ),
              style: GoogleFonts.lora(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: Colors.black87,
              ),
              maxLines: null,
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 16),
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
                      Icon(Icons.summarize, color: Colors.black54, size: 16),
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
                  const SizedBox(height: 8),
                  TextField(
                    controller: _summaryController,
                    focusNode: _summaryFocusNode,
                    decoration: InputDecoration(
                      hintText: 'Write a brief summary for post previews...',
                      hintStyle: GoogleFonts.lora(
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        color: Colors.grey[400],
                      ),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                    ),
                    style: GoogleFonts.lora(
                      fontSize: 14,
                      height: 1.5,
                      color: Colors.black87,
                    ),
                    maxLines: 3,
                    maxLength: 200,
                    textCapitalization: TextCapitalization.sentences,
                    onChanged: (text) {
                      setState(() {});
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _contentBlocks.isEmpty
                ? Center(
                    child: Column(
                      children: [
                        Icon(
                          Icons.article_outlined,
                          size: 60,
                          color: Colors.grey[300],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Add content using the + button',
                          style: GoogleFonts.lora(
                            fontSize: 14,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  )
                : ReorderableListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _contentBlocks.length,
                    itemBuilder: (context, index) {
                      return Dismissible(
                        key: ValueKey(_contentBlocks[index]),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          color: Colors.red,
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 16),
                          child: const Icon(Icons.delete, color: Colors.white),
                        ),
                        onDismissed: (_) {
                          setState(() {
                            _contentBlocks.removeAt(index);
                          });
                          _showSnackBar('Block removed');
                        },
                        child: _buildBlockWidget(_contentBlocks[index]),
                      );
                    },
                    onReorder: (oldIndex, newIndex) {
                      setState(() {
                        if (oldIndex < newIndex) newIndex -= 1;
                        final block = _contentBlocks.removeAt(oldIndex);
                        _contentBlocks.insert(newIndex, block);
                      });
                    },
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreview() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _titleController.text.isEmpty
                ? 'Your title...'
                : _titleController.text,
            style: GoogleFonts.lora(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              height: 1.2,
              color: Colors.black87,
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
                style: GoogleFonts.lora(
                  fontSize: 15,
                  height: 1.5,
                  color: Colors.black87,
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
          Row(
            children: [
              CircleAvatar(
                backgroundColor: Colors.grey[200],
                radius: 18,
                child: Icon(Icons.person, color: Colors.black54, size: 18),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'You',
                    style: GoogleFonts.lora(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  Text(
                    'Just now • ${_getReadingTime()} min read',
                    style: GoogleFonts.lora(
                      fontSize: 11,
                      color: Colors.black54,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          ..._contentBlocks.map(_buildBlockPreview),
        ],
      ),
    );
  }

  Widget _buildBlockWidget(ContentBlock block) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        title: _buildBlockContent(block),
        trailing: const Icon(Icons.drag_handle, color: Colors.grey, size: 20),
      ),
    );
  }

  Widget _buildBlockContent(ContentBlock block) {
    switch (block.type) {
      case ContentBlockType.heading:
        return TextField(
          controller: block.controller,
          decoration: const InputDecoration(
            border: InputBorder.none,
            hintText: 'Enter heading...',
            contentPadding: EdgeInsets.zero,
          ),
          style: GoogleFonts.lora(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: Colors.black87,
          ),
        );
      case ContentBlockType.subHeading:
        return TextField(
          controller: block.controller,
          decoration: const InputDecoration(
            border: InputBorder.none,
            hintText: 'Enter sub-heading...',
            contentPadding: EdgeInsets.zero,
          ),
          style: GoogleFonts.lora(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        );
      case ContentBlockType.paragraph:
        return TextField(
          controller: block.controller,
          maxLines: null,
          decoration: const InputDecoration(
            border: InputBorder.none,
            hintText: 'Write your paragraph...',
            contentPadding: EdgeInsets.zero,
          ),
          style: GoogleFonts.lora(
            fontSize: 15,
            height: 1.5,
            color: Colors.black87,
          ),
        );
      case ContentBlockType.bulletedList:
        return Column(
          children: [
            ...List.generate(block.listItems.length, (i) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 6, right: 8),
                      child: Text('•', style: TextStyle(fontSize: 15)),
                    ),
                    Expanded(
                      child: TextField(
                        controller: block.listControllers[i],
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          hintText: 'List item...',
                          contentPadding: EdgeInsets.zero,
                        ),
                        style: GoogleFonts.lora(
                          fontSize: 15,
                          height: 1.5,
                          color: Colors.black87,
                        ),
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
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                  ],
                ),
              );
            }),
            // Add item button
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  const SizedBox(width: 23), // Align with bullet points
                  TextButton.icon(
                    onPressed: () => _addListItem(block),
                    icon: const Icon(Icons.add, size: 16, color: Colors.blue),
                    label: Text(
                      'Add item',
                      style: GoogleFonts.lora(fontSize: 12, color: Colors.blue),
                    ),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      case ContentBlockType.numberedList:
        return Column(
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
                        '${i + 1}.',
                        style: const TextStyle(fontSize: 15),
                      ),
                    ),
                    Expanded(
                      child: TextField(
                        controller: block.listControllers[i],
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          hintText: 'List item...',
                          contentPadding: EdgeInsets.zero,
                        ),
                        style: GoogleFonts.lora(
                          fontSize: 15,
                          height: 1.5,
                          color: Colors.black87,
                        ),
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
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                  ],
                ),
              );
            }),
            // Add item button
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  const SizedBox(width: 27), // Align with numbered points
                  TextButton.icon(
                    onPressed: () => _addListItem(block),
                    icon: const Icon(Icons.add, size: 16, color: Colors.blue),
                    label: Text(
                      'Add item',
                      style: GoogleFonts.lora(fontSize: 12, color: Colors.blue),
                    ),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      case ContentBlockType.image:
        return Column(
          children: [
            Image.file(block.file!, height: 150, fit: BoxFit.cover),
            const SizedBox(height: 6),
            Text(
              'Image',
              style: GoogleFonts.lora(fontSize: 11, color: Colors.grey[500]),
            ),
          ],
        );
      case ContentBlockType.link:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: block.controller,
              decoration: const InputDecoration(
                border: InputBorder.none,
                hintText: 'Link text...',
                contentPadding: EdgeInsets.zero,
              ),
              style: GoogleFonts.lora(
                fontSize: 15,
                color: Colors.blue[700],
                decoration: TextDecoration.underline,
              ),
            ),
            TextField(
              decoration: const InputDecoration(
                border: InputBorder.none,
                hintText: 'https://...',
                contentPadding: EdgeInsets.zero,
              ),
              style: GoogleFonts.lora(fontSize: 13, color: Colors.grey[600]),
              onChanged: (value) => block.url = value,
            ),
          ],
        );
      case ContentBlockType.file:
        return Row(
          children: [
            const Icon(Icons.attach_file, color: Colors.black54, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    block.text ?? 'File',
                    style: GoogleFonts.lora(
                      fontSize: 15,
                      color: Colors.black87,
                    ),
                  ),
                  Text(
                    path.extension(block.file!.path).toUpperCase(),
                    style: GoogleFonts.lora(
                      fontSize: 11,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
    }
  }

  Widget _buildBlockPreview(ContentBlock block) {
    switch (block.type) {
      case ContentBlockType.heading:
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Text(
            block.controller.text,
            style: GoogleFonts.lora(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Colors.black87,
            ),
          ),
        );
      case ContentBlockType.subHeading:
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            block.controller.text,
            style: GoogleFonts.lora(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
        );
      case ContentBlockType.paragraph:
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Text(
            block.controller.text,
            style: GoogleFonts.lora(
              fontSize: 15,
              height: 1.5,
              color: Colors.black87,
            ),
          ),
        );
      case ContentBlockType.bulletedList:
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: block.listControllers
                .map(
                  (ctrl) => Padding(
                    padding: const EdgeInsets.only(bottom: 3),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('• ', style: TextStyle(fontSize: 15)),
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
                  ),
                )
                .toList(),
          ),
        );
      case ContentBlockType.numberedList:
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: block.listControllers.asMap().entries.map((entry) {
              int idx = entry.key;
              TextEditingController ctrl = entry.value;
              return Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${idx + 1}. ', style: const TextStyle(fontSize: 15)),
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
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Image.file(block.file!, fit: BoxFit.cover),
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
              const Icon(Icons.attach_file, color: Colors.black54, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      block.text ?? 'File',
                      style: GoogleFonts.lora(
                        fontSize: 15,
                        color: Colors.black87,
                      ),
                    ),
                    Text(
                      path.extension(block.file!.path).toUpperCase(),
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
  }

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
            '${_getWordCount()} words',
            style: GoogleFonts.lora(fontSize: 12, color: Colors.black54),
          ),
        ],
      ),
    );
  }

  void _showZonePicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Select Zone',
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
                  contentPadding: const EdgeInsets.symmetric(horizontal: 0),
                  leading: Icon(
                    Icons.location_on,
                    color: _selectedZone?.id == zone.id
                        ? Colors.black87
                        : Colors.grey[500],
                    size: 20,
                  ),
                  title: Text(
                    zone.name,
                    style: GoogleFonts.lora(
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
      _showSnackBar(
        'No zones available. Please select Public or contact admin.',
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      for (var block in _contentBlocks) {
        if (block.type == ContentBlockType.bulletedList ||
            block.type == ContentBlockType.numberedList) {
          block.listItems = block.listControllers
              .map((ctrl) => ctrl.text)
              .toList();
        } else {
          block.text = block.controller.text;
        }
      }

      final blocksJson = _contentBlocks.map((b) => b.toJson()).toList();
      final fullContent = jsonEncode(blocksJson);
      final Map<String, dynamic> emptyDelta = {};

      final postInput = CreatePostInput(
        title: _titleController.text.trim(),
        bodyDelta: emptyDelta,
        bodyPlain: _summaryController.text.trim(),
        scope: _selectedScope,
        imageUrl: _existingImageUrl,
      );

      if (widget.editingPost == null) {
        await PostService.createPost(postInput);
        AnalyticsService.logPostCreated('new', _selectedScope.type.name);
      } else {
        await PostService.updatePost(widget.editingPost!.id, postInput);
        AnalyticsService.logPostCreated(widget.editingPost!.id, 'updated');
      }

      if (mounted) {
        Navigator.of(context).pop(true);
        _showSnackBar(
          widget.editingPost == null ? 'Post published!' : 'Post updated!',
        );
      }
    } catch (e) {
      print('Error saving post: $e');
      _showSnackBar('Failed to save post. Please try again.');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

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
            'You have unsaved changes. Are you sure you want to leave?',
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

  bool _hasUnsavedChanges() {
    return _titleController.text.isNotEmpty ||
        _summaryController.text.isNotEmpty ||
        _contentBlocks.isNotEmpty;
  }

  int _getWordCount() {
    return _contentBlocks.fold(0, (sum, block) => sum + block.wordCount);
  }

  int _getReadingTime() {
    final wordCount = _getWordCount();
    return (wordCount / 200).ceil();
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.lora()),
        backgroundColor: Colors.black87,
      ),
    );
  }
}

enum ContentBlockType {
  heading,
  subHeading,
  paragraph,
  bulletedList,
  numberedList, // Added numbered list type
  image,
  link,
  file,
}

class ContentBlock {
  final ContentBlockType type;
  TextEditingController controller = TextEditingController();
  List<TextEditingController> listControllers = [];
  List<String> listItems = [];
  File? file;
  String text = '';
  String? url;

  ContentBlock(
    this.type, {
    this.text = '',
    this.listItems = const [],
    this.file,
    this.url,
  }) {
    controller = TextEditingController(text: text);
    listControllers = listItems
        .map((item) => TextEditingController(text: item))
        .toList();
  }

  int get wordCount {
    switch (type) {
      case ContentBlockType.heading:
      case ContentBlockType.subHeading:
      case ContentBlockType.paragraph:
      case ContentBlockType.link:
        return controller.text
            .split(RegExp(r'\s+'))
            .where((word) => word.isNotEmpty)
            .length;
      case ContentBlockType.bulletedList:
      case ContentBlockType.numberedList: // Added numbered list word count
        return listItems.fold(
          0,
          (sum, item) =>
              sum +
              item
                  .split(RegExp(r'\s+'))
                  .where((word) => word.isNotEmpty)
                  .length,
        );
      default:
        return 0;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type.index,
      'text': text,
      'listItems': listItems,
      'url': url,
      'filePath': file?.path,
    };
  }

  static ContentBlock fromJson(Map<String, dynamic> json) {
    final type = ContentBlockType.values[json['type'] as int];
    final block = ContentBlock(
      type,
      text: json['text'] as String? ?? '',
      listItems: List<String>.from(json['listItems'] ?? []),
      url: json['url'] as String?,
    );

    if (json['filePath'] != null) {
      block.file = File(json['filePath'] as String);
    }

    return block;
  }

  void dispose() {
    controller.dispose();
    for (var ctrl in listControllers) ctrl.dispose();
  }
}

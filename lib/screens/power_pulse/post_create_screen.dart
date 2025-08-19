// lib/screens/post_create_screen.dart
import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:collection/collection.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/hierarchy_models.dart';
import '../../models/power_pulse/powerpulse_models.dart';
import '../../services/power_pulse_service/powerpulse_services.dart';
import '../../widgets/post_card/flowchart_preview_widget.dart';
import 'excel_table_builder_screen.dart';
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
  final List<TextEditingController> _blockControllers = [];
  final List<List<TextEditingController>> _listControllers = [];

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
    for (final ctrl in _blockControllers) {
      ctrl.dispose();
    }
    for (final list in _listControllers) {
      for (final lc in list) {
        lc.dispose();
      }
    }
    _titleFocusNode.dispose();
    _summaryFocusNode.dispose();
    super.dispose();
  }

  void _initControllers() {
    if (widget.editingPost != null) {
      final post = widget.editingPost!;
      _titleController = TextEditingController(text: post.title);
      _summaryController = TextEditingController(text: post.excerpt);
      _selectedScope = post.scope;
      _selectedFlair = post.flair;
      _existingImageUrl = post.imageUrl;

      _contentBlocks.clear();
      _blockControllers.clear();
      _listControllers.clear();

      for (final block in post.contentBlocks) {
        _contentBlocks.add(block);

        if (_isListBlock(block.type)) {
          _blockControllers.add(TextEditingController());
          final subCtrls = block.listItems
              .map((text) => TextEditingController(text: text))
              .toList();
          _listControllers.add(subCtrls);
        } else {
          _blockControllers.add(TextEditingController(text: block.text));
          _listControllers.add([]);
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

          _contentBlocks.clear();
          _blockControllers.clear();
          _listControllers.clear();
          for (final e in (draft['contentBlocks'] as List<dynamic>? ?? [])) {
            final block = ContentBlock.fromJson(e as Map<String, dynamic>);
            _contentBlocks.add(block);
            if (_isListBlock(block.type)) {
              _blockControllers.add(TextEditingController());
              _listControllers.add(
                block.listItems
                    .map((text) => TextEditingController(text: text))
                    .toList(),
              );
            } else {
              _blockControllers.add(TextEditingController(text: block.text));
              _listControllers.add([]);
            }
          }
        });
      } catch (e) {
        debugPrint('Error loading draft: $e');
      }
    }
  }

  Future<void> _saveDraft() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final draft = {
        'title': _titleController.text,
        'summary': _summaryController.text,
        'scope': _selectedScope.toJson(),
        'flair': _selectedFlair?.toJson(),
        'imageUrl': _existingImageUrl,
        'contentBlocks': _serializeBlocks(),
        'lastSaved': DateTime.now().millisecondsSinceEpoch,
      };

      await prefs.setString('post_draft', jsonEncode(draft));
    } catch (e) {
      debugPrint('Error saving draft: $e');
    }
  }

  void _addHeading() {
    setState(() {
      _contentBlocks.add(
        ContentBlock(type: ContentBlockType.heading, text: 'Heading'),
      );
      _blockControllers.add(TextEditingController(text: 'Heading'));
      _listControllers.add([]);
      _saveDraft();
    });
  }

  void _addSubHeading() {
    setState(() {
      _contentBlocks.add(
        ContentBlock(type: ContentBlockType.subHeading, text: 'Sub-heading'),
      );
      _blockControllers.add(TextEditingController(text: 'Sub-heading'));
      _listControllers.add([]);
      _saveDraft();
    });
  }

  void _addParagraph() {
    setState(() {
      _contentBlocks.add(
        ContentBlock(type: ContentBlockType.paragraph, text: 'Paragraph text…'),
      );
      _blockControllers.add(TextEditingController(text: 'Paragraph text…'));
      _listControllers.add([]);
      _saveDraft();
    });
  }

  void _addBulletedList() {
    setState(() {
      _contentBlocks.add(
        ContentBlock(type: ContentBlockType.bulletedList, listItems: ['']),
      );
      _blockControllers.add(TextEditingController());
      _listControllers.add([TextEditingController()]);
      _saveDraft();
    });
  }

  void _addNumberedList() {
    setState(() {
      _contentBlocks.add(
        ContentBlock(type: ContentBlockType.numberedList, listItems: ['']),
      );
      _blockControllers.add(TextEditingController());
      _listControllers.add([TextEditingController()]);
      _saveDraft();
    });
  }

  void _addFlowchart() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const FlowchartCreateScreen()),
    );
    if (result != null) {
      setState(() {
        _contentBlocks.add(
          ContentBlock(
            type: ContentBlockType.flowchart,
            flowchartData: result,
            text: result['title'] ?? 'Flowchart',
          ),
        );
        _blockControllers.add(
          TextEditingController(text: result['description'] ?? ''),
        );
        _listControllers.add([]);
        _saveDraft();
      });
    }
  }

  void _addListItem(ContentBlock block, int blockIdx) {
    setState(() {
      block.listItems.add('');
      _listControllers[blockIdx].add(TextEditingController());
      _saveDraft();
    });
  }

  void _removeListItem(ContentBlock block, int blockIdx, int idx) {
    if (block.listItems.length > 1) {
      setState(() {
        block.listItems.removeAt(idx);
        _listControllers[blockIdx][idx].dispose();
        _listControllers[blockIdx].removeAt(idx);
        _saveDraft();
      });
    }
  }

  void _addLink() {
    setState(() {
      _contentBlocks.add(
        ContentBlock(
          type: ContentBlockType.link,
          text: 'Link text',
          url: 'https://example.com',
        ),
      );
      _blockControllers.add(TextEditingController(text: 'Link text'));
      _listControllers.add([]);
      _saveDraft();
    });
  }

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
      _contentBlocks.add(
        ContentBlock(type: ContentBlockType.image, file: file),
      );
      _blockControllers.add(TextEditingController());
      _listControllers.add([]);
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
        ContentBlock(
          type: ContentBlockType.file,
          file: file,
          text: picked.name,
        ),
      );
      _blockControllers.add(TextEditingController(text: picked.name));
      _listControllers.add([]);
      _saveDraft();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDarkMode ? const Color(0xFF1C1C1E) : Colors.white,
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
              backgroundColor: isDarkMode ? Colors.blue[600] : Colors.black87,
              child: const Icon(Icons.add, color: Colors.white),
            ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return AppBar(
      backgroundColor: isDarkMode ? const Color(0xFF2C2C2E) : Colors.white,
      elevation: 0,
      leading: IconButton(
        icon: Icon(
          Icons.close,
          color: isDarkMode ? Colors.white : Colors.black87,
        ),
        onPressed: _handleBack,
      ),
      title: Text(
        widget.editingPost == null ? 'New Post' : 'Edit Post',
        style: GoogleFonts.lora(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: isDarkMode ? Colors.white : Colors.black87,
        ),
      ),
      actions: [
        IconButton(
          icon: Icon(
            _isPreviewMode ? Icons.edit : Icons.visibility,
            color: isDarkMode ? Colors.white : Colors.black87,
          ),
          onPressed: () => setState(() => _isPreviewMode = !_isPreviewMode),
        ),
        IconButton(
          icon: Icon(
            Icons.save,
            color: isDarkMode ? Colors.white : Colors.black87,
          ),
          onPressed: _isLoading ? null : _savePost,
        ),
      ],
    );
  }

  Widget _buildScopeAndFlairSelector() {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return Container(
      color: isDarkMode ? const Color(0xFF2C2C2E) : null,
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
                  : (_selectedZone?.name ?? 'Select zone'),
              style: GoogleFonts.montserrat(fontSize: 14),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: _selectedScope.isPublic
                  ? (isDarkMode ? Colors.blue[800] : Colors.blue[50])
                  : Colors.orange,
              foregroundColor: _selectedScope.isPublic
                  ? (isDarkMode ? Colors.blue[200] : Colors.blue[700])
                  : Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            onPressed: _showFlairPicker,
            icon: Icon(
              Icons.label_outline,
              size: 16,
              color: _selectedFlair != null
                  ? _getFlairColor(_selectedFlair!)
                  : (isDarkMode
                        ? Colors.white.withOpacity(0.6)
                        : Colors.grey[600]),
            ),
            label: Text(
              _selectedFlair?.name ?? 'Add flair',
              style: GoogleFonts.montserrat(
                fontSize: 14,
                color: _selectedFlair != null
                    ? _getFlairColor(_selectedFlair!)
                    : (isDarkMode
                          ? Colors.white.withOpacity(0.6)
                          : Colors.grey[600]),
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: _selectedFlair != null
                  ? _getFlairColor(_selectedFlair!).withOpacity(0.1)
                  : (isDarkMode ? const Color(0xFF3C3C3E) : Colors.grey[200]),
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
                  color: isDarkMode ? Colors.blue[200] : Colors.blue[600],
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _showFlairPicker() {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: isDarkMode ? const Color(0xFF1C1C1E) : null,
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
                color: isDarkMode ? Colors.white : Colors.black87,
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
                    color: isDarkMode ? Colors.white : Colors.black87,
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
                  color: isDarkMode ? Colors.white : Colors.black87,
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

  void _showContentMenu() {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDarkMode ? const Color(0xFF1C1C1E) : null,
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
                color: isDarkMode ? Colors.white : Colors.black87,
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
                      Icons.table_chart,
                      'Excel Table',
                      'Create an interactive table',
                      _addExcelTable,
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

  void _addExcelTable() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ExcelTableBuilderScreen()),
    );

    if (result != null) {
      setState(() {
        _contentBlocks.add(
          ContentBlock(
            type: ContentBlockType.excelTable,
            excelData: result,
            text: result['title'] ?? 'Excel Table',
          ),
        );
        _blockControllers.add(
          TextEditingController(text: result['title'] ?? 'Excel Table'),
        );
        _listControllers.add([]);
        _saveDraft();
      });
    }
  }

  ListTile _contentOption(
    IconData icon,
    String title,
    String subtitle,
    VoidCallback onTap,
  ) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return ListTile(
      leading: Icon(icon, color: isDarkMode ? Colors.white54 : Colors.black54),
      title: Text(
        title,
        style: GoogleFonts.lora(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: isDarkMode ? Colors.white : Colors.black87,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: GoogleFonts.lora(
          fontSize: 13,
          color: isDarkMode ? Colors.white54 : Colors.black54,
        ),
      ),
      onTap: () {
        Navigator.pop(context);
        onTap();
      },
    );
  }

  Widget _buildEditor() {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _titleController,
            focusNode: _titleFocusNode,
            maxLines: null,
            style: GoogleFonts.lora(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: isDarkMode ? Colors.white : Colors.black87,
            ),
            decoration: InputDecoration(
              hintText: 'Enter your title…',
              hintStyle: GoogleFonts.lora(
                fontSize: 24,
                fontWeight: FontWeight.w500,
                color: isDarkMode
                    ? Colors.white.withOpacity(0.4)
                    : Colors.grey[400],
              ),
              border: InputBorder.none,
            ),
            textCapitalization: TextCapitalization.sentences,
            onChanged: (_) => _saveDraft(),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDarkMode ? const Color(0xFF2C2C2E) : Colors.grey[50],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.summarize,
                      size: 16,
                      color: isDarkMode ? Colors.white54 : Colors.black54,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Summary',
                      style: GoogleFonts.lora(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isDarkMode ? Colors.white : Colors.black87,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${_summaryController.text.length}/200',
                      style: GoogleFonts.lora(
                        fontSize: 11,
                        color: isDarkMode ? Colors.white54 : Colors.black54,
                      ),
                    ),
                  ],
                ),
                TextField(
                  controller: _summaryController,
                  focusNode: _summaryFocusNode,
                  maxLines: 3,
                  maxLength: 200,
                  style: GoogleFonts.lora(
                    fontSize: 14,
                    height: 1.5,
                    color: isDarkMode ? Colors.white : Colors.black87,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Brief summary for post previews…',
                    hintStyle: GoogleFonts.lora(
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      color: isDarkMode
                          ? Colors.white.withOpacity(0.4)
                          : Colors.grey[400],
                    ),
                    border: InputBorder.none,
                    counterText: '',
                  ),
                  textCapitalization: TextCapitalization.sentences,
                  onChanged: (_) => _saveDraft(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _contentBlocks.isEmpty
              ? Column(
                  children: [
                    Icon(
                      Icons.article_outlined,
                      size: 60,
                      color: isDarkMode
                          ? Colors.white.withOpacity(0.3)
                          : Colors.grey[300],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Add content using the + button',
                      style: GoogleFonts.lora(
                        fontSize: 14,
                        color: isDarkMode
                            ? Colors.white.withOpacity(0.6)
                            : Colors.grey[600],
                      ),
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
                      final blockCtrl = _blockControllers.removeAt(oldIdx);
                      final listCtrls = _listControllers.removeAt(oldIdx);

                      _contentBlocks.insert(newIdx, block);
                      _blockControllers.insert(newIdx, blockCtrl);
                      _listControllers.insert(newIdx, listCtrls);

                      _saveDraft();
                    });
                  },
                  itemBuilder: (context, index) {
                    final block = _contentBlocks[index];
                    return Dismissible(
                      key: ValueKey('${block.type}_$index'),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        color: Colors.red,
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 16),
                        child: const Icon(Icons.delete, color: Colors.white),
                      ),
                      confirmDismiss: (direction) async {
                        return await _showDeleteConfirmationDialog(block);
                      },
                      onDismissed: (_) {
                        setState(() {
                          _contentBlocks.removeAt(index);
                          _blockControllers[index].dispose();
                          _blockControllers.removeAt(index);
                          for (final ctrl in _listControllers[index]) {
                            ctrl.dispose();
                          }
                          _listControllers.removeAt(index);
                          _saveDraft();
                        });
                        _showSnackBar('Block removed');
                      },
                      child: _blockEditor(block, index),
                    );
                  },
                ),
        ],
      ),
    );
  }

  Future<bool?> _showDeleteConfirmationDialog(ContentBlock block) async {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

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
      case ContentBlockType.excelTable:
        blockTypeName = 'Excel Table';
        break;
    }

    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDarkMode ? const Color(0xFF1C1C1E) : null,
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
                color: isDarkMode ? Colors.white : Colors.black87,
              ),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to delete this $blockTypeName? This action cannot be undone.',
          style: GoogleFonts.lora(
            fontSize: 14,
            color: isDarkMode
                ? Colors.white.withOpacity(0.7)
                : Colors.grey[700],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              'Cancel',
              style: GoogleFonts.lora(
                fontSize: 14,
                color: isDarkMode ? Colors.white : Colors.grey,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
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

  Widget _excelTableField(ContentBlock block, int index) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final excelData = block.excelData ?? {};
    final rows = excelData['rows'] ?? 0;
    final columns = excelData['columns'] ?? 0;
    final title = excelData['title'] ?? 'Excel Table';

    return _blockShell(
      InkWell(
        onTap: () => _editExcelTable(block, index),
        child: Container(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.table_chart,
                  color: Colors.green[600],
                  size: 24,
                ),
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
                        color: isDarkMode ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${rows}×${columns} table with merged cells',
                      style: GoogleFonts.lora(
                        fontSize: 13,
                        color: isDarkMode
                            ? Colors.white.withOpacity(0.6)
                            : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.edit,
                color: isDarkMode ? Colors.white54 : Colors.grey,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _editExcelTable(ContentBlock block, int index) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            ExcelTableBuilderScreen(existingData: block.excelData),
      ),
    );

    if (result != null) {
      setState(() {
        block.excelData = result;
        block.text = result['title'] ?? 'Excel Table';
        _saveDraft();
      });
    }
  }

  Widget _blockEditor(ContentBlock block, int index) {
    switch (block.type) {
      case ContentBlockType.heading:
        return _headingField(
          block,
          index,
          fontSize: 20,
          hint: 'Enter heading…',
        );
      case ContentBlockType.subHeading:
        return _headingField(
          block,
          index,
          fontSize: 17,
          hint: 'Enter sub-heading…',
        );
      case ContentBlockType.paragraph:
        return _paragraphField(block, index);
      case ContentBlockType.bulletedList:
      case ContentBlockType.numberedList:
        return _listField(block, index);
      case ContentBlockType.image:
        return _imageField(block);
      case ContentBlockType.link:
        return _linkField(block, index);
      case ContentBlockType.file:
        return _fileField(block);
      case ContentBlockType.flowchart:
        return _flowchartField(block, index);
      case ContentBlockType.excelTable:
        return _excelTableField(block, index);
    }
  }

  Widget _headingField(
    ContentBlock block,
    int index, {
    required double fontSize,
    required String hint,
  }) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return _blockShell(
      TextField(
        controller: _blockControllers[index],
        style: GoogleFonts.lora(
          fontSize: fontSize,
          fontWeight: FontWeight.w700,
          color: isDarkMode ? Colors.white : Colors.black87,
        ),
        decoration: InputDecoration(
          border: InputBorder.none,
          hintText: hint,
          hintStyle: TextStyle(
            color: isDarkMode
                ? Colors.white.withOpacity(0.4)
                : Colors.grey[400],
          ),
        ),
        onChanged: (value) {
          block.text = value;
          _saveDraft();
        },
      ),
    );
  }

  Widget _paragraphField(ContentBlock block, int index) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return _blockShell(
      TextField(
        controller: _blockControllers[index],
        maxLines: null,
        style: GoogleFonts.lora(
          fontSize: 15,
          height: 1.5,
          color: isDarkMode ? Colors.white : Colors.black87,
        ),
        decoration: InputDecoration(
          border: InputBorder.none,
          hintText: 'Paragraph…',
          hintStyle: TextStyle(
            color: isDarkMode
                ? Colors.white.withOpacity(0.4)
                : Colors.grey[400],
          ),
        ),
        onChanged: (value) {
          block.text = value;
          _saveDraft();
        },
      ),
    );
  }

  Widget _listField(ContentBlock block, int index) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final listControllers = _listControllers[index];

    return _blockShell(
      Column(
        children: [
          ...List.generate(block.listItems.length, (i) {
            while (listControllers.length <= i) {
              listControllers.add(TextEditingController());
            }

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
                      style: TextStyle(
                        fontSize: 15,
                        color: isDarkMode ? Colors.white : Colors.black87,
                      ),
                    ),
                  ),
                  Expanded(
                    child: TextField(
                      controller: listControllers[i],
                      style: GoogleFonts.lora(
                        fontSize: 15,
                        height: 1.5,
                        color: isDarkMode ? Colors.white : Colors.black87,
                      ),
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        hintText: 'List item…',
                        hintStyle: TextStyle(
                          color: isDarkMode
                              ? Colors.white.withOpacity(0.4)
                              : Colors.grey[400],
                        ),
                      ),
                      onChanged: (value) {
                        block.listItems[i] = value;
                        _saveDraft();
                      },
                    ),
                  ),
                  if (block.listItems.length > 1)
                    IconButton(
                      icon: const Icon(
                        Icons.remove_circle_outline,
                        color: Colors.red,
                        size: 18,
                      ),
                      onPressed: () => _removeListItem(block, index, i),
                    ),
                ],
              ),
            );
          }),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => _addListItem(block, index),
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
          ClipRRect(borderRadius: BorderRadius.circular(8), child: img),
          const SizedBox(height: 6),
          Text(
            'Image',
            style: GoogleFonts.lora(fontSize: 11, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _linkField(ContentBlock block, int index) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return _blockShell(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _blockControllers[index],
            style: GoogleFonts.lora(
              fontSize: 15,
              color: Colors.blue[700],
              decoration: TextDecoration.underline,
            ),
            decoration: InputDecoration(
              border: InputBorder.none,
              hintText: 'Link text…',
              hintStyle: TextStyle(
                color: isDarkMode
                    ? Colors.white.withOpacity(0.4)
                    : Colors.grey[400],
              ),
            ),
            onChanged: (value) {
              block.text = value;
              _saveDraft();
            },
          ),
          TextField(
            style: GoogleFonts.lora(
              fontSize: 13,
              color: isDarkMode
                  ? Colors.white.withOpacity(0.6)
                  : Colors.grey[600],
            ),
            decoration: InputDecoration(
              border: InputBorder.none,
              hintText: 'https://…',
              hintStyle: TextStyle(
                color: isDarkMode
                    ? Colors.white.withOpacity(0.4)
                    : Colors.grey[400],
              ),
            ),
            controller: TextEditingController(text: block.url ?? ''),
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
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return _blockShell(
      Row(
        children: [
          Icon(
            Icons.attach_file,
            color: isDarkMode ? Colors.white54 : Colors.black54,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  block.text,
                  style: GoogleFonts.lora(
                    fontSize: 15,
                    color: isDarkMode ? Colors.white : Colors.black87,
                  ),
                ),
                Text(
                  block.file != null
                      ? p.extension(block.file!.path).toUpperCase()
                      : 'FILE',
                  style: GoogleFonts.lora(
                    fontSize: 11,
                    color: isDarkMode
                        ? Colors.white.withOpacity(0.5)
                        : Colors.grey[500],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _editFlowchart(ContentBlock block, int index) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            FlowchartCreateScreen(existingFlowchart: block.flowchartData),
      ),
    );

    if (result != null) {
      setState(() {
        block.flowchartData = result;
        block.text = result['title'] ?? 'Flowchart';
        _blockControllers[index].text = result['description'] ?? '';
        _saveDraft();
      });
    }
  }

  Widget _flowchartField(ContentBlock block, int index) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final flowchartData = block.flowchartData ?? {};
    final title = flowchartData['title'] ?? 'Untitled Flowchart';
    final description = flowchartData['description'] ?? '';
    final nodeCount = flowchartData['nodeCount'] ?? 0;

    return _blockShell(
      InkWell(
        onTap: () => _editFlowchart(block, index),
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
                child: Icon(
                  Icons.account_tree,
                  color: Colors.blue[600],
                  size: 24,
                ),
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
                        color: isDarkMode ? Colors.white : Colors.black87,
                      ),
                    ),
                    if (description.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        description,
                        style: GoogleFonts.lora(
                          fontSize: 13,
                          color: isDarkMode
                              ? Colors.white.withOpacity(0.6)
                              : Colors.grey[600],
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
              Icon(
                Icons.edit,
                color: isDarkMode ? Colors.white54 : Colors.grey,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _blockShell(Widget child) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF2C2C2E) : Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: isDarkMode
                ? Colors.black.withOpacity(0.3)
                : Colors.grey.withOpacity(0.08),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        title: child,
        contentPadding: const EdgeInsets.all(12),
        trailing: Icon(
          Icons.drag_handle,
          color: isDarkMode ? Colors.white54 : Colors.grey,
          size: 20,
        ),
      ),
    );
  }

  Widget _buildPreview() {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

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
              color: isDarkMode ? Colors.white : Colors.black87,
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
                color: isDarkMode ? const Color(0xFF2C2C2E) : Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _summaryController.text,
                style: GoogleFonts.lora(
                  fontSize: 15,
                  height: 1.5,
                  color: isDarkMode ? Colors.white : Colors.black87,
                ),
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
                    color: Colors.blue[600],
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
                      color: isDarkMode ? Colors.white : Colors.black87,
                    ),
                  ),
                  Text(
                    'Just now • ${_getReadingTime()} min read',
                    style: GoogleFonts.montserrat(
                      fontSize: 11,
                      color: isDarkMode
                          ? Colors.white.withOpacity(0.6)
                          : Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          ..._contentBlocks.asMap().entries.map(
            (entry) => _blockPreview(entry.value, entry.key),
          ),
        ],
      ),
    );
  }

  Widget _blockPreview(ContentBlock block, int index) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    switch (block.type) {
      case ContentBlockType.heading:
        return _pv(
          text: _blockControllers[index].text,
          size: 20,
          weight: FontWeight.w700,
        );
      case ContentBlockType.subHeading:
        return _pv(
          text: _blockControllers[index].text,
          size: 17,
          weight: FontWeight.w600,
        );
      case ContentBlockType.paragraph:
        return _pv(text: _blockControllers[index].text, size: 15);
      case ContentBlockType.bulletedList:
      case ContentBlockType.numberedList:
        final isBulleted = block.type == ContentBlockType.bulletedList;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: _listControllers[index].asMap().entries.map((entry) {
              final idx = entry.key;
              final ctrl = entry.value;
              return Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isBulleted ? '• ' : '${idx + 1}. ',
                      style: TextStyle(
                        fontSize: 15,
                        color: isDarkMode ? Colors.white : Colors.black87,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        ctrl.text,
                        style: GoogleFonts.lora(
                          fontSize: 15,
                          height: 1.5,
                          color: isDarkMode ? Colors.white : Colors.black87,
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
          child: ClipRRect(borderRadius: BorderRadius.circular(8), child: img),
        );
      case ContentBlockType.link:
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Text(
            _blockControllers[index].text,
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
              Icon(
                Icons.attach_file,
                size: 18,
                color: isDarkMode ? Colors.white54 : Colors.black54,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      block.text,
                      style: GoogleFonts.lora(
                        fontSize: 15,
                        color: isDarkMode ? Colors.white : Colors.black87,
                      ),
                    ),
                    Text(
                      block.file != null
                          ? p.extension(block.file!.path).toUpperCase()
                          : 'FILE',
                      style: GoogleFonts.lora(
                        fontSize: 11,
                        color: isDarkMode
                            ? Colors.white.withOpacity(0.5)
                            : Colors.grey[500],
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
              color: isDarkMode
                  ? Colors.blue[900]?.withOpacity(0.3)
                  : Colors.blue[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue[600]!),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.account_tree, color: Colors.blue[600], size: 24),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        title,
                        style: GoogleFonts.lora(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: isDarkMode ? Colors.white : Colors.black87,
                        ),
                      ),
                    ),
                  ],
                ),

                if (description.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    description,
                    style: GoogleFonts.lora(
                      fontSize: 14,
                      color: isDarkMode
                          ? Colors.white.withOpacity(0.7)
                          : Colors.grey[700],
                    ),
                  ),
                ],

                const SizedBox(height: 16),

                FlowchartPreviewWidget(
                  flowchartData: block.flowchartData,
                  height: 200,
                  onTap: () => _editFlowchart(block, index),
                ),

                const SizedBox(height: 12),

                Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue[600], size: 16),
                    const SizedBox(width: 4),
                    Text(
                      'Preview mode - Tap to edit flowchart',
                      style: GoogleFonts.lora(
                        fontSize: 12,
                        color: Colors.blue[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '$nodeCount nodes',
                      style: GoogleFonts.lora(
                        fontSize: 12,
                        color: isDarkMode
                            ? Colors.white.withOpacity(0.6)
                            : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      case ContentBlockType.excelTable:
        final excelData = block.excelData ?? {};
        final title = excelData['title'] ?? 'Excel Table';
        final rows = excelData['rows'] ?? 0;
        final columns = excelData['columns'] ?? 0;
        final data = excelData['data'] as List<dynamic>? ?? [];
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDarkMode
                  ? Colors.green[900]?.withOpacity(0.3)
                  : Colors.green[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.green!),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.table_chart, color: Colors.green, size: 24),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        title,
                        style: GoogleFonts.lora(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: isDarkMode ? Colors.white : Colors.black87,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Column(
                    children: List.generate(
                      rows > 5 ? 5 : rows,
                      (i) => Row(
                        children: List.generate(
                          columns > 5 ? 5 : columns,
                          (j) => Container(
                            width: 80,
                            height: 30,
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: isDarkMode
                                    ? Colors.white.withOpacity(0.3)
                                    : Colors.grey[300]!,
                              ),
                              color: isDarkMode
                                  ? const Color(0xFF2C2C2E)
                                  : Colors.white,
                            ),
                            child: Center(
                              child: Text(
                                i < data.length && j < (data[i] as List).length
                                    ? (data[i] as List)[j].toString()
                                    : '',
                                style: GoogleFonts.lora(
                                  fontSize: 10,
                                  color: isDarkMode
                                      ? Colors.white
                                      : Colors.black87,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Colors.green[600],
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Preview mode - Tap to edit table',
                      style: GoogleFonts.lora(
                        fontSize: 12,
                        color: Colors.green,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${rows}×${columns} table',
                      style: GoogleFonts.lora(
                        fontSize: 12,
                        color: isDarkMode
                            ? Colors.white.withOpacity(0.6)
                            : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
    }
  }

  Widget _pv({
    required String text,
    required double size,
    FontWeight weight = FontWeight.w400,
  }) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        text,
        style: GoogleFonts.lora(
          fontSize: size,
          fontWeight: weight,
          color: isDarkMode ? Colors.white : Colors.black87,
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF2C2C2E) : Colors.white,
        border: Border(
          top: BorderSide(
            color: isDarkMode
                ? Colors.white.withOpacity(0.1)
                : Colors.grey[200]!,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text(
            '${_getWordCount()} words • ${_getReadingTime()} min read',
            style: GoogleFonts.montserrat(
              fontSize: 12,
              color: isDarkMode
                  ? Colors.white.withOpacity(0.6)
                  : Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  void _showZonePicker() {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: isDarkMode ? const Color(0xFF1C1C1E) : null,
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
                color: isDarkMode ? Colors.white : Colors.black87,
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
                        ? (isDarkMode ? Colors.white : Colors.black87)
                        : (isDarkMode
                              ? Colors.white.withOpacity(0.5)
                              : Colors.grey[500]),
                    size: 20,
                  ),
                  title: Text(
                    zone.name,
                    style: GoogleFonts.montserrat(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: isDarkMode ? Colors.white : Colors.black87,
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

      for (int i = 0; i < _contentBlocks.length; ++i) {
        final block = _contentBlocks[i];

        if (block.type == ContentBlockType.image && block.file != null) {
          try {
            imageUrl = await StorageService.uploadPostImage(block.file!);
            block.url = imageUrl;
          } catch (e) {
            debugPrint('Failed to upload image: $e');
            _showSnackBar('Failed to upload image: $e');
            return;
          }
        } else if (_isListBlock(block.type)) {
          block.listItems = _listControllers[i]
              .map((c) => c.text.trim())
              .where((text) => text.isNotEmpty)
              .toList();
        } else if (block.type == ContentBlockType.flowchart) {
          if (block.flowchartData != null) {
            block.text = block.flowchartData!['title'] ?? 'Flowchart';
          }
        } else {
          block.text = _blockControllers[i].text.trim();
        }
      }

      final input = CreatePostInput(
        title: _titleController.text.trim(),
        bodyDelta: '',
        contentBlocks: _contentBlocks,
        excerpt: _summaryController.text.trim(),
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

  void _handleBack() {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    if (_hasUnsavedChanges()) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: isDarkMode ? const Color(0xFF1C1C1E) : null,
          title: Text(
            'Discard changes?',
            style: GoogleFonts.lora(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: isDarkMode ? Colors.white : null,
            ),
          ),
          content: Text(
            'You have unsaved changes. Leave anyway?',
            style: GoogleFonts.lora(
              fontSize: 14,
              color: isDarkMode ? Colors.white : null,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Cancel',
                style: GoogleFonts.lora(
                  color: isDarkMode ? Colors.white : null,
                ),
              ),
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

  List<Map<String, dynamic>> _serializeBlocks() {
    final result = <Map<String, dynamic>>[];
    for (int i = 0; i < _contentBlocks.length; ++i) {
      final block = _contentBlocks[i];
      final map = block.toJson();
      if (_isListBlock(block.type)) {
        map['listItems'] = _listControllers[i].map((c) => c.text).toList();
      } else {
        map['text'] = _blockControllers[i].text;
      }
      result.add(map);
    }
    return result;
  }

  static bool _isListBlock(ContentBlockType type) =>
      type == ContentBlockType.bulletedList ||
      type == ContentBlockType.numberedList;

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

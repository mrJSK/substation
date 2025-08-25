// lib/widgets/bookmark_bottom_sheet.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/power_pulse/bookmark_models.dart';
import '../../models/power_pulse/powerpulse_models.dart';
import '../../services/power_pulse_service/bookmark_service.dart';

class BookmarkBottomSheet extends StatefulWidget {
  final Post post;

  const BookmarkBottomSheet({Key? key, required this.post}) : super(key: key);

  @override
  State<BookmarkBottomSheet> createState() => _BookmarkBottomSheetState();
}

class _BookmarkBottomSheetState extends State<BookmarkBottomSheet> {
  List<BookmarkList> _lists = [];
  List<String> _bookmarkedListIds = [];
  bool _isLoading = true;
  bool _isOperating = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final lists = await BookmarkService.streamUserLists().first;
      final bookmarkedIds = await BookmarkService.getBookmarkedListIds(
        widget.post.id,
      );

      if (mounted) {
        setState(() {
          _lists = lists;
          _bookmarkedListIds = bookmarkedIds;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showSnackBar('Failed to load bookmark lists: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF1C1C1E) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: isDarkMode
                  ? Colors.white.withOpacity(0.3)
                  : Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Row(
              children: [
                Icon(
                  Icons.bookmark_outline,
                  color: isDarkMode ? Colors.white : Colors.black87,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Save to List',
                        style: GoogleFonts.lora(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: isDarkMode ? Colors.white : Colors.black87,
                        ),
                      ),
                      Text(
                        widget.post.title,
                        style: GoogleFonts.lora(
                          fontSize: 14,
                          color: isDarkMode
                              ? Colors.white.withOpacity(0.7)
                              : Colors.grey[600],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(
                    Icons.close,
                    color: isDarkMode ? Colors.white : Colors.black87,
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Content
          Flexible(
            child: _isLoading ? _buildLoadingState() : _buildListsView(),
          ),

          // Create new list button
          Padding(
            padding: const EdgeInsets.all(20),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _isOperating ? null : _showCreateListDialog,
                icon: const Icon(Icons.add),
                label: Text(
                  'Create New List',
                  style: GoogleFonts.lora(fontWeight: FontWeight.w500),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  side: BorderSide(
                    color: isDarkMode
                        ? Colors.white.withOpacity(0.3)
                        : Colors.grey[300]!,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: CircularProgressIndicator(),
      ),
    );
  }

  Widget _buildListsView() {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    if (_lists.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.bookmark_border,
              size: 48,
              color: isDarkMode
                  ? Colors.white.withOpacity(0.4)
                  : Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No bookmark lists yet',
              style: GoogleFonts.lora(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: isDarkMode
                    ? Colors.white.withOpacity(0.7)
                    : Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Create your first list to start saving posts',
              style: GoogleFonts.lora(
                fontSize: 14,
                color: isDarkMode
                    ? Colors.white.withOpacity(0.5)
                    : Colors.grey[500],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _lists.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final list = _lists[index];
        final isBookmarked = _bookmarkedListIds.contains(list.id);

        return ListTile(
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _getListColor(list.color).withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _getListColor(list.color), width: 1),
            ),
            child: Icon(
              list.isDefault ? Icons.bookmark : Icons.folder,
              color: _getListColor(list.color),
              size: 20,
            ),
          ),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  list.name,
                  style: GoogleFonts.lora(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: isDarkMode ? Colors.white : Colors.black87,
                  ),
                ),
              ),
              if (list.isDefault)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.blue, width: 0.5),
                  ),
                  child: Text(
                    'Default',
                    style: GoogleFonts.lora(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: Colors.blue,
                    ),
                  ),
                ),
            ],
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (list.description.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  list.description,
                  style: GoogleFonts.lora(
                    fontSize: 13,
                    color: isDarkMode
                        ? Colors.white.withOpacity(0.6)
                        : Colors.grey[600],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: 4),
              Text(
                '${list.bookmarkCount} ${list.bookmarkCount == 1 ? 'post' : 'posts'}',
                style: GoogleFonts.lora(
                  fontSize: 12,
                  color: isDarkMode
                      ? Colors.white.withOpacity(0.5)
                      : Colors.grey[500],
                ),
              ),
            ],
          ),
          trailing: _isOperating
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Checkbox(
                  value: isBookmarked,
                  onChanged: (value) => _toggleBookmark(list, value ?? false),
                  activeColor: _getListColor(list.color),
                ),
          onTap: _isOperating
              ? null
              : () => _toggleBookmark(list, !isBookmarked),
        );
      },
    );
  }

  Color _getListColor(String? colorHex) {
    if (colorHex == null) return Colors.blue;
    try {
      return Color(int.parse(colorHex.replaceFirst('#', '0xFF')));
    } catch (e) {
      return Colors.blue;
    }
  }

  Future<void> _toggleBookmark(BookmarkList list, bool shouldBookmark) async {
    if (_isOperating) return;

    setState(() => _isOperating = true);

    try {
      if (shouldBookmark) {
        await BookmarkService.addBookmark(
          postId: widget.post.id,
          listId: list.id,
        );
        _bookmarkedListIds.add(list.id);
        _showSnackBar('Added to ${list.name}');
      } else {
        await BookmarkService.removeBookmark(
          postId: widget.post.id,
          listId: list.id,
        );
        _bookmarkedListIds.remove(list.id);
        _showSnackBar('Removed from ${list.name}');
      }

      // Update the list's bookmark count locally
      final listIndex = _lists.indexWhere((l) => l.id == list.id);
      if (listIndex != -1) {
        _lists[listIndex] = _lists[listIndex].copyWith(
          bookmarkCount:
              _lists[listIndex].bookmarkCount + (shouldBookmark ? 1 : -1),
        );
      }

      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      _showSnackBar('Failed to update bookmark: $e');
    } finally {
      if (mounted) {
        setState(() => _isOperating = false);
      }
    }
  }

  void _showCreateListDialog() {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    final nameController = TextEditingController();
    final descriptionController = TextEditingController();
    String selectedColor = '#2196F3'; // Default blue

    final colors = [
      '#2196F3', // Blue
      '#4CAF50', // Green
      '#FF9800', // Orange
      '#9C27B0', // Purple
      '#F44336', // Red
      '#00BCD4', // Cyan
      '#795548', // Brown
      '#607D8B', // Blue Grey
    ];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: isDarkMode ? const Color(0xFF1C1C1E) : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            'Create New List',
            style: GoogleFonts.lora(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: isDarkMode ? Colors.white : Colors.black87,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: nameController,
                style: TextStyle(
                  color: isDarkMode ? Colors.white : Colors.black87,
                ),
                decoration: InputDecoration(
                  labelText: 'List Name',
                  labelStyle: TextStyle(
                    color: isDarkMode
                        ? Colors.white.withOpacity(0.7)
                        : Colors.grey[600],
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: isDarkMode
                          ? Colors.white.withOpacity(0.3)
                          : Colors.grey[300]!,
                    ),
                  ),
                  filled: true,
                  fillColor: isDarkMode ? const Color(0xFF2C2C2E) : Colors.grey,
                ),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: descriptionController,
                style: TextStyle(
                  color: isDarkMode ? Colors.white : Colors.black87,
                ),
                decoration: InputDecoration(
                  labelText: 'Description (Optional)',
                  labelStyle: TextStyle(
                    color: isDarkMode
                        ? Colors.white.withOpacity(0.7)
                        : Colors.grey[600],
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: isDarkMode
                          ? Colors.white.withOpacity(0.3)
                          : Colors.grey[300]!,
                    ),
                  ),
                  filled: true,
                  fillColor: isDarkMode ? const Color(0xFF2C2C2E) : Colors.grey,
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 16),
              Text(
                'Choose Color',
                style: GoogleFonts.lora(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: isDarkMode ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: colors.map((color) {
                  final isSelected = selectedColor == color;
                  return GestureDetector(
                    onTap: () => setDialogState(() => selectedColor = color),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: Color(
                          int.parse(color.replaceFirst('#', '0xFF')),
                        ),
                        shape: BoxShape.circle,
                        border: isSelected
                            ? Border.all(color: Colors.white, width: 3)
                            : null,
                        boxShadow: isSelected
                            ? [BoxShadow(color: Colors.black26, blurRadius: 4)]
                            : null,
                      ),
                      child: isSelected
                          ? const Icon(
                              Icons.check,
                              color: Colors.white,
                              size: 16,
                            )
                          : null,
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Cancel',
                style: GoogleFonts.lora(
                  color: isDarkMode ? Colors.white : Colors.grey[600],
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                if (nameController.text.trim().isEmpty) {
                  _showSnackBar('Please enter a list name');
                  return;
                }

                Navigator.pop(context);

                try {
                  final newList = await BookmarkService.createList(
                    name: nameController.text.trim(),
                    description: descriptionController.text.trim(),
                    color: selectedColor,
                  );

                  setState(() {
                    _lists.add(newList);
                  });

                  // Automatically bookmark the post to the new list
                  await _toggleBookmark(newList, true);

                  _showSnackBar(
                    'List "${newList.name}" created and post added!',
                  );
                } catch (e) {
                  _showSnackBar('Failed to create list: $e');
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text('Create', style: GoogleFonts.lora()),
            ),
          ],
        ),
      ),
    );
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.lora()),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }
}

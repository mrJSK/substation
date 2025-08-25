// lib/screens/bookmarks_screen.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/power_pulse/bookmark_models.dart';
import '../../models/power_pulse/powerpulse_models.dart';
import '../../services/power_pulse_service/bookmark_service.dart'
    show BookmarkService;
import '../../services/power_pulse_service/powerpulse_services.dart';
import '../../widgets/post_card/post_card.dart';
import 'post_detail_screen.dart';

class BookmarksScreen extends StatefulWidget {
  const BookmarksScreen({Key? key}) : super(key: key);

  @override
  State<BookmarksScreen> createState() => _BookmarksScreenState();
}

class _BookmarksScreenState extends State<BookmarksScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  List<BookmarkList> _lists = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 0, vsync: this);
    _loadLists();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadLists() async {
    try {
      // Ensure default list exists
      await BookmarkService.getOrCreateDefaultList();

      BookmarkService.streamUserLists().listen((lists) {
        if (mounted) {
          setState(() {
            _lists = lists;
            _isLoading = false;

            // Update tab controller
            _tabController.dispose();
            _tabController = TabController(length: lists.length, vsync: this);
          });
        }
      });
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

    return Scaffold(
      backgroundColor: isDarkMode ? const Color(0xFF1C1C1E) : Colors.white,
      appBar: AppBar(
        backgroundColor: isDarkMode ? const Color(0xFF2C2C2E) : Colors.white,
        elevation: 0,
        title: Text(
          'Bookmarks',
          style: GoogleFonts.lora(
            fontSize: 22,
            fontWeight: FontWeight.w600,
            color: isDarkMode ? Colors.white : Colors.black87,
          ),
        ),
        actions: [
          IconButton(
            onPressed: _showManageListsDialog,
            icon: Icon(
              Icons.more_vert,
              color: isDarkMode ? Colors.white : Colors.black87,
            ),
            tooltip: 'Manage Lists',
          ),
        ],
        bottom: _lists.isNotEmpty
            ? TabBar(
                controller: _tabController,
                isScrollable: true,
                labelColor: isDarkMode ? Colors.blue[200] : Colors.blue,
                unselectedLabelColor: isDarkMode
                    ? Colors.white.withOpacity(0.6)
                    : Colors.grey,
                indicatorColor: isDarkMode ? Colors.blue : Colors.blue,
                tabs: _lists.map((list) {
                  return Tab(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: _getListColor(list.color),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          list.name,
                          style: GoogleFonts.lora(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: isDarkMode
                                ? Colors.white.withOpacity(0.1)
                                : Colors.grey[200],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${list.bookmarkCount}',
                            style: GoogleFonts.lora(
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              )
            : null,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_lists.isEmpty) {
      return _buildEmptyState();
    }

    return TabBarView(
      controller: _tabController,
      children: _lists.map((list) => _buildListView(list)).toList(),
    );
  }

  Widget _buildEmptyState() {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.bookmark_border,
              size: 80,
              color: isDarkMode
                  ? Colors.white.withOpacity(0.4)
                  : Colors.grey[400],
            ),
            const SizedBox(height: 24),
            Text(
              'No Bookmarks Yet',
              style: GoogleFonts.lora(
                fontSize: 24,
                fontWeight: FontWeight.w600,
                color: isDarkMode ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Start saving posts by tapping the bookmark icon on any post.',
              style: GoogleFonts.lora(
                fontSize: 16,
                color: isDarkMode
                    ? Colors.white.withOpacity(0.7)
                    : Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.explore),
              label: Text('Explore Posts', style: GoogleFonts.lora()),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(25),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildListView(BookmarkList list) {
    return StreamBuilder<List<Bookmark>>(
      stream: BookmarkService.streamBookmarksInList(list.id),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return _buildErrorState('Error loading bookmarks: ${snapshot.error}');
        }

        final bookmarks = snapshot.data ?? [];

        if (bookmarks.isEmpty) {
          return _buildEmptyListState(list);
        }

        return RefreshIndicator(
          onRefresh: () async {
            setState(() {});
          },
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: bookmarks.length,
            itemBuilder: (context, index) {
              final bookmark = bookmarks[index];
              return _buildBookmarkItem(bookmark);
            },
          ),
        );
      },
    );
  }

  Widget _buildEmptyListState(BookmarkList list) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: _getListColor(list.color).withOpacity(0.1),
                shape: BoxShape.circle,
                border: Border.all(
                  color: _getListColor(list.color).withOpacity(0.3),
                  width: 2,
                ),
              ),
              child: Icon(
                list.isDefault ? Icons.bookmark : Icons.folder,
                size: 48,
                color: _getListColor(list.color),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No posts in ${list.name}',
              style: GoogleFonts.lora(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: isDarkMode ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Bookmark posts to this list to see them here.',
              style: GoogleFonts.lora(
                fontSize: 14,
                color: isDarkMode
                    ? Colors.white.withOpacity(0.7)
                    : Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(String error) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: isDarkMode
                  ? Colors.white.withOpacity(0.4)
                  : Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'Something went wrong',
              style: GoogleFonts.lora(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: isDarkMode ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              style: GoogleFonts.lora(
                fontSize: 14,
                color: isDarkMode
                    ? Colors.white.withOpacity(0.7)
                    : Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => setState(() {}),
              child: Text('Try Again', style: GoogleFonts.lora()),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBookmarkItem(Bookmark bookmark) {
    return FutureBuilder<Post?>(
      future: PostService.getPost(bookmark.postId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingCard();
        }

        if (snapshot.hasError || !snapshot.hasData) {
          return _buildErrorCard(bookmark);
        }

        final post = snapshot.data!;
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: PostCard(
            post: post,
            onTap: () => _navigateToPost(post),
            isCompact: true,
          ),
        );
      },
    );
  }

  Widget _buildLoadingCard() {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return Container(
      height: 120,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF2C2C2E) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDarkMode ? Colors.white.withOpacity(0.1) : Colors.grey[200]!,
        ),
      ),
      child: const Center(child: CircularProgressIndicator()),
    );
  }

  Widget _buildErrorCard(Bookmark bookmark) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF2C2C2E) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDarkMode ? Colors.white.withOpacity(0.1) : Colors.grey[200]!,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.error_outline,
            color: isDarkMode ? Colors.white.withOpacity(0.6) : Colors.grey,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Failed to load post',
                  style: GoogleFonts.lora(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: isDarkMode ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'This post may have been deleted',
                  style: GoogleFonts.lora(
                    fontSize: 12,
                    color: isDarkMode
                        ? Colors.white.withOpacity(0.6)
                        : Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () => _removeBookmark(bookmark),
            child: Text('Remove', style: GoogleFonts.lora(color: Colors.red)),
          ),
        ],
      ),
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

  void _navigateToPost(Post post) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PostDetailScreen(postId: post.id),
      ),
    );
  }

  Future<void> _removeBookmark(Bookmark bookmark) async {
    try {
      await BookmarkService.removeBookmark(
        postId: bookmark.postId,
        listId: bookmark.listId,
      );
      _showSnackBar('Bookmark removed');
    } catch (e) {
      _showSnackBar('Failed to remove bookmark: $e');
    }
  }

  void _showManageListsDialog() {
    // Implementation for managing lists (edit, delete, reorder)
    // This can be expanded based on your needs
    _showSnackBar('Manage lists feature coming soon!');
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

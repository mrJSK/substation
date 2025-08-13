// lib/screens/community/blog_articles_list_screen.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../models/community_models.dart';
import '../../models/user_model.dart';
import '../../services/community_service.dart';
import 'blog_article_screen.dart';
import 'knowledge_post_detail_screen.dart';

// Medium-inspired theme constants
class MediumTheme {
  static const Color primaryText = Color(0xFF292929);
  static const Color secondaryText = Color(0xFF757575);
  static const Color lightGray = Color(0xFFF2F2F2);
  static const Color mediumGray = Color(0xFFE6E6E6);
  static const Color accent = Color(0xFF1A8917);
  static const Color background = Color(0xFFFDFDFD);
}

class BlogArticlesListScreen extends StatefulWidget {
  final AppUser currentUser;

  const BlogArticlesListScreen({Key? key, required this.currentUser})
    : super(key: key);

  @override
  _BlogArticlesListScreenState createState() => _BlogArticlesListScreenState();
}

class _BlogArticlesListScreenState extends State<BlogArticlesListScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  List<KnowledgePost> _allPosts = [];
  List<KnowledgePost> _myPosts = [];
  List<KnowledgePost> _draftPosts = [];

  List<KnowledgePost> _filteredAllPosts = [];
  List<KnowledgePost> _filteredMyPosts = [];
  List<KnowledgePost> _filteredDraftPosts = [];

  bool _isLoading = false;
  bool _isSearching = false;
  String _currentSearchQuery = '';
  String _selectedCategory = 'all';

  // Auto-suggest data
  List<String> _searchSuggestions = [];
  bool _showSuggestions = false;
  OverlayEntry? _overlayEntry;
  final LayerLink _layerLink = LayerLink();

  final List<String> _categories = [
    'all',
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
    _tabController = TabController(length: 3, vsync: this);
    _loadArticles();
    _searchController.addListener(_onSearchChanged);
    _searchFocusNode.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.removeListener(_onSearchChanged);
    _searchFocusNode.removeListener(_onFocusChanged);
    _searchController.dispose();
    _searchFocusNode.dispose();
    _removeOverlay();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text;
    setState(() {
      _currentSearchQuery = query;
      _filterPosts();
    });

    if (query.isNotEmpty && query.length >= 2) {
      _generateSearchSuggestions(query);
      _showSuggestionsOverlay();
    } else {
      _hideSuggestionsOverlay();
    }
  }

  void _onFocusChanged() {
    if (!_searchFocusNode.hasFocus) {
      Future.delayed(Duration(milliseconds: 200), () {
        _hideSuggestionsOverlay();
      });
    }
  }

  void _generateSearchSuggestions(String query) {
    final suggestions = <String>{};
    final queryLower = query.toLowerCase();

    for (final post in _allPosts + _myPosts + _draftPosts) {
      if (post.title.toLowerCase().contains(queryLower)) {
        suggestions.add(post.title);
      }

      for (final tag in post.tags) {
        if (tag.toLowerCase().contains(queryLower)) {
          suggestions.add(tag);
        }
      }

      if (post.authorName.toLowerCase().contains(queryLower)) {
        suggestions.add(post.authorName);
      }

      if (_getCategoryDisplayName(
        post.category,
      ).toLowerCase().contains(queryLower)) {
        suggestions.add(_getCategoryDisplayName(post.category));
      }
    }

    _searchSuggestions =
        suggestions
            .where((s) => s.toLowerCase().contains(queryLower))
            .take(5)
            .toList()
          ..sort((a, b) {
            final aIndex = a.toLowerCase().indexOf(queryLower);
            final bIndex = b.toLowerCase().indexOf(queryLower);
            return aIndex.compareTo(bIndex);
          });
  }

  void _showSuggestionsOverlay() {
    if (_searchSuggestions.isEmpty || _overlayEntry != null) return;

    _overlayEntry = _createOverlayEntry();
    Overlay.of(context).insert(_overlayEntry!);
    setState(() {
      _showSuggestions = true;
    });
  }

  void _hideSuggestionsOverlay() {
    _removeOverlay();
    setState(() {
      _showSuggestions = false;
    });
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  OverlayEntry _createOverlayEntry() {
    RenderBox renderBox = context.findRenderObject() as RenderBox;
    var size = renderBox.size;

    return OverlayEntry(
      builder: (context) => Positioned(
        width: size.width - 48,
        child: CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          offset: Offset(24, 110),
          child: Material(
            elevation: 12,
            borderRadius: BorderRadius.circular(12),
            shadowColor: Colors.black.withOpacity(0.1),
            child: Container(
              constraints: BoxConstraints(maxHeight: 240),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: MediumTheme.lightGray, width: 0.5),
              ),
              child: ListView.builder(
                padding: EdgeInsets.symmetric(vertical: 8),
                shrinkWrap: true,
                itemCount: _searchSuggestions.length,
                itemBuilder: (context, index) {
                  final suggestion = _searchSuggestions[index];
                  return InkWell(
                    onTap: () {
                      _searchController.text = suggestion;
                      _hideSuggestionsOverlay();
                      _searchFocusNode.unfocus();
                    },
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.search_outlined,
                            size: 18,
                            color: MediumTheme.secondaryText,
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: RichText(
                              text: TextSpan(
                                children: _highlightSearchTerm(
                                  suggestion,
                                  _currentSearchQuery,
                                ),
                                style: TextStyle(
                                  color: MediumTheme.primaryText,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<TextSpan> _highlightSearchTerm(String text, String searchTerm) {
    if (searchTerm.isEmpty) {
      return [TextSpan(text: text)];
    }

    final List<TextSpan> spans = [];
    final String lowerText = text.toLowerCase();
    final String lowerSearchTerm = searchTerm.toLowerCase();

    int start = 0;
    int indexOfHighlight = lowerText.indexOf(lowerSearchTerm, start);

    while (indexOfHighlight >= 0) {
      if (indexOfHighlight > start) {
        spans.add(TextSpan(text: text.substring(start, indexOfHighlight)));
      }

      spans.add(
        TextSpan(
          text: text.substring(
            indexOfHighlight,
            indexOfHighlight + searchTerm.length,
          ),
          style: TextStyle(
            backgroundColor: Colors.yellow[100],
            fontWeight: FontWeight.w600,
          ),
        ),
      );

      start = indexOfHighlight + searchTerm.length;
      indexOfHighlight = lowerText.indexOf(lowerSearchTerm, start);
    }

    if (start < text.length) {
      spans.add(TextSpan(text: text.substring(start)));
    }

    return spans;
  }

  Future<void> _loadArticles() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final allPosts = await CommunityService.getApprovedPosts(limit: 100);
      final myPosts = await CommunityService.getPostsByAuthor(
        widget.currentUser.uid,
      );

      setState(() {
        _allPosts = allPosts;
        _myPosts = myPosts.where((p) => p.status != PostStatus.draft).toList();
        _draftPosts = myPosts
            .where((p) => p.status == PostStatus.draft)
            .toList();
        _filterPosts();
      });
    } catch (e) {
      _showErrorSnackBar('Failed to load articles: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _filterPosts() {
    _filteredAllPosts = _filterPostsList(_allPosts);
    _filteredMyPosts = _filterPostsList(_myPosts);
    _filteredDraftPosts = _filterPostsList(_draftPosts);
  }

  List<KnowledgePost> _filterPostsList(List<KnowledgePost> posts) {
    return posts.where((post) {
      bool matchesSearch = true;
      bool matchesCategory = true;

      if (_currentSearchQuery.isNotEmpty) {
        final query = _currentSearchQuery.toLowerCase();
        matchesSearch =
            post.title.toLowerCase().contains(query) ||
            post.summary.toLowerCase().contains(query) ||
            post.content.toLowerCase().contains(query) ||
            post.tags.any((tag) => tag.toLowerCase().contains(query)) ||
            post.authorName.toLowerCase().contains(query);
      }

      if (_selectedCategory != 'all') {
        matchesCategory = post.category == _selectedCategory;
      }

      return matchesSearch && matchesCategory;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MediumTheme.background,
      appBar: AppBar(
        title: _isSearching
            ? CompositedTransformTarget(
                link: _layerLink,
                child: Container(
                  height: 42,
                  decoration: BoxDecoration(
                    color: MediumTheme.lightGray,
                    borderRadius: BorderRadius.circular(21),
                  ),
                  child: TextField(
                    controller: _searchController,
                    focusNode: _searchFocusNode,
                    autofocus: true,
                    decoration: InputDecoration(
                      hintText: 'Search articles, tags, authors...',
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      hintStyle: TextStyle(
                        color: MediumTheme.secondaryText,
                        fontSize: 15,
                      ),
                      suffixIcon: _currentSearchQuery.isNotEmpty
                          ? IconButton(
                              icon: Icon(Icons.clear, size: 20),
                              onPressed: () {
                                _searchController.clear();
                                _hideSuggestionsOverlay();
                              },
                            )
                          : null,
                    ),
                    style: TextStyle(
                      color: MediumTheme.primaryText,
                      fontSize: 15,
                    ),
                  ),
                ),
              )
            : Text(
                'Stories & Articles',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: MediumTheme.primaryText,
                ),
              ),
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.white,
        iconTheme: IconThemeData(color: MediumTheme.primaryText),
        actions: [
          IconButton(
            icon: Icon(
              _isSearching ? Icons.close_outlined : Icons.search_outlined,
              color: MediumTheme.secondaryText,
            ),
            onPressed: _toggleSearch,
          ),
          if (!_isSearching)
            PopupMenuButton<String>(
              icon: Icon(Icons.tune_outlined, color: MediumTheme.secondaryText),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              onSelected: (category) {
                setState(() {
                  _selectedCategory = category;
                  _filterPosts();
                });
              },
              itemBuilder: (context) => _categories.map((category) {
                return PopupMenuItem<String>(
                  value: category,
                  child: Row(
                    children: [
                      Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _selectedCategory == category
                              ? MediumTheme.accent
                              : Colors.transparent,
                          border: Border.all(
                            color: _selectedCategory == category
                                ? MediumTheme.accent
                                : MediumTheme.secondaryText,
                            width: 2,
                          ),
                        ),
                        child: _selectedCategory == category
                            ? Icon(Icons.check, size: 10, color: Colors.white)
                            : null,
                      ),
                      SizedBox(width: 12),
                      Text(_getCategoryDisplayName(category)),
                    ],
                  ),
                );
              }).toList(),
            ),
          if (!_isSearching)
            Padding(
              padding: EdgeInsets.only(right: 8),
              child: CircleAvatar(
                radius: 18,
                backgroundColor: MediumTheme.lightGray,
                child: Text(
                  widget.currentUser.name.isNotEmpty
                      ? widget.currentUser.name[0].toUpperCase()
                      : 'U',
                  style: TextStyle(
                    color: MediumTheme.primaryText,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
        ],
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(
            48 +
                (_currentSearchQuery.isNotEmpty || _selectedCategory != 'all'
                    ? 50
                    : 0),
          ),
          child: Column(
            children: [
              Container(
                color: Colors.white,
                child: TabBar(
                  controller: _tabController,
                  labelColor: MediumTheme.accent,
                  unselectedLabelColor: MediumTheme.secondaryText,
                  indicatorColor: MediumTheme.accent,
                  indicatorWeight: 2,
                  labelStyle: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                  unselectedLabelStyle: TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                  ),
                  tabs: [
                    Tab(text: 'All (${_filteredAllPosts.length})'),
                    Tab(text: 'Mine (${_filteredMyPosts.length})'),
                    Tab(text: 'Drafts (${_filteredDraftPosts.length})'),
                  ],
                ),
              ),
              if (_currentSearchQuery.isNotEmpty || _selectedCategory != 'all')
                _buildActiveFilters(),
            ],
          ),
        ),
      ),
      body: GestureDetector(
        onTap: () {
          _hideSuggestionsOverlay();
          _searchFocusNode.unfocus();
        },
        child: TabBarView(
          controller: _tabController,
          children: [
            _buildArticlesList(_filteredAllPosts, showAuthor: true),
            _buildArticlesList(_filteredMyPosts, showAuthor: false),
            _buildArticlesList(
              _filteredDraftPosts,
              showAuthor: false,
              isDraft: true,
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _createNewArticle,
        backgroundColor: MediumTheme.accent,
        child: Icon(Icons.edit_outlined, color: Colors.white, size: 22),
        elevation: 6,
      ),
    );
  }

  Widget _buildActiveFilters() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      color: MediumTheme.lightGray.withOpacity(0.3),
      child: Row(
        children: [
          Text(
            'Filters:',
            style: TextStyle(
              fontSize: 13,
              color: MediumTheme.secondaryText,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Row(
              children: [
                if (_currentSearchQuery.isNotEmpty)
                  Container(
                    margin: EdgeInsets.only(right: 8),
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: MediumTheme.accent.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: MediumTheme.accent.withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.search, size: 14, color: MediumTheme.accent),
                        SizedBox(width: 6),
                        Text(
                          '"${_currentSearchQuery}"',
                          style: TextStyle(
                            fontSize: 12,
                            color: MediumTheme.accent,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        SizedBox(width: 6),
                        InkWell(
                          onTap: () => _searchController.clear(),
                          child: Icon(
                            Icons.close,
                            size: 14,
                            color: MediumTheme.accent,
                          ),
                        ),
                      ],
                    ),
                  ),
                if (_selectedCategory != 'all')
                  Container(
                    margin: EdgeInsets.only(right: 8),
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.orange.withOpacity(0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.category_outlined,
                          size: 14,
                          color: Colors.orange,
                        ),
                        SizedBox(width: 6),
                        Text(
                          _getCategoryDisplayName(_selectedCategory),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.orange,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        SizedBox(width: 6),
                        InkWell(
                          onTap: () {
                            setState(() {
                              _selectedCategory = 'all';
                              _filterPosts();
                            });
                          },
                          child: Icon(
                            Icons.close,
                            size: 14,
                            color: Colors.orange,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          TextButton(
            onPressed: _clearAllFilters,
            child: Text(
              'Clear all',
              style: TextStyle(
                fontSize: 12,
                color: Colors.red[400],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildArticlesList(
    List<KnowledgePost> posts, {
    required bool showAuthor,
    bool isDraft = false,
  }) {
    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(
          color: MediumTheme.accent,
          strokeWidth: 2,
        ),
      );
    }

    if (posts.isEmpty) {
      return _buildEmptyState(isDraft);
    }

    return RefreshIndicator(
      onRefresh: _loadArticles,
      color: MediumTheme.accent,
      child: ListView.builder(
        padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        itemCount: posts.length,
        itemBuilder: (context, index) {
          return _buildMediumStyleCard(
            posts[index],
            showAuthor: showAuthor,
            isDraft: isDraft,
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(bool isDraft) {
    final hasActiveFilters =
        _currentSearchQuery.isNotEmpty || _selectedCategory != 'all';

    return Center(
      child: Padding(
        padding: EdgeInsets.all(48),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: MediumTheme.lightGray,
                shape: BoxShape.circle,
              ),
              child: Icon(
                hasActiveFilters
                    ? Icons.search_off_outlined
                    : (isDraft ? Icons.drafts : Icons.article_outlined),
                size: 48,
                color: MediumTheme.secondaryText,
              ),
            ),
            SizedBox(height: 32),
            Text(
              hasActiveFilters
                  ? 'No articles found'
                  : (isDraft ? 'No drafts yet' : 'No articles yet'),
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w600,
                color: MediumTheme.primaryText,
              ),
            ),
            SizedBox(height: 16),
            Text(
              hasActiveFilters
                  ? 'Try adjusting your search or filters'
                  : (isDraft
                        ? 'Your draft articles will appear here'
                        : 'Start sharing your knowledge with the community'),
              style: TextStyle(
                color: MediumTheme.secondaryText,
                fontSize: 16,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 32),
            if (hasActiveFilters)
              OutlinedButton.icon(
                onPressed: _clearAllFilters,
                icon: Icon(Icons.clear_all, size: 18),
                label: Text('Clear filters'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: MediumTheme.accent,
                  side: BorderSide(color: MediumTheme.accent),
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              )
            else
              ElevatedButton.icon(
                onPressed: _createNewArticle,
                icon: Icon(Icons.edit_outlined, size: 18),
                label: Text('Write an article'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: MediumTheme.accent,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  elevation: 0,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMediumStyleCard(
    KnowledgePost post, {
    required bool showAuthor,
    bool isDraft = false,
  }) {
    return Container(
      margin: EdgeInsets.only(bottom: 48),
      child: InkWell(
        onTap: () => _navigateToArticle(post),
        borderRadius: BorderRadius.circular(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Author info and date (Medium style - at the top)
            Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: MediumTheme.lightGray,
                  child: Text(
                    post.authorName.isNotEmpty
                        ? post.authorName[0].toUpperCase()
                        : 'A',
                    style: TextStyle(
                      color: MediumTheme.primaryText,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (showAuthor)
                        Text(
                          post.authorName,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: MediumTheme.primaryText,
                          ),
                        ),
                      Text(
                        '${_formatDate(post.createdAt)} • ${_getReadTime(post.content)} min read',
                        style: TextStyle(
                          fontSize: 13,
                          color: MediumTheme.secondaryText,
                        ),
                      ),
                    ],
                  ),
                ),
                if (!showAuthor && post.authorId == widget.currentUser.uid)
                  PopupMenuButton<String>(
                    icon: Icon(
                      Icons.more_horiz,
                      color: MediumTheme.secondaryText,
                    ),
                    onSelected: (value) => _handleMenuAction(value, post),
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit_outlined, size: 18),
                            SizedBox(width: 12),
                            Text('Edit'),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(
                              Icons.delete_outline,
                              size: 18,
                              color: Colors.red,
                            ),
                            SizedBox(width: 12),
                            Text('Delete', style: TextStyle(color: Colors.red)),
                          ],
                        ),
                      ),
                    ],
                  ),
              ],
            ),

            SizedBox(height: 16),

            // Title - larger and more prominent
            Text(
              post.title,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w600,
                height: 1.2,
                color: MediumTheme.primaryText,
                letterSpacing: -0.8,
              ),
            ),

            SizedBox(height: 16),

            // Featured image if available (assuming first attachment is image)
            if (post.attachments.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  post.attachments[0].fileUrl,
                  height: 180,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) =>
                      SizedBox.shrink(),
                ),
              ),

            SizedBox(height: 16),

            // Summary with Medium's style
            Text(
              post.summary,
              style: TextStyle(
                fontSize: 15,
                height: 1.6,
                color: MediumTheme.secondaryText,
                letterSpacing: -0.2,
              ),
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
            ),

            SizedBox(height: 20),

            // Bottom meta info
            Row(
              children: [
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: MediumTheme.lightGray,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    _getCategoryDisplayName(post.category),
                    style: TextStyle(
                      fontSize: 12,
                      color: MediumTheme.secondaryText,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                if (post.tags.isNotEmpty) ...[
                  SizedBox(width: 8),
                  ...post.tags
                      .take(2)
                      .map(
                        (tag) => Container(
                          margin: EdgeInsets.only(right: 8),
                          padding: EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: MediumTheme.accent.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            tag,
                            style: TextStyle(
                              fontSize: 11,
                              color: MediumTheme.accent,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                ],
                Spacer(),
                Row(
                  children: [
                    if (post.attachments.isNotEmpty) ...[
                      Icon(
                        Icons.attach_file_outlined,
                        size: 16,
                        color: MediumTheme.secondaryText,
                      ),
                      SizedBox(width: 4),
                      Text(
                        '${post.attachments.length}',
                        style: TextStyle(
                          fontSize: 12,
                          color: MediumTheme.secondaryText,
                        ),
                      ),
                      SizedBox(width: 16),
                    ],
                    Icon(
                      Icons.favorite_border,
                      size: 16,
                      color: MediumTheme.secondaryText,
                    ),
                    SizedBox(width: 4),
                    Text(
                      '${post.metrics.likes}',
                      style: TextStyle(
                        fontSize: 12,
                        color: MediumTheme.secondaryText,
                      ),
                    ),
                  ],
                ),
              ],
            ),

            // Status indicator
            if (post.status != PostStatus.approved) ...[
              SizedBox(height: 16),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: _getStatusColor(post.status).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _getStatusDisplayName(post.status),
                  style: TextStyle(
                    color: _getStatusColor(post.status),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],

            // Removed subtle divider for more minimalist design with white space
          ],
        ),
      ),
    );
  }

  int _getReadTime(String content) {
    // Average reading speed: 200-250 words per minute
    final wordCount = content.split(' ').length;
    return (wordCount / 225).ceil().clamp(1, 99);
  }

  void _toggleSearch() {
    setState(() {
      _isSearching = !_isSearching;
      if (!_isSearching) {
        _searchController.clear();
        _currentSearchQuery = '';
        _filterPosts();
        _hideSuggestionsOverlay();
      }
    });
  }

  void _clearAllFilters() {
    setState(() {
      _searchController.clear();
      _selectedCategory = 'all';
      _currentSearchQuery = '';
      _filterPosts();
    });
    _hideSuggestionsOverlay();
  }

  String _getCategoryDisplayName(String category) {
    switch (category) {
      case 'all':
        return 'All Categories';
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

  Color _getStatusColor(PostStatus status) {
    switch (status) {
      case PostStatus.draft:
        return Colors.grey[600]!;
      case PostStatus.pending:
        return Colors.orange;
      case PostStatus.approved:
        return MediumTheme.accent;
      case PostStatus.rejected:
        return Colors.red;
      case PostStatus.archived:
        return Colors.grey;
    }
  }

  String _getStatusDisplayName(PostStatus status) {
    switch (status) {
      case PostStatus.draft:
        return 'Draft';
      case PostStatus.pending:
        return 'Under Review';
      case PostStatus.approved:
        return 'Published';
      case PostStatus.rejected:
        return 'Rejected';
      case PostStatus.archived:
        return 'Archived';
    }
  }

  String _formatDate(Timestamp timestamp) {
    final date = timestamp.toDate();
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 7) {
      final months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];
      return '${months[date.month - 1]} ${date.day}';
    } else if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else {
      return 'Just now';
    }
  }

  void _createNewArticle() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            BlogArticleScreen(currentUser: widget.currentUser),
      ),
    ).then((_) => _loadArticles());
  }

  void _navigateToArticle(KnowledgePost post) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => KnowledgePostDetailScreen(
          postId: post.id!,
          currentUser: widget.currentUser,
        ),
      ),
    );
  }

  void _handleMenuAction(String action, KnowledgePost post) {
    switch (action) {
      case 'edit':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => BlogArticleScreen(
              currentUser: widget.currentUser,
              existingPost: post,
            ),
          ),
        ).then((_) => _loadArticles());
        break;
      case 'delete':
        _showDeleteConfirmation(post);
        break;
    }
  }

  void _showDeleteConfirmation(KnowledgePost post) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Delete Article',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        content: Text('Are you sure you want to delete "${post.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteArticle(post);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteArticle(KnowledgePost post) async {
    try {
      final archivedPost = post.copyWith(status: PostStatus.archived);
      await CommunityService.updateKnowledgePost(post.id!, archivedPost);
      _showSuccessSnackBar('Article deleted successfully');
      _loadArticles();
    } catch (e) {
      _showErrorSnackBar('Failed to delete article: $e');
    }
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: MediumTheme.accent,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red[400],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}

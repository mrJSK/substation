// lib/screens/community/blog_articles_list_screen.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../models/community_models.dart';
import '../../models/user_model.dart';
import '../../services/community_service.dart';
import 'blog_article_screen.dart';
import 'knowledge_post_detail_screen.dart';

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

    // Generate suggestions from all posts
    for (final post in _allPosts + _myPosts + _draftPosts) {
      // Title suggestions
      if (post.title.toLowerCase().contains(queryLower)) {
        suggestions.add(post.title);
      }

      // Tag suggestions
      for (final tag in post.tags) {
        if (tag.toLowerCase().contains(queryLower)) {
          suggestions.add(tag);
        }
      }

      // Author suggestions
      if (post.authorName.toLowerCase().contains(queryLower)) {
        suggestions.add(post.authorName);
      }

      // Category suggestions
      if (_getCategoryDisplayName(
        post.category,
      ).toLowerCase().contains(queryLower)) {
        suggestions.add(_getCategoryDisplayName(post.category));
      }
    }

    // Limit to 5 suggestions and sort by relevance
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
        width: size.width - 32,
        child: CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          offset: Offset(16, 120),
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              constraints: BoxConstraints(maxHeight: 200),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: _searchSuggestions.length,
                itemBuilder: (context, index) {
                  final suggestion = _searchSuggestions[index];
                  return ListTile(
                    dense: true,
                    leading: Icon(
                      Icons.search,
                      size: 16,
                      color: Colors.grey[600],
                    ),
                    title: RichText(
                      text: TextSpan(
                        children: _highlightSearchTerm(
                          suggestion,
                          _currentSearchQuery,
                        ),
                        style: TextStyle(color: Colors.black87, fontSize: 14),
                      ),
                    ),
                    onTap: () {
                      _searchController.text = suggestion;
                      _hideSuggestionsOverlay();
                      _searchFocusNode.unfocus();
                    },
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
            backgroundColor: Colors.yellow[200],
            fontWeight: FontWeight.bold,
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
      backgroundColor: Color(0xFFFAFAFA),
      appBar: AppBar(
        title: _isSearching
            ? CompositedTransformTarget(
                link: _layerLink,
                child: TextField(
                  controller: _searchController,
                  focusNode: _searchFocusNode,
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: 'Search articles, tags, authors...',
                    border: InputBorder.none,
                    hintStyle: TextStyle(color: Colors.grey[400]),
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
                  style: TextStyle(color: Colors.black87),
                ),
              )
            : Text(
                'Blog & Articles',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.black87),
        actions: [
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search),
            onPressed: _toggleSearch,
          ),
          if (!_isSearching)
            PopupMenuButton<String>(
              icon: Icon(Icons.filter_list),
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
                      Icon(
                        _selectedCategory == category
                            ? Icons.radio_button_checked
                            : Icons.radio_button_unchecked,
                        size: 18,
                        color: Theme.of(context).primaryColor,
                      ),
                      SizedBox(width: 8),
                      Text(_getCategoryDisplayName(category)),
                    ],
                  ),
                );
              }).toList(),
            ),
        ],
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(
            48 +
                (_currentSearchQuery.isNotEmpty || _selectedCategory != 'all'
                    ? 40
                    : 0),
          ),
          child: Column(
            children: [
              TabBar(
                controller: _tabController,
                labelColor: Theme.of(context).primaryColor,
                unselectedLabelColor: Colors.grey[600],
                indicatorColor: Theme.of(context).primaryColor,
                tabs: [
                  Tab(text: 'All Articles (${_filteredAllPosts.length})'),
                  Tab(text: 'My Articles (${_filteredMyPosts.length})'),
                  Tab(text: 'Drafts (${_filteredDraftPosts.length})'),
                ],
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createNewArticle,
        backgroundColor: Theme.of(context).primaryColor,
        icon: Icon(Icons.add, color: Colors.white),
        label: Text(
          'New Article',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Widget _buildActiveFilters() {
    return Container(
      height: 40,
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      color: Colors.grey[50],
      child: Row(
        children: [
          Text(
            'Active filters:',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(width: 8),
          Expanded(
            child: Row(
              children: [
                if (_currentSearchQuery.isNotEmpty)
                  Container(
                    margin: EdgeInsets.only(right: 8),
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Theme.of(context).primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Theme.of(context).primaryColor.withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.search,
                          size: 12,
                          color: Theme.of(context).primaryColor,
                        ),
                        SizedBox(width: 4),
                        Text(
                          '"${_currentSearchQuery}"',
                          style: TextStyle(
                            fontSize: 11,
                            color: Theme.of(context).primaryColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        SizedBox(width: 4),
                        InkWell(
                          onTap: () {
                            _searchController.clear();
                          },
                          child: Icon(
                            Icons.close,
                            size: 12,
                            color: Theme.of(context).primaryColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                if (_selectedCategory != 'all')
                  Container(
                    margin: EdgeInsets.only(right: 8),
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.orange.withOpacity(0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.category, size: 12, color: Colors.orange),
                        SizedBox(width: 4),
                        Text(
                          _getCategoryDisplayName(_selectedCategory),
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.orange,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        SizedBox(width: 4),
                        InkWell(
                          onTap: () {
                            setState(() {
                              _selectedCategory = 'all';
                              _filterPosts();
                            });
                          },
                          child: Icon(
                            Icons.close,
                            size: 12,
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
              'Clear All',
              style: TextStyle(
                fontSize: 11,
                color: Colors.red,
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
      return Center(child: CircularProgressIndicator());
    }

    if (posts.isEmpty) {
      return _buildEmptyState(isDraft);
    }

    return RefreshIndicator(
      onRefresh: _loadArticles,
      child: ListView.builder(
        padding: EdgeInsets.all(16),
        itemCount: posts.length,
        itemBuilder: (context, index) {
          return _buildArticleCard(
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
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            hasActiveFilters
                ? Icons.search_off
                : (isDraft ? Icons.pending : Icons.article_outlined),
            size: 80,
            color: Colors.grey[400],
          ),
          SizedBox(height: 16),
          Text(
            hasActiveFilters
                ? 'No articles found'
                : (isDraft ? 'No drafts yet' : 'No articles yet'),
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey[600],
            ),
          ),
          SizedBox(height: 8),
          Text(
            hasActiveFilters
                ? 'Try adjusting your search or filters'
                : (isDraft
                      ? 'Your draft articles will appear here'
                      : 'Start sharing knowledge with the community'),
            style: TextStyle(color: Colors.grey[500], fontSize: 14),
          ),
          SizedBox(height: 24),
          if (hasActiveFilters)
            OutlinedButton.icon(
              onPressed: _clearAllFilters,
              icon: Icon(Icons.clear_all),
              label: Text('Clear Filters'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Theme.of(context).primaryColor,
              ),
            )
          else
            ElevatedButton.icon(
              onPressed: _createNewArticle,
              icon: Icon(Icons.add),
              label: Text('Create Article'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).primaryColor,
                foregroundColor: Colors.white,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildArticleCard(
    KnowledgePost post, {
    required bool showAuthor,
    bool isDraft = false,
  }) {
    return Card(
      margin: EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _navigateToArticle(post),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                  SizedBox(width: 8),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _getCategoryDisplayName(post.category),
                      style: TextStyle(
                        color: Colors.blue,
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Spacer(),
                  if (!showAuthor && post.authorId == widget.currentUser.uid)
                    PopupMenuButton<String>(
                      onSelected: (value) => _handleMenuAction(value, post),
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          value: 'edit',
                          child: Row(
                            children: [
                              Icon(Icons.edit, size: 16),
                              SizedBox(width: 8),
                              Text('Edit'),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete, size: 16, color: Colors.red),
                              SizedBox(width: 8),
                              Text(
                                'Delete',
                                style: TextStyle(color: Colors.red),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                ],
              ),
              SizedBox(height: 12),
              Text(
                post.title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              SizedBox(height: 8),
              Text(
                post.summary,
                style: TextStyle(color: Colors.grey[600], fontSize: 14),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              SizedBox(height: 12),
              if (post.tags.isNotEmpty)
                Wrap(
                  spacing: 6,
                  children: post.tags.take(3).map((tag) {
                    return Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        tag,
                        style: TextStyle(fontSize: 11, color: Colors.grey[700]),
                      ),
                    );
                  }).toList(),
                ),
              SizedBox(height: 12),
              Row(
                children: [
                  if (showAuthor) ...[
                    Text(
                      'By ${post.authorName}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(width: 16),
                  ],
                  Text(
                    _formatDate(post.createdAt),
                    style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                  ),
                  Spacer(),
                  if (post.attachments.isNotEmpty) ...[
                    Icon(Icons.attach_file, size: 16, color: Colors.grey[500]),
                    SizedBox(width: 4),
                    Text(
                      '${post.attachments.length}',
                      style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                    ),
                    SizedBox(width: 12),
                  ],
                  Icon(Icons.visibility, size: 16, color: Colors.grey[500]),
                  SizedBox(width: 4),
                  Text(
                    '${post.metrics.views}',
                    style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                  ),
                  SizedBox(width: 12),
                  Icon(Icons.thumb_up, size: 16, color: Colors.grey[500]),
                  SizedBox(width: 4),
                  Text(
                    '${post.metrics.likes}',
                    style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
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
        return Colors.grey;
      case PostStatus.pending:
        return Colors.orange;
      case PostStatus.approved:
        return Colors.green;
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
        return 'Pending';
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
      return '${date.day}/${date.month}/${date.year}';
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
        title: Text('Delete Article'),
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
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
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

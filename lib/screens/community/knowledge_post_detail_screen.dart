// lib/screens/community/knowledge_post_detail_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/community_models.dart';
import '../../models/user_model.dart';
import '../../services/community_service.dart';
import 'blog_article_screen.dart';

// Medium-inspired theme constants (matching the other screens)
class MediumTheme {
  static const Color primaryText = Color(0xFF292929);
  static const Color secondaryText = Color(0xFF757575);
  static const Color lightGray = Color(0xFFF2F2F2);
  static const Color mediumGray = Color(0xFFE6E6E6);
  static const Color accent = Color(0xFF1A8917);
  static const Color background = Color(0xFFFDFDFD);
  static const Color cardBackground = Colors.white;
}

class KnowledgePostDetailScreen extends StatefulWidget {
  final String postId;
  final AppUser currentUser;

  const KnowledgePostDetailScreen({
    Key? key,
    required this.postId,
    required this.currentUser,
  }) : super(key: key);

  @override
  _KnowledgePostDetailScreenState createState() =>
      _KnowledgePostDetailScreenState();
}

class _KnowledgePostDetailScreenState extends State<KnowledgePostDetailScreen> {
  KnowledgePost? _post;
  List<PostComment> _comments = [];
  bool _isLoading = true;
  bool _isLiked = false;
  bool _isCommenting = false;
  final TextEditingController _commentController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadPost();
    _loadComments();
    _incrementViewCount();
  }

  @override
  void dispose() {
    _commentController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadPost() async {
    try {
      final post = await CommunityService.getKnowledgePost(widget.postId);
      if (post != null) {
        setState(() {
          _post = post;
          _isLiked = post.metrics.likedBy.contains(widget.currentUser.uid);
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
        });
        _showErrorSnackBar('Post not found');
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showErrorSnackBar('Failed to load post: $e');
    }
  }

  Future<void> _loadComments() async {
    try {
      final comments = await CommunityService.getPostComments(widget.postId);
      setState(() {
        _comments = comments;
      });
    } catch (e) {
      _showErrorSnackBar('Failed to load comments: $e');
    }
  }

  Future<void> _incrementViewCount() async {
    try {
      await CommunityService.incrementPostViews(widget.postId);
    } catch (e) {
      // Silently fail for view count
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: MediumTheme.background,
        appBar: _buildAppBar(),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                color: MediumTheme.accent,
                strokeWidth: 2,
              ),
              SizedBox(height: 16),
              Text(
                'Loading story...',
                style: TextStyle(
                  color: MediumTheme.secondaryText,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_post == null) {
      return Scaffold(
        backgroundColor: MediumTheme.background,
        appBar: _buildAppBar(),
        body: _buildNotFoundState(),
      );
    }

    return Scaffold(
      backgroundColor: MediumTheme.background,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              controller: _scrollController,
              child: Column(
                children: [
                  _buildArticleHeader(),
                  _buildArticleContent(),
                  _buildArticleFooter(),
                  if (_post!.allowComments) _buildCommentsSection(),
                  SizedBox(height: 100), // Space for floating actions
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: _buildFloatingActions(),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white.withOpacity(0.95),
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      leading: IconButton(
        icon: Icon(
          Icons.arrow_back_ios_outlined,
          color: MediumTheme.primaryText,
          size: 20,
        ),
        onPressed: () => Navigator.pop(context),
      ),
      actions: [
        IconButton(
          icon: Icon(
            Icons.share_outlined,
            color: MediumTheme.secondaryText,
            size: 22,
          ),
          onPressed: _sharePost,
        ),
        if (_post?.authorId == widget.currentUser.uid)
          PopupMenuButton<String>(
            icon: Icon(Icons.more_horiz, color: MediumTheme.secondaryText),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            onSelected: _handleMenuAction,
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'edit',
                child: Row(
                  children: [
                    Icon(
                      Icons.edit_outlined,
                      size: 18,
                      color: MediumTheme.accent,
                    ),
                    SizedBox(width: 12),
                    Text('Edit Story'),
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
                      color: Colors.red[400],
                    ),
                    SizedBox(width: 12),
                    Text('Delete', style: TextStyle(color: Colors.red[400])),
                  ],
                ),
              ),
            ],
          ),
        SizedBox(width: 8),
      ],
    );
  }

  Widget _buildNotFoundState() {
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
                Icons.article_outlined,
                size: 48,
                color: MediumTheme.secondaryText,
              ),
            ),
            SizedBox(height: 32),
            Text(
              'Story not found',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w600,
                color: MediumTheme.primaryText,
              ),
            ),
            SizedBox(height: 16),
            Text(
              'The story you\'re looking for might have been moved or deleted.',
              style: TextStyle(
                color: MediumTheme.secondaryText,
                fontSize: 16,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildArticleHeader() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(24, 16, 24, 32),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Category and status
          Row(
            children: [
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: MediumTheme.accent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  _getCategoryDisplayName(_post!.category),
                  style: TextStyle(
                    color: MediumTheme.accent,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              if (_post!.status != PostStatus.approved) ...[
                SizedBox(width: 12),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _getStatusColor(_post!.status).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    _getStatusDisplayName(_post!.status),
                    style: TextStyle(
                      color: _getStatusColor(_post!.status),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ],
          ),

          SizedBox(height: 24),

          // Title
          Text(
            _post!.title,
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w700,
              color: MediumTheme.primaryText,
              height: 1.2,
              letterSpacing: -0.5,
            ),
          ),

          SizedBox(height: 16),

          // Summary
          Text(
            _post!.summary,
            style: TextStyle(
              fontSize: 20,
              color: MediumTheme.secondaryText,
              height: 1.5,
              letterSpacing: -0.2,
            ),
          ),

          SizedBox(height: 32),

          // Author info and metadata
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: MediumTheme.lightGray,
                child: Text(
                  _post!.authorName.isNotEmpty
                      ? _post!.authorName[0].toUpperCase()
                      : 'A',
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
                      _post!.authorName,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: MediumTheme.primaryText,
                      ),
                    ),
                    SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          _formatDate(_post!.createdAt),
                          style: TextStyle(
                            fontSize: 14,
                            color: MediumTheme.secondaryText,
                          ),
                        ),
                        Text(
                          ' • ${_getReadTime(_post!.content)} min read',
                          style: TextStyle(
                            fontSize: 14,
                            color: MediumTheme.secondaryText,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          SizedBox(height: 24),

          // Engagement bar
          Row(
            children: [
              _buildEngagementButton(
                icon: _isLiked ? Icons.favorite : Icons.favorite_border,
                count: _post!.metrics.likes,
                color: _isLiked ? Colors.red[400]! : MediumTheme.secondaryText,
                onTap: _canLike() ? _toggleLike : null,
              ),
              SizedBox(width: 24),
              _buildEngagementButton(
                icon: Icons.mode_comment_outlined,
                count: _post!.metrics.comments,
                color: MediumTheme.secondaryText,
                onTap: _post!.allowComments ? _scrollToComments : null,
              ),
              SizedBox(width: 24),
              _buildEngagementButton(
                icon: Icons.visibility_outlined,
                count: _post!.metrics.views,
                color: MediumTheme.secondaryText,
              ),
            ],
          ),

          // Divider
          Container(
            margin: EdgeInsets.only(top: 24),
            height: 1,
            color: MediumTheme.lightGray,
          ),
        ],
      ),
    );
  }

  Widget _buildEngagementButton({
    required IconData icon,
    required int count,
    required Color color,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: color),
            SizedBox(width: 6),
            Text(
              count.toString(),
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildArticleContent() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Article content with improved typography
          Text(
            _post!.content,
            style: TextStyle(
              fontSize: 18,
              height: 1.6,
              color: MediumTheme.primaryText,
              letterSpacing: -0.1,
            ),
          ),

          if (_post!.attachments.isNotEmpty) ...[
            SizedBox(height: 48),
            _buildAttachmentsSection(),
          ],
        ],
      ),
    );
  }

  Widget _buildAttachmentsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Attachments',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: MediumTheme.primaryText,
          ),
        ),
        SizedBox(height: 16),
        ..._post!.attachments.map(
          (attachment) => _buildAttachmentTile(attachment),
        ),
      ],
    );
  }

  Widget _buildAttachmentTile(PostAttachment attachment) {
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: MediumTheme.lightGray),
        borderRadius: BorderRadius.circular(12),
        color: MediumTheme.background,
      ),
      child: InkWell(
        onTap: () => _downloadAttachment(attachment),
        borderRadius: BorderRadius.circular(8),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: MediumTheme.accent.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                _getFileIcon(attachment.fileType),
                color: MediumTheme.accent,
                size: 24,
              ),
            ),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    attachment.fileName,
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      color: MediumTheme.primaryText,
                      fontSize: 15,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    '${_formatFileSize(attachment.fileSizeBytes)} • ${attachment.fileType.toUpperCase()}',
                    style: TextStyle(
                      fontSize: 13,
                      color: MediumTheme.secondaryText,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.download_outlined, color: MediumTheme.accent, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildArticleFooter() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_post!.tags.isNotEmpty) ...[
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: _post!.tags.map((tag) {
                return Container(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: MediumTheme.lightGray,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    tag,
                    style: TextStyle(
                      color: MediumTheme.secondaryText,
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                    ),
                  ),
                );
              }).toList(),
            ),
            SizedBox(height: 32),
          ],

          // Author section
          Container(
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: MediumTheme.background,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: MediumTheme.lightGray),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 32,
                  backgroundColor: MediumTheme.lightGray,
                  child: Text(
                    _post!.authorName.isNotEmpty
                        ? _post!.authorName[0].toUpperCase()
                        : 'A',
                    style: TextStyle(
                      color: MediumTheme.primaryText,
                      fontWeight: FontWeight.w600,
                      fontSize: 24,
                    ),
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _post!.authorName,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: MediumTheme.primaryText,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        _post!.authorDesignation,
                        style: TextStyle(
                          fontSize: 14,
                          color: MediumTheme.secondaryText,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentsSection() {
    return Container(
      width: double.infinity,
      margin: EdgeInsets.only(top: 24),
      padding: EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Comments',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                  color: MediumTheme.primaryText,
                ),
              ),
              SizedBox(width: 8),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: MediumTheme.lightGray,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${_comments.length}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: MediumTheme.secondaryText,
                  ),
                ),
              ),
            ],
          ),

          SizedBox(height: 24),

          if (_comments.isEmpty)
            _buildEmptyCommentsState()
          else
            ..._comments.map((comment) => _buildCommentTile(comment)),
        ],
      ),
    );
  }

  Widget _buildEmptyCommentsState() {
    return Container(
      padding: EdgeInsets.all(48),
      child: Center(
        child: Column(
          children: [
            Icon(
              Icons.mode_comment_outlined,
              size: 64,
              color: MediumTheme.secondaryText.withOpacity(0.5),
            ),
            SizedBox(height: 16),
            Text(
              'No comments yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: MediumTheme.secondaryText,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Be the first to share your thoughts',
              style: TextStyle(
                fontSize: 14,
                color: MediumTheme.secondaryText.withOpacity(0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCommentTile(PostComment comment) {
    return Container(
      margin: EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: MediumTheme.lightGray,
                child: Text(
                  comment.userName.isNotEmpty
                      ? comment.userName[0].toUpperCase()
                      : 'U',
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
                    Text(
                      comment.userName,
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 15,
                        color: MediumTheme.primaryText,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      _formatDate(comment.createdAt),
                      style: TextStyle(
                        fontSize: 13,
                        color: MediumTheme.secondaryText,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          Padding(
            padding: EdgeInsets.only(left: 52),
            child: Text(
              comment.content,
              style: TextStyle(
                fontSize: 16,
                height: 1.5,
                color: MediumTheme.primaryText,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFloatingActions() {
    if (!_post!.allowComments && !_canLike()) return SizedBox();

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 24),
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: MediumTheme.lightGray),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          if (_canLike()) ...[
            GestureDetector(
              onTap: _toggleLike,
              child: Container(
                padding: EdgeInsets.all(8),
                child: Icon(
                  _isLiked ? Icons.favorite : Icons.favorite_border,
                  color: _isLiked ? Colors.red[400] : MediumTheme.secondaryText,
                  size: 22,
                ),
              ),
            ),
            SizedBox(width: 8),
          ],
          if (_post!.allowComments) ...[
            Expanded(
              child: TextField(
                controller: _commentController,
                style: TextStyle(color: MediumTheme.primaryText),
                decoration: InputDecoration(
                  hintText: 'Write a comment...',
                  hintStyle: TextStyle(color: MediumTheme.secondaryText),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                ),
                maxLines: null,
              ),
            ),
            SizedBox(width: 8),
            GestureDetector(
              onTap: _isCommenting ? null : _postComment,
              child: Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _commentController.text.trim().isNotEmpty
                      ? MediumTheme.accent
                      : MediumTheme.lightGray,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: _isCommenting
                    ? SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Icon(
                        Icons.send,
                        color: _commentController.text.trim().isNotEmpty
                            ? Colors.white
                            : MediumTheme.secondaryText,
                        size: 16,
                      ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  int _getReadTime(String content) {
    final wordCount = content.split(' ').length;
    return (wordCount / 225).ceil().clamp(1, 99);
  }

  void _scrollToComments() {
    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent,
      duration: Duration(milliseconds: 500),
      curve: Curves.easeInOut,
    );
  }

  // Helper Methods (keeping existing logic with improved styling)
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

  IconData _getFileIcon(String fileType) {
    switch (fileType.toLowerCase()) {
      case 'excel':
      case 'xlsx':
      case 'xls':
        return Icons.table_chart_outlined;
      case 'doc':
      case 'docx':
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

  bool _canLike() {
    return _post!.status == PostStatus.approved;
  }

  // Action Methods (keeping existing logic)
  void _handleMenuAction(String action) {
    switch (action) {
      case 'edit':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => BlogArticleScreen(
              currentUser: widget.currentUser,
              existingPost: _post,
            ),
          ),
        ).then((_) => _loadPost());
        break;
      case 'delete':
        _showDeleteConfirmation();
        break;
    }
  }

  void _showDeleteConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Delete Story',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        content: Text('Are you sure you want to delete this story?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _deletePost();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red[400],
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

  Future<void> _deletePost() async {
    try {
      final archivedPost = _post!.copyWith(status: PostStatus.archived);
      await CommunityService.updateKnowledgePost(widget.postId, archivedPost);
      _showSuccessSnackBar('Story deleted successfully');
      Navigator.pop(context);
    } catch (e) {
      _showErrorSnackBar('Failed to delete story: $e');
    }
  }

  Future<void> _toggleLike() async {
    try {
      if (_isLiked) {
        await CommunityService.unlikePost(
          widget.postId,
          widget.currentUser.uid,
        );
      } else {
        await CommunityService.likePost(widget.postId, widget.currentUser.uid);
      }

      setState(() {
        _isLiked = !_isLiked;
        if (_isLiked) {
          _post = _post!.copyWith(
            metrics: _post!.metrics.copyWith(
              likes: _post!.metrics.likes + 1,
              likedBy: [..._post!.metrics.likedBy, widget.currentUser.uid],
            ),
          );
        } else {
          _post = _post!.copyWith(
            metrics: _post!.metrics.copyWith(
              likes: _post!.metrics.likes - 1,
              likedBy: _post!.metrics.likedBy
                  .where((id) => id != widget.currentUser.uid)
                  .toList(),
            ),
          );
        }
      });
    } catch (e) {
      _showErrorSnackBar('Failed to update like: $e');
    }
  }

  Future<void> _postComment() async {
    final commentText = _commentController.text.trim();
    if (commentText.isEmpty) return;

    setState(() {
      _isCommenting = true;
    });

    try {
      final comment = PostComment(
        postId: widget.postId,
        authorId: widget.currentUser.uid,
        authorName: widget.currentUser.name,
        authorDesignation: widget.currentUser.designationDisplayName,
        content: commentText,
        createdAt: Timestamp.now(),
      );

      await CommunityService.addPostComment(comment);

      setState(() {
        _commentController.clear();
        _isCommenting = false;
      });

      _loadComments();
      _showSuccessSnackBar('Comment posted successfully');
    } catch (e) {
      setState(() {
        _isCommenting = false;
      });
      _showErrorSnackBar('Failed to post comment: $e');
    }
  }

  void _sharePost() {
    _showSuccessSnackBar('Share functionality to be implemented');
  }

  Future<void> _downloadAttachment(PostAttachment attachment) async {
    try {
      if (await canLaunch(attachment.fileUrl)) {
        await launch(attachment.fileUrl);
      } else {
        _showErrorSnackBar('Cannot open file');
      }
    } catch (e) {
      _showErrorSnackBar('Failed to download file: $e');
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

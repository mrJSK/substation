// lib/screens/community/knowledge_post_detail_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/community_models.dart';
import '../../models/user_model.dart';
import '../../services/community_service.dart';
import 'blog_article_screen.dart';

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
        backgroundColor: Color(0xFFFAFAFA),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          iconTheme: IconThemeData(color: Colors.black87),
        ),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_post == null) {
      return Scaffold(
        backgroundColor: Color(0xFFFAFAFA),
        appBar: AppBar(
          title: Text('Article Not Found'),
          backgroundColor: Colors.white,
          elevation: 0,
          iconTheme: IconThemeData(color: Colors.black87),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 80, color: Colors.grey[400]),
              SizedBox(height: 16),
              Text(
                'Article not found',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Color(0xFFFAFAFA),
      appBar: AppBar(
        title: Text(
          'Article',
          style: TextStyle(fontWeight: FontWeight.w600, color: Colors.black87),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.black87),
        actions: [
          if (_post!.authorId == widget.currentUser.uid)
            PopupMenuButton<String>(
              onSelected: _handleMenuAction,
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(Icons.edit, size: 18),
                      SizedBox(width: 8),
                      Text('Edit'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete, size: 18, color: Colors.red),
                      SizedBox(width: 8),
                      Text('Delete', style: TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              ],
            ),
          IconButton(icon: Icon(Icons.share), onPressed: _sharePost),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              controller: _scrollController,
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Post Header
                  _buildPostHeader(),

                  SizedBox(height: 20),

                  // Post Content
                  _buildPostContent(),

                  SizedBox(height: 20),

                  // Attachments
                  if (_post!.attachments.isNotEmpty) _buildAttachments(),

                  SizedBox(height: 20),

                  // Tags
                  if (_post!.tags.isNotEmpty) _buildTags(),

                  SizedBox(height: 20),

                  // Engagement Stats
                  _buildEngagementStats(),

                  SizedBox(height: 20),

                  // Comments Section
                  if (_post!.allowComments) _buildCommentsSection(),
                ],
              ),
            ),
          ),

          // Bottom Action Bar
          if (_post!.allowComments || _canLike()) _buildBottomActionBar(),
        ],
      ),
    );
  }

  Widget _buildPostHeader() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status badge
            Row(
              children: [
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getStatusColor(_post!.status).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _getStatusDisplayName(_post!.status),
                    style: TextStyle(
                      color: _getStatusColor(_post!.status),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Spacer(),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _getCategoryDisplayName(_post!.category),
                    style: TextStyle(
                      color: Theme.of(context).primaryColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),

            SizedBox(height: 16),

            // Title
            Text(
              _post!.title,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
                height: 1.3,
              ),
            ),

            SizedBox(height: 12),

            // Summary
            Text(
              _post!.summary,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
                height: 1.4,
              ),
            ),

            SizedBox(height: 16),

            // Author and date info
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: Theme.of(
                    context,
                  ).primaryColor.withOpacity(0.1),
                  child: Text(
                    _post!.authorName.isNotEmpty
                        ? _post!.authorName[0].toUpperCase()
                        : 'A',
                    style: TextStyle(
                      color: Theme.of(context).primaryColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _post!.authorName,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      Text(
                        _post!.authorDesignation,
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      _formatDate(_post!.createdAt),
                      style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                    ),
                    if (_post!.updatedAt != null)
                      Text(
                        'Updated ${_formatDate(_post!.updatedAt!)}',
                        style: TextStyle(fontSize: 10, color: Colors.grey[400]),
                      ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPostContent() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Content',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            SizedBox(height: 12),
            Text(
              _post!.content,
              style: TextStyle(
                fontSize: 15,
                height: 1.6,
                color: Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAttachments() {
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
                Icon(Icons.attach_file, color: Theme.of(context).primaryColor),
                SizedBox(width: 8),
                Text(
                  'Attachments (${_post!.attachments.length})',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
            ...(_post!.attachments
                .map((attachment) => _buildAttachmentTile(attachment))
                .toList()),
          ],
        ),
      ),
    );
  }

  Widget _buildAttachmentTile(PostAttachment attachment) {
    return Container(
      margin: EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListTile(
        leading: Icon(_getFileIcon(attachment.fileType)),
        title: Text(
          attachment.fileName,
          style: TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: Text(
          '${_formatFileSize(attachment.fileSizeBytes)} • ${attachment.fileType.toUpperCase()}',
          style: TextStyle(fontSize: 12),
        ),
        trailing: IconButton(
          icon: Icon(Icons.download, color: Theme.of(context).primaryColor),
          onPressed: () => _downloadAttachment(attachment),
        ),
        onTap: () => _downloadAttachment(attachment),
      ),
    );
  }

  Widget _buildTags() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Tags',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _post!.tags.map((tag) {
                return Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Theme.of(context).primaryColor.withOpacity(0.3),
                    ),
                  ),
                  child: Text(
                    tag,
                    style: TextStyle(
                      color: Theme.of(context).primaryColor,
                      fontWeight: FontWeight.w500,
                      fontSize: 12,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEngagementStats() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildStatItem(
              icon: Icons.visibility,
              count: _post!.metrics.views,
              label: 'Views',
              color: Colors.blue,
            ),
            _buildStatItem(
              icon: Icons.thumb_up,
              count: _post!.metrics.likes,
              label: 'Likes',
              color: Colors.green,
            ),
            _buildStatItem(
              icon: Icons.comment,
              count: _post!.metrics.comments,
              label: 'Comments',
              color: Colors.orange,
            ),
            _buildStatItem(
              icon: Icons.share,
              count: _post!.metrics.shares,
              label: 'Shares',
              color: Colors.purple,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required int count,
    required String label,
    required Color color,
  }) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        SizedBox(height: 4),
        Text(
          count.toString(),
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
      ],
    );
  }

  Widget _buildCommentsSection() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Comments (${_comments.length})',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            SizedBox(height: 16),
            if (_comments.isEmpty)
              Container(
                padding: EdgeInsets.all(20),
                child: Center(
                  child: Column(
                    children: [
                      Icon(
                        Icons.comment_outlined,
                        size: 48,
                        color: Colors.grey[400],
                      ),
                      SizedBox(height: 8),
                      Text(
                        'No comments yet',
                        style: TextStyle(color: Colors.grey[500]),
                      ),
                      Text(
                        'Be the first to comment!',
                        style: TextStyle(color: Colors.grey[400], fontSize: 12),
                      ),
                    ],
                  ),
                ),
              )
            else
              ...(_comments
                  .map((comment) => _buildCommentTile(comment))
                  .toList()),
          ],
        ),
      ),
    );
  }

  Widget _buildCommentTile(PostComment comment) {
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: Theme.of(
                  context,
                ).primaryColor.withOpacity(0.1),
                child: Text(
                  comment.userName.isNotEmpty
                      ? comment.userName[0].toUpperCase()
                      : 'U',
                  style: TextStyle(
                    color: Theme.of(context).primaryColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      comment.userName,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    Text(
                      comment.userDesignation,
                      style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
              Text(
                _formatDate(comment.createdAt),
                style: TextStyle(fontSize: 11, color: Colors.grey[500]),
              ),
            ],
          ),
          SizedBox(height: 8),
          Text(comment.content, style: TextStyle(fontSize: 14, height: 1.4)),
        ],
      ),
    );
  }

  Widget _buildBottomActionBar() {
    return Container(
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
          if (_canLike()) ...[
            IconButton(
              onPressed: _toggleLike,
              icon: Icon(
                _isLiked ? Icons.thumb_up : Icons.thumb_up_outlined,
                color: _isLiked ? Colors.blue : Colors.grey[600],
              ),
            ),
            Text(
              '${_post!.metrics.likes}',
              style: TextStyle(color: Colors.grey[600]),
            ),
            SizedBox(width: 16),
          ],
          if (_post!.allowComments) ...[
            Expanded(
              child: TextField(
                controller: _commentController,
                decoration: InputDecoration(
                  hintText: 'Write a comment...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(25),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(25),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(25),
                    borderSide: BorderSide(
                      color: Theme.of(context).primaryColor,
                    ),
                  ),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                ),
                maxLines: null,
              ),
            ),
            SizedBox(width: 8),
            IconButton(
              onPressed: _isCommenting ? null : _postComment,
              icon: _isCommenting
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(Icons.send),
              color: Theme.of(context).primaryColor,
            ),
          ],
        ],
      ),
    );
  }

  // Helper Methods
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
        return 'Pending Approval';
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
        return 'News';
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
        return Icons.table_chart;
      case 'doc':
      case 'docx':
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

  bool _canLike() {
    return _post!.status == PostStatus.approved;
  }

  // Action Methods
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
        title: Text('Delete Article'),
        content: Text('Are you sure you want to delete this article?'),
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
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _deletePost() async {
    try {
      // Archive the post instead of actual deletion
      final archivedPost = _post!.copyWith(status: PostStatus.archived);
      await CommunityService.updateKnowledgePost(widget.postId, archivedPost);

      _showSuccessSnackBar('Article deleted successfully');
      Navigator.pop(context);
    } catch (e) {
      _showErrorSnackBar('Failed to delete article: $e');
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
        authorId: widget.currentUser.uid, // Changed from userId
        authorName: widget.currentUser.name, // Changed from userName
        authorDesignation:
            widget.currentUser.designationDisplayName, // Now explicitly set
        content: commentText,
        createdAt: Timestamp.now(),
      );

      await CommunityService.addPostComment(comment);

      setState(() {
        _commentController.clear();
        _isCommenting = false;
      });

      _loadComments(); // Reload comments
      _showSuccessSnackBar('Comment posted successfully');
    } catch (e) {
      setState(() {
        _isCommenting = false;
      });
      _showErrorSnackBar('Failed to post comment: $e');
    }
  }

  void _sharePost() {
    // Implement share functionality
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

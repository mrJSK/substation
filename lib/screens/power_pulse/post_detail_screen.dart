// lib/screens/post_detail_screen.dart
import 'dart:convert';
import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:graphite/core/typings.dart';
import 'package:graphite/graphite.dart';
import 'package:path/path.dart' as path;
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/power_pulse/powerpulse_models.dart';
import '../../services/power_pulse_service/powerpulse_services.dart';
import '../../widgets/post_card/flowchart_preview_widget.dart';
import 'flowchart_create_screen.dart';
import 'post_create_screen.dart';

class PostDetailScreen extends StatefulWidget {
  final String postId;

  const PostDetailScreen({Key? key, required this.postId}) : super(key: key);

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  Post? _post;
  List<ContentBlock> _contentBlocks = [];
  bool _isLoading = true;
  String? _error;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadPost();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadPost() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final prefs = await SharedPreferences.getInstance();
      final cachedPost = prefs.getString('post_${widget.postId}');

      Post? post;
      if (cachedPost != null) {
        try {
          post = Post.fromJson(jsonDecode(cachedPost) as Map<String, dynamic>);
        } catch (e) {
          debugPrint('Failed to parse cached post: $e');
        }
      }

      post ??= await PostService.getPost(widget.postId);
      if (post == null) {
        setState(() {
          _error = 'Post not found';
          _isLoading = false;
        });
        return;
      }

      // Cache post
      await prefs.setString('post_${widget.postId}', jsonEncode(post.toJson()));

      // Use the contentBlocks getter from the updated Post model
      List<ContentBlock> contentBlocks = post.contentBlocks;

      if (mounted) {
        setState(() {
          _post = post;
          _contentBlocks = contentBlocks;
          _isLoading = false;
        });

        AnalyticsService.logPostView(widget.postId);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load post: $e';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: _buildAppBar(),
      body: _buildBody(),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 2,
      systemOverlayStyle: SystemUiOverlayStyle.dark,
      leading: IconButton(
        icon: Icon(Icons.arrow_back, color: Colors.grey[700]),
        onPressed: () => Navigator.of(context).pop(),
      ),
      title: Text(
        'Post',
        style: GoogleFonts.lora(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: Colors.grey[800],
        ),
      ),
      centerTitle: true,
      actions: [
        IconButton(
          icon: Icon(Icons.share_outlined, color: Colors.grey[700]),
          onPressed: _sharePost,
          tooltip: 'Share post',
        ),
        PopupMenuButton<String>(
          icon: Icon(Icons.more_vert, color: Colors.grey[700]),
          onSelected: _handleMenuAction,
          itemBuilder: (context) => _buildMenuItems(),
        ),
      ],
    );
  }

  List<PopupMenuEntry<String>> _buildMenuItems() {
    final currentUser = AuthService.currentUser;
    final isAuthor = currentUser?.uid == _post?.authorId;

    return [
      if (isAuthor) ...[
        const PopupMenuItem(
          value: 'edit',
          child: Row(
            children: [
              Icon(Icons.edit, size: 18),
              SizedBox(width: 12),
              Text('Edit Post'),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'delete',
          child: Row(
            children: [
              Icon(Icons.delete, color: Colors.red, size: 18),
              SizedBox(width: 12),
              Text('Delete Post', style: TextStyle(color: Colors.red)),
            ],
          ),
        ),
        const PopupMenuDivider(),
      ],
      const PopupMenuItem(
        value: 'bookmark',
        child: Row(
          children: [
            Icon(Icons.bookmark_border, size: 18),
            SizedBox(width: 12),
            Text('Bookmark'),
          ],
        ),
      ),
      const PopupMenuItem(
        value: 'report',
        child: Row(
          children: [
            Icon(Icons.flag_outlined, size: 18),
            SizedBox(width: 12),
            Text('Report'),
          ],
        ),
      ),
    ];
  }

  Widget _buildBody() {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Colors.blue[600]),
            const SizedBox(height: 16),
            Text(
              'Loading post...',
              style: GoogleFonts.lora(fontSize: 16, color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 80, color: Colors.grey[400]),
              const SizedBox(height: 16),
              Text(
                _error!,
                style: GoogleFonts.lora(fontSize: 16, color: Colors.grey[600]),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _loadPost,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[600],
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_post == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.article_outlined, size: 80, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'Post not found',
              style: GoogleFonts.lora(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: Colors.blue[600],
      onRefresh: _loadPost,
      child: CustomScrollView(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          _buildPostHeader(),
          _buildPostContent(),
          _buildVoteSection(),
          _buildCommentsSection(),
          const SliverToBoxAdapter(child: SizedBox(height: 80)),
        ],
      ),
    );
  }

  Widget _buildPostHeader() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _buildScopeBadge(),
                if (_post!.flair != null) ...[
                  const SizedBox(width: 8),
                  _buildFlairBadge(),
                ],
              ],
            ),
            const SizedBox(height: 16),
            Text(
              _post!.title,
              style: GoogleFonts.lora(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                height: 1.3,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 12),
            // Display excerpt if available
            if (_post!.excerpt.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: Text(
                  _post!.excerpt,
                  style: GoogleFonts.lora(
                    fontSize: 16,
                    height: 1.5,
                    color: Colors.grey[700],
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
            _buildAuthorInfo(),
            const SizedBox(height: 24),
            if (_post!.imageUrl != null) _buildHeaderImage(),
          ],
        ),
      ),
    );
  }

  Widget _buildScopeBadge() {
    final isPublic = _post!.scope.isPublic;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isPublic ? Colors.blue[50] : Colors.orange[50],
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isPublic ? Colors.blue[600]! : Colors.orange[600]!,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isPublic ? Icons.public : Icons.location_on,
            size: 16,
            color: isPublic ? Colors.blue[700] : Colors.orange[700],
          ),
          const SizedBox(width: 8),
          Text(
            _post!.scope.displayName,
            style: GoogleFonts.lora(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isPublic ? Colors.blue[700] : Colors.orange,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFlairBadge() {
    final flair = _post!.flair!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: _getFlairColor(flair).withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _getFlairColor(flair)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (flair.emoji != null) ...[
            Text(flair.emoji!, style: const TextStyle(fontSize: 14)),
            const SizedBox(width: 6),
          ],
          Text(
            flair.name,
            style: GoogleFonts.lora(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: _getFlairColor(flair),
            ),
          ),
        ],
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
      case 'discussion':
        return Colors.purple!;
      default:
        return Colors.purple!;
    }
  }

  Widget _buildAuthorInfo() {
    return Row(
      children: [
        CircleAvatar(
          backgroundColor: Colors.blue[600],
          radius: 24,
          child: Text(
            (_post!.authorName ?? 'U').substring(0, 1).toUpperCase(),
            style: GoogleFonts.lora(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _post!.authorName ?? 'Unknown Author',
                style: GoogleFonts.lora(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Text(
                    _formatTimestamp(_post!.createdAt),
                    style: GoogleFonts.lora(
                      fontSize: 13,
                      color: Colors.grey[600],
                    ),
                  ),
                  if (_post!.authorDesignation != null) ...[
                    Text(
                      ' • ',
                      style: GoogleFonts.lora(color: Colors.grey[600]),
                    ),
                    Expanded(
                      child: Text(
                        _post!.authorDesignation!,
                        style: GoogleFonts.lora(
                          fontSize: 13,
                          color: Colors.grey[600],
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.schedule, size: 14, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    _post!.readingTime,
                    style: GoogleFonts.lora(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHeaderImage() {
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: CachedNetworkImage(
            imageUrl: _post!.imageUrl!,
            width: double.infinity,
            height: 240,
            fit: BoxFit.cover,
            placeholder: (context, url) => Container(
              height: 240,
              color: Colors.grey[100],
              child: Center(
                child: CircularProgressIndicator(color: Colors.blue[600]),
              ),
            ),
            errorWidget: (context, url, error) => Container(
              height: 240,
              color: Colors.grey[100],
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.image_not_supported,
                    color: Colors.grey[600],
                    size: 48,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Image unavailable',
                    style: GoogleFonts.lora(color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildPostContent() {
    if (_contentBlocks.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            'No content available',
            style: GoogleFonts.lora(
              fontSize: 16,
              color: Colors.grey[600],
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
      );
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) => _buildBlockPreview(_contentBlocks[index]),
        childCount: _contentBlocks.length,
      ),
    );
  }

  Widget _buildBlockPreview(ContentBlock block) {
    switch (block.type) {
      case ContentBlockType.heading:
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
          child: Text(
            block.text,
            style: GoogleFonts.lora(
              fontSize: 26,
              fontWeight: FontWeight.w700,
              color: Colors.black87,
              height: 1.3,
            ),
          ),
        );
      case ContentBlockType.subHeading:
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
          child: Text(
            block.text,
            style: GoogleFonts.lora(
              fontSize: 22,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
              height: 1.3,
            ),
          ),
        );
      case ContentBlockType.paragraph:
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 20),
          child: Text(
            block.text,
            style: GoogleFonts.lora(
              fontSize: 18,
              height: 1.6,
              color: Colors.black87,
            ),
          ),
        );
      case ContentBlockType.bulletedList:
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: block.listItems.map((item) {
              if (item.trim().isEmpty) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 8, right: 12),
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: Colors.blue[600],
                        shape: BoxShape.circle,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        item,
                        style: GoogleFonts.lora(
                          fontSize: 18,
                          height: 1.6,
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
      case ContentBlockType.numberedList:
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: block.listItems.asMap().entries.map((entry) {
              if (entry.value.trim().isEmpty) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      margin: const EdgeInsets.only(right: 12),
                      child: Text(
                        '${entry.key + 1}.',
                        style: GoogleFonts.lora(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.blue[600],
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        entry.value,
                        style: GoogleFonts.lora(
                          fontSize: 18,
                          height: 1.6,
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
        if (block.url == null && block.file == null)
          return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: block.file != null
                ? Image.file(
                    block.file!,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  )
                : CachedNetworkImage(
                    imageUrl: block.url!,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      height: 200,
                      color: Colors.grey[100],
                      child: Center(
                        child: CircularProgressIndicator(
                          color: Colors.blue[600],
                        ),
                      ),
                    ),
                    errorWidget: (context, url, error) => Container(
                      height: 200,
                      color: Colors.grey[100],
                      child: const Center(child: Text('Image unavailable')),
                    ),
                  ),
          ),
        );
      case ContentBlockType.link:
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 20),
          child: GestureDetector(
            onTap: () => _launchURL(block.url ?? ''),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue[600]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.link, color: Colors.blue[600], size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      block.text,
                      style: GoogleFonts.lora(
                        fontSize: 16,
                        color: Colors.blue[700],
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                  Icon(Icons.open_in_new, color: Colors.blue[600], size: 16),
                ],
              ),
            ),
          ),
        );
      case ContentBlockType.file:
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 20),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: Row(
              children: [
                Icon(Icons.attach_file, color: Colors.grey[600], size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        block.text,
                        style: GoogleFonts.lora(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Colors.black87,
                        ),
                      ),
                      Text(
                        'FILE',
                        style: GoogleFonts.lora(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => _showFileInfo(block.text),
                  icon: Icon(Icons.info_outline, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
        );
      case ContentBlockType.flowchart:
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          child: GestureDetector(
            onTap: () => _viewFlowchart(block),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue[600]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    children: [
                      Icon(
                        Icons.account_tree,
                        color: Colors.blue[600],
                        size: 24,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          block.flowchartData?['title'] ?? block.text,
                          style: GoogleFonts.lora(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                      Icon(
                        Icons.open_in_full,
                        color: Colors.blue[600],
                        size: 20,
                      ),
                    ],
                  ),
                  // Description
                  if (block.flowchartData?['description'] != null &&
                      block.flowchartData!['description']
                          .toString()
                          .isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      block.flowchartData!['description'],
                      style: GoogleFonts.lora(
                        fontSize: 14,
                        color: Colors.grey[700],
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  // Use the shared FlowchartPreviewWidget
                  FlowchartPreviewWidget(
                    flowchartData: block.flowchartData,
                    height: 300,
                    onTap: () => _viewFlowchart(block),
                  ),
                  const SizedBox(height: 12),
                  // Footer info
                  Row(
                    children: [
                      Icon(Icons.visibility, color: Colors.blue[600], size: 16),
                      const SizedBox(width: 4),
                      Text(
                        'Tap to view full flowchart',
                        style: GoogleFonts.lora(
                          fontSize: 12,
                          color: Colors.blue[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${block.flowchartData?['nodeCount'] ?? 0} nodes',
                        style: GoogleFonts.lora(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
    }
  }

  void _viewFlowchart(ContentBlock block) {
    if (block.flowchartData == null) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FlowchartPreviewScreen(
          title: block.flowchartData!['title'] ?? 'Flowchart',
          description: block.flowchartData!['description'] ?? '',
          nodes: block.flowchartData!['nodes'] != null
              ? nodeInputFromJson(block.flowchartData!['nodes'] as String)
              : [],
        ),
      ),
    );
  }

  Widget _buildVoteSection() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: EnhancedVoteBar(post: _post!),
      ),
    );
  }

  Widget _buildCommentsSection() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Comments',
                  style: GoogleFonts.lora(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${_post!.commentCount}',
                    style: GoogleFonts.lora(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[600],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: _addComment,
              icon: Icon(Icons.add_comment, color: Colors.blue[600]),
              label: Text(
                'Add a comment',
                style: GoogleFonts.lora(
                  fontSize: 14,
                  color: Colors.blue[600],
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 16),
            StreamBuilder<List<Comment>>(
              stream: PostService.streamComments(widget.postId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(
                    child: CircularProgressIndicator(color: Colors.blue[600]),
                  );
                }
                if (snapshot.hasError) {
                  return _buildErrorState(
                    'Error loading comments',
                    snapshot.error.toString(),
                    onRetry: () => setState(() {}),
                  );
                }
                final comments = snapshot.data ?? [];
                if (comments.isEmpty) {
                  return _buildEmptyState(
                    icon: Icons.chat_bubble_outline,
                    title: 'No comments yet',
                    subtitle: 'Be the first to share your thoughts!',
                    actionText: 'Add Comment',
                    onAction: _addComment,
                  );
                }
                return _buildCommentTree(comments);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCommentTree(List<Comment> comments) {
    final rootComments = comments.where((c) => c.parentId == null).toList();
    return Column(
      children: rootComments.map((comment) {
        final replies = comments
            .where((c) => c.parentId == comment.id)
            .toList();
        return _buildCommentItem(comment, replies, depth: 0);
      }).toList(),
    );
  }

  Widget _buildCommentItem(
    Comment comment,
    List<Comment> replies, {
    int depth = 0,
  }) {
    return Container(
      margin: EdgeInsets.only(left: depth * 16.0, bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                backgroundColor: Colors.blue[600],
                radius: 16,
                child: Text(
                  (comment.authorName ?? 'U').substring(0, 1).toUpperCase(),
                  style: GoogleFonts.lora(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          comment.authorName ?? 'Unknown',
                          style: GoogleFonts.lora(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                        if (comment.authorDesignation != null) ...[
                          Text(
                            ' • ',
                            style: GoogleFonts.lora(color: Colors.grey[600]),
                          ),
                          Text(
                            comment.authorDesignation!,
                            style: GoogleFonts.lora(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ],
                    ),
                    Text(
                      _formatTimestamp(comment.createdAt),
                      style: GoogleFonts.lora(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            comment.bodyPlain,
            style: GoogleFonts.lora(
              fontSize: 14,
              color: Colors.black87,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              EnhancedCommentVoteBar(comment: comment),
              const SizedBox(width: 16),
              TextButton.icon(
                onPressed: () => _addComment(parentId: comment.id),
                icon: Icon(Icons.reply, color: Colors.grey[600], size: 18),
                label: Text(
                  'Reply',
                  style: GoogleFonts.lora(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ),
            ],
          ),
          if (replies.isNotEmpty) ...[
            const SizedBox(height: 8),
            Column(
              children: replies
                  .map(
                    (reply) => _buildCommentItem(reply, [], depth: depth + 1),
                  )
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildErrorState(String title, String error, {VoidCallback? onRetry}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 80, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              title,
              style: GoogleFonts.lora(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              error.length > 100 ? '${error.substring(0, 100)}...' : error,
              style: GoogleFonts.lora(fontSize: 14, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[600],
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
    String? actionText,
    VoidCallback? onAction,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 80, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              title,
              style: GoogleFonts.lora(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: GoogleFonts.lora(fontSize: 14, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
            if (actionText != null && onAction != null) ...[
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: onAction,
                icon: const Icon(Icons.add),
                label: Text(actionText),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[600],
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatTimestamp(Timestamp timestamp) {
    final date = timestamp.toDate();
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inMinutes < 1) return 'now';
    if (difference.inMinutes < 60) return '${difference.inMinutes}m ago';
    if (difference.inHours < 24) return '${difference.inHours}h ago';
    if (difference.inDays < 7) return '${difference.inDays}d ago';
    if (difference.inDays < 30)
      return '${(difference.inDays / 7).floor()}w ago';
    return '${date.day}/${date.month}/${date.year}';
  }

  void _sharePost() {
    HapticFeedback.mediumImpact();
    final url = 'https://powerpulse.app/posts/${widget.postId}';
    Share.share(
      'Check out this post on PowerPulse: ${_post!.title}\n$url',
      subject: _post!.title,
    );
  }

  void _handleMenuAction(String action) {
    switch (action) {
      case 'edit':
        _editPost();
        break;
      case 'delete':
        _confirmDelete();
        break;
      case 'bookmark':
        _bookmarkPost();
        break;
      case 'report':
        _reportPost();
        break;
    }
  }

  void _editPost() {
    if (_post != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PostCreateScreen(editingPost: _post),
        ),
      ).then((result) {
        if (result == true) {
          _loadPost();
        }
      });
    }
  }

  void _confirmDelete() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text(
          'Delete Post',
          style: GoogleFonts.lora(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        content: Text(
          'Are you sure you want to delete this post? This action cannot be undone.',
          style: GoogleFonts.lora(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: GoogleFonts.lora()),
          ),
          ElevatedButton(
            onPressed: _deletePost,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red[600],
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text('Delete', style: GoogleFonts.lora()),
          ),
        ],
      ),
    );
  }

  void _deletePost() async {
    Navigator.pop(context);
    try {
      await PostService.deletePost(widget.postId);
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Post deleted successfully',
              style: GoogleFonts.lora(),
            ),
            backgroundColor: Colors.green[600],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to delete post: $e',
              style: GoogleFonts.lora(),
            ),
            backgroundColor: Colors.red[600],
          ),
        );
      }
    }
  }

  void _bookmarkPost() {
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Post bookmarked!', style: GoogleFonts.lora()),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _reportPost() {
    HapticFeedback.heavyImpact();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text('Report Post', style: GoogleFonts.lora(fontSize: 18)),
        content: Text(
          'Are you sure you want to report this post for inappropriate content?',
          style: GoogleFonts.lora(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: GoogleFonts.lora()),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Post reported. Thank you for your feedback.',
                    style: GoogleFonts.lora(),
                  ),
                  backgroundColor: Colors.orange[600],
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange[600],
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text('Report', style: GoogleFonts.lora()),
          ),
        ],
      ),
    );
  }

  void _addComment({String? parentId}) {
    final currentUser = AuthService.currentUser;
    if (currentUser == null) {
      _showLoginPrompt();
      return;
    }
    // Placeholder for comment creation UI
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Comment creation UI to be implemented',
          style: GoogleFonts.lora(),
        ),
        action: SnackBarAction(label: 'OK', onPressed: () {}),
      ),
    );
  }

  Future<void> _launchURL(String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        throw 'Could not launch $url';
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not open link: $e', style: GoogleFonts.lora()),
          backgroundColor: Colors.red[600],
        ),
      );
    }
  }

  void _showFileInfo(String fileName) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'File: $fileName (Preview not available)',
          style: GoogleFonts.lora(),
        ),
        action: SnackBarAction(label: 'OK', onPressed: () {}),
      ),
    );
  }

  void _showLoginPrompt() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text(
          'Sign in required',
          style: GoogleFonts.lora(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        content: Text(
          'Please sign in to interact with this post.',
          style: GoogleFonts.lora(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: GoogleFonts.lora()),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // Implement sign-in navigation
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue[600],
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text('Sign In', style: GoogleFonts.lora()),
          ),
        ],
      ),
    );
  }
}

class EnhancedVoteBar extends StatefulWidget {
  final Post post;

  const EnhancedVoteBar({Key? key, required this.post}) : super(key: key);

  @override
  State<EnhancedVoteBar> createState() => _EnhancedVoteBarState();
}

class _EnhancedVoteBarState extends State<EnhancedVoteBar>
    with TickerProviderStateMixin {
  late Post _post;
  Vote? _userVote;
  bool _isVoting = false;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _post = widget.post;
    _setupAnimation();
    _loadUserVote();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _setupAnimation() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.elasticOut),
    );
  }

  Future<void> _loadUserVote() async {
    try {
      final vote = await VoteService.getUserVote(postId: _post.id);
      if (mounted) {
        setState(() => _userVote = vote);
      }
    } catch (e) {
      debugPrint('Error loading user vote: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildVoteButton(isUpvote: true),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: _getScoreBackgroundColor(),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${_post.score}',
              style: GoogleFonts.lora(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: _getScoreColor(),
              ),
            ),
          ),
          _buildVoteButton(isUpvote: false),
        ],
      ),
    );
  }

  Widget _buildVoteButton({required bool isUpvote}) {
    final isSelected = _userVote?.value == (isUpvote ? 1 : -1);
    final icon = isUpvote ? Icons.arrow_upward : Icons.arrow_downward;

    return ScaleTransition(
      scale: _scaleAnimation,
      child: GestureDetector(
        onTap: _isVoting ? null : () => _vote(isUpvote ? 1 : -1),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: isSelected
                ? (isUpvote ? Colors.green[50] : Colors.red[50])
                : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected
                  ? (isUpvote ? Colors.green[600]! : Colors.red!)
                  : Colors.grey!,
            ),
          ),
          child: Icon(
            icon,
            size: 24,
            color: isSelected
                ? (isUpvote ? Colors.green[600] : Colors.red[600])
                : Colors.grey,
          ),
        ),
      ),
    );
  }

  Color _getScoreBackgroundColor() {
    if (_post.score > 0) return Colors.green[50]!;
    if (_post.score < 0) return Colors.red!;
    return Colors.grey!;
  }

  Color _getScoreColor() {
    if (_post.score > 0) return Colors.green!;
    if (_post.score < 0) return Colors.red!;
    return Colors.grey!;
  }

  Future<void> _vote(int value) async {
    final currentUser = AuthService.currentUser;
    if (currentUser == null) {
      _showLoginPrompt();
      return;
    }

    if (_isVoting) return;

    setState(() => _isVoting = true);
    _animationController.forward().then((_) => _animationController.reverse());

    final prevVote = _userVote;
    final prevScore = _post.score;

    try {
      final newValue = (_userVote?.value == value) ? 0 : value;

      setState(() {
        if (newValue == 0) {
          _userVote = null;
          _post = _post.copyWith(score: prevScore - (prevVote?.value ?? 0));
        } else {
          _userVote = Vote(
            id: Vote.generateId(postId: _post.id, userId: currentUser.uid),
            postId: _post.id,
            userId: currentUser.uid,
            value: newValue,
            createdAt: Timestamp.now(),
          );
          final scoreDelta = newValue - (prevVote?.value ?? 0);
          _post = _post.copyWith(score: prevScore + scoreDelta);
        }
      });

      await VoteService.setVote(postId: _post.id, value: newValue);
      await AnalyticsService.logVote(_post.id, newValue);
    } catch (e) {
      setState(() {
        _userVote = prevVote;
        _post = _post.copyWith(score: prevScore);
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to vote. Please try again.',
              style: GoogleFonts.lora(),
            ),
            backgroundColor: Colors.red[600],
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isVoting = false);
      }
    }
  }

  void _showLoginPrompt() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text(
          'Sign in required',
          style: GoogleFonts.lora(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        content: Text(
          'Please sign in to vote on posts.',
          style: GoogleFonts.lora(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: GoogleFonts.lora()),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // Implement sign-in navigation
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue[600],
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text('Sign In', style: GoogleFonts.lora()),
          ),
        ],
      ),
    );
  }
}

class EnhancedCommentVoteBar extends StatefulWidget {
  final Comment comment;

  const EnhancedCommentVoteBar({Key? key, required this.comment})
    : super(key: key);

  @override
  State<EnhancedCommentVoteBar> createState() => _EnhancedCommentVoteBarState();
}

class _EnhancedCommentVoteBarState extends State<EnhancedCommentVoteBar>
    with TickerProviderStateMixin {
  late Comment _comment;
  Vote? _userVote;
  bool _isVoting = false;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _comment = widget.comment;
    _setupAnimation();
    _loadUserVote();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _setupAnimation() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.elasticOut),
    );
  }

  Future<void> _loadUserVote() async {
    try {
      final vote = await VoteService.getUserVote(commentId: _comment.id);
      if (mounted) {
        setState(() => _userVote = vote);
      }
    } catch (e) {
      debugPrint('Error loading user vote: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        ScaleTransition(
          scale: _scaleAnimation,
          child: GestureDetector(
            onTap: _isVoting ? null : () => _vote(1),
            child: Icon(
              Icons.arrow_upward,
              size: 20,
              color: _userVote?.value == 1 ? Colors.green[600] : Colors.grey,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '${_comment.score}',
          style: GoogleFonts.lora(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: _comment.score > 0
                ? Colors.green[700]
                : _comment.score < 0
                ? Colors.red
                : Colors.grey,
          ),
        ),
        const SizedBox(width: 8),
        ScaleTransition(
          scale: _scaleAnimation,
          child: GestureDetector(
            onTap: _isVoting ? null : () => _vote(-1),
            child: Icon(
              Icons.arrow_downward,
              size: 20,
              color: _userVote?.value == -1 ? Colors.red[600] : Colors.grey,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _vote(int value) async {
    final currentUser = AuthService.currentUser;
    if (currentUser == null) {
      _showLoginPrompt();
      return;
    }

    if (_isVoting) return;

    setState(() => _isVoting = true);
    _animationController.forward().then((_) => _animationController.reverse());

    final prevVote = _userVote;
    final prevScore = _comment.score;

    try {
      final newValue = (_userVote?.value == value) ? 0 : value;

      setState(() {
        if (newValue == 0) {
          _userVote = null;
          _comment = _comment.copyWith(
            score: prevScore - (prevVote?.value ?? 0),
          );
        } else {
          _userVote = Vote(
            id: Vote.generateId(
              commentId: _comment.id,
              userId: currentUser.uid,
            ),
            commentId: _comment.id,
            userId: currentUser.uid,
            value: newValue,
            createdAt: Timestamp.now(),
          );
          final scoreDelta = newValue - (prevVote?.value ?? 0);
          _comment = _comment.copyWith(score: prevScore + scoreDelta);
        }
      });

      await VoteService.setVote(commentId: _comment.id, value: newValue);
      await AnalyticsService.logVote(_comment.id, newValue);
    } catch (e) {
      setState(() {
        _userVote = prevVote;
        _comment = _comment.copyWith(score: prevScore);
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to vote. Please try again.',
              style: GoogleFonts.lora(),
            ),
            backgroundColor: Colors.red[600],
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isVoting = false);
      }
    }
  }

  void _showLoginPrompt() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text(
          'Sign in required',
          style: GoogleFonts.lora(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        content: Text(
          'Please sign in to vote on comments.',
          style: GoogleFonts.lora(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: GoogleFonts.lora()),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // Implement sign-in navigation
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue[600],
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text('Sign In', style: GoogleFonts.lora()),
          ),
        ],
      ),
    );
  }
}

// Placeholder for FlowchartPreviewScreen
class FlowchartPreviewScreen extends StatelessWidget {
  final String title;
  final String description;
  final List<NodeInput> nodes;

  const FlowchartPreviewScreen({
    Key? key,
    required this.title,
    required this.description,
    required this.nodes,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title, style: GoogleFonts.lora()),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 1,
      ),
      body: Column(
        children: [
          if (description.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(description, style: GoogleFonts.lora(fontSize: 16)),
            ),
          Expanded(
            child: nodes.isNotEmpty
                ? InteractiveViewer(
                    constrained: false,
                    child: DirectGraph(
                      list: nodes,
                      defaultCellSize: const Size(104.0, 104.0),
                      cellPadding: const EdgeInsets.all(14),
                      contactEdgesDistance: 5.0,
                      orientation: MatrixOrientation.Vertical,
                    ),
                  )
                : const Center(child: Text('No flowchart data available')),
          ),
        ],
      ),
    );
  }
}

// lib/screens/post_detail_screen.dart
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path/path.dart' as path;
import 'dart:io';

import '../../models/power_pulse/powerpulse_models.dart';
import '../../services/power_pulse_service/powerpulse_services.dart';

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
    final post = await PostService.getPost(widget.postId);
    if (post != null) {
      setState(() {
        _post = post;
        // Parse blocks from bodyPlain JSON
        if (post.bodyPlain.isNotEmpty) {
          final json = jsonDecode(post.bodyPlain) as List<dynamic>;
          _contentBlocks = json
              .map((e) => ContentBlock.fromJson(e as Map<String, dynamic>))
              .toList();
        }
        _isLoading = false;
      });

      // Log post view for analytics
      AnalyticsService.logPostView(widget.postId);
    } else {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Icon(Icons.bolt, color: Colors.blue[600], size: 24),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.share_outlined, color: Colors.grey),
            onPressed: () {
              // Implement share functionality
              _sharePost();
            },
          ),
          IconButton(
            icon: Icon(Icons.more_vert, color: Colors.grey),
            onPressed: () {
              // Show options menu
              _showOptionsMenu();
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _post == null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'Post not found',
                    style: GoogleFonts.montserrat(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            )
          : CustomScrollView(
              controller: _scrollController,
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Title
                        Text(
                          _post!.title,
                          style: GoogleFonts.lora(
                            fontSize: 32,
                            fontWeight: FontWeight.w700,
                            height: 1.25,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Meta information
                        Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: Colors.blue[100],
                              radius: 20,
                              child: Text(
                                (_post!.authorName ?? 'U').toUpperCase(),
                                style: GoogleFonts.montserrat(
                                  fontWeight: FontWeight.w600,
                                  color: Colors.blue,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _post!.authorName ?? 'Unknown Author',
                                    style: GoogleFonts.montserrat(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Row(
                                    children: [
                                      Text(
                                        _formatTimestamp(_post!.createdAt),
                                        style: GoogleFonts.montserrat(
                                          fontSize: 12,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                      if (_post!.authorDesignation != null) ...[
                                        Text(
                                          ' • ',
                                          style: TextStyle(color: Colors.grey),
                                        ),
                                        Text(
                                          _post!.authorDesignation!,
                                          style: GoogleFonts.montserrat(
                                            fontSize: 12,
                                            color: Colors.grey,
                                          ),
                                        ),
                                      ],
                                      Text(
                                        ' • ',
                                        style: TextStyle(color: Colors.grey),
                                      ),
                                      Text(
                                        _post!.readingTime,
                                        style: GoogleFonts.montserrat(
                                          fontSize: 12,
                                          color: Colors.grey,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),

                        // Header image if exists
                        if (_post!.imageUrl != null) ...[
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              _post!.imageUrl!,
                              width: double.infinity,
                              height: 200,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  height: 200,
                                  color: Colors.grey[200],
                                  child: Icon(
                                    Icons.image_not_supported,
                                    color: Colors.grey,
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 24),
                        ],

                        // Scope indicator
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: _post!.scope.isPublic
                                ? Colors.blue[50]
                                : Colors.orange[1],
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: _post!.scope.isPublic
                                  ? Colors.blue!
                                  : Colors.orange!,
                            ),
                          ),
                          child: Text(
                            _post!.scope.displayName,
                            style: GoogleFonts.montserrat(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: _post!.scope.isPublic
                                  ? Colors.blue[700]
                                  : Colors.orange,
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ),

                // Article body - Render blocks
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) =>
                        _buildBlockPreview(_contentBlocks[index]),
                    childCount: _contentBlocks.length,
                  ),
                ),

                // Vote bar
                SliverToBoxAdapter(
                  child: Container(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 32,
                    ),
                    child: VoteBar(post: _post!),
                  ),
                ),

                // Comments section
                SliverToBoxAdapter(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Comments (${_post!.commentCount})',
                          style: GoogleFonts.montserrat(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),

                // Comments list
                SliverToBoxAdapter(child: CommentList(postId: widget.postId)),

                // Bottom padding
                const SliverToBoxAdapter(child: SizedBox(height: 32)),
              ],
            ),
    );
  }

  String _formatTimestamp(Timestamp timestamp) {
    final date = timestamp.toDate();
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  void _sharePost() {
    // Implement share functionality (e.g., using share_plus package)
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Share functionality to be implemented')),
    );
  }

  void _showOptionsMenu() {
    final currentUser = AuthService.currentUser;
    final isAuthor = currentUser?.uid == _post?.authorId;

    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isAuthor) ...[
              ListTile(
                leading: const Icon(Icons.edit),
                title: const Text('Edit Post'),
                onTap: () {
                  Navigator.pop(context);
                  // Navigate to edit screen (e.g., Navigator.push(context, MaterialPageRoute(builder: (_) => PostCreateScreen(editingPost: _post))));
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text(
                  'Delete Post',
                  style: TextStyle(color: Colors.red),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _confirmDelete();
                },
              ),
            ],
            ListTile(
              leading: const Icon(Icons.report),
              title: const Text('Report'),
              onTap: () {
                Navigator.pop(context);
                // Implement report functionality
              },
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Post'),
        content: const Text(
          'Are you sure you want to delete this post? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await PostService.deletePost(widget.postId);
                Navigator.of(context).pop(); // Go back to previous screen
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Failed to delete post')),
                );
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Widget _buildBlockPreview(ContentBlock block) {
    switch (block.type) {
      case ContentBlockType.heading:
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 20.0),
          child: Text(
            block.text,
            style: GoogleFonts.lora(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        );
      case ContentBlockType.subHeading:
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 20.0),
          child: Text(
            block.text,
            style: GoogleFonts.lora(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        );
      case ContentBlockType.paragraph:
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 20.0),
          child: Text(
            block.text,
            style: GoogleFonts.lora(fontSize: 16, color: Colors.black87),
          ),
        );
      case ContentBlockType.bulletedList:
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: block.listItems
                .map(
                  (item) => Row(
                    children: [
                      const Text('• ', style: TextStyle(fontSize: 16)),
                      Expanded(
                        child: Text(
                          item,
                          style: GoogleFonts.lora(
                            fontSize: 16,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                    ],
                  ),
                )
                .toList(),
          ),
        );
      case ContentBlockType.image:
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 20.0),
          child: Image.file(block.file!),
        );
      case ContentBlockType.link:
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 20.0),
          child: GestureDetector(
            onTap: () {
              // Open link (use url_launcher)
            },
            child: Text(
              block.text,
              style: GoogleFonts.lora(
                fontSize: 16,
                color: Colors.blue,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        );
      case ContentBlockType.file:
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 20.0),
          child: ListTile(
            leading: const Icon(Icons.attach_file),
            title: Text(block.text),
            subtitle: Text(path.extension(block.file!.path).toUpperCase()),
            onTap: () {
              // Open file viewer
            },
          ),
        );
    }
  }
}

// Basic VoteBar Widget
class VoteBar extends StatelessWidget {
  final Post post;

  const VoteBar({Key? key, required this.post}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          icon: const Icon(Icons.arrow_upward),
          onPressed: () {
            // Implement upvote
          },
        ),
        Text(
          '${post.score}',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        IconButton(
          icon: const Icon(Icons.arrow_downward),
          onPressed: () {
            // Implement downvote
          },
        ),
      ],
    );
  }
}

// Basic CommentList Widget (Placeholder - Integrate with CommentService)
class CommentList extends StatelessWidget {
  final String postId;

  const CommentList({Key? key, required this.postId}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // TODO: Stream comments from CommentService.streamComments(postId)
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 3, // Placeholder count
      itemBuilder: (context, index) {
        return ListTile(
          leading: const CircleAvatar(child: Text('U')),
          title: const Text('Sample Comment'),
          subtitle: const Text('This is a placeholder comment'),
        );
      },
    );
  }
}

// ContentBlock class (add to models if not present)
enum ContentBlockType {
  heading,
  subHeading,
  paragraph,
  bulletedList,
  image,
  link,
  file,
}

class ContentBlock {
  final ContentBlockType type;
  String text;
  List<String> listItems;
  File? file;
  String? url;
  TextEditingController controller = TextEditingController();

  ContentBlock({
    required this.type,
    this.text = '',
    this.listItems = const [],
    this.file,
    this.url,
  }) {
    controller.text = text;
  }

  factory ContentBlock.fromJson(Map<String, dynamic> json) {
    return ContentBlock(
      type: ContentBlockType.values[json['type'] as int],
      text: json['text'] as String? ?? '',
      listItems: List<String>.from(json['listItems'] ?? []),
      url: json['url'] as String?,
      file: json['filePath'] != null ? File(json['filePath'] as String) : null,
    );
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
}

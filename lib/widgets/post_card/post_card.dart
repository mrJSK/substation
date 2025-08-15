// lib/widgets/post_card.dart
import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:animated_emoji/animated_emoji.dart';
import '../../models/power_pulse/powerpulse_models.dart';
import '../../services/power_pulse_service/powerpulse_services.dart';

class PostCard extends StatefulWidget {
  final Post post;
  final VoidCallback onTap;
  final bool showRank;
  final int? rank;

  const PostCard({
    Key? key,
    required this.post,
    required this.onTap,
    this.showRank = false,
    this.rank,
  }) : super(key: key);

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> {
  late Post _post; // Store mutable post in state
  Vote? _userVote;
  bool _isVoting = false;

  @override
  void initState() {
    super.initState();
    _post = widget.post; // Initialize from widget
    _loadUserVote();
  }

  Future<void> _loadUserVote() async {
    final vote = await VoteService.getUserVote(_post.id);
    if (mounted) {
      setState(() {
        _userVote = vote;
      });
    }
  }

  // Generate human-readable excerpt from JSON blocks
  String _generateExcerpt(String bodyPlain) {
    if (bodyPlain.isEmpty) return 'No content available';

    try {
      // Parse the JSON blocks
      final json = jsonDecode(bodyPlain) as List<dynamic>;

      // Extract text from blocks to create readable excerpt
      StringBuffer excerpt = StringBuffer();

      for (var blockJson in json) {
        final type = ContentBlockType.values[blockJson['type'] as int];
        final text = blockJson['text'] as String? ?? '';
        final listItems = List<String>.from(blockJson['listItems'] ?? []);

        switch (type) {
          case ContentBlockType.heading:
          case ContentBlockType.subHeading:
          case ContentBlockType.paragraph:
            if (text.isNotEmpty) {
              excerpt.write(text);
              excerpt.write(' ');
            }
            break;
          case ContentBlockType.bulletedList:
            for (var item in listItems) {
              if (item.isNotEmpty) {
                excerpt.write('• $item ');
              }
            }
            break;
          case ContentBlockType.link:
            if (text.isNotEmpty) {
              excerpt.write(text);
              excerpt.write(' ');
            }
            break;
          case ContentBlockType.image:
            excerpt.write('[Image] ');
            break;
          case ContentBlockType.file:
            excerpt.write('[File: ${text.isNotEmpty ? text : 'Attachment'}] ');
            break;
        }

        // Stop if we have enough text for preview
        if (excerpt.length > 300) break;
      }

      String result = excerpt.toString().trim();
      if (result.isEmpty) return 'No readable content available';

      // Truncate if too long
      return result.length > 200 ? '${result.substring(0, 200)}...' : result;
    } catch (e) {
      // Fallback: if JSON parsing fails, try to show plain text excerpt
      print('Error parsing bodyPlain JSON: $e');
      return bodyPlain.length > 200
          ? '${bodyPlain.substring(0, 200)}...'
          : bodyPlain;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Rank indicator (for top posts)
              if (widget.showRank && widget.rank != null) ...[
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: _getRankColor(widget.rank!),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      '${widget.rank}',
                      style: GoogleFonts.montserrat(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
              ],

              // Main content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Scope badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _post.scope.isPublic
                            ? Colors.blue[50]
                            : Colors.orange,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _post.scope.isPublic
                              ? Colors.blue[200]!
                              : Colors.orange[200]!,
                          width: 0.5,
                        ),
                      ),
                      child: Text(
                        _post.scope.displayName,
                        style: GoogleFonts.montserrat(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: _post.scope.isPublic
                              ? Colors.blue[700]
                              : Colors.orange[700],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Title
                    Text(
                      _post.title,
                      style: GoogleFonts.lora(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        height: 1.3,
                        color: Colors.black87,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),

                    // Excerpt - shows human-readable content
                    Text(
                      _generateExcerpt(_post.bodyPlain),
                      style: GoogleFonts.lora(
                        fontSize: 16,
                        height: 1.5,
                        color: Colors.grey[700],
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 16),

                    // Bottom row
                    Row(
                      children: [
                        // Author avatar
                        CircleAvatar(
                          backgroundColor: Colors.blue[100],
                          radius: 16,
                          child: Text(
                            (_post.authorName ?? 'U')[0].toUpperCase(),
                            style: GoogleFonts.montserrat(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.blue[600],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),

                        // Author info
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _post.authorName ?? 'Unknown',
                                style: GoogleFonts.montserrat(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black87,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              Row(
                                children: [
                                  Text(
                                    _formatTimestamp(_post.createdAt),
                                    style: GoogleFonts.montserrat(
                                      fontSize: 11,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                  Text(
                                    ' • ${_post.readingTime}',
                                    style: GoogleFonts.montserrat(
                                      fontSize: 11,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        // Engagement metrics
                        Row(
                          children: [
                            // Vote buttons - UPDATED with animated emojis
                            _buildVoteButton(
                              isUpvote: true,
                              isSelected: _userVote?.value == 1,
                              onTap: () => _vote(1),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '${_post.score}',
                              style: GoogleFonts.montserrat(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: _getScoreColor(),
                              ),
                            ),
                            const SizedBox(width: 6),
                            _buildVoteButton(
                              isUpvote: false,
                              isSelected: _userVote?.value == -1,
                              onTap: () => _vote(-1),
                            ),
                            const SizedBox(width: 16),

                            // Comment count
                            Row(
                              children: [
                                Icon(
                                  Icons.chat_bubble_outline,
                                  size: 16,
                                  color: Colors.grey[600],
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '${_post.commentCount}',
                                  style: GoogleFonts.montserrat(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Header image (if exists)
              if (_post.imageUrl != null) ...[
                const SizedBox(width: 16),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    _post.imageUrl!,
                    width: 80,
                    height: 80,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        width: 80,
                        height: 80,
                        color: Colors.grey[200],
                        child: Icon(
                          Icons.image_not_supported,
                          color: Colors.grey[400],
                          size: 24,
                        ),
                      );
                    },
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // UPDATED: Vote button with animated thumbs up/down
  Widget _buildVoteButton({
    required bool isUpvote,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    // Choose emoji based on vote type and selection state
    AnimatedEmojiData emojiData;
    Color? backgroundColor;
    Color? borderColor;

    if (isUpvote) {
      emojiData = AnimatedEmojis.thumbsUp;
      backgroundColor = isSelected ? Colors.green[50] : Colors.grey;
      borderColor = isSelected ? Colors.green : Colors.grey[200];
    } else {
      emojiData = AnimatedEmojis.thumbsDown;
      backgroundColor = isSelected ? Colors.red[50] : Colors.grey[50];
      borderColor = isSelected ? Colors.red : Colors.grey[200];
    }

    return GestureDetector(
      onTap: _isVoting ? null : onTap,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: borderColor!, width: 1),
        ),
        child: AnimatedEmoji(
          emojiData,
          size: 18,
          repeat: isSelected, // Only animate when selected
        ),
      ),
    );
  }

  Future<void> _vote(int value) async {
    final currentUser = AuthService.currentUser;
    if (currentUser == null) {
      _showLoginPrompt();
      return;
    }

    if (_isVoting) return;

    setState(() {
      _isVoting = true;
    });

    // Declare and initialize BEFORE try so they are in scope for catch
    Vote? prevVote = _userVote;
    int prevScore = _post.score;

    try {
      final newValue = (_userVote?.value == value) ? 0 : value;

      setState(() {
        if (newValue == 0) {
          // Removing existing vote
          _userVote = null;
          _post = _post.copyWith(score: prevScore - (prevVote?.value ?? 0));
        } else {
          // Applying/updating vote
          _userVote = Vote(
            id: Vote.generateId(_post.id, currentUser.uid),
            postId: _post.id,
            userId: currentUser.uid,
            value: newValue,
            createdAt: Timestamp.now(),
          );
          final scoreDelta = newValue - (prevVote?.value ?? 0);
          _post = _post.copyWith(score: prevScore + scoreDelta);
        }
      });

      // Persist
      await VoteService.setVote(_post.id, newValue);

      // Analytics
      AnalyticsService.logVote(_post.id, newValue);
    } catch (e) {
      // Rollback using the variables defined outside try
      setState(() {
        _userVote = prevVote;
        _post = _post.copyWith(score: prevScore);
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to vote. Please try again.')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isVoting = false;
        });
      }
    }
  }

  void _showLoginPrompt() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Sign in required',
          style: GoogleFonts.montserrat(fontWeight: FontWeight.w600),
        ),
        content: Text(
          'Please sign in to vote and interact with posts.',
          style: GoogleFonts.montserrat(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _triggerAuth();
            },
            child: const Text('Sign In'),
          ),
        ],
      ),
    );
  }

  void _triggerAuth() async {
    try {
      await AuthService.signInAnonymously();
      _loadUserVote(); // Reload vote state after auth
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to sign in. Please try again.')),
        );
      }
    }
  }

  Color _getRankColor(int rank) {
    if (rank <= 3) {
      return Colors.orange[600]!; // Gold/bronze for top 3
    } else if (rank <= 10) {
      return Colors.blue[600]!; // Blue for top 10
    } else {
      return Colors.grey[600]!; // Grey for others
    }
  }

  Color _getScoreColor() {
    if (_post.score > 0) {
      return Colors.green[600]!;
    } else if (_post.score < 0) {
      return Colors.red[600]!;
    } else {
      return Colors.grey!;
    }
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
}

/// Variant for compact list view (optional)
class CompactPostCard extends StatelessWidget {
  final Post post;
  final VoidCallback onTap;

  const CompactPostCard({Key? key, required this.post, required this.onTap})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title
            Text(
              post.title,
              style: GoogleFonts.lora(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),

            // Meta info
            Row(
              children: [
                Text(
                  post.authorName ?? 'Unknown',
                  style: GoogleFonts.montserrat(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[600],
                  ),
                ),
                Text(' • ', style: TextStyle(color: Colors.grey[600])),
                Text(
                  _formatTimestamp(post.createdAt),
                  style: GoogleFonts.montserrat(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
                const Spacer(),
                // Quick metrics
                Text(
                  '${post.score} votes • ${post.commentCount} comments',
                  style: GoogleFonts.montserrat(
                    fontSize: 11,
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatTimestamp(Timestamp timestamp) {
    final date = timestamp.toDate();
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}

// ContentBlock enum for parsing
enum ContentBlockType {
  heading,
  subHeading,
  paragraph,
  bulletedList,
  image,
  link,
  file,
}

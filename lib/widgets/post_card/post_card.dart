import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

import '../../models/power_pulse/powerpulse_models.dart';
import '../../services/power_pulse_service/powerpulse_services.dart';

class PostCard extends StatefulWidget {
  final Post post;
  final VoidCallback onTap;
  final bool showRank;
  final int? rank;
  final bool isCompact;

  const PostCard({
    Key? key,
    required this.post,
    required this.onTap,
    this.showRank = false,
    this.rank,
    this.isCompact = false,
  }) : super(key: key);

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> with TickerProviderStateMixin {
  late Post _post;
  Vote? _userVote;
  bool _isVoting = false;
  late AnimationController _voteAnimationController;
  late Animation<double> _voteScaleAnimation;
  String? _cachedExcerpt;

  @override
  void initState() {
    super.initState();
    _post = widget.post;
    _setupAnimations();
    _loadUserVote();
    _generateCachedExcerpt();
  }

  @override
  void dispose() {
    _voteAnimationController.dispose();
    super.dispose();
  }

  void _setupAnimations() {
    _voteAnimationController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _voteScaleAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(
        parent: _voteAnimationController,
        curve: Curves.easeInOut,
      ),
    );
  }

  Future<void> _loadUserVote() async {
    try {
      final vote = await VoteService.getUserVote(postId: _post.id);
      if (mounted) {
        setState(() {
          _userVote = vote;
        });
      }
    } catch (e) {
      debugPrint('Error loading user vote: $e');
    }
  }

  void _generateCachedExcerpt() {
    if (_post.excerpt != null && _post.excerpt!.isNotEmpty) {
      _cachedExcerpt = _post.excerpt!;
    } else {
      _cachedExcerpt = _generateExcerpt(_post.bodyPlain);
    }
  }

  String _generateExcerpt(String bodyPlain) {
    if (bodyPlain.isEmpty) return 'No content available';
    try {
      final json = jsonDecode(bodyPlain) as List;
      final excerptBuffer = StringBuffer();
      int wordCount = 0;
      const maxWords = 35;

      for (var blockJson in json) {
        if (wordCount >= maxWords) break;
        final type = ContentBlockType.values[blockJson['type'] as int];
        final text = (blockJson['text'] as String? ?? '').trim();
        final listItems = List<String>.from(blockJson['listItems'] ?? []);
        final flowchartData =
            blockJson['flowchartData'] as Map<String, dynamic>?;
        final excelData = blockJson['excelData'] as Map<String, dynamic>?;

        switch (type) {
          case ContentBlockType.heading:
          case ContentBlockType.subHeading:
          case ContentBlockType.paragraph:
            if (text.isNotEmpty) {
              final words = text.split(RegExp(r'\s+'));
              final wordsToAdd = (maxWords - wordCount).clamp(0, words.length);
              excerptBuffer.write(words.take(wordsToAdd).join(' '));
              wordCount += wordsToAdd;
              if (wordCount < maxWords) excerptBuffer.write(' ');
            }
            break;

          case ContentBlockType.bulletedList:
          case ContentBlockType.numberedList:
            for (var item in listItems) {
              if (wordCount >= maxWords) break;
              if (item.trim().isNotEmpty) {
                final words = item.trim().split(RegExp(r'\s+'));
                final wordsToAdd = (maxWords - wordCount).clamp(
                  0,
                  words.length,
                );
                excerptBuffer.write('• ${words.take(wordsToAdd).join(' ')} ');
                wordCount += wordsToAdd;
              }
            }
            break;

          case ContentBlockType.link:
            if (text.isNotEmpty && wordCount < maxWords) {
              excerptBuffer.write('🔗 $text ');
              wordCount += text.split(RegExp(r'\s+')).length;
            }
            break;

          case ContentBlockType.image:
            if (wordCount < maxWords) {
              excerptBuffer.write('📷 Image ');
              wordCount += 1;
            }
            break;

          case ContentBlockType.file:
            if (wordCount < maxWords) {
              final fileName = text.isNotEmpty ? text : 'Attachment';
              excerptBuffer.write('📎 $fileName ');
              wordCount += fileName.split(RegExp(r'\s+')).length;
            }
            break;

          case ContentBlockType.flowchart:
            if (wordCount < maxWords) {
              final description =
                  flowchartData?['description']?.toString() ?? 'Flowchart';
              excerptBuffer.write('📊 $description ');
              wordCount += description.split(RegExp(r'\s+')).length;
            }
            break;

          case ContentBlockType.excelTable:
            if (wordCount < maxWords) {
              final title = excelData?['title']?.toString() ?? 'Excel Table';
              final rows = excelData?['rows'] ?? 0;
              final columns = excelData?['columns'] ?? 0;

              String tableDescription;
              if (rows > 0 && columns > 0) {
                tableDescription = '📊 $title (${rows}×${columns} table)';
              } else {
                tableDescription = '📊 $title';
              }

              final data = excelData?['data'] as List?;
              if (data != null && data.isNotEmpty && wordCount < maxWords - 3) {
                final firstRow = data[0] as List?;
                if (firstRow != null && firstRow.isNotEmpty) {
                  final firstCellText = firstRow[0]?.toString()?.trim();
                  if (firstCellText != null && firstCellText.isNotEmpty) {
                    final cellWords = firstCellText.split(RegExp(r'\s+'));
                    final availableWords = maxWords - wordCount - 3;
                    if (availableWords > 0) {
                      final sampleWords = cellWords
                          .take(availableWords.clamp(0, 3))
                          .join(' ');
                      tableDescription += ' - $sampleWords...';
                    }
                  }
                }
              }
              excerptBuffer.write('$tableDescription ');
              wordCount += tableDescription.split(RegExp(r'\s+')).length;
            }
            break;
        }
      }

      String result = excerptBuffer.toString().trim();
      if (result.isEmpty) return 'No readable content available';
      return wordCount >= maxWords ? '$result...' : result;
    } catch (e) {
      debugPrint('Error parsing bodyPlain JSON: $e');
      return bodyPlain.length > 150
          ? '${bodyPlain.substring(0, 150)}...'
          : bodyPlain;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Post: ${_post.title}',
      child: widget.isCompact ? _buildCompactCard() : _buildFullCard(),
    );
  }

  // Full card UI
  Widget _buildFullCard() {
    return Card(
      elevation: 2,
      shadowColor: Colors.black.withOpacity(0.1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          widget.onTap();
          AnalyticsService.logPostView(_post.id);
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 16),
              _buildContent(),
              const SizedBox(height: 16),
              _buildFooter(),
            ],
          ),
        ),
      ),
    );
  }

  // Compact card UI
  Widget _buildCompactCard() {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          widget.onTap();
          AnalyticsService.logPostView(_post.id);
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              if (widget.showRank && widget.rank != null) ...[
                _buildRankBadge(),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(compact: true),
                    const SizedBox(height: 8),
                    _buildTitle(compact: true),
                    const SizedBox(height: 12),
                    _buildCompactFooter(),
                  ],
                ),
              ),
              if (_post.imageUrl != null) ...[
                const SizedBox(width: 12),
                _buildThumbnail(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // Header, flair, scope, menu
  Widget _buildHeader({bool compact = false}) {
    return Row(
      children: [
        if (widget.showRank && widget.rank != null && !compact) ...[
          _buildRankBadge(),
          const SizedBox(width: 12),
        ],
        _buildScopeBadge(),
        if (_post.flair != null) ...[
          const SizedBox(width: 8),
          _buildFlairBadge(),
        ],
        if (!compact) ...[const Spacer(), _buildMenuButton()],
      ],
    );
  }

  Widget _buildRankBadge() {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: _getRankGradient(widget.rank!),
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: _getRankColor(widget.rank!).withOpacity(0.3),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
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
    );
  }

  Widget _buildScopeBadge() {
    final isPublic = _post.scope.isPublic;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isPublic ? Colors.blue[50] : Colors.orange[50],
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isPublic ? Colors.blue[600]! : Colors.orange[600]!,
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isPublic ? Icons.public : Icons.location_on,
            size: 12,
            color: isPublic ? Colors.blue[700] : Colors.orange[700],
          ),
          const SizedBox(width: 4),
          Text(
            _post.scope.displayName,
            style: GoogleFonts.montserrat(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isPublic ? Colors.blue[700] : Colors.orange,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFlairBadge() {
    final flair = _post.flair;
    if (flair == null) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: _getFlairColor(flair).withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _getFlairColor(flair), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (flair.emoji != null) ...[
            Text(flair.emoji!, style: const TextStyle(fontSize: 12)),
            const SizedBox(width: 4),
          ],
          Text(
            flair.name,
            style: GoogleFonts.montserrat(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: _getFlairColor(flair),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuButton() {
    return PopupMenuButton<String>(
      icon: Icon(Icons.more_horiz, color: Colors.grey[600]),
      onSelected: _handleMenuAction,
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: 'share',
          child: Row(
            children: [
              Icon(Icons.share, size: 18),
              SizedBox(width: 8),
              Text('Share'),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'bookmark',
          child: Row(
            children: [
              Icon(Icons.bookmark_border, size: 18),
              SizedBox(width: 8),
              Text('Bookmark'),
            ],
          ),
        ),
        if (AuthService.currentUser?.uid == _post.authorId)
          const PopupMenuItem(
            value: 'delete',
            child: Row(
              children: [
                Icon(Icons.delete_outline, size: 18),
                SizedBox(width: 8),
                Text('Delete'),
              ],
            ),
          ),
        const PopupMenuItem(
          value: 'report',
          child: Row(
            children: [
              Icon(Icons.flag_outlined, size: 18),
              SizedBox(width: 8),
              Text('Report'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTitle(),
        const SizedBox(height: 12),
        if (_cachedExcerpt != null && _cachedExcerpt!.isNotEmpty) ...[
          _buildExcerpt(),
          const SizedBox(height: 12),
        ],
        if (_post.imageUrl != null) _buildHeroImage(),
      ],
    );
  }

  Widget _buildTitle({bool compact = false}) {
    return Text(
      _post.title,
      style: GoogleFonts.lora(
        fontSize: compact ? 16 : 22,
        fontWeight: FontWeight.w700,
        height: 1.3,
        color: Colors.black87,
      ),
      maxLines: compact ? 2 : 3,
      overflow: TextOverflow.ellipsis,
      semanticsLabel: _post.title,
    );
  }

  Widget _buildExcerpt() {
    return Text(
      _cachedExcerpt!,
      style: GoogleFonts.lora(
        fontSize: 16,
        height: 1.6,
        color: Colors.grey[700],
      ),
      maxLines: 3,
      overflow: TextOverflow.ellipsis,
      semanticsLabel: _cachedExcerpt,
    );
  }

  Widget _buildHeroImage() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: CachedNetworkImage(
        imageUrl: _post.imageUrl!,
        height: 200,
        width: double.infinity,
        fit: BoxFit.cover,
        placeholder: (context, url) => Container(
          height: 200,
          color: Colors.grey[100],
          child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
        ),
        errorWidget: (context, url, error) => Container(
          height: 200,
          color: Colors.grey[100],
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.image_not_supported,
                color: Colors.grey[400],
                size: 32,
              ),
              const SizedBox(height: 8),
              Text(
                'Image unavailable',
                style: GoogleFonts.montserrat(
                  fontSize: 12,
                  color: Colors.grey[500],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildThumbnail() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: CachedNetworkImage(
        imageUrl: _post.imageUrl!,
        width: 64,
        height: 64,
        fit: BoxFit.cover,
        placeholder: (context, url) => Container(
          width: 64,
          height: 64,
          color: Colors.grey[200],
          child: const Center(
            child: SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ),
        errorWidget: (context, url, error) => Container(
          width: 64,
          height: 64,
          color: Colors.grey[200],
          child: Icon(Icons.image_not_supported, color: Colors.grey, size: 20),
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return Row(
      children: [_buildAuthorInfo(), const Spacer(), _buildEngagementMetrics()],
    );
  }

  Widget _buildCompactFooter() {
    return Row(
      children: [
        _buildAuthorInfo(compact: true),
        const Spacer(),
        _buildCompactMetrics(),
      ],
    );
  }

  Widget _buildAuthorInfo({bool compact = false}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircleAvatar(
          backgroundColor: Colors.blue[100],
          radius: compact ? 12 : 16,
          child: Text(
            (_post.authorName ?? 'U').characters.first.toUpperCase(),
            style: GoogleFonts.montserrat(
              fontSize: compact ? 10 : 12,
              fontWeight: FontWeight.w600,
              color: Colors.blue[600],
            ),
          ),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _post.authorName ?? 'Unknown',
              style: GoogleFonts.montserrat(
                fontSize: compact ? 11 : 12,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            if (!compact)
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
      ],
    );
  }

  Widget _buildEngagementMetrics() {
    return Row(
      children: [
        _buildVoteSection(),
        const SizedBox(width: 16),
        _buildCommentSection(),
      ],
    );
  }

  Widget _buildCompactMetrics() {
    return Row(
      children: [
        Icon(
          _userVote?.value == 1 ? Icons.thumb_up : Icons.thumb_up_outlined,
          size: 16,
          color: _userVote?.value == 1 ? Colors.green[600] : Colors.grey,
        ),
        const SizedBox(width: 4),
        Text(
          '${_post.score}',
          style: GoogleFonts.montserrat(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: _getScoreColor(),
          ),
        ),
        const SizedBox(width: 12),
        Icon(Icons.chat_bubble_outline, size: 14, color: Colors.grey[600]),
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
    );
  }

  Widget _buildVoteSection() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Upvote Button
        ScaleTransition(
          scale: _voteScaleAnimation,
          child: GestureDetector(
            onTap: _isVoting
                ? null
                : () {
                    HapticFeedback.lightImpact();
                    _voteAnimationController.forward().then((_) {
                      _voteAnimationController.reverse();
                    });
                    _vote(1);
                  },
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Icon(
                _userVote?.value == 1
                    ? Icons.thumb_up
                    : Icons.thumb_up_outlined,
                size: 22,
                color: _userVote?.value == 1
                    ? Colors.green[600]
                    : Colors.grey[600],
              ),
            ),
          ),
        ),

        // Score Display
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            '${_post.score}',
            style: GoogleFonts.montserrat(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: _getScoreColor(),
            ),
          ),
        ),

        // Downvote Button
        ScaleTransition(
          scale: _voteScaleAnimation,
          child: GestureDetector(
            onTap: _isVoting
                ? null
                : () {
                    HapticFeedback.lightImpact();
                    _voteAnimationController.forward().then((_) {
                      _voteAnimationController.reverse();
                    });
                    _vote(-1);
                  },
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Icon(
                _userVote?.value == -1
                    ? Icons.thumb_down
                    : Icons.thumb_down_outlined,
                size: 22,
                color: _userVote?.value == -1 ? Colors.red[600] : Colors.grey,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCommentSection() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.chat_bubble_outline, size: 18, color: Colors.grey[600]),
        const SizedBox(width: 6),
        Text(
          '${_post.commentCount}',
          style: GoogleFonts.montserrat(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.grey[600],
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
    final Vote? prevVote = _userVote;
    final int prevScore = _post.score;

    try {
      final newValue = (_userVote?.value == value) ? 0 : value;

      // Optimistic UI update
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

      // Cache updated post
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'post_${_post.id}',
        jsonEncode({..._post.toJson(), 'id': _post.id, 'score': _post.score}),
      );
    } catch (e) {
      setState(() {
        _userVote = prevVote;
        _post = _post.copyWith(score: prevScore);
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Failed to vote. Please try again.'),
            backgroundColor: Colors.red[600],
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isVoting = false);
    }
  }

  void _handleMenuAction(String action) {
    switch (action) {
      case 'share':
        _sharePost();
        break;
      case 'bookmark':
        _bookmarkPost();
        break;
      case 'delete':
        _deletePost();
        break;
      case 'report':
        _reportPost();
        break;
    }
  }

  void _sharePost() {
    HapticFeedback.mediumImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Share functionality not implemented yet.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _bookmarkPost() {
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Post bookmarked!'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _deletePost() async {
    final currentUser = AuthService.currentUser;
    if (currentUser == null || currentUser.uid != _post.authorId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Only the post author can delete this post.'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Post'),
        content: const Text('Are you sure you want to delete this post?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await PostService.deletePost(_post.id);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Post deleted successfully.'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('Failed to delete post.'),
                      backgroundColor: Colors.red[400],
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _reportPost() {
    HapticFeedback.heavyImpact();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Report Post'),
        content: const Text('Are you sure you want to report this post?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Post reported. Thank you for your feedback.'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            child: const Text('Report'),
          ),
        ],
      ),
    );
  }

  void _showLoginPrompt() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Sign in required',
          style: GoogleFonts.montserrat(fontWeight: FontWeight.w600),
        ),
        content: Text(
          'Please sign in to vote and interact with posts.',
          style: GoogleFonts.lora(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _triggerAuth();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue[600],
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Sign In'),
          ),
        ],
      ),
    );
  }

  void _triggerAuth() async {
    try {
      await AuthService.signInAnonymously();
      await _loadUserVote();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Failed to sign in. Please try again.'),
            backgroundColor: Colors.red[400],
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  List<Color> _getRankGradient(int rank) {
    if (rank <= 3) {
      return [Colors.orange[400]!, Colors.orange[600]!];
    } else if (rank <= 10) {
      return [Colors.blue!, Colors.blue!];
    } else {
      return [Colors.grey!, Colors.grey!];
    }
  }

  Color _getRankColor(int rank) {
    if (rank <= 3) return Colors.orange[600]!;
    if (rank <= 10) return Colors.blue!;
    return Colors.grey!;
  }

  Color _getScoreColor() {
    if (_post.score > 0) return Colors.green[700]!;
    if (_post.score < 0) return Colors.red!;
    return Colors.grey!;
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

  String _formatTimestamp(Timestamp timestamp) {
    final date = timestamp.toDate();
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inMinutes < 1) {
      return 'now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d';
    } else if (difference.inDays < 30) {
      return '${(difference.inDays / 7).floor()}w';
    } else {
      return '${date.day}/${date.month}/${date.year % 100}';
    }
  }
}

// lib/screens/power_pulse_dashboard_screen.dart

import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/hierarchy_models.dart';
import '../../models/power_pulse/powerpulse_models.dart';
import '../../services/power_pulse_service/powerpulse_services.dart';
import '../../widgets/post_card/post_card.dart';
import 'post_create_screen.dart';
import 'post_detail_screen.dart';

class PowerPulseDashboardScreen extends StatefulWidget {
  const PowerPulseDashboardScreen({Key? key}) : super(key: key);

  @override
  State<PowerPulseDashboardScreen> createState() =>
      _PowerPulseDashboardScreenState();
}

class _PowerPulseDashboardScreenState extends State<PowerPulseDashboardScreen>
    with TickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  late TabController _tabController;
  String? selectedZoneId;
  String? selectedZoneName;
  bool _isLoadingZones = false;
  List<Zone> _zones = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadZones();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  bool get wantKeepAlive => true;

  Future<void> _loadZones() async {
    if (!mounted) return;

    setState(() {
      _isLoadingZones = true;
      _error = null;
    });

    try {
      final zones = await HierarchyService.getZones();
      final prefs = await SharedPreferences.getInstance();

      // Convert zones to JSON-safe format before caching
      final zonesJson = zones
          .map(
            (z) => {
              'id': z.id,
              'name': z.name,
              'description': z.description,
              'createdBy': z.createdBy,
              'companyId': z.companyId,
              'address': z.address,
              'landmark': z.landmark,
              'contactNumber': z.contactNumber,
              'contactPerson': z.contactPerson,
              'contactDesignation': z.contactDesignation,
              'createdAt': z.createdAt?.millisecondsSinceEpoch,
            },
          )
          .toList();

      await prefs.setString('cached_zones', jsonEncode(zonesJson));

      if (mounted) {
        setState(() {
          _zones = zones;
          _isLoadingZones = false;
        });
      }
    } catch (e) {
      final prefs = await SharedPreferences.getInstance();
      final cachedZones = prefs.getString('cached_zones');
      if (cachedZones != null) {
        try {
          await _cleanupBadCache();
          final zoneMaps = List<Map<String, dynamic>>.from(
            jsonDecode(cachedZones),
          );
          _zones = zoneMaps
              .map(
                (map) => Zone(
                  id: map['id'] ?? '',
                  name: map['name'] ?? '',
                  description: map['description'],
                  createdBy: map['createdBy'],
                  createdAt: map['createdAt'] != null
                      ? Timestamp.fromMillisecondsSinceEpoch(map['createdAt'])
                      : null,
                  companyId: map['companyId'] ?? '',
                  address: map['address'],
                  landmark: map['landmark'],
                  contactNumber: map['contactNumber'],
                  contactPerson: map['contactPerson'],
                  contactDesignation: map['contactDesignation'],
                ),
              )
              .toList();
        } catch (cacheError) {
          debugPrint('Error parsing cached zones: $cacheError');
          _zones = [];
        }
      }
      if (mounted) {
        setState(() {
          _error = cachedZones != null && _zones.isNotEmpty
              ? null
              : 'Failed to load zones: $e';
          _isLoadingZones = false;
        });
      }
      debugPrint('Error loading zones: $e');
    }
  }

  Future<void> _cleanupBadCache() async {
    final prefs = await SharedPreferences.getInstance();

    for (final key in prefs.getKeys()) {
      if (key.startsWith('post_')) {
        final raw = prefs.getString(key);
        if (raw != null) {
          try {
            final map = jsonDecode(raw) as Map<String, dynamic>;
            final bodyPlain = map['bodyPlain'];
            final bodyDelta = map['bodyDelta'];

            bool needsUpdate = false;

            if (bodyPlain is! String) {
              map['bodyPlain'] = jsonEncode(bodyPlain);
              needsUpdate = true;
            }

            if (bodyDelta is! String) {
              map['bodyDelta'] = jsonEncode(bodyDelta);
              needsUpdate = true;
            }

            if (needsUpdate) {
              await prefs.setString(key, jsonEncode(map));
            }
          } catch (_) {
            await prefs.remove(key);
          }
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          _buildZoneSelector(),
          _buildTabBar(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [_buildLatestFeed(), _buildTopFeed()],
            ),
          ),
        ],
      ),
      floatingActionButton: _buildFloatingActionButton(),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      centerTitle: true,
      title: Text(
        'PowerPulse',
        style: GoogleFonts.lora(
          fontSize: 22,
          fontWeight: FontWeight.w600,
          color: Colors.black87,
        ),
      ),
      actions: [
        IconButton(
          icon: Icon(Icons.search, color: Colors.grey[600]),
          onPressed: () => _showSearchDelegate(context),
          tooltip: 'Search posts',
        ),
        PopupMenuButton<String>(
          icon: Icon(Icons.more_vert, color: Colors.grey[600]),
          onSelected: _handleMenuAction,
          itemBuilder: (context) => [
            const PopupMenuItem(value: 'profile', child: Text('Profile')),
            const PopupMenuItem(value: 'settings', child: Text('Settings')),
            const PopupMenuItem(value: 'about', child: Text('About')),
          ],
        ),
      ],
    );
  }

  Widget _buildZoneSelector() {
    if (_isLoadingZones && _zones.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16.0),
        child: CircularProgressIndicator(color: Colors.blueGrey[400]),
      );
    }

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: DropdownButtonFormField<String>(
        value: selectedZoneId,
        decoration: InputDecoration(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 8,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.grey[300]!),
          ),
          filled: true,
          fillColor: Colors.grey[50],
        ),
        hint: Text(
          'Select a Zone',
          style: GoogleFonts.montserrat(fontSize: 14, color: Colors.grey[600]),
        ),
        items: [
          DropdownMenuItem(
            value: null,
            child: Text(
              'All Zones (Public)',
              style: GoogleFonts.montserrat(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          ..._zones.map(
            (zone) => DropdownMenuItem(
              value: zone.id,
              child: Text(
                zone.name,
                style: GoogleFonts.montserrat(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
        onChanged: (value) {
          setState(() {
            selectedZoneId = value;
            selectedZoneName = value == null
                ? null
                : _zones.firstWhere((zone) => zone.id == value).name;
          });
        },
        dropdownColor: Colors.white,
        icon: Icon(Icons.arrow_drop_down, color: Colors.grey[600]),
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: TabBar(
        controller: _tabController,
        labelColor: Colors.blueGrey[700],
        unselectedLabelColor: Colors.grey[500],
        indicatorColor: Colors.blueGrey[700],
        indicatorWeight: 2,
        labelStyle: GoogleFonts.montserrat(
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: GoogleFonts.montserrat(
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        tabs: const [
          Tab(text: 'Latest'),
          Tab(text: 'Top'),
        ],
      ),
    );
  }

  Widget _buildLatestFeed() {
    return StreamBuilder<List<Post>>(
      stream: selectedZoneId == null
          ? PostService.streamPublicPosts()
          : PostService.streamZonePosts(selectedZoneId!),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingState();
        }

        if (snapshot.hasError) {
          return _buildErrorState(
            'Error loading posts',
            snapshot.error.toString(),
            onRetry: () => setState(() {}),
          );
        }

        final posts = snapshot.data ?? [];

        if (posts.isEmpty) {
          return _buildEmptyState(
            icon: Icons.inbox_outlined,
            title: 'No posts yet',
            subtitle: 'Start the conversation with your ideas.',
            actionText: 'Create Post',
            onAction: _navigateToCreatePost,
          );
        }

        return RefreshIndicator(
          color: Colors.blueGrey[400],
          onRefresh: () async {
            setState(() {});
          },
          child: ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            itemCount: posts.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              return PostCard(
                post: posts[index],
                onTap: () => _navigateToPost(posts[index]),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildTopFeed() {
    return StreamBuilder<List<Post>>(
      stream: PostService.streamTopPosts(zoneId: selectedZoneId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingState();
        }

        if (snapshot.hasError) {
          return _buildErrorState(
            'Error loading trending posts',
            snapshot.error.toString(),
            onRetry: () => setState(() {}),
          );
        }

        final posts = snapshot.data ?? [];

        if (posts.isEmpty) {
          return _buildEmptyState(
            icon: Icons.trending_up_outlined,
            title: 'No trending posts',
            subtitle: 'Share something to spark a trend.',
            actionText: 'Create Post',
            onAction: _navigateToCreatePost,
          );
        }

        return RefreshIndicator(
          color: Colors.blueGrey[400],
          onRefresh: () async {
            setState(() {});
          },
          child: ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            itemCount: posts.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              return PostCard(
                post: posts[index],
                onTap: () => _navigateToPost(posts[index]),
                showRank: true,
                rank: index + 1,
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: Colors.blueGrey[400]),
          const SizedBox(height: 12),
          Text(
            'Loading...',
            style: GoogleFonts.montserrat(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
        ],
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
            Icon(icon, size: 60, color: Colors.grey[400]),
            const SizedBox(height: 12),
            Text(
              title,
              style: GoogleFonts.montserrat(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: GoogleFonts.montserrat(
                fontSize: 14,
                color: Colors.grey[500],
              ),
              textAlign: TextAlign.center,
            ),
            if (actionText != null && onAction != null) ...[
              const SizedBox(height: 16),
              TextButton(
                onPressed: onAction,
                child: Text(
                  actionText,
                  style: GoogleFonts.montserrat(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.blueGrey[700],
                  ),
                ),
              ),
            ],
          ],
        ),
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
            Icon(Icons.error_outline, size: 60, color: Colors.grey[400]),
            const SizedBox(height: 12),
            Text(
              title,
              style: GoogleFonts.montserrat(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              error.length > 100 ? '${error.substring(0, 100)}...' : error,
              style: GoogleFonts.montserrat(
                fontSize: 14,
                color: Colors.grey[500],
              ),
              textAlign: TextAlign.center,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              TextButton(
                onPressed: onRetry,
                child: Text(
                  'Retry',
                  style: GoogleFonts.montserrat(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.blueGrey[700],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFloatingActionButton() {
    return FloatingActionButton(
      onPressed: _navigateToCreatePost,
      backgroundColor: Colors.blueGrey[700],
      child: const Icon(Icons.edit, color: Colors.white),
      tooltip: 'Create a new post',
    );
  }

  void _navigateToPost(Post post) {
    HapticFeedback.lightImpact();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PostDetailScreen(postId: post.id),
      ),
    );
    AnalyticsService.logPostView(post.id);
  }

  void _navigateToCreatePost() {
    HapticFeedback.lightImpact();
    final currentUser = AuthService.currentUser;
    if (currentUser == null) {
      _showLoginPrompt();
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const PostCreateScreen()),
    ).then((result) {
      if (result == true) {
        setState(() {});
        AnalyticsService.logPostCreated(
          'new_post',
          selectedZoneId != null ? 'zone' : 'public',
          flair: null,
        );
      }
    });
  }

  void _showSearchDelegate(BuildContext context) {
    HapticFeedback.lightImpact();
    showSearch(context: context, delegate: PostSearchDelegate());
  }

  void _handleMenuAction(String action) {
    switch (action) {
      case 'profile':
        _showComingSoonDialog('Profile');
        break;
      case 'settings':
        _showComingSoonDialog('Settings');
        break;
      case 'about':
        _showAboutDialog();
        break;
    }
  }

  void _showComingSoonDialog(String feature) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text(
          feature,
          style: GoogleFonts.montserrat(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Text(
          '$feature functionality coming soon.',
          style: GoogleFonts.montserrat(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('OK', style: GoogleFonts.montserrat(fontSize: 14)),
          ),
        ],
      ),
    );
  }

  void _showAboutDialog() {
    showAboutDialog(
      context: context,
      applicationName: 'PowerPulse',
      applicationVersion: '1.0.0',
      applicationIcon: Icon(Icons.bolt, color: Colors.blueGrey[700], size: 32),
      children: [
        const SizedBox(height: 12),
        Text(
          'Igniting Ideas in Power & Transmission',
          style: GoogleFonts.montserrat(fontSize: 14),
        ),
      ],
    );
  }

  void _showLoginPrompt() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text(
          'Sign in required',
          style: GoogleFonts.montserrat(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Text(
          'Please sign in to create a post.',
          style: GoogleFonts.montserrat(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: GoogleFonts.montserrat(fontSize: 14)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await AuthService.signInWithGoogle();
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to sign in: $e'),
                      backgroundColor: Colors.red[400],
                    ),
                  );
                }
              }
            },
            child: Text(
              'Sign In',
              style: GoogleFonts.montserrat(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.blueGrey[700],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class PostSearchDelegate extends SearchDelegate<Post?> {
  final List<String> recentSearches = [];
  final List<String> popularSearches = ['Innovation', 'Transmission', 'Energy'];

  @override
  ThemeData appBarTheme(BuildContext context) {
    return Theme.of(context).copyWith(
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.white,
        elevation: 0,
        titleTextStyle: GoogleFonts.montserrat(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: Colors.black87,
        ),
        iconTheme: IconThemeData(color: Colors.grey[600]),
      ),
      inputDecorationTheme: InputDecorationTheme(
        hintStyle: GoogleFonts.montserrat(
          fontSize: 14,
          color: Colors.grey[500],
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        filled: true,
        fillColor: Colors.grey[100],
      ),
    );
  }

  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      if (query.isNotEmpty)
        IconButton(
          icon: Icon(Icons.clear, color: Colors.grey[600]),
          onPressed: () {
            query = '';
            showSuggestions(context);
          },
          tooltip: 'Clear search',
        ),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      icon: Icon(Icons.arrow_back, color: Colors.grey[600]),
      onPressed: () => close(context, null),
      tooltip: 'Back',
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    if (query.trim().isEmpty) {
      return _buildEmptySearchState('Enter a search term');
    }

    if (query.trim().length < 2) {
      return _buildEmptySearchState('Enter at least 2 characters');
    }

    if (!recentSearches.contains(query)) {
      recentSearches.add(query);
      if (recentSearches.length > 5) recentSearches.removeAt(0);
    }

    return FutureBuilder<List<Post>>(
      future: PostService.searchPosts(query),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(color: Colors.blueGrey[400]),
                const SizedBox(height: 12),
                Text(
                  'Searching...',
                  style: GoogleFonts.montserrat(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          );
        }

        if (snapshot.hasError) {
          return _buildErrorState(
            'Search failed',
            snapshot.error.toString(),
            onRetry: () => showResults(context),
          );
        }

        final posts = snapshot.data ?? [];

        if (posts.isEmpty) {
          return _buildEmptySearchState('No posts found for "$query"');
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: posts.length,
          separatorBuilder: (context, index) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            return PostCard(
              post: posts[index],
              isCompact: true,
              onTap: () {
                close(context, posts[index]);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        PostDetailScreen(postId: posts[index].id),
                  ),
                );
                AnalyticsService.logPostView(posts[index].id);
              },
            );
          },
        );
      },
    );
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    final suggestions = query.isEmpty
        ? recentSearches.isNotEmpty
              ? recentSearches
              : popularSearches
        : popularSearches
              .where((s) => s.toLowerCase().contains(query.toLowerCase()))
              .toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          query.isEmpty ? 'Recent Searches' : 'Suggested Searches',
          style: GoogleFonts.montserrat(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.grey[700],
          ),
        ),
        const SizedBox(height: 12),
        if (suggestions.isEmpty)
          _buildEmptySearchState(
            query.isEmpty ? 'No recent searches' : 'No suggestions found',
          ),
        ...suggestions.map(
          (suggestion) => ListTile(
            leading: Icon(
              query.isEmpty ? Icons.history : Icons.search,
              color: Colors.grey[600],
            ),
            title: Text(
              suggestion,
              style: GoogleFonts.montserrat(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            onTap: () {
              query = suggestion;
              showResults(context);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildEmptySearchState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 60, color: Colors.grey[400]),
            const SizedBox(height: 12),
            Text(
              message,
              style: GoogleFonts.montserrat(
                fontSize: 14,
                color: Colors.grey[500],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
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
            Icon(Icons.error_outline, size: 60, color: Colors.grey[400]),
            const SizedBox(height: 12),
            Text(
              title,
              style: GoogleFonts.montserrat(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              error.length > 100 ? '${error.substring(0, 100)}...' : error,
              style: GoogleFonts.montserrat(
                fontSize: 14,
                color: Colors.grey[500],
              ),
              textAlign: TextAlign.center,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              TextButton(
                onPressed: onRetry,
                child: Text(
                  'Retry',
                  style: GoogleFonts.montserrat(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.blueGrey[700],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  String get searchFieldLabel => 'Search posts...';

  @override
  TextStyle get searchFieldStyle => GoogleFonts.montserrat(fontSize: 14);
}

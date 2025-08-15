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
              // Convert Timestamp to milliseconds for JSON encoding
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

  // Add this to your dashboard screen's _loadZones method after getting prefs:
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
            // If corrupt, remove
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
      elevation: 2,
      centerTitle: true,
      toolbarHeight: 64,
      systemOverlayStyle: SystemUiOverlayStyle.dark,
      title: Column(
        children: [
          Text(
            'PowerPulse',
            style: GoogleFonts.lora(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: Colors.blue[700],
            ),
          ),
          Text(
            'Igniting Ideas in Power & Transmission',
            style: GoogleFonts.lora(
              fontSize: 12,
              color: Colors.grey,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: Icon(Icons.search, color: Colors.grey),
          onPressed: () => _showSearchDelegate(context),
          tooltip: 'Search posts',
        ),
        PopupMenuButton<String>(
          icon: Icon(Icons.person_outline, color: Colors.grey),
          onSelected: _handleMenuAction,
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'profile',
              child: Row(
                children: [
                  Icon(Icons.person, size: 20),
                  SizedBox(width: 12),
                  Text('Profile'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'settings',
              child: Row(
                children: [
                  Icon(Icons.settings, size: 20),
                  SizedBox(width: 12),
                  Text('Settings'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'about',
              child: Row(
                children: [
                  Icon(Icons.info, size: 20),
                  SizedBox(width: 12),
                  Text('About'),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildZoneSelector() {
    if (_isLoadingZones && _zones.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: CircularProgressIndicator(color: Colors.blue[600]),
        ),
      );
    }

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            ChoiceChip(
              label: Text(
                'All Zones (Public)',
                style: GoogleFonts.montserrat(
                  fontSize: 14,
                  fontWeight: selectedZoneId == null
                      ? FontWeight.w600
                      : FontWeight.w500,
                  color: selectedZoneId == null
                      ? Colors.blue[700]
                      : Colors.grey,
                ),
              ),
              avatar: Icon(
                Icons.public,
                size: 18,
                color: selectedZoneId == null ? Colors.blue : Colors.grey,
              ),
              selected: selectedZoneId == null,
              selectedColor: Colors.blue,
              onSelected: (selected) {
                if (selected) {
                  setState(() {
                    selectedZoneId = null;
                    selectedZoneName = null;
                  });
                }
              },
            ),
            const SizedBox(width: 8),
            ..._zones.map(
              (zone) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(
                    zone.name,
                    style: GoogleFonts.montserrat(
                      fontSize: 14,
                      fontWeight: selectedZoneId == zone.id
                          ? FontWeight.w600
                          : FontWeight.w500,
                      color: selectedZoneId == zone.id
                          ? Colors.blue[700]
                          : Colors.grey,
                    ),
                  ),
                  avatar: Icon(
                    Icons.location_on_outlined,
                    size: 18,
                    color: selectedZoneId == zone.id
                        ? Colors.blue
                        : Colors.grey,
                  ),
                  selected: selectedZoneId == zone.id,
                  selectedColor: Colors.blue,
                  onSelected: (selected) {
                    if (selected) {
                      setState(() {
                        selectedZoneId = zone.id;
                        selectedZoneName = zone.name;
                      });
                    }
                  },
                ),
              ),
            ),
            if (_error != null && _zones.isEmpty) ...[
              const SizedBox(width: 8),
              IconButton(
                icon: Icon(Icons.refresh, color: Colors.orange),
                onPressed: _loadZones,
                tooltip: 'Retry loading zones',
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: TabBar(
        controller: _tabController,
        labelColor: Colors.blue,
        unselectedLabelColor: Colors.grey,
        indicatorColor: Colors.blue,
        indicatorWeight: 3,
        labelStyle: GoogleFonts.lora(fontSize: 16, fontWeight: FontWeight.w600),
        unselectedLabelStyle: GoogleFonts.lora(
          fontSize: 16,
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
            subtitle: 'Spark the conversation with your ideas!',
            actionText: 'Create Post',
            onAction: _navigateToCreatePost,
          );
        }

        return RefreshIndicator(
          color: Colors.blue[600],
          onRefresh: () async {
            setState(() {});
          },
          child: ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            itemCount: posts.length,
            separatorBuilder: (context, index) => const SizedBox(height: 16),
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
            subtitle: 'Share something awesome to get the buzz going!',
            actionText: 'Create Post',
            onAction: _navigateToCreatePost,
          );
        }

        return RefreshIndicator(
          color: Colors.blue[600],
          onRefresh: () async {
            setState(() {});
          },
          child: ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            itemCount: posts.length,
            separatorBuilder: (context, index) => const SizedBox(height: 16),
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
          CircularProgressIndicator(color: Colors.blue[600]),
          const SizedBox(height: 16),
          Text(
            'Loading posts...',
            style: GoogleFonts.lora(fontSize: 16, color: Colors.grey),
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
            Icon(icon, size: 80, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              title,
              style: GoogleFonts.lora(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: GoogleFonts.lora(fontSize: 14, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            if (actionText != null && onAction != null) ...[
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: onAction,
                icon: const Icon(Icons.add),
                label: Text(actionText),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
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
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              error.length > 100 ? '${error.substring(0, 100)}...' : error,
              style: GoogleFonts.lora(fontSize: 14, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
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

  Widget _buildFloatingActionButton() {
    return FloatingActionButton.extended(
      onPressed: _navigateToCreatePost,
      backgroundColor: Colors.blue,
      icon: const Icon(Icons.edit, color: Colors.white),
      label: Text(
        'Write',
        style: GoogleFonts.lora(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
      heroTag: "createPost",
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
        title: Text(feature, style: GoogleFonts.lora(fontSize: 18)),
        content: Text(
          '$feature functionality coming soon!',
          style: GoogleFonts.lora(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('OK', style: GoogleFonts.lora()),
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
      applicationIcon: Icon(Icons.bolt, color: Colors.blue[600], size: 32),
      children: [
        const SizedBox(height: 16),
        Text(
          'Igniting Ideas in Power & Transmission',
          style: GoogleFonts.lora(),
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
          style: GoogleFonts.lora(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        content: Text(
          'Please sign in to create a post.',
          style: GoogleFonts.lora(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: GoogleFonts.lora()),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await AuthService.signInWithGoogle();
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to sign in: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue[600],
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              'Sign In',
              style: GoogleFonts.lora(color: Colors.white),
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
        elevation: 2,
        titleTextStyle: GoogleFonts.lora(fontSize: 18, color: Colors.grey[800]),
        iconTheme: IconThemeData(color: Colors.grey),
      ),
      inputDecorationTheme: InputDecorationTheme(
        hintStyle: GoogleFonts.lora(fontSize: 16, color: Colors.grey),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        filled: true,
        fillColor: Colors.grey,
      ),
    );
  }

  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      if (query.isNotEmpty)
        IconButton(
          icon: const Icon(Icons.clear),
          onPressed: () {
            query = '';
            showSuggestions(context);
          },
          tooltip: 'Clear search',
        ),
      PopupMenuButton<String>(
        icon: Icon(Icons.filter_list, color: Colors.grey),
        onSelected: (filter) {
          showResults(context);
        },
        itemBuilder: (context) => [
          const PopupMenuItem(value: 'author', child: Text('Filter by Author')),
          const PopupMenuItem(value: 'flair', child: Text('Filter by Flair')),
          const PopupMenuItem(value: 'zone', child: Text('Filter by Zone')),
        ],
      ),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () => close(context, null),
      tooltip: 'Back',
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    if (query.trim().isEmpty) {
      return _buildEmptySearchState('Enter a search term to find posts');
    }

    if (query.trim().length < 2) {
      return _buildEmptySearchState('Enter at least 2 characters to search');
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
                CircularProgressIndicator(color: Colors.blue[600]),
                const SizedBox(height: 16),
                Text(
                  'Searching posts...',
                  style: GoogleFonts.lora(fontSize: 16),
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
          separatorBuilder: (context, index) => const SizedBox(height: 16),
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
          style: GoogleFonts.lora(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 16),
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
              style: GoogleFonts.lora(fontWeight: FontWeight.w500),
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
            Icon(Icons.search_off, size: 80, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              message,
              style: GoogleFonts.lora(fontSize: 16, color: Colors.grey),
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
            Icon(Icons.error_outline, size: 80, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              title,
              style: GoogleFonts.lora(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              error.length > 100 ? '${error.substring(0, 100)}...' : error,
              style: GoogleFonts.lora(fontSize: 14, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
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

  @override
  String get searchFieldLabel => 'Search posts by title, content, or author...';

  @override
  TextStyle get searchFieldStyle => GoogleFonts.lora(fontSize: 16);
}

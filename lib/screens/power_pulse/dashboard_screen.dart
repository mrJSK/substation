// lib/screens/dashboard_screen.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

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
    with TickerProviderStateMixin {
  late TabController _tabController;
  String? selectedZoneId;
  String? selectedZoneName;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        toolbarHeight: 80,
        title: Row(
          children: [
            // PowerPulse Logo
            // Container(
            //   padding: const EdgeInsets.all(8),
            //   decoration: BoxDecoration(
            //     color: Colors.blue[600],
            //     borderRadius: BorderRadius.circular(8),
            //   ),
            //   child: Icon(Icons.bolt, color: Colors.white, size: 20),
            // ),
            // const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'PowerPulse',
                  style: GoogleFonts.montserrat(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue[700],
                  ),
                ),
                Text(
                  'Igniting Ideas in Power & Transmission',
                  style: GoogleFonts.montserrat(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.search, color: Colors.grey[700]),
            onPressed: () {
              _showSearchDelegate(context);
            },
          ),
          IconButton(
            icon: Icon(Icons.person_outline, color: Colors.grey[700]),
            onPressed: () {
              // Navigate to profile or show menu
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // Zone Selector
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: _showZonePicker,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey[300]!),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.location_on_outlined,
                            color: Colors.grey[600],
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            selectedZoneName ?? 'All Zones (Public)',
                            style: GoogleFonts.montserrat(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Colors.grey[700],
                            ),
                          ),
                          const Spacer(),
                          Icon(
                            Icons.keyboard_arrow_down,
                            color: Colors.grey[600],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Tab Bar
          Container(
            color: Colors.white,
            child: TabBar(
              controller: _tabController,
              labelColor: Colors.blue[600],
              unselectedLabelColor: Colors.grey,
              indicatorColor: Colors.blue,
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
          ),

          // Content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [_buildLatestFeed(), _buildTopFeed()],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const PostCreateScreen()),
          );
        },
        backgroundColor: Colors.blue[600],
        icon: const Icon(Icons.edit, color: Colors.white),
        label: Text(
          'Write',
          style: GoogleFonts.montserrat(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
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
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Error loading posts',
              style: GoogleFonts.montserrat(color: Colors.grey[600]),
            ),
          );
        }

        final posts = snapshot.data ?? [];

        if (posts.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.article_outlined, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  'No posts yet',
                  style: GoogleFonts.montserrat(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Be the first to share your insights!',
                  style: GoogleFonts.montserrat(
                    fontSize: 14,
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: posts.length,
          separatorBuilder: (context, index) => const SizedBox(height: 16),
          itemBuilder: (context, index) {
            return PostCard(
              post: posts[index],
              onTap: () => _navigateToPost(posts[index]),
            );
          },
        );
      },
    );
  }

  Widget _buildTopFeed() {
    return StreamBuilder<List<Post>>(
      stream: PostService.streamTopPosts(zoneId: selectedZoneId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Error loading posts',
              style: GoogleFonts.montserrat(color: Colors.grey[600]),
            ),
          );
        }

        final posts = snapshot.data ?? [];

        if (posts.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.trending_up_outlined,
                  size: 64,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 16),
                Text(
                  'No trending posts',
                  style: GoogleFonts.montserrat(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.separated(
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
        );
      },
    );
  }

  void _navigateToPost(Post post) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PostDetailScreen(postId: post.id),
      ),
    );
  }

  void _showZonePicker() async {
    final zones = await HierarchyService.getZones();

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Select Zone',
              style: GoogleFonts.montserrat(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: Icon(Icons.public, color: Colors.blue[600]),
              title: Text(
                'All Zones (Public)',
                style: GoogleFonts.montserrat(fontWeight: FontWeight.w500),
              ),
              selected: selectedZoneId == null,
              onTap: () {
                setState(() {
                  selectedZoneId = null;
                  selectedZoneName = null;
                });
                Navigator.pop(context);
              },
            ),
            const Divider(),
            ...zones.map(
              (zone) => ListTile(
                leading: Icon(Icons.location_on, color: Colors.grey[600]),
                title: Text(
                  zone.name,
                  style: GoogleFonts.montserrat(fontWeight: FontWeight.w500),
                ),
                selected: selectedZoneId == zone.id,
                onTap: () {
                  setState(() {
                    selectedZoneId = zone.id;
                    selectedZoneName = zone.name;
                  });
                  Navigator.pop(context);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSearchDelegate(BuildContext context) {
    showSearch(context: context, delegate: PostSearchDelegate());
  }
}

// Search Delegate
class PostSearchDelegate extends SearchDelegate<Post?> {
  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      IconButton(icon: const Icon(Icons.clear), onPressed: () => query = ''),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () => close(context, null),
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    if (query.trim().isEmpty) {
      return const Center(child: Text('Enter search term'));
    }

    return FutureBuilder<List<Post>>(
      future: PostService.searchPosts(query),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final posts = snapshot.data ?? [];

        if (posts.isEmpty) {
          return Center(
            child: Text(
              'No posts found for "$query"',
              style: GoogleFonts.montserrat(color: Colors.grey[600]),
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: posts.length,
          separatorBuilder: (context, index) => const SizedBox(height: 16),
          itemBuilder: (context, index) {
            return PostCard(
              post: posts[index],
              onTap: () {
                close(context, posts[index]);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        PostDetailScreen(postId: posts[index].id),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return const Center(child: Text('Search for posts by title...'));
  }
}

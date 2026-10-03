import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/auth/session_notifier.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';

class LaunchpadScreen extends ConsumerWidget {
  const LaunchpadScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionNotifierProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('GridERP'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sign out',
            onPressed: () async {
              await ref.read(sessionNotifierProvider.notifier).signOut();
              if (context.mounted) context.go(AppRoutes.login);
            },
          ),
        ],
      ),
      body: session.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (profile) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // User + substation header
            Container(
              width: double.infinity,
              color: AppColors.primary,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    profile?.fullName ?? 'User',
                    style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                  Text(
                    '${profile?.designation ?? ''} — ${profile?.orgUnitName ?? ''}',
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),

            // Micro-app grid
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SectionLabel('Operations'),
                    _AppGrid(tiles: [
                      _AppTile(Icons.book_outlined,      'Shift Logsheet',   AppRoutes.logsheet,  _has(profile, 'LOGSHEET_WRITE')),
                      _AppTile(Icons.flash_on_outlined,  'Tripping Register', AppRoutes.tripping,  _has(profile, 'TRIPPING_WRITE')),
                      _AppTile(Icons.pause_circle_outline,'Stoppages',        AppRoutes.stoppage,  _has(profile, 'STOPPAGE_WRITE')),
                    ]),
                    _SectionLabel('Permit to Work'),
                    _AppGrid(tiles: [
                      _AppTile(Icons.assignment_outlined, 'PTW',             AppRoutes.ptwList,   _has(profile, 'PTW_REQUEST')),
                    ]),
                    _SectionLabel('Maintenance'),
                    _AppGrid(tiles: [
                      _AppTile(Icons.build_outlined,     'Work Orders',      AppRoutes.workOrders, _has(profile, 'WO_CREATE')),
                      _AppTile(Icons.report_outlined,    'Defects',          AppRoutes.defects,   _has(profile, 'DEFECT_CREATE')),
                      _AppTile(Icons.devices_outlined,   'Assets',           AppRoutes.assetList, true),
                    ]),
                    _SectionLabel('Energy'),
                    _AppGrid(tiles: [
                      _AppTile(Icons.bolt_outlined,      'Energy Account',   AppRoutes.energyAccount, _has(profile, 'ENERGY_WRITE')),
                    ]),
                    if (_has(profile, 'USER_ADMIN') || _has(profile, 'ROLE_ADMIN')) ...[
                      _SectionLabel('Administration'),
                      _AppGrid(tiles: [
                        _AppTile(Icons.people_outline,   'Users',            AppRoutes.users,     _has(profile, 'USER_ADMIN')),
                        _AppTile(Icons.shield_outlined,  'Roles & Permissions', AppRoutes.roles,  _has(profile, 'ROLE_ADMIN')),
                      ]),
                    ],
                    _SectionLabel('Reports'),
                    _AppGrid(tiles: [
                      _AppTile(Icons.dashboard_outlined, 'Dashboard',        AppRoutes.dashboard, true),
                    ]),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _has(profile, String code) =>
      profile?.permissions.contains(code) ?? false;
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 16, bottom: 8),
    child: Text(text,
      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
          color: Color(0xFF6B7280), letterSpacing: 0.8)),
  );
}

class _AppGrid extends StatelessWidget {
  final List<_AppTile> tiles;
  const _AppGrid({required this.tiles});

  @override
  Widget build(BuildContext context) {
    final visible = tiles.where((t) => t.allowed).toList();
    if (visible.isEmpty) return const SizedBox.shrink();

    return GridView.count(
      crossAxisCount: MediaQuery.sizeOf(context).width > 600 ? 4 : 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      children: visible.map((t) => _TileWidget(t)).toList(),
    );
  }
}

class _AppTile {
  final IconData icon;
  final String label;
  final String route;
  final bool allowed;
  const _AppTile(this.icon, this.label, this.route, this.allowed);
}

class _TileWidget extends StatelessWidget {
  final _AppTile tile;
  const _TileWidget(this.tile);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => context.go(tile.route),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFE5E7EB)),
          borderRadius: BorderRadius.circular(8),
          color: Colors.white,
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(tile.icon, color: AppColors.primary, size: 28),
            const SizedBox(height: 8),
            Text(
              tile.label,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Color(0xFF374151)),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

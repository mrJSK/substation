import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:provider/provider.dart';

import '../../models/app_state_data.dart';
import '../../models/user_model.dart';

class SidebarNavItem {
  final String label;
  final IconData icon;
  final Color color;

  const SidebarNavItem(this.label, this.icon, this.color);
}

class WindowsSidebar extends StatelessWidget {
  final AppUser currentUser;
  final List<SidebarNavItem> navItems;
  final int selectedIndex;
  final ValueChanged<int> onItemSelected;
  final String title;

  const WindowsSidebar({
    super.key,
    required this.currentUser,
    required this.navItems,
    required this.selectedIndex,
    required this.onItemSelected,
    required this.title,
  });

  static const double _sidebarWidth = 240.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final appState = Provider.of<AppStateData>(context, listen: false);

    final sidebarBg = isDark ? const Color(0xFF2C2C2E) : Colors.white;
    final selectedBg = isDark
        ? theme.colorScheme.primary.withValues(alpha: 0.18)
        : theme.colorScheme.primary.withValues(alpha: 0.10);
    final unselectedLabel =
        isDark ? Colors.white60 : Colors.black54;

    return SizedBox(
      width: _sidebarWidth,
      child: Material(
        color: sidebarBg,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // App title / brand area
            _buildHeader(theme, isDark),

            // User info card
            _buildUserCard(theme, isDark),

            const SizedBox(height: 8),

            // Nav items
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: navItems.length,
                itemBuilder: (context, i) {
                  final item = navItems[i];
                  final isSelected = i == selectedIndex;
                  return _buildNavItem(
                    context: context,
                    item: item,
                    isSelected: isSelected,
                    selectedBg: selectedBg,
                    unselectedLabel: unselectedLabel,
                    theme: theme,
                    onTap: () => onItemSelected(i),
                  );
                },
              ),
            ),

            const Divider(height: 1),

            // Theme toggle
            _buildThemeToggle(context, appState, theme, isDark),

            // Logout
            _buildLogoutButton(context, theme, isDark),

            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme, bool isDark) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.electrical_services_rounded,
              color: Colors.white,
              size: 18,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : theme.colorScheme.onSurface,
                letterSpacing: -0.2,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserCard(ThemeData theme, bool isDark) {
    final cardBg = isDark
        ? Colors.white.withValues(alpha: 0.06)
        : Colors.black.withValues(alpha: 0.04);
    final initials = _getInitials(currentUser.name.isNotEmpty ? currentUser.name : currentUser.email);
    final roleLabel = _getRoleLabel(currentUser.role);

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor:
                theme.colorScheme.primary.withValues(alpha: 0.15),
            child: Text(
              initials,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.primary,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  currentUser.name.isNotEmpty ? currentUser.name : currentUser.email,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : theme.colorScheme.onSurface,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  roleLabel,
                  style: TextStyle(
                    fontSize: 11,
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem({
    required BuildContext context,
    required SidebarNavItem item,
    required bool isSelected,
    required Color selectedBg,
    required Color unselectedLabel,
    required ThemeData theme,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected ? selectedBg : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  item.icon,
                  size: 20,
                  color: isSelected ? item.color : unselectedLabel,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    item.label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.w400,
                      color: isSelected
                          ? (theme.brightness == Brightness.dark
                              ? Colors.white
                              : theme.colorScheme.onSurface)
                          : unselectedLabel,
                    ),
                  ),
                ),
                if (isSelected)
                  Container(
                    width: 4,
                    height: 4,
                    decoration: BoxDecoration(
                      color: item.color,
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildThemeToggle(
    BuildContext context,
    AppStateData appState,
    ThemeData theme,
    bool isDark,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () {
            appState.toggleTheme();
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Icon(
                  isDark
                      ? Icons.light_mode_rounded
                      : Icons.dark_mode_rounded,
                  size: 20,
                  color: isDark ? Colors.white60 : Colors.black54,
                ),
                const SizedBox(width: 12),
                Text(
                  isDark ? 'Light Mode' : 'Dark Mode',
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.white60 : Colors.black54,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogoutButton(
      BuildContext context, ThemeData theme, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () async {
            await FirebaseAuth.instance.signOut();
            await GoogleSignIn().signOut();
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Icon(
                  Icons.logout_rounded,
                  size: 20,
                  color: Colors.red.shade400,
                ),
                const SizedBox(width: 12),
                Text(
                  'Sign Out',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.red.shade400,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _getInitials(String? name) {
    if (name == null || name.isEmpty) return '?';
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name[0].toUpperCase();
  }

  String _getRoleLabel(UserRole role) {
    switch (role) {
      case UserRole.admin:
        return 'Administrator';
      case UserRole.superAdmin:
        return 'Super Admin';
      case UserRole.subdivisionManager:
        return 'Subdivision Manager';
      case UserRole.substationUser:
        return 'Substation User';
      case UserRole.stateManager:
        return 'State Manager';
      case UserRole.zoneManager:
        return 'Zone Manager';
      case UserRole.circleManager:
        return 'Circle Manager';
      case UserRole.divisionManager:
        return 'Division Manager';
      case UserRole.companyManager:
        return 'Company Manager';
      default:
        return 'User';
    }
  }
}

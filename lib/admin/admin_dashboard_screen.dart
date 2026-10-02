// GoTRVL PH admin dashboard shell.
//
// SECURITY MODEL: admin role is a Firebase custom claim only. Firestore
// rules enforce it server-side. The app never hardcodes credentials and
// never bypasses auth. This screen is reachable inside the PHONE app;
// on a computer use `flutter build web`.

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../theme/boho_theme.dart';
import 'admin_auth_service.dart';
import 'dashboard_home.dart';
import 'admin_users_screen.dart';
import 'admin_moderation_screen.dart';
import 'admin_content_screen.dart';
import 'admin_marketplace_screen.dart';
import 'admin_live_screen.dart';
import 'admin_places_screen.dart';
import 'admin_announcements_screen.dart';
import 'admin_settings_screen.dart';

/// Admin section identifiers.
enum AdminSection {
  overview,
  users,
  places,
  moderation,
  content,
  marketplace,
  live,
  announcements,
  settings,
}

/// Root admin screen with responsive navigation between admin sections.
/// Narrow screens (< 700) get a single-column list nav; medium screens
/// (700-1100) and wide screens (> 1100) get a NavigationRail with a
/// 2- or 3-column stat grid on the overview tab.
class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  AdminSection _section = AdminSection.overview;

  static const _titles = <AdminSection, String>{
    AdminSection.overview: 'Overview',
    AdminSection.users: 'Users',
    AdminSection.places: 'Places',
    AdminSection.moderation: 'Moderation',
    AdminSection.content: 'Content',
    AdminSection.marketplace: 'Marketplace',
    AdminSection.live: 'Live',
    AdminSection.announcements: 'Announcements',
    AdminSection.settings: 'Settings',
  };

  static const _icons = <AdminSection, IconData>{
    AdminSection.overview: Icons.dashboard_rounded,
    AdminSection.users: Icons.people_rounded,
    AdminSection.places: Icons.pin_drop_rounded,
    AdminSection.moderation: Icons.flag_rounded,
    AdminSection.content: Icons.photo_library_rounded,
    AdminSection.marketplace: Icons.storefront_rounded,
    AdminSection.live: Icons.live_tv_rounded,
    AdminSection.announcements: Icons.campaign_rounded,
    AdminSection.settings: Icons.settings_rounded,
  };

  /// Logout: signs out via the admin auth service, then returns to login.
  Future<void> _logout() async {
    await AdminAuthService.signOut();
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
  }

  /// Content for the selected section. Screens with no parameters yet are
  /// owned by teammates; only the overview grid column count is set here.
  Widget _contentFor(int statColumns) {
    switch (_section) {
      case AdminSection.overview:
        return DashboardHome(statColumns: statColumns);
      case AdminSection.users:
        return const AdminUsersScreen();
      case AdminSection.moderation:
        return const AdminModerationScreen();
      case AdminSection.places:
        return const AdminPlacesScreen();
      case AdminSection.content:
        return const AdminContentScreen();
      case AdminSection.marketplace:
        return const AdminMarketplaceScreen();
      case AdminSection.live:
        return const AdminLiveScreen();
      case AdminSection.announcements:
        return const AdminAnnouncementsScreen();
      case AdminSection.settings:
        return const AdminSettingsScreen();
    }
  }

  @override
  Widget build(BuildContext context) {
    final email = FirebaseAuth.instance.currentUser?.email ?? 'Admin';
    return Scaffold(
      backgroundColor: BohoColors.cream,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth < 700) {
              return _narrowLayout(email);
            }
            final statColumns = constraints.maxWidth > 1100 ? 3 : 2;
            return _wideLayout(email, statColumns);
          },
        ),
      ),
    );
  }

  /// Header row: title, admin email, logout.
  Widget _header(String email) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: BohoColors.sandDark)),
      ),
      child: Row(
        children: [
          const HibiscusStamp(size: 36),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Admin Dashboard', style: BohoFonts.heading(20)),
                Text(email,
                    style: BohoFonts.body(12, color: BohoColors.sandMuted),
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          TextButton.icon(
            onPressed: _logout,
            icon: const Icon(Icons.logout_rounded,
                color: BohoColors.terracotta, size: 18),
            label: Text('Logout',
                style: BohoFonts.body(13,
                    color: BohoColors.terracotta, weight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  /// Narrow layout: header, single-column list nav, then content.
  Widget _narrowLayout(String email) {
    return Column(
      children: [
        _header(email),
        SizedBox(
          height: 200,
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            children: AdminSection.values.map((s) {
              final selected = s == _section;
              return Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: ListTile(
                  dense: true,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: BorderSide(
                      color: selected ? BohoColors.forest : BohoColors.sandDark,
                    ),
                  ),
                  tileColor: selected
                      ? BohoColors.forest.withValues(alpha: 0.12)
                      : Colors.white,
                  leading: Icon(_icons[s],
                      color:
                          selected ? BohoColors.forest : BohoColors.sandMuted),
                  title: Text(_titles[s]!,
                      style: BohoFonts.body(14,
                          weight:
                              selected ? FontWeight.w700 : FontWeight.w500)),
                  onTap: () => setState(() => _section = s),
                ),
              );
            }).toList(),
          ),
        ),
        const Divider(color: BohoColors.sandDark, height: 1),
        Expanded(child: _contentFor(1)),
      ],
    );
  }

  /// Medium/wide layout: header, NavigationRail + content.
  Widget _wideLayout(String email, int statColumns) {
    return Column(
      children: [
        _header(email),
        Expanded(
          child: Row(
            children: [
              NavigationRail(
                backgroundColor: BohoColors.creamSheet,
                selectedIndex: _section.index,
                onDestinationSelected: (i) =>
                    setState(() => _section = AdminSection.values[i]),
                labelType: NavigationRailLabelType.all,
                selectedIconTheme:
                    const IconThemeData(color: BohoColors.forest),
                unselectedIconTheme:
                    const IconThemeData(color: BohoColors.sandMuted),
                selectedLabelTextStyle:
                    BohoFonts.capsLabel(10, color: BohoColors.forest),
                unselectedLabelTextStyle:
                    BohoFonts.capsLabel(10, color: BohoColors.sandMuted),
                destinations: AdminSection.values
                    .map((s) => NavigationRailDestination(
                          icon: Icon(_icons[s]),
                          label: Text(_titles[s]!),
                        ))
                    .toList(),
              ),
              const VerticalDivider(width: 1, color: BohoColors.sandDark),
              Expanded(child: _contentFor(statColumns)),
            ],
          ),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../admin/admin_login_screen.dart';
import '../admin/triple_tap_detector.dart';
import '../theme/boho_theme.dart';
import '../services/auth_service.dart';
import 'map_screen.dart';
import 'feed_screen.dart';
import 'create_post_screen.dart';
import 'matching_screen.dart';
import 'profile_screen.dart';
import 'onboarding_tutorial.dart';

/// Five-tab shell per the approved structure (2026-09-30):
/// Map / Feed / Create Post (raised center button) / Matching / Profile.
///
/// The center + is NOT a tab: tapping it pushes the full-screen
/// [CreatePostScreen] composer modally and the current tab stays put.
///
/// Tab-screen contracts:
/// - MapScreen, FeedScreen, MatchingScreen, ProfileScreen: default const
///   constructors.
/// - CreatePostScreen: `const CreatePostScreen({super.key, int initialTab = 0})`.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});
  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  /// Tab index: 0 = Map, 1 = Feed, 2 = Create (modal, never a stack page),
  /// 3 = Matching, 4 = Profile.
  int _index = 0;

  /// Hidden admin entrance: 3 taps on the Profile tab icon within 1.5s
  /// reveals the Admin Login screen. This is obscurity only, not security:
  /// entry still requires a valid admin email/password plus the `admin`
  /// custom claim verified against Firebase. Single/double taps behave
  /// exactly as normal tab switches.
  final _adminTapDetector = TripleTapDetector();

  bool _tutorialChecked = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeTutorial());
  }

  /// First-run onboarding: users who signed up but never finished the
  /// tutorial get it once, right after landing in the shell.
  void _maybeTutorial() {
    if (_tutorialChecked || !mounted) return;
    _tutorialChecked = true;
    final user = context.read<AuthService>().user;
    if (user != null && !user.onboardingDone) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const OnboardingTutorial()),
      );
    }
  }

  void _go(int i) => setState(() => _index = i);

  void _onTabTap(int i) {
    if (i == 2) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const CreatePostScreen()),
      );
      return;
    }
    if (i == 4 &&
        _adminTapDetector.registerTap(DateTime.now().millisecondsSinceEpoch)) {
      _go(i);
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const AdminLoginScreen()),
      );
      return;
    }
    _go(i);
  }

  /// IndexedStack holds 4 pages (Create is modal-only): map stack slots
  /// 3 and 4 down to 2 and 3.
  int get _stackIndex => _index <= 1 ? _index : _index - 1;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _stackIndex,
        children: const [
          MapScreen(),
          FeedScreen(),
          MatchingScreen(),
          ProfileScreen(),
        ],
      ),
      bottomNavigationBar: _GoTrvlBottomBar(index: _index, onTap: _onTabTap),
    );
  }
}

/// Cream bottom bar: espresso icons, forest when selected, and a raised
/// terracotta circular Create Post button in the center.
class _GoTrvlBottomBar extends StatelessWidget {
  final int index;
  final ValueChanged<int> onTap;

  const _GoTrvlBottomBar({required this.index, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: SizedBox(
        height: 96,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                height: 72,
                decoration: BoxDecoration(
                  color: BohoColors.cream,
                  border: const Border(
                    top: BorderSide(color: BohoColors.tan, width: 1),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: BohoColors.espresso.withValues(alpha: 0.08),
                      blurRadius: 12,
                      offset: const Offset(0, -4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    _tab(0, 'Map', Icons.map_rounded, Icons.map_outlined),
                    _tab(1, 'Feed', Icons.image_rounded, Icons.image_outlined),
                    // Center slot: tap target for Create Post, label under
                    // the raised button.
                    Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => onTap(2),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            const SizedBox(height: 42),
                            _label('Create Post', 2),
                            const SizedBox(height: 8),
                          ],
                        ),
                      ),
                    ),
                    _tab(3, 'Matching', Icons.favorite_rounded,
                        Icons.favorite_outline_rounded),
                    _tab(4, 'Profile', Icons.person_rounded,
                        Icons.person_outline_rounded),
                  ],
                ),
              ),
            ),
            // Raised circular Create Post button, overlapping the bar.
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Center(
                child: Material(
                  shape: const CircleBorder(),
                  color: BohoColors.terracotta,
                  elevation: 6,
                  shadowColor: BohoColors.espresso.withValues(alpha: 0.3),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () => onTap(2),
                    child: const SizedBox(
                      width: 62,
                      height: 62,
                      child: Icon(
                        Icons.add_rounded,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tab(int i, String label, IconData filled, IconData outlined) {
    final selected = index == i;
    final color = selected
        ? BohoColors.forest
        : BohoColors.espresso.withValues(alpha: 0.55);
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onTap(i),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(selected ? filled : outlined, color: color, size: 26),
            const SizedBox(height: 3),
            _label(label, i),
          ],
        ),
      ),
    );
  }

  Widget _label(String label, int i) {
    final selected = index == i;
    return Text(
      label,
      style: BohoFonts.body(
        10.5,
        color: selected
            ? BohoColors.forest
            : BohoColors.espresso.withValues(alpha: 0.55),
        weight: selected ? FontWeight.w700 : FontWeight.w500,
      ),
    );
  }
}

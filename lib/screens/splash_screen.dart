import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/boho_theme.dart';
import '../widgets/logo.dart';
import '../services/auth_service.dart';

/// Tropical splash: full-bleed sunset scene, handwritten wordmark with a
/// gentle float, then the existing auth-based routing.
class SplashScreen extends StatefulWidget {
  final bool firebaseOk;
  const SplashScreen({super.key, required this.firebaseOk});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _introCtrl;
  late final AnimationController _floatCtrl;
  late final Animation<double> _fade;
  late final Animation<double> _scale;
  late final Animation<double> _float;

  @override
  void initState() {
    super.initState();
    _introCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1400));
    final curved =
        CurvedAnimation(parent: _introCtrl, curve: Curves.easeOutCubic);
    _fade = Tween<double>(begin: 0, end: 1).animate(curved);
    _scale = Tween<double>(begin: 0.92, end: 1).animate(curved);
    _introCtrl.forward();

    _floatCtrl =
        AnimationController(vsync: this, duration: const Duration(seconds: 3))
          ..repeat(reverse: true);
    _float = Tween<double>(begin: -8, end: 8)
        .animate(CurvedAnimation(parent: _floatCtrl, curve: Curves.easeInOut));

    _decideRoute();
  }

  /// Routes after the intro, but only once the auth state is known.
  /// The old fixed 2.6s delay raced the async auth-state restore: a slow
  /// first event bounced returning users to the login screen, where
  /// nothing redirected them home. Now we wait for [AuthService.ready]
  /// (with a hard cap so a stalled network never hangs the splash) and
  /// keep the splash up for at least the intro duration.
  Future<void> _decideRoute() async {
    final started = DateTime.now();
    final auth = context.read<AuthService>();
    final deadline = started.add(const Duration(seconds: 8));
    while (
        widget.firebaseOk && !auth.ready && DateTime.now().isBefore(deadline)) {
      await Future.delayed(const Duration(milliseconds: 120));
      if (!mounted) return;
    }
    final elapsed = DateTime.now().difference(started);
    const minSplash = Duration(milliseconds: 2600);
    if (elapsed < minSplash) {
      await Future.delayed(minSplash - elapsed);
      if (!mounted) return;
    }
    if (!widget.firebaseOk || !auth.signedIn) {
      Navigator.of(context).pushReplacementNamed('/login');
    } else {
      Navigator.of(context).pushReplacementNamed('/home');
    }
  }

  @override
  void dispose() {
    _introCtrl.dispose();
    _floatCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(child: TropicalScene()),
          const Positioned.fill(child: DotPatternOverlay()),
          FadeTransition(
            opacity: _fade,
            child: ScaleTransition(
              scale: _scale,
              child: AnimatedBuilder(
                animation: _float,
                builder: (_, child) => Transform.translate(
                  offset: Offset(0, _float.value),
                  child: child,
                ),
                child: const Center(
                  child: GoTrvlLogo(light: true, size: 72),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

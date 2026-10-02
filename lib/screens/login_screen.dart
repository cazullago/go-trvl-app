import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/boho_theme.dart';
import '../widgets/logo.dart';
import '../services/auth_service.dart';
import 'signup_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  /// Key under which the last successfully-signed-in email is stored so
  /// users only have to type it once.
  static const _savedEmailKey = 'saved_login_email';

  final _email = TextEditingController();
  final _pass = TextEditingController();
  bool _busy = false;
  String? _error;

  late final AnimationController _cardCtrl;
  late final Animation<Offset> _cardSlide;
  late final Animation<double> _cardFade;

  @override
  void initState() {
    super.initState();
    _cardCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800));
    final curved =
        CurvedAnimation(parent: _cardCtrl, curve: Curves.easeOutCubic);
    _cardSlide = Tween<Offset>(begin: const Offset(0, 0.18), end: Offset.zero)
        .animate(curved);
    _cardFade = Tween<double>(begin: 0, end: 1).animate(curved);
    _cardCtrl.forward();
    // Prefill the email typed on the previous successful sign-in/sign-up.
    SharedPreferences.getInstance().then((prefs) {
      final saved = prefs.getString(_savedEmailKey);
      if (saved != null && saved.isNotEmpty && mounted) {
        _email.text = saved;
      }
    });
    // If an auth-state restore just bounced a suspended account, say why.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = context.read<AuthService>();
      if (auth.suspendedNotice && mounted) {
        auth.clearSuspendedNotice();
        setState(() => _error = 'This account has been suspended.');
      }
    });
  }

  @override
  void dispose() {
    _cardCtrl.dispose();
    _email.dispose();
    _pass.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final err = await context
        .read<AuthService>()
        .signIn(email: _email.text, password: _pass.text);
    if (!mounted) return;
    setState(() => _busy = false);
    if (err != null) {
      setState(() => _error = err);
    } else {
      // Remember the email so the next sign-in prefills it.
      final email = _email.text.trim();
      if (email.isNotEmpty) {
        SharedPreferences.getInstance()
            .then((prefs) => prefs.setString(_savedEmailKey, email));
      }
      Navigator.of(context).pushReplacementNamed('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          const Positioned.fill(child: TropicalScene()),
          const Positioned.fill(child: DotPatternOverlay()),
          SafeArea(
            child: Column(
              children: [
                Expanded(
                  flex: 36,
                  child: const Center(
                    child: GoTrvlLogo(light: true, size: 56),
                  ),
                ),
                Expanded(
                  flex: 64,
                  child: SlideTransition(
                    position: _cardSlide,
                    child: FadeTransition(
                      opacity: _cardFade,
                      child: Container(
                        width: double.infinity,
                        decoration: BohoDecor.tropicalCard,
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(28, 12, 28, 28),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              BohoDecor.dragHandle(),
                              const SizedBox(height: 14),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Expanded(
                                    child: Text('Welcome Back',
                                        style: BohoFonts.display(42,
                                            color: BohoColors.coconut)),
                                  ),
                                  const HibiscusStamp(size: 44),
                                ],
                              ),
                              Text('Sign in to continue your journey',
                                  style: BohoFonts.body(15,
                                      color: BohoColors.sandMuted)),
                              const SizedBox(height: 20),
                              Text('EMAIL', style: BohoFonts.capsLabel(12)),
                              const SizedBox(height: 6),
                              TextField(
                                controller: _email,
                                keyboardType: TextInputType.emailAddress,
                                decoration: const InputDecoration(
                                    hintText: 'traveler@gotrvl.com',
                                    prefixIcon: Icon(Icons.mail_outline)),
                              ),
                              const SizedBox(height: 14),
                              Text('PASSWORD', style: BohoFonts.capsLabel(12)),
                              const SizedBox(height: 6),
                              TextField(
                                controller: _pass,
                                obscureText: true,
                                decoration: const InputDecoration(
                                    hintText: '••••••••',
                                    prefixIcon: Icon(Icons.lock_outline)),
                                onSubmitted: (_) => _submit(),
                              ),
                              if (_error != null) ...[
                                const SizedBox(height: 10),
                                Text(_error!,
                                    style: BohoFonts.body(14,
                                        color: BohoColors.coralDeep,
                                        weight: FontWeight.w700)),
                              ],
                              const SizedBox(height: 22),
                              ElevatedButton(
                                onPressed: _busy ? null : _submit,
                                child: _busy
                                    ? const SizedBox(
                                        width: 22,
                                        height: 22,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white))
                                    : const Text('Sign In'),
                              ),
                              const SizedBox(height: 18),
                              const OrDivider(),
                              const SizedBox(height: 18),
                              OutlinedButton(
                                style: BohoDecor.ghostButtonStyle,
                                onPressed: () => Navigator.of(context).push(
                                    MaterialPageRoute(
                                        builder: (_) => const SignupScreen())),
                                child: const Text('Create Account'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

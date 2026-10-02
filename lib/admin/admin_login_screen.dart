// Admin login screen. Revealed only by the triple-tap gesture, it never
// bypasses authentication: every attempt goes through AdminAuthService, which
// requires a fresh Firebase ID token carrying the admin custom claim. There is
// intentionally no signup link, no password reset, and no hint about valid
// credentials on this screen.
import 'package:flutter/material.dart';
import '../../theme/boho_theme.dart';
import 'admin_auth_service.dart';
import 'admin_dashboard_screen.dart';

class AdminLoginScreen extends StatefulWidget {
  const AdminLoginScreen({super.key});

  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (_busy) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    final result = await AdminAuthService.signInAsAdmin(
      email: _emailController.text.trim(),
      password: _passwordController.text,
    );
    if (!mounted) return;
    if (result.ok) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const AdminDashboardScreen()),
      );
    } else {
      setState(() {
        _busy = false;
        _error = result.error ?? 'Sign-in failed. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BohoColors.cream,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
              decoration: const BoxDecoration(color: BohoColors.espresso),
              child: Column(
                children: [
                  const Icon(Icons.lock_rounded,
                      color: BohoColors.tan, size: 40),
                  const SizedBox(height: 12),
                  Text(
                    'Admin Access',
                    style: BohoFonts.script(38, color: BohoColors.cream),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Restricted area. Sign in to continue.',
                    style: BohoFonts.body(14, color: BohoColors.sandDark),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('EMAIL',
                        style: BohoFonts.capsLabel(12,
                            color: BohoColors.espresso)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      autocorrect: false,
                      autofillHints: const [AutofillHints.email],
                      style: BohoFonts.body(15),
                      decoration: const InputDecoration(
                        hintText: 'Email address',
                        prefixIcon: Icon(Icons.email_outlined),
                      ),
                      onSubmitted: (_) => _signIn(),
                    ),
                    const SizedBox(height: 18),
                    Text('PASSWORD',
                        style: BohoFonts.capsLabel(12,
                            color: BohoColors.espresso)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _passwordController,
                      obscureText: true,
                      autofillHints: const [AutofillHints.password],
                      style: BohoFonts.body(15),
                      decoration: const InputDecoration(
                        hintText: 'Password',
                        prefixIcon: Icon(Icons.lock_outline_rounded),
                      ),
                      onSubmitted: (_) => _signIn(),
                    ),
                    const SizedBox(height: 16),
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Text(
                          _error!,
                          style: BohoFonts.body(14,
                              color: BohoColors.terracotta,
                              weight: FontWeight.w600),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    SizedBox(
                      height: 54,
                      child: ElevatedButton(
                        onPressed: _busy ? null : _signIn,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: BohoColors.forest,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          textStyle: BohoFonts.heading(16),
                        ),
                        child: _busy
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.6,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('Sign In'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/auth_service.dart';
import '../services/content_filter.dart';
import '../services/database_service.dart';
import '../services/permission_service.dart';
import '../theme/boho_theme.dart';
import '../widgets/logo.dart';
import 'onboarding_tutorial.dart';

/// Signup collects the full traveler profile: name, email, password,
/// optional photo, location, age (13+), gender (used by Travel Buddy
/// filters), and bio (runs through the community content filter).
///
/// On success the Firestore user doc is created with every AppUser field,
/// onboardingDone=false, and the first-run tutorial is pushed.
class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});
  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen>
    with SingleTickerProviderStateMixin {
  /// Same key as LoginScreen: the last successfully-registered email is
  /// saved so the sign-in screen prefills it next time.
  static const _savedEmailKey = 'saved_login_email';

  final _name = TextEditingController();
  final _email = TextEditingController();
  final _pass = TextEditingController();
  final _age = TextEditingController();
  final _location = TextEditingController();
  final _bio = TextEditingController();
  String? _gender; // 'Woman' | 'Man' | 'Non-binary' | 'Prefer not to say'
  XFile? _photo;
  bool _busy = false;
  String? _error;

  static const _genders = [
    'Woman',
    'Man',
    'Non-binary',
    'Prefer not to say',
  ];

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
  }

  @override
  void dispose() {
    _cardCtrl.dispose();
    _name.dispose();
    _email.dispose();
    _pass.dispose();
    _age.dispose();
    _location.dispose();
    _bio.dispose();
    super.dispose();
  }

  static String _genderValue(String? label) {
    switch (label) {
      case 'Woman':
        return 'woman';
      case 'Man':
        return 'man';
      case 'Non-binary':
        return 'nonbinary';
      default:
        return 'unspecified';
    }
  }

  Future<void> _pickPhoto() async {
    final granted = await PermissionService()
        .ensurePhotos(context, 'to add a profile photo');
    if (!granted || !mounted) return;
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1200,
      imageQuality: 85,
    );
    if (picked != null && mounted) {
      setState(() => _photo = picked);
    }
  }

  Future<void> _submit() async {
    final name = _name.text.trim();
    final email = _email.text.trim();
    final age = int.tryParse(_age.text.trim());
    final bio = _bio.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Please tell us your name.');
      return;
    }
    if (!email.contains('@')) {
      setState(() => _error = 'Please enter a valid email address.');
      return;
    }
    if (_pass.text.length < 6) {
      setState(() => _error = 'Password should be at least 6 characters.');
      return;
    }
    if (age == null) {
      setState(() => _error = 'Please enter your age.');
      return;
    }
    if (age < 13) {
      setState(
          () => _error = 'You must be at least 13 to join GoTRVL.');
      return;
    }
    if (_gender == null) {
      setState(() => _error = 'Please choose how we should list you.');
      return;
    }
    if (!ContentFilter.isAllowed(bio)) {
      setState(() => _error = ContentFilter.refusalMessage);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final auth = context.read<AuthService>();
    final err = await auth.signUp(
      name: name,
      email: email,
      password: _pass.text,
      age: age,
      gender: _genderValue(_gender),
      location: _location.text.trim(),
      bio: bio,
    );
    if (!mounted) return;
    if (err != null) {
      setState(() {
        _busy = false;
        _error = err;
      });
      return;
    }
    // Optional photo: upload after the account exists, then tag the doc.
    final uid = auth.user?.uid ?? '';
    if (_photo != null && uid.isNotEmpty) {
      try {
        final url = await DatabaseService().uploadImage(
          File(_photo!.path),
          'users/$uid/avatar_${DateTime.now().millisecondsSinceEpoch}.jpg',
        );
        await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .update({'photoUrl': url});
        await auth.refreshUser();
      } catch (_) {
        // Non-blocking: the account is created, the photo can be added
        // later from Settings.
      }
    }
    if (!mounted) return;
    setState(() => _busy = false);
    // Remember the email so the sign-in screen prefills it next time.
    SharedPreferences.getInstance()
        .then((prefs) => prefs.setString(_savedEmailKey, email));
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const OnboardingTutorial()),
      (_) => false,
    );
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
                  flex: 22,
                  child: const Center(
                    child: GoTrvlLogo(light: true, size: 46),
                  ),
                ),
                Expanded(
                  flex: 78,
                  child: SlideTransition(
                    position: _cardSlide,
                    child: FadeTransition(
                      opacity: _cardFade,
                      child: Container(
                        width: double.infinity,
                        decoration: BohoDecor.tropicalCard,
                        child: SingleChildScrollView(
                          padding:
                              const EdgeInsets.fromLTRB(28, 12, 28, 28),
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.stretch,
                            children: [
                              BohoDecor.dragHandle(),
                              const SizedBox(height: 14),
                              Row(
                                crossAxisAlignment:
                                    CrossAxisAlignment.center,
                                children: [
                                  Expanded(
                                    child: Text('Join the Journey',
                                        style: BohoFonts.display(38,
                                            color: BohoColors.coconut)),
                                  ),
                                  const HibiscusStamp(size: 44),
                                ],
                              ),
                              Text('Create your account to start exploring',
                                  style: BohoFonts.body(15,
                                      color: BohoColors.sandMuted)),
                              const SizedBox(height: 18),
                              Center(child: _photoPicker()),
                              const SizedBox(height: 18),
                              Text('NAME', style: BohoFonts.capsLabel(12)),
                              const SizedBox(height: 6),
                              TextField(
                                controller: _name,
                                textCapitalization:
                                    TextCapitalization.words,
                                decoration: const InputDecoration(
                                    hintText: 'Juan Dela Cruz',
                                    prefixIcon:
                                        Icon(Icons.person_outline)),
                              ),
                              const SizedBox(height: 14),
                              Text('EMAIL', style: BohoFonts.capsLabel(12)),
                              const SizedBox(height: 6),
                              TextField(
                                controller: _email,
                                keyboardType:
                                    TextInputType.emailAddress,
                                decoration: const InputDecoration(
                                    hintText: 'traveler@gotrvl.com',
                                    prefixIcon: Icon(Icons.mail_outline)),
                              ),
                              const SizedBox(height: 14),
                              Text('PASSWORD',
                                  style: BohoFonts.capsLabel(12)),
                              const SizedBox(height: 6),
                              TextField(
                                controller: _pass,
                                obscureText: true,
                                decoration: const InputDecoration(
                                    hintText: 'Min. 6 characters',
                                    prefixIcon: Icon(Icons.lock_outline)),
                              ),
                              const SizedBox(height: 14),
                              Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        Text('AGE',
                                            style:
                                                BohoFonts.capsLabel(12)),
                                        const SizedBox(height: 6),
                                        TextField(
                                          controller: _age,
                                          keyboardType:
                                              TextInputType.number,
                                          decoration:
                                              const InputDecoration(
                                                  hintText: '23'),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    flex: 2,
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        Text('GENDER',
                                            style:
                                                BohoFonts.capsLabel(12)),
                                        const SizedBox(height: 6),
                                        DropdownButtonFormField<String>(
                                          initialValue: _gender,
                                          hint: const Text('Select'),
                                          items: [
                                            for (final g in _genders)
                                              DropdownMenuItem(
                                                  value: g,
                                                  child: Text(g)),
                                          ],
                                          onChanged: (v) => setState(
                                              () => _gender = v),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              Text('LOCATION',
                                  style: BohoFonts.capsLabel(12)),
                              const SizedBox(height: 6),
                              TextField(
                                controller: _location,
                                textCapitalization:
                                    TextCapitalization.words,
                                decoration: const InputDecoration(
                                    hintText: 'Manila, Philippines',
                                    prefixIcon:
                                        Icon(Icons.place_outlined)),
                              ),
                              const SizedBox(height: 14),
                              Text('BIO (OPTIONAL)',
                                  style: BohoFonts.capsLabel(12)),
                              const SizedBox(height: 6),
                              TextField(
                                controller: _bio,
                                maxLines: 3,
                                textCapitalization:
                                    TextCapitalization.sentences,
                                decoration: const InputDecoration(
                                    hintText:
                                        'Island hopper, coffee lover...'),
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
                                        child:
                                            CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: Colors.white))
                                    : const Text('Create Account'),
                              ),
                              const SizedBox(height: 14),
                              Text(
                                  'You must be at least 13 to join. Travel Buddy matching is 18+.',
                                  style: BohoFonts.body(12,
                                      color: BohoColors.sandMuted),
                                  textAlign: TextAlign.center),
                              const SizedBox(height: 18),
                              const OrDivider(),
                              const SizedBox(height: 18),
                              OutlinedButton(
                                style: BohoDecor.ghostButtonStyle,
                                onPressed: () =>
                                    Navigator.of(context).pop(),
                                child: const Text('Back to Sign In'),
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

  Widget _photoPicker() {
    return GestureDetector(
      onTap: _pickPhoto,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: BohoColors.sand,
              border:
                  Border.all(color: BohoColors.sandDark, width: 2),
              image: _photo == null
                  ? null
                  : DecorationImage(
                      image: FileImage(File(_photo!.path)),
                      fit: BoxFit.cover,
                    ),
            ),
            child: _photo == null
                ? const Icon(Icons.person_rounded,
                    size: 44, color: BohoColors.sandMuted)
                : null,
          ),
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.all(7),
              decoration: const BoxDecoration(
                color: BohoColors.forest,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.add_a_photo_rounded,
                  color: Colors.white, size: 15),
            ),
          ),
        ],
      ),
    );
  }
}

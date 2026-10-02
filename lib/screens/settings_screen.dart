import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../services/auth_service.dart';
import '../services/content_filter.dart';
import '../services/database_service.dart';
import '../services/permission_service.dart';
import '../theme/boho_theme.dart';
import 'blocked_users_screen.dart';
import 'legal_screen.dart';

/// Settings: profile editing, photo changes, blocked users, notification
/// preferences, privacy toggles, legal, help, sign out, and delete account.
///
/// The delete-account flow is the exact flow from the old profile screen:
/// double confirm, password re-auth, blocking progress, then
/// AuthService.deleteAccount.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // Toggle state lives here (these prefs are plain user-doc fields, not
  // part of the AppUser contract), loaded once from Firestore.
  bool _notifyLikes = true;
  bool _notifyMatches = true;
  bool _notifyMessages = true;
  bool _showLocation = true;
  bool _showAge = true;
  bool _prefsLoaded = false;

  static const _supportEmail = '[YOUR SUPPORT EMAIL]';

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final uid = context.read<AuthService>().user?.uid ?? '';
    if (uid.isEmpty) return;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      final data = doc.data() ?? {};
      if (!mounted) return;
      setState(() {
        _notifyLikes = data['notifyLikes'] != false;
        _notifyMatches = data['notifyMatches'] != false;
        _notifyMessages = data['notifyMessages'] != false;
        _showLocation = data['showLocation'] != false;
        _showAge = data['showAge'] != false;
        _prefsLoaded = true;
      });
    } catch (_) {}
  }

  Future<void> _setPref(String key, bool value, void Function(bool) apply) async {
    final uid = context.read<AuthService>().user?.uid ?? '';
    if (uid.isEmpty) return;
    setState(() => apply(value));
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .update({key: value});
      await context.read<AuthService>().refreshUser();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not save. Please try again.',
              style: BohoFonts.body(14, color: Colors.white)),
          backgroundColor: BohoColors.coralDeep,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthService>(
      builder: (context, auth, _) {
        final user = auth.user;
        if (user == null) {
          return Scaffold(
            backgroundColor: BohoColors.cream,
            appBar: AppBar(
              backgroundColor: BohoColors.cream,
              title: Text('Settings',
                  style: BohoFonts.heading(22, color: BohoColors.espresso)),
            ),
            body: Center(
              child: Text('Sign in to change your settings.',
                  style: BohoFonts.body(16, color: BohoColors.espresso)),
            ),
          );
        }
        return Scaffold(
          backgroundColor: BohoColors.cream,
          appBar: AppBar(
            backgroundColor: BohoColors.cream,
            title: Text('Settings',
                style: BohoFonts.heading(22, color: BohoColors.espresso)),
            centerTitle: true,
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            children: [
              _sectionTitle('Profile'),
              _tile(
                icon: Icons.edit_rounded,
                label: 'Edit Profile',
                subtitle: 'Name, age, gender, location, bio',
                onTap: () => _editProfile(context, auth, user),
              ),
              _tile(
                icon: Icons.add_a_photo_rounded,
                label: 'Change Photo',
                subtitle: 'Profile photo or cover photo',
                onTap: () => _changePhotoSheet(context, auth, user),
              ),
              _sectionTitle('Notifications'),
              _switchTile(
                icon: Icons.favorite_rounded,
                label: 'Likes and profile views',
                subtitle: 'When someone likes you or views your profile',
                value: _notifyLikes,
                onChanged: (v) =>
                    _setPref('notifyLikes', v, (nv) => _notifyLikes = nv),
              ),
              _switchTile(
                icon: Icons.people_rounded,
                label: 'New matches',
                subtitle: 'When you match with a travel buddy',
                value: _notifyMatches,
                onChanged: (v) => _setPref(
                    'notifyMatches', v, (nv) => _notifyMatches = nv),
              ),
              _switchTile(
                icon: Icons.chat_bubble_rounded,
                label: 'Messages',
                subtitle: 'When someone sends you a message',
                value: _notifyMessages,
                onChanged: (v) => _setPref(
                    'notifyMessages', v, (nv) => _notifyMessages = nv),
              ),
              _sectionTitle('Privacy'),
              _switchTile(
                icon: Icons.location_on_rounded,
                label: 'Show my location',
                subtitle: 'Other travelers can see your location',
                value: _showLocation,
                onChanged: (v) => _setPref(
                    'showLocation', v, (nv) => _showLocation = nv),
              ),
              _switchTile(
                icon: Icons.cake_rounded,
                label: 'Show my age',
                subtitle: 'Other travelers can see your age',
                value: _showAge,
                onChanged: (v) =>
                    _setPref('showAge', v, (nv) => _showAge = nv),
              ),
              _sectionTitle('General'),
              _tile(
                icon: Icons.block_rounded,
                label: 'Blocked Users',
                subtitle: 'Travelers you have blocked',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                      builder: (_) => const BlockedUsersScreen()),
                ),
              ),
              _tile(
                icon: Icons.description_rounded,
                label: 'Legal',
                subtitle: 'Privacy Policy and Terms of Service',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const LegalScreen()),
                ),
              ),
              _tile(
                icon: Icons.help_outline_rounded,
                label: 'Help & About',
                subtitle: 'Contact support, app info',
                onTap: () => _showHelpAbout(context),
              ),
              const SizedBox(height: 12),
              _tile(
                icon: Icons.logout_rounded,
                label: 'Sign Out',
                danger: true,
                onTap: () => _confirmSignOut(context, auth),
              ),
              _tile(
                icon: Icons.delete_forever_rounded,
                label: 'Delete Account',
                subtitle: 'Permanently delete everything',
                danger: true,
                onTap: () => _confirmDeleteAccount(context, auth),
              ),
              if (!_prefsLoaded)
                const Padding(
                  padding: EdgeInsets.only(top: 16),
                  child: Center(
                      child: CircularProgressIndicator(
                          color: BohoColors.forest)),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 18, 4, 8),
      child: Text(title,
          style: BohoFonts.body(13,
              color: BohoColors.cocoaSoft, weight: FontWeight.w800)),
    );
  }

  Widget _tile(
      {required IconData icon,
      required String label,
      String? subtitle,
      required VoidCallback onTap,
      bool danger = false}) {
    final color = danger ? BohoColors.terracotta : BohoColors.forest;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: BohoColors.tan, width: 1.2),
      ),
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text(label,
            style: BohoFonts.body(15, color: color, weight: FontWeight.w700)),
        subtitle: subtitle == null
            ? null
            : Text(subtitle,
                style: BohoFonts.body(12,
                    color: BohoColors.espresso.withValues(alpha: 0.6))),
        trailing: const Icon(Icons.chevron_right_rounded,
            color: BohoColors.espresso),
        onTap: onTap,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
    );
  }

  Widget _switchTile(
      {required IconData icon,
      required String label,
      required String subtitle,
      required bool value,
      required ValueChanged<bool> onChanged}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: BohoColors.tan, width: 1.2),
      ),
      child: SwitchListTile(
        secondary: Icon(icon, color: BohoColors.forest),
        title: Text(label,
            style: BohoFonts.body(15,
                color: BohoColors.espresso, weight: FontWeight.w700)),
        subtitle: Text(subtitle,
            style: BohoFonts.body(12,
                color: BohoColors.espresso.withValues(alpha: 0.6))),
        value: value,
        activeThumbColor: BohoColors.forest,
        onChanged: onChanged,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
    );
  }

  // ---------- Edit profile ----------

  static const _genders = ['Woman', 'Man', 'Non-binary', 'Prefer not to say'];

  Future<void> _editProfile(
      BuildContext context, AuthService auth, AppUser user) async {
    final nameC = TextEditingController(text: user.name);
    final ageC = TextEditingController(text: user.age > 0 ? '${user.age}' : '');
    final locC = TextEditingController(text: user.location);
    final bioC = TextEditingController(text: user.bio);
    String? gender = _labelForGender(user.gender);

    final saved = await showDialog<bool>(
      context: context,
      builder: (dctx) => StatefulBuilder(
        builder: (dctx, setDialog) => AlertDialog(
          backgroundColor: BohoColors.cream,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Text('Edit Profile',
              style: BohoFonts.heading(22, color: BohoColors.espresso)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: nameC,
                  decoration: const InputDecoration(labelText: 'Name'),
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: ageC,
                  decoration: const InputDecoration(labelText: 'Age'),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: gender,
                  decoration: const InputDecoration(labelText: 'Gender'),
                  items: [
                    for (final g in _genders)
                      DropdownMenuItem(value: g, child: Text(g)),
                  ],
                  onChanged: (v) => setDialog(() => gender = v),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: locC,
                  decoration:
                      const InputDecoration(labelText: 'Location'),
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: bioC,
                  decoration: const InputDecoration(labelText: 'Bio'),
                  maxLines: 3,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dctx).pop(false),
              child: Text('Cancel',
                  style: BohoFonts.body(15,
                      color: BohoColors.espresso.withValues(alpha: 0.6))),
            ),
            ElevatedButton(
              style:
                  ElevatedButton.styleFrom(backgroundColor: BohoColors.forest),
              onPressed: () async {
                final bio = bioC.text.trim();
                if (!ContentFilter.isAllowed(bio)) {
                  ScaffoldMessenger.of(dctx).showSnackBar(
                    SnackBar(
                      content: Text(ContentFilter.refusalMessage,
                          style:
                              BohoFonts.body(14, color: Colors.white)),
                      backgroundColor: BohoColors.coralDeep,
                    ),
                  );
                  return;
                }
                final err = await auth.updateProfile(
                  name: nameC.text.trim(),
                  age: int.tryParse(ageC.text.trim()),
                  location: locC.text.trim(),
                  bio: bio,
                  gender: _valueForGender(gender),
                );
                await auth.refreshUser();
                if (!dctx.mounted) return;
                if (err != null) {
                  ScaffoldMessenger.of(dctx)
                      .showSnackBar(SnackBar(content: Text(err)));
                } else {
                  Navigator.of(dctx).pop(true);
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    nameC.dispose();
    ageC.dispose();
    locC.dispose();
    bioC.dispose();
    if (saved == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated')),
      );
    }
  }

  static String? _labelForGender(String value) {
    switch (value.toLowerCase()) {
      case 'woman':
      case 'women':
      case 'female':
        return 'Woman';
      case 'man':
      case 'men':
      case 'male':
        return 'Man';
      case 'nonbinary':
      case 'non-binary':
        return 'Non-binary';
      default:
        return 'Prefer not to say';
    }
  }

  static String? _valueForGender(String? label) {
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

  // ---------- Change photo ----------

  Future<void> _changePhotoSheet(
      BuildContext context, AuthService auth, AppUser user) async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: BohoColors.cream,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            BohoDecor.dragHandle(),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.person_rounded,
                  color: BohoColors.forest),
              title: Text('Profile photo',
                  style: BohoFonts.body(16, color: BohoColors.espresso)),
              onTap: () => Navigator.of(sctx).pop('avatar'),
            ),
            ListTile(
              leading: const Icon(Icons.landscape_rounded,
                  color: BohoColors.forest),
              title: Text('Cover photo',
                  style: BohoFonts.body(16, color: BohoColors.espresso)),
              onTap: () => Navigator.of(sctx).pop('cover'),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
    if (choice == null || !context.mounted) return;
    final granted = await PermissionService()
        .ensurePhotos(context, 'to update your profile photo');
    if (!granted || !context.mounted) return;
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      imageQuality: 85,
    );
    if (picked == null || !context.mounted) return;
    try {
      final cover = choice == 'cover';
      final url = await DatabaseService().uploadImage(
        File(picked.path),
        'users/${user.uid}/${cover ? 'cover' : 'avatar'}_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({cover ? 'coverUrl' : 'photoUrl': url});
      await auth.refreshUser();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Photo updated',
                style: BohoFonts.body(14, color: Colors.white)),
            backgroundColor: BohoColors.forest),
      );
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not upload the photo. Please try again.',
              style: BohoFonts.body(14, color: Colors.white)),
          backgroundColor: BohoColors.coralDeep,
        ),
      );
    }
  }

  // ---------- Help & About ----------

  void _showHelpAbout(BuildContext context) {
    showDialog(
      context: context,
      builder: (dctx) => AlertDialog(
        backgroundColor: BohoColors.cream,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text('Help & About',
            style: BohoFonts.heading(22, color: BohoColors.espresso)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('GoTRVL PH v1.0.0',
                style: BohoFonts.body(15,
                    color: BohoColors.espresso,
                    weight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(
                'Questions about the app, your account, or a safety concern? Email us and we will get back to you.',
                style: BohoFonts.body(14, color: BohoColors.espresso)),
            const SizedBox(height: 12),
            SelectableText(_supportEmail,
                style: BohoFonts.body(15,
                    color: BohoColors.forest, weight: FontWeight.w700)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dctx).pop(),
            child: Text('Close',
                style: BohoFonts.body(15,
                    color: BohoColors.espresso.withValues(alpha: 0.6))),
          ),
        ],
      ),
    );
  }

  // ---------- Sign out (confirm) ----------

  Future<void> _confirmSignOut(BuildContext context, AuthService auth) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text('Sign out?',
            style: BohoFonts.heading(24, color: BohoColors.espresso)),
        content: Text('See you on the next island hop.',
            style: BohoFonts.body(15, color: BohoColors.espresso)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dctx).pop(false),
            child: Text('Stay',
                style: BohoFonts.body(15,
                    color: BohoColors.espresso.withValues(alpha: 0.6))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: BohoColors.forest),
            onPressed: () => Navigator.of(dctx).pop(true),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    await auth.signOut();
    if (!context.mounted) return;
    Navigator.of(context).pushReplacementNamed('/login');
  }

  // ---------- Delete Account (Apple guideline 5.1.1(v)) ----------
  // Flow kept exactly as in the old profile screen: double confirm,
  // password re-auth, blocking progress, then AuthService.deleteAccount.

  /// Password prompt shown after the double-confirm, so the account can be
  /// re-authenticated before anything is deleted. Returns the typed
  /// password, or null when cancelled.
  Future<String?> _askDeletePassword(BuildContext context) {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (dctx) => AlertDialog(
        backgroundColor: BohoColors.cream,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text('Confirm it is you',
            style: BohoFonts.heading(22, color: BohoColors.espresso)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Enter your password to verify this deletion.',
                style: BohoFonts.body(15, color: BohoColors.espresso)),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              obscureText: true,
              autofocus: true,
              onSubmitted: (_) => Navigator.of(dctx).pop(ctrl.text),
              decoration: InputDecoration(
                hintText: 'Password',
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dctx).pop(),
            child: Text('Cancel',
                style: BohoFonts.body(15,
                    color: BohoColors.espresso.withValues(alpha: 0.6))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: BohoColors.terracotta),
            onPressed: () => Navigator.of(dctx).pop(ctrl.text),
            child: const Text('Delete my account'),
          ),
        ],
      ),
    );
  }

  /// Double-confirm flow, then AuthService.deleteAccount removes the
  /// Firestore user doc, best-effort Storage files, and the Auth user.
  Future<void> _confirmDeleteAccount(
      BuildContext context, AuthService auth) async {
    final first = await showDialog<bool>(
      context: context,
      builder: (dctx) => AlertDialog(
        backgroundColor: BohoColors.cream,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text('Delete your account?',
            style: BohoFonts.heading(22, color: BohoColors.espresso)),
        content: Text(
            'This permanently deletes your profile, posts, and photos. '
            'This cannot be undone.',
            style: BohoFonts.body(15, color: BohoColors.espresso)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dctx).pop(false),
            child: Text('Keep my account',
                style: BohoFonts.body(15,
                    color: BohoColors.espresso.withValues(alpha: 0.6))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: BohoColors.terracotta),
            onPressed: () => Navigator.of(dctx).pop(true),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
    if (first != true || !context.mounted) return;
    final second = await showDialog<bool>(
      context: context,
      builder: (dctx) => AlertDialog(
        backgroundColor: BohoColors.cream,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text('Are you really sure?',
            style: BohoFonts.heading(22, color: BohoColors.espresso)),
        content: Text(
            'Last chance. Once deleted, your traveler profile is gone for good.',
            style: BohoFonts.body(15, color: BohoColors.espresso)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dctx).pop(false),
            child: Text('Cancel',
                style: BohoFonts.body(15,
                    color: BohoColors.espresso.withValues(alpha: 0.6))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: BohoColors.terracotta),
            onPressed: () => Navigator.of(dctx).pop(true),
            child: const Text('Yes, delete everything'),
          ),
        ],
      ),
    );
    if (second != true || !context.mounted) return;
    // Firebase requires a recent sign-in to delete the account. Ask for the
    // password and re-authenticate BEFORE any destructive step runs, so a
    // stale credential cannot wipe the user's data while the account
    // itself survives.
    final password = await _askDeletePassword(context);
    if (password == null || password.isEmpty || !context.mounted) return;
    // Blocking progress indicator while the deletion runs.
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(color: BohoColors.forest),
      ),
    );
    final err =
        await auth.reauthenticate(password) ?? await auth.deleteAccount();
    if (!context.mounted) return;
    Navigator.of(context).pop(); // Dismiss the progress indicator.
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(err, style: BohoFonts.body(14, color: Colors.white)),
          backgroundColor: BohoColors.coralDeep,
        ),
      );
      return;
    }
    if (!context.mounted) return;
    Navigator.of(context).pushReplacementNamed('/login');
  }
}

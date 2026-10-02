import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../models/models.dart';
import '../theme/boho_theme.dart';

/// User-facing safety tools required by Apple App Review guideline 1.2:
/// report objectionable content and block users.
///
/// Reports are written to the `reports` collection using the exact schema
/// the admin console triages (see lib/admin/admin_moderation_screen.dart):
/// reason, targetType, targetId, authorUid, reporterUid, createdAt, status.
/// Only admins can read or update reports (see firestore.rules).
class ModerationService {
  static const List<String> reportReasons = [
    'Spam or scam',
    'Harassment or hate speech',
    'Inappropriate content',
    'Fake profile',
    'Something else',
  ];

  /// Opens a reason picker, then files the report. Shows a confirmation
  /// snackbar on success. No-op when the user cancels.
  static Future<void> fileReport(
    BuildContext context, {
    required String targetType, // 'post' | 'comment' | 'message' | 'user'
    required String targetId,
    required String authorUid,
    required String reporterUid,
    String? details,
  }) async {
    final reason = await showDialog<String>(
      context: context,
      builder: (dctx) => AlertDialog(
        backgroundColor: BohoColors.cream,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text('Report this $targetType',
            style: BohoFonts.heading(20, color: BohoColors.espresso)),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: reportReasons.length,
            itemBuilder: (_, i) => ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading:
                  const Icon(Icons.flag_outlined, color: BohoColors.terracotta),
              title: Text(reportReasons[i],
                  style: BohoFonts.body(15, color: BohoColors.espresso)),
              onTap: () => Navigator.of(dctx).pop(reportReasons[i]),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dctx).pop(),
            child: Text('Cancel',
                style: BohoFonts.body(15,
                    color: BohoColors.espresso.withValues(alpha: 0.6))),
          ),
        ],
      ),
    );
    if (reason == null || !context.mounted) return;
    final report = UserReport(
      reason: reason,
      targetType: targetType,
      targetId: targetId,
      authorUid: authorUid,
      reporterUid: reporterUid,
      details: details,
    );
    if (!report.isValid) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not send the report. Please try again.',
              style: BohoFonts.body(14, color: Colors.white)),
          backgroundColor: BohoColors.coralDeep,
        ),
      );
      return;
    }
    try {
      await FirebaseFirestore.instance
          .collection('reports')
          .add(report.toMap());
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Thanks. Our team will review this $targetType soon.',
              style: BohoFonts.body(14, color: Colors.white)),
          backgroundColor: BohoColors.forest,
        ),
      );
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Could not send the report. Check your connection and try again.',
              style: BohoFonts.body(14, color: Colors.white)),
          backgroundColor: BohoColors.coralDeep,
        ),
      );
    }
  }

  // ---------- Blocking ----------

  /// Adds [otherUid] to the current user's `blockedUids` array.
  /// Firestore rules only let a user write their own block list.
  static Future<void> blockUser(String meUid, String otherUid) async {
    await FirebaseFirestore.instance.collection('users').doc(meUid).update({
      'blockedUids': FieldValue.arrayUnion([otherUid]),
    });
  }

  static Future<void> unblockUser(String meUid, String otherUid) async {
    await FirebaseFirestore.instance.collection('users').doc(meUid).update({
      'blockedUids': FieldValue.arrayRemove([otherUid]),
    });
  }

  static Future<Set<String>> blockedUids(String uid) async {
    final doc =
        await FirebaseFirestore.instance.collection('users').doc(uid).get();
    return stringList(doc.data()?['blockedUids']).toSet();
  }

  static Stream<Set<String>> blockedUidsStream(String uid) {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .snapshots()
        .map((d) => stringList(d.data()?['blockedUids']).toSet());
  }

  /// Asks for confirmation, blocks the user, and shows a snackbar.
  /// Returns true when the block went through.
  static Future<bool> confirmAndBlock(
    BuildContext context, {
    required String meUid,
    required String otherUid,
    required String otherName,
  }) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dctx) => AlertDialog(
        backgroundColor: BohoColors.cream,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text('Block $otherName?',
            style: BohoFonts.heading(20, color: BohoColors.espresso)),
        content: Text(
            'You will not see each other in matching or messages anymore. '
            'You can unblock them later from Settings, then Blocked Users.',
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
            child: const Text('Block'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return false;
    try {
      await blockUser(meUid, otherUid);
      if (!context.mounted) return true;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$otherName has been blocked.',
              style: BohoFonts.body(14, color: Colors.white)),
          backgroundColor: BohoColors.forest,
        ),
      );
      return true;
    } catch (_) {
      if (!context.mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not block. Please try again.',
              style: BohoFonts.body(14, color: Colors.white)),
          backgroundColor: BohoColors.coralDeep,
        ),
      );
      return false;
    }
  }

  // ---------- Pure filtering helpers (unit-tested) ----------

  /// Removes buddy candidates the user blocked.
  static List<BuddyCard> filterBlockedBuddies(
      List<BuddyCard> cards, Set<String> blockedUids) {
    return cards.where((c) => !blockedUids.contains(c.uid)).toList();
  }

  /// Removes conversations with any blocked member.
  static List<Conversation> filterBlockedConversations(
      List<Conversation> convos, Set<String> blockedUids) {
    return convos.where((c) => !c.memberIds.any(blockedUids.contains)).toList();
  }
}

/// A user-filed moderation report. Field names must stay in sync with
/// lib/admin/admin_moderation_screen.dart, which reads: reason,
/// targetType, targetId, authorUid, reporterUid, createdAt, status.
class UserReport {
  /// Allowed values for [targetType].
  static const List<String> targetTypes = [
    'post',
    'comment',
    'message',
    'user',
  ];

  final String reason;
  final String targetType;
  final String targetId;
  final String authorUid;
  final String reporterUid;
  final String? details;

  UserReport({
    required this.reason,
    required this.targetType,
    required this.targetId,
    required this.authorUid,
    required this.reporterUid,
    this.details,
  });

  /// True when the report carries the minimum the admin queue needs:
  /// a real reason, a known target type, and non-empty target/reporter ids.
  bool get isValid =>
      reason.trim().isNotEmpty &&
      targetTypes.contains(targetType) &&
      targetId.trim().isNotEmpty &&
      reporterUid.trim().isNotEmpty;

  Map<String, dynamic> toMap() => {
        'reason': reason,
        'targetType': targetType,
        'targetId': targetId,
        'authorUid': authorUid,
        'reporterUid': reporterUid,
        if (details != null && details!.isNotEmpty) 'details': details,
        'createdAt': FieldValue.serverTimestamp(),
        'status': 'pending',
      };
}

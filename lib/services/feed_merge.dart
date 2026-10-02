// Pure feed-timeline merge: combines live streams, posts, quest memories
// and travel invitations into one newest-first list with live streams
// pinned on top. Blocked users (either direction) are excluded, and an
// optional search query filters every kind by its text fields.
//
// Pure Dart (no Flutter/Firebase imports) so it is unit-testable. The
// feed screen builds the typed entry lists and delegates here.
import '../models/models.dart';
import '../models/monetization_models.dart';

enum FeedEntryKind { live, post, memory, invitation }

class FeedEntry {
  final FeedEntryKind kind;
  final DateTime at;
  final Object item;
  const FeedEntry(this.kind, this.at, this.item);
}

/// Merges the four feed sources. [blockedUids] hides entries from those
/// users in either block direction; [query] matches case-insensitively
/// against each kind's text fields.
List<FeedEntry> mergeFeedEntries({
  required List<LiveStream> live,
  required List<Post> posts,
  required List<Memory> memories,
  required List<TravelInvitation> invitations,
  required Set<String> blockedUids,
  String query = '',
}) {
  bool hidden(String uid) => uid.isNotEmpty && blockedUids.contains(uid);
  final q = query.trim().toLowerCase();
  final entries = <FeedEntry>[];

  for (final s in live) {
    if (hidden(s.creatorUid)) continue;
    entries
        .add(FeedEntry(FeedEntryKind.live, s.scheduledAt ?? DateTime.now(), s));
  }
  for (final p in posts) {
    if (hidden(p.uid)) continue;
    if (q.isNotEmpty &&
        !p.caption.toLowerCase().contains(q) &&
        !p.userName.toLowerCase().contains(q) &&
        !p.locationTag.toLowerCase().contains(q)) {
      continue;
    }
    entries.add(FeedEntry(FeedEntryKind.post, p.createdAt, p));
  }
  for (final m in memories) {
    if (hidden(m.uid)) continue;
    if (q.isNotEmpty &&
        !m.caption.toLowerCase().contains(q) &&
        !m.placeName.toLowerCase().contains(q) &&
        !m.userName.toLowerCase().contains(q)) {
      continue;
    }
    entries.add(FeedEntry(FeedEntryKind.memory, m.createdAt, m));
  }
  for (final inv in invitations) {
    if (hidden(inv.uid)) continue;
    if (q.isNotEmpty &&
        !inv.what.toLowerCase().contains(q) &&
        !inv.where.toLowerCase().contains(q) &&
        !inv.userName.toLowerCase().contains(q)) {
      continue;
    }
    entries.add(FeedEntry(FeedEntryKind.invitation, inv.createdAt, inv));
  }

  entries.sort((a, b) {
    // Live streams always float to the top of the timeline.
    if (a.kind == FeedEntryKind.live && b.kind != FeedEntryKind.live) {
      return -1;
    }
    if (b.kind == FeedEntryKind.live && a.kind != FeedEntryKind.live) {
      return 1;
    }
    return b.at.compareTo(a.at);
  });
  return entries;
}

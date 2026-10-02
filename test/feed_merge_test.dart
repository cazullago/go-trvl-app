import 'package:flutter_test/flutter_test.dart';
import 'package:go_trvl/models/models.dart';
import 'package:go_trvl/models/monetization_models.dart';
import 'package:go_trvl/services/feed_merge.dart';

Post _post(String id, String uid, DateTime at,
        {String caption = '', String userName = 'Ana'}) =>
    Post(
      id: id,
      uid: uid,
      userName: userName,
      userPhoto: '',
      imageUrl: '',
      caption: caption,
      locationTag: 'Boracay',
      createdAt: at,
    );

Memory _memory(String id, String uid, DateTime at) => Memory(
      id: id,
      uid: uid,
      userName: 'Ben',
      userPhoto: '',
      placeId: 'p1',
      placeName: 'El Nido',
      caption: 'Sunset!',
      photoUrls: const [],
      privacy: 'public',
      createdAt: at,
    );

TravelInvitation _invite(String id, String uid, DateTime at) =>
    TravelInvitation(
      id: id,
      uid: uid,
      userName: 'Cara',
      what: 'Island hop',
      where: 'Coron',
      createdAt: at,
    );

LiveStream _live(String id, String uid, DateTime? at) => LiveStream(
      id: id,
      creatorUid: uid,
      creatorName: 'Dan',
      title: 'Live tour',
      scheduledAt: at,
    );

void main() {
  final t1 = DateTime(2026, 9, 30, 10);
  final t2 = DateTime(2026, 9, 30, 12);
  final t3 = DateTime(2026, 9, 30, 14);

  group('mergeFeedEntries', () {
    test('orders newest first across kinds', () {
      final out = mergeFeedEntries(
        live: const [],
        posts: [_post('p1', 'u1', t1)],
        memories: [_memory('m1', 'u2', t3)],
        invitations: [_invite('i1', 'u3', t2)],
        blockedUids: const {},
      );
      expect(out.map((e) => e.kind), [
        FeedEntryKind.memory,
        FeedEntryKind.invitation,
        FeedEntryKind.post,
      ]);
    });

    test('live streams float above newer posts', () {
      final out = mergeFeedEntries(
        live: [_live('l1', 'u9', t1)],
        posts: [_post('p1', 'u1', t3)],
        memories: const [],
        invitations: const [],
        blockedUids: const {},
      );
      expect(out.first.kind, FeedEntryKind.live);
      expect(out.map((e) => (e.item as dynamic).id), ['l1', 'p1']);
    });

    test('blocked users are excluded in every kind', () {
      const blocked = {'bad'};
      final out = mergeFeedEntries(
        live: [_live('l1', 'bad', t3)],
        posts: [_post('p1', 'bad', t3), _post('p2', 'good', t1)],
        memories: [_memory('m1', 'bad', t3)],
        invitations: [_invite('i1', 'bad', t3)],
        blockedUids: blocked,
      );
      expect(out.length, 1);
      expect((out.single.item as Post).id, 'p2');
    });

    test('query filters posts, memories and invitations', () {
      final out = mergeFeedEntries(
        live: const [],
        posts: [
          _post('p1', 'u1', t2, caption: 'Diving in Moalboal'),
          _post('p2', 'u2', t1, caption: 'Manila food crawl'),
        ],
        memories: [_memory('m1', 'u3', t3)],
        invitations: const [],
        blockedUids: const {},
        query: 'moalboal',
      );
      expect(out.map((e) => (e.item as Post).id), ['p1']);
    });

    test('empty inputs produce an empty timeline', () {
      expect(
          mergeFeedEntries(
            live: const [],
            posts: const [],
            memories: const [],
            invitations: const [],
            blockedUids: const {},
          ),
          isEmpty);
    });
  });
}

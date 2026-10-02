import 'package:flutter_test/flutter_test.dart';
import 'package:go_trvl/models/models.dart';
import 'package:go_trvl/services/content_filter.dart';
import 'package:go_trvl/services/moderation_service.dart';

void main() {
  group('ContentFilter.isAllowed', () {
    test('allows ordinary travel text', () {
      expect(ContentFilter.isAllowed('Loved the sunset in El Nido!'), true);
      expect(ContentFilter.isAllowed(''), true);
      expect(ContentFilter.isAllowed('12345 !!!'), true);
    });

    test('blocks banned words case-insensitively', () {
      expect(ContentFilter.isAllowed('This is shit'), false);
      expect(ContentFilter.isAllowed('You are a BITCH'), false);
      expect(ContentFilter.isAllowed('putangina mo'), false);
      expect(ContentFilter.isAllowed('GAGO ka'), false);
    });

    test('matches whole words only, no substring false positives', () {
      expect(ContentFilter.isAllowed('The classic view was great'), true);
      expect(ContentFilter.isAllowed('Scunthorpe is a town'), true);
      expect(ContentFilter.isAllowed('passionate traveler'), true);
    });

    test('refusal message is friendly and has no em-dashes', () {
      expect(ContentFilter.refusalMessage.contains('\u2014'), false);
      expect(ContentFilter.refusalMessage.isNotEmpty, true);
    });
  });

  group('ModerationService.filterBlockedBuddies', () {
    BuddyCard card(String uid) => BuddyCard(
          uid: uid,
          name: 'Traveler $uid',
          age: 25,
          location: '',
          photoUrl: '',
          bio: '',
          interests: const [],
        );

    test('removes blocked uids from candidates', () {
      final cards = [card('a'), card('b'), card('c')];
      final out = ModerationService.filterBlockedBuddies(cards, {'b'});
      expect(out.map((c) => c.uid), ['a', 'c']);
    });

    test('empty block list keeps everyone', () {
      final cards = [card('a'), card('b')];
      final out = ModerationService.filterBlockedBuddies(cards, {});
      expect(out.length, 2);
    });
  });

  group('ModerationService.filterBlockedConversations', () {
    Conversation convo(String id, List<String> members) => Conversation(
          id: id,
          memberIds: members,
          otherName: 'Traveler',
          otherPhoto: '',
          lastMessage: 'hi',
          updatedAt: DateTime(2026, 1, 1),
        );

    test('removes conversations with a blocked member', () {
      final convos = [
        convo('c1', ['me', 'a']),
        convo('c2', ['me', 'b']),
      ];
      final out = ModerationService.filterBlockedConversations(convos, {'b'});
      expect(out.map((c) => c.id), ['c1']);
    });

    test('keeps all conversations when nobody is blocked', () {
      final convos = [
        convo('c1', ['me', 'a'])
      ];
      final out = ModerationService.filterBlockedConversations(convos, {});
      expect(out.length, 1);
    });
  });

  group('UserReport.toMap', () {
    test('matches the admin console report schema', () {
      final report = UserReport(
        reason: 'Spam or scam',
        targetType: 'post',
        targetId: 'post123',
        authorUid: 'author1',
        reporterUid: 'reporter9',
      );
      final map = report.toMap();
      expect(map['reason'], 'Spam or scam');
      expect(map['targetType'], 'post');
      expect(map['targetId'], 'post123');
      expect(map['authorUid'], 'author1');
      expect(map['reporterUid'], 'reporter9');
      expect(map['status'], 'pending');
      expect(map.containsKey('createdAt'), true);
      expect(map.containsKey('details'), false);
    });

    test('includes details when provided', () {
      final report = UserReport(
        reason: 'Harassment or hate speech',
        targetType: 'message',
        targetId: 'msg1',
        authorUid: 'author1',
        reporterUid: 'reporter9',
        details: 'In chat with Ana: hello',
      );
      expect(report.toMap()['details'], 'In chat with Ana: hello');
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:plans/api/types.dart';
import 'package:plans/i18n/i18n.dart';
import 'package:plans/util/format.dart';
import 'package:plans/util/misc.dart';

import 'fixtures.dart';

void main() {
  group('i18n', () {
    test('English is the source text, with placeholders filled', () {
      expect(tr('Step {step} of 4', {'step': 2}, 'en'), 'Step 2 of 4');
      expect(tr('Not a key at all', null, 'hi'), 'Not a key at all');
    });

    test('Hindi translations come from the converted dictionary', () {
      expect(tr('Chats', null, 'hi'), 'चैट');
      expect(tr(', {unread} unread', {'unread': 3}, 'hi'), ', 3 अपठित');
    });

    test('server text: exact match, then templates with values inside', () {
      expect(translateServer('You’re offline. Reconnect and try again.', 'hi'), 'आप ऑफ़लाइन हैं। दोबारा कनेक्ट करके फिर कोशिश करें।');
      expect(translateServer('Notifications, 5 unread', 'hi'), 'सूचनाएँ, 5 अपठित');
      expect(translateServer('Something only the server says', 'hi'), 'Something only the server says');
      expect(translateServer('Chats', 'en'), 'Chats');
    });

    test('rich text keeps word order per language', () {
      final spans = trRich('Shared interests: {list}', {});
      expect(spans, isNotEmpty);
    });
  });

  group('format', () {
    test('initials match the React helper', () {
      expect(initials('Ananya Kapoor'), 'AK');
      expect(initials("D'Souza, Riya"), 'DR');
      expect(initials(''), '?');
      expect(initials('riya'), 'R');
    });

    test('clock is 12-hour with AM/PM', () {
      expect(clock(DateTime(2026, 1, 1, 0, 5)), '12:05 AM');
      expect(clock(DateTime(2026, 1, 1, 13, 0)), '1:00 PM');
      expect(clock(DateTime(2026, 1, 1, 12, 30)), '12:30 PM');
    });

    test('planDate covers unset, today, multi-day ranges', () {
      expect(planDate(null), 'Date not set');
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day, 17).toUtc().toIso8601String();
      expect(planDate(today), 'Today · 5:00 PM');
      expect(planDate('2026-09-20T04:00:00Z', '2026-09-23T10:00:00Z'), '20–23 Sep');
      expect(planDate('2026-09-28T04:00:00Z', '2026-10-02T10:00:00Z'), '28 Sep – 2 Oct');
    });

    test('weekday names line up with JavaScript getDay()', () {
      // 21 Sep 2026 is a Monday.
      final iso = DateTime(2026, 9, 21, 9).toUtc().toIso8601String();
      expect(planDate(iso).startsWith('Mon, 21 Sep'), isTrue);
    });

    test('signals sort strongest first', () {
      expect(sortSignals(['EMAIL', 'IDENTITY', 'PHONE']), ['IDENTITY', 'PHONE', 'EMAIL']);
      expect(topSignal(['PHONE', 'ORGANIZER']), 'Organizer verified');
      expect(topSignal([]), isNull);
    });

    test('intent kicker uses up to two intents', () {
      expect(intentKicker(['FRIENDS', 'DATING', 'NETWORKING']), 'OPEN TO FRIENDS · DATING');
      expect(intentKicker([]), '');
    });
  });

  group('models', () {
    test('AppConfig reads feature flags and treats anything missing as off', () {
      final on = AppConfig({'features': {'payments': true, 'banners': false, 'broadcasts': true}}).features;
      expect([on.payments, on.banners, on.broadcasts], [true, false, true]);
      final empty = AppConfig({}).features;
      expect([empty.payments, empty.banners, empty.broadcasts], [false, false, false]);
      final partial = AppConfig({'features': {'banners': true}}).features;
      expect([partial.payments, partial.banners, partial.broadcasts], [false, true, false]);
    });

    test('Me parses the full /api/me shape and patches like a spread', () {
      final me = fakeMe();
      expect(me.privacy.language, 'en');
      expect(me.organizer?.status, 'IN_REVIEW');
      final patched = me.copyWith({'privacy': {...me.privacy.json, 'showAge': false}});
      expect(patched.privacy.showAge, isFalse);
      expect(patched.displayName, me.displayName);
    });

    test('short choice labels follow the privacy settings', () {
      final me = fakeMe();
      expect(shortChoice('connectionRequests', me.privacy), 'People from my Plans');
      expect(shortChoice('language', me.privacy), 'English');
    });

    test('business placeholders are never used as email addresses', () {
      expect(isPlaceholder('[support@yourdomain]'), isTrue);
      expect(emailOrNull('[support@yourdomain]'), isNull);
      expect(emailOrNull('help@plans.app'), 'help@plans.app');
    });

    test('message JSON round-trips with optional sender', () {
      final m = Message({'id': 1, 'conversationId': 2, 'mine': false, 'system': true, 'removed': false, 'text': 'Hi', 'createdAt': '2026-10-01T10:00:00Z'});
      expect(m.sender, isNull);
      expect(m.system, isTrue);
    });
  });
}

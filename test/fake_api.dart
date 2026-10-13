import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'fixtures.dart';

// Realistic responses for every endpoint the screens read, so each screen renders with data.

final _now = DateTime.now().toUtc();
String _at(Duration d) => _now.add(d).toIso8601String();

Map<String, dynamic> user(int id, String name, {List<String> signals = const ['PHONE'], String? area = 'Koramangala'}) =>
    {'id': id, 'displayName': name, 'photoUrl': null, 'area': area, 'signals': signals, 'signalsUnavailable': false};

Map<String, dynamic> host({bool organizer = false}) => {
      'kind': organizer ? 'ORGANIZER' : 'USER',
      'id': organizer ? 3 : 11,
      'name': organizer ? 'Bengaluru Trekkers Collective' : 'Vikram Shetty',
      'photoUrl': null,
      'signals': organizer ? ['ORGANIZER'] : ['IDENTITY', 'PHONE'],
      'subtitle': organizer ? 'Community organizer' : 'Creator',
    };

Map<String, dynamic> planSummary(int id,
        {String title = 'Weekend Photography Walk through Cubbon Park and the old city markets',
        String category = 'Photography',
        String status = 'ACTIVE',
        bool official = false,
        bool joined = false,
        bool owner = false}) =>
    {
      'id': id,
      'title': title,
      'category': category,
      'area': 'Indiranagar, Bengaluru',
      'startAt': _at(const Duration(days: 2, hours: 3)),
      'endAt': null,
      'participantCount': 6,
      'participantLimit': 12,
      'status': status,
      'official': official,
      'coverImageUrl': null,
      'host': host(organizer: official),
      'why': 'Matches your interest in Photography and is near Indiranagar',
      'joined': joined,
      'owner': owner,
    };

Map<String, dynamic> planDetail(int id, {bool owner = false, String status = 'UPDATED'}) => {
      ...planSummary(id, status: status, official: true, joined: !owner, owner: owner),
      'description': 'A slow morning walk with cameras. Beginners welcome — we stop for chai halfway.',
      'meetingPoint': 'Cubbon Park bandstand',
      'meetingPointHidden': false,
      'locationMode': 'PUBLIC_VENUE',
      'visibility': 'DISCOVERABLE',
      'registrationMode': 'EXTERNAL',
      'registrationUrl': 'trekkers.example.org/register',
      'schedule': [
        {'time': '7:00 AM', 'what': 'Meet at the bandstand'},
        {'time': '9:30 AM', 'what': 'Chai break and photo review'},
      ],
      'bring': 'Water, comfortable shoes',
      'eligibility': 'Beginners welcome · 18+',
      'instructions': 'Look for the green flag.',
      'members': [
        {'user': user(7, 'Ananya Kapoor'), 'role': 'PARTICIPANT', 'me': true},
        {'user': user(11, 'Vikram Shetty', signals: ['IDENTITY']), 'role': 'CREATOR', 'me': false},
        {'user': user(12, 'Nisha Menon'), 'role': 'PARTICIPANT', 'me': false},
        {'user': user(13, 'Rahul Dev'), 'role': 'PARTICIPANT', 'me': false},
        {'user': user(14, 'Sara Ali'), 'role': 'PARTICIPANT', 'me': false},
        {'user': user(15, 'Kiran B'), 'role': 'PARTICIPANT', 'me': false},
      ],
      'groupConversationId': 21,
      'latestChange': {
        'by': 'Vikram Shetty',
        'at': _at(const Duration(hours: -3)),
        'changes': [
          {'field': 'startAt', 'label': 'Date & time', 'from': 'Sat, 20 Sep · 7:00 AM', 'to': 'Sun, 21 Sep · 7:00 AM'},
          {'field': 'meetingPoint', 'label': 'Meeting point', 'from': 'MG Road metro', 'to': 'Cubbon Park bandstand'},
        ],
      },
      'cancelReason': null,
      'shareCode': 'abc123',
      'createdAt': _at(const Duration(days: -5)),
      'updatedAt': _at(const Duration(hours: -3)),
    };

Map<String, dynamic> message(int id, String text, {bool mine = false, bool system = false, int senderId = 11, String sender = 'Vikram Shetty', Duration ago = const Duration(minutes: 30)}) => {
      'id': id,
      'conversationId': 20,
      'sender': system ? null : user(mine ? 7 : senderId, mine ? 'Ananya Kapoor' : sender),
      'mine': mine,
      'system': system,
      'removed': false,
      'text': text,
      'createdAt': _at(-ago),
    };

Map<String, dynamic> conversation(int id, {bool group = false}) => {
      'id': id,
      'type': group ? 'GROUP' : 'DIRECT',
      'title': group ? 'Weekend Photography Walk' : 'Vikram Shetty',
      'context': group ? 'Plan Group · 6 participants' : 'Met through Weekend Photography Walk',
      'planId': 5,
      'otherUser': group ? null : user(11, 'Vikram Shetty', signals: ['IDENTITY']),
      'lastMessage': message(103, 'See you at the bandstand! Bring a spare battery if you have one.', mine: false),
      'unread': group ? 0 : 14,
      'muted': group,
    };

Map<String, dynamic> conversationDetail(int id, {bool group = false}) => {
      ...conversation(id, group: group),
      'planTitle': 'Weekend Photography Walk',
      'planLine': 'Weekend Photography Walk · Sun, 21 Sep · 7:00 AM',
      'official': group,
      'archived': false,
      'archivedReason': null,
      'announcement': group ? {'title': 'Meeting point update', 'body': 'We now meet at the west entrance.', 'by': 'Vikram Shetty', 'at': _at(const Duration(hours: -1))} : null,
      'members': planDetail(5)['members'],
      'canSend': true,
      'blockedByMe': false,
      'firstUnreadMessageId': 102,
    };

Map<String, dynamic> notification(int id, {String category = 'PLANS', String priority = 'HIGH', bool read = false, Duration ago = const Duration(hours: 2)}) => {
      'id': id,
      'category': category,
      'type': 'PLAN_UPDATED',
      'priority': priority,
      'icon': category == 'SAFETY' ? 'lock' : 'calendar',
      'actor': category == 'PEOPLE' ? user(12, 'Nisha Menon') : null,
      'title': 'Weekend Photography Walk was updated',
      'body': 'The time and meeting point changed.',
      'quote': category == 'PEOPLE' ? 'Hi! Saw we are both joining the walk.' : null,
      'context': 'Weekend Photography Walk',
      'diff': category == 'PLANS' ? [{'label': 'Date & time', 'from': 'Sat 7:00 AM', 'to': 'Sun 7:00 AM'}] : [],
      'cta': 'View Plan',
      'destination': {'kind': 'PLAN', 'id': 5, 'mode': 'updated'},
      'read': read,
      'createdAt': _at(-ago),
    };

Map<String, dynamic> report(int id, {String status = 'UNDER_REVIEW'}) => {
      'id': id,
      'targetType': 'PROFILE',
      'targetId': 12,
      'targetLabel': 'Nisha Menon’s profile',
      'personId': 12,
      'personName': 'Nisha',
      'reason': 'Spam or scams',
      'details': 'Kept sending links to a paid group.',
      'status': status,
      'submittedAt': _at(const Duration(days: -2)),
      'updatedAt': _at(const Duration(days: -1)),
      'unseenUpdate': true,
    };

const _verification = {
  'identity': {'status': 'VERIFIED', 'expiresAt': null},
  'phone': {'status': 'VERIFIED', 'masked': '+91 ••••••3210'},
  'email': {'status': 'PENDING', 'masked': 'an••••@example.com'},
  'organizer': {'status': 'IN_REVIEW', 'organizerId': 3, 'name': 'Ananya’s Photo Walks'},
};

Object? fakeResponse(String method, Uri uri) {
  final p = uri.path;
  final seg = p.split('/').where((s) => s.isNotEmpty).toList();
  if (p == '/api/me') return meJson();
  if (p == '/api/discover') {
    return {
      'plans': [planSummary(5, official: true), planSummary(6, category: 'Trek', title: 'Nandi Hills sunrise trek', status: 'FULL')],
      'people': [
        {'user': user(12, 'Nisha Menon', signals: ['IDENTITY', 'PHONE']), 'bio': 'Street photographer and filter coffee person.', 'context': 'Also joining Weekend Photography Walk', 'sharedInterests': ['Photography', 'Cafés']},
      ],
      'organizerNearby': {'id': 3, 'name': 'Bengaluru Trekkers Collective', 'type': 'COMMUNITY', 'status': 'VERIFIED', 'signals': ['ORGANIZER'], 'upcomingCount': 4},
      'hiddenFromPeople': true,
    };
  }
  if (p == '/api/search') return {'plans': [planSummary(5)], 'people': [{'user': user(12, 'Nisha Menon'), 'bio': null, 'context': 'Shared interest: Photography', 'sharedInterests': []}]};
  if (p == '/api/plans/mine') {
    return {
      'upcoming': [planSummary(5, joined: true)],
      'hosting': [planSummary(8, owner: true, status: 'UPDATED')],
      'drafts': [planSummary(9, owner: true, status: 'DRAFT')],
      'past': [planSummary(10, status: 'COMPLETED')],
    };
  }
  if (seg.length == 3 && seg[1] == 'plans') return planDetail(int.parse(seg[2]), owner: seg[2] == '8');
  if (p == '/api/conversations') return [conversation(21, group: true), conversation(20)];
  if (seg.length == 3 && seg[1] == 'conversations') return conversationDetail(int.parse(seg[2]), group: seg[2] == '21');
  if (seg.length == 4 && seg[1] == 'conversations' && seg[3] == 'messages') {
    return [
      message(100, 'Vikram created this Plan Group.', system: true, ago: const Duration(days: 2)),
      message(101, 'Hi everyone! Looking forward to Sunday.', mine: true, ago: const Duration(days: 1)),
      message(102, 'Same here. Is the route OK for beginners?', senderId: 12, sender: 'Nisha Menon', ago: const Duration(hours: 2)),
      message(103, 'See you at the bandstand! Bring a spare battery if you have one.', ago: const Duration(minutes: 30)),
    ];
  }
  if (seg.length == 3 && seg[1] == 'users') {
    return {
      ...user(int.parse(seg[2]), 'Nisha Menon', signals: ['IDENTITY', 'PHONE']),
      'firstName': 'Nisha',
      'ageRange': '26–29',
      'intents': ['FRIENDS', 'ACTIVITY_PARTNERS'],
      'bio': 'Street photographer and filter coffee person.',
      'interests': ['Photography', 'Cafés', 'Trekking'],
      'sharedInterests': ['Photography'],
      'mutualConnections': ['Vikram'],
      'sharedPlan': {'id': 5, 'title': 'Weekend Photography Walk', 'when': 'Sun, 21 Sep · 7:00 AM', 'label': 'YOU’RE BOTH JOINING'},
      'connectionStatus': 'PENDING_INCOMING',
      'connectionId': 40,
      'blockedByMe': false,
      'canMessage': true,
      'canConnect': false,
      'availability': 'AVAILABLE',
    };
  }
  if (seg.length == 3 && seg[1] == 'organizers') {
    return {
      'id': 3, 'name': 'Bengaluru Trekkers Collective', 'type': 'COMMUNITY', 'status': 'VERIFIED', 'signals': ['ORGANIZER'], 'upcomingCount': 2,
      'about': 'Weekend treks around Bengaluru for all levels.', 'area': 'Bengaluru', 'website': 'trekkers.example.org', 'since': 'Mar 2024',
      'mine': false, 'available': true, 'upcoming': [planSummary(6, category: 'Trek')], 'past': [planSummary(10, status: 'COMPLETED')],
    };
  }
  if (seg.length == 4 && seg[1] == 'connections' && seg[2] == 'requests') {
    return {
      'id': 40, 'from': user(12, 'Nisha Menon', signals: ['IDENTITY']), 'ageRange': '26–29', 'intents': ['FRIENDS'],
      'note': 'Hi! Saw we are both joining the walk.',
      'sharedPlan': {'id': 5, 'title': 'Weekend Photography Walk', 'when': 'Sun, 21 Sep · 7:00 AM', 'label': 'YOU’RE BOTH JOINING'},
      'sharedInterests': ['Photography'], 'status': 'PENDING', 'createdAt': _at(const Duration(hours: -5)),
    };
  }
  if (p == '/api/notifications') {
    return [
      notification(1),
      notification(2, category: 'PEOPLE', priority: 'NORMAL', ago: const Duration(days: 1)),
      notification(3, category: 'SAFETY', priority: 'LOW', read: true, ago: const Duration(days: 3)),
      notification(4, read: true, ago: const Duration(days: 12)),
    ];
  }
  if (p == '/api/notifications/preferences') {
    return {
      'push': true, 'directMessages': true, 'groupMessages': false, 'connectionRequests': true, 'acceptedRequests': true, 'planUpdates': true,
      'planReminders': true, 'participantUpdates': false, 'cancellations': true, 'announcements': true, 'suggestions': false,
      'remindDayBefore': true, 'remindHourBefore': false,
    };
  }
  if (p == '/api/reports' && method == 'POST') return report(32, status: 'SUBMITTED');
  if (p == '/api/reports') return [report(30), report(31, status: 'ACTION_TAKEN')];
  if (seg.length == 3 && seg[1] == 'reports') return report(int.parse(seg[2]));
  if (p == '/api/blocks') return [{'user': user(16, 'Spam Account'), 'context': 'From Weekend Photography Walk', 'blockedAt': _at(const Duration(days: -4))}];
  if (p == '/api/verification') return _verification;
  if (p == '/api/me/sessions') {
    return [
      {'id': 1, 'deviceName': 'Pixel 7', 'platform': 'ANDROID', 'app': 'Plans 1.0.0', 'area': 'Bengaluru', 'lastActiveAt': _at(Duration.zero), 'current': true},
      {'id': 2, 'deviceName': 'iPhone 15', 'platform': 'IOS', 'app': 'Plans 1.0.0', 'area': 'Mysuru', 'lastActiveAt': _at(const Duration(days: -2)), 'current': false},
    ];
  }
  if (p == '/api/me/security-events') {
    return [{'id': 1, 'title': 'New sign-in on iPhone 15', 'deviceName': 'iPhone 15', 'area': 'Mysuru', 'createdAt': _at(const Duration(days: -2))}];
  }
  if (p == '/api/me/consents') {
    return {
      'analytics': false, 'offers': false, 'marketingEmails': false, 'decided': true, 'policyVersion': '2026-01',
      'history': [{'kind': 'TERMS', 'granted': true, 'version': '2026-01', 'source': 'SIGNUP', 'at': _at(const Duration(days: -30))}],
    };
  }
  if (seg.length == 4 && seg[1] == 'content' && seg[2] == 'pages') {
    return {
      'id': 1, 'slug': seg[3], 'title': 'Privacy policy', 'published': true, 'updatedAt': _at(const Duration(days: -10)),
      'body': '# Privacy policy\n\nWe collect **only** what Plans needs. Contact [Grievance Officer](mailto:grievance@example.com).\n\n## Your rights\n\n- Download your data\n- Delete your account\n\n_Last reviewed by [Company legal name]._',
    };
  }
  if (p == '/api/categories') return [{'id': 1, 'name': 'Photography', 'labelHi': 'फ़ोटोग्राफ़ी', 'labelKn': null}, {'id': 2, 'name': 'Trek', 'labelHi': null, 'labelKn': null}];
  return null;
}

/// Every request answered from the fixtures above; anything unknown is a 404 like the real server.
MockClient fakeBackend({List<String>? log}) => MockClient((req) async {
      log?.add('${req.method} ${req.url.path}');
      final body = fakeResponse(req.method, req.url);
      if (body == null) {
        if (req.method != 'GET') return http.Response('', 204);
        return http.Response(jsonEncode({'status': 404, 'code': 'NOT_FOUND', 'message': 'Not found'}), 404, headers: {'content-type': 'application/json'});
      }
      return http.Response.bytes(utf8.encode(jsonEncode(body)), 200, headers: {'content-type': 'application/json; charset=utf-8'});
    });

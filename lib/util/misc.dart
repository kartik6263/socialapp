import '../api/api.dart';
import '../i18n/i18n.dart';
import '../nav.dart';
import '../theme.dart';
import '../widgets/icons.dart';

// ---------- Business details ----------

/// Business and grievance details shown in the app (About, Help, policies).
/// India’s IT Rules 2021 and the DPDP Act require a reachable Grievance Officer; app stores require a support contact.
///
/// FILL THESE IN BEFORE LAUNCH. Bracketed values are placeholders, and the app labels them as "to be added".
/// Keep them in step with the policy pages in the Admin Console (Content → Pages & policies).
class Business {
  static const legalName = '[Company legal name]';
  static const brand = 'Plans';
  static const registeredAddress = '[Registered office address, City, State, PIN]';
  static const cin = '[CIN / registration number]';
  static const gstin = '[GSTIN, if registered]';
  static const supportEmail = '[support@yourdomain]';
  static const privacyEmail = '[privacy@yourdomain]';
  static const grievanceOfficerName = '[Grievance Officer name]';
  static const grievanceOfficerEmail = '[grievance@yourdomain]';

  /// Shown as the expected first-response time. Only state what the team actually commits to.
  static const responseTime = '[e.g. within 2 working days]';
  static const website = '[https://yourdomain]';
}

bool isPlaceholder(String v) => RegExp(r'^\[.*\]$').hasMatch(v.trim());

/// A usable email address, or null while it's still a placeholder (so we never open a broken mailto:).
String? emailOrNull(String v) => isPlaceholder(v) || !v.contains('@') ? null : v;

/// mailto: link with properly encoded subject/body (spaces as %20, like encodeURIComponent).
Uri mailto(String to, {String? subject, String? body}) {
  final q = <String>[
    if (subject != null) 'subject=${Uri.encodeComponent(subject)}',
    if (body != null) 'body=${Uri.encodeComponent(body)}',
  ];
  return Uri.parse('mailto:$to${q.isEmpty ? '' : '?${q.join('&')}'}');
}

// ---------- Categories ----------

/// Plan categories are managed in the admin console; each carries its own Hindi and Kannada label.
// Built-in list until the server answers (first launch, offline). Labels then come from the app dictionary.
List<Category> _categoryCache = [for (var i = 0; i < categoriesList.length; i++) Category.local(-i - 1, categoriesList[i])];
Future<List<Category>>? _categoriesLoading;

Future<List<Category>> loadCategories() {
  return _categoriesLoading ??= () async {
    try {
      final list = await CategoriesApi.list();
      if (list.isNotEmpty) _categoryCache = list;
    } catch (_) {
      _categoriesLoading = null; // retry next time a screen asks
    }
    return _categoryCache;
  }();
}

List<Category> get cachedCategories => _categoryCache;

/// The category name stored on Plans stays English; this is what people see in their language.
String categoryLabel(String name) {
  final lang = getLang();
  final matches = _categoryCache.where((x) => x.name == name);
  final c = matches.isEmpty ? null : matches.first;
  final fromServer = lang == 'hi' ? c?.labelHi : (lang == 'kn' ? c?.labelKn : null);
  return (fromServer != null && fromServer.isNotEmpty) ? fromServer : tr(name);
}

// ---------- Notification destinations ----------

/// Deep-link map from the prototype: each notification opens one destination, or a fallback if it's gone.
void openDestination(Destination d) {
  final id = d.id;
  switch (d.kind) {
    case 'PLAN':
      Nav.push('/plan/$id', {'from': 'notification', 'mode': d.mode ?? ''});
    case 'CHAT':
      Nav.push('/chat/$id');
    case 'GROUP':
      Nav.push('/group/$id');
    case 'REQUEST':
      Nav.push('/request/$id');
    case 'PROFILE':
      Nav.push('/user/$id');
    case 'REPORT':
      Nav.push('/safety/reports/$id');
    case 'VERIFY':
      Nav.push('/verify');
    case 'SECURITY':
      Nav.push('/settings/secActivity');
    default:
      Nav.push('/unavailable', {'reason': d.reason ?? 'content'});
  }
}

// ---------- Report flow ----------

class ReportParams {
  final ReportTarget targetType;
  final int? targetId;

  /// What is being reported, shown at the top of the flow ("Aarav P.’s profile").
  final String title;
  final String? sub;
  final String? quote;

  /// Person who can optionally be blocked in the same flow.
  final int? personId;
  final String? personName;
  const ReportParams({required this.targetType, this.targetId, required this.title, this.sub, this.quote, this.personId, this.personName});
}

void openReport(ReportParams p) {
  Nav.push('/report', {
    'targetType': p.targetType,
    'targetId': p.targetId?.toString() ?? '',
    'title': p.title,
    'sub': p.sub ?? '',
    'quote': p.quote ?? '',
    'personId': p.personId?.toString() ?? '',
    'personName': p.personName ?? '',
  });
}

const reportStatusLabel = {
  'SUBMITTED': 'Submitted', 'UNDER_REVIEW': 'Under review', 'ACTION_TAKEN': 'Action taken', 'NO_ACTION': 'No action', 'CLOSED': 'Closed',
};

const reportStatusTone = {
  'SUBMITTED': PillTone.neutral, 'UNDER_REVIEW': PillTone.blue, 'ACTION_TAKEN': PillTone.ok, 'NO_ACTION': PillTone.warn, 'CLOSED': PillTone.neutral,
};

const reportOutcome = {
  'SUBMITTED': 'Your report was received. We’ll review it soon.',
  'UNDER_REVIEW': 'The report is being reviewed. We’ll update you here when it’s done.',
  'ACTION_TAKEN': 'Appropriate action was taken under our community guidelines.',
  'NO_ACTION': 'The review didn’t result in an action. You can still block this person at any time.',
  'CLOSED': 'This report is closed.',
};

const reportTypeLabel = {
  'PROFILE': 'Profile', 'PARTICIPANT': 'Participant', 'MESSAGE': 'Message', 'CONVERSATION': 'Conversation', 'PLAN': 'Plan',
  'GROUP': 'Group', 'ORGANIZER': 'Organizer', 'EVENT': 'Event', 'PROBLEM': 'Problem',
};

const reportTypeIcon = <String, IconName>{
  'PROFILE': 'user', 'PARTICIPANT': 'user', 'MESSAGE': 'message-circle', 'CONVERSATION': 'message-circle', 'PLAN': 'calendar',
  'GROUP': 'users', 'ORGANIZER': 'users', 'EVENT': 'calendar', 'PROBLEM': 'flag',
};

// ---------- Privacy choices ----------

class ChoiceOption {
  final String value;
  final String label;
  final String? sub;
  final String short;
  const ChoiceOption(this.value, this.label, this.sub, this.short);
}

class Choice {
  final String kicker;
  final String title;
  final String intro;
  final String? note;
  final List<ChoiceOption> opts;
  const Choice({required this.kicker, required this.title, required this.intro, this.note, required this.opts});
}

/// 'profileVisibility' | 'areaLevel' | 'defaultPlanVisibility' | 'planLocation' | 'connectionRequests' | 'messages' | 'language'
typedef ChoiceKey = String;

const choices = <ChoiceKey, Choice>{
  'profileVisibility': Choice(
    kicker: 'PRIVACY', title: 'Profile visibility',
    intro: 'Your profile can show your public profile information, Plans and relevant shared context according to your privacy settings.',
    opts: [
      ChoiceOption('EVERYONE', 'Visible to people using Plans', 'People discovering nearby Plans can open your profile.', 'Everyone on Plans'),
      ChoiceOption('SHARED_CONTEXT', 'Only people with shared context', 'Only people in the same Plan, event or destination can open your profile.', 'Shared context only'),
    ],
  ),
  'areaLevel': Choice(
    kicker: 'LOCATION', title: 'Area detail', intro: 'How broad your approximate area is when shown.',
    opts: [
      ChoiceOption('NEIGHBOURHOOD', 'Neighbourhood', 'Shown as “Indiranagar area”.', 'Neighbourhood'),
      ChoiceOption('CITY', 'City only', 'Shown as “Bengaluru”.', 'City only'),
    ],
  ),
  'defaultPlanVisibility': Choice(
    kicker: 'PRIVACY', title: 'Default Plan visibility', intro: 'Used for new Plans you create. You can change it on each Plan.',
    opts: [
      ChoiceOption('DISCOVERABLE', 'Discoverable', 'Discoverable Plans can appear in relevant discovery results.', 'Discoverable'),
      ChoiceOption('SHARED_CONTEXT', 'Shared-context only', 'Only people with a shared event, destination or connection can find it.', 'Shared-context only'),
      ChoiceOption('PRIVATE', 'Private', 'Private Plans are not publicly discoverable. Only people with the link can join.', 'Private'),
    ],
  ),
  'planLocation': Choice(
    kicker: 'LOCATION', title: 'Plan location', intro: 'What people see about where your Plans happen. Meeting points are always public places.',
    note: 'Destinations and official event venues are always shown, because they’re already public.',
    opts: [
      ChoiceOption('APPROXIMATE', 'Approximate area until people join', 'Participants see the exact public meeting point after joining.', 'Approximate until joined'),
      ChoiceOption('PUBLIC_VENUE', 'Public venue for everyone', 'Only for public places like cafés, parks and event venues.', 'Public venue'),
    ],
  ),
  'connectionRequests': Choice(
    kicker: 'CONTACT', title: 'Who can send me connection requests?', intro: 'Requests always show the shared Plan or context they came from.',
    opts: [
      ChoiceOption('MY_PLANS', 'People from my Plans', 'Only people who joined the same Plan as you.', 'People from my Plans'),
      ChoiceOption('SHARED_CONTEXT', 'People with shared context', 'Same Plan, event, or destination and dates.', 'Shared context'),
      ChoiceOption('ANYONE', 'Anyone who can discover me', 'Anyone who can see your profile, based on your visibility setting.', 'Anyone who can discover me'),
      ChoiceOption('NOBODY', 'Nobody', 'You can still send requests yourself.', 'Nobody'),
    ],
  ),
  'messages': Choice(
    kicker: 'CONTACT', title: 'Who can message me?', intro: 'Blocked people can never message you, whatever you choose here.',
    opts: [
      ChoiceOption('CONNECTED', 'Connected people only', 'People you’ve accepted a connection with.', 'Connected people'),
      ChoiceOption('CONNECTED_AND_PLANS', 'Connected people and people from my Plans', 'Includes people in the same Plan, before connecting.', 'Connected + my Plans'),
      ChoiceOption('NOBODY', 'Nobody', 'Existing conversations become read-only. Plan Groups still work.', 'Nobody'),
    ],
  ),
  'language': Choice(
    kicker: 'PREFERENCES', title: 'Language', intro: 'English is the default. Hindi is fully supported; Kannada is a secondary language and may show some English.',
    opts: [
      ChoiceOption('en', 'English', 'Default', 'English'),
      ChoiceOption('hi', 'हिन्दी', 'Hindi', 'हिन्दी'),
      ChoiceOption('kn', 'ಕನ್ನಡ', 'Kannada · secondary language', 'ಕನ್ನಡ'),
    ],
  ),
};

/// Translated short value for settings rows (language names stay in their own script).
String shortChoice(ChoiceKey key, PrivacySettings p) {
  final current = p[key];
  final match = choices[key]!.opts.where((o) => o.value == current);
  final short = match.isEmpty ? '' : match.first.short;
  return key == 'language' ? short : tr(short);
}

import 'client.dart';
import 'types.dart';

export 'client.dart' show ApiError, apiUrl, asApiError;
export 'types.dart';

typedef Channel = String; // 'PHONE' | 'EMAIL'

List<T> _list<T>(dynamic v, T Function(Json) f) => (v as List).map((e) => f(e as Json)).toList();

class AuthApi {
  static Future<OtpRequestResponse> requestOtp(Channel channel, String destination) async =>
      OtpRequestResponse(await Http.post('/api/auth/otp/request', {'channel': channel, 'destination': destination}));
  static Future<AuthResponse> verifyOtp(Channel channel, String destination, String code) async =>
      AuthResponse(await Http.post('/api/auth/otp/verify', {'channel': channel, 'destination': destination, 'code': code}));
  static Future<void> logout(String refreshToken) => Http.post('/api/auth/logout', {'refreshToken': refreshToken});
}

class ProfileUpdate {
  final String displayName;
  final int? birthYear;
  final String area;
  final String? city;
  final String? bio;
  final String? photoUrl;
  final bool sendPhotoUrl;
  final List<String> interests;
  final List<String> languages;
  final List<String> intents;
  const ProfileUpdate({
    required this.displayName,
    this.birthYear,
    required this.area,
    this.city,
    this.bio,
    this.photoUrl,
    this.sendPhotoUrl = false,
    required this.interests,
    required this.languages,
    required this.intents,
  });

  // Optional fields are left out (like `undefined` in JSON.stringify) unless set.
  Json toJson() => {
        'displayName': displayName,
        if (birthYear != null) 'birthYear': birthYear,
        'area': area,
        if (city != null) 'city': city,
        if (bio != null) 'bio': bio,
        if (sendPhotoUrl) 'photoUrl': photoUrl,
        'interests': interests,
        'languages': languages,
        'intents': intents,
      };
}

class MeApi {
  static Future<Me> get() async => Me(await Http.get('/api/me'));
  static Future<Me> update(ProfileUpdate body) async => Me(await Http.put('/api/me', body.toJson()));
  static Future<Me> updateName(String displayName) async => Me(await Http.put('/api/me/name', {'displayName': displayName}));
  static Future<Me> updatePrivacy(Json body) async => Me(await Http.put('/api/me/privacy', body));
  static Future<Me> completeOnboarding() async => Me(await Http.post('/api/me/onboarding-complete'));
  static Future<void> changePassword(String? currentPassword, String newPassword) =>
      Http.put('/api/me/password', {'currentPassword': currentPassword, 'newPassword': newPassword});
  static Future<OtpRequestResponse> startContactChange(Channel channel, String value) async =>
      OtpRequestResponse(await Http.post('/api/me/contact/start', {'channel': channel, 'value': value}));
  static Future<Me> confirmContactChange(Channel channel, String value, String code) async =>
      Me(await Http.post('/api/me/contact/confirm', {'channel': channel, 'value': value, 'code': code}));
  static Future<List<Session>> sessions() async => _list(await Http.get('/api/me/sessions'), Session.new);
  static Future<void> signOutSession(int id) => Http.del('/api/me/sessions/$id');
  static Future<void> signOutOthers() => Http.post('/api/me/sessions/sign-out-others');
  static Future<List<SecurityEvent>> securityEvents() async => _list(await Http.get('/api/me/security-events'), SecurityEvent.new);
  static Future<Me> deactivate() async => Me(await Http.post('/api/me/deactivate'));
  static Future<Me> reactivate() async => Me(await Http.post('/api/me/reactivate'));
  static Future<void> requestDeletion() => Http.post('/api/me/deletion');
  static Future<Me> cancelDeletion() async => Me(await Http.del('/api/me/deletion'));
  static Future<void> registerPushToken(String token, String platform) =>
      Http.post('/api/me/push-tokens', {'token': token, 'platform': platform});
}

class DiscoverApi {
  static Future<DiscoverResponse> home([String filter = 'all']) async =>
      DiscoverResponse(await Http.get('/api/discover${query({'filter': filter})}'));
  static Future<SearchResult> search(String q) async => SearchResult(await Http.get('/api/search${query({'q': q})}'));
}

class PlanRequest {
  final bool asOrganizer;
  final bool official;
  final String title;
  final String category;
  final String? description;
  final String area;
  final String? startAt;
  final String? endAt;
  final String locationMode;
  final String? meetingPoint;
  final int participantLimit;
  final String visibility;
  final String registrationMode;
  final String? registrationUrl;
  final List<ScheduleItem> schedule;
  final String? bring;
  final String? eligibility;
  final String? instructions;
  final bool draft;
  const PlanRequest({
    required this.asOrganizer,
    required this.official,
    required this.title,
    required this.category,
    this.description,
    required this.area,
    this.startAt,
    this.endAt,
    required this.locationMode,
    this.meetingPoint,
    required this.participantLimit,
    required this.visibility,
    required this.registrationMode,
    this.registrationUrl,
    required this.schedule,
    this.bring,
    this.eligibility,
    this.instructions,
    required this.draft,
  });

  Json toJson() => {
        'asOrganizer': asOrganizer,
        'official': official,
        'title': title,
        'category': category,
        if (description != null) 'description': description,
        'area': area,
        'startAt': startAt,
        'endAt': endAt,
        'locationMode': locationMode,
        if (meetingPoint != null) 'meetingPoint': meetingPoint,
        'participantLimit': participantLimit,
        'visibility': visibility,
        'registrationMode': registrationMode,
        if (registrationUrl != null) 'registrationUrl': registrationUrl,
        'schedule': schedule.map((s) => s.toJson()).toList(),
        if (bring != null) 'bring': bring,
        if (eligibility != null) 'eligibility': eligibility,
        if (instructions != null) 'instructions': instructions,
        'draft': draft,
      };
}

class PlansApi {
  static Future<MyPlans> mine() async => MyPlans(await Http.get('/api/plans/mine'));
  static Future<PlanDetail> get(int id) async => PlanDetail(await Http.get('/api/plans/$id'));
  static Future<PlanDetail> create(PlanRequest body) async => PlanDetail(await Http.post('/api/plans', body.toJson()));
  static Future<PlanDetail> updateDraft(int id, PlanRequest body) async => PlanDetail(await Http.put('/api/plans/$id', body.toJson()));
  static Future<PlanDetail> updateDetails(int id, Json body) async => PlanDetail(await Http.put('/api/plans/$id/details', body));
  static Future<PlanDetail> join(int id) async => PlanDetail(await Http.post('/api/plans/$id/join'));
  static Future<PlanDetail> leave(int id) async => PlanDetail(await Http.post('/api/plans/$id/leave'));
  static Future<PlanDetail> cancel(int id, String reason) async => PlanDetail(await Http.post('/api/plans/$id/cancel', {'reason': reason}));
  static Future<PlanDetail> complete(int id) async => PlanDetail(await Http.post('/api/plans/$id/complete'));
  static Future<void> remove(int id) => Http.del('/api/plans/$id');
  static Future<PlanDetail> removeParticipant(int id, int userId) async =>
      PlanDetail(await Http.del('/api/plans/$id/participants/$userId'));
  static Future<void> announce(int id, String title, String body) =>
      Http.post('/api/plans/$id/announcements', {'title': title, 'body': body});
}

class UsersApi {
  static Future<PublicProfile> get(int id) async => PublicProfile(await Http.get('/api/users/$id'));
}

class ConnectionsApi {
  static Future<List<Connection>> list() async => _list(await Http.get('/api/connections'), Connection.new);
  static Future<ConnectionRequest> request(int id) async => ConnectionRequest(await Http.get('/api/connections/requests/$id'));
  static Future<List<ConnectionRequest>> incoming() async => _list(await Http.get('/api/connections/requests'), ConnectionRequest.new);
  static Future<ConnectionRequest> send(int userId, [int? planId, String? note]) async => ConnectionRequest(
      await Http.post('/api/connections/requests', {'userId': userId, 'planId': planId, 'note': ?note}));
  static Future<ConnectionRequest> accept(int id) async => ConnectionRequest(await Http.post('/api/connections/requests/$id/accept'));
  static Future<ConnectionRequest> decline(int id) async => ConnectionRequest(await Http.post('/api/connections/requests/$id/decline'));
  static Future<ConnectionRequest> cancel(int id) async => ConnectionRequest(await Http.post('/api/connections/requests/$id/cancel'));
  static Future<void> remove(int userId) => Http.del('/api/connections/$userId');
}

class ChatApi {
  static Future<List<ConversationSummary>> list() async => _list(await Http.get('/api/conversations'), ConversationSummary.new);
  static Future<ConversationDetail> get(int id) async => ConversationDetail(await Http.get('/api/conversations/$id'));
  static Future<ConversationSummary> openDirect(int userId) async =>
      ConversationSummary(await Http.post('/api/conversations/direct', {'userId': userId}));
  static Future<List<Message>> messages(int id, [int? before]) async =>
      _list(await Http.get('/api/conversations/$id/messages${query({'before': before})}'), Message.new);
  static Future<Message> send(int id, String text, String clientId) async =>
      Message(await Http.post('/api/conversations/$id/messages', {'text': text, 'clientId': clientId}));
  static Future<void> markRead(int id) => Http.post('/api/conversations/$id/read');
  static Future<void> mute(int id, bool muted) => Http.post('/api/conversations/$id/mute', {'muted': muted});
}

class NotificationsApi {
  static Future<List<AppNotification>> list() async => _list(await Http.get('/api/notifications'), AppNotification.new);
  static Future<void> markRead(int id, [bool read = true]) => Http.post('/api/notifications/$id/read', {'read': read});
  static Future<void> markAllRead() => Http.post('/api/notifications/read-all');
  static Future<NotificationPrefs> prefs() async => NotificationPrefs(await Http.get('/api/notifications/preferences'));
  static Future<NotificationPrefs> updatePrefs(Json p) async => NotificationPrefs(await Http.put('/api/notifications/preferences', p));
}

class SafetyApi {
  static Future<Report> report({
    required ReportTarget targetType,
    int? targetId,
    required String reason,
    String? details,
    int? blockUserId,
  }) async =>
      Report(await Http.post('/api/reports', {
        'targetType': targetType,
        'targetId': targetId,
        'reason': reason,
        'details': ?details,
        'blockUserId': blockUserId,
      }));
  static Future<List<Report>> reports() async => _list(await Http.get('/api/reports'), Report.new);
  static Future<Report> reportDetail(int id) async => Report(await Http.get('/api/reports/$id'));
  static Future<void> block(int userId) => Http.post('/api/blocks', {'userId': userId});
  static Future<void> unblock(int userId) => Http.del('/api/blocks/$userId');
  static Future<List<BlockedUser>> blocked() async => _list(await Http.get('/api/blocks'), BlockedUser.new);
}

class VerificationApi {
  static Future<VerificationState> state() async => VerificationState(await Http.get('/api/verification'));
  static Future<({String sessionId, String? providerUrl})> startIdentity() async {
    final j = await Http.post('/api/verification/identity/sessions') as Json;
    return (sessionId: j['sessionId'].toString(), providerUrl: j['providerUrl'] as String?);
  }

  static Future<VerificationState> submitIdentity(String sessionId) async =>
      VerificationState(await Http.post('/api/verification/identity/sessions/$sessionId/submit'));
  static Future<OtpRequestResponse> sendPhoneCode() async => OtpRequestResponse(await Http.post('/api/verification/phone/send'));
  static Future<VerificationState> verifyPhone(String code) async =>
      VerificationState(await Http.post('/api/verification/phone/verify', {'code': code}));
  static Future<VerificationState> sendEmailLink([String? email]) async =>
      VerificationState(await Http.post('/api/verification/email/send', {'email': ?email}));
}

class OrganizerSetup {
  final String type;
  final String name;
  final String about;
  final String area;
  final String? website;
  final String? contactEmail;
  const OrganizerSetup({required this.type, required this.name, required this.about, required this.area, this.website, this.contactEmail});
  Json toJson() => {
        'type': type,
        'name': name,
        'about': about,
        'area': area,
        if (website != null) 'website': website,
        if (contactEmail != null) 'contactEmail': contactEmail,
      };
}

class OrganizersApi {
  static Future<OrganizerProfile> get(int id) async => OrganizerProfile(await Http.get('/api/organizers/$id'));
  static Future<OrganizerProfile> apply(OrganizerSetup body) async => OrganizerProfile(await Http.post('/api/organizers', body.toJson()));
}

/// Off until the person opts in (privacy choices). The server also drops events without consent.
bool _analyticsAllowed = false;
void setAnalyticsAllowed(bool v) => _analyticsAllowed = v;

class AnalyticsApi {
  static Future<void> track(String name, [Map<String, Object> properties = const {}]) async {
    if (!_analyticsAllowed) return;
    try {
      await Http.post('/api/analytics', {'name': name, 'properties': properties});
    } catch (_) {}
  }
}

class PrivacyApi {
  static Future<Consents> consents() async => Consents(await Http.get('/api/me/consents'));
  static Future<Consents> saveConsents({required bool analytics, required bool offers, required bool marketingEmails, String? source}) async =>
      Consents(await Http.put('/api/me/consents', {
        'analytics': analytics,
        'offers': offers,
        'marketingEmails': marketingEmails,
        'source': ?source,
      }));
  static Future<void> recordSignup() => Http.post('/api/me/consents/signup');
  static Future<Json> exportData() async => (await Http.get('/api/me/export')) as Json;
  static Future<void> deleteUnderage() => Http.post('/api/me/underage');
}

class ContentApi {
  static Future<ContentPage> page(String slug) async => ContentPage(await Http.get('/api/content/pages/${Uri.encodeComponent(slug)}'));
}

class ConfigApi {
  static Future<AppConfig> get() async => AppConfig(await Http.get('/api/config'));
}

class CategoriesApi {
  static Future<List<Category>> list() async => _list(await Http.get('/api/categories'), Category.new);
}

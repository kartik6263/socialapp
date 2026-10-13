// Mirrors the DTOs exposed by the Spring Boot backend (backend/src/main/java/com/plans/**/dto).
// Union types from the server stay as Strings (e.g. 'VERIFIED'), exactly as the server sends them.
// Every model keeps its source JSON so `copyWith` can patch fields the same way `{ ...obj, field }` did.

typedef Json = Map<String, dynamic>;

List<T> _list<T>(Object? v, T Function(Json) f) => (v as List? ?? const []).map((e) => f(e as Json)).toList();
List<String> _strings(Object? v) => (v as List? ?? const []).map((e) => e.toString()).toList();
int? _int(Object? v) => v == null ? null : (v as num).toInt();
T? _opt<T>(Object? v, T Function(Json) f) => v == null ? null : f(v as Json);

abstract class Model {
  final Json json;
  const Model(this.json);
}

// ---------- Trust ----------

/// Factual trust signals. Never scores, ratings or rankings.
/// 'IDENTITY' | 'ORGANIZER' | 'OFFICIAL' | 'PHONE' | 'EMAIL'
typedef Signal = String;
const signalOrder = ['IDENTITY', 'ORGANIZER', 'OFFICIAL', 'PHONE', 'EMAIL'];

class StatusMasked {
  final String status;
  final String? masked;
  final String? expiresAt;
  StatusMasked(Json j)
      : status = j['status'] as String,
        masked = j['masked'] as String?,
        expiresAt = j['expiresAt'] as String?;
}

class OrganizerVerification {
  final String status;
  final int? organizerId;
  final String? name;
  OrganizerVerification(Json j)
      : status = j['status'] as String,
        organizerId = _int(j['organizerId']),
        name = j['name'] as String?;
}

class VerificationState extends Model {
  final StatusMasked identity;
  final StatusMasked phone;
  final StatusMasked email;
  final OrganizerVerification organizer;
  VerificationState(super.json)
      : identity = StatusMasked(json['identity'] as Json),
        phone = StatusMasked(json['phone'] as Json),
        email = StatusMasked(json['email'] as Json),
        organizer = OrganizerVerification(json['organizer'] as Json);
}

// ---------- People ----------

class IntentOption {
  final String value;
  final String label;
  const IntentOption(this.value, this.label);
}

const intents = [
  IntentOption('FRIENDS', 'Friends'),
  IntentOption('ACTIVITY_PARTNERS', 'Activity partners'),
  IntentOption('TRAVEL_COMPANIONS', 'Travel companions'),
  IntentOption('NETWORKING', 'Networking'),
  IntentOption('OPEN_TO_MEETING', 'Open to meeting people'),
  IntentOption('DATING', 'Dating'),
];

const interestsList = [
  'Travel', 'Trekking', 'Live music', 'Photography', 'Startups', 'Technology', 'Hackathons', 'Sports',
  'Football', 'Cycling', 'Fitness', 'College events', 'Networking', 'Movies', 'Cafés', 'Design', 'Gaming', 'Food',
];

class UserSummary extends Model {
  final int id;
  final String displayName;
  final String? photoUrl;
  final String? area;
  final List<Signal> signals;
  final bool signalsUnavailable;
  UserSummary(super.json)
      : id = _int(json['id'])!,
        displayName = json['displayName'] as String,
        photoUrl = json['photoUrl'] as String?,
        area = json['area'] as String?,
        signals = _strings(json['signals']),
        signalsUnavailable = json['signalsUnavailable'] == true;
}

class PrivacySettings extends Model {
  final String profileVisibility;
  final String areaLevel;
  final String defaultPlanVisibility;
  final String planLocation;
  final String connectionRequests;
  final String messages;
  final String language;
  final bool showAge, showArea, showIntent, showInterests, showPlans;
  final bool discoverPeople, discoverParticipants, discoverDestination, discoverSearch;
  PrivacySettings(super.json)
      : profileVisibility = json['profileVisibility'] as String,
        areaLevel = json['areaLevel'] as String,
        defaultPlanVisibility = json['defaultPlanVisibility'] as String,
        planLocation = json['planLocation'] as String,
        connectionRequests = json['connectionRequests'] as String,
        messages = json['messages'] as String,
        language = (json['language'] as String?) ?? 'en',
        showAge = json['showAge'] == true,
        showArea = json['showArea'] == true,
        showIntent = json['showIntent'] == true,
        showInterests = json['showInterests'] == true,
        showPlans = json['showPlans'] == true,
        discoverPeople = json['discoverPeople'] == true,
        discoverParticipants = json['discoverParticipants'] == true,
        discoverDestination = json['discoverDestination'] == true,
        discoverSearch = json['discoverSearch'] == true;

  /// Value by key, for the generic choice screen.
  Object? operator [](String key) => json[key];
  PrivacySettings copyWith(Json patch) => PrivacySettings({...json, ...patch});
}

class Completeness {
  final int percent, done, total;
  final String? hint;
  Completeness(Json j)
      : percent = _int(j['percent'])!,
        done = _int(j['done'])!,
        total = _int(j['total'])!,
        hint = j['hint'] as String?;
}

class Me extends UserSummary {
  final String? ageRange;
  final String? bio;
  final String? city;
  final List<String> interests;
  final List<String> languages;
  final List<String> intents;
  final String? maskedPhone;
  final String? maskedEmail;
  final bool onboarded;
  final String accountStatus;
  final String role;
  final PrivacySettings privacy;
  final Completeness completeness;
  final OrganizerSummary? organizer;
  final bool hasPassword;
  final String? passwordChangedAt;
  final String memberSince;
  final int unreadNotifications;
  final int unreadConversations;
  Me(super.json)
      : ageRange = json['ageRange'] as String?,
        bio = json['bio'] as String?,
        city = json['city'] as String?,
        interests = _strings(json['interests']),
        languages = _strings(json['languages']),
        intents = _strings(json['intents']),
        maskedPhone = json['maskedPhone'] as String?,
        maskedEmail = json['maskedEmail'] as String?,
        onboarded = json['onboarded'] == true,
        accountStatus = json['accountStatus'] as String,
        role = (json['role'] as String?) ?? 'USER',
        privacy = PrivacySettings(json['privacy'] as Json),
        completeness = Completeness(json['completeness'] as Json),
        organizer = _opt(json['organizer'], OrganizerSummary.new),
        hasPassword = json['hasPassword'] == true,
        passwordChangedAt = json['passwordChangedAt'] as String?,
        memberSince = json['memberSince'] as String,
        unreadNotifications = _int(json['unreadNotifications']) ?? 0,
        unreadConversations = _int(json['unreadConversations']) ?? 0;

  Me copyWith(Json patch) => Me({...json, ...patch});
}

class SharedPlanRef {
  final int id;
  final String title;
  final String when;
  final String label; // e.g. "YOU’RE BOTH JOINING"
  SharedPlanRef(Json j)
      : id = _int(j['id'])!,
        title = j['title'] as String,
        when = j['when'] as String,
        label = j['label'] as String;
}

class PublicProfile extends UserSummary {
  final String firstName;
  final String? ageRange;
  final List<String> intents;
  final String? bio;
  final List<String> interests;
  final List<String> sharedInterests;
  final List<String> mutualConnections;
  final SharedPlanRef? sharedPlan;
  final String connectionStatus; // NONE | PENDING_OUTGOING | PENDING_INCOMING | ACCEPTED | BLOCKED
  final int? connectionId;
  final bool blockedByMe;
  final bool canMessage;
  final bool canConnect;
  final String availability; // AVAILABLE | RESTRICTED | SUSPENDED | DELETED
  PublicProfile(super.json)
      : firstName = json['firstName'] as String,
        ageRange = json['ageRange'] as String?,
        intents = _strings(json['intents']),
        bio = json['bio'] as String?,
        interests = _strings(json['interests']),
        sharedInterests = _strings(json['sharedInterests']),
        mutualConnections = _strings(json['mutualConnections']),
        sharedPlan = _opt(json['sharedPlan'], SharedPlanRef.new),
        connectionStatus = json['connectionStatus'] as String,
        connectionId = _int(json['connectionId']),
        blockedByMe = json['blockedByMe'] == true,
        canMessage = json['canMessage'] == true,
        canConnect = json['canConnect'] == true,
        availability = json['availability'] as String;

  PublicProfile copyWith(Json patch) => PublicProfile({...json, ...patch});
}

class PersonCard {
  final UserSummary user;
  final String? bio;
  final String context;
  final List<String> sharedInterests;
  PersonCard(Json j)
      : user = UserSummary(j['user'] as Json),
        bio = j['bio'] as String?,
        context = j['context'] as String,
        sharedInterests = _strings(j['sharedInterests']);
}

class OrganizerSummary extends Model {
  final int id;
  final String name;
  final String type; // INDIVIDUAL | COMMUNITY | ORGANIZATION | OFFICIAL
  final String status;
  final List<Signal> signals;
  final int upcomingCount;
  OrganizerSummary(super.json)
      : id = _int(json['id'])!,
        name = json['name'] as String,
        type = json['type'] as String,
        status = json['status'] as String,
        signals = _strings(json['signals']),
        upcomingCount = _int(json['upcomingCount']) ?? 0;
}

class OrganizerProfile extends OrganizerSummary {
  final String? about;
  final String? area;
  final String? website;
  final String since;
  final bool mine;
  final bool available;
  final List<PlanSummary> upcoming;
  final List<PlanSummary> past;
  OrganizerProfile(super.json)
      : about = json['about'] as String?,
        area = json['area'] as String?,
        website = json['website'] as String?,
        since = json['since'] as String,
        mine = json['mine'] == true,
        available = json['available'] == true,
        upcoming = _list(json['upcoming'], PlanSummary.new),
        past = _list(json['past'], PlanSummary.new);
}

// ---------- Plans ----------

const categoriesList = [
  'Travel', 'Trek', 'Photography', 'Concert', 'Event', 'Sports', 'Gaming', 'College', 'Hackathon',
  'Networking', 'Food', 'Movie', 'Other',
];

class Host {
  final String kind; // USER | ORGANIZER
  final int id;
  final String name;
  final String? photoUrl;
  final List<Signal> signals;
  final String subtitle; // "Creator" / "Community organizer"
  Host(Json j)
      : kind = j['kind'] as String,
        id = _int(j['id'])!,
        name = j['name'] as String,
        photoUrl = j['photoUrl'] as String?,
        signals = _strings(j['signals']),
        subtitle = (j['subtitle'] as String?) ?? '';
}

class PlanSummary extends Model {
  final int id;
  final String title;
  final String category;
  final String area;
  final String? startAt;
  final String? endAt;
  final int participantCount;
  final int participantLimit;
  final String status; // DRAFT | ACTIVE | FULL | UPDATED | CANCELLED | COMPLETED
  final bool official;
  final String? coverImageUrl;
  final Host host;
  final String? why;
  final bool joined;
  final bool owner;
  PlanSummary(super.json)
      : id = _int(json['id'])!,
        title = json['title'] as String,
        category = json['category'] as String,
        area = json['area'] as String,
        startAt = json['startAt'] as String?,
        endAt = json['endAt'] as String?,
        participantCount = _int(json['participantCount']) ?? 0,
        participantLimit = _int(json['participantLimit']) ?? 0,
        status = json['status'] as String,
        official = json['official'] == true,
        coverImageUrl = json['coverImageUrl'] as String?,
        host = Host(json['host'] as Json),
        why = json['why'] as String?,
        joined = json['joined'] == true,
        owner = json['owner'] == true;
}

class FieldChange {
  final String field;
  final String label;
  final String from;
  final String to;
  FieldChange(Json j)
      : field = (j['field'] as String?) ?? '',
        label = j['label'] as String,
        from = j['from'] as String,
        to = j['to'] as String;
  FieldChange.of(this.label, this.from, this.to, {this.field = ''});
}

class PlanMember {
  final UserSummary user;
  final String role; // CREATOR | ORGANIZER | PARTICIPANT
  final bool me;
  PlanMember(Json j)
      : user = UserSummary(j['user'] as Json),
        role = j['role'] as String,
        me = j['me'] == true;
}

class ScheduleItem {
  final String time;
  final String what;
  ScheduleItem(Json j)
      : time = (j['time'] as String?) ?? '',
        what = (j['what'] as String?) ?? '';
  const ScheduleItem.of(this.time, this.what);
  Json toJson() => {'time': time, 'what': what};
}

class LatestChange {
  final String by;
  final String at;
  final List<FieldChange> changes;
  LatestChange(Json j)
      : by = j['by'] as String,
        at = j['at'] as String,
        changes = _list(j['changes'], FieldChange.new);
}

class PlanDetail extends PlanSummary {
  final String? description;
  final String? meetingPoint;
  final bool meetingPointHidden;
  final String locationMode; // APPROXIMATE | PUBLIC_VENUE | OFFICIAL_VENUE
  final String visibility; // DISCOVERABLE | SHARED_CONTEXT | PRIVATE
  final String registrationMode; // APP | EXTERNAL
  final String? registrationUrl;
  final List<ScheduleItem> schedule;
  final String? bring;
  final String? eligibility;
  final String? instructions;
  final List<PlanMember> members;
  final int? groupConversationId;
  final LatestChange? latestChange;
  final String? cancelReason;

  /// Only returned to members; lets them share private Plans by link.
  final String? shareCode;
  final String createdAt;
  final String updatedAt;
  PlanDetail(super.json)
      : description = json['description'] as String?,
        meetingPoint = json['meetingPoint'] as String?,
        meetingPointHidden = json['meetingPointHidden'] == true,
        locationMode = json['locationMode'] as String,
        visibility = json['visibility'] as String,
        registrationMode = (json['registrationMode'] as String?) ?? 'APP',
        registrationUrl = json['registrationUrl'] as String?,
        schedule = _list(json['schedule'], ScheduleItem.new),
        bring = json['bring'] as String?,
        eligibility = json['eligibility'] as String?,
        instructions = json['instructions'] as String?,
        members = _list(json['members'], PlanMember.new),
        groupConversationId = _int(json['groupConversationId']),
        latestChange = _opt(json['latestChange'], LatestChange.new),
        cancelReason = json['cancelReason'] as String?,
        shareCode = json['shareCode'] as String?,
        createdAt = (json['createdAt'] as String?) ?? '',
        updatedAt = (json['updatedAt'] as String?) ?? '';
}

class DiscoverResponse {
  final List<PlanSummary> plans;
  final List<PersonCard> people;
  final OrganizerSummary? organizerNearby;
  final bool hiddenFromPeople;
  DiscoverResponse(Json j)
      : plans = _list(j['plans'], PlanSummary.new),
        people = _list(j['people'], PersonCard.new),
        organizerNearby = _opt(j['organizerNearby'], OrganizerSummary.new),
        hiddenFromPeople = j['hiddenFromPeople'] == true;
}

class SearchResult {
  final List<PlanSummary> plans;
  final List<PersonCard> people;
  SearchResult(Json j)
      : plans = _list(j['plans'], PlanSummary.new),
        people = _list(j['people'], PersonCard.new);
}

class MyPlans {
  final List<PlanSummary> upcoming, hosting, drafts, past;
  MyPlans(Json j)
      : upcoming = _list(j['upcoming'], PlanSummary.new),
        hosting = _list(j['hosting'], PlanSummary.new),
        drafts = _list(j['drafts'], PlanSummary.new),
        past = _list(j['past'], PlanSummary.new);
}

// ---------- Connections ----------

class ConnectionRequest {
  final int id;
  final UserSummary from;
  final String? ageRange;
  final List<String> intents;
  final String? note;
  final SharedPlanRef? sharedPlan;
  final List<String> sharedInterests;
  final String status; // PENDING | ACCEPTED | DECLINED | CANCELLED
  final String createdAt;
  ConnectionRequest(Json j)
      : id = _int(j['id'])!,
        from = UserSummary(j['from'] as Json),
        ageRange = j['ageRange'] as String?,
        intents = _strings(j['intents']),
        note = j['note'] as String?,
        sharedPlan = _opt(j['sharedPlan'], SharedPlanRef.new),
        sharedInterests = _strings(j['sharedInterests']),
        status = j['status'] as String,
        createdAt = j['createdAt'] as String;
}

class Connection {
  final int id;
  final UserSummary user;
  final String context;
  final String connectedAt;
  Connection(Json j)
      : id = _int(j['id'])!,
        user = UserSummary(j['user'] as Json),
        context = (j['context'] as String?) ?? '',
        connectedAt = j['connectedAt'] as String;
}

// ---------- Chat ----------

class Message extends Model {
  final int id;
  final int conversationId;
  final UserSummary? sender;
  final bool mine;
  final bool system;
  final bool removed;
  final String text;
  final String createdAt;
  Message(super.json)
      : id = _int(json['id'])!,
        conversationId = _int(json['conversationId']) ?? 0,
        sender = _opt(json['sender'], UserSummary.new),
        mine = json['mine'] == true,
        system = json['system'] == true,
        removed = json['removed'] == true,
        text = (json['text'] as String?) ?? '',
        createdAt = json['createdAt'] as String;
}

class Announcement {
  final String title, body, by, at;
  Announcement(Json j)
      : title = j['title'] as String,
        body = j['body'] as String,
        by = j['by'] as String,
        at = j['at'] as String;
}

class ConversationSummary extends Model {
  final int id;
  final String type; // DIRECT | GROUP
  final String title;
  final String? context;
  final int? planId;
  final UserSummary? otherUser;
  final Message? lastMessage;
  final int unread;
  final bool muted;
  ConversationSummary(super.json)
      : id = _int(json['id'])!,
        type = json['type'] as String,
        title = json['title'] as String,
        context = json['context'] as String?,
        planId = _int(json['planId']),
        otherUser = _opt(json['otherUser'], UserSummary.new),
        lastMessage = _opt(json['lastMessage'], Message.new),
        unread = _int(json['unread']) ?? 0,
        muted = json['muted'] == true;
}

class ConversationDetail extends ConversationSummary {
  final String? planTitle;
  final String? planLine;
  final bool official;
  final bool archived;
  final String? archivedReason;
  final Announcement? announcement;
  final List<PlanMember> members;
  final bool canSend;
  final bool blockedByMe;
  final int? firstUnreadMessageId;
  ConversationDetail(super.json)
      : planTitle = json['planTitle'] as String?,
        planLine = json['planLine'] as String?,
        official = json['official'] == true,
        archived = json['archived'] == true,
        archivedReason = json['archivedReason'] as String?,
        announcement = _opt(json['announcement'], Announcement.new),
        members = _list(json['members'], PlanMember.new),
        canSend = json['canSend'] == true,
        blockedByMe = json['blockedByMe'] == true,
        firstUnreadMessageId = _int(json['firstUnreadMessageId']);

  ConversationDetail copyWith(Json patch) => ConversationDetail({...json, ...patch});
}

// ---------- Notifications ----------

class Destination {
  final String kind; // PLAN | CHAT | REQUEST | GROUP | PROFILE | SECURITY | REPORT | VERIFY | UNAVAILABLE
  final int? id;
  final String? mode;
  final String? reason;
  const Destination(this.kind, {this.id, this.mode, this.reason});
  Destination.fromJson(Json j)
      : kind = j['kind'] as String,
        id = _int(j['id']),
        mode = j['mode'] as String?,
        reason = j['reason'] as String?;
}

class AppNotification extends Model {
  final int id;
  final String category; // PLANS | PEOPLE | SAFETY
  final String type;
  final String priority; // HIGH | NORMAL | LOW
  final String icon;
  final UserSummary? actor;
  final String title;
  final String? body;
  final String? quote;
  final String? context;
  final List<FieldChange> diff;
  final String cta;
  final Destination destination;
  final bool read;
  final String createdAt;
  AppNotification(super.json)
      : id = _int(json['id'])!,
        category = json['category'] as String,
        type = (json['type'] as String?) ?? '',
        priority = (json['priority'] as String?) ?? 'NORMAL',
        icon = (json['icon'] as String?) ?? '',
        actor = _opt(json['actor'], UserSummary.new),
        title = json['title'] as String,
        body = json['body'] as String?,
        quote = json['quote'] as String?,
        context = json['context'] as String?,
        diff = _list(json['diff'], FieldChange.new),
        cta = (json['cta'] as String?) ?? '',
        destination = Destination.fromJson(json['destination'] as Json),
        read = json['read'] == true,
        createdAt = json['createdAt'] as String;

  AppNotification copyWith(Json patch) => AppNotification({...json, ...patch});
}

class NotificationPrefs extends Model {
  NotificationPrefs(super.json);
  bool operator [](String key) => json[key] == true;
  bool get push => this['push'];
  bool get remindDayBefore => this['remindDayBefore'];
  bool get remindHourBefore => this['remindHourBefore'];
  NotificationPrefs copyWith(Json patch) => NotificationPrefs({...json, ...patch});
}

// ---------- Safety ----------

/// 'PROFILE' | 'PARTICIPANT' | 'MESSAGE' | 'CONVERSATION' | 'PLAN' | 'GROUP' | 'ORGANIZER' | 'EVENT' | 'PROBLEM'
typedef ReportTarget = String;

class Report {
  final int id;
  final ReportTarget targetType;
  final int? targetId;
  final String targetLabel;
  final int? personId;
  final String? personName;
  final String reason;
  final String? details;
  final String status; // SUBMITTED | UNDER_REVIEW | ACTION_TAKEN | NO_ACTION | CLOSED
  final String submittedAt;
  final String updatedAt;
  final bool unseenUpdate;
  Report(Json j)
      : id = _int(j['id'])!,
        targetType = j['targetType'] as String,
        targetId = _int(j['targetId']),
        targetLabel = (j['targetLabel'] as String?) ?? '',
        personId = _int(j['personId']),
        personName = j['personName'] as String?,
        reason = j['reason'] as String,
        details = j['details'] as String?,
        status = j['status'] as String,
        submittedAt = j['submittedAt'] as String,
        updatedAt = j['updatedAt'] as String,
        unseenUpdate = j['unseenUpdate'] == true;
}

class BlockedUser {
  final UserSummary user;
  final String? context;
  final String blockedAt;
  BlockedUser(Json j)
      : user = UserSummary(j['user'] as Json),
        context = j['context'] as String?,
        blockedAt = j['blockedAt'] as String;
}

// ---------- Account ----------

class Session {
  final int id;
  final String deviceName;
  final String platform; // ANDROID | IOS | WEB
  final String app;
  final String? area;
  final String lastActiveAt;
  final bool current;
  Session(Json j)
      : id = _int(j['id'])!,
        deviceName = j['deviceName'] as String,
        platform = j['platform'] as String,
        app = (j['app'] as String?) ?? '',
        area = j['area'] as String?,
        lastActiveAt = j['lastActiveAt'] as String,
        current = j['current'] == true;
}

class SecurityEvent {
  final int id;
  final String title;
  final String? deviceName;
  final String? area;
  final String createdAt;
  SecurityEvent(Json j)
      : id = _int(j['id'])!,
        title = j['title'] as String,
        deviceName = j['deviceName'] as String?,
        area = j['area'] as String?,
        createdAt = j['createdAt'] as String;
}

class AuthResponse {
  final String accessToken;
  final String refreshToken;
  final Me user;
  final bool newUser;
  AuthResponse(Json j)
      : accessToken = j['accessToken'] as String,
        refreshToken = j['refreshToken'] as String,
        user = Me(j['user'] as Json),
        newUser = j['newUser'] == true;
}

class OtpRequestResponse {
  final int expiresInSeconds;
  final int resendInSeconds;
  final String? devCode;
  OtpRequestResponse(Json j)
      : expiresInSeconds = _int(j['expiresInSeconds']) ?? 0,
        resendInSeconds = _int(j['resendInSeconds']) ?? 0,
        devCode = j['devCode'] as String?;
}

class ConsentRow {
  final String kind;
  final bool granted;
  final String version;
  final String source;
  final String at;
  ConsentRow(Json j)
      : kind = j['kind'] as String,
        granted = j['granted'] == true,
        version = (j['version'] ?? '').toString(),
        source = (j['source'] as String?) ?? '',
        at = j['at'] as String;
}

class Consents {
  final bool analytics, offers, marketingEmails, decided;
  final String policyVersion;
  final List<ConsentRow> history;
  Consents(Json j)
      : analytics = j['analytics'] == true,
        offers = j['offers'] == true,
        marketingEmails = j['marketingEmails'] == true,
        decided = j['decided'] == true,
        policyVersion = (j['policyVersion'] ?? '').toString(),
        history = _list(j['history'], ConsentRow.new);
  Consents._(this.analytics, this.offers, this.marketingEmails, this.decided, this.policyVersion, this.history);
  Consents copyWith({bool? analytics, bool? offers, bool? marketingEmails}) => Consents._(
      analytics ?? this.analytics, offers ?? this.offers, marketingEmails ?? this.marketingEmails, decided, policyVersion, history);
}

class ContentPage {
  final int id;
  final String slug, title, body, updatedAt;
  final bool published;
  ContentPage(Json j)
      : id = _int(j['id']) ?? 0,
        slug = j['slug'] as String,
        title = j['title'] as String,
        body = (j['body'] as String?) ?? '',
        published = j['published'] == true,
        updatedAt = j['updatedAt'] as String;
}

class Category {
  final int id;
  final String name;
  final String? labelHi;
  final String? labelKn;
  Category(Json j)
      : id = _int(j['id'])!,
        name = j['name'] as String,
        labelHi = j['labelHi'] as String?,
        labelKn = j['labelKn'] as String?;
  const Category.local(this.id, this.name)
      : labelHi = null,
        labelKn = null;
}

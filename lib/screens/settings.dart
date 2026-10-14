import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart' hide Card, Chip, Switch, Banner;
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../api/api.dart';
import '../api/client.dart' show appVersionString;
import '../i18n/i18n.dart';
import '../nav.dart';
import '../state/auth.dart';
import '../state/focus_data.dart';
import '../state/toast.dart';
import '../util/format.dart';
import '../util/misc.dart';
import '../widgets/parts.dart';
import '../widgets/sheet.dart';
import '../widgets/ui.dart';

/// Optimistic privacy updates with the prototype's offline/server-error banner semantics (useSavePrivacy).
mixin SavePrivacy<W extends StatefulWidget> on State<W> {
  SaveError? saveError;

  Future<bool> savePrivacy(Map<String, dynamic> patch, [String? message]) async {
    final auth = authOf(context);
    final toast = useToast(context);
    final previous = auth.user!;
    auth.setUser(previous.copyWith({'privacy': {...previous.privacy.json, ...patch}}));
    setState(() => saveError = null);
    try {
      auth.setUser(await MeApi.updatePrivacy(patch));
      if (message != null) toast(message);
      return true;
    } catch (e) {
      auth.setUser(previous);
      if (mounted) {
        setState(() => saveError = SaveError(offline: e is ApiError && e.isNetwork, retry: () => savePrivacy(patch, message)));
      }
      return false;
    }
  }
}

// ---------- Settings home ----------

class SettingsHomeScreen extends StatelessWidget {
  const SettingsHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    useLanguage(context);
    final me = useMe(context);
    final auth = authOf(context);
    final verified = me.signals.where((s) => s != 'OFFICIAL').map((s) => signalLabel(s).replaceAll(' verified', '')).toList();

    return Screen(children: [
      Header(kicker: me.displayName.toUpperCase(), title: tr('Settings')),
      if (me.accountStatus == 'RESTRICTED')
        GestureDetector(
          onTap: () => Nav.push('/settings/restricted'),
          child: Banner(
            icon: 'lock',
            tone: PillTone.warn,
            title: tr('Some features are limited'),
            body: tr('See what’s affected on your account.'),
            action: tr('View'),
            onAction: () => Nav.push('/settings/restricted'),
          ),
        ),
      SectionTitle(tr('Account')),
      Group([
        ListRow(first: true, icon: 'user', label: tr('Profile'), sub: tr('How others see you'), onPress: () => Nav.push('/me')),
        ListRow(icon: 'settings', label: tr('Account information'), sub: tr('Name, email, phone'), onPress: () => Nav.push('/settings/account')),
        ListRow(icon: 'shield', label: tr('Verification'), value: verified.isNotEmpty ? verified.join(', ') : tr('Not started'), onPress: () => Nav.push('/verify')),
      ]),
      SectionTitle(tr('Privacy')),
      Group([
        ListRow(first: true, icon: 'eye', label: tr('Privacy'), sub: tr('Visibility, location, discovery and contact'), onPress: () => Nav.push('/settings/privacy')),
        ListRow(icon: 'download', label: tr('Your data'), sub: tr('Download a copy, consent choices, deletion'), onPress: () => Nav.push('/settings/data')),
      ]),
      SectionTitle(tr('Notifications')),
      Group([ListRow(first: true, icon: 'bell', label: tr('Notification preferences'), sub: tr('Push and in-app'), onPress: () => Nav.push('/notifications/settings'))]),
      SectionTitle(tr('Safety')),
      Group([
        ListRow(first: true, icon: 'shield', label: tr('Safety Center'), sub: tr('Tools, guidelines and help'), onPress: () => Nav.push('/safety')),
        ListRow(icon: 'lock', label: tr('Blocked people'), onPress: () => Nav.push('/safety/blocked')),
        ListRow(icon: 'flag', label: tr('Your reports'), onPress: () => Nav.push('/safety/reports')),
      ]),
      SectionTitle(tr('Organizer')),
      Group([
        if (me.organizer != null)
          ListRow(
            first: true,
            icon: 'users',
            label: me.organizer!.name,
            sub: tr('Organizer profile'),
            value: me.organizer!.status == 'VERIFIED' ? tr('Verified') : tr('In progress'),
            onPress: () => Nav.push(me.organizer!.status == 'VERIFIED' ? '/organizer/${me.organizer!.id}' : '/verify/organizer'),
          )
        else
          ListRow(first: true, icon: 'users', label: tr('Become an organizer'), sub: tr('For community and official events'), onPress: () => Nav.push('/organizer/setup')),
      ]),
      SectionTitle(tr('Security')),
      Group([
        ListRow(first: true, icon: 'key', label: tr('Security'), sub: tr('Password, sign-in and activity'), onPress: () => Nav.push('/settings/security')),
        ListRow(icon: 'smartphone', label: tr('Active sessions'), onPress: () => Nav.push('/settings/sessions')),
      ]),
      SectionTitle(tr('Preferences')),
      Group([
        ListRow(first: true, icon: 'globe', label: tr('Language'), value: shortChoice('language', me.privacy), onPress: () => Nav.push('/settings/choice/language')),
        ListRow(icon: 'eye', label: tr('Accessibility'), sub: tr('Follows your device’s text size and reduced-motion settings.'), onPress: () => Nav.push('/legal/accessibility')),
      ]),
      SectionTitle(tr('Help')),
      Group([
        ListRow(first: true, icon: 'message-circle', label: tr('Help & support'), sub: tr('Report a problem or contact us'), onPress: () => Nav.push('/help')),
        ListRow(icon: 'flag', label: tr('Community guidelines'), onPress: () => Nav.push('/safety/guidelines')),
        ListRow(icon: 'file-text', label: tr('Legal & privacy'), sub: tr('Terms, privacy, refunds, cookies and licences'), onPress: () => Nav.push('/legal')),
        ListRow(icon: 'briefcase', label: tr('About Plans'), sub: tr('Business details and Grievance Officer'), value: 'v$appVersionString', onPress: () => Nav.push('/legal/business')),
      ]),
      SectionTitle(tr('Account lifecycle'), danger: true),
      Group(danger: true, [
        ListRow(first: true, icon: 'trash-2', danger: true, label: tr('Deactivate or delete account'), sub: tr('Temporary or permanent — you choose'), onPress: () => Nav.push('/settings/lifecycle')),
      ]),
      Group(margin: const EdgeInsets.only(top: 16), [
        ListRow(
          first: true,
          icon: 'log-out',
          label: tr('Sign out'),
          onPress: () => showConfirm(
            context,
            title: tr('Sign out?'),
            body: tr('You can sign back in with a code to your phone or email.'),
            okLabel: tr('Sign out'),
            icon: 'log-out',
            onConfirm: auth.signOut,
          ),
        ),
      ]),
    ]);
  }
}

// ---------- Settings pages ----------

class _Page {
  final String kicker;
  final String title;
  final String? intro;
  final List<Widget> body;
  final String? foot;
  const _Page({required this.kicker, required this.title, this.intro, required this.body, this.foot});
}

class SettingsPageScreen extends StatefulWidget {
  final String page;
  const SettingsPageScreen({super.key, required this.page});
  @override
  State<SettingsPageScreen> createState() => _SettingsPageScreenState();
}

class _SettingsPageScreenState extends State<SettingsPageScreen> with SavePrivacy<SettingsPageScreen> {
  @override
  Widget build(BuildContext context) {
    useLanguage(context);
    final me = useMe(context);
    final auth = authOf(context);
    final p = me.privacy;

    VoidCallback choice(String k) => () => Nav.push('/settings/choice/$k');
    VoidCallback go(String page) => () => Nav.push('/settings/$page');

    final area = p.areaLevel == 'CITY' ? (me.city ?? me.area ?? '') : '${me.area ?? ''} area';
    final discOn = [p.discoverPeople, p.discoverParticipants, p.discoverDestination, p.discoverSearch].where((v) => v).length;
    final discSum = discOn == 4 ? tr('Everywhere') : (discOn == 0 ? tr('Hidden from discovery') : tr('Limited'));
    ValueChanged<bool> toggle(String k, String label) => (v) => savePrivacy({k: v}, '$label ${v ? tr('turned on') : tr('turned off')}');

    Widget g(List<Widget> rows, {bool danger = false, double top = 0}) => Group(rows, danger: danger, margin: top > 0 ? EdgeInsets.only(top: top) : null);

    Future<void> confirmDeactivate() => showConfirm(
          context,
          title: tr('Confirm deactivation'),
          body: tr('Your profile will no longer appear, people won’t be able to discover you, and your upcoming Plans will be hidden. Sign in any time to come back.'),
          okLabel: tr('Confirm deactivation'),
          okKind: BK.ink,
          icon: 'lock',
          tone: PillTone.neutral,
          onConfirm: () async => auth.setUser(await MeApi.deactivate()),
        );

    final _Page? pg = switch (widget.page) {
      'account' => _Page(
          kicker: 'SETTINGS',
          title: tr('Account information'),
          intro: tr('Public information appears on your profile. Private information is only used to run your account.'),
          body: [
            SectionTitle(tr('Public · shown on your profile')),
            g([
              ListRow(first: true, icon: 'user', label: tr('Name'), value: me.displayName, onPress: () => Nav.push('/settings/name')),
              ListRow(icon: 'clock', label: tr('Age range'), sub: tr('Worked out from your birth year'), value: '${me.ageRange ?? '—'}${p.showAge ? '' : tr(' · hidden')}'),
              ListRow(icon: 'map-pin', label: tr('Area'), value: area, onPress: go('location')),
              ListRow(icon: 'settings', label: tr('Other profile details'), sub: tr('Bio, interests, languages, intent'), onPress: () => Nav.push('/edit-profile')),
            ]),
            SectionTitle(tr('Private · never shown to others')),
            g([
              ListRow(
                first: true,
                icon: 'message-circle',
                label: tr('Email'),
                value: me.maskedEmail ?? tr('Not added'),
                tag: tr('Private'),
                tagTone: PillTone.neutral,
                onPress: () => Nav.push('/settings/contact/EMAIL'),
              ),
              ListRow(
                icon: 'lock',
                label: tr('Phone'),
                value: me.maskedPhone ?? tr('Not added'),
                tag: tr('Private'),
                tagTone: PillTone.neutral,
                onPress: () => Nav.push('/settings/contact/PHONE'),
              ),
              ListRow(icon: 'clock', label: tr('Member since'), value: enMonthYear(me.memberSince)),
            ]),
            SectionTitle(tr('Trust')),
            g([ListRow(first: true, icon: 'shield', label: tr('Verification'), onPress: () => Nav.push('/verify'))]),
            SectionTitle(tr('Your data')),
            g([ListRow(first: true, icon: 'download', label: tr('Download your data'), sub: tr('Get a copy, and manage consent'), onPress: () => Nav.push('/settings/data'))]),
            SectionTitle(tr('Account lifecycle'), danger: true),
            g([ListRow(first: true, icon: 'trash-2', danger: true, label: tr('Deactivate or delete account'), onPress: go('lifecycle'))], danger: true),
          ],
        ),
      'privacy' => _Page(
          kicker: 'SETTINGS',
          title: tr('Privacy'),
          intro: tr('Control what people can see and how they can interact with you.'),
          body: [
            SectionTitle(tr('Profile')),
            g([
              ListRow(first: true, icon: 'eye', label: tr('Profile visibility'), value: shortChoice('profileVisibility', p), onPress: choice('profileVisibility')),
              ListRow(icon: 'user', label: tr('Public profile fields'), sub: tr('Age range, intent, interests, Plans'), onPress: go('fields')),
            ]),
            SectionTitle(tr('Location')),
            g([ListRow(first: true, icon: 'map-pin', label: tr('Approximate location'), sub: tr('Your exact address is never shown'), value: area, onPress: go('location'))]),
            SectionTitle(tr('Discovery')),
            g([
              ListRow(first: true, icon: 'search', label: tr('Who can discover me'), value: discSum, onPress: go('discover')),
              ListRow(icon: 'calendar', label: tr('Default Plan visibility'), value: shortChoice('defaultPlanVisibility', p), onPress: choice('defaultPlanVisibility')),
              ListRow(icon: 'map-pin', label: tr('Plan location'), value: shortChoice('planLocation', p), onPress: choice('planLocation')),
            ]),
            SectionTitle(tr('Contact')),
            g([
              ListRow(first: true, icon: 'users', label: tr('Connection requests'), value: shortChoice('connectionRequests', p), onPress: choice('connectionRequests')),
              ListRow(icon: 'message-circle', label: tr('Messages'), value: shortChoice('messages', p), onPress: choice('messages')),
              ListRow(icon: 'lock', label: tr('Blocked people'), onPress: () => Nav.push('/safety/blocked')),
            ]),
            SectionTitle(tr('Learn more')),
            g([
              ListRow(first: true, icon: 'star', label: tr('How privacy works'), onPress: go('howPrivacy')),
              ListRow(icon: 'eye', label: tr('Preview what others can see'), onPress: () => Nav.push('/safety/visibility')),
            ]),
          ],
        ),
      'fields' => _Page(
          kicker: 'PRIVACY',
          title: tr('Public profile fields'),
          intro: tr('Choose what appears on your profile. Your first name is always shown so people can recognise you at a Plan.'),
          body: [
            g(top: 16, [
              ToggleRow(
                first: true,
                label: tr('Age range'),
                sub: tr('Shown as {v}', {'v': me.ageRange ?? tr('your age range')}),
                value: p.showAge,
                onChange: toggle('showAge', tr('Age range')),
              ),
              ToggleRow(label: tr('Connection intent'), sub: tr('Optional. Dating is never required.'), value: p.showIntent, onChange: toggle('showIntent', tr('Connection intent'))),
              ToggleRow(
                label: tr('Interests'),
                sub: me.interests.isNotEmpty ? me.interests.join(', ') : tr('None added'),
                value: p.showInterests,
                onChange: toggle('showInterests', tr('Interests')),
              ),
              ToggleRow(
                label: tr('Plans you’ve joined'),
                sub: tr('Only Plans that are themselves discoverable'),
                value: p.showPlans,
                onChange: toggle('showPlans', tr('Plans you’ve joined')),
              ),
              ListRow(icon: 'map-pin', label: tr('Approximate area'), sub: tr('Managed in Location'), value: area, onPress: go('location')),
            ]),
            Padding(padding: const EdgeInsets.only(top: 16), child: Button(tr('Preview your profile'), kind: BK.secondary, onPress: () => Nav.push('/me'))),
          ],
        ),
      'location' => _Page(
          kicker: 'PRIVACY',
          title: tr('Location'),
          intro: tr('We use approximate location to help you discover relevant Plans without showing your exact location.'),
          body: [
            g(top: 16, [
              ListRow(first: true, icon: 'eye', label: tr('People see'), value: p.showArea ? area : tr('Hidden')),
              ToggleRow(label: tr('Show approximate area'), sub: tr('On your profile and person cards'), value: p.showArea, onChange: toggle('showArea', tr('Approximate area'))),
              ListRow(icon: 'map-pin', label: tr('Area detail'), value: shortChoice('areaLevel', p), onPress: choice('areaLevel')),
            ]),
            SectionTitle(tr('Never shown')),
            g([
              ListRow(first: true, icon: 'lock', label: tr('Exact home address'), value: tr('Never shown')),
              ListRow(icon: 'lock', label: tr('Exact coordinates'), value: tr('Never shown')),
              ListRow(icon: 'lock', label: tr('Live location'), value: tr('Never shared')),
            ]),
            SectionTitle(tr('Plans')),
            g([ListRow(first: true, icon: 'calendar', label: tr('Plan location'), value: shortChoice('planLocation', p), onPress: choice('planLocation'))]),
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Txt(tr('Meeting points are always public places. Exact venues are only shown when a Plan needs one.'), variant: TV.small),
            ),
          ],
        ),
      'discover' => _Page(
          kicker: 'PRIVACY',
          title: tr('Who can discover me'),
          intro: tr('Choose where your profile can appear. Turning these off doesn’t remove you from Plans you’ve joined.'),
          body: [
            g(top: 16, [
              ToggleRow(
                first: true,
                label: tr('People discovery'),
                sub: tr('Appear in “People around your plans” for nearby Plans.'),
                value: p.discoverPeople,
                onChange: toggle('discoverPeople', tr('People discovery')),
              ),
              ToggleRow(
                label: tr('Plan participant lists'),
                sub: tr('Show to people viewing a Plan you joined. Participants in the same Plan always see you.'),
                value: p.discoverParticipants,
                onChange: toggle('discoverParticipants', tr('Plan participant lists')),
              ),
              ToggleRow(
                label: tr('Same destination'),
                sub: tr('Appear to people going to the same place on similar dates.'),
                value: p.discoverDestination,
                onChange: toggle('discoverDestination', tr('Same destination')),
              ),
              ToggleRow(
                label: tr('Search results'),
                sub: tr('Appear when people search by name or interest.'),
                value: p.discoverSearch,
                onChange: toggle('discoverSearch', tr('Search results')),
              ),
            ]),
          ],
        ),
      'howPrivacy' => _Page(
          kicker: 'PRIVACY',
          title: tr('How privacy works'),
          intro: tr('People discover each other through shared Plans and context, not through access to private personal information.'),
          body: [
            g(top: 16, [
              ListRow(first: true, icon: 'map-pin', label: tr('Approximate location'), sub: tr('An area like “Indiranagar area”. Never your address or live location.')),
              ListRow(icon: 'user', label: tr('Public profile fields'), sub: tr('You choose which appear. Contact details are never public.')),
              ListRow(icon: 'calendar', label: tr('Plan visibility'), sub: tr('Discoverable, shared-context only or private — per Plan.')),
              ListRow(icon: 'users', label: tr('Connection controls'), sub: tr('Choose who can send you requests. Every request shows its shared context.')),
              ListRow(icon: 'message-circle', label: tr('Messaging controls'), sub: tr('Choose who can message you. Blocking always wins.')),
            ]),
            Padding(padding: const EdgeInsets.only(top: 16), child: Button(tr('Open privacy settings'), onPress: go('privacy'))),
          ],
        ),
      'security' => _Page(
          kicker: 'SETTINGS',
          title: tr('Security'),
          intro: tr('Protect your account and manage where you’re signed in.'),
          body: [
            SectionTitle(tr('Login & authentication')),
            g([
              ListRow(
                first: true,
                icon: 'lock',
                label: tr('Sign-in method'),
                sub: tr('One-time code to your verified phone or email'),
                value: me.maskedPhone ?? me.maskedEmail ?? '',
              ),
              ListRow(
                icon: 'key',
                label: tr('Password'),
                sub: tr('Backup sign-in when a code isn’t available · {v}', {
                  'v': me.hasPassword
                      ? (me.passwordChangedAt != null ? tr('Changed {when}', {'when': relativeTime(me.passwordChangedAt!)}) : tr('Set'))
                      : tr('Not set'),
                }),
                onPress: () => Nav.push('/settings/password'),
              ),
            ]),
            SectionTitle(tr('Sessions')),
            g([ListRow(first: true, icon: 'smartphone', label: tr('Active sessions'), onPress: () => Nav.push('/settings/sessions'))]),
            SectionTitle(tr('Security activity')),
            g([ListRow(first: true, icon: 'clock', label: tr('Recent security activity'), onPress: () => Nav.push('/settings/secActivity'))]),
            SectionTitle(tr('Account protection')),
            g([ListRow(first: true, icon: 'shield', label: tr('Account recovery'), sub: tr('Phone and email on file'), onPress: go('recovery'))]),
          ],
        ),
      'recovery' => _Page(
          kicker: 'SECURITY',
          title: tr('Account recovery'),
          intro: tr('Used to get back into your account if you lose access. Never shown on your profile.'),
          body: [
            g(top: 16, [
              ListRow(
                first: true,
                icon: 'lock',
                label: tr('Phone'),
                sub: me.signals.contains('PHONE') ? tr('Verified') : tr('Not verified'),
                value: me.maskedPhone ?? tr('Not added'),
                tag: tr('Private'),
                tagTone: PillTone.neutral,
              ),
              ListRow(
                icon: 'message-circle',
                label: tr('Email'),
                sub: me.signals.contains('EMAIL') ? tr('Verified') : tr('Not verified'),
                value: me.maskedEmail ?? tr('Not added'),
                tag: tr('Private'),
                tagTone: PillTone.neutral,
              ),
              ListRow(icon: 'settings', label: tr('Change these'), sub: tr('In Account information'), onPress: go('account')),
            ]),
          ],
        ),
      'lifecycle' => _Page(
          kicker: 'SETTINGS',
          title: tr('Deactivate or delete'),
          intro: tr('Two different choices. Take a break, or leave permanently.'),
          body: [
            SectionTitle(tr('Temporary')),
            g([
              ListRow(first: true, icon: 'lock', label: tr('Deactivate account'), sub: tr('Hide your profile and Plans. Come back any time by signing in.'), onPress: go('deactivate')),
            ]),
            SectionTitle(tr('Permanent'), danger: true),
            g(danger: true, [
              ListRow(
                first: true,
                icon: 'trash-2',
                danger: true,
                label: tr('Delete account'),
                sub: tr('Remove your profile and account. This can’t be easily undone.'),
                onPress: go('delete'),
              ),
            ]),
            g(top: 16, [ListRow(first: true, icon: 'star', label: tr('What happens to my content?'), onPress: go('content'))]),
          ],
        ),
      'deactivate' => _Page(
          kicker: tr('ACCOUNT LIFECYCLE'),
          title: tr('Deactivate your account?'),
          intro: tr('Your profile and discovery presence will be hidden while your account is deactivated.'),
          body: [
            SectionTitle(tr('While deactivated')),
            g([
              ListRow(first: true, icon: 'eye', label: tr('Profile hidden'), sub: tr('People can’t open your profile.')),
              ListRow(icon: 'search', label: tr('Not discoverable'), sub: tr('You won’t appear in people or Plan discovery.')),
              ListRow(icon: 'users', label: tr('No new requests or messages'), sub: tr('Existing connections are paused, not removed.')),
              ListRow(icon: 'calendar', label: tr('Your Plans'), sub: tr('Upcoming Plans you created are hidden from discovery.')),
              ListRow(icon: 'check', label: tr('Your data is kept'), sub: tr('Sign in again to reactivate.')),
            ]),
            Padding(
              padding: const EdgeInsets.only(top: 16),
              // Equal weight: leaving shouldn’t be harder to find than staying.
              child: Col(gap: 8, [
                Button(tr('Deactivate account'), kind: BK.secondary, onPress: confirmDeactivate),
                Button(tr('Keep account'), kind: BK.secondary, onPress: Nav.back),
              ]),
            ),
          ],
        ),
      'delete' => _Page(
          kicker: tr('ACCOUNT LIFECYCLE'),
          title: tr('Delete your account?'),
          intro: tr('Deleting your account is permanent after a short grace period.'),
          body: [
            SectionTitle(tr('What happens')),
            g([
              ListRow(first: true, icon: 'user', label: tr('Profile removed'), sub: tr('Your profile and discovery presence are removed.')),
              ListRow(icon: 'users', label: tr('Connections removed'), sub: tr('People aren’t told why.')),
              ListRow(icon: 'calendar', label: tr('Plans you created'), sub: tr('Upcoming Plans are cancelled and participants are told.')),
              ListRow(icon: 'message-circle', label: tr('Messages and groups'), sub: tr('Shown as from “Deleted account”, handled under our retention policy.')),
              ListRow(icon: 'lock', label: tr('Account data'), sub: tr('Deleted after the grace period under our data policy.')),
            ]),
            g(top: 16, [
              ListRow(first: true, icon: 'lock', label: tr('Want a break instead?'), sub: tr('Deactivate keeps everything and hides you'), onPress: () => Nav.replace('/settings/deactivate')),
              ListRow(icon: 'star', label: tr('What happens to my content?'), onPress: go('content')),
            ]),
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Col(gap: 8, [
                Button(tr('Continue'), kind: BK.dangerSolid, onPress: () => Nav.push('/settings/delete-confirm')),
                Button(tr('Keep account'), kind: BK.secondary, onPress: Nav.back),
              ]),
            ),
          ],
        ),
      'content' => _Page(
          kicker: tr('ACCOUNT LIFECYCLE'),
          title: tr('What happens to my content?'),
          intro: tr('A plain-language summary of what happens when you deactivate or delete.'),
          body: [
            g(top: 16, [
              ListRow(first: true, icon: 'user', label: tr('Profile'), sub: tr('Deactivate: hidden. Delete: removed.')),
              ListRow(icon: 'calendar', label: tr('Plans you created'), sub: tr('Deactivate: hidden from discovery. Delete: upcoming Plans are cancelled and participants told.')),
              ListRow(icon: 'calendar', label: tr('Plans you joined'), sub: tr('Delete: you leave them. Others see “A participant left”.')),
              ListRow(icon: 'users', label: tr('Connections'), sub: tr('Deactivate: paused. Delete: removed. People aren’t told why.')),
              ListRow(icon: 'message-circle', label: tr('Messages'), sub: tr('Deactivate: kept. Delete: shown as from “Deleted account”.')),
              ListRow(icon: 'users', label: tr('Plan Groups'), sub: tr('Delete: you leave every group.')),
              ListRow(icon: 'flag', label: tr('Reports you made'), sub: tr('May be kept to protect others, without your profile.')),
              ListRow(icon: 'shield', label: tr('Verification'), sub: tr('Delete: verification results are deleted.')),
            ]),
          ],
        ),
      'restricted' => _Page(
          kicker: 'ACCOUNT',
          title: tr('Some features are limited'),
          intro: tr('Your account currently has limited access after a review under our community guidelines.'),
          foot: tr('We don’t share review details here. If you think this is a mistake, contact support.'),
          body: [
            g(top: 16, [
              ListRow(first: true, icon: 'users', label: tr('New connection requests'), value: tr('Paused')),
              ListRow(icon: 'message-circle', label: tr('Messaging people you’re not connected with'), value: tr('Paused')),
              ListRow(icon: 'calendar', label: tr('Creating Plans'), value: tr('Paused')),
              ListRow(icon: 'check', label: tr('Plans you’ve joined, existing chats, settings'), value: tr('Available')),
            ]),
            Padding(padding: const EdgeInsets.only(top: 16), child: Button(tr('Contact support'), kind: BK.secondary, onPress: () => Nav.push('/help'))),
          ],
        ),
      _ => null,
    };

    if (pg == null) {
      return Screen(children: [
        const Header(),
        StateBlock(icon: 'eye-off', tone: PillTone.neutral, title: tr('This page isn’t available'), actions: [StateAction(tr('Back'), Nav.back)]),
      ]);
    }

    return Screen(children: [
      Header(kicker: pg.kicker, title: pg.title),
      SaveErrorBanner(saveError),
      if (pg.intro != null) Txt(pg.intro),
      ...pg.body,
      if (pg.foot != null) Padding(padding: const EdgeInsets.only(top: 14), child: Txt(pg.foot, variant: TV.small)),
    ]);
  }
}

// ---------- Choice ----------

class ChoiceScreen extends StatefulWidget {
  final String choiceKey;
  const ChoiceScreen({super.key, required this.choiceKey});
  @override
  State<ChoiceScreen> createState() => _ChoiceScreenState();
}

class _ChoiceScreenState extends State<ChoiceScreen> with SavePrivacy<ChoiceScreen> {
  late String? value = authOf(context).user?.privacy[widget.choiceKey]?.toString();
  bool busy = false;

  @override
  Widget build(BuildContext context) {
    useLanguage(context);
    final i18n = context.read<I18n>();
    final def = choices[widget.choiceKey];
    final me = useMe(context);
    if (def == null) return const Scaffold(backgroundColor: AppColors.paper);
    final current = me.privacy[widget.choiceKey]?.toString();
    final key = widget.choiceKey;

    Future<void> submit() async {
      setState(() => busy = true);
      final ok = await savePrivacy({key: value}, tr('{setting} updated', {'setting': tr(def.title).replaceAll(RegExp(r'[?？]$'), '')}));
      if (mounted) setState(() => busy = false);
      if (!ok) return;
      if (key == 'language' && value != null) i18n.setLang(value!); // switch the app immediately
      Nav.back();
    }

    return Screen(children: [
      Header(kicker: tr(def.kicker), title: tr(def.title)),
      SaveErrorBanner(saveError),
      Padding(padding: const EdgeInsets.only(bottom: 14), child: Txt(tr(def.intro))),
      RadioCards<String>(
        label: tr(def.title),
        options: def.opts
            .map((o) => RadioOption(
                  o.value,
                  // Language names are always shown in their own script, with the English name as the subtitle.
                  key == 'language' ? o.label : tr(o.label),
                  sub: o.sub != null ? tr(o.sub!) : null,
                ))
            .toList(),
        value: value,
        onChange: (v) => setState(() => value = v),
      ),
      if (def.note != null) Padding(padding: const EdgeInsets.only(top: 10), child: Txt(tr(def.note!), variant: TV.small)),
      Padding(padding: const EdgeInsets.only(top: 18), child: Button(tr('Save'), disabled: value == current, loading: busy, onPress: submit)),
    ]);
  }
}

// ---------- Change contact ----------

/// Change email/phone: enter the new value, confirm with a one-time code sent to it.
class ChangeContactScreen extends StatefulWidget {
  final String channel;
  const ChangeContactScreen({super.key, required this.channel});
  @override
  State<ChangeContactScreen> createState() => _ChangeContactScreenState();
}

class _ChangeContactScreenState extends State<ChangeContactScreen> {
  String step = 'enter';
  String value = '';
  String code = '';
  String? error;
  bool busy = false;
  String? devCode;

  bool get email => widget.channel == 'EMAIL';
  String get _digits => value.replaceAll(RegExp(r'\D'), '');
  String get normalized => email ? value.trim().toLowerCase() : '+91$_digits';
  String get masked {
    if (!email) return '+91 ••••••${_digits.length > 4 ? _digits.substring(_digits.length - 4) : _digits}';
    final m = RegExp(r'^(.).*(@.*)$').firstMatch(value.trim());
    return m == null ? value.trim() : '${m.group(1)}••••${m.group(2)}';
  }

  Future<void> _send() async {
    final valid = email ? RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value.trim()) : _digits.length == 10;
    if (!valid) return setState(() => error = email ? tr('Enter a valid email address.') : tr('Enter a valid 10-digit mobile number.'));
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final r = await MeApi.startContactChange(widget.channel, normalized);
      if (mounted) {
        setState(() {
          devCode = r.devCode;
          step = 'code';
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = e is ApiError ? e.message : tr('Couldn’t send a code.'));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _confirm() async {
    final auth = authOf(context);
    setState(() {
      busy = true;
      error = null;
    });
    try {
      auth.setUser(await MeApi.confirmContactChange(widget.channel, normalized, code));
      if (mounted) setState(() => step = 'done');
    } catch (e) {
      if (mounted) setState(() => error = e is ApiError ? e.message : tr('That code didn’t work.'));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    useLanguage(context);
    final me = useMe(context);
    return Screen(children: [
      Header(kicker: tr('ACCOUNT INFORMATION'), title: email ? tr('Change email') : tr('Change phone')),
      if (step == 'enter') ...[
        Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Txt.rich(trRich(email ? 'Current email: {value}' : 'Current phone number: {value}', {
            'value': bold((email ? me.maskedEmail : me.maskedPhone) ?? tr('Not added')),
          })),
        ),
        Field(
          label: email ? tr('New email') : tr('New phone number'),
          value: value,
          onChanged: (t) => setState(() {
            value = t;
            error = null;
          }),
          keyboardType: email ? TextInputType.emailAddress : TextInputType.phone,
          capitalization: TextCapitalization.none,
          prefix: email ? null : '+91',
          placeholder: email ? tr('name@example.com') : '98765 43210',
          error: error,
        ),
        Txt(email ? tr('Your email is private. People only ever see Email verified.') : tr('Your number is private. People only ever see Phone verified.'), variant: TV.small),
        Padding(padding: const EdgeInsets.only(top: 16), child: Button(tr('Send code'), loading: busy, onPress: _send)),
      ] else if (step == 'code') ...[
        Txt(tr('Enter the code'), variant: TV.title),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Txt.rich(trRich(
            email
                ? 'We sent a 6-digit code to {destination}. Your current email stays active until you confirm.'
                : 'We sent a 6-digit code to {destination}. Your current number stays active until you confirm.',
            {'destination': bold(masked)},
          )),
        ),
        Field(
          label: tr('6-digit verification code'),
          value: code,
          onChanged: (t) => setState(() => code = t),
          formatters: [digitsOnly],
          maxLength: 6,
          keyboardType: TextInputType.number,
          autofill: const [AutofillHints.oneTimeCode],
          placeholder: '••••••',
          error: error,
        ),
        Button(tr('Verify'), loading: busy, disabled: code.length < 6, onPress: _confirm),
        if (devCode != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Txt(tr('Development build · code: {code}', {'code': devCode}), variant: TV.caption, align: TextAlign.center),
          ),
      ] else
        StateBlock(
          icon: 'check',
          title: email ? tr('Email updated') : tr('Phone number updated'),
          body: email ? tr('Your new email is verified and stays private.') : tr('Your new number is verified and stays private. It’s used for sign-in codes.'),
          actions: [StateAction(tr('Done'), Nav.back)],
        ),
    ]);
  }
}

// ---------- Your data ----------

const _kindLabel = {
  'TERMS': 'Terms of service',
  'PRIVACY_POLICY': 'Privacy policy',
  'AGE_18_PLUS': 'Confirmed 18 or older',
  'ANALYTICS': 'Product analytics',
  'OFFERS': 'Offers & promotions',
  'MARKETING_EMAILS': 'Update emails',
};

/// Your data: download a copy, change optional consents, see the consent record, delete the account.
class YourDataScreen extends StatefulWidget {
  const YourDataScreen({super.key});
  @override
  State<YourDataScreen> createState() => _YourDataScreenState();
}

class _YourDataScreenState extends State<YourDataScreen> {
  Consents? c;
  ApiError? loadError;
  String? saveError;
  bool exporting = false;
  bool showHistory = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    setState(() => loadError = null);
    PrivacyApi.consents().then((v) {
      if (mounted) setState(() => c = v);
    }).catchError((e) {
      if (mounted) setState(() => loadError = e is ApiError ? e : ApiError(0, 'ERROR', tr('Couldn’t load this')));
    });
  }

  Future<void> _save({bool? analytics, bool? offers, bool? marketingEmails, required String label}) async {
    final cur = c;
    if (cur == null) return;
    final toast = useToast(context);
    final next = cur.copyWith(analytics: analytics, offers: offers, marketingEmails: marketingEmails);
    setState(() {
      c = next; // optimistic; reverted below if the save fails
      saveError = null;
    });
    try {
      final saved = await PrivacyApi.saveConsents(analytics: next.analytics, offers: next.offers, marketingEmails: next.marketingEmails, source: 'SETTINGS');
      setAnalyticsAllowed(saved.analytics);
      if (mounted) setState(() => c = saved);
      toast(label);
    } catch (e) {
      if (mounted) {
        setState(() {
          c = cur;
          saveError = e is ApiError ? e.message : tr('Couldn’t save. Try again.');
        });
      }
    }
  }

  Future<void> _download(Me me) async {
    final toast = useToast(context);
    setState(() => exporting = true);
    try {
      final data = await PrivacyApi.exportData();
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/plans-data-${me.id}.json');
      if (await file.exists()) await file.delete();
      await file.writeAsString(const JsonEncoder.withIndent('  ').convert(data));
      final res = await SharePlus.instance.share(ShareParams(
        files: [XFile(file.path, mimeType: 'application/json')],
        title: tr('Save your Plans data'),
      ));
      if (res.status == ShareResultStatus.unavailable) toast(tr('Saved to {path}', {'path': file.path}));
    } catch (e) {
      toast(e is ApiError ? e.message : tr('Couldn’t prepare your data. Try again.'));
    } finally {
      if (mounted) setState(() => exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    useLanguage(context);
    final me = useMe(context);
    final cc = c;
    return Screen(children: [
      Header(kicker: tr('PRIVACY'), title: tr('Your data')),
      Txt(tr('See what we hold, choose what’s optional, and leave whenever you like.')),
      SectionTitle(tr('Download')),
      Group([
        ListRow(
          first: true,
          icon: 'download',
          label: tr('Download your data'),
          sub: tr('Profile, settings, Plans, connections, messages you sent, reports you made and consents, as a JSON file.'),
        ),
      ]),
      Padding(
        padding: const EdgeInsets.only(top: 10),
        child: Button(exporting ? tr('Preparing…') : tr('Download a copy'), icon: 'download', kind: BK.secondary, loading: exporting, onPress: () => _download(me)),
      ),
      SectionTitle(tr('Data & consent')),
      if (loadError != null)
        ErrorBlock.of(loadError!, onRetry: _load)
      else if (cc == null)
        const Skeleton(rows: 3)
      else ...[
        if (saveError != null) Padding(padding: const EdgeInsets.only(bottom: 10), child: Banner(icon: 'alert-circle', tone: PillTone.bad, title: saveError!)),
        Group([
          ToggleRow(
            first: true,
            label: tr('Product analytics'),
            sub: tr('Counts of actions like “Plan joined” to improve Plans. Never message content or location. Turning this off also unlinks past events from you.'),
            value: cc.analytics,
            onChange: (v) => _save(analytics: v, label: v ? tr('Analytics on') : tr('Analytics off')),
          ),
          ToggleRow(
            label: tr('Offers & promotions'),
            sub: tr('Occasional in-app notifications about deals on events.'),
            value: cc.offers,
            onChange: (v) => _save(offers: v, label: v ? tr('Offers on') : tr('Offers off')),
          ),
          ToggleRow(
            label: tr('Update emails'),
            sub: tr('News about Plans by email. Every email has an unsubscribe link. Security emails you request are always sent.'),
            value: cc.marketingEmails,
            onChange: (v) => _save(marketingEmails: v, label: v ? tr('Update emails on') : tr('Update emails off')),
          ),
        ]),
        Note(tr('Needed to run your account and always on: sign-in, your profile, Plans, messages and safety tools.'), icon: 'check'),
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Button(showHistory ? tr('Hide consent record') : tr('Show consent record'), kind: BK.text, onPress: () => setState(() => showHistory = !showHistory)),
        ),
        if (showHistory)
          Group([
            if (cc.history.isNotEmpty)
              for (final (i, h) in cc.history.reversed.indexed)
                ListRow(
                  key: ValueKey('${h.kind}-${h.at}-$i'),
                  first: i == 0,
                  icon: h.granted ? 'check-circle' : 'x-circle',
                  label: tr(_kindLabel[h.kind] ?? h.kind),
                  sub: '${h.granted ? tr('Agreed') : tr('Declined')} · ${enMediumDateTime(h.at)} · v${h.version}',
                )
            else
              ListRow(first: true, icon: 'info', label: tr('No choices recorded yet')),
          ]),
      ],
      SectionTitle(tr('Policies')),
      Group([
        ListRow(first: true, icon: 'lock', label: tr('Privacy policy'), onPress: () => Nav.push('/legal/privacy')),
        ListRow(icon: 'database', label: tr('Cookie & storage policy'), onPress: () => Nav.push('/legal/cookie-policy')),
        ListRow(icon: 'package', label: tr('Third-party services'), onPress: () => Nav.push('/legal/licenses')),
      ]),
      SectionTitle(tr('Delete'), danger: true),
      Group(danger: true, [
        ListRow(
          first: true,
          icon: 'trash-2',
          danger: true,
          label: tr('Delete your account'),
          sub: tr('Your data is removed after a 30-day grace period. You can cancel during that time.'),
          onPress: () => Nav.push('/settings/lifecycle'),
        ),
      ]),
    ]);
  }
}

// ---------- Delete confirm ----------

class DeleteConfirmScreen extends StatefulWidget {
  const DeleteConfirmScreen({super.key});
  @override
  State<DeleteConfirmScreen> createState() => _DeleteConfirmScreenState();
}

class _DeleteConfirmScreenState extends State<DeleteConfirmScreen> {
  String text = '';
  bool busy = false;
  String? error;

  Future<void> _go() async {
    final auth = authOf(context);
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await MeApi.requestDeletion();
      // Account state flips to DELETION_REQUESTED; the router shows the pending screen.
      await auth.refreshUser();
    } catch (e) {
      if (mounted) {
        setState(() => error = e is ApiError && e.isNetwork
            ? tr('You’re offline. Reconnect to continue. Nothing was changed.')
            : (e is ApiError ? e.message : tr('Couldn’t delete your account. Try again.')));
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    useLanguage(context);
    return Screen(children: [
      Header(kicker: tr('ACCOUNT LIFECYCLE'), title: tr('Delete account')),
      if (error != null) Padding(padding: const EdgeInsets.only(bottom: 12), child: Banner(icon: 'refresh-cw', tone: PillTone.bad, title: error!)),
      const Start(IconTile('trash-2', tone: PillTone.bad, size: 52)),
      Padding(padding: const EdgeInsets.only(top: 14), child: Txt(tr('Are you sure?'), variant: TV.title)),
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Txt(tr('This action can’t be easily undone. Your profile, connections and Plans will be removed as described on the previous screen.')),
      ),
      Field(
        label: tr('Type DELETE to confirm'),
        value: text,
        onChanged: (t) => setState(() => text = t),
        capitalization: TextCapitalization.characters,
        autocorrect: false,
        hint: tr('Capital letters, exactly as shown.'),
      ),
      Col(gap: 8, [
        Button(tr('Delete account'), kind: BK.dangerSolid, disabled: text != 'DELETE', loading: busy, onPress: _go),
        Button(tr('Keep account'), kind: BK.secondary, onPress: () => Nav.dismissTo('/settings')),
      ]),
    ]);
  }
}

// ---------- Change name ----------

class ChangeNameScreen extends StatefulWidget {
  const ChangeNameScreen({super.key});
  @override
  State<ChangeNameScreen> createState() => _ChangeNameScreenState();
}

class _ChangeNameScreenState extends State<ChangeNameScreen> {
  late String name = authOf(context).user?.displayName ?? '';
  String? error;
  bool busy = false;

  Future<void> _save() async {
    final auth = authOf(context);
    final toast = useToast(context);
    final me = auth.user!;
    if (name.trim().length < 2) return setState(() => error = tr('Enter at least 2 characters.'));
    if (name.trim() == me.displayName) return Nav.back();
    setState(() => busy = true);
    try {
      auth.setUser(await MeApi.updateName(name.trim()));
      toast(tr('Name updated'));
      Nav.back();
    } catch (e) {
      if (mounted) setState(() => error = e is ApiError ? e.message : tr('Couldn’t save. Try again.'));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    useLanguage(context);
    final me = useMe(context);
    return Screen(children: [
      Header(kicker: tr('ACCOUNT INFORMATION'), title: tr('Change name')),
      Padding(padding: const EdgeInsets.only(bottom: 14), child: Txt.rich(trRich('Current name: {name}', {'name': bold(me.displayName)}))),
      Field(
        label: tr('New name'),
        value: name,
        onChanged: (t) => setState(() {
          name = t;
          error = null;
        }),
        autofill: const [AutofillHints.name],
        capitalization: TextCapitalization.words,
        error: error,
      ),
      Txt(tr('Your name appears on your public profile and in Plans you join.'), variant: TV.small),
      if (me.signals.contains('IDENTITY'))
        Banner(icon: 'shield', tone: PillTone.neutral, title: tr('Because you’re Identity verified, a new name is re-checked before that signal shows again.')),
      Padding(padding: const EdgeInsets.only(top: 16), child: Button(tr('Save name'), loading: busy, onPress: _save)),
    ]);
  }
}

// ---------- Change password ----------

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});
  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  String cur = '';
  String nw = '';
  String cf = '';
  bool show = false;
  String? error;
  bool busy = false;
  bool done = false;

  List<(bool, String)> get rules => [
        (nw.length >= 8, tr('At least 8 characters')),
        (RegExp(r'\d').hasMatch(nw), tr('Includes a number')),
        (RegExp(r'[A-Za-z]').hasMatch(nw), tr('Includes a letter')),
        (nw.isNotEmpty && nw != cur, tr('Different from your current password')),
        if (cf.isNotEmpty) (cf == nw, cf == nw ? tr('Passwords match') : tr('Passwords don’t match')),
      ];

  Future<void> _submit() async {
    final valid = rules.every((r) => r.$1) && cf == nw;
    if (!valid) return setState(() => error = tr('Check the password requirements.'));
    final auth = authOf(context);
    final me = auth.user!;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await MeApi.changePassword(me.hasPassword ? cur : null, nw);
      await auth.refreshUser();
      if (mounted) setState(() => done = true);
    } catch (e) {
      if (mounted) setState(() => error = e is ApiError ? e.message : tr('Couldn’t update your password.'));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    useLanguage(context);
    final me = useMe(context);
    if (done) {
      return Screen(children: [
        Header(kicker: tr('SECURITY'), title: tr('Change password')),
        StateBlock(
          icon: 'check',
          title: tr('Password updated'),
          body: tr('Your password has been changed successfully. Other devices stay signed in until you sign them out.'),
          actions: [StateAction(tr('Review active sessions'), () => Nav.replace('/settings/sessions'), BK.secondary), StateAction(tr('Done'), Nav.back)],
        ),
      ]);
    }
    return Screen(children: [
      Header(kicker: tr('SECURITY'), title: me.hasPassword ? tr('Change password') : tr('Set a password')),
      if (me.hasPassword)
        Field(
          label: tr('Current password'),
          value: cur,
          onChanged: (t) => setState(() => cur = t),
          obscure: !show,
          capitalization: TextCapitalization.none,
          autofill: const [AutofillHints.password],
        ),
      Field(
        label: tr('New password'),
        value: nw,
        onChanged: (t) => setState(() => nw = t),
        obscure: !show,
        capitalization: TextCapitalization.none,
        autofill: const [AutofillHints.newPassword],
      ),
      Field(
        label: tr('Confirm new password'),
        value: cf,
        onChanged: (t) => setState(() => cf = t),
        obscure: !show,
        capitalization: TextCapitalization.none,
        autofill: const [AutofillHints.newPassword],
      ),
      Start(Button(show ? tr('Hide passwords') : tr('Show passwords'), kind: BK.text, compact: true, onPress: () => setState(() => show = !show))),
      Semantics(
        label: tr('Password requirements'),
        container: true,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Col(gap: 4, [
            for (final (ok, text) in rules)
              Text.rich(
                TextSpan(children: [
                  TextSpan(text: ok ? '✓' : '○', style: const TextStyle(fontFamily: Fonts.bodyBold)),
                  TextSpan(text: '  $text'),
                ]),
                style: TextStyle(fontFamily: Fonts.body, fontSize: 13, color: ok ? AppColors.brand : AppColors.inkSoft),
              ),
          ]),
        ),
      ),
      if (error != null) Banner(icon: 'alert-circle', tone: PillTone.bad, title: error!),
      Padding(padding: const EdgeInsets.only(top: 12), child: Button(busy ? tr('Updating…') : tr('Update password'), loading: busy, onPress: _submit)),
    ]);
  }
}

// ---------- Security activity ----------

class SecurityActivityScreen extends StatefulWidget {
  const SecurityActivityScreen({super.key});
  @override
  State<SecurityActivityScreen> createState() => _SecurityActivityScreenState();
}

class _SecurityActivityScreenState extends State<SecurityActivityScreen> with FocusData<SecurityActivityScreen, List<SecurityEvent>> {
  @override
  Future<List<SecurityEvent>> load() => MeApi.securityEvents();

  void _open(SecurityEvent e) => showSheet<void>(
        context,
        label: e.title,
        builder: (ctx) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Txt(tr('SECURITY ACTIVITY'), variant: TV.kicker),
          Padding(padding: const EdgeInsets.only(bottom: 12), child: Txt(e.title, variant: TV.heading)),
          KeyValue([
            KV(tr('When'), relativeTime(e.createdAt)),
            KV(tr('Device'), e.deviceName ?? '—'),
            KV(tr('Approximate location'), e.area ?? '—'),
          ]),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Txt(tr('We never ask for your code or password in a message, call or notification.'), variant: TV.small),
          ),
          Button(tr('This was me'), onPress: () => Navigator.of(ctx).pop()),
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Button(tr('This wasn’t me'), kind: BK.secondary, onPress: () {
              Navigator.of(ctx).pop();
              Nav.replace('/settings/sessions');
            }),
          ),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    useLanguage(context);
    final d = data;
    return Screen(children: [
      Header(kicker: tr('SECURITY'), title: tr('Recent security activity')),
      Txt(tr('Important changes and sign-ins from the last 30 days.')),
      if (loading)
        const Skeleton()
      else if (error != null && d == null)
        ErrorBlock.of(error!, onRetry: refresh)
      else if (d == null || d.isEmpty)
        StateBlock(icon: 'check', title: tr('No recent activity'), body: tr('Sign-ins and account changes will appear here.'))
      else
        Group(margin: const EdgeInsets.only(top: 16), [
          for (var i = 0; i < d.length; i++)
            ListRow(
              first: i == 0,
              icon: 'clock',
              label: d[i].title,
              sub: '${relativeTime(d[i].createdAt)}${d[i].deviceName != null ? ' · ${d[i].deviceName}' : ''}',
              onPress: () => _open(d[i]),
            ),
        ]),
    ]);
  }
}

// ---------- Sessions ----------

class SessionsScreen extends StatefulWidget {
  const SessionsScreen({super.key});
  @override
  State<SessionsScreen> createState() => _SessionsScreenState();
}

class _SessionsScreenState extends State<SessionsScreen> with FocusData<SessionsScreen, List<Session>> {
  @override
  Future<List<Session>> load() => MeApi.sessions();

  IconName _icon(Session s) => s.platform == 'WEB' ? 'monitor' : 'smartphone';

  @override
  Widget build(BuildContext context) {
    useLanguage(context);
    final toast = useToast(context);
    final d = data;
    final current = d?.where((s) => s.current).toList() ?? [];
    final others = d?.where((s) => !s.current).toList() ?? [];

    Future<void> confirmOne(Session s) => showConfirm(
          context,
          title: tr('Sign out {deviceName}?', {'deviceName': s.deviceName}),
          body: tr('That device will need to sign in again.'),
          okLabel: tr('Sign out'),
          icon: 'smartphone',
          onConfirm: () async {
            await MeApi.signOutSession(s.id);
            setData(data?.where((x) => x.id != s.id).toList());
            toast(tr('{deviceName} signed out', {'deviceName': s.deviceName}));
          },
        );

    Future<void> confirmOthers() => showConfirm(
          context,
          title: tr('Sign out other devices?'),
          body: tr('You’ll stay signed in on this device.'),
          okLabel: tr('Sign out'),
          icon: 'smartphone',
          onConfirm: () async {
            await MeApi.signOutOthers();
            setData(data?.where((x) => x.current).toList());
            toast(tr('Other sessions signed out'));
          },
        );

    return Screen(children: [
      Header(kicker: tr('SECURITY'), title: tr('Active sessions')),
      Txt(tr('Where you’re signed in. Locations are approximate, based on the network.')),
      if (loading)
        const Skeleton()
      else if (error != null && d == null)
        ErrorBlock.of(error!, onRetry: refresh)
      else ...[
        SectionTitle(tr('This device')),
        Group([
          for (var i = 0; i < current.length; i++)
            ListRow(
              first: i == 0,
              icon: _icon(current[i]),
              label: current[i].deviceName,
              sub: '${current[i].app}${current[i].area != null ? ' · ${current[i].area}' : ''}',
              value: tr('Active now'),
              tag: tr('Current session'),
              tagTone: PillTone.ok,
            ),
        ]),
        if (others.isNotEmpty) ...[
          SectionTitle(tr('Other devices')),
          Group([
            for (var i = 0; i < others.length; i++)
              ListRow(
                first: i == 0,
                icon: _icon(others[i]),
                label: others[i].deviceName,
                sub: '${others[i].app}${others[i].area != null ? ' · ${others[i].area}' : ''} · ${relativeTime(others[i].lastActiveAt)}',
                onPress: () {
                  final s = others[i];
                  showActionSheet(context, title: s.deviceName, sub: '${s.app} · ${s.area ?? ''} · ${relativeTime(s.lastActiveAt)}', actions: [
                    SheetAction(tr('Sign out this device'), 'log-out', () => confirmOne(s), danger: true, sub: tr('It will need to sign in again')),
                  ]);
                },
              ),
          ]),
          Padding(padding: const EdgeInsets.only(top: 16), child: Button(tr('Sign out all other devices'), kind: BK.secondary, onPress: confirmOthers)),
        ] else
          Group(margin: const EdgeInsets.only(top: 16), [ListRow(first: true, icon: 'check', label: tr('No other devices'), sub: tr('You’re only signed in here.'))]),
      ],
    ]);
  }
}

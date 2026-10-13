import { router } from 'expo-router';
import { useState } from 'react';
import { Linking, View } from 'react-native';
import { ApiError, meApi } from '@/api';
import { ConfirmDialog } from '@/components/Sheet';
import { Button, IconTile, Logo, Screen, T } from '@/components/ui';
import { useAuth, useMe } from '@/context/AuthContext';
import { useToast } from '@/context/ToastContext';
import { business, emailOrNull } from '@/lib/business';
import { tr, useLanguage } from '@/i18n';

/** Full-screen account states from the prototype: deactivated, deletion pending, suspended. */
export default function AccountState() {
  useLanguage();
  const me = useMe();
  const { setUser, signOut } = useAuth();
  const toast = useToast();
  const [confirm, setConfirm] = useState(false);

  const content = {
    DEACTIVATED: {
      icon: 'lock' as const, tone: 'neutral' as const, kicker: tr('ACCOUNT DEACTIVATED'), title: tr('Your account is currently inactive'),
      body: tr('Your profile is hidden and people can’t discover or message you. Your data is kept.'),
      primary: tr('Reactivate account'), foot: tr('While deactivated, you can’t browse Plans or use chats.'),
    },
    DELETION_REQUESTED: {
      icon: 'clock' as const, tone: 'warn' as const, kicker: tr('DELETION REQUESTED'), title: tr('Your account is scheduled for deletion'),
      body: tr('Your profile stays hidden while deletion is pending. You can cancel the request if you’ve changed your mind.'),
      primary: tr('Cancel deletion request'), foot: tr('You can cancel within the grace period set by our data policy.'),
    },
    SUSPENDED: {
      icon: 'lock' as const, tone: 'bad' as const, kicker: tr('ACCOUNT UNAVAILABLE'), title: tr('Your account is suspended'),
      body: tr('You can’t use Plans while your account is suspended. If you think this is a mistake, contact support.'),
      primary: tr('Contact support'), foot: null,
    },
  }[me.accountStatus as 'DEACTIVATED' | 'DELETION_REQUESTED' | 'SUSPENDED'];

  if (!content) return null;

  const primary = async () => {
    if (me.accountStatus === 'DEACTIVATED') setConfirm(true);
    else if (me.accountStatus === 'DELETION_REQUESTED') {
      try {
        setUser(await meApi.cancelDeletion());
        toast(tr('Deletion cancelled. Welcome back.'));
      } catch (e) {
        toast(e instanceof ApiError ? e.message : tr('Something went wrong. Try again.'));
      }
    } else {
      // Suspended accounts can’t use in-app reporting, so contact goes by email (or the published business details).
      const to = emailOrNull(business.supportEmail);
      if (to) void Linking.openURL(`mailto:${to}?subject=${encodeURIComponent('Suspended account')}&body=${encodeURIComponent(`

—
Account #${me.id}`)}`);
      else router.push('/legal/business');
    }
  };

  return (
    <Screen edges={['top', 'bottom']}>
      <View style={{ paddingVertical: 16 }}><Logo /></View>
      <View style={{ marginTop: 60, gap: 12 }}>
        <IconTile name={content.icon} tone={content.tone} size={56} />
        <T variant="kicker">{content.kicker}</T>
        <T variant="display" accessibilityRole="header">{content.title}</T>
        <T variant="body" style={{ fontSize: 15, lineHeight: 22 }}>{content.body}</T>
        <View style={{ gap: 8, marginTop: 14 }}>
          <Button label={content.primary} onPress={primary} />
          <Button label={tr('Sign out')} kind="secondary" onPress={signOut} />
          <Button label={tr('Legal & privacy')} kind="text" onPress={() => router.push('/legal')} />
        </View>
        {content.foot ? <T variant="small" style={{ marginTop: 8 }}>{content.foot}</T> : null}
      </View>
      <ConfirmDialog
        visible={confirm}
        onClose={() => setConfirm(false)}
        title={tr('Reactivate your account?')}
        body={tr('Your profile and Plans will be visible again with your current privacy settings.')}
        okLabel={tr('Reactivate')}
        icon="check"
        onConfirm={async () => {
          setUser(await meApi.reactivate());
          toast(tr('Welcome back. Your account is active.'));
        }}
      />
    </Screen>
  );
}

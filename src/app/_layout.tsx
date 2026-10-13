import { DMSans_400Regular, DMSans_500Medium, DMSans_600SemiBold, DMSans_700Bold } from '@expo-google-fonts/dm-sans';
import { Manrope_700Bold, Manrope_800ExtraBold } from '@expo-google-fonts/manrope';
import { useFonts } from 'expo-font';
import { Stack } from 'expo-router';
import { StatusBar } from 'expo-status-bar';
import { View } from 'react-native';
import { SafeAreaProvider } from 'react-native-safe-area-context';
import { useEffect } from 'react';
import { meApi } from '@/api';
import { Backdrop } from '@/components/glass';
import { Logo } from '@/components/ui';
import { AuthProvider, useAuth } from '@/context/AuthContext';
import { ToastProvider } from '@/context/ToastContext';
import { LanguageProvider, useT } from '@/i18n';
import { colors } from '@/theme';

/** Keeps the app language and the account's language setting in step. */
function LanguageSync() {
  const { user, setUser } = useAuth();
  const { lang, setLang } = useT();
  useEffect(() => {
    if (!user) return;
    const server = user.privacy.language;
    if (user.onboarded) {
      if (server !== lang) setLang(server); // the account is the source of truth across devices
    } else if (server !== lang) {
      // A language picked on the welcome screen carries into the new account.
      void meApi.updatePrivacy({ language: lang }).then(setUser).catch(() => undefined);
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [user?.id, user?.onboarded, user?.privacy.language]);
  return null;
}

function Splash() {
  return (
    <View style={{ flex: 1, backgroundColor: colors.paper, alignItems: 'center', justifyContent: 'center' }}>
      <Backdrop />
      <Logo size={24} />
    </View>
  );
}

function RootNavigator() {
  const { ready, user } = useAuth();
  if (!ready) return <Splash />;

  const signedIn = !!user;
  // Restricted accounts can still use the app (with limits); these three states get a dedicated screen.
  const blockedState = !!user && ['DEACTIVATED', 'DELETION_REQUESTED', 'SUSPENDED'].includes(user.accountStatus);
  const onboarded = !!user?.onboarded;

  return (
    <Stack screenOptions={{ headerShown: false, contentStyle: { backgroundColor: colors.paper } }}>
      <Stack.Protected guard={signedIn && !blockedState && onboarded}>
        <Stack.Screen name="(app)" />
      </Stack.Protected>
      <Stack.Protected guard={signedIn && !blockedState && !onboarded}>
        <Stack.Screen name="onboarding/profile" />
        <Stack.Screen name="onboarding/interests" />
        <Stack.Screen name="onboarding/underage" options={{ gestureEnabled: false }} />
      </Stack.Protected>
      <Stack.Protected guard={blockedState}>
        <Stack.Screen name="account-state" />
      </Stack.Protected>
      <Stack.Protected guard={!signedIn}>
        <Stack.Screen name="welcome" />
        <Stack.Screen name="sign-in" />
      </Stack.Protected>
      {/* Policies and business details are readable by everyone, signed in or not. */}
      <Stack.Screen name="legal/index" />
      <Stack.Screen name="legal/[slug]" />
      <Stack.Screen name="legal/business" />
      <Stack.Screen name="legal/licenses" />
      <Stack.Screen name="legal/accessibility" />
    </Stack>
  );
}

export default function RootLayout() {
  const [fontsLoaded] = useFonts({
    Manrope_700Bold, Manrope_800ExtraBold, DMSans_400Regular, DMSans_500Medium, DMSans_600SemiBold, DMSans_700Bold,
  });

  return (
    <SafeAreaProvider>
      <StatusBar style="dark" />
      {fontsLoaded ? (
        <LanguageProvider>
          <AuthProvider>
            <ToastProvider>
              <LanguageSync />
              <RootNavigator />
            </ToastProvider>
          </AuthProvider>
        </LanguageProvider>
      ) : (
        <View style={{ flex: 1, backgroundColor: colors.paper }} />
      )}
    </SafeAreaProvider>
  );
}

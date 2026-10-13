import { router, useLocalSearchParams } from 'expo-router';
import { useEffect, useRef, useState } from 'react';
import { Pressable, StyleSheet, Text, TextInput, View } from 'react-native';
import { ApiError, analyticsApi, authApi, privacyApi, type Channel } from '@/api';
import { ConsentChecks, type ConsentState } from '@/components/ConsentChecks';
import { Banner, Button, Field, Header, Note, Screen, T } from '@/components/ui';
import { useAuth } from '@/context/AuthContext';
import { colors, fonts } from '@/theme';
import { tr, useLanguage, trRich } from '@/i18n';

const CODE_LENGTH = 6;

export default function SignIn() {
  useLanguage();
  const params = useLocalSearchParams<{ mode?: string }>();
  const signup = params.mode !== 'login';
  const { signIn } = useAuth();

  const [stage, setStage] = useState<'credential' | 'otp'>('credential');
  const [channel, setChannel] = useState<Channel>('PHONE');
  const [value, setValue] = useState('');
  const [consent, setConsent] = useState<ConsentState>({ terms: false, adult: false });
  const [consentError, setConsentError] = useState(false);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [code, setCode] = useState('');
  const [resendIn, setResendIn] = useState(0);
  const [devCode, setDevCode] = useState<string | null>(null);
  const codeRef = useRef<TextInput>(null);

  useEffect(() => {
    if (resendIn <= 0) return;
    const t = setInterval(() => setResendIn((s) => Math.max(0, s - 1)), 1000);
    return () => clearInterval(t);
  }, [resendIn]);

  const digits = value.replace(/\D/g, '');
  const destination = channel === 'PHONE' ? `+91${digits}` : value.trim().toLowerCase();
  const valid = channel === 'PHONE' ? digits.length === 10 : /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(value.trim());
  const masked = channel === 'PHONE' ? `+91 ••••••${digits.slice(-4)}` : value.trim().replace(/^(.{1,2}).*(@.*)$/, '$1••••$2');

  const sendCode = async () => {
    if (!valid) {
      setError(channel === 'PHONE' ? tr('Enter a valid 10-digit mobile number.') : tr('Enter a valid email address.'));
      return;
    }
    if (signup && !(consent.terms && consent.adult)) {
      setConsentError(true);
      return;
    }
    setBusy(true);
    setError(null);
    try {
      const res = await authApi.requestOtp(channel, destination);
      setDevCode(res.devCode ?? null);
      setResendIn(res.resendInSeconds);
      setCode('');
      setStage('otp');
      setTimeout(() => codeRef.current?.focus(), 150);
    } catch (e) {
      setError(e instanceof ApiError ? e.message : tr('Couldn’t send a code. Try again.'));
    } finally {
      setBusy(false);
    }
  };

  const verify = async (entered = code) => {
    if (entered.length < CODE_LENGTH) {
      setError(tr('Enter all 6 digits.'));
      return;
    }
    setBusy(true);
    setError(null);
    try {
      const res = await authApi.verifyOtp(channel, destination, entered);
      await signIn(res);
      // Proof of the agreements ticked above. (New accounts made from the sign-in path are asked during onboarding.)
      if (res.newUser && signup) await privacyApi.recordSignup().catch(() => undefined);
      analyticsApi.track(res.newUser ? 'signup_completed' : 'login_completed', { channel });
      // Navigation guards move the user to onboarding or the app automatically.
    } catch (e) {
      setCode('');
      setError(e instanceof ApiError ? e.message : tr('That code didn’t work. Try again.'));
      codeRef.current?.focus();
    } finally {
      setBusy(false);
    }
  };

  if (stage === 'otp') {
    return (
      <Screen edges={['top', 'bottom']}>
        <Header onBack={() => setStage('credential')} />
        <T variant="kicker">{tr('ONE-TIME CODE')}</T>
        <T variant="display" style={{ marginTop: 8, fontSize: 30 }}>{channel === 'PHONE' ? tr('Check your phone.') : tr('Check your email.')}</T>
        <T variant="body" style={{ marginTop: 8 }}>
          {trRich('Enter the 6-digit code sent to {destination}.', { destination: <Text style={{ fontFamily: fonts.bodyBold, color: colors.ink }}>{masked}</Text> })}
        </T>

        <Pressable onPress={() => codeRef.current?.focus()} style={styles.otpRow} accessibilityLabel={tr('6-digit code')}>
          {Array.from({ length: CODE_LENGTH }, (_, i) => (
            <View key={i} style={[styles.otpBox, code.length === i && styles.otpActive, error && styles.otpError]}>
              <Text style={styles.otpDigit}>{code[i] ?? ''}</Text>
            </View>
          ))}
        </Pressable>
        {/* One hidden input drives all six boxes: supports paste and SMS autofill. */}
        <TextInput
          ref={codeRef}
          value={code}
          onChangeText={(t) => {
            const next = t.replace(/\D/g, '').slice(0, CODE_LENGTH);
            setCode(next);
            setError(null);
            if (next.length === CODE_LENGTH) void verify(next);
          }}
          keyboardType="number-pad"
          textContentType="oneTimeCode"
          autoComplete="sms-otp"
          maxLength={CODE_LENGTH}
          style={styles.hiddenInput}
          accessibilityLabel={tr('One-time code')}
        />

        {error ? <View style={{ marginTop: 14 }}><Banner icon="alert-circle" tone="bad" title={error} action={(channel === 'PHONE' ? tr('Change number') : tr('Change email'))} onAction={() => setStage('credential')} /></View> : null}

        <View style={styles.resend}>
          {resendIn > 0 ? (
            <T variant="small">{trRich('Resend code in {time}', { time: <Text style={{ fontFamily: fonts.bodyBold, color: colors.ink }}>0:{String(resendIn).padStart(2, '0')}</Text> })}</T>
          ) : (
            <Button label={tr('Resend code')} kind="text" onPress={sendCode} />
          )}
        </View>

        <Button label={tr('Verify and continue')} iconRight="arrow-right" loading={busy} disabled={code.length < CODE_LENGTH} onPress={() => verify()} />
        <View style={{ marginTop: 16 }}>
          <Note icon="shield">{tr('Never share this code. Plans support will never ask for it.')}</Note>
        </View>
        {devCode ? <T variant="caption" style={{ textAlign: 'center', marginTop: 12 }}>{tr('Development build · code: {code}', { code: devCode })}</T> : null}
      </Screen>
    );
  }

  return (
    <Screen edges={['top', 'bottom']}>
      <Header />
      <T variant="kicker">{signup ? tr('CREATE YOUR ACCOUNT') : tr('WELCOME BACK')}</T>
      <T variant="display" style={{ marginTop: 8, fontSize: 30 }}>{signup ? tr('How should we verify you?') : tr('Sign in to your Plans.')}</T>
      <T variant="body" style={{ marginTop: 8, marginBottom: 18 }}>
        {signup ? tr('Use a mobile number or email. Neither is shown on your profile.') : tr('We’ll send a one-time code—no password to remember.')}
      </T>

      <View style={styles.methods} accessibilityRole="tablist">
        {(['PHONE', 'EMAIL'] as const).map((c) => (
          <Pressable
            key={c}
            accessibilityRole="tab"
            accessibilityState={{ selected: channel === c }}
            onPress={() => { setChannel(c); setValue(''); setError(null); }}
            style={[styles.method, channel === c && styles.methodOn]}
          >
            <Text style={[styles.methodText, channel === c && { color: colors.ink }]}>{c === 'PHONE' ? tr('Phone') : tr('Email')}</Text>
          </Pressable>
        ))}
      </View>

      <Field
        label={channel === 'PHONE' ? tr('Mobile number') : tr('Email address')}
        prefix={channel === 'PHONE' ? '+91' : undefined}
        value={value}
        onChangeText={(t) => { setValue(t); setError(null); }}
        keyboardType={channel === 'PHONE' ? 'phone-pad' : 'email-address'}
        autoCapitalize="none"
        autoComplete={channel === 'PHONE' ? 'tel' : 'email'}
        placeholder={channel === 'PHONE' ? '98765 43210' : tr('you@example.com')}
        error={error}
        autoFocus
        returnKeyType="go"
        onSubmitEditing={sendCode}
      />

      {signup ? (
        <ConsentChecks value={consent} onChange={(v) => { setConsent(v); setConsentError(false); setError(null); }} error={consentError} />
      ) : (
        <T variant="small" style={{ marginBottom: 16 }}>
          {tr('By continuing you agree to our ')}
          <Text style={styles.link} accessibilityRole="link" onPress={() => router.push({ pathname: '/legal/[slug]', params: { slug: 'terms' } })}>{tr('Terms')}</Text>
          {tr(' and ')}
          <Text style={styles.link} accessibilityRole="link" onPress={() => router.push({ pathname: '/legal/[slug]', params: { slug: 'privacy' } })}>{tr('Privacy policy')}</Text>
          {tr('.')}
        </T>
      )}

      <Button label={tr('Continue')} iconRight="arrow-right" loading={busy} disabled={!value.trim()} onPress={sendCode} />
      <Button
        label={signup ? tr('Already have an account? Sign in') : tr('New here? Create an account')}
        kind="text"
        onPress={() => router.setParams({ mode: signup ? 'login' : 'signup' })}
        style={{ marginTop: 8 }}
      />
    </Screen>
  );
}

const styles = StyleSheet.create({
  methods: { flexDirection: 'row', backgroundColor: 'rgba(24,35,33,0.06)', borderRadius: 16, padding: 4, marginBottom: 16, borderWidth: 1, borderColor: 'rgba(255,255,255,0.7)' },
  method: { flex: 1, alignItems: 'center', paddingVertical: 10, borderRadius: 11 },
  methodOn: { backgroundColor: '#fff', shadowColor: '#0c4f40', shadowOpacity: 0.12, shadowRadius: 8, shadowOffset: { width: 0, height: 3 }, elevation: 2 },
  methodText: { fontFamily: fonts.bodyBold, fontSize: 13, color: colors.inkSoft },
  link: { fontFamily: fonts.bodyBold, color: colors.brand, textDecorationLine: 'underline' },
  otpRow: { flexDirection: 'row', gap: 8, marginTop: 24 },
  otpBox: { flex: 1, height: 58, borderRadius: 16, borderWidth: 1, borderColor: colors.inputBorder, backgroundColor: 'rgba(255,255,255,0.88)', alignItems: 'center', justifyContent: 'center' },
  otpActive: { borderColor: colors.brand, borderWidth: 2 },
  otpError: { borderColor: colors.danger },
  otpDigit: { fontFamily: fonts.display, fontSize: 22, color: colors.ink },
  hiddenInput: { position: 'absolute', opacity: 0, width: 1, height: 1 },
  resend: { flexDirection: 'row', justifyContent: 'center', alignItems: 'center', minHeight: 48, marginVertical: 8 },
});

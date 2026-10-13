import * as SecureStore from 'expo-secure-store';
import { createContext, useCallback, useContext, useEffect, useMemo, useState, type ReactNode } from 'react';
import { Platform } from 'react-native';
import { authApi, meApi, type AuthResponse, type Me } from '@/api';
import { configureAuth, setTokens } from '@/api/client';

const KEY = 'plans.tokens';

// SecureStore (Keychain / Keystore) on device; localStorage only for `expo start --web` during development.
const storage = {
  get: async (): Promise<string | null> =>
    Platform.OS === 'web' ? globalThis.localStorage?.getItem(KEY) ?? null : SecureStore.getItemAsync(KEY),
  set: async (v: string) => (Platform.OS === 'web' ? globalThis.localStorage?.setItem(KEY, v) : SecureStore.setItemAsync(KEY, v)),
  clear: async () => (Platform.OS === 'web' ? globalThis.localStorage?.removeItem(KEY) : SecureStore.deleteItemAsync(KEY)),
};

interface Tokens {
  accessToken: string;
  refreshToken: string;
}

interface AuthState {
  ready: boolean;
  user: Me | null;
  sessionExpired: boolean;
  signIn: (res: AuthResponse) => Promise<void>;
  signOut: () => Promise<void>;
  setUser: (user: Me) => void;
  refreshUser: () => Promise<void>;
}

const AuthContext = createContext<AuthState | null>(null);

export function AuthProvider({ children }: { children: ReactNode }) {
  const [ready, setReady] = useState(false);
  const [user, setUser] = useState<Me | null>(null);
  const [tokens, setTokenState] = useState<Tokens | null>(null);
  const [sessionExpired, setSessionExpired] = useState(false);

  const persist = useCallback(async (t: Tokens | null) => {
    setTokens(t);
    setTokenState(t);
    if (t) await storage.set(JSON.stringify(t));
    else await storage.clear();
  }, []);

  useEffect(() => {
    configureAuth({
      onTokensChanged: (t) => void persist(t),
      onSessionExpired: () => {
        setSessionExpired(true);
        setUser(null);
      },
    });
    (async () => {
      const raw = await storage.get();
      if (raw) {
        try {
          const t = JSON.parse(raw) as Tokens;
          setTokens(t);
          setTokenState(t);
          setUser(await meApi.get());
        } catch {
          // Expired/invalid tokens or server unreachable: start signed out instead of blocking on splash.
          await persist(null);
        }
      }
      setReady(true);
    })();
  }, [persist]);

  const signIn = useCallback(
    async (res: AuthResponse) => {
      await persist({ accessToken: res.accessToken, refreshToken: res.refreshToken });
      setSessionExpired(false);
      setUser(res.user);
    },
    [persist],
  );

  const signOut = useCallback(async () => {
    if (tokens) await authApi.logout(tokens.refreshToken).catch(() => undefined);
    await persist(null);
    setUser(null);
  }, [persist, tokens]);

  const refreshUser = useCallback(async () => {
    setUser(await meApi.get());
  }, []);

  const value = useMemo(
    () => ({ ready, user, sessionExpired, signIn, signOut, setUser, refreshUser }),
    [ready, user, sessionExpired, signIn, signOut, refreshUser],
  );

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
}

export function useAuth() {
  const ctx = useContext(AuthContext);
  if (!ctx) throw new Error('useAuth must be used inside AuthProvider');
  return ctx;
}

/** The signed-in user. Only call from screens behind the signed-in guard. */
export function useMe() {
  const { user } = useAuth();
  if (!user) throw new Error('useMe called while signed out');
  return user;
}

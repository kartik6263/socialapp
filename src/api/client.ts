import * as Device from 'expo-device';
import Constants from 'expo-constants';
import { Platform } from 'react-native';
import { translate, translateServer } from '@/i18n';
import type { ApiErrorBody } from './types';

// EXPO_PUBLIC_API_URL wins; otherwise app.json "extra.apiUrl" (10.0.2.2 = host machine from the Android emulator).
export const API_URL: string =
  process.env.EXPO_PUBLIC_API_URL ??
  (Constants.expoConfig?.extra as { apiUrl?: string } | undefined)?.apiUrl ??
  'http://localhost:8080';

export class ApiError extends Error {
  constructor(
    public status: number,
    public code: string,
    message: string,
    public fields?: Record<string, string>,
    public existingId?: number | null,
  ) {
    super(message);
  }

  get isNetwork() {
    return this.status === 0;
  }
}

interface Tokens {
  accessToken: string;
  refreshToken: string;
}

let tokens: Tokens | null = null;
let onTokensChanged: ((t: Tokens | null) => void) | null = null;
let onSessionExpired: (() => void) | null = null;
let refreshing: Promise<boolean> | null = null;

export function configureAuth(opts: { onTokensChanged: (t: Tokens | null) => void; onSessionExpired: () => void }) {
  onTokensChanged = opts.onTokensChanged;
  onSessionExpired = opts.onSessionExpired;
}

export function setTokens(t: Tokens | null) {
  tokens = t;
}

export function getAccessToken() {
  return tokens?.accessToken ?? null;
}

const deviceHeaders = {
  'X-Client-Platform': Platform.OS.toUpperCase(),
  // Model only ("Pixel 7"), not the user-set device name — that often contains the owner's real name.
  'X-Client-Device': Device.modelName ?? Platform.OS,
  'X-Client-Version': Constants.expoConfig?.version ?? '1.0.0',
};

/** Single-flight refresh: concurrent 401s wait on the same rotation. */
async function refresh(): Promise<boolean> {
  if (!tokens?.refreshToken) return false;
  if (!refreshing) {
    const rt = tokens.refreshToken;
    refreshing = (async () => {
      try {
        const res = await fetch(`${API_URL}/api/auth/refresh`, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json', ...deviceHeaders },
          body: JSON.stringify({ refreshToken: rt }),
        });
        if (!res.ok) return false;
        const next = (await res.json()) as Tokens;
        tokens = { accessToken: next.accessToken, refreshToken: next.refreshToken };
        onTokensChanged?.(tokens);
        return true;
      } catch {
        return false;
      } finally {
        refreshing = null;
      }
    })();
  }
  return refreshing;
}

type Method = 'GET' | 'POST' | 'PUT' | 'DELETE';

async function request<T>(method: Method, path: string, body?: unknown, retried = false): Promise<T> {
  const headers: Record<string, string> = { Accept: 'application/json', ...deviceHeaders };
  if (body !== undefined) headers['Content-Type'] = 'application/json';
  if (tokens) headers.Authorization = `Bearer ${tokens.accessToken}`;

  let res: Response;
  try {
    res = await fetch(`${API_URL}${path}`, {
      method,
      headers,
      body: body === undefined ? undefined : JSON.stringify(body),
    });
  } catch {
    throw new ApiError(0, 'NETWORK', translate('You’re offline. Reconnect and try again.'));
  }

  if (res.status === 401 && tokens && !retried) {
    if (await refresh()) return request<T>(method, path, body, true);
    tokens = null;
    onTokensChanged?.(null);
    onSessionExpired?.();
  }

  if (!res.ok) {
    let err: Partial<ApiErrorBody> = {};
    try {
      err = await res.json();
    } catch {
      // non-JSON error body
    }
    // Server messages are English; show them in the user's language when a translation exists.
    throw new ApiError(res.status, err.code ?? 'ERROR', translateServer(err.message ?? 'Something went wrong. Try again.'),
      err.fields && Object.fromEntries(Object.entries(err.fields).map(([k, v]) => [k, translateServer(v)])), err.existingId);
  }

  if (res.status === 204) return undefined as T;
  const text = await res.text();
  return (text ? JSON.parse(text) : undefined) as T;
}

export const http = {
  get: <T>(path: string) => request<T>('GET', path),
  post: <T>(path: string, body?: unknown) => request<T>('POST', path, body ?? {}),
  put: <T>(path: string, body?: unknown) => request<T>('PUT', path, body ?? {}),
  del: <T>(path: string) => request<T>('DELETE', path),
};

export function query(params: Record<string, string | number | boolean | undefined | null>) {
  const parts = Object.entries(params)
    .filter(([, v]) => v !== undefined && v !== null && v !== '')
    .map(([k, v]) => `${encodeURIComponent(k)}=${encodeURIComponent(String(v))}`);
  return parts.length ? `?${parts.join('&')}` : '';
}

import * as SecureStore from 'expo-secure-store';
import { createContext, Fragment, useCallback, useContext, useEffect, useMemo, useState, type ReactNode } from 'react';
import { Platform } from 'react-native';
import hi from './hi';
import kn from './kn';

/**
 * Languages: English is the default and the source of every key; Hindi is fully supported;
 * Kannada is the secondary language — anything not yet translated falls back to English.
 */
export type Lang = 'en' | 'hi' | 'kn';

export const LANGUAGES: { value: Lang; label: string; english: string; secondary?: boolean }[] = [
  { value: 'en', label: 'English', english: 'English' },
  { value: 'hi', label: 'हिन्दी', english: 'Hindi' },
  { value: 'kn', label: 'ಕನ್ನಡ', english: 'Kannada', secondary: true },
];

const DICTS: Record<Lang, Record<string, string>> = { en: {}, hi, kn };
const KEY = 'plans.lang';

// Module-level copy so non-React helpers (date formatting) follow the current language.
let current: Lang = 'en';
export const getLang = () => current;

type Vars = Record<string, string | number | null | undefined>;

function fill(template: string, vars?: Vars) {
  if (!vars) return template;
  return template.replace(/\{(\w+)\}/g, (m, k) => (k in vars ? String(vars[k] ?? '') : m));
}

/** Translate an English source string. Missing translations fall back to English. */
export function translate(key: string, vars?: Vars, lang: Lang = current) {
  return fill(DICTS[lang][key] ?? key, vars);
}

// Patterns for server-generated text with values inside ("That code is incorrect. 2 attempts remaining.").
const patternCache = new Map<Lang, { re: RegExp; names: string[]; key: string }[]>();
function patterns(lang: Lang) {
  let list = patternCache.get(lang);
  if (!list) {
    list = Object.keys(DICTS[lang]).filter((k) => k.includes('{')).map((key) => {
      const names: string[] = [];
      const src = key.replace(/[.*+?^$()|[\]\\]/g, '\\$&').replace(/\\?\{(\w+)\\?\}/g, (_m, n) => {
        names.push(n);
        return '(.+?)';
      });
      return { re: new RegExp(`^${src}$`), names, key };
    });
    patternCache.set(lang, list);
  }
  return list;
}

/** Translate text that arrived from the server: exact match first, then templates with placeholders. */
export function translateServer(text: string | null | undefined, lang: Lang = current): string {
  if (!text) return '';
  if (lang === 'en') return text;
  const exact = DICTS[lang][text];
  if (exact) return exact;
  for (const p of patterns(lang)) {
    const m = text.match(p.re);
    if (m) return fill(DICTS[lang][p.key], Object.fromEntries(p.names.map((n, i) => [n, m[i + 1]])));
  }
  return text;
}

interface I18n {
  lang: Lang;
  setLang: (l: Lang) => void;
  t: (key: string, vars?: Vars) => string;
  /** Like t, but placeholders can be React nodes (bold names, links). */
  tRich: (key: string, vars: Record<string, ReactNode>) => ReactNode;
  ts: (serverText: string | null | undefined) => string;
}

const Ctx = createContext<I18n | null>(null);

const store = {
  get: async () => (Platform.OS === 'web' ? globalThis.localStorage?.getItem(KEY) : SecureStore.getItemAsync(KEY)),
  set: async (v: string) => (Platform.OS === 'web' ? globalThis.localStorage?.setItem(KEY, v) : SecureStore.setItemAsync(KEY, v)),
};

export function LanguageProvider({ children }: { children: ReactNode }) {
  const [lang, setLangState] = useState<Lang>('en');

  useEffect(() => {
    void store.get().then((v) => {
      if (v === 'hi' || v === 'kn' || v === 'en') {
        current = v;
        setLangState(v);
      }
    }).catch(() => undefined);
  }, []);

  const setLang = useCallback((l: Lang) => {
    current = l;
    setLangState(l);
    void store.set(l).catch(() => undefined);
  }, []);

  const value = useMemo<I18n>(() => ({
    lang,
    setLang,
    t: (key, vars) => translate(key, vars, lang),
    ts: (text) => translateServer(text, lang),
    tRich: (key, vars) => {
      const parts = translate(key, undefined, lang).split(/(\{\w+\})/g);
      return parts.map((p, i) => {
        const m = p.match(/^\{(\w+)\}$/);
        return <Fragment key={i}>{m && m[1] in vars ? vars[m[1]] : p}</Fragment>;
      });
    },
  }), [lang, setLang]);

  return <Ctx.Provider value={value}>{children}</Ctx.Provider>;
}

export function useT() {
  const c = useContext(Ctx);
  if (!c) throw new Error('useT outside LanguageProvider');
  return c;
}

/** Short alias used across screens: translates with the current language. */
export const tr = translate;

/**
 * Whole-sentence translation whose placeholders are React nodes (e.g. a bold phone number),
 * so word order can differ per language: trRich('Enter the code sent to {phone}.', { phone: <Bold/> }).
 */
export function trRich(key: string, vars: Record<string, ReactNode>): ReactNode {
  return translate(key).split(/(\{\w+\})/g).map((part, i) => {
    const m = part.match(/^\{(\w+)\}$/);
    return <Fragment key={i}>{m && m[1] in vars ? vars[m[1]] : part}</Fragment>;
  });
}

/**
 * Subscribes a component to language changes so its tr() calls re-render.
 * Call it at the top of any component that renders translated text.
 */
export function useLanguage() {
  return useT().lang;
}

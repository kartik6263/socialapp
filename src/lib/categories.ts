import { useEffect, useState } from 'react';
import { CATEGORIES } from '@/api';
import { http } from '@/api/client';
import { getLang, translate } from '@/i18n';

/** Plan categories are managed in the admin console; each carries its own Hindi and Kannada label. */
export interface Category {
  id: number;
  name: string;
  labelHi?: string | null;
  labelKn?: string | null;
}

// Built-in list until the server answers (first launch, offline). Labels then come from the app dictionary.
let cache: Category[] = CATEGORIES.map((name, i) => ({ id: -i - 1, name }));
let loaded: Promise<Category[]> | null = null;

function load() {
  if (!loaded) {
    loaded = http.get<Category[]>('/api/categories').then((list) => {
      if (list.length) cache = list;
      return cache;
    }).catch(() => {
      loaded = null; // retry next time a screen asks
      return cache;
    });
  }
  return loaded;
}

/** The category name stored on Plans stays English; this is what people see in their language. */
export function categoryLabel(name: string) {
  const lang = getLang();
  const c = cache.find((x) => x.name === name);
  const fromServer = lang === 'hi' ? c?.labelHi : lang === 'kn' ? c?.labelKn : null;
  return fromServer || translate(name);
}

/** Active categories for pickers. Starts with the cached list and refreshes from the server once per launch. */
export function useCategories() {
  const [list, setList] = useState(cache);
  useEffect(() => {
    let live = true;
    void load().then((l) => live && setList(l));
    return () => {
      live = false;
    };
  }, []);
  return list;
}

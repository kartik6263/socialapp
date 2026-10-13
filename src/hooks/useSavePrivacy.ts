import { useState } from 'react';
import { ApiError, meApi, type PrivacySettings } from '@/api';
import { useAuth, useMe } from '@/context/AuthContext';
import { useToast } from '@/context/ToastContext';

/** Optimistic privacy updates with the prototype's offline/server-error banner semantics. */
export function useSavePrivacy() {
  const me = useMe();
  const { setUser } = useAuth();
  const toast = useToast();
  const [saveError, setSaveError] = useState<{ offline: boolean; retry: () => void } | null>(null);

  const save = async (patch: Partial<PrivacySettings>, message?: string) => {
    const previous = me;
    setUser({ ...me, privacy: { ...me.privacy, ...patch } });
    setSaveError(null);
    try {
      setUser(await meApi.updatePrivacy(patch));
      if (message) toast(message);
      return true;
    } catch (e) {
      setUser(previous);
      setSaveError({ offline: e instanceof ApiError && e.isNetwork, retry: () => void save(patch, message) });
      return false;
    }
  };

  return { save, saveError, privacy: me.privacy };
}

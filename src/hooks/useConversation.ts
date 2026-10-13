import { useCallback, useEffect, useRef, useState } from 'react';
import { ApiError, analyticsApi, chatApi, type ConversationDetail, type Message } from '@/api';
import { useAuth } from '@/context/AuthContext';
import { useChatSocket } from './useChatSocket';

export type LocalMessage = Message & { pending?: boolean; failed?: boolean; clientId?: string };

const POLL_MS = 5000;

/**
 * Shared state for direct and group conversations: detail, messages, realtime updates,
 * optimistic sends with retry, and read receipts. Falls back to polling when the socket is down.
 */
export function useConversation(id: number) {
  const { refreshUser, user } = useAuth();
  const myId = user?.id;
  const [detail, setDetail] = useState<ConversationDetail | null>(null);
  const [messages, setMessages] = useState<LocalMessage[]>([]);
  const [firstUnreadId, setFirstUnreadId] = useState<number | null>(null);
  const [error, setError] = useState<ApiError | null>(null);
  const [loading, setLoading] = useState(true);
  const lastId = useRef(0);

  const merge = useCallback((incoming: Message[]) => {
    setMessages((cur) => {
      const byId = new Map(cur.filter((m) => !m.pending || m.failed).map((m) => [m.id, m]));
      for (const m of incoming) byId.set(m.id, m);
      // Drop optimistic copies once the server echo arrives.
      const confirmedText = new Set(incoming.filter((m) => m.mine).map((m) => m.text));
      const list = [...byId.values()].filter((m) => !(m.pending && !m.failed && confirmedText.has(m.text)));
      list.sort((a, b) => (a.pending ? 1 : 0) - (b.pending ? 1 : 0) || a.id - b.id);
      lastId.current = Math.max(lastId.current, ...incoming.map((m) => m.id));
      return list;
    });
  }, []);

  const load = useCallback(async () => {
    try {
      const [d, msgs] = await Promise.all([chatApi.get(id), chatApi.messages(id)]);
      setDetail(d);
      setFirstUnreadId((prev) => prev ?? d.firstUnreadMessageId ?? null);
      merge(msgs);
      setError(null);
      if (d.unread > 0) void chatApi.markRead(id).then(() => refreshUser()).catch(() => undefined);
    } catch (e) {
      setError(e instanceof ApiError ? e : new ApiError(0, 'UNKNOWN', String(e)));
    } finally {
      setLoading(false);
    }
  }, [id, merge, refreshUser]);

  useEffect(() => {
    void load();
  }, [load]);

  const connected = useChatSocket(id, (raw) => {
    // Broadcasts are viewer-agnostic, so ownership is decided here.
    const m = { ...raw, mine: raw.sender?.id === myId };
    merge([m]);
    if (!m.mine) void chatApi.markRead(id).catch(() => undefined);
  });

  useEffect(() => {
    if (connected) return;
    const t = setInterval(() => {
      void chatApi.messages(id).then(merge).catch(() => undefined);
    }, POLL_MS);
    return () => clearInterval(t);
  }, [connected, id, merge]);

  const send = useCallback(
    async (text: string, retryOf?: LocalMessage) => {
      const clientId = retryOf?.clientId ?? `${Date.now()}-${Math.random().toString(36).slice(2)}`;
      const temp: LocalMessage = retryOf
        ? { ...retryOf, failed: false }
        : { id: Number.MAX_SAFE_INTEGER - Date.now(), conversationId: id, mine: true, system: false, removed: false, text, createdAt: new Date().toISOString(), pending: true, clientId };
      setMessages((cur) => [...cur.filter((m) => m.clientId !== clientId), temp]);
      try {
        const saved = await chatApi.send(id, text, clientId);
        setMessages((cur) => cur.filter((m) => m.clientId !== clientId));
        merge([saved]);
        if (!messages.some((m) => m.mine)) analyticsApi.track('first_message_sent');
      } catch {
        setMessages((cur) => cur.map((m) => (m.clientId === clientId ? { ...m, failed: true } : m)));
      }
    },
    [id, merge, messages],
  );

  return { detail, setDetail, messages, firstUnreadId, error, loading, reload: load, send, connected };
}

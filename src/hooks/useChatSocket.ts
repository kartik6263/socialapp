import { Client, type IMessage } from '@stomp/stompjs';
import { useEffect, useRef, useState } from 'react';
import type { Message } from '@/api/types';
import { API_URL, getAccessToken } from '@/api/client';

const WS_URL = API_URL.replace(/^http/, 'ws') + '/ws';

/**
 * Subscribes to /topic/conversations/{id} over STOMP.
 * Returns `connected` so the screen can fall back to polling when the socket is down.
 */
export function useChatSocket(conversationId: number | null, onMessage: (m: Message) => void) {
  const [connected, setConnected] = useState(false);
  const handler = useRef(onMessage);
  handler.current = onMessage;

  useEffect(() => {
    if (!conversationId) return;
    const token = getAccessToken();
    const client = new Client({
      brokerURL: WS_URL,
      connectHeaders: token ? { Authorization: `Bearer ${token}` } : {},
      reconnectDelay: 4000,
      heartbeatIncoming: 10000,
      heartbeatOutgoing: 10000,
      // React Native's WebSocket needs these two flags for STOMP frames to parse correctly.
      forceBinaryWSFrames: true,
      appendMissingNULLonIncoming: true,
      onConnect: () => {
        setConnected(true);
        client.subscribe(`/topic/conversations/${conversationId}`, (frame: IMessage) => {
          try {
            handler.current(JSON.parse(frame.body) as Message);
          } catch {
            // ignore malformed frames
          }
        });
      },
      onWebSocketClose: () => setConnected(false),
      onStompError: () => setConnected(false),
    });
    client.activate();
    return () => {
      setConnected(false);
      void client.deactivate();
    };
  }, [conversationId]);

  return connected;
}

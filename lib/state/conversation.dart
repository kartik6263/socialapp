import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:stomp_dart_client/stomp_dart_client.dart';

import '../api/api.dart';
import '../api/client.dart' show getAccessToken;
import 'auth.dart';

final String _wsUrl = '${apiUrl.replaceFirst(RegExp(r'^http'), 'ws')}/ws';

/// A message as shown in the chat: the server copy, or an optimistic one still sending (or failed).
class LocalMessage {
  final Message m;
  final bool pending;
  final bool failed;
  final String? clientId;
  const LocalMessage(this.m, {this.pending = false, this.failed = false, this.clientId});

  int get id => m.id;
  bool get mine => m.mine;
  bool get system => m.system;
  bool get removed => m.removed;
  String get text => m.text;
  String get createdAt => m.createdAt;
  UserSummary? get sender => m.sender;

  /// Stable key for list items.
  Object get key => clientId ?? m.id;
}

const _pollEvery = Duration(seconds: 5);
// JS Number.MAX_SAFE_INTEGER: temporary ids sort after every real one.
const _maxSafeInt = 9007199254740991;

/// Shared state for direct and group conversations: detail, messages, realtime updates,
/// optimistic sends with retry, and read receipts. Falls back to polling when the socket is down.
class Conversation extends ChangeNotifier {
  final int id;
  final AuthState auth;
  Conversation(this.id, this.auth) {
    load();
    _connect();
    _syncPolling();
  }

  ConversationDetail? detail;
  List<LocalMessage> messages = [];
  int? firstUnreadId;
  ApiError? error;
  bool loading = true;
  bool connected = false;
  bool _disposed = false;

  StompClient? _client;
  Timer? _poll;

  int? get _myId => auth.user?.id;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void setDetail(ConversationDetail d) {
    detail = d;
    _notify();
  }

  void _merge(List<Message> incoming) {
    final cur = messages;
    final byId = <int, LocalMessage>{};
    for (final m in cur.where((m) => !m.pending || m.failed)) {
      byId[m.id] = m;
    }
    for (final m in incoming) {
      byId[m.id] = LocalMessage(m);
    }
    // Drop optimistic copies once the server echo arrives.
    final confirmedText = incoming.where((m) => m.mine).map((m) => m.text).toSet();
    final list = byId.values.where((m) => !(m.pending && !m.failed && confirmedText.contains(m.text))).toList();
    list.sort((a, b) {
      final p = (a.pending ? 1 : 0) - (b.pending ? 1 : 0);
      return p != 0 ? p : a.id.compareTo(b.id);
    });
    messages = list;
    _notify();
  }

  Future<void> load() async {
    try {
      final results = await Future.wait([ChatApi.get(id), ChatApi.messages(id)]);
      final d = results[0] as ConversationDetail;
      final msgs = results[1] as List<Message>;
      detail = d;
      firstUnreadId ??= d.firstUnreadMessageId;
      _merge(msgs);
      error = null;
      if (d.unread > 0) {
        ChatApi.markRead(id).then((_) => auth.refreshUser()).catchError((_) {});
      }
    } catch (e) {
      error = asApiError(e);
    } finally {
      loading = false;
      _notify();
    }
  }

  void _connect() {
    final token = getAccessToken();
    final client = StompClient(
      config: StompConfig(
        url: _wsUrl,
        stompConnectHeaders: token != null ? {'Authorization': 'Bearer $token'} : const {},
        reconnectDelay: const Duration(seconds: 4),
        heartbeatIncoming: const Duration(seconds: 10),
        heartbeatOutgoing: const Duration(seconds: 10),
        onConnect: (_) {
          _setConnected(true);
          _client?.subscribe(
            destination: '/topic/conversations/$id',
            callback: (frame) {
              try {
                final raw = Message(jsonDecode(frame.body ?? '') as Map<String, dynamic>);
                // Broadcasts are viewer-agnostic, so ownership is decided here.
                final mine = raw.sender?.id == _myId;
                _merge([Message({...raw.json, 'mine': mine})]);
                if (!mine) ChatApi.markRead(id).catchError((_) {});
              } catch (_) {
                // ignore malformed frames
              }
            },
          );
        },
        onWebSocketDone: () => _setConnected(false),
        onWebSocketError: (_) => _setConnected(false),
        onStompError: (_) => _setConnected(false),
      ),
    );
    _client = client;
    client.activate();
  }

  void _setConnected(bool v) {
    if (connected == v) return;
    connected = v;
    _syncPolling();
    _notify();
  }

  void _syncPolling() {
    if (connected || _disposed) {
      _poll?.cancel();
      _poll = null;
      return;
    }
    _poll ??= Timer.periodic(_pollEvery, (_) {
      ChatApi.messages(id).then(_merge).catchError((_) {});
    });
  }

  Future<void> send(String text, [LocalMessage? retryOf]) async {
    final clientId = retryOf?.clientId ?? '${DateTime.now().millisecondsSinceEpoch}-${Random().nextInt(1 << 32).toRadixString(36)}';
    final hadMine = messages.any((m) => m.mine);
    final temp = retryOf != null
        ? LocalMessage(retryOf.m, pending: retryOf.pending, failed: false, clientId: clientId)
        : LocalMessage(
            Message({
              'id': _maxSafeInt - DateTime.now().millisecondsSinceEpoch,
              'conversationId': id,
              'mine': true,
              'system': false,
              'removed': false,
              'text': text,
              'createdAt': DateTime.now().toUtc().toIso8601String(),
            }),
            pending: true,
            clientId: clientId,
          );
    messages = [...messages.where((m) => m.clientId != clientId), temp];
    _notify();
    try {
      final saved = await ChatApi.send(id, text, clientId);
      messages = messages.where((m) => m.clientId != clientId).toList();
      _merge([saved]);
      if (!hadMine) AnalyticsApi.track('first_message_sent');
    } catch (_) {
      messages = messages.map((m) => m.clientId == clientId ? LocalMessage(m.m, pending: m.pending, failed: true, clientId: m.clientId) : m).toList();
      _notify();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _poll?.cancel();
    _client?.deactivate();
    super.dispose();
  }
}

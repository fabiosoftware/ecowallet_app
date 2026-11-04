import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../src/domain/services/card_transaction_listener_service.dart';
import 'notification_access.dart';
import 'notification_access_event.dart';
import 'notification_parser.dart';

enum NotificationCaptureStatus {
  unsupported,
  permissionRequired,
  listening,
  error,
}

/// Adapta notificações Android para o fluxo existente de despesas.
///
/// O acesso às notificações só é solicitado após ação explícita do usuário.
/// O texto da notificação é analisado localmente e nunca é registrado em log.
class NotificationExpenseCaptureService {
  NotificationExpenseCaptureService({
    required CardTransactionListenerService cardTransactions,
    NotificationParser parser = const NotificationParser(),
  })  : _cardTransactions = cardTransactions,
        _parser = parser,
        _access = createNotificationAccess();

  final CardTransactionListenerService _cardTransactions;
  final NotificationParser _parser;
  final NotificationAccess _access;
  final ValueNotifier<NotificationCaptureStatus> status =
      ValueNotifier(NotificationCaptureStatus.permissionRequired);
  final Set<String> _seenNotifications = <String>{};

  StreamSubscription<NotificationAccessEvent>? _subscription;
  int _fallbackId = 0;
  bool _disposed = false;

  Future<void> startIfPermissionGranted() async {
    if (!_access.isSupported) {
      status.value = NotificationCaptureStatus.unsupported;
      return;
    }

    try {
      if (await _access.isPermissionGranted()) {
        _listen();
      } else {
        status.value = NotificationCaptureStatus.permissionRequired;
      }
    } catch (error) {
      debugPrint('Não foi possível verificar o acesso às notificações: $error');
      status.value = NotificationCaptureStatus.error;
    }
  }

  Future<bool> requestPermissionAndStart() async {
    if (!_access.isSupported) {
      status.value = NotificationCaptureStatus.unsupported;
      return false;
    }

    try {
      await _access.requestPermission();
      if (!await _access.isPermissionGranted()) {
        status.value = NotificationCaptureStatus.permissionRequired;
        return false;
      }
      _listen();
      return true;
    } catch (error) {
      debugPrint('Não foi possível ativar a captura de notificações: $error');
      status.value = NotificationCaptureStatus.error;
      return false;
    }
  }

  void _listen() {
    if (_disposed || _subscription != null) return;
    _subscription = _access.notifications.listen(
      _handleNotification,
      onError: (Object error, StackTrace stackTrace) {
        debugPrint('Falha ao receber notificações: $error');
        status.value = NotificationCaptureStatus.error;
        _subscription = null;
      },
    );
    status.value = NotificationCaptureStatus.listening;
  }

  void _handleNotification(NotificationAccessEvent event) {
    if (event.hasRemoved || event.onGoing) return;

    final receivedAt = event.timestamp > 0
        ? DateTime.fromMillisecondsSinceEpoch(event.timestamp)
        : DateTime.now();
    final parsed = _parser.parse(
      title: event.title,
      content: event.content,
      timestamp: receivedAt,
    );
    if (parsed == null) return;

    final packageName = event.packageName.trim();
    final fingerprint =
        '$packageName|${event.id}|${parsed.timestamp.millisecondsSinceEpoch}';
    if (!_seenNotifications.add(fingerprint)) return;
    if (_seenNotifications.length > 1000) _seenNotifications.clear();

    _cardTransactions.onCardTransaction(
      CardTransactionEvent(
        id: 'notification_${parsed.timestamp.microsecondsSinceEpoch}_${_fallbackId++}',
        valor: parsed.amount,
        estabelecimento: parsed.merchant,
        timestamp: parsed.timestamp,
        sourceLabel: packageName.isEmpty ? 'notificação bancária' : packageName,
      ),
    );
  }

  Future<void> dispose() async {
    _disposed = true;
    await _subscription?.cancel();
    _subscription = null;
    status.dispose();
  }
}

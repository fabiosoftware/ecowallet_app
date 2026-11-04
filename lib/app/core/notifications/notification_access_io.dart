import 'dart:io';

import 'package:notification_listener_service/notification_event.dart';
import 'package:notification_listener_service/notification_listener_service.dart';

import 'notification_access_event.dart';
import 'notification_access_stub.dart' show NotificationAccess;

export 'notification_access_stub.dart' show NotificationAccess;

NotificationAccess createNotificationAccess() => _AndroidNotificationAccess();

class _AndroidNotificationAccess implements NotificationAccess {
  @override
  bool get isSupported => Platform.isAndroid;

  @override
  Future<bool> isPermissionGranted() async {
    if (!isSupported) return false;
    return NotificationListenerService.isPermissionGranted();
  }

  @override
  Future<bool> requestPermission() async {
    if (!isSupported) return false;
    return NotificationListenerService.requestPermission();
  }

  @override
  Stream<NotificationAccessEvent> get notifications {
    if (!isSupported) return const Stream.empty();
    return NotificationListenerService.notificationsStream.map(_toAccessEvent);
  }

  NotificationAccessEvent _toAccessEvent(ServiceNotificationEvent event) =>
      NotificationAccessEvent(
        id: event.id,
        title: event.title,
        content: event.content,
        packageName: event.packageName,
        timestamp: event.timestamp,
        hasRemoved: event.hasRemoved,
        onGoing: event.onGoing,
      );
}

import 'notification_access_event.dart';

NotificationAccess createNotificationAccess() => _UnsupportedNotificationAccess();

abstract interface class NotificationAccess {
  bool get isSupported;
  Future<bool> isPermissionGranted();
  Future<bool> requestPermission();
  Stream<NotificationAccessEvent> get notifications;
}

class _UnsupportedNotificationAccess implements NotificationAccess {
  @override
  bool get isSupported => false;

  @override
  Future<bool> isPermissionGranted() async => false;

  @override
  Future<bool> requestPermission() async => false;

  @override
  Stream<NotificationAccessEvent> get notifications => const Stream.empty();
}

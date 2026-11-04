class NotificationAccessEvent {
  const NotificationAccessEvent({
    required this.id,
    required this.title,
    required this.content,
    required this.packageName,
    required this.timestamp,
    required this.hasRemoved,
    required this.onGoing,
  });

  final int id;
  final String title;
  final String content;
  final String packageName;
  final int timestamp;
  final bool hasRemoved;
  final bool onGoing;
}

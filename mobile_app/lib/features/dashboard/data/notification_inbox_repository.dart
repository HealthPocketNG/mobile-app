import 'package:healthpocket/core/backend/trusted_backend_client.dart';

class InboxNotification {
  const InboxNotification({
    required this.id,
    required this.category,
    required this.type,
    required this.title,
    required this.body,
    required this.createdAt,
    required this.unread,
    this.previewGroup,
    this.previewTime,
  });

  final String id;
  final String category;
  final String type;
  final String title;
  final String body;
  final DateTime createdAt;
  final bool unread;
  final String? previewGroup;
  final String? previewTime;

  InboxNotification markedRead() => InboxNotification(
    id: id,
    category: category,
    type: type,
    title: title,
    body: body,
    createdAt: createdAt,
    unread: false,
    previewGroup: previewGroup,
    previewTime: previewTime,
  );

  factory InboxNotification.fromBackend(Map<String, dynamic> data) {
    final rawDate = data['createdAt'];
    final date = rawDate is DateTime
        ? rawDate
        : DateTime.tryParse(rawDate?.toString() ?? '');
    if (date == null ||
        data['notificationId'] is! String ||
        data['title'] is! String ||
        data['body'] is! String) {
      throw const FormatException('Invalid notification response.');
    }
    return InboxNotification(
      id: data['notificationId'] as String,
      category: data['category']?.toString() ?? 'system',
      type: data['type']?.toString() ?? '',
      title: data['title'] as String,
      body: data['body'] as String,
      createdAt: date,
      unread: data['readState'] == 'unread',
    );
  }
}

class NotificationInboxRepository {
  const NotificationInboxRepository(this.client);
  final TrustedBackendClient client;

  Future<List<InboxNotification>> list() async {
    final result = await client.call(
      TrustedBackendAction.notificationsList,
      payload: const {'pageSize': 100},
    );
    final raw = result['notifications'];
    if (raw is! List) throw const FormatException('Invalid notification list.');
    return [
      for (final item in raw)
        if (item is Map)
          InboxNotification.fromBackend(Map<String, dynamic>.from(item))
        else
          throw const FormatException('Invalid notification item.'),
    ];
  }

  Future<void> markRead(String id) async {
    await client.call(
      TrustedBackendAction.notificationsMarkRead,
      payload: {'notificationId': id},
    );
  }

  Future<void> markAllRead() async {
    await client.call(TrustedBackendAction.notificationsMarkAllRead);
  }
}

List<InboxNotification> previewNotifications() {
  final now = DateTime.now();
  return [
    InboxNotification(
      id: 'preview-savings',
      category: 'savings',
      type: 'savings_added',
      title: 'Savings added',
      body: 'Your weekly ₦500 contribution has been added to your savings.',
      createdAt: now,
      unread: true,
      previewGroup: 'Today',
      previewTime: '9:14 AM',
    ),
    InboxNotification(
      id: 'preview-family',
      category: 'family_pocket',
      type: 'family_contribution',
      title: 'Mercy contributed',
      body: 'Mercy added ₦500 to The Ayo Family pocket.',
      createdAt: now,
      unread: true,
      previewGroup: 'Today',
      previewTime: '8:30 AM',
    ),
    InboxNotification(
      id: 'preview-payment',
      category: 'payment',
      type: 'payment_successful',
      title: 'Payment successful',
      body: '₦2,500 was sent to Lagoon Clinic.',
      createdAt: now.subtract(const Duration(days: 1)),
      unread: false,
      previewGroup: 'Yesterday',
      previewTime: '4:21 PM',
    ),
    InboxNotification(
      id: 'preview-failed',
      category: 'payment',
      type: 'payment_failed',
      title: 'Payment not completed',
      body: "Sunrise Pharmacy isn't an eligible healthcare provider. Your ₦5,000 is safe in your balance.",
      createdAt: now.subtract(const Duration(days: 1)),
      unread: false,
      previewGroup: 'Yesterday',
      previewTime: '2:14 PM',
    ),
    InboxNotification(
      id: 'preview-streak',
      category: 'savings',
      type: 'streak',
      title: '4-week streak!',
      body: "You've saved every week for a month. Keep the momentum going.",
      createdAt: now.subtract(const Duration(days: 3)),
      unread: false,
      previewGroup: 'Earlier this week',
      previewTime: 'Sept 13',
    ),
    InboxNotification(
      id: 'preview-login',
      category: 'security',
      type: 'new_login',
      title: 'New login detected',
      body: 'A new login from an Android phone in Lagos. Not you?',
      createdAt: now.subtract(const Duration(days: 4)),
      unread: true,
      previewGroup: 'Earlier this week',
      previewTime: 'Sept 12',
    ),
  ];
}

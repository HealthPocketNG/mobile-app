import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:healthpocket/core/state/notification_unread_count.dart';

/// The single notification entry point used across the signed-in app.
class AppNotificationBell extends StatelessWidget {
  const AppNotificationBell({
    required this.onPressed,
    super.key,
    this.iconSize = 24,
    this.tooltip = 'Notifications',
  });

  final VoidCallback onPressed;
  final double iconSize;
  final String tooltip;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<int>(
    valueListenable: NotificationUnreadCount.value,
    builder: (context, unreadCount, _) {
      final hasUnread = unreadCount > 0;
      final badgeLabel = unreadCount > 99 ? '99+' : '$unreadCount';
      return Semantics(
        button: true,
        label: hasUnread
            ? '$tooltip, $unreadCount unread notification${unreadCount == 1 ? '' : 's'}'
            : tooltip,
        child: IconButton(
          tooltip: tooltip,
          onPressed: onPressed,
          icon: Stack(
            clipBehavior: Clip.none,
            children: [
              SvgPicture.asset(
                'assets/dashboard/v2/bell.svg',
                width: iconSize,
                height: iconSize,
              ),
              if (hasUnread)
                Positioned(
                  top: -7,
                  right: -9,
                  child: Container(
                    key: const Key('notification-unread-badge'),
                    constraints: const BoxConstraints(minWidth: 15),
                    height: 15,
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8405F),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                    child: Text(
                      badgeLabel,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        color: Colors.white,
                        fontSize: 8,
                        fontWeight: FontWeight.w700,
                        height: 1,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    },
  );
}

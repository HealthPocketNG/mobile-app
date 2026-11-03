import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:healthpocket/app/app_router.dart';
import 'package:healthpocket/features/dashboard/data/notification_inbox_repository.dart';

abstract final class _NoticeStyle {
  static const navy = Color(0xFF0F1B4C);
  static const teal = Color(0xFF0B7F7A);
  static const muted = Color(0xFF5B6477);
  static const pale = Color(0xFFEEF9F7);
  static const assets = 'assets/dashboard/v2/states/';
}

TextStyle _text(double size, FontWeight weight, Color color) => TextStyle(
  fontFamily: 'Inter',
  fontSize: size,
  fontWeight: weight,
  color: color,
);

enum _NoticeFilter { all, unread, payments, savings, family }

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({
    this.repository,
    this.designPreview = false,
    this.previewEmpty = false,
    super.key,
  });
  final NotificationInboxRepository? repository;
  final bool designPreview;
  final bool previewEmpty;

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  _NoticeFilter _filter = _NoticeFilter.all;
  List<InboxNotification>? _items;
  Object? _error;

  @override
  void initState() {
    super.initState();
    if (widget.designPreview) {
      _items = widget.previewEmpty ? [] : previewNotifications();
    } else {
      _load();
    }
  }

  @override
  void didUpdateWidget(covariant NotificationsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.designPreview &&
        (oldWidget.designPreview != widget.designPreview ||
            oldWidget.previewEmpty != widget.previewEmpty)) {
      _filter = _NoticeFilter.all;
      _items = widget.previewEmpty ? [] : previewNotifications();
      _error = null;
    }
  }

  Future<void> _load() async {
    final repository = widget.repository;
    if (repository == null) {
      setState(() => _items = []);
      return;
    }
    setState(() {
      _items = null;
      _error = null;
    });
    try {
      final items = await repository.list();
      if (mounted) setState(() => _items = items);
    } catch (error) {
      if (mounted) setState(() => _error = error);
    }
  }

  Future<void> _markAll() async {
    final current = _items;
    if (current == null || !current.any((item) => item.unread)) return;
    try {
      if (!widget.designPreview) await widget.repository?.markAllRead();
      if (mounted) {
        setState(
          () => _items = current.map((item) => item.markedRead()).toList(),
        );
      }
    } catch (_) {
      _showError();
    }
  }

  Future<void> _open(InboxNotification item) async {
    if (item.unread) {
      try {
        if (!widget.designPreview) await widget.repository?.markRead(item.id);
        if (mounted) {
          setState(
            () => _items = [
              for (final value in _items ?? <InboxNotification>[])
                value.id == item.id ? value.markedRead() : value,
            ],
          );
        }
      } catch (_) {
        _showError();
        return;
      }
    }
    if (!mounted) return;
    if (item.category == 'security') {
      Navigator.pushNamed(context, AppRoute.profile.path);
    } else if (item.category == 'payment' &&
        item.title == 'Payment successful') {
      Navigator.pushNamed(context, AppRoute.activity.path);
    }
  }

  void _showError() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Could not update notifications. Please try again.'),
      ),
    );
  }

  bool _matches(InboxNotification item) => switch (_filter) {
    _NoticeFilter.all => true,
    _NoticeFilter.unread => item.unread,
    _NoticeFilter.payments =>
      item.category == 'payment' || item.category == 'funding',
    _NoticeFilter.savings => item.category == 'savings',
    _NoticeFilter.family => item.category == 'family_pocket',
  };

  @override
  Widget build(BuildContext context) {
    final items = (_items ?? []).where(_matches).toList();
    final unread = _items?.where((item) => item.unread).length ?? 0;
    final empty = _items != null && _items!.isEmpty;
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1.1,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          bottom: false,
          child: _error != null
              ? _NoticeError(onRetry: _load)
              : _items == null
              ? const Center(child: CircularProgressIndicator())
              : empty
              ? _emptyScreen(context)
              : _populatedScreen(context, items, unread),
        ),
        bottomNavigationBar: empty && _error == null
            ? SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                  child: SizedBox(
                    height: 46,
                    child: TextButton(
                      onPressed: () =>
                          Navigator.pushNamed(context, AppRoute.profile.path),
                      style: TextButton.styleFrom(
                        backgroundColor: const Color(0xFFE4F6F3),
                        shape: const StadiumBorder(),
                      ),
                      child: Text(
                        'Notification settings',
                        style: _text(15, FontWeight.w600, _NoticeStyle.teal),
                      ),
                    ),
                  ),
                ),
              )
            : null,
      ),
    );
  }

  Widget _header(
    BuildContext context, {
    required bool empty,
    int unread = 0,
  }) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            SizedBox(
              width: 28,
              height: 36,
              child: IconButton(
                padding: EdgeInsets.zero,
                onPressed: () => Navigator.of(context).pop(),
                icon: SvgPicture.asset('assets/dashboard/v2/coverage/back.svg'),
              ),
            ),
            if (empty)
              const Spacer()
            else ...[
              Expanded(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: InkWell(
                    onTap: unread == 0 ? null : _markAll,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        'Mark all as read',
                        style: _text(13, FontWeight.w500, _NoticeStyle.teal),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
            ],
            InkWell(
              onTap: () => Navigator.pushNamed(context, AppRoute.profile.path),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                key: const Key('notification-settings-action'),
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFFE4F6F3),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: SvgPicture.asset(
                  '${_NoticeStyle.assets}notification-settings.svg',
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          'Notifications',
          style: _text(26, FontWeight.w700, _NoticeStyle.teal),
        ),
        Text(
          empty
              ? 'Nothing new right now.'
              : unread == 0
              ? 'Nothing new right now.'
              : 'You have $unread new ${unread == 1 ? 'update' : 'updates'}.',
          style: _text(13, FontWeight.w400, _NoticeStyle.muted),
        ),
      ],
    ),
  );

  Widget _emptyScreen(BuildContext context) => Column(
    children: [
      _header(context, empty: true),
      const SizedBox(height: 75),
      SizedBox(
        width: 220,
        height: 180,
        child: Center(
          child: Image.asset(
            '${_NoticeStyle.assets}notifications-empty-bell.png',
            width: 180,
            height: 180,
          ),
        ),
      ),
      const SizedBox(height: 17),
      Text(
        "You're all caught up",
        textAlign: TextAlign.center,
        style: _text(20, FontWeight.w700, _NoticeStyle.navy),
      ),
      const SizedBox(height: 6),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 25),
        child: Text(
          'Updates about your savings, payments\nand family pockets will show up here.',
          textAlign: TextAlign.center,
          style: _text(
            13.5,
            FontWeight.w400,
            _NoticeStyle.muted,
          ).copyWith(height: 1.5),
        ),
      ),
    ],
  );

  Widget _populatedScreen(
    BuildContext context,
    List<InboxNotification> items,
    int unread,
  ) {
    String? lastGroup;
    final rows = <Widget>[];
    for (final item in items) {
      final group = item.previewGroup ?? _dateGroup(item.createdAt);
      if (group != lastGroup) {
        rows.add(
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 2),
            child: Text(
              group,
              style: _text(13, FontWeight.w700, _NoticeStyle.muted),
            ),
          ),
        );
        lastGroup = group;
      }
      rows.add(
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
          child: _NoticeRow(item: item, onTap: () => _open(item)),
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        _header(context, empty: false, unread: unread),
        const SizedBox(height: 9),
        SizedBox(
          height: 32,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            scrollDirection: Axis.horizontal,
            itemCount: _NoticeFilter.values.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final value = _NoticeFilter.values[index];
              final selected = value == _filter;
              final label = switch (value) {
                _NoticeFilter.all => 'All',
                _NoticeFilter.unread => 'Unread',
                _NoticeFilter.payments => 'Payments',
                _NoticeFilter.savings => 'Savings',
                _NoticeFilter.family => 'Family',
              };
              return InkWell(
                onTap: () => setState(() => _filter = value),
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: selected
                        ? _NoticeStyle.teal
                        : const Color(0xFFF0F3F5),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    label,
                    style: _text(
                      12,
                      selected ? FontWeight.w600 : FontWeight.w400,
                      selected ? Colors.white : _NoticeStyle.navy,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        if (rows.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 80, 20, 0),
            child: Column(
              children: [
                Image.asset(
                  '${_NoticeStyle.assets}notifications-empty-bell.png',
                  width: 176,
                ),
                const SizedBox(height: 12),
                Text(
                  'No notifications in this filter',
                  textAlign: TextAlign.center,
                  style: _text(17, FontWeight.w700, _NoticeStyle.navy),
                ),
              ],
            ),
          )
        else
          ...rows,
      ],
    );
  }
}

class _NoticeRow extends StatelessWidget {
  const _NoticeRow({required this.item, required this.onTap});
  final InboxNotification item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final kind = _iconKind(item);
    final asset = switch (kind) {
      'family' => 'notice-family.svg',
      'payment-success' => 'notice-payment-success.svg',
      'payment-failed' => 'notice-payment-failed.svg',
      'streak' => 'notice-streak.svg',
      'security' => 'notice-security.svg',
      _ => 'notice-savings.svg',
    };
    final tint = kind == 'payment-success' || kind == 'payment-failed'
        ? const Color(0xFFFDE8EE)
        : kind == 'streak' || kind == 'security'
        ? const Color(0xFFFFEBC8)
        : const Color(0xFFE4F6F3);
    final action = item.category == 'security'
        ? 'Secure my account'
        : kind == 'payment-success'
        ? 'View receipt'
        : null;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(12, 13, 12, 11),
        decoration: BoxDecoration(
          color: item.unread ? _NoticeStyle.pale : Colors.white,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: tint, shape: BoxShape.circle),
              child: SvgPicture.asset('${_NoticeStyle.assets}$asset'),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: _text(
                            14.5,
                            item.unread ? FontWeight.w700 : FontWeight.w600,
                            _NoticeStyle.navy,
                          ),
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        item.previewTime ?? _time(item.createdAt),
                        style: _text(
                          11.5,
                          item.unread ? FontWeight.w500 : FontWeight.w400,
                          item.unread ? _NoticeStyle.teal : _NoticeStyle.muted,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  if (item.id == 'preview-family')
                    SizedBox(
                      width: double.infinity,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          item.body,
                          style: _text(
                            12.5,
                            FontWeight.w400,
                            _NoticeStyle.muted,
                          ),
                        ),
                      ),
                    )
                  else
                    Text(
                      item.body,
                      style: _text(
                        12.5,
                        FontWeight.w400,
                        _NoticeStyle.muted,
                      ).copyWith(height: 1.45),
                    ),
                  if (action != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      action,
                      style: _text(12.5, FontWeight.w600, _NoticeStyle.teal),
                    ),
                  ],
                ],
              ),
            ),
            if (item.unread) ...[
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Color(0xFF13A39B),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _NoticeError extends StatelessWidget {
  const _NoticeError({required this.onRetry});
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Could not load notifications',
          style: _text(18, FontWeight.w700, _NoticeStyle.navy),
        ),
        const SizedBox(height: 8),
        TextButton(onPressed: onRetry, child: const Text('Retry')),
      ],
    ),
  );
}

String _iconKind(InboxNotification item) {
  if (item.category == 'family_pocket') return 'family';
  if (item.category == 'security') return 'security';
  if (item.type.contains('streak')) return 'streak';
  if (item.category == 'payment') {
    return item.type.contains('fail') ||
            item.title.toLowerCase().contains('not completed')
        ? 'payment-failed'
        : 'payment-success';
  }
  return 'savings';
}

String _dateGroup(DateTime date) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(date.year, date.month, date.day);
  final difference = today.difference(day).inDays;
  if (difference <= 0) return 'Today';
  if (difference == 1) return 'Yesterday';
  if (difference < 7) return 'Earlier this week';
  return '${date.day}/${date.month}/${date.year}';
}

String _time(DateTime date) {
  final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
  final minute = date.minute.toString().padLeft(2, '0');
  return '$hour:$minute ${date.hour < 12 ? 'AM' : 'PM'}';
}

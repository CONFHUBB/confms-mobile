import 'package:confms_mobile/constants/app_theme.dart';
import 'package:confms_mobile/constants/dimensions.dart';
import 'package:confms_mobile/features/main_shell/widgets/main_tab_scaffold.dart';
import 'package:confms_mobile/features/main_shell/widgets/shell_shared_widgets.dart';
import 'package:confms_mobile/models/auth_user.dart';
import 'package:confms_mobile/services/mobile_feature_service.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class NotificationsTab extends StatefulWidget {
  const NotificationsTab({
    super.key,
    required this.featureService,
    required this.user,
    this.onMenuTap,
  });

  final MobileFeatureService featureService;
  final AuthUser? user;
  final VoidCallback? onMenuTap;

  @override
  State<NotificationsTab> createState() => _NotificationsTabState();
}

class _NotificationsTabState extends State<NotificationsTab> {
  List<NotificationPreview> _items = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    final userId = widget.user?.id;
    if (userId == null) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final data = await widget.featureService.getNotifications(userId: userId);
      if (!mounted) return;
      setState(() {
        _items = data;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _markAsRead(int index) {
    final n = _items[index];
    if (n.isRead) return;

    // Optimistic update
    setState(() {
      _items = List.from(_items);
      _items[index] = NotificationPreview(
        id: n.id,
        title: n.title,
        message: n.message,
        deepLinkHint: n.deepLinkHint,
        isRead: true,
        type: n.type,
        createdAt: n.createdAt,
      );
    });

    // Fire-and-forget
    widget.featureService.markNotificationRead(notificationId: n.id);
  }

  Future<void> _markAllRead() async {
    final userId = widget.user?.id;
    if (userId == null) return;

    // Optimistic update
    setState(() {
      _items = _items.map((n) => NotificationPreview(
        id: n.id,
        title: n.title,
        message: n.message,
        deepLinkHint: n.deepLinkHint,
        isRead: true,
        type: n.type,
        createdAt: n.createdAt,
      )).toList();
    });

    await widget.featureService.markAllNotificationsRead(userId: userId);
  }

  int get _unreadCount => _items.where((n) => !n.isRead).length;

  @override
  Widget build(BuildContext context) {
    final userId = widget.user?.id;

    return MainTabScaffold(
      title: 'Notifications',
      subtitle: 'Stay updated on your conferences.',
      icon: Icons.notifications_rounded,
      user: widget.user,
      onMenuTap: widget.onMenuTap,
      body: userId == null
          ? const CenteredMutedText('Missing user context.')
          : _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return SectionError(message: _error!);
    }

    return RefreshIndicator(
      onRefresh: _loadNotifications,
      child: _items.isEmpty
          ? _buildEmpty(context)
          : _buildList(context),
    );
  }

  Widget _buildEmpty(BuildContext context) {
    return ListView(
      children: [
        const SizedBox(height: 80),
        Column(
          children: [
            Icon(
              Icons.notifications_off_rounded,
              size: 56,
              color: context.scheme.onSurfaceVariant.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 12),
            Text(
              'No notifications yet',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: context.scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'You\'ll receive updates about your\nconferences, papers, and tickets here.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: context.scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildList(BuildContext context) {
    return Column(
      children: [
        // Mark all read bar
        if (_unreadCount > 0)
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimensions.screenPadding,
              vertical: 8,
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: context.scheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '$_unreadCount unread',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: context.scheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: _markAllRead,
                  icon: const Icon(Icons.done_all_rounded, size: 16),
                  label: const Text('Mark all read'),
                  style: TextButton.styleFrom(
                    foregroundColor: context.scheme.primary,
                    textStyle: Theme.of(context).textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    minimumSize: const Size(0, 32),
                  ),
                ),
              ],
            ),
          ),
        // Notification list
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimensions.screenPadding,
            ),
            itemCount: _items.length,
            itemBuilder: (context, index) {
              final n = _items[index];
              return _NotificationCard(
                notification: n,
                onTap: () {
                  _markAsRead(index);
                  _showNotificationDetail(context, n);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  void _showNotificationDetail(
    BuildContext context,
    NotificationPreview n,
  ) {
    final iconData = _NotificationCard.resolveIcon(n);
    final iconColor = _NotificationCard.resolveColor(n, context);
    final timeLabel = _formatTime(n.createdAt);

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.55,
        minChildSize: 0.35,
        maxChildSize: 0.85,
        expand: false,
        builder: (_, controller) => ListView(
          controller: controller,
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: context.scheme.onSurfaceVariant.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            // Icon + title
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(iconData, size: 22, color: iconColor),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        n.title,
                        style: Theme.of(ctx)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      if (timeLabel.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.access_time_rounded,
                              size: 12,
                              color: context.scheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              timeLabel,
                              style: Theme.of(ctx)
                                  .textTheme
                                  .labelSmall
                                  ?.copyWith(
                                    color: context.scheme.onSurfaceVariant,
                                  ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 16),
            // Full message
            Text(
              n.message,
              style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
                height: 1.6,
              ),
            ),
            if (n.type.isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: context.scheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.label_outline_rounded,
                      size: 14,
                      color: context.scheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Type: ${n.type.replaceAll('_', ' ')}',
                      style: Theme.of(ctx)
                          .textTheme
                          .labelSmall
                          ?.copyWith(
                            color: context.scheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatTime(String raw) {
    if (raw.isEmpty) return '';
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return raw;
    final now = DateTime.now();
    final diff = now.difference(parsed);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return DateFormat('MMM d, yyyy').format(parsed);
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({
    required this.notification,
    required this.onTap,
  });

  final NotificationPreview notification;
  final VoidCallback onTap;

  static IconData resolveIcon(NotificationPreview n) {
    final type = n.type.toUpperCase();
    final title = n.title.toLowerCase();

    if (type.contains('PAPER_SUBMIT')) return Icons.upload_file_rounded;
    if (type.contains('PAPER_WITHDRAW')) return Icons.remove_circle_outline_rounded;
    if (type.contains('PAPER')) return Icons.article_rounded;
    if (type.contains('REVIEW')) return Icons.rate_review_rounded;
    if (type.contains('DEADLINE')) return Icons.timer_rounded;
    if (type.contains('INVITE') || type.contains('INVITATION')) return Icons.mail_rounded;
    if (type.contains('TICKET') || type.contains('REGISTRATION')) return Icons.confirmation_num_rounded;
    if (type.contains('PAYMENT')) return Icons.payment_rounded;
    if (type.contains('CONFERENCE')) return Icons.groups_rounded;
    if (type.contains('CAMERA_READY')) return Icons.camera_rounded;
    if (type.contains('DECISION') || type.contains('NOTIFICATION')) return Icons.gavel_rounded;

    if (title.contains('submitted') || title.contains('submission')) return Icons.upload_file_rounded;
    if (title.contains('withdrawn') || title.contains('withdraw')) return Icons.remove_circle_outline_rounded;
    if (title.contains('paper')) return Icons.article_rounded;
    if (title.contains('review')) return Icons.rate_review_rounded;
    if (title.contains('deadline')) return Icons.timer_rounded;
    if (title.contains('invited') || title.contains('invitation')) return Icons.mail_rounded;
    if (title.contains('ticket')) return Icons.confirmation_num_rounded;
    if (title.contains('payment')) return Icons.payment_rounded;
    if (title.contains('conference')) return Icons.groups_rounded;
    if (title.contains('camera')) return Icons.camera_rounded;
    if (title.contains('decision') || title.contains('accepted') || title.contains('rejected')) {
      return Icons.gavel_rounded;
    }

    return Icons.notifications_rounded;
  }

  static Color resolveColor(NotificationPreview n, BuildContext context) {
    final type = n.type.toUpperCase();
    final title = n.title.toLowerCase();

    if (type.contains('PAPER_SUBMIT') || title.contains('submitted')) return Colors.green;
    if (type.contains('PAPER_WITHDRAW') || title.contains('withdrawn')) return Colors.red;
    if (type.contains('PAPER')) return Colors.indigo;
    if (type.contains('REVIEW')) return Colors.orange;
    if (type.contains('DEADLINE')) return Colors.deepOrange;
    if (type.contains('INVITE') || title.contains('invited')) return Colors.purple;
    if (type.contains('TICKET') || type.contains('REGISTRATION')) return Colors.teal;
    if (type.contains('PAYMENT')) return Colors.amber.shade700;

    if (!n.isRead) return context.scheme.primary;
    return context.scheme.onSurfaceVariant;
  }

  @override
  Widget build(BuildContext context) {
    final accent = resolveColor(notification, context);
    final icon = resolveIcon(notification);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: notification.isRead
                ? context.scheme.surface
                : context.scheme.primaryContainer.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: notification.isRead
                  ? context.tokens.cardBorder
                  : context.scheme.primary.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 18, color: accent),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            notification.title,
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(
                                  fontSize: 14,
                                  fontWeight: notification.isRead
                                      ? FontWeight.w500
                                      : FontWeight.w700,
                                ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (!notification.isRead) ...[
                          const SizedBox(width: 6),
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: context.scheme.primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      notification.message,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: context.scheme.onSurfaceVariant,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Text(
                          'Tap to read more',
                          style: Theme.of(context)
                              .textTheme
                              .labelSmall
                              ?.copyWith(
                                color: context.scheme.primary,
                                fontWeight: FontWeight.w600,
                                fontSize: 10,
                              ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 10,
                          color: context.scheme.primary,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

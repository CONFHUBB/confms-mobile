import 'package:confms_mobile/constants/app_theme.dart';
import 'package:confms_mobile/constants/dimensions.dart';
import 'package:confms_mobile/features/main_shell/widgets/main_tab_scaffold.dart';
import 'package:confms_mobile/features/main_shell/widgets/shell_shared_widgets.dart';
import 'package:confms_mobile/models/auth_user.dart';
import 'package:confms_mobile/services/mobile_feature_service.dart';
import 'package:flutter/material.dart';

/// Reviewer workspace — shows all papers assigned for review, grouped by
/// conference, with review status badges.
class MyReviewsTab extends StatefulWidget {
  const MyReviewsTab({
    super.key,
    required this.featureService,
    required this.user,
    this.onMenuTap,
  });

  final MobileFeatureService featureService;
  final AuthUser? user;
  final VoidCallback? onMenuTap;

  @override
  State<MyReviewsTab> createState() => _MyReviewsTabState();
}

class _MyReviewsTabState extends State<MyReviewsTab> {
  String _filter = 'all'; // all, pending, completed

  @override
  Widget build(BuildContext context) {
    final userId = widget.user?.id;

    return MainTabScaffold(
      title: 'My Reviews',
      subtitle: 'Papers assigned for your review.',
      icon: Icons.rate_review_rounded,
      user: widget.user,
      onMenuTap: widget.onMenuTap,
      body: userId == null
          ? const CenteredMutedText('Missing user context.')
          : _buildBody(userId),
    );
  }

  Widget _buildBody(int userId) {
    return FutureBuilder<List<TaskPreview>>(
      future: widget.featureService.getPendingReviews(userId: userId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return SectionError(message: snapshot.error.toString());
        }

        final all = snapshot.data ?? const <TaskPreview>[];

        if (all.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.rate_review_outlined,
                    size: 56,
                    color: context.scheme.onSurfaceVariant
                        .withValues(alpha: 0.4),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'No reviews assigned',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(
                          color: context.scheme.onSurfaceVariant,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'You don\'t have any papers\nassigned for review yet.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: context.scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        final filtered = all.where((t) {
          final status = _extractStatus(t.subtitle);
          if (_filter == 'all') return true;
          if (_filter == 'pending') {
            return status == 'PENDING' || status == 'IN_PROGRESS';
          }
          if (_filter == 'completed') {
            return status == 'COMPLETED' || status == 'SUBMITTED';
          }
          return true;
        }).toList();

        final pendingCount = all
            .where((t) {
              final s = _extractStatus(t.subtitle);
              return s == 'PENDING' || s == 'IN_PROGRESS';
            })
            .length;
        final completedCount = all.length - pendingCount;

        return RefreshIndicator(
          onRefresh: () async => setState(() {}),
          child: ListView(
            padding: const EdgeInsets.all(AppDimensions.screenPadding),
            children: [
              // Stats
              Row(
                children: [
                  Expanded(
                    child: _ReviewStat(
                      label: 'Total',
                      value: '${all.length}',
                      color: Colors.indigo,
                      icon: Icons.rate_review_rounded,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _ReviewStat(
                      label: 'Pending',
                      value: '$pendingCount',
                      color: Colors.orange,
                      icon: Icons.pending_actions_rounded,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _ReviewStat(
                      label: 'Done',
                      value: '$completedCount',
                      color: Colors.green,
                      icon: Icons.check_circle_rounded,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppDimensions.space3),
              // Filter chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _FilterChip(
                      label: 'All (${all.length})',
                      selected: _filter == 'all',
                      onTap: () => setState(() => _filter = 'all'),
                    ),
                    _FilterChip(
                      label: 'Pending ($pendingCount)',
                      selected: _filter == 'pending',
                      onTap: () => setState(() => _filter = 'pending'),
                    ),
                    _FilterChip(
                      label: 'Completed ($completedCount)',
                      selected: _filter == 'completed',
                      onTap: () => setState(() => _filter = 'completed'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppDimensions.space3),
              if (filtered.isEmpty)
                const CenteredMutedText(
                  'No reviews match this filter.',
                )
              else
                ...filtered.map(
                  (task) => Padding(
                    padding:
                        const EdgeInsets.only(bottom: AppDimensions.space2),
                    child: _ReviewCard(task: task),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  String _extractStatus(String subtitle) {
    // subtitle format: "Conference Name • Status: PENDING"
    final match = RegExp(r'Status:\s*(\S+)').firstMatch(subtitle);
    return match?.group(1)?.toUpperCase() ?? 'PENDING';
  }
}

class _ReviewStat extends StatelessWidget {
  const _ReviewStat({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  final String label;
  final String value;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(height: 4),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          Text(label, style: Theme.of(context).textTheme.labelSmall),
        ],
      ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({required this.task});

  final TaskPreview task;

  Color _statusColor(String status) {
    switch (status) {
      case 'PENDING':
      case 'IN_PROGRESS':
        return Colors.orange;
      case 'COMPLETED':
      case 'SUBMITTED':
        return Colors.green;
      case 'REJECTED':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _extractStatus(String subtitle) {
    final match = RegExp(r'Status:\s*(\S+)').firstMatch(subtitle);
    return match?.group(1)?.toUpperCase() ?? 'PENDING';
  }

  String _extractConference(String subtitle) {
    final parts = subtitle.split('•');
    return parts.isNotEmpty ? parts.first.trim() : subtitle;
  }

  @override
  Widget build(BuildContext context) {
    final status = _extractStatus(task.subtitle);
    final conference = _extractConference(task.subtitle);
    final color = _statusColor(status);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.scheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.tokens.cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  status == 'COMPLETED' || status == 'SUBMITTED'
                      ? Icons.check_circle_rounded
                      : Icons.pending_actions_rounded,
                  color: color,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.title,
                      style:
                          Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      conference,
                      style:
                          Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: context.scheme.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: color.withValues(alpha: 0.3)),
                ),
                child: Text(
                  status.replaceAll('_', ' '),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w700,
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: context.scheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  size: 14,
                  color: context.scheme.onSurfaceVariant,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Submit your review on the web app',
                    style:
                        Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: context.scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        selected: selected,
        showCheckmark: false,
        onSelected: (_) => onTap(),
        label: Text(label),
      ),
    );
  }
}

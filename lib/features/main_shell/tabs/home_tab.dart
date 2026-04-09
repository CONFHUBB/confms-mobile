import 'package:confms_mobile/constants/app_theme.dart';
import 'package:confms_mobile/constants/dimensions.dart';
import 'package:confms_mobile/features/main_shell/widgets/main_tab_scaffold.dart';
import 'package:confms_mobile/features/main_shell/widgets/shell_shared_widgets.dart';
import 'package:confms_mobile/models/auth_user.dart';
import 'package:confms_mobile/services/mobile_feature_service.dart';
import 'package:flutter/material.dart';

                      class HomeTab extends StatelessWidget {
                        const HomeTab({
                          super.key,
                          required this.featureService,
                          required this.user,
                          this.onMenuTap,
                        });

                        final MobileFeatureService featureService;
                        final AuthUser? user;
                        final VoidCallback? onMenuTap;

                        @override
                        Widget build(BuildContext context) {
                          final userId = user?.id;
                          if (userId == null) {
                            return MainTabScaffold(
                              title: 'Home',
                              subtitle: 'Conference highlights and quick updates.',
                              icon: Icons.home_rounded,
                              user: user,
                              onMenuTap: onMenuTap,
                              body: const CenteredMutedText('No user context available.'),
                            );
                          }

                          return MainTabScaffold(
                            title: 'Home',
                            subtitle: 'Welcome, ${user?.firstName ?? 'User'}',
                            icon: Icons.space_dashboard_rounded,
                            user: user,
                            onMenuTap: onMenuTap,
                            body: FutureBuilder<_HomeData>(
                              future: _loadHomeData(userId),
                              builder: (context, snapshot) {
                                if (snapshot.connectionState == ConnectionState.waiting) {
                                  return const Center(child: CircularProgressIndicator());
                                }
                                if (snapshot.hasError) {
                                  return SectionError(message: snapshot.error.toString());
                                }

                                final data = snapshot.data;
                                if (data == null) {
                                  return const CenteredMutedText('No home data available.');
                                }

                                return RefreshIndicator(
                                  onRefresh: () async {
                                    await _loadHomeData(userId);
                                  },
                                  child: ListView(
                                    padding: const EdgeInsets.all(AppDimensions.screenPadding),
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: _QuickStatCard(
                                              icon: Icons.event_rounded,
                                              label: 'Conferences',
                                              value: '${data.activeConferences.length}',
                                              color: Colors.indigo,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: _QuickStatCard(
                                              icon: Icons.article_rounded,
                                              label: 'Papers',
                                              value: '${data.paperCount}',
                                              color: Colors.teal,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: _QuickStatCard(
                                              icon: Icons.confirmation_num_rounded,
                                              label: 'Tickets',
                                              value: '${data.ticketCount}',
                                              color: Colors.orange,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: AppDimensions.space4),
                                      if (data.ticketCount > 0) ...[
                                        _buildSummaryCard(
                                          context,
                                          icon: Icons.confirmation_num_rounded,
                                          title: 'My Tickets',
                                          count: data.ticketCount,
                                          status: '${data.paidCount} paid · ${data.pendingCount} pending',
                                          color: Colors.indigo,
                                        ),
                                        const SizedBox(height: 12),
                                      ],
                                      if (data.paperCount > 0) ...[
                                        _buildSummaryCard(
                                          context,
                                          icon: Icons.article_rounded,
                                          title: 'My Papers',
                                          count: data.paperCount,
                                          status: '${data.acceptedCount} accepted · ${data.underReviewCount} reviewing',
                                          color: Colors.teal,
                                        ),
                                        const SizedBox(height: AppDimensions.space4),
                                      ],
                                      _SectionHeader(title: 'Active Conferences'),
                                      const SizedBox(height: 8),
                                      if (data.activeConferences.isEmpty)
                                        Container(
                                          padding: const EdgeInsets.all(24),
                                          decoration: BoxDecoration(
                                            color: context.scheme.surfaceContainerLow,
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Column(
                                            children: [
                                              Icon(
                                                Icons.event_busy_rounded,
                                                size: 40,
                                                color: context.scheme.onSurfaceVariant,
                                              ),
                                              const SizedBox(height: 8),
                                              Text(
                                                'No active conferences',
                                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                                      color: context.scheme.onSurfaceVariant,
                                                    ),
                                              ),
                                            ],
                                          ),
                                        )
                                      else
                                        ...data.activeConferences.map(
                                          (conf) => _buildConferenceCard(context, conf),
                                        ),
                                      const SizedBox(height: AppDimensions.space4),
                                      _SectionHeader(title: 'Recent Notifications'),
                                      const SizedBox(height: 8),
                                      if (data.recentNotifications.isEmpty)
                                        Container(
                                          padding: const EdgeInsets.all(24),
                                          decoration: BoxDecoration(
                                            color: context.scheme.surfaceContainerLow,
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Column(
                                            children: [
                                              Icon(
                                                Icons.notifications_off_rounded,
                                                size: 40,
                                                color: context.scheme.onSurfaceVariant,
                                              ),
                                              const SizedBox(height: 8),
                                              Text(
                                                'No recent notifications',
                                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                                      color: context.scheme.onSurfaceVariant,
                                                    ),
                                              ),
                                            ],
                                          ),
                                        )
                                      else
                                        ...data.recentNotifications.map(
                                          (n) => Container(
                                            margin: const EdgeInsets.only(bottom: 8),
                                            padding: const EdgeInsets.all(12),
                                            decoration: BoxDecoration(
                                              color: n.isRead
                                                  ? context.scheme.surface
                                                  : context.scheme.primaryContainer.withValues(alpha: 0.15),
                                              borderRadius: BorderRadius.circular(10),
                                              border: Border.all(color: context.tokens.cardBorder),
                                            ),
                                            child: Row(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                if (!n.isRead)
                                                  Container(
                                                    width: 8,
                                                    height: 8,
                                                    margin: const EdgeInsets.only(top: 5, right: 8),
                                                    decoration: BoxDecoration(
                                                      color: context.scheme.primary,
                                                      shape: BoxShape.circle,
                                                    ),
                                                  ),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Text(
                                                        n.title,
                                                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                                              fontWeight: FontWeight.w600,
                                                            ),
                                                        maxLines: 1,
                                                        overflow: TextOverflow.ellipsis,
                                                      ),
                                                      const SizedBox(height: 2),
                                                      Text(
                                                        n.message,
                                                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                                              color: context.scheme.onSurfaceVariant,
                                                            ),
                                                        maxLines: 2,
                                                        overflow: TextOverflow.ellipsis,
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      const SizedBox(height: AppDimensions.space6),
                                    ],
                                  ),
                                );
                              },
                            ),
                          );
                        }

                        Future<_HomeData> _loadHomeData(int userId) async {
                          final tickets = await featureService.getMyTickets(userId: userId);
                          final conferences = await featureService.getAuthorConferences(userId: userId);
                          final notifications = await featureService.getNotifications(userId: userId);

                          final activeConfs = conferences
                              .where((c) => c.status.toLowerCase() == 'active' || c.status.toLowerCase() == 'ongoing')
                              .toList();

                          final paperGroups = await Future.wait(
                            conferences.map(
                              (conf) => featureService.getAuthorPapersByConference(
                                userId: userId,
                                conferenceId: conf.conferenceId,
                              ),
                            ),
                          );
                          final allPapers = paperGroups.expand((e) => e).toList();

                          final accepted = allPapers.where((p) {
                            final status = p.status.toUpperCase();
                            return status == 'ACCEPTED' || status == 'PUBLISHED' || status == 'CAMERA_READY';
                          }).length;
                          final underReview = allPapers.where((p) => p.status.toUpperCase() == 'UNDER_REVIEW').length;

                          return _HomeData(
                            ticketCount: tickets.length,
                            paidCount: tickets.where((t) => (t.paymentStatus ?? '').toUpperCase() == 'COMPLETED').length,
                            pendingCount: tickets.where((t) => (t.paymentStatus ?? '').toUpperCase() == 'PENDING').length,
                            paperCount: allPapers.length,
                            acceptedCount: accepted,
                            underReviewCount: underReview,
                            activeConferences: activeConfs,
                            recentNotifications: notifications.take(5).toList(),
                          );
                        }

                        Widget _buildSummaryCard(
                          BuildContext context, {
                          required IconData icon,
                          required String title,
                          required int count,
                          required String status,
                          required Color color,
                        }) {
                          return Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: color.withValues(alpha: 0.25)),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: color.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(icon, color: color, size: 20),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        title,
                                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                              fontWeight: FontWeight.w700,
                                            ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        status,
                                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                              color: context.scheme.onSurfaceVariant,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: color.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    count.toString(),
                                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                          color: color,
                                          fontWeight: FontWeight.w800,
                                        ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }

                        Widget _buildConferenceCard(BuildContext context, AuthorConferenceSummary conf) {
                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: context.scheme.primaryContainer.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: context.scheme.primary.withValues(alpha: 0.2)),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _ConferenceThumb(imageUrl: conf.bannerImageUrl),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        conf.conferenceName,
                                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                              fontWeight: FontWeight.w700,
                                            ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 2),
                                      Row(
                                        children: [
                                          Icon(Icons.location_on_rounded,
                                              size: 12, color: context.scheme.onSurfaceVariant),
                                          const SizedBox(width: 3),
                                          Expanded(
                                            child: Text(
                                              conf.location,
                                              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                                    color: context.scheme.onSurfaceVariant,
                                                  ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Wrap(
                                        spacing: 6,
                                        runSpacing: 6,
                                        children: [
                                          _SmallBadge(
                                            label: conf.status,
                                            icon: Icons.flag_rounded,
                                            color: Colors.indigo,
                                          ),
                                          _SmallBadge(
                                            label: '${conf.myPaperCount} papers',
                                            icon: Icons.article_rounded,
                                            color: Colors.teal,
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: Colors.green.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    '${conf.acceptedCount}',
                                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                          color: Colors.green,
                                          fontWeight: FontWeight.w800,
                                        ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }
                      }

class _ConferenceThumb extends StatelessWidget {
  const _ConferenceThumb({required this.imageUrl});

  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    final hasImage = imageUrl.trim().isNotEmpty;
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 58,
        height: 58,
        color: context.scheme.primaryContainer.withValues(alpha: 0.4),
        child: hasImage
            ? Image.network(
                imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const _ThumbFallback(),
              )
            : const _ThumbFallback(),
      ),
    );
  }
}

class _ThumbFallback extends StatelessWidget {
  const _ThumbFallback();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Image.asset(
            'assets/images/Logo Favicon.png',
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }
}

class _SmallBadge extends StatelessWidget {
  const _SmallBadge({
    required this.label,
    required this.icon,
    required this.color,
  });

  final String label;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}

class _QuickStatCard extends StatelessWidget {
  const _QuickStatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 6),
          Text(
            value,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
          ),
          const SizedBox(height: 2),
          Text(label, style: Theme.of(context).textTheme.labelSmall),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        const Spacer(),
      ],
    );
  }
}

class _HomeData {
  const _HomeData({
    required this.ticketCount,
    required this.paidCount,
    required this.pendingCount,
    required this.paperCount,
    required this.acceptedCount,
    required this.underReviewCount,
    required this.activeConferences,
    required this.recentNotifications,
  });

  final int ticketCount;
  final int paidCount;
  final int pendingCount;
  final int paperCount;
  final int acceptedCount;
  final int underReviewCount;
  final List<AuthorConferenceSummary> activeConferences;
  final List<NotificationPreview> recentNotifications;
}

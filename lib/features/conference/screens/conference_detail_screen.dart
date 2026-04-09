import 'package:confms_mobile/constants/app_theme.dart';
import 'package:confms_mobile/constants/dimensions.dart';
import 'package:confms_mobile/constants/colors.dart';
import 'package:confms_mobile/models/conference.dart';
import 'package:confms_mobile/services/api_service.dart';
import 'package:confms_mobile/services/conference_service.dart';
import 'package:confms_mobile/services/mobile_feature_service.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

class ConferenceDetailScreen extends StatelessWidget {
  const ConferenceDetailScreen({
    super.key,
    required this.conferenceService,
    this.featureService,
    this.apiService,
  });

  final ConferenceService conferenceService;
  final MobileFeatureService? featureService;
  final ApiService? apiService;

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments;
    final conferenceId = _resolveConferenceId(args);

    if (conferenceId == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Conference Detail')),
        body: const Center(child: Text('No conference selected.')),
      );
    }

    return Scaffold(
      body: FutureBuilder<_DetailBundle>(
        future: _loadBundle(conferenceId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _ErrorView(error: snapshot.error.toString());
          }

          final data = snapshot.data;
          if (data == null) {
            return const _ErrorView(error: 'Conference not found.');
          }

          return _ConferenceDetailContent(
            conference: data.conference,
            progress: data.progress,
            tracks: data.tracks,
          );
        },
      ),
    );
  }

  Future<_DetailBundle> _loadBundle(int conferenceId) async {
    final conference = await conferenceService.getConferenceById(conferenceId);
    List<ConferenceProgressStep> progress = const [];
    List<Map<String, dynamic>> tracks = const [];

    if (featureService != null) {
      try {
        progress = await featureService!.getConferenceProgress(
          conferenceId: conferenceId,
        );
      } catch (_) {}
    }

    final api = apiService ?? featureService?.apiServiceRef;
    if (api != null) {
      try {
        final tracksData = await api.getAny(
          '/conferences-track/conferenceId/$conferenceId?page=0&size=100',
        );
        tracks = _normalizeTrackList(tracksData);
      } catch (_) {
        try {
          final fallback = await api.getAny('/tracks/conference/$conferenceId');
          tracks = _normalizeTrackList(fallback);
        } catch (_) {}
      }
    }

    return _DetailBundle(
      conference: conference,
      progress: progress,
      tracks: tracks,
    );
  }

  List<Map<String, dynamic>> _normalizeTrackList(dynamic raw) {
    if (raw is List) {
      return raw.whereType<Map<String, dynamic>>().toList();
    }
    if (raw is Map<String, dynamic>) {
      final content = raw['content'];
      if (content is List) {
        return content.whereType<Map<String, dynamic>>().toList();
      }
      final data = raw['data'];
      if (data is List) {
        return data.whereType<Map<String, dynamic>>().toList();
      }
      final items = raw['items'];
      if (items is List) {
        return items.whereType<Map<String, dynamic>>().toList();
      }
      if (raw.containsKey('id') || raw.containsKey('name')) {
        return [raw];
      }
    }
    return const [];
  }

  int? _resolveConferenceId(dynamic args) {
    if (args is int) return args;
    if (args is String) return int.tryParse(args);
    if (args is Conference) return args.id;
    if (args is Map<String, dynamic>) {
      final raw = args['conferenceId'] ?? args['id'];
      if (raw is int) return raw;
      if (raw is String) return int.tryParse(raw);
    }
    return null;
  }
}

class _DetailBundle {
  const _DetailBundle({
    required this.conference,
    required this.progress,
    this.tracks = const [],
  });
  final Conference conference;
  final List<ConferenceProgressStep> progress;
  final List<Map<String, dynamic>> tracks;
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.error});
  final String error;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Conference Detail')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.error_outline_rounded,
                size: 56,
                color: context.scheme.error,
              ),
              const SizedBox(height: 12),
              Text(
                error,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
//  Hero + TabBar (Overview / Tracks)
// ═══════════════════════════════════════════════════════════════════════
class _ConferenceDetailContent extends StatefulWidget {
  const _ConferenceDetailContent({
    required this.conference,
    required this.progress,
    this.tracks = const [],
  });

  final Conference conference;
  final List<ConferenceProgressStep> progress;
  final List<Map<String, dynamic>> tracks;

  @override
  State<_ConferenceDetailContent> createState() =>
      _ConferenceDetailContentState();
}

class _ConferenceDetailContentState extends State<_ConferenceDetailContent>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String _fmt(DateTime d) => DateFormat('MMM d, yyyy').format(d);
  String _fmtStr(String? raw) {
    if (raw == null || raw.trim().isEmpty) return 'TBA';
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return raw;
    return DateFormat('MMM d, yyyy').format(parsed);
  }

  Color _statusColor(String s) {
    switch (s.toUpperCase()) {
      case 'ACTIVE':
      case 'APPROVED':
        return Colors.green;
      case 'PENDING':
        return Colors.amber;
      default:
        return Colors.orange;
    }
  }

  @override
  Widget build(BuildContext context) {
    final conf = widget.conference;
    final sc = _statusColor(conf.status);

    return NestedScrollView(
      headerSliverBuilder: (context, _) => [
        // ─── HERO ───
        SliverAppBar(
          expandedHeight: 200,
          pinned: true,
          stretch: true,
          leading: IconButton(
            icon: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.3),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.arrow_back,
                color: Colors.white,
                size: 20,
              ),
            ),
            onPressed: () => Navigator.pop(context),
          ),
          flexibleSpace: FlexibleSpaceBar(
            background: Stack(
              fit: StackFit.expand,
              children: [
                if (conf.bannerImageUrl != null &&
                    conf.bannerImageUrl!.isNotEmpty)
                  Image.network(
                    conf.bannerImageUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      decoration: const BoxDecoration(
                        gradient: AppColors.primaryGradient,
                      ),
                    ),
                  )
                else
                  Container(
                    decoration: const BoxDecoration(
                      gradient: AppColors.primaryGradient,
                    ),
                  ),
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.3),
                        Colors.black.withValues(alpha: 0.75),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 12,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          if (conf.acronym.isNotEmpty)
                            _HeroBadge(
                              text: conf.acronym,
                              bg: Colors.white.withValues(alpha: 0.2),
                              border: Colors.white.withValues(alpha: 0.25),
                              isMono: true,
                            ),
                          _HeroBadge(
                            text: conf.status,
                            bg: sc.withValues(alpha: 0.25),
                            border: sc.withValues(alpha: 0.4),
                            fontSize: 10,
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        conf.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 20,
                          height: 1.2,
                          shadows: [
                            Shadow(blurRadius: 8, color: Colors.black54),
                          ],
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

        // ─── TAB BAR ───
        SliverPersistentHeader(
          pinned: true,
          delegate: _StickyTabBarDelegate(
            TabBar(
              controller: _tabController,
              labelColor: context.scheme.primary,
              unselectedLabelColor: context.scheme.onSurfaceVariant,
              indicatorColor: context.scheme.primary,
              indicatorWeight: 3,
              labelStyle: Theme.of(
                context,
              ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
              tabs: [
                const Tab(text: 'Overview'),
                Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Tracks'),
                      if (widget.tracks.isNotEmpty) ...[
                        const SizedBox(width: 4),
                        _CountBadge(
                          count: widget.tracks.length,
                          color: Colors.indigo,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
      body: TabBarView(
        controller: _tabController,
        children: [
          _OverviewTab(
            conference: conf,
            progress: widget.progress,
            fmt: _fmt,
            fmtStr: _fmtStr,
          ),
          _TracksTab(tracks: widget.tracks),
        ],
      ),
    );
  }
}

class _HeroBadge extends StatelessWidget {
  const _HeroBadge({
    required this.text,
    required this.bg,
    required this.border,
    this.isMono = false,
    this.fontSize = 12,
  });
  final String text;
  final Color bg;
  final Color border;
  final bool isMono;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(isMono ? 6 : 999),
        border: Border.all(color: border),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: fontSize,
          fontFamily: isMono ? 'monospace' : null,
        ),
      ),
    );
  }
}

class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.count, required this.color});
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$count',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

class _StickyTabBarDelegate extends SliverPersistentHeaderDelegate {
  const _StickyTabBarDelegate(this.tabBar);
  final TabBar tabBar;

  @override
  double get minExtent => tabBar.preferredSize.height;
  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(BuildContext c, double s, bool o) =>
      Container(color: Theme.of(c).scaffoldBackgroundColor, child: tabBar);

  @override
  bool shouldRebuild(covariant _StickyTabBarDelegate old) =>
      tabBar != old.tabBar;
}

// ═══════════════════════════════════════════════════════════════════════
//  TAB 1: Overview
// ═══════════════════════════════════════════════════════════════════════
class _OverviewTab extends StatelessWidget {
  const _OverviewTab({
    required this.conference,
    required this.progress,
    required this.fmt,
    required this.fmtStr,
  });

  final Conference conference;
  final List<ConferenceProgressStep> progress;
  final String Function(DateTime) fmt;
  final String Function(String?) fmtStr;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppDimensions.screenPadding),
      children: [
        // ── Info cards row 1
        Row(
          children: [
            Expanded(
              child: _InfoCard(
                icon: Icons.location_on_rounded,
                iconColor: Colors.indigo,
                label: 'Location',
                value:
                    conference.location +
                    (conference.province != null
                        ? ', ${conference.province}'
                        : ''),
                subtitle: conference.country,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _InfoCard(
                icon: Icons.calendar_month_rounded,
                iconColor: Colors.purple,
                label: 'Event Dates',
                value: fmt(conference.startDate),
                subtitle: 'to ${fmt(conference.endDate)}',
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // ── Info cards row 2
        Row(
          children: [
            Expanded(
              child: _InfoCard(
                icon: Icons.category_rounded,
                iconColor: Colors.teal,
                label: 'Research Area',
                value: conference.area.isNotEmpty
                    ? conference.area
                    : 'Not specified',
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _InfoCard(
                icon: conference.paperDeadline != null
                    ? Icons.timer_rounded
                    : conference.websiteUrl != null
                    ? Icons.language_rounded
                    : Icons.phone_rounded,
                iconColor: Colors.orange,
                label: conference.paperDeadline != null
                    ? 'Deadline'
                    : conference.websiteUrl != null
                    ? 'Website'
                    : 'Contact',
                value: conference.paperDeadline != null
                    ? fmtStr(conference.paperDeadline)
                    : conference.websiteUrl != null
                    ? 'Visit site →'
                    : conference.contactInformation ?? '—',
                subtitle: conference.paperDeadline != null
                    ? 'submission closes'
                    : null,
                onTap: conference.websiteUrl != null
                    ? () => launchUrl(
                        Uri.parse(conference.websiteUrl!),
                        mode: LaunchMode.externalApplication,
                      )
                    : null,
              ),
            ),
          ],
        ),

        // ── Phase tracker
        if (progress.isNotEmpty) ...[
          const SizedBox(height: 20),
          _PhaseTracker(steps: progress),
        ],

        // ── Description
        if (conference.description.isNotEmpty) ...[
          const SizedBox(height: 20),
          _DescriptionSection(description: conference.description),
        ],

        // ── Organizer
        ..._buildOrganizer(context),

        // ── Actions
        const SizedBox(height: 20),
        _ActionsSection(conference: conference),
        const SizedBox(height: 32),
      ],
    );
  }

  List<Widget> _buildOrganizer(BuildContext context) {
    final hasO = (conference.organizerName ?? '').isNotEmpty;
    final hasC = (conference.creatorName ?? '').isNotEmpty;
    final hasCt = (conference.contactInformation ?? '').isNotEmpty;
    if (!hasO && !hasC && !hasCt) return [];

    return [
      const SizedBox(height: 20),
      Text(
        'Organizer',
        style: Theme.of(
          context,
        ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: 8),
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: context.scheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: context.tokens.cardBorder),
        ),
        child: Column(
          children: [
            if (hasO)
              _OrgRow(
                icon: Icons.business_rounded,
                label: 'Organizer',
                value: conference.organizerName!,
              ),
            if (hasC) ...[
              if (hasO) const SizedBox(height: 8),
              _OrgRow(
                icon: Icons.person_rounded,
                label: 'Created by',
                value: conference.creatorName!,
              ),
            ],
            if (hasCt) ...[
              if (hasO || hasC) const SizedBox(height: 8),
              _OrgRow(
                icon: Icons.email_rounded,
                label: 'Contact',
                value: conference.contactInformation!,
              ),
            ],
          ],
        ),
      ),
    ];
  }
}

// ═══════════════════════════════════════════════════════════════════════
//  TAB 2: Tracks
// ═══════════════════════════════════════════════════════════════════════
class _TracksTab extends StatelessWidget {
  const _TracksTab({required this.tracks});
  final List<Map<String, dynamic>> tracks;

  Color _statusColor(String s) {
    switch (s.toUpperCase()) {
      case 'OPEN':
      case 'ACTIVE':
      case 'APPROVED':
        return Colors.green;
      case 'PENDING':
        return Colors.amber;
      default:
        return Colors.orange;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (tracks.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.view_list_rounded,
              size: 56,
              color: context.scheme.onSurfaceVariant.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 12),
            Text(
              'No tracks yet',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: context.scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Tracks will appear once the organizer adds them.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: context.scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(AppDimensions.screenPadding),
      itemCount: tracks.length,
      itemBuilder: (context, idx) {
        final t = tracks[idx];
        final name = (t['name'] ?? 'Track ${idx + 1}') as String;
        final desc = (t['description'] ?? '') as String;
        final rawStatus = (t['status'] ?? t['trackStatus'] ?? 'OPEN').toString();
        final status = rawStatus.toUpperCase() == 'ACTIVE' ? 'OPEN' : rawStatus;

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: context.scheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: context.tokens.cardBorder),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.indigo.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(
                    '${idx + 1}',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: Colors.indigo,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _MiniStatusBadge(
                          label: status,
                          color: _statusColor(status),
                        ),
                      ],
                    ),
                    if (desc.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        desc,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: context.scheme.onSurfaceVariant,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _MiniStatusBadge extends StatelessWidget {
  const _MiniStatusBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
//  Shared sub-widgets
// ═══════════════════════════════════════════════════════════════════════
class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    this.subtitle,
    this.onTap,
  });
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final String? subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: context.scheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: context.tokens.cardBorder),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: iconColor, size: 14),
                ),
                const SizedBox(width: 6),
                Text(
                  label.toUpperCase(),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                    color: context.scheme.onSurfaceVariant,
                    fontSize: 9,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: onTap != null ? Colors.indigo : null,
                fontSize: 13,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 1),
              Text(
                subtitle!,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: context.scheme.onSurfaceVariant,
                  fontSize: 10,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PhaseTracker extends StatelessWidget {
  const _PhaseTracker({required this.steps});
  final List<ConferenceProgressStep> steps;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Conference Phases',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: context.scheme.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: context.tokens.cardBorder),
          ),
          child: Column(
            children: steps.asMap().entries.map((e) {
              final idx = e.key;
              final step = e.value;
              final isLast = idx == steps.length - 1;
              final on = step.isEnabled;

              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  border: isLast
                      ? null
                      : Border(
                          bottom: BorderSide(color: context.tokens.cardBorder),
                        ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: on
                            ? Colors.green.withValues(alpha: 0.15)
                            : context.scheme.surfaceContainerLow,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: on ? Colors.green : context.tokens.cardBorder,
                          width: 1.5,
                        ),
                      ),
                      child: Icon(
                        on ? Icons.check_rounded : Icons.circle_outlined,
                        size: 14,
                        color: on
                            ? Colors.green
                            : context.scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            step.name,
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(
                                  fontWeight: on
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  color: on
                                      ? null
                                      : context.scheme.onSurfaceVariant,
                                  fontSize: 13,
                                ),
                          ),
                          if (step.deadline.isNotEmpty)
                            Text(
                              step.deadline,
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(
                                    color: context.scheme.onSurfaceVariant,
                                    fontSize: 10,
                                  ),
                            ),
                        ],
                      ),
                    ),
                    if (on)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'ACTIVE',
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: Colors.green,
                                fontWeight: FontWeight.w700,
                                fontSize: 9,
                              ),
                        ),
                      ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

class _DescriptionSection extends StatefulWidget {
  const _DescriptionSection({required this.description});
  final String description;
  @override
  State<_DescriptionSection> createState() => _DescriptionSectionState();
}

class _DescriptionSectionState extends State<_DescriptionSection> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final isLong = widget.description.length > 200;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'About',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: context.scheme.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: context.tokens.cardBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.description,
                maxLines: _expanded ? null : 5,
                overflow: _expanded
                    ? TextOverflow.visible
                    : TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(height: 1.5),
              ),
              if (isLong)
                GestureDetector(
                  onTap: () => setState(() => _expanded = !_expanded),
                  child: Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      _expanded ? 'Show less' : 'Read more',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: context.scheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _OrgRow extends StatelessWidget {
  const _OrgRow({required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: context.scheme.onSurfaceVariant),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: context.scheme.onSurfaceVariant,
                  fontSize: 10,
                ),
              ),
              Text(
                value,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ActionsSection extends StatelessWidget {
  const _ActionsSection({required this.conference});
  final Conference conference;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Actions',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        if (conference.websiteUrl != null && conference.websiteUrl!.isNotEmpty)
          _ActionTile(
            icon: Icons.language_rounded,
            color: Colors.indigo,
            label: 'Visit Conference Website',
            onTap: () => launchUrl(
              Uri.parse(conference.websiteUrl!),
              mode: LaunchMode.externalApplication,
            ),
          ),
        _ActionTile(
          icon: Icons.share_rounded,
          color: Colors.teal,
          label: 'Share Conference',
          onTap: () {},
        ),
      ],
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.color,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.15)),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              const SizedBox(width: 12),
              Text(
                label,
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 14,
                color: context.scheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

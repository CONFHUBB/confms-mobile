import 'dart:convert';

import 'package:confms_mobile/constants/colors.dart';
import 'package:confms_mobile/constants/dimensions.dart';
import 'package:confms_mobile/constants/text_styles.dart';
import 'package:confms_mobile/models/auth_user.dart';
import 'package:confms_mobile/models/conference.dart';
import 'package:confms_mobile/screens/conference_detail_placeholder_screen.dart';
import 'package:confms_mobile/services/auth_session.dart';
import 'package:confms_mobile/services/conference_service.dart';
import 'package:confms_mobile/services/conference_user_track_service.dart';
import 'package:confms_mobile/services/mobile_feature_service.dart';
import 'package:confms_mobile/widgets/custom_button.dart';
import 'package:confms_mobile/widgets/custom_card.dart';
import 'package:google_nav_bar/google_nav_bar.dart';
import 'package:flutter/material.dart';

enum _MainTab { home, attend, contribute, notifications, profile }

enum _AttendSection { browse, myTickets, schedule, bookmarks }

enum _ContributeRoleFilter { all, author, reviewer }

class MainShellScreen extends StatefulWidget {
  const MainShellScreen({
    super.key,
    required this.authSession,
    required this.conferenceService,
    required this.conferenceUserTrackService,
    required this.featureService,
    required this.onLogout,
  });

  final AuthSession authSession;
  final ConferenceService conferenceService;
  final ConferenceUserTrackService conferenceUserTrackService;
  final MobileFeatureService featureService;
  final Future<void> Function() onLogout;

  @override
  State<MainShellScreen> createState() => _MainShellScreenState();
}

class _MainShellScreenState extends State<MainShellScreen> {
  _MainTab _currentTab = _MainTab.home;

  Future<void> _handleLogout() async {
    await widget.onLogout();
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.authSession.user;

    return Scaffold(
      body: SafeArea(
        child: IndexedStack(
          index: _currentTab.index,
          children: [
            _HomeTab(featureService: widget.featureService, user: user),
            _AttendTab(
              conferenceService: widget.conferenceService,
              featureService: widget.featureService,
              user: user,
            ),
            _ContributeTab(
              user: user,
              conferenceUserTrackService: widget.conferenceUserTrackService,
            ),
            _NotificationsTab(
              featureService: widget.featureService,
              user: user,
            ),
            _ProfileTab(
              authSession: widget.authSession,
              featureService: widget.featureService,
              onLogout: _handleLogout,
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          decoration: const BoxDecoration(
            color: AppColors.surface,
            border: Border(top: BorderSide(color: AppColors.border)),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.space4,
            vertical: AppDimensions.space2,
          ),
          child: GNav(
            selectedIndex: _currentTab.index,
            onTabChange: (index) {
              setState(() => _currentTab = _MainTab.values[index]);
            },
            rippleColor: AppColors.muted,
            hoverColor: AppColors.muted,
            haptic: true,
            tabBorderRadius: 14,
            curve: Curves.easeOutExpo,
            duration: const Duration(milliseconds: 320),
            gap: 8,
            color: AppColors.textSecondary,
            activeColor: AppColors.primary,
            iconSize: 22,
            tabBackgroundColor: const Color(0xFFEFEFFE),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            tabs: const [
              GButton(icon: Icons.home_outlined, text: 'Home'),
              GButton(icon: Icons.confirmation_num_outlined, text: 'Attend'),
              GButton(icon: Icons.draw_outlined, text: 'Contribute'),
              GButton(icon: Icons.notifications_none, text: 'Alerts'),
              GButton(icon: Icons.person_outline, text: 'Profile'),
            ],
          ),
        ),
      ),
    );
  }
}

class _HomeTab extends StatelessWidget {
  const _HomeTab({required this.featureService, required this.user});

  final MobileFeatureService featureService;
  final AuthUser? user;

  @override
  Widget build(BuildContext context) {
    final userId = user?.id;
    if (userId == null) {
      return const _CenteredMutedText('No user context available.');
    }

    return FutureBuilder<HomeDashboardData>(
      future: featureService.getHomeDashboard(userId: userId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return _SectionError(message: snapshot.error.toString());
        }

        final data = snapshot.data;
        if (data == null) {
          return const _CenteredMutedText('No home data available.');
        }

        return RefreshIndicator(
          onRefresh: () async {
            await featureService.getHomeDashboard(userId: userId);
          },
          child: ListView(
            padding: const EdgeInsets.all(AppDimensions.screenPadding),
            children: [
              Text('Home', style: AppTextStyles.h2),
              const SizedBox(height: AppDimensions.space2),
              Text(
                'Welcome, ${user?.firstName ?? 'User'}',
                style: AppTextStyles.bodyMuted,
              ),
              const SizedBox(height: AppDimensions.space4),
              _SectionCard(
                title: 'Upcoming Sessions',
                children: data.upcomingSessions
                    .map(
                      (s) => _SimpleListTile(
                        title: s.title,
                        subtitle: '${s.subtitle}\n${s.conferenceName}',
                        trailing: s.isBookmarked
                            ? const Icon(
                                Icons.bookmark,
                                color: AppColors.primary,
                              )
                            : const Icon(Icons.bookmark_outline),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: AppDimensions.space3),
              _SectionCard(
                title: 'My Tickets (Preview)',
                children: data.myTickets
                    .map(
                      (t) => _SimpleListTile(
                        title: t.conferenceName,
                        subtitle: '${t.ticketType}\n${t.checkInStatus}',
                        trailing: const Icon(Icons.qr_code_2),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: AppDimensions.space3),
              _SectionCard(
                title: 'Pending Reviews',
                children: data.pendingReviews
                    .map(
                      (r) => _SimpleListTile(
                        title: r.title,
                        subtitle: r.subtitle,
                        trailing: const Icon(Icons.rate_review_outlined),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: AppDimensions.space3),
              _SectionCard(
                title: 'Submission Updates',
                children: data.submissionUpdates
                    .map(
                      (u) => _SimpleListTile(
                        title: u.title,
                        subtitle: u.subtitle,
                        trailing: const Icon(Icons.upload_file_outlined),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: AppDimensions.space3),
              _SectionCard(
                title: 'Announcements / Notifications',
                children: data.announcements
                    .map(
                      (a) => _SimpleListTile(
                        title: a.title,
                        subtitle: a.subtitle,
                        trailing: const Icon(Icons.campaign_outlined),
                      ),
                    )
                    .toList(),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _AttendTab extends StatefulWidget {
  const _AttendTab({
    required this.conferenceService,
    required this.featureService,
    required this.user,
  });

  final ConferenceService conferenceService;
  final MobileFeatureService featureService;
  final AuthUser? user;

  @override
  State<_AttendTab> createState() => _AttendTabState();
}

class _AttendTabState extends State<_AttendTab> {
  _AttendSection _section = _AttendSection.browse;

  @override
  Widget build(BuildContext context) {
    final userId = widget.user?.id;

    return ListView(
      padding: const EdgeInsets.all(AppDimensions.screenPadding),
      children: [
        Text('Attend', style: AppTextStyles.h2),
        const SizedBox(height: AppDimensions.space2),
        const Text(
          'Browse conferences, tickets, schedule, and bookmarks.',
          style: AppTextStyles.bodyMuted,
        ),
        const SizedBox(height: AppDimensions.space4),
        Wrap(
          spacing: AppDimensions.space2,
          runSpacing: AppDimensions.space2,
          children: [
            _TopSwitchButton(
              label: 'Browse',
              selected: _section == _AttendSection.browse,
              onPressed: () => setState(() => _section = _AttendSection.browse),
            ),
            _TopSwitchButton(
              label: 'My Tickets',
              selected: _section == _AttendSection.myTickets,
              onPressed: () =>
                  setState(() => _section = _AttendSection.myTickets),
            ),
            _TopSwitchButton(
              label: 'Schedule',
              selected: _section == _AttendSection.schedule,
              onPressed: () =>
                  setState(() => _section = _AttendSection.schedule),
            ),
            _TopSwitchButton(
              label: 'Bookmarks',
              selected: _section == _AttendSection.bookmarks,
              onPressed: () =>
                  setState(() => _section = _AttendSection.bookmarks),
            ),
          ],
        ),
        const SizedBox(height: AppDimensions.space4),
        if (_section == _AttendSection.browse) _buildBrowseSection(),
        if (_section == _AttendSection.myTickets)
          _buildTicketsSection(userId: userId),
        if (_section == _AttendSection.schedule)
          _buildScheduleSection(userId: userId),
        if (_section == _AttendSection.bookmarks)
          _buildBookmarksSection(userId: userId),
      ],
    );
  }

  Widget _buildBrowseSection() {
    return FutureBuilder<ConferencePage>(
      future: widget.conferenceService.getConferences(page: 0, size: 20),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return _SectionError(message: snapshot.error.toString());
        }

        final conferences = snapshot.data?.content ?? const <Conference>[];
        if (conferences.isEmpty) {
          return const _CenteredMutedText('No conferences available.');
        }

        return Column(
          children: conferences
              .map(
                (c) => Padding(
                  padding: const EdgeInsets.only(bottom: AppDimensions.space3),
                  child: CustomCard(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) =>
                              const ConferenceDetailPlaceholderScreen(),
                          settings: RouteSettings(arguments: c),
                        ),
                      );
                    },
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(c.name, style: AppTextStyles.title),
                        const SizedBox(height: 6),
                        Text(c.description, style: AppTextStyles.bodyMuted),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            _MiniChip(label: c.country),
                            const SizedBox(width: 8),
                            _MiniChip(label: c.area),
                            const Spacer(),
                            const Icon(Icons.arrow_forward_ios, size: 14),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              )
              .toList(),
        );
      },
    );
  }

  Widget _buildTicketsSection({required int? userId}) {
    if (userId == null) return const _CenteredMutedText('Missing user ID.');

    return FutureBuilder<List<TicketPreview>>(
      future: widget.featureService.getMyTickets(userId: userId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return _SectionError(message: snapshot.error.toString());
        }
        final tickets = snapshot.data ?? const <TicketPreview>[];
        if (tickets.isEmpty) {
          return const _CenteredMutedText('No tickets found.');
        }

        return _SectionCard(
          title: 'Ticket List',
          children: tickets
              .map(
                (t) => _SimpleListTile(
                  title: t.conferenceName,
                  subtitle: '${t.ticketType}\n${t.checkInStatus}',
                  trailing: const Icon(Icons.qr_code),
                ),
              )
              .toList(),
        );
      },
    );
  }

  Widget _buildScheduleSection({required int? userId}) {
    if (userId == null) return const _CenteredMutedText('Missing user ID.');

    return FutureBuilder<List<SessionPreview>>(
      future: widget.featureService.getMySchedule(userId: userId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return _SectionError(message: snapshot.error.toString());
        }
        final sessions = snapshot.data ?? const <SessionPreview>[];
        if (sessions.isEmpty) {
          return const _CenteredMutedText('No schedule data.');
        }

        return _SectionCard(
          title: 'My Schedule',
          children: sessions
              .map(
                (s) => _SimpleListTile(
                  title: s.title,
                  subtitle: '${s.subtitle}\n${s.conferenceName}',
                  trailing: Icon(
                    s.isBookmarked ? Icons.bookmark : Icons.bookmark_outline,
                    color: s.isBookmarked ? AppColors.primary : null,
                  ),
                ),
              )
              .toList(),
        );
      },
    );
  }

  Widget _buildBookmarksSection({required int? userId}) {
    if (userId == null) return const _CenteredMutedText('Missing user ID.');

    return FutureBuilder<List<SessionPreview>>(
      future: widget.featureService.getBookmarkedSessions(userId: userId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return _SectionError(message: snapshot.error.toString());
        }
        final sessions = snapshot.data ?? const <SessionPreview>[];
        if (sessions.isEmpty) {
          return const _CenteredMutedText('No bookmarked sessions.');
        }

        return _SectionCard(
          title: 'Saved Sessions',
          children: sessions
              .map(
                (s) => _SimpleListTile(
                  title: s.title,
                  subtitle: '${s.subtitle}\n${s.conferenceName}',
                  trailing: const Icon(
                    Icons.bookmark,
                    color: AppColors.primary,
                  ),
                ),
              )
              .toList(),
        );
      },
    );
  }
}

class _ContributeTab extends StatefulWidget {
  const _ContributeTab({
    required this.user,
    required this.conferenceUserTrackService,
  });

  final AuthUser? user;
  final ConferenceUserTrackService conferenceUserTrackService;

  @override
  State<_ContributeTab> createState() => _ContributeTabState();
}

class _ContributeTabState extends State<_ContributeTab> {
  _ContributeRoleFilter _filter = _ContributeRoleFilter.all;

  @override
  Widget build(BuildContext context) {
    final user = widget.user;
    if (user == null) return const _CenteredMutedText('Missing user context.');

    return FutureBuilder<List<ConferenceRoleEntry>>(
      future: widget.conferenceUserTrackService.getMyConferenceRoles(user.id),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final entries = snapshot.data ?? const <ConferenceRoleEntry>[];
        final filtered = _applyFilter(entries, _filter);

        return ListView(
          padding: const EdgeInsets.all(AppDimensions.screenPadding),
          children: [
            Text('Contribute', style: AppTextStyles.h2),
            const SizedBox(height: AppDimensions.space2),
            const Text(
              'Conference entry filtered by role (Author/Reviewer).',
              style: AppTextStyles.bodyMuted,
            ),
            const SizedBox(height: AppDimensions.space4),
            Wrap(
              spacing: AppDimensions.space2,
              children: [
                _TopSwitchButton(
                  label: 'All',
                  selected: _filter == _ContributeRoleFilter.all,
                  onPressed: () =>
                      setState(() => _filter = _ContributeRoleFilter.all),
                ),
                _TopSwitchButton(
                  label: 'Author',
                  selected: _filter == _ContributeRoleFilter.author,
                  onPressed: () =>
                      setState(() => _filter = _ContributeRoleFilter.author),
                ),
                _TopSwitchButton(
                  label: 'Reviewer',
                  selected: _filter == _ContributeRoleFilter.reviewer,
                  onPressed: () =>
                      setState(() => _filter = _ContributeRoleFilter.reviewer),
                ),
              ],
            ),
            const SizedBox(height: AppDimensions.space4),
            if (snapshot.hasError)
              _SectionError(message: snapshot.error.toString())
            else if (filtered.isEmpty)
              const _CenteredMutedText('No conferences for this role filter.')
            else
              ...filtered.map(
                (entry) => Padding(
                  padding: const EdgeInsets.only(bottom: AppDimensions.space3),
                  child: _ContributeConferenceCard(entry: entry),
                ),
              ),
          ],
        );
      },
    );
  }

  List<ConferenceRoleEntry> _applyFilter(
    List<ConferenceRoleEntry> entries,
    _ContributeRoleFilter filter,
  ) {
    switch (filter) {
      case _ContributeRoleFilter.all:
        return entries;
      case _ContributeRoleFilter.author:
        return entries.where((e) => e.isAuthor).toList();
      case _ContributeRoleFilter.reviewer:
        return entries.where((e) => e.isReviewer).toList();
    }
  }
}

class _NotificationsTab extends StatelessWidget {
  const _NotificationsTab({required this.featureService, required this.user});

  final MobileFeatureService featureService;
  final AuthUser? user;

  @override
  Widget build(BuildContext context) {
    final userId = user?.id;
    if (userId == null) {
      return const _CenteredMutedText('Missing user context.');
    }

    return FutureBuilder<List<NotificationPreview>>(
      future: featureService.getNotifications(userId: userId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return _SectionError(message: snapshot.error.toString());
        }

        final items = snapshot.data ?? const <NotificationPreview>[];

        return ListView(
          padding: const EdgeInsets.all(AppDimensions.screenPadding),
          children: [
            Text('Notifications', style: AppTextStyles.h2),
            const SizedBox(height: AppDimensions.space2),
            const Text(
              'Alerts with deep-link placeholders to Attend/Contribute flows.',
              style: AppTextStyles.bodyMuted,
            ),
            const SizedBox(height: AppDimensions.space4),
            if (items.isEmpty)
              const _CenteredMutedText('No notifications.')
            else
              ...items.map(
                (n) => Padding(
                  padding: const EdgeInsets.only(bottom: AppDimensions.space3),
                  child: CustomCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(n.title, style: AppTextStyles.title),
                            ),
                            if (!n.isRead)
                              Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: AppColors.primary,
                                  shape: BoxShape.circle,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(n.message, style: AppTextStyles.body),
                        const SizedBox(height: 8),
                        Text(
                          'Deep link: ${n.deepLinkHint}',
                          style: AppTextStyles.caption,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _ProfileTab extends StatelessWidget {
  const _ProfileTab({
    required this.authSession,
    required this.featureService,
    required this.onLogout,
  });

  final AuthSession authSession;
  final MobileFeatureService featureService;
  final Future<void> Function() onLogout;

  @override
  Widget build(BuildContext context) {
    final user = authSession.user;
    final claims = _decodeTokenClaims(authSession.token);
    final userId = user?.id;

    return ListView(
      padding: const EdgeInsets.all(AppDimensions.screenPadding),
      children: [
        Text('Profile', style: AppTextStyles.h2),
        const SizedBox(height: AppDimensions.space4),
        CustomCard(
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: const Color(0xFFEFEFFE),
                child: Text(
                  _initials(user),
                  style: AppTextStyles.title.copyWith(color: AppColors.primary),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${user?.firstName ?? claims['firstName'] ?? ''} ${user?.lastName ?? claims['lastName'] ?? ''}'
                          .trim(),
                      style: AppTextStyles.title,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      user?.email ?? claims['email']?.toString() ?? '-',
                      style: AppTextStyles.bodyMuted,
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      children: (user?.roles ?? _rolesFromClaims(claims))
                          .map(
                            (role) => _MiniChip(
                              label: role.replaceFirst('ROLE_', ''),
                            ),
                          )
                          .toList(),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppDimensions.space3),
        _SectionCard(
          title: 'Settings',
          children: const [
            _SimpleListTile(
              title: 'Notification Preferences',
              subtitle: 'Manage push and in-app alerts',
            ),
            _SimpleListTile(
              title: 'Language',
              subtitle: 'English / Vietnamese',
            ),
            _SimpleListTile(
              title: 'Security',
              subtitle: 'Password and account protection',
            ),
          ],
        ),
        const SizedBox(height: AppDimensions.space3),
        if (userId != null)
          FutureBuilder<List<PaymentHistoryPreview>>(
            future: featureService.getPaymentHistory(userId: userId),
            builder: (context, snapshot) {
              final data = snapshot.data ?? const <PaymentHistoryPreview>[];
              return _SectionCard(
                title: 'Payment History',
                children: data
                    .map(
                      (p) => _SimpleListTile(
                        title: p.conferenceName,
                        subtitle:
                            '${p.amountLabel} • ${p.status}\n${p.timestampLabel}',
                      ),
                    )
                    .toList(),
              );
            },
          ),
        const SizedBox(height: AppDimensions.space3),
        CustomButton(
          label: 'Logout',
          expanded: true,
          variant: CustomButtonVariant.outline,
          icon: const Icon(Icons.logout, size: 18),
          onPressed: onLogout,
        ),
      ],
    );
  }

  String _initials(AuthUser? user) {
    final first = (user?.firstName ?? '').trim();
    final last = (user?.lastName ?? '').trim();
    final a = first.isNotEmpty ? first[0] : '';
    final b = last.isNotEmpty ? last[0] : '';
    final initials = '$a$b'.trim();
    return initials.isEmpty ? 'U' : initials.toUpperCase();
  }

  List<String> _rolesFromClaims(Map<String, dynamic> claims) {
    final raw = claims['roles'];
    if (raw is List) {
      return raw.map((e) => e.toString()).toList();
    }
    return const <String>[];
  }

  Map<String, dynamic> _decodeTokenClaims(String? token) {
    if (token == null || token.isEmpty) return const <String, dynamic>{};
    final parts = token.split('.');
    if (parts.length < 2) return const <String, dynamic>{};

    try {
      final payload = base64Url.normalize(parts[1]);
      final json = utf8.decode(base64Url.decode(payload));
      final decoded = jsonDecode(json);
      if (decoded is Map<String, dynamic>) return decoded;
      return const <String, dynamic>{};
    } catch (_) {
      return const <String, dynamic>{};
    }
  }
}

class _ContributeConferenceCard extends StatelessWidget {
  const _ContributeConferenceCard({required this.entry});

  final ConferenceRoleEntry entry;

  @override
  Widget build(BuildContext context) {
    return CustomCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(entry.conferenceName, style: AppTextStyles.title),
          const SizedBox(height: 6),
          Text(
            'Conference ID: ${entry.conferenceId}',
            style: AppTextStyles.caption,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: entry.roles
                .map((r) => _MiniChip(label: r.replaceAll('_', ' ')))
                .toList(),
          ),
          const SizedBox(height: 10),
          const Text(
            'Entry actions (placeholder): My Submissions, Assigned Papers, Discussions',
            style: AppTextStyles.bodyMuted,
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return CustomCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTextStyles.title),
          const SizedBox(height: AppDimensions.space3),
          ...children,
        ],
      ),
    );
  }
}

class _SimpleListTile extends StatelessWidget {
  const _SimpleListTile({
    required this.title,
    required this.subtitle,
    this.trailing,
  });

  final String title;
  final String subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimensions.space3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTextStyles.body.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(subtitle, style: AppTextStyles.caption),
              ],
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 8), trailing!],
        ],
      ),
    );
  }
}

class _MiniChip extends StatelessWidget {
  const _MiniChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.muted,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(label, style: AppTextStyles.caption),
    );
  }
}

class _TopSwitchButton extends StatelessWidget {
  const _TopSwitchButton({
    required this.label,
    required this.selected,
    required this.onPressed,
  });

  final String label;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: selected ? AppColors.primary : AppColors.textSecondary,
        backgroundColor: selected ? const Color(0xFFEFEFFE) : AppColors.surface,
        side: BorderSide(
          color: selected ? AppColors.primary : AppColors.border,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      ),
      child: Text(label),
    );
  }
}

class _SectionError extends StatelessWidget {
  const _SectionError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return CustomCard(
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppColors.destructive),
          const SizedBox(width: 8),
          Expanded(child: Text(message, style: AppTextStyles.body)),
        ],
      ),
    );
  }
}

class _CenteredMutedText extends StatelessWidget {
  const _CenteredMutedText(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.screenPadding),
        child: Text(
          text,
          style: AppTextStyles.bodyMuted,
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

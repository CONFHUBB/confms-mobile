import 'dart:async';

import 'package:confms_mobile/constants/app_theme.dart';
import 'package:confms_mobile/constants/dimensions.dart';
import 'package:confms_mobile/features/main_shell/widgets/main_tab_scaffold.dart';
import 'package:confms_mobile/features/main_shell/widgets/shell_shared_widgets.dart';
import 'package:confms_mobile/models/auth_user.dart';
import 'package:confms_mobile/services/mobile_feature_service.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

enum _WorkspaceSection { overview, myPapers, cameraReady }

class ContributeTab extends StatefulWidget {
  const ContributeTab({
    super.key,
    required this.user,
    required this.featureService,
    required this.onOpenNotifications,
  });

  final AuthUser? user;
  final MobileFeatureService featureService;
  final VoidCallback onOpenNotifications;

  @override
  State<ContributeTab> createState() => _ContributeTabState();
}

class _ContributeTabState extends State<ContributeTab> {
  final TextEditingController _searchController = TextEditingController();
  _WorkspaceSection _section = _WorkspaceSection.overview;
  AuthorConferenceSummary? _selectedConference;
  late final _DebouncedSearch _debouncedSearch;

  @override
  void initState() {
    super.initState();
    _debouncedSearch = _DebouncedSearch(
      onSearch: () {
        if (mounted) setState(() {});
      },
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debouncedSearch.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.user;
    if (user == null) {
      return MainTabScaffold(
        title: 'My Papers',
        subtitle: 'Author workspace and conference submissions.',
        icon: Icons.article_rounded,
        onOpenNotifications: widget.onOpenNotifications,
        body: const CenteredMutedText('Missing user context.'),
      );
    }

    return MainTabScaffold(
      title: _selectedConference == null
          ? 'My Papers'
          : (_selectedConference?.acronym.isNotEmpty ?? false)
          ? _selectedConference!.acronym
          : 'Author Workspace',
      subtitle: _selectedConference == null
          ? 'Conference list, counters, search and filters.'
          : 'Overview, papers and camera-ready files.',
      icon: _selectedConference == null
          ? Icons.folder_special_rounded
          : Icons.space_dashboard_rounded,
      onOpenNotifications: widget.onOpenNotifications,
      body: _selectedConference == null
          ? _buildConferenceList(user.id)
          : _buildConferenceWorkspace(user.id, _selectedConference!),
    );
  }

  Widget _buildConferenceList(int userId) {
    return FutureBuilder<List<AuthorConferenceSummary>>(
      future: widget.featureService.getAuthorConferences(userId: userId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError)
          return SectionError(message: snapshot.error.toString());

        final all = snapshot.data ?? const <AuthorConferenceSummary>[];
        final q = _searchController.text.trim().toLowerCase();
        final filtered = all.where((c) {
          if (q.isEmpty) return true;
          return c.conferenceName.toLowerCase().contains(q) ||
              c.acronym.toLowerCase().contains(q) ||
              c.location.toLowerCase().contains(q);
        }).toList();

        return ListView(
          padding: const EdgeInsets.all(AppDimensions.screenPadding),
          children: [
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by conference, acronym, location...',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _searchController.text.isEmpty
                    ? null
                    : IconButton(
                        onPressed: () {
                          _searchController.clear();
                          _debouncedSearch.cancel();
                          setState(() {});
                        },
                        icon: const Icon(Icons.clear_rounded),
                      ),
              ),
              onChanged: (_) {
                _debouncedSearch.search();
              },
            ),
            const SizedBox(height: AppDimensions.space3),
            if (filtered.isEmpty)
              const CenteredMutedText('No conferences match your filters.')
            else
              ...filtered.map(
                (c) => Padding(
                  padding: const EdgeInsets.only(bottom: AppDimensions.space3),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                    onTap: () {
                      setState(() {
                        _selectedConference = c;
                        _section = _WorkspaceSection.overview;
                      });
                    },
                    child: SectionCard(
                      title: c.conferenceName,
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _badge(
                              c.status,
                              Icons.flag_rounded,
                              _statusColor(c.status),
                            ),
                            _badge(
                              '${c.myPaperCount} papers',
                              Icons.article_rounded,
                              Colors.indigo,
                            ),
                            _badge(
                              '${c.acceptedCount} accepted',
                              Icons.verified_rounded,
                              Colors.green,
                            ),
                          ],
                        ),
                        const SizedBox(height: AppDimensions.space2),
                        SimpleListTile(
                          title: c.acronym.isEmpty ? 'Conference' : c.acronym,
                          subtitle:
                              '${c.location}\n${_formatDate(c.startDate)} - ${_formatDate(c.endDate)}',
                          trailing: const Icon(
                            Icons.arrow_forward_ios_rounded,
                            size: 16,
                          ),
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

  Widget _buildConferenceWorkspace(
    int userId,
    AuthorConferenceSummary conference,
  ) {
    return FutureBuilder<_WorkspaceData>(
      future: _loadWorkspaceData(
        userId: userId,
        conferenceId: conference.conferenceId,
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError)
          return SectionError(message: snapshot.error.toString());
        final data = snapshot.data;
        if (data == null)
          return const CenteredMutedText('Unable to load workspace data.');

        return ListView(
          padding: const EdgeInsets.all(AppDimensions.screenPadding),
          children: [
            OutlinedButton.icon(
              onPressed: () => setState(() => _selectedConference = null),
              icon: const Icon(Icons.arrow_back_rounded, size: 18),
              label: const Text('Conference List'),
            ),
            const SizedBox(height: AppDimensions.space3),
            _ConferenceMetaCard(conference: conference),
            const SizedBox(height: AppDimensions.space3),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _WorkspaceChip(
                    icon: Icons.insights_rounded,
                    label: 'Overview',
                    selected: _section == _WorkspaceSection.overview,
                    onTap: () =>
                        setState(() => _section = _WorkspaceSection.overview),
                  ),
                  _WorkspaceChip(
                    icon: Icons.article_rounded,
                    label: 'My Papers',
                    selected: _section == _WorkspaceSection.myPapers,
                    onTap: () =>
                        setState(() => _section = _WorkspaceSection.myPapers),
                  ),
                  _WorkspaceChip(
                    icon: Icons.camera_enhance_rounded,
                    label: 'Camera Ready',
                    selected: _section == _WorkspaceSection.cameraReady,
                    onTap: () => setState(
                      () => _section = _WorkspaceSection.cameraReady,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppDimensions.space3),
            _buildSectionBody(conference, data),
          ],
        );
      },
    );
  }

  Widget _buildSectionBody(
    AuthorConferenceSummary conference,
    _WorkspaceData data,
  ) {
    switch (_section) {
      case _WorkspaceSection.overview:
        final underReview = data.papers
            .where((p) => p.status.toUpperCase() == 'UNDER_REVIEW')
            .length;
        final accepted = data.papers.where((p) {
          final status = p.status.toUpperCase();
          return status == 'ACCEPTED' ||
              status == 'PUBLISHED' ||
              status == 'CAMERA_READY';
        }).length;
        final scores = data.papers
            .where((p) => p.averageScore != null)
            .map((p) => p.averageScore!)
            .toList();
        final avg = scores.isEmpty
            ? '—'
            : (scores.reduce((a, b) => a + b) / scores.length).toStringAsFixed(
                1,
              );

        return Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: _CompactStatCard(
                    label: 'Papers',
                    value: '${data.papers.length}',
                    icon: Icons.article_rounded,
                    color: Colors.indigo,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _CompactStatCard(
                    label: 'Accepted',
                    value: '$accepted',
                    icon: Icons.check_circle_rounded,
                    color: Colors.green,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _CompactStatCard(
                    label: 'Review',
                    value: '$underReview',
                    icon: Icons.hourglass_top_rounded,
                    color: Colors.orange,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _CompactStatCard(
                    label: 'Avg',
                    value: avg,
                    icon: Icons.star_rounded,
                    color: Colors.purple,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppDimensions.space3),
            SectionCard(
              title: 'Conference Progress Timeline',
              children: data.progress.isEmpty
                  ? const [
                      CenteredMutedText('No activity timeline configured.'),
                    ]
                  : [_ConferenceTimeline(steps: data.progress)],
            ),
          ],
        );

      case _WorkspaceSection.myPapers:
        if (data.papers.isEmpty)
          return const CenteredMutedText('No papers in this conference.');
        return Column(
          children: data.papers.map((paper) {
            return Padding(
              padding: const EdgeInsets.only(bottom: AppDimensions.space3),
              child: _PaperSummaryCard(
                paper: paper,
                accent: _paperStatusColor(paper.status),
                onOpen: () =>
                    _openPaperDetails(paper.paperId, conference.conferenceId),
              ),
            );
          }).toList(),
        );

      case _WorkspaceSection.cameraReady:
        final cameraReady = data.papers.where((p) {
          final status = p.status.toUpperCase();
          return status == 'ACCEPTED' ||
              status == 'CAMERA_READY' ||
              status == 'PUBLISHED';
        }).toList();
        if (cameraReady.isEmpty)
          return const CenteredMutedText(
            'No eligible camera-ready papers yet.',
          );
        return Column(
          children: cameraReady.map((paper) {
            return Padding(
              padding: const EdgeInsets.only(bottom: AppDimensions.space3),
              child: _PaperSummaryCard(
                paper: paper,
                accent: Colors.teal,
                onOpen: () =>
                    _openPaperDetails(paper.paperId, conference.conferenceId),
                cameraReadyMode: true,
              ),
            );
          }).toList(),
        );
    }
  }

  Future<_WorkspaceData> _loadWorkspaceData({
    required int userId,
    required int conferenceId,
  }) async {
    final papers = await widget.featureService.getAuthorPapersByConference(
      userId: userId,
      conferenceId: conferenceId,
    );
    final progress = await widget.featureService.getConferenceProgress(
      conferenceId: conferenceId,
    );
    return _WorkspaceData(papers: papers, progress: progress);
  }

  Future<void> _openPaperDetails(int paperId, int conferenceId) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _PaperDetailsScreen(
          paperId: paperId,
          conferenceId: conferenceId,
          featureService: widget.featureService,
        ),
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'active':
        return Colors.green;
      case 'upcoming':
        return Colors.blue;
      case 'completed':
        return Colors.grey;
      default:
        return Colors.orange;
    }
  }

  Color _paperStatusColor(String status) {
    final value = status.toUpperCase();
    if (value == 'ACCEPTED' ||
        value == 'PUBLISHED' ||
        value == 'CAMERA_READY') {
      return Colors.green;
    }
    if (value == 'UNDER_REVIEW') return Colors.orange;
    if (value == 'REJECTED') return Colors.red;
    return Colors.indigo;
  }

  String _formatDate(String raw) {
    if (raw.trim().isEmpty) return 'TBA';
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return raw;
    return DateFormat('MMM d, yyyy').format(parsed);
  }

  Widget _badge(String label, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _WorkspaceData {
  const _WorkspaceData({required this.papers, required this.progress});

  final List<AuthorPaperSummary> papers;
  final List<ConferenceProgressStep> progress;
}

class _ConferenceMetaCard extends StatelessWidget {
  const _ConferenceMetaCard({required this.conference});

  final AuthorConferenceSummary conference;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: conference.conferenceName,
      children: [
        SimpleListTile(
          title: conference.acronym.isEmpty ? 'Conference' : conference.acronym,
          subtitle: conference.location,
          trailing: const Icon(Icons.location_on_outlined),
        ),
        SimpleListTile(
          title: 'Dates',
          subtitle:
              '${_formatRawDate(conference.startDate)} - ${_formatRawDate(conference.endDate)}',
          trailing: const Icon(Icons.calendar_month_rounded),
        ),
        SimpleListTile(
          title: 'Status',
          subtitle: conference.status,
          trailing: const Icon(Icons.flag_circle_rounded),
        ),
      ],
    );
  }

  String _formatRawDate(String raw) {
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return raw.isEmpty ? 'TBA' : raw;
    return DateFormat('MMM d, yyyy').format(parsed);
  }
}

class _WorkspaceChip extends StatelessWidget {
  const _WorkspaceChip({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected
        ? context.scheme.primary
        : context.scheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        selected: selected,
        onSelected: (_) => onTap(),
        showCheckmark: false,
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Text(label),
          ],
        ),
      ),
    );
  }
}

class _CompactStatCard extends StatelessWidget {
  const _CompactStatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 15),
          const SizedBox(height: 3),
          Text(
            value,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(label, style: Theme.of(context).textTheme.labelSmall),
        ],
      ),
    );
  }
}

class _ConferenceTimeline extends StatelessWidget {
  const _ConferenceTimeline({required this.steps});

  final List<ConferenceProgressStep> steps;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < steps.length; i++) ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  Icon(
                    steps[i].isEnabled
                        ? Icons.check_circle_rounded
                        : Icons.radio_button_unchecked_rounded,
                    color: steps[i].isEnabled ? Colors.green : Colors.grey,
                  ),
                  if (i < steps.length - 1)
                    Container(
                      width: 2,
                      height: 30,
                      color: Colors.grey.withValues(alpha: 0.3),
                    ),
                ],
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        steps[i].name,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${steps[i].activityType} • Deadline ${_formatRawDate(steps[i].deadline)}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: context.scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  String _formatRawDate(String raw) {
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return raw.isEmpty ? 'TBA' : raw;
    return DateFormat('MMM d, yyyy').format(parsed);
  }
}

class _PaperSummaryCard extends StatelessWidget {
  const _PaperSummaryCard({
    required this.paper,
    required this.accent,
    required this.onOpen,
    this.cameraReadyMode = false,
  });

  final AuthorPaperSummary paper;
  final Color accent;
  final VoidCallback onOpen;
  final bool cameraReadyMode;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withValues(alpha: 0.28)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              paper.title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _TagChip(
                  text: paper.status,
                  color: accent,
                  icon: Icons.flag_rounded,
                ),
                _TagChip(
                  text:
                      'Score ${paper.averageScore?.toStringAsFixed(1) ?? '—'}',
                  color: Colors.deepPurple,
                  icon: Icons.star_rounded,
                ),
                if (!cameraReadyMode)
                  _TagChip(
                    text: paper.finalDecision ?? 'No decision',
                    color: Colors.teal,
                    icon: Icons.gavel_rounded,
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'Track: ${paper.trackName}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: context.scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: FilledButton.tonalIcon(
                onPressed: onOpen,
                icon: const Icon(Icons.visibility_rounded, size: 18),
                label: const Text('View Details'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TagChip extends StatelessWidget {
  const _TagChip({required this.text, required this.color, required this.icon});

  final String text;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(
            text,
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

class _PaperDetailsScreen extends StatefulWidget {
  const _PaperDetailsScreen({
    required this.paperId,
    required this.conferenceId,
    required this.featureService,
  });

  final int paperId;
  final int conferenceId;
  final MobileFeatureService featureService;

  @override
  State<_PaperDetailsScreen> createState() => _PaperDetailsScreenState();
}

class _PaperDetailsScreenState extends State<_PaperDetailsScreen> {
  bool _expandedAbstract = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Paper Details')),
      body: FutureBuilder<_PaperDetailsBundle>(
        future: _loadBundle(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError)
            return SectionError(message: snapshot.error.toString());

          final data = snapshot.data;
          if (data == null) return const CenteredMutedText('Paper not found.');
          final paper = data.paper;

          final manuscripts = paper.files
              .where(
                (f) =>
                    !f.isCameraReady &&
                    !f.isSupplementary &&
                    !f.isCopyrightSubmission,
              )
              .toList();
          final supplementary = paper.files
              .where((f) => f.isSupplementary)
              .toList();
          final cameraReady = paper.files
              .where((f) => f.isCameraReady)
              .toList();

          return ListView(
            padding: const EdgeInsets.all(AppDimensions.screenPadding),
            children: [
              SectionCard(
                title: paper.title,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _TagChip(
                        text: paper.status,
                        color: Colors.indigo,
                        icon: Icons.flag_rounded,
                      ),
                      _TagChip(
                        text:
                            'Plagiarism: ${paper.plagiarismStatus ?? 'UNKNOWN'}',
                        color: Colors.deepOrange,
                        icon: Icons.plagiarism_rounded,
                      ),
                      _TagChip(
                        text:
                            'Score ${paper.averageScore?.toStringAsFixed(1) ?? '—'}',
                        color: Colors.purple,
                        icon: Icons.star_rounded,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppDimensions.space2),
                  SimpleListTile(
                    title: 'Track',
                    subtitle: paper.trackName,
                    trailing: const Icon(Icons.account_tree_outlined),
                  ),
                  SimpleListTile(
                    title: 'Submitted',
                    subtitle: _formatRawDate(paper.submissionTime),
                    trailing: const Icon(Icons.schedule_rounded),
                  ),
                ],
              ),
              const SizedBox(height: AppDimensions.space3),
              SectionCard(
                title: 'Conference Progress',
                children: data.progress.isEmpty
                    ? const [CenteredMutedText('No conference progress found.')]
                    : [_ConferenceTimeline(steps: data.progress)],
              ),
              const SizedBox(height: AppDimensions.space3),
              SectionCard(
                title: 'Abstract',
                children: [
                  Text(
                    paper.abstractText,
                    maxLines: _expandedAbstract ? null : 4,
                    overflow: _expandedAbstract
                        ? TextOverflow.visible
                        : TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  if (paper.abstractText.split('\n').length > 4 ||
                      (paper.abstractText.length > 200 && !_expandedAbstract))
                    TextButton.icon(
                      onPressed: () => setState(
                        () => _expandedAbstract = !_expandedAbstract,
                      ),
                      icon: Icon(
                        _expandedAbstract
                            ? Icons.expand_less_rounded
                            : Icons.expand_more_rounded,
                      ),
                      label: Text(_expandedAbstract ? 'See less' : 'See full'),
                    ),
                ],
              ),
              const SizedBox(height: AppDimensions.space3),
              SectionCard(
                title: 'Keywords & Subject Areas',
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ...paper.keywords.map(
                        (k) => _TagChip(
                          text: k,
                          color: Colors.cyan,
                          icon: Icons.sell_rounded,
                        ),
                      ),
                      ...paper.subjectAreaNames.map(
                        (s) => _TagChip(
                          text: s,
                          color: Colors.teal,
                          icon: Icons.category_rounded,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: AppDimensions.space3),
              SectionCard(
                title: 'Co-authors',
                children: paper.authorNames.isEmpty
                    ? const [CenteredMutedText('No co-authors listed.')]
                    : paper.authorNames
                          .map(
                            (name) => SimpleListTile(
                              title: name,
                              subtitle: 'Co-author',
                              trailing: const Icon(
                                Icons.person_outline_rounded,
                              ),
                            ),
                          )
                          .toList(),
              ),
              const SizedBox(height: AppDimensions.space3),
              _FileSection(
                title: 'Manuscript Files',
                color: Colors.indigo,
                files: manuscripts,
              ),
              const SizedBox(height: AppDimensions.space3),
              _FileSection(
                title: 'Supplementary Files',
                color: Colors.deepPurple,
                files: supplementary,
              ),
              const SizedBox(height: AppDimensions.space3),
              _FileSection(
                title: 'Camera Ready Files',
                color: Colors.teal,
                files: cameraReady,
              ),
            ],
          );
        },
      ),
    );
  }

  Future<_PaperDetailsBundle> _loadBundle() async {
    final paper = await widget.featureService.getAuthorPaperDetail(
      paperId: widget.paperId,
    );
    final progress = await widget.featureService.getConferenceProgress(
      conferenceId: paper.conferenceId ?? widget.conferenceId,
    );
    return _PaperDetailsBundle(paper: paper, progress: progress);
  }

  String _formatRawDate(String raw) {
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return raw.isEmpty ? '—' : raw;
    return DateFormat('MMM d, yyyy').format(parsed);
  }
}

class _PaperDetailsBundle {
  const _PaperDetailsBundle({required this.paper, required this.progress});

  final AuthorPaperDetail paper;
  final List<ConferenceProgressStep> progress;
}

class _FileSection extends StatelessWidget {
  const _FileSection({
    required this.title,
    required this.color,
    required this.files,
  });

  final String title;
  final Color color;
  final List<AuthorPaperFile> files;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: title,
      children: files.isEmpty
          ? const [CenteredMutedText('No files available.')]
          : files.map((file) {
              final uri = Uri.parse(file.url);
              final name = uri.pathSegments.isNotEmpty
                  ? uri.pathSegments.last
                  : 'file';
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.08),
                  border: Border.all(color: color.withValues(alpha: 0.25)),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.insert_drive_file_rounded, color: color),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(name, overflow: TextOverflow.ellipsis),
                    ),
                    FilledButton.tonalIcon(
                      onPressed: () =>
                          launchUrl(uri, mode: LaunchMode.externalApplication),
                      icon: const Icon(Icons.download_rounded, size: 16),
                      label: const Text('Download'),
                    ),
                  ],
                ),
              );
            }).toList(),
    );
  }
}

class _DebouncedSearch {
  _DebouncedSearch({required this.onSearch});

  final VoidCallback onSearch;
  Timer? _timer;

  void search() {
    _timer?.cancel();
    _timer = Timer(const Duration(milliseconds: 500), onSearch);
  }

  void cancel() {
    _timer?.cancel();
  }
}

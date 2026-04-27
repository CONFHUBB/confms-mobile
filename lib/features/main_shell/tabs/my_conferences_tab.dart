import 'package:confms_mobile/constants/app_theme.dart';
import 'package:confms_mobile/constants/dimensions.dart';
import 'package:confms_mobile/features/main_shell/widgets/main_tab_scaffold.dart';
import 'package:confms_mobile/features/main_shell/widgets/shell_shared_widgets.dart';
import 'package:confms_mobile/models/auth_user.dart';
import 'package:confms_mobile/services/mobile_feature_service.dart';
import 'package:confms_mobile/utils/date_time_display.dart';
import 'package:flutter/material.dart';

const int _pageSize = 10;

/// Chair/Program Chair management view — shows only conferences where user
/// has a CHAIR or PROGRAM_CHAIR role.
class MyConferencesTab extends StatefulWidget {
  const MyConferencesTab({
    super.key,
    required this.featureService,
    required this.user,
    this.onMenuTap,
  });

  final MobileFeatureService featureService;
  final AuthUser? user;
  final VoidCallback? onMenuTap;

  @override
  State<MyConferencesTab> createState() => _MyConferencesTabState();
}

class _MyConferencesTabState extends State<MyConferencesTab> {
  List<AuthorConferenceSummary> _allData = [];
  bool _loading = true;
  String? _error;

  // Search + filter + pagination
  String _searchQuery = '';
  String _statusFilter = 'All';
  int _currentPage = 0;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final userId = widget.user?.id;
    if (userId == null) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final list =
          await widget.featureService.getAllMyConferences(userId: userId);
      final filtered = list
          .where((c) => c.roles.any((r) =>
              r.toUpperCase().contains('CHAIR') ||
              r.toUpperCase().contains('ORGANIZER')))
          .toList();
      if (!mounted) return;
      setState(() {
        _allData = filtered;
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

  // ── Derived computed list ──
  List<AuthorConferenceSummary> get _filteredList {
    var result = _allData;

    // Status filter
    if (_statusFilter != 'All') {
      result = result
          .where(
              (c) => c.status.toUpperCase() == _statusFilter.toUpperCase())
          .toList();
    }

    // Search
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      result = result
          .where((c) =>
              c.conferenceName.toLowerCase().contains(q) ||
              c.acronym.toLowerCase().contains(q) ||
              c.location.toLowerCase().contains(q))
          .toList();
    }

    return result;
  }

  List<AuthorConferenceSummary> get _pagedList {
    final start = _currentPage * _pageSize;
    if (start >= _filteredList.length) return [];
    return _filteredList.skip(start).take(_pageSize).toList();
  }

  int get _totalPages => (_filteredList.length / _pageSize).ceil().clamp(1, 999);

  Set<String> get _availableStatuses {
    final set = <String>{'All'};
    for (final c in _allData) {
      if (c.status.isNotEmpty) {
        set.add(c.status[0].toUpperCase() + c.status.substring(1).toLowerCase());
      }
    }
    return set;
  }

  @override
  Widget build(BuildContext context) {
    final userId = widget.user?.id;

    return MainTabScaffold(
      title: 'My Conferences',
      subtitle: 'Conferences you organise or chair.',
      icon: Icons.admin_panel_settings_rounded,
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
      onRefresh: _loadData,
      child: Column(
        children: [
          // ── Search bar ──
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppDimensions.screenPadding,
              8,
              AppDimensions.screenPadding,
              0,
            ),
            child: TextField(
              controller: _searchController,
              onChanged: (v) => setState(() {
                _searchQuery = v;
                _currentPage = 0;
              }),
              decoration: InputDecoration(
                hintText: 'Search conferences...',
                hintStyle: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: context.scheme.onSurfaceVariant),
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _searchQuery = '';
                            _currentPage = 0;
                          });
                        },
                      )
                    : null,
                filled: true,
                fillColor: context.scheme.surfaceContainerLow,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 10),
                isDense: true,
              ),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),

          // ── Filter chips ──
          if (_availableStatuses.length > 2)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppDimensions.screenPadding,
                8,
                AppDimensions.screenPadding,
                0,
              ),
              child: SizedBox(
                height: 32,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: _availableStatuses.map((s) {
                    final active = _statusFilter == s;
                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: FilterChip(
                        label: Text(s, style: const TextStyle(fontSize: 12)),
                        selected: active,
                        onSelected: (_) => setState(() {
                          _statusFilter = s;
                          _currentPage = 0;
                        }),
                        selectedColor:
                            context.scheme.primary.withValues(alpha: 0.12),
                        checkmarkColor: context.scheme.primary,
                        padding: EdgeInsets.zero,
                        visualDensity: VisualDensity.compact,
                        materialTapTargetSize:
                            MaterialTapTargetSize.shrinkWrap,
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),

          const SizedBox(height: 4),

          // ── Results info ──
          Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: AppDimensions.screenPadding),
            child: Row(
              children: [
                Text(
                  '${_filteredList.length} conference${_filteredList.length == 1 ? '' : 's'}',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: context.scheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                if (_totalPages > 1)
                  Text(
                    'Page ${_currentPage + 1} of $_totalPages',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: context.scheme.onSurfaceVariant),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 4),

          // ── List ──
          Expanded(
            child: _filteredList.isEmpty
                ? _buildEmpty(context)
                : ListView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppDimensions.screenPadding,
                    ),
                    children: [
                      _ChairStats(conferences: _filteredList),
                      const SizedBox(height: AppDimensions.space3),
                      ..._pagedList.map(
                        (conf) => Padding(
                          padding: const EdgeInsets.only(
                              bottom: AppDimensions.space3),
                          child: _ChairConferenceCard(
                            conference: conf,
                            onTap: () => Navigator.pushNamed(
                              context,
                              '/conference-detail',
                              arguments: conf.conferenceId,
                            ),
                          ),
                        ),
                      ),
                      // ── Pagination controls ──
                      if (_totalPages > 1)
                        _PaginationControls(
                          currentPage: _currentPage,
                          totalPages: _totalPages,
                          onPageChanged: (p) =>
                              setState(() => _currentPage = p),
                        ),
                      const SizedBox(height: 16),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty(BuildContext context) {
    final hasSearch = _searchQuery.isNotEmpty || _statusFilter != 'All';
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              hasSearch
                  ? Icons.search_off_rounded
                  : Icons.event_busy_rounded,
              size: 56,
              color: context.scheme.onSurfaceVariant.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 12),
            Text(
              hasSearch ? 'No matching conferences' : 'No conferences to manage',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(color: context.scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 4),
            Text(
              hasSearch
                  ? 'Try adjusting your search or filters.'
                  : 'You don\'t have a Chair or Program Chair\nrole in any conference yet.',
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: context.scheme.onSurfaceVariant),
            ),
            if (hasSearch)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: TextButton.icon(
                  onPressed: () {
                    _searchController.clear();
                    setState(() {
                      _searchQuery = '';
                      _statusFilter = 'All';
                      _currentPage = 0;
                    });
                  },
                  icon: const Icon(Icons.clear_rounded, size: 16),
                  label: const Text('Clear filters'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
//  Pagination Controls
// ═══════════════════════════════════════════════════════════════════════
class _PaginationControls extends StatelessWidget {
  const _PaginationControls({
    required this.currentPage,
    required this.totalPages,
    required this.onPageChanged,
  });
  final int currentPage;
  final int totalPages;
  final ValueChanged<int> onPageChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _PageBtn(
            icon: Icons.chevron_left_rounded,
            enabled: currentPage > 0,
            onTap: () => onPageChanged(currentPage - 1),
          ),
          const SizedBox(width: 4),
          // Page numbers
          ...List.generate(totalPages.clamp(0, 7), (i) {
            int page;
            if (totalPages <= 7) {
              page = i;
            } else if (currentPage < 4) {
              page = i;
            } else if (currentPage > totalPages - 5) {
              page = totalPages - 7 + i;
            } else {
              page = currentPage - 3 + i;
            }

            final isActive = page == currentPage;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: InkWell(
                onTap: () => onPageChanged(page),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: isActive
                        ? context.scheme.primary
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '${page + 1}',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: isActive
                              ? context.scheme.onPrimary
                              : context.scheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
              ),
            );
          }),
          const SizedBox(width: 4),
          _PageBtn(
            icon: Icons.chevron_right_rounded,
            enabled: currentPage < totalPages - 1,
            onTap: () => onPageChanged(currentPage + 1),
          ),
        ],
      ),
    );
  }
}

class _PageBtn extends StatelessWidget {
  const _PageBtn({
    required this.icon,
    required this.enabled,
    required this.onTap,
  });
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: context.scheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(8),
        ),
        alignment: Alignment.center,
        child: Icon(icon,
            size: 20,
            color: enabled
                ? context.scheme.onSurface
                : context.scheme.onSurfaceVariant.withValues(alpha: 0.3)),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
//  Existing sub-widgets (unchanged)
// ═══════════════════════════════════════════════════════════════════════
class _ChairStats extends StatelessWidget {
  const _ChairStats({required this.conferences});
  final List<AuthorConferenceSummary> conferences;

  @override
  Widget build(BuildContext context) {
    final active = conferences
        .where((c) =>
            c.status.toLowerCase() == 'active' ||
            c.status.toLowerCase() == 'ongoing')
        .length;

    return Row(children: [
      Expanded(
        child: _MiniStat(
            label: 'Managing',
            value: '${conferences.length}',
            color: Colors.purple,
            icon: Icons.admin_panel_settings_rounded),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: _MiniStat(
            label: 'Active',
            value: '$active',
            color: Colors.green,
            icon: Icons.play_circle_rounded),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: _MiniStat(
            label: 'Completed',
            value: '${conferences.length - active}',
            color: Colors.grey,
            icon: Icons.check_circle_rounded),
      ),
    ]);
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({
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
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(height: 4),
        Text(value,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w800, color: color)),
        Text(label, style: Theme.of(context).textTheme.labelSmall),
      ]),
    );
  }
}

class _ChairConferenceCard extends StatelessWidget {
  const _ChairConferenceCard({
    required this.conference,
    required this.onTap,
  });
  final AuthorConferenceSummary conference;
  final VoidCallback onTap;

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'active':
      case 'ongoing':
        return Colors.green;
      case 'upcoming':
        return Colors.blue;
      case 'completed':
      case 'finished':
        return Colors.grey;
      default:
        return Colors.orange;
    }
  }

  String _formatDate(String raw) {
    return formatDateTimeYmdHms(raw);
  }

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(conference.status);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
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
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.purple.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.admin_panel_settings_rounded,
                  color: Colors.purple, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(conference.conferenceName,
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: color.withValues(alpha: 0.3)),
              ),
              child: Text(conference.status,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: color, fontWeight: FontWeight.w700)),
            ),
          ]),
          if (conference.acronym.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(conference.acronym,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: context.scheme.primary,
                    fontWeight: FontWeight.w600)),
          ],
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: conference.roles
                .where((r) =>
                    r.toUpperCase().contains('CHAIR') ||
                    r.toUpperCase().contains('ORGANIZER'))
                .map((role) {
              final clean =
                  role.replaceAll('ROLE_', '').replaceAll('_', ' ');
              return Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.purple.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(clean,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Colors.purple,
                        fontWeight: FontWeight.w600,
                        fontSize: 10)),
              );
            }).toList(),
          ),
          const SizedBox(height: 8),
          Row(children: [
            Icon(Icons.location_on_outlined,
                size: 14, color: context.scheme.onSurfaceVariant),
            const SizedBox(width: 4),
            Expanded(
              child: Text(conference.location,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: context.scheme.onSurfaceVariant),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
            ),
          ]),
          const SizedBox(height: 4),
          Row(children: [
            Icon(Icons.calendar_month_outlined,
                size: 14, color: context.scheme.onSurfaceVariant),
            const SizedBox(width: 4),
            Text(
                '${_formatDate(conference.startDate)} — ${_formatDate(conference.endDate)}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: context.scheme.onSurfaceVariant)),
          ]),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: context.scheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(children: [
              Icon(Icons.info_outline_rounded,
                  size: 14, color: context.scheme.onSurfaceVariant),
              const SizedBox(width: 6),
              Expanded(
                child: Text('Manage on the web app for full features',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: context.scheme.onSurfaceVariant)),
              ),
              Icon(Icons.arrow_forward_ios_rounded,
                  size: 12, color: context.scheme.onSurfaceVariant),
            ]),
          ),
        ]),
      ),
    );
  }
}

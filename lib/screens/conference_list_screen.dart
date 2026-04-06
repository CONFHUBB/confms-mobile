import 'package:confms_mobile/constants/colors.dart';
import 'package:confms_mobile/constants/dimensions.dart';
import 'package:confms_mobile/constants/text_styles.dart';
import 'package:confms_mobile/models/conference.dart';
import 'package:confms_mobile/services/api_service.dart';
import 'package:confms_mobile/services/conference_service.dart';
import 'package:confms_mobile/widgets/conference_list_item.dart';
import 'package:confms_mobile/widgets/custom_button.dart';
import 'package:confms_mobile/widgets/custom_text_field.dart';
import 'package:flutter/material.dart';

class ConferenceListScreen extends StatefulWidget {
  const ConferenceListScreen({
    super.key,
    required this.conferenceService,
    required this.onLogout,
  });

  final ConferenceService conferenceService;
  final Future<void> Function() onLogout;

  @override
  State<ConferenceListScreen> createState() => _ConferenceListScreenState();
}

class _ConferenceListScreenState extends State<ConferenceListScreen> {
  final TextEditingController _searchController = TextEditingController();

  List<Conference> _conferences = <Conference>[];
  bool _isLoading = true;
  String? _error;

  String _selectedLocation = 'All';
  String _selectedArea = 'All';
  String _query = '';

  @override
  void initState() {
    super.initState();
    _loadConferences();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadConferences() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final page = await widget.conferenceService.getConferences();
      if (!mounted) return;
      setState(() {
        _conferences = page.content;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.statusCode == 401 || e.statusCode == 403) {
        await widget.onLogout();
        if (!mounted) return;
        Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
        return;
      }
      setState(() => _error = e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Failed to load conferences. Please try again.');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  List<String> get _locations {
    final set =
        _conferences
            .map((e) => e.location.trim())
            .where((e) => e.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    return <String>['All', ...set];
  }

  List<String> get _areas {
    final set =
        _conferences
            .map((e) => e.area.trim())
            .where((e) => e.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    return <String>['All', ...set];
  }

  List<Conference> get _filteredConferences {
    return _conferences.where((conference) {
      final matchesLocation =
          _selectedLocation == 'All' ||
          conference.location == _selectedLocation;
      final matchesArea =
          _selectedArea == 'All' || conference.area == _selectedArea;
      final q = _query.trim().toLowerCase();
      final matchesQuery =
          q.isEmpty ||
          conference.name.toLowerCase().contains(q) ||
          conference.acronym.toLowerCase().contains(q) ||
          conference.description.toLowerCase().contains(q);

      return matchesLocation && matchesArea && matchesQuery;
    }).toList();
  }

  Future<void> _openFilterSheet() async {
    String tempLocation = _selectedLocation;
    String tempArea = _selectedArea;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppDimensions.radiusLg),
        ),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                AppDimensions.screenPadding,
                AppDimensions.space4,
                AppDimensions.screenPadding,
                MediaQuery.of(context).viewInsets.bottom + AppDimensions.space4,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Filters', style: AppTextStyles.title),
                  const SizedBox(height: AppDimensions.space4),
                  DropdownButtonFormField<String>(
                    initialValue: tempLocation,
                    decoration: const InputDecoration(
                      labelText: 'Location',
                      border: OutlineInputBorder(),
                    ),
                    items: _locations
                        .map(
                          (location) => DropdownMenuItem<String>(
                            value: location,
                            child: Text(location),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      setModalState(() => tempLocation = value);
                    },
                  ),
                  const SizedBox(height: AppDimensions.space3),
                  DropdownButtonFormField<String>(
                    initialValue: tempArea,
                    decoration: const InputDecoration(
                      labelText: 'Research area',
                      border: OutlineInputBorder(),
                    ),
                    items: _areas
                        .map(
                          (area) => DropdownMenuItem<String>(
                            value: area,
                            child: Text(area),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      setModalState(() => tempArea = value);
                    },
                  ),
                  const SizedBox(height: AppDimensions.space4),
                  Row(
                    children: [
                      Expanded(
                        child: CustomButton(
                          label: 'Reset',
                          variant: CustomButtonVariant.outline,
                          onPressed: () {
                            setModalState(() {
                              tempLocation = 'All';
                              tempArea = 'All';
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: AppDimensions.space3),
                      Expanded(
                        child: CustomButton(
                          label: 'Apply',
                          onPressed: () {
                            setState(() {
                              _selectedLocation = tempLocation;
                              _selectedArea = tempArea;
                            });
                            Navigator.pop(context);
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredConferences;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Conferences'),
        actions: [
          IconButton(
            onPressed: () async {
              await widget.onLogout();
              if (!context.mounted) return;
              Navigator.pushNamedAndRemoveUntil(
                context,
                '/login',
                (_) => false,
              );
            },
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
          ),
          IconButton(
            onPressed: _openFilterSheet,
            icon: const Icon(Icons.tune),
            tooltip: 'Filters',
          ),
        ],
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? _ErrorState(message: _error!, onRetry: _loadConferences)
            : RefreshIndicator(
                onRefresh: _loadConferences,
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(
                        AppDimensions.screenPadding,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Browse and discover conferences',
                            style: AppTextStyles.bodyMuted,
                          ),
                          const SizedBox(height: AppDimensions.space3),
                          CustomTextField(
                            controller: _searchController,
                            hintText:
                                'Search by conference name, acronym, or description',
                            prefixIcon: const Icon(
                              Icons.search,
                              color: AppColors.textSecondary,
                            ),
                            onChanged: (value) =>
                                setState(() => _query = value),
                            textInputAction: TextInputAction.search,
                          ),
                          const SizedBox(height: AppDimensions.space3),
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                _FilterChip(
                                  label: 'Location: $_selectedLocation',
                                ),
                                const SizedBox(width: AppDimensions.space2),
                                _FilterChip(label: 'Area: $_selectedArea'),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: filtered.isEmpty
                          ? const _EmptyState()
                          : ListView.separated(
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: const EdgeInsets.fromLTRB(
                                AppDimensions.screenPadding,
                                0,
                                AppDimensions.screenPadding,
                                AppDimensions.space6,
                              ),
                              itemCount: filtered.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(height: AppDimensions.space3),
                              itemBuilder: (context, index) {
                                final conference = filtered[index];
                                return ConferenceListItem(
                                  conference: conference,
                                  onTap: () {
                                    Navigator.pushNamed(
                                      context,
                                      '/conference-detail',
                                      arguments: conference.id,
                                    );
                                  },
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.muted,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(label, style: AppTextStyles.caption),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.screenPadding),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline,
              color: AppColors.destructive,
              size: 40,
            ),
            const SizedBox(height: AppDimensions.space3),
            Text(
              message,
              style: AppTextStyles.body,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppDimensions.space3),
            CustomButton(label: 'Retry', onPressed: onRetry),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(AppDimensions.screenPadding),
        child: Text(
          'No conferences match your filters.',
          style: AppTextStyles.bodyMuted,
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

import 'package:confms_mobile/services/api_service.dart';

class ConferenceUserTrackService {
  ConferenceUserTrackService(this._apiService);

  final ApiService _apiService;

  /// Current backend endpoint:
  /// GET /api/v1/conference-user-tracks/users/{userId}/my-roles
  Future<List<ConferenceRoleEntry>> getMyConferenceRoles(int userId) async {
    final data = await _apiService.getAny(
      '/conference-user-tracks/users/$userId/my-roles',
    );

    if (data is! List) return const <ConferenceRoleEntry>[];

    final grouped = <int, Set<String>>{};
    for (final raw in data) {
      if (raw is! Map<String, dynamic>) continue;
      final conferenceId = _toInt(raw['conferenceId']);
      if (conferenceId == null) continue;
      final role = (raw['assignedRole'] ?? 'UNKNOWN').toString();
      grouped.putIfAbsent(conferenceId, () => <String>{}).add(role);
    }

    return grouped.entries
        .map(
          (e) => ConferenceRoleEntry(
            conferenceId: e.key,
            conferenceName: 'Conference #${e.key}',
            roles: e.value.toList()..sort(),
          ),
        )
        .toList()
      ..sort((a, b) => a.conferenceId.compareTo(b.conferenceId));
  }

  int? _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }
}

class ConferenceRoleEntry {
  const ConferenceRoleEntry({
    required this.conferenceId,
    required this.conferenceName,
    required this.roles,
  });

  final int conferenceId;
  final String conferenceName;
  final List<String> roles;

  bool get isAuthor => roles.any((r) => r.toUpperCase().contains('AUTHOR'));
  bool get isReviewer => roles.any((r) => r.toUpperCase().contains('REVIEWER'));
}

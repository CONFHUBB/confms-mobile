import 'package:confms_mobile/models/user_profile.dart';
import 'package:confms_mobile/services/api_service.dart';

class MobileFeatureService {
  MobileFeatureService(this._apiService);

  final ApiService _apiService;

  /// Placeholder aggregator for Home tab.
  ///
  /// Planned backend sources:
  /// - Upcoming sessions: GET /api/v1/conferences/{conferenceId}/program
  /// - Ticket preview: GET /api/v1/my-tickets?userId={userId}
  /// - Pending reviews: GET /api/v1/review/reviewer/{reviewerId}/conference/{conferenceId}
  /// - Submission updates: GET /api/v1/paper/author/{authorId}
  /// - Notifications preview: GET /api/v1/notifications/user/{userId}
  Future<HomeDashboardData> getHomeDashboard({required int userId}) async {
    final tickets = await getMyTickets(userId: userId);
    final notifications = await getNotifications(userId: userId);
    final schedule = await getMySchedule(userId: userId);
    final pendingReviews = await getPendingReviews(userId: userId);
    final submissionUpdates = await getSubmissionUpdates(userId: userId);

    return HomeDashboardData(
      upcomingSessions: schedule.take(5).toList(),
      myTickets: tickets,
      pendingReviews: pendingReviews,
      submissionUpdates: submissionUpdates,
      announcements: notifications
          .take(3)
          .map(
            (n) => AnnouncementPreview(
              id: n.id,
              title: n.title,
              subtitle: n.message,
            ),
          )
          .toList(),
    );
  }

  /// Backend:
  /// - GET /api/v1/conference-user-tracks/users/{userId}/my-roles
  /// - GET /api/v1/review/reviewer/{reviewerId}/conference/{conferenceId}
  Future<List<TaskPreview>> getPendingReviews({required int userId}) async {
    final rolesData = await _apiService.getAny(
      '/conference-user-tracks/users/$userId/my-roles',
    );
    if (rolesData is! List) return const <TaskPreview>[];

    final reviewerConferenceIds = <int>{};
    final conferenceNames = <int, String>{};

    for (final row in rolesData.whereType<Map<String, dynamic>>()) {
      final role = _string(row['assignedRole'], fallback: '').toUpperCase();
      if (!role.contains('REVIEWER')) continue;

      final conferenceId = _toInt(row['conferenceId']);
      if (conferenceId == null) continue;
      reviewerConferenceIds.add(conferenceId);

      final conferenceName = _string(row['conferenceName'], fallback: '');
      if (conferenceName.isNotEmpty) {
        conferenceNames[conferenceId] = conferenceName;
      }
    }

    if (reviewerConferenceIds.isEmpty) return const <TaskPreview>[];

    final tasks = <TaskPreview>[];
    for (final conferenceId in reviewerConferenceIds) {
      final data = await _apiService.getAny(
        '/review/reviewer/$userId/conference/$conferenceId',
      );
      if (data is! List) continue;

      final conferenceLabel = conferenceNames[conferenceId] ??
          'Conference #$conferenceId';

      for (final review in data.whereType<Map<String, dynamic>>()) {
        final paper = review['paper'];
        final paperMap = paper is Map<String, dynamic>
            ? paper
            : const <String, dynamic>{};

        final reviewId = _toInt(review['id']) ?? 0;
        final paperId = _toInt(paperMap['id']) ?? 0;
        final paperTitle = _string(
          paperMap['title'],
          fallback: 'Paper #$paperId',
        );
        final status = _string(review['status'], fallback: 'PENDING');

        tasks.add(
          TaskPreview(
            id: 'review-$reviewId',
            title: paperTitle,
            subtitle: '$conferenceLabel • Status: $status',
            conferenceId: conferenceId,
          ),
        );
      }
    }

    return tasks;
  }

  /// Backend: GET /api/v1/paper/author/{authorId}?page=0&size=20
  Future<List<TaskPreview>> getSubmissionUpdates({required int userId}) async {
    final data = await _apiService.getAny('/paper/author/$userId?page=0&size=20');
    if (data is! Map<String, dynamic>) return const <TaskPreview>[];

    final content = data['content'];
    if (content is! List) return const <TaskPreview>[];

    return content.whereType<Map<String, dynamic>>().map((paper) {
      final paperId = _toInt(paper['id']) ?? 0;
      final title = _string(paper['title'], fallback: 'Paper #$paperId');
      final conferenceName = _string(
        paper['conferenceName'],
        fallback: _string(paper['trackName'], fallback: 'Conference'),
      );
      final status = _string(paper['status'], fallback: 'SUBMITTED');

      return TaskPreview(
        id: 'paper-$paperId',
        title: title,
        subtitle: '$conferenceName • Status: $status',
        conferenceId: _toInt(paper['conferenceId']),
      );
    }).toList();
  }

  /// Backend: GET /api/v1/my-tickets?userId={userId}
  Future<List<TicketPreview>> getMyTickets({required int userId}) async {
    final data = await _apiService.getAny('/my-tickets?userId=$userId');
    if (data is! List) return const <TicketPreview>[];

    return data.whereType<Map<String, dynamic>>().map((raw) {
      final id = _toInt(raw['id']) ?? 0;
      final conferenceName = _string(raw['conferenceName'], fallback: 'Conference');
      final ticketType = _string(raw['ticketTypeName'], fallback: 'Ticket');
      final qrCodeValue = _string(raw['qrCode'], fallback: '-');
      final isCheckedIn = raw['isCheckedIn'] == true;
      final status = _string(raw['paymentStatus'], fallback: 'UNKNOWN').toUpperCase();

      return TicketPreview(
        ticketId: id,
        conferenceId: _toInt(raw['conferenceId']),
        conferenceName: conferenceName,
        ticketType: ticketType,
        qrCodeValue: qrCodeValue,
        checkInStatus: isCheckedIn ? 'Checked in' : 'Not checked in',
        paymentStatus: status,
      );
    }).toList();
  }

  /// Backend:
  /// - GET /api/v1/conferences/{conferenceId}/program
  /// - GET /api/v1/session-bookmarks/{conferenceId}
  Future<List<SessionPreview>> getMySchedule({required int userId}) async {
    final tickets = await getMyTickets(userId: userId);
    final conferenceIds = tickets
        .map((t) => t.conferenceId)
        .whereType<int>()
        .toSet()
        .toList();

    if (conferenceIds.isEmpty) return const <SessionPreview>[];

    final sessions = <SessionPreview>[];

    for (final conferenceId in conferenceIds) {
      final bookmarkedIds = await _getBookmarkedIds(conferenceId);
      final conferenceName = tickets
          .firstWhere((t) => t.conferenceId == conferenceId)
          .conferenceName;

      final program = await _apiService.getAny('/conferences/$conferenceId/program');
      final extracted = _extractProgramSessions(program);

      for (final map in extracted) {
        final id = _string(
          map['id'] ?? map['sessionId'] ?? map['code'],
          fallback: 'session-${sessions.length + 1}',
        );
        final title = _string(
          map['title'] ?? map['name'] ?? map['sessionTitle'],
          fallback: 'Untitled session',
        );

        final start = _string(
          map['startTime'] ?? map['start'] ?? map['time'],
          fallback: '',
        );
        final room = _string(map['room'] ?? map['location'], fallback: 'TBA');
        final speaker = _string(
          map['speaker'] ?? map['speakerName'] ?? map['presenter'],
          fallback: 'TBA',
        );

        final subtitle = [start, room, speaker]
            .where((e) => e.trim().isNotEmpty)
            .join(' • ');

        sessions.add(
          SessionPreview(
            id: id,
            title: title,
            subtitle: subtitle.isEmpty ? 'Session details unavailable' : subtitle,
            conferenceName: conferenceName,
            isBookmarked: bookmarkedIds.contains(id),
          ),
        );
      }
    }

    return sessions;
  }

  /// Filter schedule by bookmark state.
  Future<List<SessionPreview>> getBookmarkedSessions({
    required int userId,
  }) async {
    return (await getMySchedule(userId: userId))
        .where((s) => s.isBookmarked)
        .toList();
  }

  /// Backend: GET /api/v1/notifications/user/{userId}?page=0&size=20
  Future<List<NotificationPreview>> getNotifications({
    required int userId,
  }) async {
    final data = await _apiService.getAny('/notifications/user/$userId?page=0&size=20');
    if (data is! Map<String, dynamic>) return const <NotificationPreview>[];

    final content = data['content'];
    if (content is! List) return const <NotificationPreview>[];

    return content.whereType<Map<String, dynamic>>().map((raw) {
      final type = _string(raw['type'], fallback: '').toUpperCase();
      return NotificationPreview(
        id: _toInt(raw['id']) ?? 0,
        title: _string(raw['title'], fallback: 'Notification'),
        message: _string(raw['message'], fallback: ''),
        deepLinkHint: _string(
          raw['link'],
          fallback: type.contains('REVIEW')
              ? 'Contribute'
              : type.contains('PAYMENT')
              ? 'Attend → My Tickets'
              : 'Home',
        ),
        isRead: raw['isRead'] == true,
      );
    }).toList();
  }

  /// Backend: GET /api/v1/my-payment-history?userId={userId}
  Future<List<PaymentHistoryPreview>> getPaymentHistory({
    required int userId,
  }) async {
    final data = await _apiService.getAny('/my-payment-history?userId=$userId');
    if (data is! List) return const <PaymentHistoryPreview>[];

    return data.whereType<Map<String, dynamic>>().map((raw) {
      final amount = _toInt(raw['amount']) ?? 0;
      final registrationNumber = _string(raw['registrationNumber'], fallback: '-');
      final payDate = _string(raw['payDate'], fallback: '');
      final recordedAt = _string(raw['recordedAt'], fallback: '');

      return PaymentHistoryPreview(
        id: _toInt(raw['id']) ?? 0,
        conferenceName: 'Ticket #$registrationNumber',
        amountLabel: _formatCurrencyVnd(amount),
        status: _string(raw['outcome'], fallback: 'UNKNOWN'),
        timestampLabel: payDate.isNotEmpty ? payDate : recordedAt,
      );
    }).toList();
  }

  /// Backend: GET /api/v1/users/{userId}/profile
  Future<UserProfileData?> getUserProfile({required int userId}) async {
    try {
      final data = await _apiService.get('/users/$userId/profile');
      return UserProfileData.fromJson(data);
    } on ApiException catch (error) {
      if (error.statusCode == 404) {
        return null;
      }
      rethrow;
    }
  }

  /// Backend: PUT /api/v1/users/{userId}/profile
  Future<UserProfileData> upsertUserProfile({
    required int userId,
    required UserProfileData profile,
  }) async {
    final data = await _apiService.put(
      '/users/$userId/profile',
      body: profile.toRequestJson(),
    );
    return UserProfileData.fromJson(data);
  }

  Future<Set<String>> _getBookmarkedIds(int conferenceId) async {
    final data = await _apiService.getAny('/session-bookmarks/$conferenceId');
    if (data is! List) return <String>{};
    return data.map((e) => e.toString()).toSet();
  }

  List<Map<String, dynamic>> _extractProgramSessions(dynamic data) {
    final sessions = <Map<String, dynamic>>[];

    void walk(dynamic node) {
      if (node is List) {
        for (final item in node) {
          walk(item);
        }
        return;
      }

      if (node is! Map<String, dynamic>) return;

      final hasSessionSignals =
          node.containsKey('id') &&
          (node.containsKey('title') ||
              node.containsKey('name') ||
              node.containsKey('sessionTitle'));
      if (hasSessionSignals) {
        sessions.add(node);
      }

      for (final value in node.values) {
        walk(value);
      }
    }

    walk(data);
    return sessions;
  }

  int? _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  String _string(dynamic value, {required String fallback}) {
    final asString = value?.toString() ?? '';
    return asString.trim().isEmpty ? fallback : asString;
  }

  String _formatCurrencyVnd(int amount) {
    final digits = amount.toString();
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      final fromEnd = digits.length - i;
      buffer.write(digits[i]);
      if (fromEnd > 1 && fromEnd % 3 == 1) {
        buffer.write(',');
      }
    }
    return '${buffer.toString()} VND';
  }
}

class HomeDashboardData {
  const HomeDashboardData({
    required this.upcomingSessions,
    required this.myTickets,
    required this.pendingReviews,
    required this.submissionUpdates,
    required this.announcements,
  });

  final List<SessionPreview> upcomingSessions;
  final List<TicketPreview> myTickets;
  final List<TaskPreview> pendingReviews;
  final List<TaskPreview> submissionUpdates;
  final List<AnnouncementPreview> announcements;
}

class SessionPreview {
  const SessionPreview({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.conferenceName,
    required this.isBookmarked,
  });

  final String id;
  final String title;
  final String subtitle;
  final String conferenceName;
  final bool isBookmarked;
}

class TicketPreview {
  const TicketPreview({
    required this.ticketId,
    this.conferenceId,
    required this.conferenceName,
    required this.ticketType,
    required this.qrCodeValue,
    required this.checkInStatus,
    this.paymentStatus,
  });

  final int ticketId;
  final int? conferenceId;
  final String conferenceName;
  final String ticketType;
  final String qrCodeValue;
  final String checkInStatus;
  final String? paymentStatus;
}

class TaskPreview {
  const TaskPreview({
    required this.id,
    required this.title,
    required this.subtitle,
    this.conferenceId,
  });

  final String id;
  final String title;
  final String subtitle;
  final int? conferenceId;
}

class AnnouncementPreview {
  const AnnouncementPreview({
    required this.id,
    required this.title,
    required this.subtitle,
  });

  final int id;
  final String title;
  final String subtitle;
}

class NotificationPreview {
  const NotificationPreview({
    required this.id,
    required this.title,
    required this.message,
    required this.deepLinkHint,
    required this.isRead,
  });

  final int id;
  final String title;
  final String message;
  final String deepLinkHint;
  final bool isRead;
}

class PaymentHistoryPreview {
  const PaymentHistoryPreview({
    required this.id,
    required this.conferenceName,
    required this.amountLabel,
    required this.status,
    required this.timestampLabel,
  });

  final int id;
  final String conferenceName;
  final String amountLabel;
  final String status;
  final String timestampLabel;
}

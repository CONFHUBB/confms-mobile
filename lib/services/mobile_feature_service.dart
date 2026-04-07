import 'dart:io';

import 'package:confms_mobile/models/user_profile.dart';
import 'package:confms_mobile/services/api_service.dart';

const int _authorPaperPageSize = 100;

class MobileFeatureService {
  MobileFeatureService(this._apiService);

  final ApiService _apiService;

  /// Public reference for screens that need direct API access.
  ApiService get apiServiceRef => _apiService;

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

      final conferenceLabel =
          conferenceNames[conferenceId] ?? 'Conference #$conferenceId';

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
    final data = await _apiService.getAny(
      '/paper/author/$userId?page=0&size=20',
    );
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
      final conferenceName = _string(
        raw['conferenceName'],
        fallback: 'Conference',
      );
      final ticketType = _string(raw['ticketTypeName'], fallback: 'Ticket');
      final qrCodeValue = _string(raw['qrCode'], fallback: '-');
      final isCheckedIn = raw['isCheckedIn'] == true;
      final status = _string(
        raw['paymentStatus'],
        fallback: 'UNKNOWN',
      ).toUpperCase();

      return TicketPreview(
        ticketId: id,
        conferenceId: _toInt(raw['conferenceId']),
        conferenceName: conferenceName,
        ticketType: ticketType,
        qrCodeValue: qrCodeValue,
        checkInStatus: isCheckedIn ? 'Checked in' : 'Not checked in',
        paymentStatus: status,
        registrationNumber: _string(raw['registrationNumber'], fallback: ''),
        paperId: _toInt(raw['paperId']),
        userName: _string(raw['userName'], fallback: ''),
        userEmail: _string(raw['userEmail'], fallback: ''),
        priceLabel: _formatCurrencyVnd((raw['price'] as num?)?.toInt() ?? 0),
        isCheckedIn: isCheckedIn,
        createdAt: _string(raw['createdAt'], fallback: ''),
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

      final program = await _apiService.getAny(
        '/conferences/$conferenceId/program',
      );
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

        final subtitle = [
          start,
          room,
          speaker,
        ].where((e) => e.trim().isNotEmpty).join(' • ');

        sessions.add(
          SessionPreview(
            id: id,
            title: title,
            subtitle: subtitle.isEmpty
                ? 'Session details unavailable'
                : subtitle,
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
    return (await getMySchedule(
      userId: userId,
    )).where((s) => s.isBookmarked).toList();
  }

  /// Backend: GET /api/v1/notifications/user/{userId}?page=0&size=20
  Future<List<NotificationPreview>> getNotifications({
    required int userId,
  }) async {
    final data = await _apiService.getAny(
      '/notifications/user/$userId?page=0&size=20',
    );
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
        type: type,
        createdAt: _string(raw['createdAt'], fallback: ''),
      );
    }).toList();
  }

  /// Mark a single notification as read.
  /// Backend: PUT /api/v1/notifications/{id}/read
  Future<void> markNotificationRead({required int notificationId}) async {
    try {
      await _apiService.put('/notifications/$notificationId/read');
    } catch (_) {}
  }

  /// Mark all notifications as read for a user.
  /// Backend: PUT /api/v1/notifications/user/{userId}/read-all
  Future<void> markAllNotificationsRead({required int userId}) async {
    try {
      await _apiService.put('/notifications/user/$userId/read-all');
    } catch (_) {}
  }

  /// Backend: GET /api/v1/my-payment-history?userId={userId}
  Future<List<PaymentHistoryPreview>> getPaymentHistory({
    required int userId,
  }) async {
    final data = await _apiService.getAny('/my-payment-history?userId=$userId');
    if (data is! List) return const <PaymentHistoryPreview>[];

    return data.whereType<Map<String, dynamic>>().map((raw) {
      final amount = _toInt(raw['amount']) ?? 0;
      final registrationNumber = _string(
        raw['registrationNumber'],
        fallback: '-',
      );
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

  Future<List<AuthorConferenceSummary>> getAuthorConferences({
    required int userId,
  }) async {
    final content = await _fetchAllAuthorPaperRows(userId);
    if (content.isEmpty) return const <AuthorConferenceSummary>[];

    final byConference = <int, List<Map<String, dynamic>>>{};
    for (final row in content) {
      final conferenceId = _toInt(row['conferenceId']);
      if (conferenceId == null) continue;
      byConference
          .putIfAbsent(conferenceId, () => <Map<String, dynamic>>[])
          .add(row);
    }

    final result = <AuthorConferenceSummary>[];
    for (final entry in byConference.entries) {
      final conferenceId = entry.key;
      final papers = entry.value;
      final confData = await _apiService.getAny('/conferences/$conferenceId');
      final conf = confData is Map<String, dynamic>
          ? confData
          : const <String, dynamic>{};

      final status = _string(conf['status'], fallback: 'UNKNOWN');
      final firstPaper = papers.isNotEmpty
          ? papers.first
          : const <String, dynamic>{};
      final conferenceName = _string(
        conf['name'],
        fallback: _string(
          firstPaper['conferenceName'],
          fallback: 'Conference #$conferenceId',
        ),
      );

      result.add(
        AuthorConferenceSummary(
          conferenceId: conferenceId,
          conferenceName: conferenceName,
          acronym: _string(conf['acronym'], fallback: ''),
          location: _string(conf['location'], fallback: 'TBA'),
          status: status,
          startDate: _string(conf['startDate'], fallback: ''),
          endDate: _string(conf['endDate'], fallback: ''),
          myPaperCount: papers.length,
          acceptedCount: papers.where((p) {
            final state = _string(p['status'], fallback: '').toUpperCase();
            return state == 'ACCEPTED' ||
                state == 'PUBLISHED' ||
                state == 'CAMERA_READY';
          }).length,
        ),
      );
    }

    result.sort(
      (a, b) => a.conferenceName.toLowerCase().compareTo(
        b.conferenceName.toLowerCase(),
      ),
    );
    return result;
  }

  /// Fetches ALL conferences the user participates in (any role).
  /// Uses /conference-user-tracks/users/{userId}/my-roles to get all roles,
  /// then fetches conference details for each unique conferenceId.
  Future<List<AuthorConferenceSummary>> getAllMyConferences({
    required int userId,
  }) async {
    final rolesData = await _apiService.getAny(
      '/conference-user-tracks/users/$userId/my-roles',
    );
    if (rolesData is! List) return const <AuthorConferenceSummary>[];

    // Group roles by conferenceId
    final conferenceRoles = <int, Set<String>>{};
    final conferenceNames = <int, String>{};

    for (final row in rolesData.whereType<Map<String, dynamic>>()) {
      final conferenceId = _toInt(row['conferenceId']);
      if (conferenceId == null) continue;

      final role = _string(row['assignedRole'], fallback: '').toUpperCase();
      conferenceRoles.putIfAbsent(conferenceId, () => <String>{}).add(role);

      final name = _string(row['conferenceName'], fallback: '');
      if (name.isNotEmpty) {
        conferenceNames[conferenceId] = name;
      }
    }

    if (conferenceRoles.isEmpty) {
      // Fallback to author-only conferences
      return getAuthorConferences(userId: userId);
    }

    // Also merge author conferences (from paper submissions)
    final authorConfs = await getAuthorConferences(userId: userId);
    final authorConfIds = <int, AuthorConferenceSummary>{};
    for (final ac in authorConfs) {
      authorConfIds[ac.conferenceId] = ac;
      conferenceRoles.putIfAbsent(ac.conferenceId, () => <String>{}).add('AUTHOR');
    }

    final result = <AuthorConferenceSummary>[];
    for (final conferenceId in conferenceRoles.keys) {
      // If we already have author data for this, reuse it
      final existingAuthor = authorConfIds[conferenceId];
      if (existingAuthor != null) {
        result.add(AuthorConferenceSummary(
          conferenceId: existingAuthor.conferenceId,
          conferenceName: existingAuthor.conferenceName,
          acronym: existingAuthor.acronym,
          location: existingAuthor.location,
          status: existingAuthor.status,
          startDate: existingAuthor.startDate,
          endDate: existingAuthor.endDate,
          myPaperCount: existingAuthor.myPaperCount,
          acceptedCount: existingAuthor.acceptedCount,
          roles: conferenceRoles[conferenceId]?.toList() ?? const <String>[],
        ));
        continue;
      }

      // Fetch conference details for non-author conferences
      try {
        final confData = await _apiService.getAny('/conferences/$conferenceId');
        final conf = confData is Map<String, dynamic>
            ? confData
            : const <String, dynamic>{};

        result.add(AuthorConferenceSummary(
          conferenceId: conferenceId,
          conferenceName: _string(
            conf['name'],
            fallback: conferenceNames[conferenceId] ?? 'Conference #$conferenceId',
          ),
          acronym: _string(conf['acronym'], fallback: ''),
          location: _string(conf['location'], fallback: 'TBA'),
          status: _string(conf['status'], fallback: 'UNKNOWN'),
          startDate: _string(conf['startDate'], fallback: ''),
          endDate: _string(conf['endDate'], fallback: ''),
          myPaperCount: 0,
          acceptedCount: 0,
          roles: conferenceRoles[conferenceId]?.toList() ?? const <String>[],
        ));
      } catch (_) {
        // If conference fetch fails, still show with basic info
        result.add(AuthorConferenceSummary(
          conferenceId: conferenceId,
          conferenceName: conferenceNames[conferenceId] ?? 'Conference #$conferenceId',
          acronym: '',
          location: 'TBA',
          status: 'UNKNOWN',
          startDate: '',
          endDate: '',
          myPaperCount: 0,
          acceptedCount: 0,
          roles: conferenceRoles[conferenceId]?.toList() ?? const <String>[],
        ));
      }
    }

    result.sort(
      (a, b) => a.conferenceName.toLowerCase().compareTo(
        b.conferenceName.toLowerCase(),
      ),
    );
    return result;
  }

  Future<List<ConferenceProgressStep>> getConferenceProgress({
    required int conferenceId,
  }) async {
    final data = await _apiService.getAny(
      '/conferences/$conferenceId/activities',
    );
    if (data is! List) return const <ConferenceProgressStep>[];
    return data.whereType<Map<String, dynamic>>().map((raw) {
      return ConferenceProgressStep(
        activityType: _string(raw['activityType'], fallback: 'UNKNOWN'),
        name: _string(raw['name'], fallback: 'Activity'),
        isEnabled: raw['isEnabled'] == true,
        deadline: _string(raw['deadline'], fallback: ''),
      );
    }).toList();
  }

  Future<List<AuthorPaperSummary>> getAuthorPapersByConference({
    required int userId,
    required int conferenceId,
  }) async {
    final content = await _fetchAllAuthorPaperRows(userId);
    if (content.isEmpty) return const <AuthorPaperSummary>[];

    final list = <AuthorPaperSummary>[];
    for (final row in content) {
      if (_toInt(row['conferenceId']) != conferenceId) continue;
      final paperId = _toInt(row['id']) ?? 0;

      final aggregateRaw = await _apiService.getAny(
        '/review-aggregates/paper/$paperId',
      );
      final aggregate = aggregateRaw is Map<String, dynamic>
          ? (aggregateRaw['averageTotalScore'] as num?)?.toDouble()
          : null;

      String? finalDecision;
      try {
        final metaRaw = await _apiService.getAny(
          '/review-meta-review/by-paper/$paperId',
        );
        if (metaRaw is Map<String, dynamic>) {
          finalDecision = _string(metaRaw['finalDecision'], fallback: '');
          if (finalDecision.isEmpty) finalDecision = null;
        }
      } catch (_) {
        finalDecision = null;
      }

      list.add(
        AuthorPaperSummary(
          paperId: paperId,
          title: _string(row['title'], fallback: 'Paper #$paperId'),
          status: _string(row['status'], fallback: 'SUBMITTED'),
          trackName: _string(row['trackName'], fallback: 'Main Track'),
          submissionTime: _string(row['submissionTime'], fallback: ''),
          averageScore: aggregate,
          finalDecision: finalDecision,
        ),
      );
    }

    return list;
  }

  Future<AuthorPaperDetail> getAuthorPaperDetail({required int paperId}) async {
    final raw = await _apiService.getAny('/paper/$paperId');
    final paper = raw is Map<String, dynamic> ? raw : const <String, dynamic>{};

    final fetchedAuthorNames = await getPaperAuthorNames(paperId: paperId);

    final keywordRaw = paper['keywords'];
    final keywords = keywordRaw is List
        ? keywordRaw
              .map((e) => e.toString())
              .where((e) => e.isNotEmpty)
              .toList()
        : const <String>[];

    final secondaryRaw = paper['secondarySubjectAreaIds'];
    final secondarySubjectAreaIds = secondaryRaw is List
        ? secondaryRaw.map(_toInt).whereType<int>().toList()
        : const <int>[];

    final authorRaw = paper['authorNames'];
    final authorNames = authorRaw is List
        ? authorRaw.map((e) => e.toString()).where((e) => e.isNotEmpty).toList()
        : fetchedAuthorNames;

    final subjectAreaNames = await getSubjectAreaNames(
      ids: [
        if (_toInt(paper['primarySubjectAreaId']) != null)
          _toInt(paper['primarySubjectAreaId'])!,
        ...secondarySubjectAreaIds,
      ],
    );

    final filesRaw = await _apiService.getAny('/paper-file/paper/$paperId');
    final files = filesRaw is List
        ? filesRaw
              .whereType<Map<String, dynamic>>()
              .map((f) {
                return AuthorPaperFile(
                  url: _string(f['url'], fallback: ''),
                  isCameraReady: f['isCameraReady'] == true,
                  isCopyrightSubmission: f['isCopyrightSubmission'] == true,
                  isSupplementary: f['isSupplementary'] == true,
                  isActive: f['isActive'] == true,
                );
              })
              .where((f) => f.url.isNotEmpty)
              .toList()
        : const <AuthorPaperFile>[];

    double? average;
    final aggregateRaw = await _apiService.getAny(
      '/review-aggregates/paper/$paperId',
    );
    if (aggregateRaw is Map<String, dynamic>) {
      average = (aggregateRaw['averageTotalScore'] as num?)?.toDouble();
    }

    String? decision;
    try {
      final metaRaw = await _apiService.getAny(
        '/review-meta-review/by-paper/$paperId',
      );
      if (metaRaw is Map<String, dynamic>) {
        final text = _string(metaRaw['finalDecision'], fallback: '');
        decision = text.isEmpty ? null : text;
      }
    } catch (_) {
      decision = null;
    }

    return AuthorPaperDetail(
      paperId: _toInt(paper['id']) ?? paperId,
      conferenceId: _toInt(paper['conferenceId']),
      title: _string(paper['title'], fallback: 'Paper #$paperId'),
      status: _string(paper['status'], fallback: 'SUBMITTED'),
      abstractText: _string(
        paper['abstractField'],
        fallback: 'No abstract provided.',
      ),
      keywords: keywords,
      authorNames: authorNames,
      subjectAreaNames: subjectAreaNames,
      primarySubjectAreaId: _toInt(paper['primarySubjectAreaId']),
      secondarySubjectAreaIds: secondarySubjectAreaIds,
      plagiarismStatus: _string(paper['plagiarismStatus'], fallback: 'UNKNOWN'),
      trackName: _string(paper['trackName'], fallback: 'Main Track'),
      submissionTime: _string(paper['submissionTime'], fallback: ''),
      averageScore: average,
      finalDecision: decision,
      files: files,
    );
  }

  Future<List<String>> getPaperAuthorNames({required int paperId}) async {
    try {
      final data = await _apiService.getAny(
        '/paper-author/paper/$paperId?page=0&size=50',
      );
      if (data is! Map<String, dynamic>) return const <String>[];
      final content = data['content'];
      if (content is! List) return const <String>[];
      return content
          .whereType<Map<String, dynamic>>()
          .map((raw) {
            final user = raw['user'];
            if (user is! Map<String, dynamic>) return '';
            final fullName =
                '${_string(user['firstName'], fallback: '')} ${_string(user['lastName'], fallback: '')}'
                    .trim();
            return fullName.isEmpty
                ? _string(user['email'], fallback: '')
                : fullName;
          })
          .where((name) => name.isNotEmpty)
          .toList();
    } catch (_) {
      return const <String>[];
    }
  }

  Future<List<String>> getSubjectAreaNames({required List<int> ids}) async {
    if (ids.isEmpty) return const <String>[];
    final unique = ids.toSet().toList()..sort();
    final names = <String>[];
    for (final id in unique) {
      try {
        final data = await _apiService.getAny('/subject-areas/$id');
        if (data is Map<String, dynamic>) {
          final name = _string(data['name'], fallback: 'Subject Area #$id');
          names.add(name);
        }
      } catch (_) {
        names.add('Subject Area #$id');
      }
    }
    return names;
  }

  Future<AuthorTicketDetail?> getAuthorTicketForConference({
    required int userId,
    required int conferenceId,
  }) async {
    try {
      final raw = await _apiService.getAny(
        '/conferences/$conferenceId/my-ticket?userId=$userId',
      );
      if (raw is! Map<String, dynamic>) return null;
      return AuthorTicketDetail(
        ticketId: _toInt(raw['id']) ?? 0,
        conferenceName: _string(raw['conferenceName'], fallback: 'Conference'),
        ticketType: _string(raw['ticketTypeName'], fallback: 'Ticket'),
        registrationNumber: _string(raw['registrationNumber'], fallback: '-'),
        qrCode: _string(raw['qrCode'], fallback: '-'),
        paymentStatus: _string(raw['paymentStatus'], fallback: 'UNKNOWN'),
        checkedIn: raw['isCheckedIn'] == true,
        paperId: _toInt(raw['paperId']),
      );
    } on ApiException catch (error) {
      if (error.statusCode == 404) return null;
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> _fetchAllAuthorPaperRows(
    int userId,
  ) async {
    final rows = <Map<String, dynamic>>[];
    var page = 0;

    while (true) {
      final papersRaw = await _apiService.getAny(
        '/paper/author/$userId?page=$page&size=$_authorPaperPageSize',
      );
      if (papersRaw is! Map<String, dynamic>) break;

      final content = papersRaw['content'];
      if (content is! List) break;

      final pageRows = content.whereType<Map<String, dynamic>>().toList();
      rows.addAll(pageRows);

      final isLast = papersRaw['last'] == true;
      if (isLast || pageRows.length < _authorPaperPageSize) break;
      page++;
    }

    return rows;
  }

  String? _extractFilename(String? contentDisposition) {
    if (contentDisposition == null || contentDisposition.trim().isEmpty) {
      return null;
    }

    final lower = contentDisposition.toLowerCase();
    final marker = 'filename=';
    var index = lower.indexOf(marker);
    if (index < 0) return null;

    var value = contentDisposition.substring(index + marker.length).trim();
    if (value.toLowerCase().startsWith("utf-8''")) {
      value = value.substring(7);
    }
    if (value.startsWith('"') && value.endsWith('"')) {
      value = value.substring(1, value.length - 1);
    }
    if (value.contains(';')) {
      value = value.split(';').first;
    }
    return Uri.decodeFull(value).trim();
  }

  Future<DownloadedDocument> downloadDocument({
    required String path,
    String? fallbackFilename,
  }) async {
    final response = await _apiService.getRaw(path);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        message: 'Request failed with status ${response.statusCode}.',
        statusCode: response.statusCode,
      );
    }

    final filename =
        _extractFilename(response.headers['content-disposition']) ??
        fallbackFilename ??
        'document.pdf';
    final safeFilename = filename.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    final file = File(
      '${Directory.systemTemp.path}${Platform.pathSeparator}$safeFilename',
    );
    await file.writeAsBytes(response.bodyBytes, flush: true);
    return DownloadedDocument(filePath: file.path, filename: safeFilename);
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
    this.registrationNumber,
    this.paperId,
    this.userName,
    this.userEmail,
    this.priceLabel,
    this.isCheckedIn = false,
    this.createdAt,
  });

  final int ticketId;
  final int? conferenceId;
  final String conferenceName;
  final String ticketType;
  final String qrCodeValue;
  final String checkInStatus;
  final String? paymentStatus;
  final String? registrationNumber;
  final int? paperId;
  final String? userName;
  final String? userEmail;
  final String? priceLabel;
  final bool isCheckedIn;
  final String? createdAt;
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
    this.type = '',
    this.createdAt = '',
  });

  final int id;
  final String title;
  final String message;
  final String deepLinkHint;
  final bool isRead;
  final String type;
  final String createdAt;
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

class AuthorConferenceSummary {
  const AuthorConferenceSummary({
    required this.conferenceId,
    required this.conferenceName,
    required this.acronym,
    required this.location,
    required this.status,
    required this.startDate,
    required this.endDate,
    required this.myPaperCount,
    required this.acceptedCount,
    this.roles = const <String>[],
  });

  final int conferenceId;
  final String conferenceName;
  final String acronym;
  final String location;
  final String status;
  final String startDate;
  final String endDate;
  final int myPaperCount;
  final int acceptedCount;
  final List<String> roles;
}

class ConferenceProgressStep {
  const ConferenceProgressStep({
    required this.activityType,
    required this.name,
    required this.isEnabled,
    required this.deadline,
  });

  final String activityType;
  final String name;
  final bool isEnabled;
  final String deadline;
}

class AuthorPaperSummary {
  const AuthorPaperSummary({
    required this.paperId,
    required this.title,
    required this.status,
    required this.trackName,
    required this.submissionTime,
    this.averageScore,
    this.finalDecision,
  });

  final int paperId;
  final String title;
  final String status;
  final String trackName;
  final String submissionTime;
  final double? averageScore;
  final String? finalDecision;
}

class AuthorPaperDetail {
  const AuthorPaperDetail({
    required this.paperId,
    this.conferenceId,
    required this.title,
    required this.status,
    required this.abstractText,
    required this.keywords,
    required this.authorNames,
    required this.subjectAreaNames,
    this.primarySubjectAreaId,
    this.secondarySubjectAreaIds = const <int>[],
    this.plagiarismStatus,
    required this.trackName,
    required this.submissionTime,
    required this.files,
    this.averageScore,
    this.finalDecision,
  });

  final int paperId;
  final int? conferenceId;
  final String title;
  final String status;
  final String abstractText;
  final List<String> keywords;
  final List<String> authorNames;
  final List<String> subjectAreaNames;
  final int? primarySubjectAreaId;
  final List<int> secondarySubjectAreaIds;
  final String? plagiarismStatus;
  final String trackName;
  final String submissionTime;
  final double? averageScore;
  final String? finalDecision;
  final List<AuthorPaperFile> files;
}

class AuthorPaperFile {
  const AuthorPaperFile({
    required this.url,
    required this.isCameraReady,
    required this.isCopyrightSubmission,
    required this.isSupplementary,
    required this.isActive,
  });

  final String url;
  final bool isCameraReady;
  final bool isCopyrightSubmission;
  final bool isSupplementary;
  final bool isActive;
}

class AuthorTicketDetail {
  const AuthorTicketDetail({
    required this.ticketId,
    required this.conferenceName,
    required this.ticketType,
    required this.registrationNumber,
    required this.qrCode,
    required this.paymentStatus,
    required this.checkedIn,
    this.paperId,
  });

  final int ticketId;
  final String conferenceName;
  final String ticketType;
  final String registrationNumber;
  final String qrCode;
  final String paymentStatus;
  final bool checkedIn;
  final int? paperId;
}

class DownloadedDocument {
  const DownloadedDocument({required this.filePath, required this.filename});

  final String filePath;
  final String filename;
}

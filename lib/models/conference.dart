class Conference {
  Conference({
    required this.id,
    required this.name,
    required this.acronym,
    required this.description,
    required this.location,
    required this.startDate,
    required this.endDate,
    required this.status,
    required this.area,
    required this.country,
    this.province,
    this.bannerImageUrl,
    this.websiteUrl,
    this.contactInformation,
    this.paperDeadline,
    this.creatorName,
    this.organizerName,
  });

  final int id;
  final String name;
  final String acronym;
  final String description;
  final String location;
  final DateTime startDate;
  final DateTime endDate;
  final String status;
  final String area;
  final String country;
  final String? province;
  final String? bannerImageUrl;
  final String? websiteUrl;
  final String? contactInformation;
  final String? paperDeadline;
  final String? creatorName;
  final String? organizerName;

  factory Conference.fromJson(Map<String, dynamic> json) {
    return Conference(
      id: json['id'] as int,
      name: (json['name'] ?? '') as String,
      acronym: (json['acronym'] ?? '') as String,
      description: (json['description'] ?? '') as String,
      location: (json['location'] ?? '') as String,
      startDate: DateTime.parse(json['startDate'] as String),
      endDate: DateTime.parse(json['endDate'] as String),
      status: (json['status'] ?? 'PENDING') as String,
      area: (json['area'] ?? '') as String,
      country: (json['country'] ?? '') as String,
      province: json['province'] as String?,
      bannerImageUrl: json['bannerImageUrl'] as String?,
      websiteUrl: json['websiteUrl'] as String?,
      contactInformation: json['contactInformation'] as String?,
      paperDeadline: json['paperDeadline'] as String?,
      creatorName: json['creatorName'] as String?,
      organizerName: json['organizerName'] as String?,
    );
  }
}

class ConferencePage {
  ConferencePage({
    required this.content,
    required this.page,
    required this.size,
    required this.totalElements,
    required this.totalPages,
    required this.last,
  });

  final List<Conference> content;
  final int page;
  final int size;
  final int totalElements;
  final int totalPages;
  final bool last;

  factory ConferencePage.fromJson(Map<String, dynamic> json) {
    final contentJson = (json['content'] as List<dynamic>? ?? const []);
    return ConferencePage(
      content: contentJson
          .whereType<Map<String, dynamic>>()
          .map(Conference.fromJson)
          .toList(),
      page: (json['page'] ?? 0) as int,
      size: (json['size'] ?? 20) as int,
      totalElements: (json['totalElements'] ?? 0) as int,
      totalPages: (json['totalPages'] ?? 0) as int,
      last: (json['last'] ?? true) as bool,
    );
  }
}

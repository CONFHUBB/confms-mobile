class UserProfileData {
  const UserProfileData({
    this.id,
    this.userId,
    this.userType,
    this.jobTitle,
    this.department,
    this.institution,
    this.institutionCountry,
    this.institutionUrl,
    this.secondaryInstitution,
    this.secondaryCountry,
    this.phoneOffice,
    this.phoneMobile,
    this.avatarUrl,
    this.biography,
    this.websiteUrl,
    this.dblpId,
    this.googleScholarLink,
    this.orcid,
    this.semanticScholarId,
  });

  final int? id;
  final int? userId;
  final String? userType;
  final String? jobTitle;
  final String? department;
  final String? institution;
  final String? institutionCountry;
  final String? institutionUrl;
  final String? secondaryInstitution;
  final String? secondaryCountry;
  final String? phoneOffice;
  final String? phoneMobile;
  final String? avatarUrl;
  final String? biography;
  final String? websiteUrl;
  final String? dblpId;
  final String? googleScholarLink;
  final String? orcid;
  final String? semanticScholarId;

  factory UserProfileData.fromJson(Map<String, dynamic> json) {
    return UserProfileData(
      id: (json['id'] as num?)?.toInt(),
      userId: (json['userId'] as num?)?.toInt(),
      userType: _readString(json['userType']),
      jobTitle: _readString(json['jobTitle']),
      department: _readString(json['department']),
      institution: _readString(json['institution']),
      institutionCountry: _readString(json['institutionCountry']),
      institutionUrl: _readString(json['institutionUrl']),
      secondaryInstitution: _readString(json['secondaryInstitution']),
      secondaryCountry: _readString(json['secondaryCountry']),
      phoneOffice: _readString(json['phoneOffice']),
      phoneMobile: _readString(json['phoneMobile']),
      avatarUrl: _readString(json['avatarUrl']),
      biography: _readString(json['biography']),
      websiteUrl: _readString(json['websiteUrl']),
      dblpId: _readString(json['dblpId']),
      googleScholarLink: _readString(json['googleScholarLink']),
      orcid: _readString(json['orcid']),
      semanticScholarId: _readString(json['semanticScholarId']),
    );
  }

  Map<String, dynamic> toRequestJson() => <String, dynamic>{
    'userType': _nullIfEmpty(userType),
    'jobTitle': _nullIfEmpty(jobTitle),
    'department': _nullIfEmpty(department),
    'institution': _nullIfEmpty(institution),
    'institutionCountry': _nullIfEmpty(institutionCountry),
    'institutionUrl': _nullIfEmpty(institutionUrl),
    'secondaryInstitution': _nullIfEmpty(secondaryInstitution),
    'secondaryCountry': _nullIfEmpty(secondaryCountry),
    'phoneOffice': _nullIfEmpty(phoneOffice),
    'phoneMobile': _nullIfEmpty(phoneMobile),
    'avatarUrl': _nullIfEmpty(avatarUrl),
    'biography': _nullIfEmpty(biography),
    'websiteUrl': _nullIfEmpty(websiteUrl),
    'dblpId': _nullIfEmpty(dblpId),
    'googleScholarLink': _nullIfEmpty(googleScholarLink),
    'orcid': _nullIfEmpty(orcid),
    'semanticScholarId': _nullIfEmpty(semanticScholarId),
  };

  static String? _readString(dynamic value) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? null : text;
  }

  static String? _nullIfEmpty(String? value) {
    final text = value?.trim() ?? '';
    return text.isEmpty ? null : text;
  }
}

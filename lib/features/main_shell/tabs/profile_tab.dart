import 'dart:convert';

import 'package:confms_mobile/constants/app_theme.dart';
import 'package:confms_mobile/constants/dimensions.dart';
import 'package:confms_mobile/constants/text_styles.dart';
import 'package:confms_mobile/features/main_shell/widgets/main_tab_scaffold.dart';
import 'package:confms_mobile/features/main_shell/widgets/shell_shared_widgets.dart';
import 'package:confms_mobile/models/auth_user.dart';
import 'package:confms_mobile/models/user_profile.dart';
import 'package:confms_mobile/services/auth_session.dart';
import 'package:confms_mobile/services/mobile_feature_service.dart';
import 'package:confms_mobile/widgets/custom_button.dart';
import 'package:confms_mobile/widgets/custom_card.dart';
import 'package:flutter/material.dart';

enum _ProfileSection { personal, affiliation, contact, academic }

class ProfileTab extends StatefulWidget {
  const ProfileTab({
    super.key,
    required this.authSession,
    required this.featureService,
    required this.onLogout,
    required this.onOpenNotifications,
  });

  final AuthSession authSession;
  final MobileFeatureService featureService;
  final Future<void> Function() onLogout;
  final VoidCallback onOpenNotifications;

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  static const List<String> _userTypes = <String>[
    'ACADEMIA',
    'INDUSTRY',
    'GOVERNMENT',
    'STUDENT',
    'OTHER',
  ];

  _ProfileSection _activeSection = _ProfileSection.personal;
  bool _isLoading = true;
  bool _isSaving = false;
  String? _selectedUserType;

  final TextEditingController _jobTitleController = TextEditingController();
  final TextEditingController _avatarUrlController = TextEditingController();
  final TextEditingController _biographyController = TextEditingController();
  final TextEditingController _departmentController = TextEditingController();
  final TextEditingController _institutionController = TextEditingController();
  final TextEditingController _institutionCountryController =
      TextEditingController();
  final TextEditingController _institutionUrlController =
      TextEditingController();
  final TextEditingController _secondaryInstitutionController =
      TextEditingController();
  final TextEditingController _secondaryCountryController =
      TextEditingController();
  final TextEditingController _phoneOfficeController = TextEditingController();
  final TextEditingController _phoneMobileController = TextEditingController();
  final TextEditingController _websiteController = TextEditingController();
  final TextEditingController _dblpController = TextEditingController();
  final TextEditingController _googleScholarController =
      TextEditingController();
  final TextEditingController _orcidController = TextEditingController();
  final TextEditingController _semanticScholarController =
      TextEditingController();

  @override
  void initState() {
    super.initState();
    _prefillFromSession();
    _loadProfile();
  }

  @override
  void dispose() {
    _jobTitleController.dispose();
    _avatarUrlController.dispose();
    _biographyController.dispose();
    _departmentController.dispose();
    _institutionController.dispose();
    _institutionCountryController.dispose();
    _institutionUrlController.dispose();
    _secondaryInstitutionController.dispose();
    _secondaryCountryController.dispose();
    _phoneOfficeController.dispose();
    _phoneMobileController.dispose();
    _websiteController.dispose();
    _dblpController.dispose();
    _googleScholarController.dispose();
    _orcidController.dispose();
    _semanticScholarController.dispose();
    super.dispose();
  }

  void _prefillFromSession() {
    final claims = _decodeTokenClaims(widget.authSession.token);
    final claimUserType = claims['userType']?.toString().toUpperCase();
    if (_userTypes.contains(claimUserType)) {
      _selectedUserType = claimUserType;
    }
  }

  Future<void> _loadProfile() async {
    final userId = widget.authSession.user?.id;
    if (userId == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      final profile = await widget.featureService.getUserProfile(
        userId: userId,
      );
      if (!mounted) return;
      if (profile != null) {
        _applyProfile(profile);
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Unable to load profile: $error')));
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _applyProfile(UserProfileData profile) {
    _selectedUserType = profile.userType?.toUpperCase();
    _jobTitleController.text = profile.jobTitle ?? '';
    _avatarUrlController.text = profile.avatarUrl ?? '';
    _biographyController.text = profile.biography ?? '';
    _departmentController.text = profile.department ?? '';
    _institutionController.text = profile.institution ?? '';
    _institutionCountryController.text = profile.institutionCountry ?? '';
    _institutionUrlController.text = profile.institutionUrl ?? '';
    _secondaryInstitutionController.text = profile.secondaryInstitution ?? '';
    _secondaryCountryController.text = profile.secondaryCountry ?? '';
    _phoneOfficeController.text = profile.phoneOffice ?? '';
    _phoneMobileController.text = profile.phoneMobile ?? '';
    _websiteController.text = profile.websiteUrl ?? '';
    _dblpController.text = profile.dblpId ?? '';
    _googleScholarController.text = profile.googleScholarLink ?? '';
    _orcidController.text = profile.orcid ?? '';
    _semanticScholarController.text = profile.semanticScholarId ?? '';
  }

  Future<void> _saveProfile() async {
    final userId = widget.authSession.user?.id;
    if (userId == null) return;

    setState(() => _isSaving = true);
    try {
      final payload = UserProfileData(
        userType: _selectedUserType,
        jobTitle: _jobTitleController.text,
        department: _departmentController.text,
        institution: _institutionController.text,
        institutionCountry: _institutionCountryController.text,
        institutionUrl: _institutionUrlController.text,
        secondaryInstitution: _secondaryInstitutionController.text,
        secondaryCountry: _secondaryCountryController.text,
        phoneOffice: _phoneOfficeController.text,
        phoneMobile: _phoneMobileController.text,
        avatarUrl: _avatarUrlController.text,
        biography: _biographyController.text,
        websiteUrl: _websiteController.text,
        dblpId: _dblpController.text,
        googleScholarLink: _googleScholarController.text,
        orcid: _orcidController.text,
        semanticScholarId: _semanticScholarController.text,
      );

      final saved = await widget.featureService.upsertUserProfile(
        userId: userId,
        profile: payload,
      );
      if (!mounted) return;
      _applyProfile(saved);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated successfully.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to save profile: $error')));
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;

    final user = widget.authSession.user;
    final claims = _decodeTokenClaims(widget.authSession.token);
    final userId = user?.id;

    final fullName =
        '${user?.firstName ?? claims['firstName'] ?? ''} ${user?.lastName ?? claims['lastName'] ?? ''}'
            .trim();
    final email = user?.email ?? claims['email']?.toString() ?? '-';

    return MainTabScaffold(
      title: 'Profile',
      subtitle: 'Personal, affiliation, contact and academic info.',
      icon: Icons.person_rounded,
      onOpenNotifications: widget.onOpenNotifications,
      body: ListView(
        padding: const EdgeInsets.all(AppDimensions.screenPadding),
        children: [
          CustomCard(
            child: Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: scheme.primaryContainer,
                  child: Text(
                    _initials(user),
                    style: AppTextStyles.title.copyWith(color: scheme.primary),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        fullName.isEmpty ? 'User' : fullName,
                        style: AppTextStyles.title,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        email,
                        style: AppTextStyles.bodyMuted.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        children: (user?.roles ?? _rolesFromClaims(claims))
                            .map(
                              (role) => MiniChip(
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
          CustomCard(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _ProfileChip(
                    icon: Icons.person_rounded,
                    label: 'Personal',
                    selected: _activeSection == _ProfileSection.personal,
                    onTap: () => setState(
                      () => _activeSection = _ProfileSection.personal,
                    ),
                  ),
                  const SizedBox(width: AppDimensions.space2),
                  _ProfileChip(
                    icon: Icons.apartment_rounded,
                    label: 'Affiliation',
                    selected: _activeSection == _ProfileSection.affiliation,
                    onTap: () => setState(
                      () => _activeSection = _ProfileSection.affiliation,
                    ),
                  ),
                  const SizedBox(width: AppDimensions.space2),
                  _ProfileChip(
                    icon: Icons.contact_phone_rounded,
                    label: 'Contact',
                    selected: _activeSection == _ProfileSection.contact,
                    onTap: () => setState(
                      () => _activeSection = _ProfileSection.contact,
                    ),
                  ),
                  const SizedBox(width: AppDimensions.space2),
                  _ProfileChip(
                    icon: Icons.school_rounded,
                    label: 'Academic',
                    selected: _activeSection == _ProfileSection.academic,
                    onTap: () => setState(
                      () => _activeSection = _ProfileSection.academic,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppDimensions.space3),
          if (_isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(AppDimensions.space6),
                child: CircularProgressIndicator(),
              ),
            )
          else
            _buildSectionContent(),
          const SizedBox(height: AppDimensions.space4),
          CustomButton(
            label: 'Save Profile',
            expanded: true,
            icon: _isSaving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_outlined, size: 18),
            onPressed: _isSaving || userId == null ? null : _saveProfile,
          ),
          const SizedBox(height: AppDimensions.space3),
          CustomButton(
            label: 'Logout',
            expanded: true,
            variant: CustomButtonVariant.outline,
            icon: const Icon(Icons.logout, size: 18),
            onPressed: widget.onLogout,
          ),
        ],
      ),
    );
  }

  Widget _buildSectionContent() {
    switch (_activeSection) {
      case _ProfileSection.personal:
        return SectionCard(
          title: 'Personal Information',
          children: [
            DropdownButtonFormField<String>(
              value: _selectedUserType,
              decoration: const InputDecoration(labelText: 'User Type'),
              items: _userTypes
                  .map(
                    (item) => DropdownMenuItem(value: item, child: Text(item)),
                  )
                  .toList(),
              onChanged: (value) => setState(() => _selectedUserType = value),
            ),
            const SizedBox(height: AppDimensions.space3),
            _field(
              'Job Title',
              _jobTitleController,
              hint: 'e.g. Associate Professor',
            ),
            const SizedBox(height: AppDimensions.space3),
            _field(
              'Avatar URL',
              _avatarUrlController,
              hint: 'https://example.com/avatar.jpg',
            ),
            const SizedBox(height: AppDimensions.space3),
            _field(
              'Biography',
              _biographyController,
              hint: 'Short bio, research interests, and expertise',
              minLines: 4,
              maxLines: 6,
            ),
          ],
        );
      case _ProfileSection.affiliation:
        return SectionCard(
          title: 'Affiliation',
          children: [
            _field(
              'Institution',
              _institutionController,
              hint: 'e.g. FPT University',
            ),
            const SizedBox(height: AppDimensions.space3),
            _field(
              'Department',
              _departmentController,
              hint: 'e.g. Computer Science',
            ),
            const SizedBox(height: AppDimensions.space3),
            _field(
              'Institution Country',
              _institutionCountryController,
              hint: 'e.g. Vietnam',
            ),
            const SizedBox(height: AppDimensions.space3),
            _field(
              'Institution Website',
              _institutionUrlController,
              hint: 'https://university.edu',
            ),
            const SizedBox(height: AppDimensions.space3),
            _field(
              'Secondary Institution',
              _secondaryInstitutionController,
              hint: 'Optional',
            ),
            const SizedBox(height: AppDimensions.space3),
            _field(
              'Secondary Country',
              _secondaryCountryController,
              hint: 'Optional',
            ),
          ],
        );
      case _ProfileSection.contact:
        return SectionCard(
          title: 'Contact Details',
          children: [
            _field(
              'Office Phone',
              _phoneOfficeController,
              hint: '+84 28 1234 5678',
            ),
            const SizedBox(height: AppDimensions.space3),
            _field(
              'Mobile Phone',
              _phoneMobileController,
              hint: '+84 912 345 678',
            ),
            const SizedBox(height: AppDimensions.space3),
            _field(
              'Personal Website',
              _websiteController,
              hint: 'https://yourwebsite.com',
            ),
          ],
        );
      case _ProfileSection.academic:
        return SectionCard(
          title: 'Academic Profiles',
          children: [
            _field('ORCID iD', _orcidController, hint: '0000-0002-1825-0097'),
            const SizedBox(height: AppDimensions.space3),
            _field(
              'Google Scholar',
              _googleScholarController,
              hint: 'https://scholar.google.com/citations?user=XXXX',
            ),
            const SizedBox(height: AppDimensions.space3),
            _field('DBLP', _dblpController, hint: 'Your DBLP author ID'),
            const SizedBox(height: AppDimensions.space3),
            _field(
              'Semantic Scholar',
              _semanticScholarController,
              hint: 'Your Semantic Scholar author ID',
            ),
          ],
        );
    }
  }

  Widget _field(
    String label,
    TextEditingController controller, {
    String? hint,
    int minLines = 1,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      minLines: minLines,
      maxLines: maxLines,
      decoration: InputDecoration(labelText: label, hintText: hint),
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

class _ProfileChip extends StatelessWidget {
  const _ProfileChip({
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
        showCheckmark: false,
        onSelected: (_) => onTap(),
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

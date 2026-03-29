import 'package:flutter/material.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'user_model.freezed.dart';
part 'user_model.g.dart';

enum UserRole {
  jobSeeker,
  employer,
  peer; // 新增 peer，讓 users.role 可以存同業身份

  static UserRole fromString(String value) {
    return switch (value) {
      'job_seeker' => UserRole.jobSeeker,
      'employer' => UserRole.employer,
      'peer' => UserRole.peer,
      _ => UserRole.jobSeeker,
    };
  }

  String get toDbString => switch (this) {
        UserRole.jobSeeker => 'job_seeker',
        UserRole.employer => 'employer',
        UserRole.peer => 'peer',
      };
}

/// 目前的操作身份（和 UserRole 對應）
enum AppRole {
  jobSeeker,
  employer,
  peer;

  String get label => switch (this) {
        AppRole.jobSeeker => '求職者',
        AppRole.employer => '雇主',
        AppRole.peer => '同業交流',
      };

  String get toDbString => switch (this) {
        AppRole.jobSeeker => 'job_seeker',
        AppRole.employer => 'employer',
        AppRole.peer => 'peer',
      };

  static AppRole fromString(String value) => switch (value) {
        'job_seeker' => AppRole.jobSeeker,
        'employer' => AppRole.employer,
        'peer' => AppRole.peer,
        _ => AppRole.jobSeeker,
      };

  Color get themeColor => switch (this) {
        AppRole.jobSeeker => const Color(0xFF00BFFF),
        AppRole.employer => const Color(0xFFBF00FF),
        AppRole.peer => const Color(0xFF00FF9F),
      };

  IconData get icon => switch (this) {
        AppRole.jobSeeker => Icons.person_search,
        AppRole.employer => Icons.business_center,
        AppRole.peer => Icons.people,
      };
}

@freezed
class UserModel with _$UserModel {
  const UserModel._();

  const factory UserModel({
    required String id,
    required String email,
    required UserRole role, // ← 這就是當前身份，直接更新它
    required String displayName,
    String? avatarUrl,
    String? bio,
    String? location,
    @Default([]) List<String> skills,
    int? experienceYears,
    int? expectedSalary,
    String? companyName,
    String? companySize,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) = _UserModel;

  bool get isProfileComplete {
    final hasAvatar = avatarUrl != null && avatarUrl!.isNotEmpty;
    final hasRealName = displayName != '未命名' && displayName.isNotEmpty;
    return hasAvatar && hasRealName;
  }

  /// 當前身份直接從 users.role 讀
  /// switchRole 更新 users.role → profileProvider stream 推新值
  /// → currentRoleProvider build() 重新執行 → UI 自動更新
  AppRole get effectiveRole => AppRole.fromString(role.toDbString);

  factory UserModel.fromJson(Map<String, dynamic> json) =>
      _$UserModelFromJson(json);

  factory UserModel.fromSupabase(Map<String, dynamic> row) {
    return UserModel(
      id: row['id'] as String,
      email: row['email'] as String? ?? '',
      role: UserRole.fromString(row['role'] as String? ?? ''),
      displayName: row['display_name'] as String? ?? '未命名',
      avatarUrl: row['avatar_url'] as String?,
      bio: row['bio'] as String?,
      location: row['location'] as String?,
      skills: (row['skills'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      experienceYears: row['experience_years'] as int?,
      expectedSalary: row['expected_salary'] as int?,
      companyName: row['company_name'] as String?,
      companySize: row['company_size'] as String?,
      createdAt: row['created_at'] != null
          ? DateTime.parse(row['created_at'] as String)
          : DateTime.now(),
      updatedAt: row['updated_at'] != null
          ? DateTime.parse(row['updated_at'] as String)
          : DateTime.now(),
    );
  }
}
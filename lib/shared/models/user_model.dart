import 'package:flutter/material.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'user_model.freezed.dart';
part 'user_model.g.dart';

enum UserRole {
  jobSeeker,
  employer;

  static UserRole fromString(String value) {
    return switch (value) {
      'job_seeker' => UserRole.jobSeeker,
      'employer' => UserRole.employer,
      _ => UserRole.jobSeeker,
    };
  }

  String get toDbString => switch (this) {
        UserRole.jobSeeker => 'job_seeker',
        UserRole.employer => 'employer',
      };
}

/// 目前的操作身份（可以和帳號 role 不同）
/// jobSeeker: 求職者模式，看職缺卡片
/// employer:  雇主模式，看求職者卡片
/// peer:      同業交流模式，看同技能的人
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

  /// Cyberpunk 主題色
  Color get themeColor => switch (this) {
        AppRole.jobSeeker => const Color(0xFF00BFFF), // 電藍
        AppRole.employer => const Color(0xFFBF00FF),  // 電紫
        AppRole.peer => const Color(0xFF00FF9F),      // 電綠
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
    required UserRole role,
    required String displayName,
    String? avatarUrl,
    String? bio,
    String? location,
    @Default([]) List<String> skills,
    int? experienceYears,
    int? expectedSalary,
    String? companyName,
    String? companySize,
    // 目前操作身份（儲存在 DB，預設與 role 相同）
    AppRole? currentRole,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) = _UserModel;

  bool get isProfileComplete {
    final hasAvatar = avatarUrl != null && avatarUrl!.isNotEmpty;
    final hasRealName = displayName != '未命名' && displayName.isNotEmpty;
    return hasAvatar && hasRealName;
  }

  /// 取得目前有效的操作身份
  AppRole get effectiveRole =>
      currentRole ?? AppRole.fromString(role.toDbString);

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
      currentRole: row['current_role'] != null
          ? AppRole.fromString(row['current_role'] as String)
          : null,
      createdAt: row['created_at'] != null
          ? DateTime.parse(row['created_at'] as String)
          : DateTime.now(),
      updatedAt: row['updated_at'] != null
          ? DateTime.parse(row['updated_at'] as String)
          : DateTime.now(),
    );
  }
}
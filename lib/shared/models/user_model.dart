import 'package:flutter/material.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'user_model.freezed.dart';
part 'user_model.g.dart';

enum UserRole {
  jobSeeker,
  employer,
  peer; // 讓 users.role 可以存同業身份

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

  // --- 補回你原本的 UI 設定 ---
  Color get themeColor => switch (this) {
        AppRole.jobSeeker => const Color(0xFF00BFFF),
        AppRole.employer => const Color.fromARGB(255, 20, 102, 156),
        AppRole.peer => const Color.fromARGB(255, 12, 187, 120),
      };

  IconData get icon => switch (this) {
        AppRole.jobSeeker => Icons.person_search,
        AppRole.employer => Icons.business_center,
        AppRole.peer => Icons.people,
      };
}

@freezed
class UserModel with _$UserModel {
  const UserModel._(); // 為了定義自定義方法

  const factory UserModel({
    required String id,
    required String email,
    required UserRole role, // 當前身份
    required String displayName,
    String? avatarUrl,
    String? bio,
    String? location,
    @Default([]) List<String> skills,
    int? experienceYears,
    int? expectedSalary,
    String? companyName,
    String? companySize,
    @Default('matched') String salaryVisibility,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) = _UserModel;

  /// 【關鍵】根據當前身份檢查資料是否完整
  /// 初始用戶是雇主時，切換身份會觸發此判斷並導向 Onboarding
  bool isCompleteFor(AppRole currentRole) {
    // 1. 通用基礎檢查：名字與頭像
    final hasBasic = displayName != '未命名' && displayName.trim().isNotEmpty;
    final hasAvatar = avatarUrl != null && avatarUrl!.isNotEmpty;
    if (!hasBasic || !hasAvatar) return false;

    // 2. 角色專屬必填項檢查
    return switch (currentRole) {
      AppRole.jobSeeker => skills.isNotEmpty, // 求職者必須有技能
      AppRole.employer => companyName != null && companyName!.isNotEmpty, // 雇主必須有公司名
      AppRole.peer => skills.isNotEmpty, // 同業交流需要技能
    };
  }

  /// 保留舊有簡單判斷（供舊邏輯參考）
  bool get isProfileComplete {
    final hasAvatar = avatarUrl != null && avatarUrl!.isNotEmpty;
    final hasRealName = displayName != '未命名' && displayName.isNotEmpty;
    return hasAvatar && hasRealName;
  }

  /// 當前身份轉為 AppRole
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
      salaryVisibility: row['salary_visibility'] as String? ?? 'matched',
      createdAt: row['created_at'] != null
          ? DateTime.parse(row['created_at'] as String)
          : DateTime.now(),
      updatedAt: row['updated_at'] != null
          ? DateTime.parse(row['updated_at'] as String)
          : DateTime.now(),
    );
  }
}
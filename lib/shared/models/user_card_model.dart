// lib/shared/models/user_card_model.dart
import 'package:freezed_annotation/freezed_annotation.dart';

part 'user_card_model.freezed.dart';
part 'user_card_model.g.dart';

/// 雇主和同業配對用的卡片 Model
/// 對應 user_cards view
@freezed
class UserCardModel with _$UserCardModel {
  const factory UserCardModel({
    required String id,          // user_profiles.id
    required String userId,      // users.id
    required String role,        // 'job_seeker' | 'employer' | 'peer'
    required String displayName,
    String? avatarUrl,
    String? bio,
    @Default([]) List<String> skills,
    int? expectedSalary,
    String? companyName,
    String? companySize,
    @Default(true) bool isOpenToOpportunity,
    @Default(true) bool isOpenToExchange,
  }) = _UserCardModel;

  factory UserCardModel.fromJson(Map<String, dynamic> json) =>
      _$UserCardModelFromJson(json);

  factory UserCardModel.fromSupabase(Map<String, dynamic> row) {
    return UserCardModel(
      id: row['id'] as String,
      userId: row['user_id'] as String,
      role: row['role'] as String? ?? 'job_seeker',
      displayName: row['display_name'] as String? ?? '未命名',
      avatarUrl: row['avatar_url'] as String?,
      bio: row['bio'] as String?,
      skills: (row['skills'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      expectedSalary: row['expected_salary'] as int?,
      companyName: row['company_name'] as String?,
      companySize: row['company_size'] as String?,
      isOpenToOpportunity: row['is_open_to_opportunity'] as bool? ?? true,
      isOpenToExchange: row['is_open_to_exchange'] as bool? ?? true,
    );
  }
}
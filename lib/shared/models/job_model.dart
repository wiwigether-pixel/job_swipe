import 'package:freezed_annotation/freezed_annotation.dart';

part 'job_model.freezed.dart';
part 'job_model.g.dart';

enum JobType {
  fullTime,
  partTime,
  contract,
  remote;

  static JobType fromString(String value) => switch (value) {
    'full_time'  => JobType.fullTime,
    'part_time'  => JobType.partTime,
    'contract'   => JobType.contract,
    'remote'     => JobType.remote,
    _            => JobType.fullTime,
  };

  String get label => switch (this) {
    JobType.fullTime  => '全職',
    JobType.partTime  => '兼職',
    JobType.contract  => '約聘',
    JobType.remote    => '遠端',
  };
}

@freezed
class JobModel with _$JobModel {
  const factory JobModel({
    required String id,
    required String employerId,
    required String title,
    required String description,
    @Default([]) List<String> requiredSkills,
    int? salaryMin,
    int? salaryMax,
    String? location,
    JobType? jobType,
    @Default('open') String status,

    // 關聯的雇主資訊（JOIN 查詢時帶入，方便卡片顯示）
    String? companyName,
    String? companyAvatarUrl,

    required DateTime createdAt,
  }) = _JobModel;

  factory JobModel.fromJson(Map<String, dynamic> json) =>
      _$JobModelFromJson(json);

  factory JobModel.fromSupabase(Map<String, dynamic> row) {
    // Supabase JOIN 查詢時，關聯表資料會嵌套在對應 key 裡
    final employer = row['users'] as Map<String, dynamic>?;

    return JobModel(
      id: row['id'] as String,
      employerId: row['employer_id'] as String,
      title: row['title'] as String? ?? '未命名職缺',
      description: row['description'] as String? ?? '',
      requiredSkills: (row['required_skills'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      salaryMin: row['salary_min'] as int?,
      salaryMax: row['salary_max'] as int?,
      location: row['location'] as String?,
      jobType: row['job_type'] != null
          ? JobType.fromString(row['job_type'] as String)
          : null,
      status: row['status'] as String? ?? 'open',
      companyName: employer?['company_name'] as String?,
      companyAvatarUrl: employer?['avatar_url'] as String?,
      createdAt: DateTime.parse(row['created_at'] as String),
    );
  }
}
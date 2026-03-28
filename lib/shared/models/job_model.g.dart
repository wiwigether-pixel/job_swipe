// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'job_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$JobModelImpl _$$JobModelImplFromJson(Map<String, dynamic> json) =>
    _$JobModelImpl(
      id: json['id'] as String,
      employerId: json['employerId'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      requiredSkills: (json['requiredSkills'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      salaryMin: (json['salaryMin'] as num?)?.toInt(),
      salaryMax: (json['salaryMax'] as num?)?.toInt(),
      location: json['location'] as String?,
      jobType: $enumDecodeNullable(_$JobTypeEnumMap, json['jobType']),
      status: json['status'] as String? ?? 'open',
      companyName: json['companyName'] as String?,
      companyAvatarUrl: json['companyAvatarUrl'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );

Map<String, dynamic> _$$JobModelImplToJson(_$JobModelImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'employerId': instance.employerId,
      'title': instance.title,
      'description': instance.description,
      'requiredSkills': instance.requiredSkills,
      'salaryMin': instance.salaryMin,
      'salaryMax': instance.salaryMax,
      'location': instance.location,
      'jobType': _$JobTypeEnumMap[instance.jobType],
      'status': instance.status,
      'companyName': instance.companyName,
      'companyAvatarUrl': instance.companyAvatarUrl,
      'createdAt': instance.createdAt.toIso8601String(),
    };

const _$JobTypeEnumMap = {
  JobType.fullTime: 'fullTime',
  JobType.partTime: 'partTime',
  JobType.contract: 'contract',
  JobType.remote: 'remote',
};

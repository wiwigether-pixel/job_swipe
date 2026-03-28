// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$UserModelImpl _$$UserModelImplFromJson(Map<String, dynamic> json) =>
    _$UserModelImpl(
      id: json['id'] as String,
      email: json['email'] as String,
      role: $enumDecode(_$UserRoleEnumMap, json['role']),
      displayName: json['displayName'] as String,
      avatarUrl: json['avatarUrl'] as String?,
      bio: json['bio'] as String?,
      location: json['location'] as String?,
      skills: (json['skills'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      experienceYears: (json['experienceYears'] as num?)?.toInt(),
      expectedSalary: (json['expectedSalary'] as num?)?.toInt(),
      companyName: json['companyName'] as String?,
      companySize: json['companySize'] as String?,
      currentRole: $enumDecodeNullable(_$AppRoleEnumMap, json['currentRole']),
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );

Map<String, dynamic> _$$UserModelImplToJson(_$UserModelImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'email': instance.email,
      'role': _$UserRoleEnumMap[instance.role]!,
      'displayName': instance.displayName,
      'avatarUrl': instance.avatarUrl,
      'bio': instance.bio,
      'location': instance.location,
      'skills': instance.skills,
      'experienceYears': instance.experienceYears,
      'expectedSalary': instance.expectedSalary,
      'companyName': instance.companyName,
      'companySize': instance.companySize,
      'currentRole': _$AppRoleEnumMap[instance.currentRole],
      'createdAt': instance.createdAt.toIso8601String(),
      'updatedAt': instance.updatedAt.toIso8601String(),
    };

const _$UserRoleEnumMap = {
  UserRole.jobSeeker: 'jobSeeker',
  UserRole.employer: 'employer',
};

const _$AppRoleEnumMap = {
  AppRole.jobSeeker: 'jobSeeker',
  AppRole.employer: 'employer',
  AppRole.peer: 'peer',
};

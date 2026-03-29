// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_card_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$UserCardModelImpl _$$UserCardModelImplFromJson(Map<String, dynamic> json) =>
    _$UserCardModelImpl(
      id: json['id'] as String,
      userId: json['userId'] as String,
      role: json['role'] as String,
      displayName: json['displayName'] as String,
      avatarUrl: json['avatarUrl'] as String?,
      bio: json['bio'] as String?,
      skills: (json['skills'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      expectedSalary: (json['expectedSalary'] as num?)?.toInt(),
      companyName: json['companyName'] as String?,
      companySize: json['companySize'] as String?,
      isOpenToOpportunity: json['isOpenToOpportunity'] as bool? ?? true,
      isOpenToExchange: json['isOpenToExchange'] as bool? ?? true,
    );

Map<String, dynamic> _$$UserCardModelImplToJson(_$UserCardModelImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'userId': instance.userId,
      'role': instance.role,
      'displayName': instance.displayName,
      'avatarUrl': instance.avatarUrl,
      'bio': instance.bio,
      'skills': instance.skills,
      'expectedSalary': instance.expectedSalary,
      'companyName': instance.companyName,
      'companySize': instance.companySize,
      'isOpenToOpportunity': instance.isOpenToOpportunity,
      'isOpenToExchange': instance.isOpenToExchange,
    };

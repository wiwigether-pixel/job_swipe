// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'user_card_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

UserCardModel _$UserCardModelFromJson(Map<String, dynamic> json) {
  return _UserCardModel.fromJson(json);
}

/// @nodoc
mixin _$UserCardModel {
  String get id => throw _privateConstructorUsedError; // user_profiles.id
  String get userId => throw _privateConstructorUsedError; // users.id
  String get role =>
      throw _privateConstructorUsedError; // 'job_seeker' | 'employer' | 'peer'
  String get displayName => throw _privateConstructorUsedError;
  String? get avatarUrl => throw _privateConstructorUsedError;
  String? get bio => throw _privateConstructorUsedError;
  List<String> get skills => throw _privateConstructorUsedError;
  int? get expectedSalary => throw _privateConstructorUsedError;
  String? get companyName => throw _privateConstructorUsedError;
  String? get companySize => throw _privateConstructorUsedError;
  bool get isOpenToOpportunity => throw _privateConstructorUsedError;
  bool get isOpenToExchange => throw _privateConstructorUsedError;

  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
  @JsonKey(ignore: true)
  $UserCardModelCopyWith<UserCardModel> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $UserCardModelCopyWith<$Res> {
  factory $UserCardModelCopyWith(
          UserCardModel value, $Res Function(UserCardModel) then) =
      _$UserCardModelCopyWithImpl<$Res, UserCardModel>;
  @useResult
  $Res call(
      {String id,
      String userId,
      String role,
      String displayName,
      String? avatarUrl,
      String? bio,
      List<String> skills,
      int? expectedSalary,
      String? companyName,
      String? companySize,
      bool isOpenToOpportunity,
      bool isOpenToExchange});
}

/// @nodoc
class _$UserCardModelCopyWithImpl<$Res, $Val extends UserCardModel>
    implements $UserCardModelCopyWith<$Res> {
  _$UserCardModelCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? userId = null,
    Object? role = null,
    Object? displayName = null,
    Object? avatarUrl = freezed,
    Object? bio = freezed,
    Object? skills = null,
    Object? expectedSalary = freezed,
    Object? companyName = freezed,
    Object? companySize = freezed,
    Object? isOpenToOpportunity = null,
    Object? isOpenToExchange = null,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      userId: null == userId
          ? _value.userId
          : userId // ignore: cast_nullable_to_non_nullable
              as String,
      role: null == role
          ? _value.role
          : role // ignore: cast_nullable_to_non_nullable
              as String,
      displayName: null == displayName
          ? _value.displayName
          : displayName // ignore: cast_nullable_to_non_nullable
              as String,
      avatarUrl: freezed == avatarUrl
          ? _value.avatarUrl
          : avatarUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      bio: freezed == bio
          ? _value.bio
          : bio // ignore: cast_nullable_to_non_nullable
              as String?,
      skills: null == skills
          ? _value.skills
          : skills // ignore: cast_nullable_to_non_nullable
              as List<String>,
      expectedSalary: freezed == expectedSalary
          ? _value.expectedSalary
          : expectedSalary // ignore: cast_nullable_to_non_nullable
              as int?,
      companyName: freezed == companyName
          ? _value.companyName
          : companyName // ignore: cast_nullable_to_non_nullable
              as String?,
      companySize: freezed == companySize
          ? _value.companySize
          : companySize // ignore: cast_nullable_to_non_nullable
              as String?,
      isOpenToOpportunity: null == isOpenToOpportunity
          ? _value.isOpenToOpportunity
          : isOpenToOpportunity // ignore: cast_nullable_to_non_nullable
              as bool,
      isOpenToExchange: null == isOpenToExchange
          ? _value.isOpenToExchange
          : isOpenToExchange // ignore: cast_nullable_to_non_nullable
              as bool,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$UserCardModelImplCopyWith<$Res>
    implements $UserCardModelCopyWith<$Res> {
  factory _$$UserCardModelImplCopyWith(
          _$UserCardModelImpl value, $Res Function(_$UserCardModelImpl) then) =
      __$$UserCardModelImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      String userId,
      String role,
      String displayName,
      String? avatarUrl,
      String? bio,
      List<String> skills,
      int? expectedSalary,
      String? companyName,
      String? companySize,
      bool isOpenToOpportunity,
      bool isOpenToExchange});
}

/// @nodoc
class __$$UserCardModelImplCopyWithImpl<$Res>
    extends _$UserCardModelCopyWithImpl<$Res, _$UserCardModelImpl>
    implements _$$UserCardModelImplCopyWith<$Res> {
  __$$UserCardModelImplCopyWithImpl(
      _$UserCardModelImpl _value, $Res Function(_$UserCardModelImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? userId = null,
    Object? role = null,
    Object? displayName = null,
    Object? avatarUrl = freezed,
    Object? bio = freezed,
    Object? skills = null,
    Object? expectedSalary = freezed,
    Object? companyName = freezed,
    Object? companySize = freezed,
    Object? isOpenToOpportunity = null,
    Object? isOpenToExchange = null,
  }) {
    return _then(_$UserCardModelImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      userId: null == userId
          ? _value.userId
          : userId // ignore: cast_nullable_to_non_nullable
              as String,
      role: null == role
          ? _value.role
          : role // ignore: cast_nullable_to_non_nullable
              as String,
      displayName: null == displayName
          ? _value.displayName
          : displayName // ignore: cast_nullable_to_non_nullable
              as String,
      avatarUrl: freezed == avatarUrl
          ? _value.avatarUrl
          : avatarUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      bio: freezed == bio
          ? _value.bio
          : bio // ignore: cast_nullable_to_non_nullable
              as String?,
      skills: null == skills
          ? _value._skills
          : skills // ignore: cast_nullable_to_non_nullable
              as List<String>,
      expectedSalary: freezed == expectedSalary
          ? _value.expectedSalary
          : expectedSalary // ignore: cast_nullable_to_non_nullable
              as int?,
      companyName: freezed == companyName
          ? _value.companyName
          : companyName // ignore: cast_nullable_to_non_nullable
              as String?,
      companySize: freezed == companySize
          ? _value.companySize
          : companySize // ignore: cast_nullable_to_non_nullable
              as String?,
      isOpenToOpportunity: null == isOpenToOpportunity
          ? _value.isOpenToOpportunity
          : isOpenToOpportunity // ignore: cast_nullable_to_non_nullable
              as bool,
      isOpenToExchange: null == isOpenToExchange
          ? _value.isOpenToExchange
          : isOpenToExchange // ignore: cast_nullable_to_non_nullable
              as bool,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$UserCardModelImpl implements _UserCardModel {
  const _$UserCardModelImpl(
      {required this.id,
      required this.userId,
      required this.role,
      required this.displayName,
      this.avatarUrl,
      this.bio,
      final List<String> skills = const [],
      this.expectedSalary,
      this.companyName,
      this.companySize,
      this.isOpenToOpportunity = true,
      this.isOpenToExchange = true})
      : _skills = skills;

  factory _$UserCardModelImpl.fromJson(Map<String, dynamic> json) =>
      _$$UserCardModelImplFromJson(json);

  @override
  final String id;
// user_profiles.id
  @override
  final String userId;
// users.id
  @override
  final String role;
// 'job_seeker' | 'employer' | 'peer'
  @override
  final String displayName;
  @override
  final String? avatarUrl;
  @override
  final String? bio;
  final List<String> _skills;
  @override
  @JsonKey()
  List<String> get skills {
    if (_skills is EqualUnmodifiableListView) return _skills;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_skills);
  }

  @override
  final int? expectedSalary;
  @override
  final String? companyName;
  @override
  final String? companySize;
  @override
  @JsonKey()
  final bool isOpenToOpportunity;
  @override
  @JsonKey()
  final bool isOpenToExchange;

  @override
  String toString() {
    return 'UserCardModel(id: $id, userId: $userId, role: $role, displayName: $displayName, avatarUrl: $avatarUrl, bio: $bio, skills: $skills, expectedSalary: $expectedSalary, companyName: $companyName, companySize: $companySize, isOpenToOpportunity: $isOpenToOpportunity, isOpenToExchange: $isOpenToExchange)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$UserCardModelImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.userId, userId) || other.userId == userId) &&
            (identical(other.role, role) || other.role == role) &&
            (identical(other.displayName, displayName) ||
                other.displayName == displayName) &&
            (identical(other.avatarUrl, avatarUrl) ||
                other.avatarUrl == avatarUrl) &&
            (identical(other.bio, bio) || other.bio == bio) &&
            const DeepCollectionEquality().equals(other._skills, _skills) &&
            (identical(other.expectedSalary, expectedSalary) ||
                other.expectedSalary == expectedSalary) &&
            (identical(other.companyName, companyName) ||
                other.companyName == companyName) &&
            (identical(other.companySize, companySize) ||
                other.companySize == companySize) &&
            (identical(other.isOpenToOpportunity, isOpenToOpportunity) ||
                other.isOpenToOpportunity == isOpenToOpportunity) &&
            (identical(other.isOpenToExchange, isOpenToExchange) ||
                other.isOpenToExchange == isOpenToExchange));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      userId,
      role,
      displayName,
      avatarUrl,
      bio,
      const DeepCollectionEquality().hash(_skills),
      expectedSalary,
      companyName,
      companySize,
      isOpenToOpportunity,
      isOpenToExchange);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$UserCardModelImplCopyWith<_$UserCardModelImpl> get copyWith =>
      __$$UserCardModelImplCopyWithImpl<_$UserCardModelImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$UserCardModelImplToJson(
      this,
    );
  }
}

abstract class _UserCardModel implements UserCardModel {
  const factory _UserCardModel(
      {required final String id,
      required final String userId,
      required final String role,
      required final String displayName,
      final String? avatarUrl,
      final String? bio,
      final List<String> skills,
      final int? expectedSalary,
      final String? companyName,
      final String? companySize,
      final bool isOpenToOpportunity,
      final bool isOpenToExchange}) = _$UserCardModelImpl;

  factory _UserCardModel.fromJson(Map<String, dynamic> json) =
      _$UserCardModelImpl.fromJson;

  @override
  String get id;
  @override // user_profiles.id
  String get userId;
  @override // users.id
  String get role;
  @override // 'job_seeker' | 'employer' | 'peer'
  String get displayName;
  @override
  String? get avatarUrl;
  @override
  String? get bio;
  @override
  List<String> get skills;
  @override
  int? get expectedSalary;
  @override
  String? get companyName;
  @override
  String? get companySize;
  @override
  bool get isOpenToOpportunity;
  @override
  bool get isOpenToExchange;
  @override
  @JsonKey(ignore: true)
  _$$UserCardModelImplCopyWith<_$UserCardModelImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'user_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

UserModel _$UserModelFromJson(Map<String, dynamic> json) {
  return _UserModel.fromJson(json);
}

/// @nodoc
mixin _$UserModel {
  String get id => throw _privateConstructorUsedError;
  String get email => throw _privateConstructorUsedError;
  UserRole get role => throw _privateConstructorUsedError;
  String get displayName => throw _privateConstructorUsedError;
  String? get avatarUrl => throw _privateConstructorUsedError;
  String? get bio => throw _privateConstructorUsedError;
  String? get location => throw _privateConstructorUsedError;
  List<String> get skills => throw _privateConstructorUsedError;
  int? get experienceYears => throw _privateConstructorUsedError;
  int? get expectedSalary => throw _privateConstructorUsedError;
  String? get companyName => throw _privateConstructorUsedError;
  String? get companySize =>
      throw _privateConstructorUsedError; // 目前操作身份（儲存在 DB，預設與 role 相同）
  AppRole? get currentRole => throw _privateConstructorUsedError;
  DateTime get createdAt => throw _privateConstructorUsedError;
  DateTime get updatedAt => throw _privateConstructorUsedError;

  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
  @JsonKey(ignore: true)
  $UserModelCopyWith<UserModel> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $UserModelCopyWith<$Res> {
  factory $UserModelCopyWith(UserModel value, $Res Function(UserModel) then) =
      _$UserModelCopyWithImpl<$Res, UserModel>;
  @useResult
  $Res call(
      {String id,
      String email,
      UserRole role,
      String displayName,
      String? avatarUrl,
      String? bio,
      String? location,
      List<String> skills,
      int? experienceYears,
      int? expectedSalary,
      String? companyName,
      String? companySize,
      AppRole? currentRole,
      DateTime createdAt,
      DateTime updatedAt});
}

/// @nodoc
class _$UserModelCopyWithImpl<$Res, $Val extends UserModel>
    implements $UserModelCopyWith<$Res> {
  _$UserModelCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? email = null,
    Object? role = null,
    Object? displayName = null,
    Object? avatarUrl = freezed,
    Object? bio = freezed,
    Object? location = freezed,
    Object? skills = null,
    Object? experienceYears = freezed,
    Object? expectedSalary = freezed,
    Object? companyName = freezed,
    Object? companySize = freezed,
    Object? currentRole = freezed,
    Object? createdAt = null,
    Object? updatedAt = null,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      email: null == email
          ? _value.email
          : email // ignore: cast_nullable_to_non_nullable
              as String,
      role: null == role
          ? _value.role
          : role // ignore: cast_nullable_to_non_nullable
              as UserRole,
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
      location: freezed == location
          ? _value.location
          : location // ignore: cast_nullable_to_non_nullable
              as String?,
      skills: null == skills
          ? _value.skills
          : skills // ignore: cast_nullable_to_non_nullable
              as List<String>,
      experienceYears: freezed == experienceYears
          ? _value.experienceYears
          : experienceYears // ignore: cast_nullable_to_non_nullable
              as int?,
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
      currentRole: freezed == currentRole
          ? _value.currentRole
          : currentRole // ignore: cast_nullable_to_non_nullable
              as AppRole?,
      createdAt: null == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      updatedAt: null == updatedAt
          ? _value.updatedAt
          : updatedAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$UserModelImplCopyWith<$Res>
    implements $UserModelCopyWith<$Res> {
  factory _$$UserModelImplCopyWith(
          _$UserModelImpl value, $Res Function(_$UserModelImpl) then) =
      __$$UserModelImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      String email,
      UserRole role,
      String displayName,
      String? avatarUrl,
      String? bio,
      String? location,
      List<String> skills,
      int? experienceYears,
      int? expectedSalary,
      String? companyName,
      String? companySize,
      AppRole? currentRole,
      DateTime createdAt,
      DateTime updatedAt});
}

/// @nodoc
class __$$UserModelImplCopyWithImpl<$Res>
    extends _$UserModelCopyWithImpl<$Res, _$UserModelImpl>
    implements _$$UserModelImplCopyWith<$Res> {
  __$$UserModelImplCopyWithImpl(
      _$UserModelImpl _value, $Res Function(_$UserModelImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? email = null,
    Object? role = null,
    Object? displayName = null,
    Object? avatarUrl = freezed,
    Object? bio = freezed,
    Object? location = freezed,
    Object? skills = null,
    Object? experienceYears = freezed,
    Object? expectedSalary = freezed,
    Object? companyName = freezed,
    Object? companySize = freezed,
    Object? currentRole = freezed,
    Object? createdAt = null,
    Object? updatedAt = null,
  }) {
    return _then(_$UserModelImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      email: null == email
          ? _value.email
          : email // ignore: cast_nullable_to_non_nullable
              as String,
      role: null == role
          ? _value.role
          : role // ignore: cast_nullable_to_non_nullable
              as UserRole,
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
      location: freezed == location
          ? _value.location
          : location // ignore: cast_nullable_to_non_nullable
              as String?,
      skills: null == skills
          ? _value._skills
          : skills // ignore: cast_nullable_to_non_nullable
              as List<String>,
      experienceYears: freezed == experienceYears
          ? _value.experienceYears
          : experienceYears // ignore: cast_nullable_to_non_nullable
              as int?,
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
      currentRole: freezed == currentRole
          ? _value.currentRole
          : currentRole // ignore: cast_nullable_to_non_nullable
              as AppRole?,
      createdAt: null == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      updatedAt: null == updatedAt
          ? _value.updatedAt
          : updatedAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$UserModelImpl extends _UserModel {
  const _$UserModelImpl(
      {required this.id,
      required this.email,
      required this.role,
      required this.displayName,
      this.avatarUrl,
      this.bio,
      this.location,
      final List<String> skills = const [],
      this.experienceYears,
      this.expectedSalary,
      this.companyName,
      this.companySize,
      this.currentRole,
      required this.createdAt,
      required this.updatedAt})
      : _skills = skills,
        super._();

  factory _$UserModelImpl.fromJson(Map<String, dynamic> json) =>
      _$$UserModelImplFromJson(json);

  @override
  final String id;
  @override
  final String email;
  @override
  final UserRole role;
  @override
  final String displayName;
  @override
  final String? avatarUrl;
  @override
  final String? bio;
  @override
  final String? location;
  final List<String> _skills;
  @override
  @JsonKey()
  List<String> get skills {
    if (_skills is EqualUnmodifiableListView) return _skills;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_skills);
  }

  @override
  final int? experienceYears;
  @override
  final int? expectedSalary;
  @override
  final String? companyName;
  @override
  final String? companySize;
// 目前操作身份（儲存在 DB，預設與 role 相同）
  @override
  final AppRole? currentRole;
  @override
  final DateTime createdAt;
  @override
  final DateTime updatedAt;

  @override
  String toString() {
    return 'UserModel(id: $id, email: $email, role: $role, displayName: $displayName, avatarUrl: $avatarUrl, bio: $bio, location: $location, skills: $skills, experienceYears: $experienceYears, expectedSalary: $expectedSalary, companyName: $companyName, companySize: $companySize, currentRole: $currentRole, createdAt: $createdAt, updatedAt: $updatedAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$UserModelImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.email, email) || other.email == email) &&
            (identical(other.role, role) || other.role == role) &&
            (identical(other.displayName, displayName) ||
                other.displayName == displayName) &&
            (identical(other.avatarUrl, avatarUrl) ||
                other.avatarUrl == avatarUrl) &&
            (identical(other.bio, bio) || other.bio == bio) &&
            (identical(other.location, location) ||
                other.location == location) &&
            const DeepCollectionEquality().equals(other._skills, _skills) &&
            (identical(other.experienceYears, experienceYears) ||
                other.experienceYears == experienceYears) &&
            (identical(other.expectedSalary, expectedSalary) ||
                other.expectedSalary == expectedSalary) &&
            (identical(other.companyName, companyName) ||
                other.companyName == companyName) &&
            (identical(other.companySize, companySize) ||
                other.companySize == companySize) &&
            (identical(other.currentRole, currentRole) ||
                other.currentRole == currentRole) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.updatedAt, updatedAt) ||
                other.updatedAt == updatedAt));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      email,
      role,
      displayName,
      avatarUrl,
      bio,
      location,
      const DeepCollectionEquality().hash(_skills),
      experienceYears,
      expectedSalary,
      companyName,
      companySize,
      currentRole,
      createdAt,
      updatedAt);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$UserModelImplCopyWith<_$UserModelImpl> get copyWith =>
      __$$UserModelImplCopyWithImpl<_$UserModelImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$UserModelImplToJson(
      this,
    );
  }
}

abstract class _UserModel extends UserModel {
  const factory _UserModel(
      {required final String id,
      required final String email,
      required final UserRole role,
      required final String displayName,
      final String? avatarUrl,
      final String? bio,
      final String? location,
      final List<String> skills,
      final int? experienceYears,
      final int? expectedSalary,
      final String? companyName,
      final String? companySize,
      final AppRole? currentRole,
      required final DateTime createdAt,
      required final DateTime updatedAt}) = _$UserModelImpl;
  const _UserModel._() : super._();

  factory _UserModel.fromJson(Map<String, dynamic> json) =
      _$UserModelImpl.fromJson;

  @override
  String get id;
  @override
  String get email;
  @override
  UserRole get role;
  @override
  String get displayName;
  @override
  String? get avatarUrl;
  @override
  String? get bio;
  @override
  String? get location;
  @override
  List<String> get skills;
  @override
  int? get experienceYears;
  @override
  int? get expectedSalary;
  @override
  String? get companyName;
  @override
  String? get companySize;
  @override // 目前操作身份（儲存在 DB，預設與 role 相同）
  AppRole? get currentRole;
  @override
  DateTime get createdAt;
  @override
  DateTime get updatedAt;
  @override
  @JsonKey(ignore: true)
  _$$UserModelImplCopyWith<_$UserModelImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

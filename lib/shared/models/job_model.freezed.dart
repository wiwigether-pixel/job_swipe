// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'job_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

JobModel _$JobModelFromJson(Map<String, dynamic> json) {
  return _JobModel.fromJson(json);
}

/// @nodoc
mixin _$JobModel {
  String get id => throw _privateConstructorUsedError;
  String get employerId => throw _privateConstructorUsedError;
  String get title => throw _privateConstructorUsedError;
  String get description => throw _privateConstructorUsedError;
  List<String> get requiredSkills => throw _privateConstructorUsedError;
  int? get salaryMin => throw _privateConstructorUsedError;
  int? get salaryMax => throw _privateConstructorUsedError;
  String? get location => throw _privateConstructorUsedError;
  JobType? get jobType => throw _privateConstructorUsedError;
  String get status =>
      throw _privateConstructorUsedError; // 關聯的雇主資訊（JOIN 查詢時帶入，方便卡片顯示）
  String? get companyName => throw _privateConstructorUsedError;
  String? get companyAvatarUrl => throw _privateConstructorUsedError;
  DateTime get createdAt => throw _privateConstructorUsedError;

  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
  @JsonKey(ignore: true)
  $JobModelCopyWith<JobModel> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $JobModelCopyWith<$Res> {
  factory $JobModelCopyWith(JobModel value, $Res Function(JobModel) then) =
      _$JobModelCopyWithImpl<$Res, JobModel>;
  @useResult
  $Res call(
      {String id,
      String employerId,
      String title,
      String description,
      List<String> requiredSkills,
      int? salaryMin,
      int? salaryMax,
      String? location,
      JobType? jobType,
      String status,
      String? companyName,
      String? companyAvatarUrl,
      DateTime createdAt});
}

/// @nodoc
class _$JobModelCopyWithImpl<$Res, $Val extends JobModel>
    implements $JobModelCopyWith<$Res> {
  _$JobModelCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? employerId = null,
    Object? title = null,
    Object? description = null,
    Object? requiredSkills = null,
    Object? salaryMin = freezed,
    Object? salaryMax = freezed,
    Object? location = freezed,
    Object? jobType = freezed,
    Object? status = null,
    Object? companyName = freezed,
    Object? companyAvatarUrl = freezed,
    Object? createdAt = null,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      employerId: null == employerId
          ? _value.employerId
          : employerId // ignore: cast_nullable_to_non_nullable
              as String,
      title: null == title
          ? _value.title
          : title // ignore: cast_nullable_to_non_nullable
              as String,
      description: null == description
          ? _value.description
          : description // ignore: cast_nullable_to_non_nullable
              as String,
      requiredSkills: null == requiredSkills
          ? _value.requiredSkills
          : requiredSkills // ignore: cast_nullable_to_non_nullable
              as List<String>,
      salaryMin: freezed == salaryMin
          ? _value.salaryMin
          : salaryMin // ignore: cast_nullable_to_non_nullable
              as int?,
      salaryMax: freezed == salaryMax
          ? _value.salaryMax
          : salaryMax // ignore: cast_nullable_to_non_nullable
              as int?,
      location: freezed == location
          ? _value.location
          : location // ignore: cast_nullable_to_non_nullable
              as String?,
      jobType: freezed == jobType
          ? _value.jobType
          : jobType // ignore: cast_nullable_to_non_nullable
              as JobType?,
      status: null == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as String,
      companyName: freezed == companyName
          ? _value.companyName
          : companyName // ignore: cast_nullable_to_non_nullable
              as String?,
      companyAvatarUrl: freezed == companyAvatarUrl
          ? _value.companyAvatarUrl
          : companyAvatarUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      createdAt: null == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$JobModelImplCopyWith<$Res>
    implements $JobModelCopyWith<$Res> {
  factory _$$JobModelImplCopyWith(
          _$JobModelImpl value, $Res Function(_$JobModelImpl) then) =
      __$$JobModelImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      String employerId,
      String title,
      String description,
      List<String> requiredSkills,
      int? salaryMin,
      int? salaryMax,
      String? location,
      JobType? jobType,
      String status,
      String? companyName,
      String? companyAvatarUrl,
      DateTime createdAt});
}

/// @nodoc
class __$$JobModelImplCopyWithImpl<$Res>
    extends _$JobModelCopyWithImpl<$Res, _$JobModelImpl>
    implements _$$JobModelImplCopyWith<$Res> {
  __$$JobModelImplCopyWithImpl(
      _$JobModelImpl _value, $Res Function(_$JobModelImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? employerId = null,
    Object? title = null,
    Object? description = null,
    Object? requiredSkills = null,
    Object? salaryMin = freezed,
    Object? salaryMax = freezed,
    Object? location = freezed,
    Object? jobType = freezed,
    Object? status = null,
    Object? companyName = freezed,
    Object? companyAvatarUrl = freezed,
    Object? createdAt = null,
  }) {
    return _then(_$JobModelImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      employerId: null == employerId
          ? _value.employerId
          : employerId // ignore: cast_nullable_to_non_nullable
              as String,
      title: null == title
          ? _value.title
          : title // ignore: cast_nullable_to_non_nullable
              as String,
      description: null == description
          ? _value.description
          : description // ignore: cast_nullable_to_non_nullable
              as String,
      requiredSkills: null == requiredSkills
          ? _value._requiredSkills
          : requiredSkills // ignore: cast_nullable_to_non_nullable
              as List<String>,
      salaryMin: freezed == salaryMin
          ? _value.salaryMin
          : salaryMin // ignore: cast_nullable_to_non_nullable
              as int?,
      salaryMax: freezed == salaryMax
          ? _value.salaryMax
          : salaryMax // ignore: cast_nullable_to_non_nullable
              as int?,
      location: freezed == location
          ? _value.location
          : location // ignore: cast_nullable_to_non_nullable
              as String?,
      jobType: freezed == jobType
          ? _value.jobType
          : jobType // ignore: cast_nullable_to_non_nullable
              as JobType?,
      status: null == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as String,
      companyName: freezed == companyName
          ? _value.companyName
          : companyName // ignore: cast_nullable_to_non_nullable
              as String?,
      companyAvatarUrl: freezed == companyAvatarUrl
          ? _value.companyAvatarUrl
          : companyAvatarUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      createdAt: null == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$JobModelImpl implements _JobModel {
  const _$JobModelImpl(
      {required this.id,
      required this.employerId,
      required this.title,
      required this.description,
      final List<String> requiredSkills = const [],
      this.salaryMin,
      this.salaryMax,
      this.location,
      this.jobType,
      this.status = 'open',
      this.companyName,
      this.companyAvatarUrl,
      required this.createdAt})
      : _requiredSkills = requiredSkills;

  factory _$JobModelImpl.fromJson(Map<String, dynamic> json) =>
      _$$JobModelImplFromJson(json);

  @override
  final String id;
  @override
  final String employerId;
  @override
  final String title;
  @override
  final String description;
  final List<String> _requiredSkills;
  @override
  @JsonKey()
  List<String> get requiredSkills {
    if (_requiredSkills is EqualUnmodifiableListView) return _requiredSkills;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_requiredSkills);
  }

  @override
  final int? salaryMin;
  @override
  final int? salaryMax;
  @override
  final String? location;
  @override
  final JobType? jobType;
  @override
  @JsonKey()
  final String status;
// 關聯的雇主資訊（JOIN 查詢時帶入，方便卡片顯示）
  @override
  final String? companyName;
  @override
  final String? companyAvatarUrl;
  @override
  final DateTime createdAt;

  @override
  String toString() {
    return 'JobModel(id: $id, employerId: $employerId, title: $title, description: $description, requiredSkills: $requiredSkills, salaryMin: $salaryMin, salaryMax: $salaryMax, location: $location, jobType: $jobType, status: $status, companyName: $companyName, companyAvatarUrl: $companyAvatarUrl, createdAt: $createdAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$JobModelImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.employerId, employerId) ||
                other.employerId == employerId) &&
            (identical(other.title, title) || other.title == title) &&
            (identical(other.description, description) ||
                other.description == description) &&
            const DeepCollectionEquality()
                .equals(other._requiredSkills, _requiredSkills) &&
            (identical(other.salaryMin, salaryMin) ||
                other.salaryMin == salaryMin) &&
            (identical(other.salaryMax, salaryMax) ||
                other.salaryMax == salaryMax) &&
            (identical(other.location, location) ||
                other.location == location) &&
            (identical(other.jobType, jobType) || other.jobType == jobType) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.companyName, companyName) ||
                other.companyName == companyName) &&
            (identical(other.companyAvatarUrl, companyAvatarUrl) ||
                other.companyAvatarUrl == companyAvatarUrl) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      employerId,
      title,
      description,
      const DeepCollectionEquality().hash(_requiredSkills),
      salaryMin,
      salaryMax,
      location,
      jobType,
      status,
      companyName,
      companyAvatarUrl,
      createdAt);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$JobModelImplCopyWith<_$JobModelImpl> get copyWith =>
      __$$JobModelImplCopyWithImpl<_$JobModelImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$JobModelImplToJson(
      this,
    );
  }
}

abstract class _JobModel implements JobModel {
  const factory _JobModel(
      {required final String id,
      required final String employerId,
      required final String title,
      required final String description,
      final List<String> requiredSkills,
      final int? salaryMin,
      final int? salaryMax,
      final String? location,
      final JobType? jobType,
      final String status,
      final String? companyName,
      final String? companyAvatarUrl,
      required final DateTime createdAt}) = _$JobModelImpl;

  factory _JobModel.fromJson(Map<String, dynamic> json) =
      _$JobModelImpl.fromJson;

  @override
  String get id;
  @override
  String get employerId;
  @override
  String get title;
  @override
  String get description;
  @override
  List<String> get requiredSkills;
  @override
  int? get salaryMin;
  @override
  int? get salaryMax;
  @override
  String? get location;
  @override
  JobType? get jobType;
  @override
  String get status;
  @override // 關聯的雇主資訊（JOIN 查詢時帶入，方便卡片顯示）
  String? get companyName;
  @override
  String? get companyAvatarUrl;
  @override
  DateTime get createdAt;
  @override
  @JsonKey(ignore: true)
  _$$JobModelImplCopyWith<_$JobModelImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

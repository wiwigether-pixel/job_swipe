// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'swipe_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$swipeRepositoryHash() => r'f2fcf103878e1379b42d911076846f75d4460cc2';

/// SwipeRepository Provider
///
/// Copied from [swipeRepository].
@ProviderFor(swipeRepository)
final swipeRepositoryProvider = Provider<SwipeRepository>.internal(
  swipeRepository,
  name: r'swipeRepositoryProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$swipeRepositoryHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef SwipeRepositoryRef = ProviderRef<SwipeRepository>;
String _$recommendedJobsHash() => r'9da3538fc0967383c37c4f20e78ba02231714da8';

/// 推薦職缺列表 Provider
/// 【設計說明】使用 AsyncNotifier 而非單純的 FutureProvider
/// 好處：可以在滑卡後動態移除卡片，不需要重新 fetch 整個列表
///
/// Copied from [RecommendedJobs].
@ProviderFor(RecommendedJobs)
final recommendedJobsProvider =
    AutoDisposeAsyncNotifierProvider<RecommendedJobs, List<JobModel>>.internal(
  RecommendedJobs.new,
  name: r'recommendedJobsProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$recommendedJobsHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$RecommendedJobs = AutoDisposeAsyncNotifier<List<JobModel>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member

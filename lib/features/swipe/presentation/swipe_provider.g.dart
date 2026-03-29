// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'swipe_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$swipeRepositoryHash() => r'e9ba88384d3437d1ff95b32ec330c5e2f1b26bfd';

/// See also [swipeRepository].
@ProviderFor(swipeRepository)
final swipeRepositoryProvider = Provider<SupabaseSwipeRepository>.internal(
  swipeRepository,
  name: r'swipeRepositoryProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$swipeRepositoryHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef SwipeRepositoryRef = ProviderRef<SupabaseSwipeRepository>;
String _$recommendedJobsHash() => r'21ca97905fae148fef48f1b01e7c3340bee52b33';

/// See also [RecommendedJobs].
@ProviderFor(RecommendedJobs)
final recommendedJobsProvider =
    AutoDisposeAsyncNotifierProvider<RecommendedJobs, List<SwipeCard>>.internal(
  RecommendedJobs.new,
  name: r'recommendedJobsProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$recommendedJobsHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$RecommendedJobs = AutoDisposeAsyncNotifier<List<SwipeCard>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member

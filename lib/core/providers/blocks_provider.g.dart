// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'blocks_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$blockedIdsHash() => r'1c2302745f0831a5544717b9113b337d2b86df6a';

/// 雙向封鎖名單：我封鎖的 + 封鎖我的（後者走 SECURITY DEFINER RPC）。
///
/// Copied from [BlockedIds].
@ProviderFor(BlockedIds)
final blockedIdsProvider =
    AsyncNotifierProvider<BlockedIds, Set<String>>.internal(
  BlockedIds.new,
  name: r'blockedIdsProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$blockedIdsHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$BlockedIds = AsyncNotifier<Set<String>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member

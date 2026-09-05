// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'admin_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$adminRoleHash() => r'1bcac89772386f46ab4eedc214647d992a3203c6';

/// 當前登入者的管理員等級；非管理員回傳 null
///
/// Copied from [adminRole].
@ProviderFor(adminRole)
final adminRoleProvider = FutureProvider<AdminRole?>.internal(
  adminRole,
  name: r'adminRoleProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$adminRoleHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef AdminRoleRef = FutureProviderRef<AdminRole?>;
String _$adminStatsHash() => r'3807b6961495af0154e8d484143faf325daba294';

/// ── 後台統計（Dashboard 用）──────────────────────────────────
///
/// Copied from [adminStats].
@ProviderFor(adminStats)
final adminStatsProvider = AutoDisposeFutureProvider<AdminStats>.internal(
  adminStats,
  name: r'adminStatsProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$adminStatsHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef AdminStatsRef = AutoDisposeFutureProviderRef<AdminStats>;
String _$adminUsersHash() => r'9a465c6a7e009e0936b8f524f79c5a5a78e78ffa';

/// Copied from Dart SDK
class _SystemHash {
  _SystemHash._();

  static int combine(int hash, int value) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + value);
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x0007ffff & hash) << 10));
    return hash ^ (hash >> 6);
  }

  static int finish(int hash) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x03ffffff & hash) << 3));
    // ignore: parameter_assignments
    hash = hash ^ (hash >> 11);
    return 0x1fffffff & (hash + ((0x00003fff & hash) << 15));
  }
}

/// ── 用戶管理 ─────────────────────────────────────────────────
///
/// Copied from [adminUsers].
@ProviderFor(adminUsers)
const adminUsersProvider = AdminUsersFamily();

/// ── 用戶管理 ─────────────────────────────────────────────────
///
/// Copied from [adminUsers].
class AdminUsersFamily extends Family<AsyncValue<List<Map<String, dynamic>>>> {
  /// ── 用戶管理 ─────────────────────────────────────────────────
  ///
  /// Copied from [adminUsers].
  const AdminUsersFamily();

  /// ── 用戶管理 ─────────────────────────────────────────────────
  ///
  /// Copied from [adminUsers].
  AdminUsersProvider call({
    String search = '',
    String? roleFilter,
  }) {
    return AdminUsersProvider(
      search: search,
      roleFilter: roleFilter,
    );
  }

  @override
  AdminUsersProvider getProviderOverride(
    covariant AdminUsersProvider provider,
  ) {
    return call(
      search: provider.search,
      roleFilter: provider.roleFilter,
    );
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'adminUsersProvider';
}

/// ── 用戶管理 ─────────────────────────────────────────────────
///
/// Copied from [adminUsers].
class AdminUsersProvider
    extends AutoDisposeFutureProvider<List<Map<String, dynamic>>> {
  /// ── 用戶管理 ─────────────────────────────────────────────────
  ///
  /// Copied from [adminUsers].
  AdminUsersProvider({
    String search = '',
    String? roleFilter,
  }) : this._internal(
          (ref) => adminUsers(
            ref as AdminUsersRef,
            search: search,
            roleFilter: roleFilter,
          ),
          from: adminUsersProvider,
          name: r'adminUsersProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$adminUsersHash,
          dependencies: AdminUsersFamily._dependencies,
          allTransitiveDependencies:
              AdminUsersFamily._allTransitiveDependencies,
          search: search,
          roleFilter: roleFilter,
        );

  AdminUsersProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.search,
    required this.roleFilter,
  }) : super.internal();

  final String search;
  final String? roleFilter;

  @override
  Override overrideWith(
    FutureOr<List<Map<String, dynamic>>> Function(AdminUsersRef provider)
        create,
  ) {
    return ProviderOverride(
      origin: this,
      override: AdminUsersProvider._internal(
        (ref) => create(ref as AdminUsersRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        search: search,
        roleFilter: roleFilter,
      ),
    );
  }

  @override
  AutoDisposeFutureProviderElement<List<Map<String, dynamic>>> createElement() {
    return _AdminUsersProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is AdminUsersProvider &&
        other.search == search &&
        other.roleFilter == roleFilter;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, search.hashCode);
    hash = _SystemHash.combine(hash, roleFilter.hashCode);

    return _SystemHash.finish(hash);
  }
}

mixin AdminUsersRef
    on AutoDisposeFutureProviderRef<List<Map<String, dynamic>>> {
  /// The parameter `search` of this provider.
  String get search;

  /// The parameter `roleFilter` of this provider.
  String? get roleFilter;
}

class _AdminUsersProviderElement
    extends AutoDisposeFutureProviderElement<List<Map<String, dynamic>>>
    with AdminUsersRef {
  _AdminUsersProviderElement(super.provider);

  @override
  String get search => (origin as AdminUsersProvider).search;
  @override
  String? get roleFilter => (origin as AdminUsersProvider).roleFilter;
}

String _$adminJobsHash() => r'7f30476ffa4eb8f50686db134826f8aa2f9c5a23';

/// ── 職缺管理 ─────────────────────────────────────────────────
///
/// Copied from [adminJobs].
@ProviderFor(adminJobs)
const adminJobsProvider = AdminJobsFamily();

/// ── 職缺管理 ─────────────────────────────────────────────────
///
/// Copied from [adminJobs].
class AdminJobsFamily extends Family<AsyncValue<List<Map<String, dynamic>>>> {
  /// ── 職缺管理 ─────────────────────────────────────────────────
  ///
  /// Copied from [adminJobs].
  const AdminJobsFamily();

  /// ── 職缺管理 ─────────────────────────────────────────────────
  ///
  /// Copied from [adminJobs].
  AdminJobsProvider call({
    String? statusFilter,
  }) {
    return AdminJobsProvider(
      statusFilter: statusFilter,
    );
  }

  @override
  AdminJobsProvider getProviderOverride(
    covariant AdminJobsProvider provider,
  ) {
    return call(
      statusFilter: provider.statusFilter,
    );
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'adminJobsProvider';
}

/// ── 職缺管理 ─────────────────────────────────────────────────
///
/// Copied from [adminJobs].
class AdminJobsProvider
    extends AutoDisposeFutureProvider<List<Map<String, dynamic>>> {
  /// ── 職缺管理 ─────────────────────────────────────────────────
  ///
  /// Copied from [adminJobs].
  AdminJobsProvider({
    String? statusFilter,
  }) : this._internal(
          (ref) => adminJobs(
            ref as AdminJobsRef,
            statusFilter: statusFilter,
          ),
          from: adminJobsProvider,
          name: r'adminJobsProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$adminJobsHash,
          dependencies: AdminJobsFamily._dependencies,
          allTransitiveDependencies: AdminJobsFamily._allTransitiveDependencies,
          statusFilter: statusFilter,
        );

  AdminJobsProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.statusFilter,
  }) : super.internal();

  final String? statusFilter;

  @override
  Override overrideWith(
    FutureOr<List<Map<String, dynamic>>> Function(AdminJobsRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: AdminJobsProvider._internal(
        (ref) => create(ref as AdminJobsRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        statusFilter: statusFilter,
      ),
    );
  }

  @override
  AutoDisposeFutureProviderElement<List<Map<String, dynamic>>> createElement() {
    return _AdminJobsProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is AdminJobsProvider && other.statusFilter == statusFilter;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, statusFilter.hashCode);

    return _SystemHash.finish(hash);
  }
}

mixin AdminJobsRef on AutoDisposeFutureProviderRef<List<Map<String, dynamic>>> {
  /// The parameter `statusFilter` of this provider.
  String? get statusFilter;
}

class _AdminJobsProviderElement
    extends AutoDisposeFutureProviderElement<List<Map<String, dynamic>>>
    with AdminJobsRef {
  _AdminJobsProviderElement(super.provider);

  @override
  String? get statusFilter => (origin as AdminJobsProvider).statusFilter;
}

String _$adminReportsHash() => r'a35f9095f725ddf84a4c91d7df21ba02c320200e';

/// ── 檢舉管理 ─────────────────────────────────────────────────
///
/// Copied from [adminReports].
@ProviderFor(adminReports)
const adminReportsProvider = AdminReportsFamily();

/// ── 檢舉管理 ─────────────────────────────────────────────────
///
/// Copied from [adminReports].
class AdminReportsFamily
    extends Family<AsyncValue<List<Map<String, dynamic>>>> {
  /// ── 檢舉管理 ─────────────────────────────────────────────────
  ///
  /// Copied from [adminReports].
  const AdminReportsFamily();

  /// ── 檢舉管理 ─────────────────────────────────────────────────
  ///
  /// Copied from [adminReports].
  AdminReportsProvider call({
    String statusFilter = 'pending',
  }) {
    return AdminReportsProvider(
      statusFilter: statusFilter,
    );
  }

  @override
  AdminReportsProvider getProviderOverride(
    covariant AdminReportsProvider provider,
  ) {
    return call(
      statusFilter: provider.statusFilter,
    );
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'adminReportsProvider';
}

/// ── 檢舉管理 ─────────────────────────────────────────────────
///
/// Copied from [adminReports].
class AdminReportsProvider
    extends AutoDisposeFutureProvider<List<Map<String, dynamic>>> {
  /// ── 檢舉管理 ─────────────────────────────────────────────────
  ///
  /// Copied from [adminReports].
  AdminReportsProvider({
    String statusFilter = 'pending',
  }) : this._internal(
          (ref) => adminReports(
            ref as AdminReportsRef,
            statusFilter: statusFilter,
          ),
          from: adminReportsProvider,
          name: r'adminReportsProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$adminReportsHash,
          dependencies: AdminReportsFamily._dependencies,
          allTransitiveDependencies:
              AdminReportsFamily._allTransitiveDependencies,
          statusFilter: statusFilter,
        );

  AdminReportsProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.statusFilter,
  }) : super.internal();

  final String statusFilter;

  @override
  Override overrideWith(
    FutureOr<List<Map<String, dynamic>>> Function(AdminReportsRef provider)
        create,
  ) {
    return ProviderOverride(
      origin: this,
      override: AdminReportsProvider._internal(
        (ref) => create(ref as AdminReportsRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        statusFilter: statusFilter,
      ),
    );
  }

  @override
  AutoDisposeFutureProviderElement<List<Map<String, dynamic>>> createElement() {
    return _AdminReportsProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is AdminReportsProvider && other.statusFilter == statusFilter;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, statusFilter.hashCode);

    return _SystemHash.finish(hash);
  }
}

mixin AdminReportsRef
    on AutoDisposeFutureProviderRef<List<Map<String, dynamic>>> {
  /// The parameter `statusFilter` of this provider.
  String get statusFilter;
}

class _AdminReportsProviderElement
    extends AutoDisposeFutureProviderElement<List<Map<String, dynamic>>>
    with AdminReportsRef {
  _AdminReportsProviderElement(super.provider);

  @override
  String get statusFilter => (origin as AdminReportsProvider).statusFilter;
}

String _$reportConversationHash() =>
    r'3ad1d3f4cdfa7fa1888810f90df2ddf48252bd86';

/// 載入某個對話（match）的訊息，供管理員審核
///
/// Copied from [reportConversation].
@ProviderFor(reportConversation)
const reportConversationProvider = ReportConversationFamily();

/// 載入某個對話（match）的訊息，供管理員審核
///
/// Copied from [reportConversation].
class ReportConversationFamily
    extends Family<AsyncValue<List<Map<String, dynamic>>>> {
  /// 載入某個對話（match）的訊息，供管理員審核
  ///
  /// Copied from [reportConversation].
  const ReportConversationFamily();

  /// 載入某個對話（match）的訊息，供管理員審核
  ///
  /// Copied from [reportConversation].
  ReportConversationProvider call(
    String matchId,
  ) {
    return ReportConversationProvider(
      matchId,
    );
  }

  @override
  ReportConversationProvider getProviderOverride(
    covariant ReportConversationProvider provider,
  ) {
    return call(
      provider.matchId,
    );
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'reportConversationProvider';
}

/// 載入某個對話（match）的訊息，供管理員審核
///
/// Copied from [reportConversation].
class ReportConversationProvider
    extends AutoDisposeFutureProvider<List<Map<String, dynamic>>> {
  /// 載入某個對話（match）的訊息，供管理員審核
  ///
  /// Copied from [reportConversation].
  ReportConversationProvider(
    String matchId,
  ) : this._internal(
          (ref) => reportConversation(
            ref as ReportConversationRef,
            matchId,
          ),
          from: reportConversationProvider,
          name: r'reportConversationProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$reportConversationHash,
          dependencies: ReportConversationFamily._dependencies,
          allTransitiveDependencies:
              ReportConversationFamily._allTransitiveDependencies,
          matchId: matchId,
        );

  ReportConversationProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.matchId,
  }) : super.internal();

  final String matchId;

  @override
  Override overrideWith(
    FutureOr<List<Map<String, dynamic>>> Function(
            ReportConversationRef provider)
        create,
  ) {
    return ProviderOverride(
      origin: this,
      override: ReportConversationProvider._internal(
        (ref) => create(ref as ReportConversationRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        matchId: matchId,
      ),
    );
  }

  @override
  AutoDisposeFutureProviderElement<List<Map<String, dynamic>>> createElement() {
    return _ReportConversationProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is ReportConversationProvider && other.matchId == matchId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, matchId.hashCode);

    return _SystemHash.finish(hash);
  }
}

mixin ReportConversationRef
    on AutoDisposeFutureProviderRef<List<Map<String, dynamic>>> {
  /// The parameter `matchId` of this provider.
  String get matchId;
}

class _ReportConversationProviderElement
    extends AutoDisposeFutureProviderElement<List<Map<String, dynamic>>>
    with ReportConversationRef {
  _ReportConversationProviderElement(super.provider);

  @override
  String get matchId => (origin as ReportConversationProvider).matchId;
}

String _$adminInboxHash() => r'85bde59574c5d585807c00419f15d08c6ede695a';

/// ── 站內信 / 官方信箱 ────────────────────────────────────────
///
/// Copied from [adminInbox].
@ProviderFor(adminInbox)
const adminInboxProvider = AdminInboxFamily();

/// ── 站內信 / 官方信箱 ────────────────────────────────────────
///
/// Copied from [adminInbox].
class AdminInboxFamily extends Family<AsyncValue<List<Map<String, dynamic>>>> {
  /// ── 站內信 / 官方信箱 ────────────────────────────────────────
  ///
  /// Copied from [adminInbox].
  const AdminInboxFamily();

  /// ── 站內信 / 官方信箱 ────────────────────────────────────────
  ///
  /// Copied from [adminInbox].
  AdminInboxProvider call({
    String statusFilter = 'unread',
  }) {
    return AdminInboxProvider(
      statusFilter: statusFilter,
    );
  }

  @override
  AdminInboxProvider getProviderOverride(
    covariant AdminInboxProvider provider,
  ) {
    return call(
      statusFilter: provider.statusFilter,
    );
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'adminInboxProvider';
}

/// ── 站內信 / 官方信箱 ────────────────────────────────────────
///
/// Copied from [adminInbox].
class AdminInboxProvider
    extends AutoDisposeFutureProvider<List<Map<String, dynamic>>> {
  /// ── 站內信 / 官方信箱 ────────────────────────────────────────
  ///
  /// Copied from [adminInbox].
  AdminInboxProvider({
    String statusFilter = 'unread',
  }) : this._internal(
          (ref) => adminInbox(
            ref as AdminInboxRef,
            statusFilter: statusFilter,
          ),
          from: adminInboxProvider,
          name: r'adminInboxProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$adminInboxHash,
          dependencies: AdminInboxFamily._dependencies,
          allTransitiveDependencies:
              AdminInboxFamily._allTransitiveDependencies,
          statusFilter: statusFilter,
        );

  AdminInboxProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.statusFilter,
  }) : super.internal();

  final String statusFilter;

  @override
  Override overrideWith(
    FutureOr<List<Map<String, dynamic>>> Function(AdminInboxRef provider)
        create,
  ) {
    return ProviderOverride(
      origin: this,
      override: AdminInboxProvider._internal(
        (ref) => create(ref as AdminInboxRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        statusFilter: statusFilter,
      ),
    );
  }

  @override
  AutoDisposeFutureProviderElement<List<Map<String, dynamic>>> createElement() {
    return _AdminInboxProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is AdminInboxProvider && other.statusFilter == statusFilter;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, statusFilter.hashCode);

    return _SystemHash.finish(hash);
  }
}

mixin AdminInboxRef
    on AutoDisposeFutureProviderRef<List<Map<String, dynamic>>> {
  /// The parameter `statusFilter` of this provider.
  String get statusFilter;
}

class _AdminInboxProviderElement
    extends AutoDisposeFutureProviderElement<List<Map<String, dynamic>>>
    with AdminInboxRef {
  _AdminInboxProviderElement(super.provider);

  @override
  String get statusFilter => (origin as AdminInboxProvider).statusFilter;
}

String _$adminActionsHash() => r'9945718fd4008cfbff9b6012569b4fb8f6c186b9';

/// ── 管理操作 ─────────────────────────────────────────────────
///
/// Copied from [adminActions].
@ProviderFor(adminActions)
final adminActionsProvider = AutoDisposeProvider<AdminActions>.internal(
  adminActions,
  name: r'adminActionsProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$adminActionsHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef AdminActionsRef = AutoDisposeProviderRef<AdminActions>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member

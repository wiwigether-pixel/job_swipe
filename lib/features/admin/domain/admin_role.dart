/// 管理員等級（對應 admin_roles.level）
enum AdminRole {
  superAdmin,
  moderator;

  static AdminRole? fromString(String? value) => switch (value) {
        'super_admin' => AdminRole.superAdmin,
        'moderator' => AdminRole.moderator,
        _ => null,
      };

  String get label => switch (this) {
        AdminRole.superAdmin => '超級管理員',
        AdminRole.moderator => '版主',
      };

  /// 是否可管理其他管理員 / 刪除用戶（僅 super_admin）
  bool get canManageAdmins => this == AdminRole.superAdmin;
  bool get canDeleteUsers => this == AdminRole.superAdmin;
}

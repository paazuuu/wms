/// The three kinds of user (0193), from the roles they hold:
///  * [admin] (ADMIN) — system_admin, company_admin: sees everything and
///    decides what the others see;
///  * [manager] (管理者ユーザー) — the warehouse's people in charge:
///    warehouse_manager, inventory_controller, purchasing, sales;
///  * [user] (通常ユーザー) — everyone else: the warehouse floor.
enum UserTier {
  admin,
  manager,
  user;

  /// What the server calls it (menu_visibility.tier); admin has no setting.
  String get wire => name;

  static const adminRoles = {'system_admin', 'company_admin'};
  static const managerRoles = {'warehouse_manager', 'inventory_controller', 'purchasing', 'sales'};

  /// The tier [roles] make; null with no role at all — nothing is hidden
  /// then, since without a role there is no permission to show anything.
  static UserTier? of(Iterable<String> roles) {
    final r = roles.toSet();
    if (r.isEmpty) return null;
    if (r.any(adminRoles.contains)) return admin;
    if (r.any(managerRoles.contains)) return manager;
    return user;
  }
}

/// Content (not a menu) that can be shown or hidden per tier: prices and
/// amounts — 仕入れ値 in a product's page, 金額 in the 出庫カレンダー.
const contentPrices = 'content.prices';

/// The groups each tier sees unless set otherwise: a user the floor's work
/// (現場作業) only; a manager the products, the floor and shipping, with the
/// management screens a warehouse runs on.
const _managerGroups = {'products_master', 'field_operations', 'shipping'};
const _managerExtras = {'reports', 'locations', 'partners', 'stock_reconciliation', 'reservations', contentPrices};

/// Whether [tier] sees [featureId] (in [groupId]) when nobody has set it.
bool defaultVisible(String featureId, String groupId, UserTier tier) => switch (tier) {
      UserTier.admin => true,
      UserTier.manager => _managerGroups.contains(groupId) || _managerExtras.contains(featureId),
      UserTier.user => groupId == 'field_operations',
    };

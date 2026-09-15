import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Whether the wide-layout sidebar is collapsed to an icon-only rail.
///
/// Persisted, following [TextScaleController]'s pattern, because this is a
/// per-operator preference about their own screen: someone on a 1280px laptop
/// who collapses the sidebar to get the content area back should not have to
/// do it again every morning.
///
/// Only affects the wide layout. Below the 900px breakpoint the sidebar is
/// already a drawer, where "collapsed" has no meaning.
class SidebarController extends StateNotifier<bool> {
  SidebarController(this._storage) : super(false) {
    _restore();
  }

  final FlutterSecureStorage _storage;
  static const _storageKey = 'sidebar_collapsed';

  Future<void> _restore() async {
    try {
      final raw = await _storage.read(key: _storageKey);
      if (raw == 'true') state = true;
    } catch (_) {
      // Keep the default (expanded) if storage is unavailable.
    }
  }

  Future<void> toggle() => setCollapsed(!state);

  Future<void> setCollapsed(bool collapsed) async {
    state = collapsed;
    try {
      await _storage.write(key: _storageKey, value: '$collapsed');
    } catch (_) {
      // Non-fatal: the in-memory choice still applies for this session.
    }
  }
}

final sidebarCollapsedProvider =
    StateNotifierProvider<SidebarController, bool>((ref) {
  return SidebarController(const FlutterSecureStorage());
});

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/supabase_auth_interceptor.dart';
import '../../../core/config/app_config.dart';
import '../../../core/providers.dart';
import '../data/delivery_note_scanner.dart';
import '../data/delivery_repository.dart';
import '../data/on_device_scanner.dart';
import '../data/remote_delivery_note_scanner.dart';
import '../data/stock_repository.dart';
import '../../warehouse_context/application/warehouse_providers.dart';
import '../domain/delivery_plan.dart';
import '../domain/receipt.dart';
import '../domain/stock_item.dart';
import '../domain/stock_movement.dart';
import 'reconciliation_controller.dart';

/// Dedicated Dio for the delivery feature, pointed at the Supabase Edge
/// Functions that back it (schema + reconcile RPC + OCR). Separate from the
/// app's main API client so the other features are unaffected. Carries the
/// anon key as a baseline (for the gateway) and, once someone's signed in,
/// the real access token via [SupabaseAuthInterceptor] — that's what lets
/// `auth.uid()` resolve server-side instead of staying null.
final deliveryDioProvider = Provider<Dio>((ref) {
  final dio = Dio(BaseOptions(
    baseUrl: AppConfig.functionsBaseUrl,
    connectTimeout: AppConfig.connectTimeout,
    receiveTimeout: AppConfig.receiveTimeout,
    headers: {
      'Accept': 'application/json',
      'apikey': AppConfig.supabaseAnonKey,
      'Authorization': 'Bearer ${AppConfig.supabaseAnonKey}',
    },
  ));
  SupabaseAuthInterceptor(
    storage: ref.watch(supabaseSessionStorageProvider),
    refresher: ref.watch(supabaseTokenRefresherProvider),
  ).attachTo(dio);
  return dio;
});

final deliveryRepositoryProvider = Provider<DeliveryRepository>((ref) {
  return DeliveryRepositoryImpl(ref.watch(deliveryDioProvider));
});

/// Dio for Supabase PostgREST (`/rest/v1`), used to read the stock table and
/// (since 0024) the auth-bootstrap RPCs. Same auth wiring as
/// [deliveryDioProvider] — see its doc comment.
final restDioProvider = Provider<Dio>((ref) {
  final dio = Dio(BaseOptions(
    baseUrl: '${AppConfig.supabaseUrl}/rest/v1',
    connectTimeout: AppConfig.connectTimeout,
    receiveTimeout: AppConfig.receiveTimeout,
    headers: {
      'Accept': 'application/json',
      'apikey': AppConfig.supabaseAnonKey,
      'Authorization': 'Bearer ${AppConfig.supabaseAnonKey}',
    },
  ));
  SupabaseAuthInterceptor(
    storage: ref.watch(supabaseSessionStorageProvider),
    refresher: ref.watch(supabaseTokenRefresherProvider),
  ).attachTo(dio);
  return dio;
});

final stockRepositoryProvider = Provider<StockRepository>((ref) {
  return StockRepositoryImpl(ref.watch(restDioProvider));
});

/// Dio for Supabase Storage (`/storage/v1`) — attachment upload and signed
/// download URLs (0031). Same auth wiring as [deliveryDioProvider]: the RLS
/// policies on `storage.objects` are permission-gated, so this needs the
/// real signed-in user's token, not just the anon key.
final storageDioProvider = Provider<Dio>((ref) {
  final dio = Dio(BaseOptions(
    baseUrl: AppConfig.storageBaseUrl,
    connectTimeout: AppConfig.connectTimeout,
    receiveTimeout: AppConfig.receiveTimeout,
    headers: {
      'Accept': 'application/json',
      'apikey': AppConfig.supabaseAnonKey,
      'Authorization': 'Bearer ${AppConfig.supabaseAnonKey}',
    },
  ));
  SupabaseAuthInterceptor(
    storage: ref.watch(supabaseSessionStorageProvider),
    refresher: ref.watch(supabaseTokenRefresherProvider),
  ).attachTo(dio);
  return dio;
});

/// Per-JAN on-hand stock for the active warehouse, highest first. A null active
/// warehouse means the company-wide view.
final stockListProvider =
    FutureProvider.autoDispose<List<StockItem>>((ref) async {
  final warehouseId = ref.watch(activeWarehouseIdProvider);
  final result =
      await ref.watch(stockRepositoryProvider).list(warehouseId: warehouseId);
  return result.when(
    success: (data) => data,
    failure: (f) => throw Exception(f.message),
  );
});

/// The stock ledger for one JAN in the active warehouse — why it changed.
final stockLedgerProvider = FutureProvider.autoDispose
    .family<List<StockMovement>, String>((ref, janCode) async {
  final warehouseId = ref.watch(activeWarehouseIdProvider);
  final result = await ref
      .watch(stockRepositoryProvider)
      .ledger(janCode, warehouseId: warehouseId);
  return result.when(
    success: (data) => data,
    failure: (f) => throw Exception(f.message),
  );
});

/// Delivery-note OCR assist: cloud vision (Gemini, via the backend) first, with
/// the on-device engine as an offline fallback.
final deliveryNoteScannerProvider = Provider<DeliveryNoteScanner>((ref) {
  final scanner = FallbackDeliveryNoteScanner(
    primary: RemoteDeliveryNoteScanner(ref.watch(deliveryDioProvider)),
    fallback: MlKitDeliveryNoteScanner(),
  );
  ref.onDispose(scanner.dispose);
  return scanner;
});

/// Whether the plan list also shows already-reconciled plans (for corrections).
final showCompletedPlansProvider = StateProvider<bool>((_) => false);

/// Delivery plans awaiting a physical check: freshly imported (`open`), any
/// mid-reconciliation, and partly-delivered (`partial`, i.e. still carrying an
/// outstanding 未納 list), newest first. Completed plans are included only when
/// [showCompletedPlansProvider] is on, so a mistaken receipt can be corrected.
///
/// Scoped to the current warehouse (UI spec §4: switching warehouse switches
/// Receiving too). A null scope is the deliberate "all warehouses" view.
final deliveryPlansProvider =
    FutureProvider.autoDispose<List<DeliveryPlan>>((ref) async {
  final repository = ref.watch(deliveryRepositoryProvider);
  final includeCompleted = ref.watch(showCompletedPlansProvider);
  final warehouseId = ref.watch(activeWarehouseIdProvider);
  final statuses = [
    'open',
    'reconciling',
    'partial',
    if (includeCompleted) 'completed',
  ];

  final plans = <DeliveryPlan>[];
  for (final status in statuses) {
    final result =
        await repository.list(status: status, warehouseId: warehouseId);
    result.when(
      success: plans.addAll,
      failure: (f) => throw Exception(f.message),
    );
  }
  plans.sort((a, b) => b.id.compareTo(a.id));
  return plans;
});

/// The receipts (reconciliations) recorded against one plan, newest first.
final planReceiptsProvider = FutureProvider.autoDispose
    .family<List<Receipt>, int>((ref, planId) async {
  final result = await ref.watch(deliveryRepositoryProvider).receipts(planId);
  return result.when(
    success: (data) => data,
    failure: (f) => throw Exception(f.message),
  );
});

/// A single delivery plan with its expected lines, for reconciliation.
final deliveryPlanDetailProvider =
    FutureProvider.autoDispose.family<DeliveryPlan, int>((ref, id) async {
  final repository = ref.watch(deliveryRepositoryProvider);
  final result = await repository.show(id);
  return result.when(
    success: (data) => data,
    failure: (failure) => throw Exception(failure.message),
  );
});

/// Session controller for reconciling one loaded plan.
final reconciliationControllerProvider = StateNotifierProvider.autoDispose
    .family<ReconciliationController, ReconciliationState, DeliveryPlan>(
        (ref, plan) {
  return ReconciliationController(
      ref.watch(deliveryRepositoryProvider), plan);
});

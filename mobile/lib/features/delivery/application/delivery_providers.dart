import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../data/delivery_note_scanner.dart';
import '../data/delivery_repository.dart';
import '../data/mlkit_delivery_note_scanner.dart';
import '../data/remote_delivery_note_scanner.dart';
import '../data/stock_repository.dart';
import '../domain/delivery_plan.dart';
import '../domain/receipt.dart';
import '../domain/stock_item.dart';
import 'reconciliation_controller.dart';

/// Dedicated Dio for the delivery feature, pointed at the Supabase Edge
/// Functions that back it (schema + reconcile RPC + OCR). Separate from the
/// app's main API client so the other features are unaffected. The anon key
/// authorizes the gateway; data is guarded server-side.
final deliveryDioProvider = Provider<Dio>((ref) {
  return Dio(BaseOptions(
    baseUrl: AppConfig.functionsBaseUrl,
    connectTimeout: AppConfig.connectTimeout,
    receiveTimeout: AppConfig.receiveTimeout,
    headers: {
      'Accept': 'application/json',
      'apikey': AppConfig.supabaseAnonKey,
      'Authorization': 'Bearer ${AppConfig.supabaseAnonKey}',
    },
  ));
});

final deliveryRepositoryProvider = Provider<DeliveryRepository>((ref) {
  return DeliveryRepositoryImpl(ref.watch(deliveryDioProvider));
});

/// Dio for Supabase PostgREST (`/rest/v1`), used to read the stock table.
final restDioProvider = Provider<Dio>((ref) {
  return Dio(BaseOptions(
    baseUrl: '${AppConfig.supabaseUrl}/rest/v1',
    connectTimeout: AppConfig.connectTimeout,
    receiveTimeout: AppConfig.receiveTimeout,
    headers: {
      'Accept': 'application/json',
      'apikey': AppConfig.supabaseAnonKey,
      'Authorization': 'Bearer ${AppConfig.supabaseAnonKey}',
    },
  ));
});

final stockRepositoryProvider = Provider<StockRepository>((ref) {
  return StockRepositoryImpl(ref.watch(restDioProvider));
});

/// Per-JAN total on-hand stock, highest first.
final stockListProvider =
    FutureProvider.autoDispose<List<StockItem>>((ref) async {
  final result = await ref.watch(stockRepositoryProvider).list();
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
final deliveryPlansProvider =
    FutureProvider.autoDispose<List<DeliveryPlan>>((ref) async {
  final repository = ref.watch(deliveryRepositoryProvider);
  final includeCompleted = ref.watch(showCompletedPlansProvider);
  final statuses = [
    'open',
    'reconciling',
    'partial',
    if (includeCompleted) 'completed',
  ];

  final plans = <DeliveryPlan>[];
  for (final status in statuses) {
    final result = await repository.list(status: status);
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

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../data/delivery_note_scanner.dart';
import '../data/delivery_repository.dart';
import '../data/mlkit_delivery_note_scanner.dart';
import '../data/remote_delivery_note_scanner.dart';
import '../domain/delivery_plan.dart';
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

/// Delivery plans awaiting a physical check: freshly imported (`open`) plus any
/// already mid-reconciliation, newest first.
final deliveryPlansProvider =
    FutureProvider.autoDispose<List<DeliveryPlan>>((ref) async {
  final repository = ref.watch(deliveryRepositoryProvider);
  final open = await repository.list(status: 'open');
  final reconciling = await repository.list(status: 'reconciling');

  final plans = <DeliveryPlan>[];
  open.when(
    success: plans.addAll,
    failure: (f) => throw Exception(f.message),
  );
  reconciling.when(
    success: plans.addAll,
    failure: (f) => throw Exception(f.message),
  );
  plans.sort((a, b) => b.id.compareTo(a.id));
  return plans;
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

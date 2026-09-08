import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../delivery/application/delivery_providers.dart';
import '../data/dashboard_repository.dart';
import '../domain/dashboard_metrics.dart';

/// Low-stock threshold used by the dashboard watch list (SKUs at or below this
/// on-hand quantity are flagged). Adjustable from the UI.
final lowStockThresholdProvider = StateProvider<int>((_) => 10);

/// Days of history shown in the inbound/outbound trend chart.
const dashboardTrendDays = 14;

final dashboardRepositoryProvider = Provider<DashboardRepository>((ref) {
  // Reuses the Supabase PostgREST Dio (anon key) already configured for stock.
  return DashboardRepositoryImpl(ref.watch(restDioProvider));
});

/// The aggregated home-dashboard figures. Auto-disposes so it refetches each
/// time the dashboard is shown, and re-runs when the threshold changes.
final dashboardMetricsProvider =
    FutureProvider.autoDispose<DashboardMetrics>((ref) async {
  final threshold = ref.watch(lowStockThresholdProvider);
  final result = await ref
      .watch(dashboardRepositoryProvider)
      .metrics(days: dashboardTrendDays, lowThreshold: threshold);
  return result.when(
    success: (data) => data,
    failure: (f) => throw Exception(f.message),
  );
});

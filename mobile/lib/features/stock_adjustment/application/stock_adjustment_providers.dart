import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../data/stock_adjustment_repository.dart';

final stockAdjustmentRepositoryProvider =
    Provider<StockAdjustmentRepository>((ref) {
  return StockAdjustmentRepositoryImpl(ref.watch(dioProvider));
});

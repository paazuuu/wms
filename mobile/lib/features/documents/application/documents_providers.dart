import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../delivery/application/delivery_providers.dart';
import '../../warehouse_context/application/warehouse_providers.dart';
import '../data/documents_repository.dart';
import '../domain/documents.dart';

final documentsRepositoryProvider = Provider<DocumentsRepository>((ref) => DocumentsRepositoryImpl(ref.watch(restDioProvider)));

T _unwrap<T>(dynamic r) => r.when(success: (T d) => d, failure: (f) => throw Exception(f.message));

final documentMatchProvider = FutureProvider.autoDispose.family<DocumentMatch, int>((ref, poId) async =>
    _unwrap<DocumentMatch>(await ref.watch(documentsRepositoryProvider).match(poId)));

final documentExceptionsProvider = FutureProvider.autoDispose<List<DocumentException>>((ref) async =>
    _unwrap<List<DocumentException>>(
        await ref.watch(documentsRepositoryProvider).exceptions(warehouseId: ref.watch(activeWarehouseIdProvider))));

final purchaseOrderInvoicesProvider = FutureProvider.autoDispose.family<List<SupplierInvoice>, int>((ref, poId) async =>
    _unwrap<List<SupplierInvoice>>(await ref.watch(documentsRepositoryProvider).invoices(purchaseOrderId: poId)));

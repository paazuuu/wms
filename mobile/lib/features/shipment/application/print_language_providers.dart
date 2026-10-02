import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_result.dart';
import '../../delivery/application/delivery_providers.dart';
import '../data/print_language_repository.dart';
import '../data/shipment_print.dart';
import '../domain/print_language.dart';

final printLanguageRepositoryProvider = Provider<PrintLanguageRepository>(
    (ref) => PrintLanguageRepositoryImpl(ref.watch(restDioProvider)));

/// The print languages and words (0118). A failure to load falls back to the
/// seeded Japanese + English, so printing never waits on it.
final printLanguageProvider = FutureProvider<PrintLanguage>((ref) async {
  final r = await ref.watch(printLanguageRepositoryProvider).load();
  return switch (r) {
    ApiSuccess(:final data) => data,
    ApiFailure() => const PrintLanguage(),
  };
});

/// A printer set up with the print languages and the names of [jans].
Future<ShipmentPrinter> printerFor(WidgetRef ref, Iterable<String> jans) async {
  final language = await ref.read(printLanguageProvider.future);
  final codes = {for (final j in jans) if (j.trim().isNotEmpty) j}.toList();
  final names = await ref.read(printLanguageRepositoryProvider).namesByJan(codes);
  return ShipmentPrinter(
    language: language,
    namesByJan: switch (names) {
      ApiSuccess(:final data) => data,
      ApiFailure() => const {},
    },
  );
}

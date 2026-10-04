import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_controller.dart';
import '../../delivery/application/delivery_providers.dart';
import '../data/company_repository.dart';
import '../domain/company_profile.dart';

final companyRepositoryProvider = Provider<CompanyRepository>((ref) {
  return CompanyRepositoryImpl(ref.watch(restDioProvider));
});

final companyProfileProvider = FutureProvider.autoDispose<CompanyProfile>((ref) async {
  final r = await ref.watch(companyRepositoryProvider).profile();
  return r.when(success: (d) => d, failure: (f) => throw Exception(f.message));
});

final ownNameSuggestionsProvider = FutureProvider.autoDispose<List<OwnNameSuggestion>>((ref) async {
  final r = await ref.watch(companyRepositoryProvider).suggestions();
  return r.when(success: (d) => d, failure: (_) => const <OwnNameSuggestion>[]);
});

/// Changing our company needs user.manage (company and system admins).
final companyCanEditProvider = Provider<bool>((ref) {
  final p = ref.watch(authControllerProvider).user?.permissions ?? const <String>[];
  return p.contains('user.manage');
});

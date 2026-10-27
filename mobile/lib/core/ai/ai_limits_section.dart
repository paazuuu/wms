import 'package:dio/dio.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/delivery/application/delivery_providers.dart';
import '../../l10n/app_localizations.dart';
import '../api/api_error_mapper.dart';
import '../api/api_error_text.dart';
import '../api/api_result.dart';
import '../theme/app_spacing.dart';

/// Which model reads what, and how much the AI may be used a day (0151).
class AiLimits extends Equatable {
  const AiLimits({
    this.documentModel = 'gemini-3.8-flash',
    this.lightModel = 'gemini-3.1-flash-lite',
    this.dailyLimit = 50,
    this.dailyDocumentLimit = 50,
    this.callsToday = 0,
    this.documentsToday = 0,
  });

  /// For a PDF, a scan or a photo; and for the rest (a sheet's headings, …).
  final String documentModel;
  final String lightModel;

  /// AI calls a day, and documents read a day; null for no limit.
  final int? dailyLimit;
  final int? dailyDocumentLimit;
  final int callsToday;
  final int documentsToday;

  factory AiLimits.fromJson(Map<String, dynamic> j) {
    final today = j['today'] is Map ? (j['today'] as Map).cast<String, dynamic>() : const <String, dynamic>{};
    return AiLimits(
      documentModel: j['document_model']?.toString() ?? 'gemini-3.8-flash',
      lightModel: j['light_model']?.toString() ?? 'gemini-3.1-flash-lite',
      dailyLimit: (j['daily_limit'] as num?)?.toInt(),
      dailyDocumentLimit: (j['daily_document_limit'] as num?)?.toInt(),
      callsToday: (today['calls'] as num?)?.toInt() ?? 0,
      documentsToday: (today['documents'] as num?)?.toInt() ?? 0,
    );
  }

  @override
  List<Object?> get props => [documentModel, lightModel, dailyLimit, dailyDocumentLimit, callsToday, documentsToday];
}

/// The models offered, strongest first, with what each is for.
const aiModelChoices = [
  'gemini-3.8-flash',
  'gemini-3.5-flash',
  'gemini-3.5-flash-lite',
  'gemini-3.1-flash-lite',
];

abstract class AiLimitsRepository {
  Future<ApiResult<AiLimits>> load();
  Future<ApiResult<AiLimits>> save(AiLimits l);
}

class AiLimitsRepositoryImpl implements AiLimitsRepository {
  AiLimitsRepositoryImpl(this._dio);

  final Dio _dio;

  Future<ApiResult<AiLimits>> _call(String rpc, Map<String, dynamic> body) async {
    try {
      final r = await _dio.post('/rpc/$rpc', data: body);
      final d = r.data is List && (r.data as List).isNotEmpty ? (r.data as List).first : r.data;
      return ApiSuccess(AiLimits.fromJson((d as Map).cast<String, dynamic>()));
    } on DioException catch (e) {
      return mapDioError<AiLimits>(e);
    }
  }

  @override
  Future<ApiResult<AiLimits>> load() => _call('get_ai_settings', const {});

  @override
  Future<ApiResult<AiLimits>> save(AiLimits l) => _call('set_ai_limits', {
        'p_document_model': l.documentModel,
        'p_light_model': l.lightModel,
        'p_daily_limit': l.dailyLimit,
        'p_daily_document_limit': l.dailyDocumentLimit,
      });
}

final aiLimitsRepositoryProvider = Provider<AiLimitsRepository>((ref) => AiLimitsRepositoryImpl(ref.watch(restDioProvider)));

final aiLimitsProvider = FutureProvider.autoDispose<AiLimits>((ref) async {
  final r = await ref.watch(aiLimitsRepositoryProvider).load();
  return r.when(success: (d) => d, failure: (f) => throw Exception(f.message));
});

/// AI設定's models and daily limits, with today's use beside them.
class AiLimitsSection extends ConsumerStatefulWidget {
  const AiLimitsSection({super.key});

  @override
  ConsumerState<AiLimitsSection> createState() => _AiLimitsSectionState();
}

class _AiLimitsSectionState extends ConsumerState<AiLimitsSection> {
  String? _doc;
  String? _light;
  final _daily = TextEditingController();
  final _docs = TextEditingController();
  bool _filled = false;
  bool _busy = false;

  @override
  void dispose() {
    _daily.dispose();
    _docs.dispose();
    super.dispose();
  }

  int? _limit(TextEditingController c) => c.text.trim().isEmpty ? null : int.tryParse(c.text.trim());

  Future<void> _save(AiLimits now) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    final r = await ref.read(aiLimitsRepositoryProvider).save(AiLimits(
          documentModel: _doc ?? now.documentModel,
          lightModel: _light ?? now.lightModel,
          dailyLimit: _limit(_daily),
          dailyDocumentLimit: _limit(_docs),
        ));
    if (!mounted) return;
    setState(() => _busy = false);
    switch (r) {
      case ApiSuccess():
        ref.invalidate(aiLimitsProvider);
        messenger.showSnackBar(SnackBar(content: Text(l10n.aiSaved)));
      case ApiFailure(:final message):
        messenger.showSnackBar(SnackBar(content: Text(humanizeApiErrorMessage(l10n, message))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    final async = ref.watch(aiLimitsProvider);
    final now = async.valueOrNull;
    if (now == null) {
      return async.hasError
          ? Text(humanizeApiErrorMessage(l10n, '${async.error}'), style: TextStyle(color: theme.colorScheme.error))
          : const LinearProgressIndicator();
    }
    if (!_filled) {
      _filled = true;
      _daily.text = now.dailyLimit?.toString() ?? '';
      _docs.text = now.dailyDocumentLimit?.toString() ?? '';
    }
    Widget model(String key, String label, String hint, String value, ValueChanged<String> onChanged) {
      final choices = {...aiModelChoices, value}.toList();
      return DropdownButtonFormField<String>(
        key: ValueKey(key),
        initialValue: value,
        isExpanded: true,
        decoration: InputDecoration(labelText: label, helperText: hint, helperMaxLines: 3),
        items: [for (final m in choices) DropdownMenuItem(value: m, child: Text(aiModelLabel(l10n, m)))],
        onChanged: (v) => v == null ? null : setState(() => onChanged(v)),
      );
    }

    return Card(
      key: const ValueKey('ai-limits'),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(l10n.aiLimitsTitle, style: theme.textTheme.titleMedium),
          const SizedBox(height: AppSpacing.xs),
          Text(l10n.aiLimitsIntro, style: muted),
          const SizedBox(height: AppSpacing.md),
          model('ai-document-model', l10n.aiDocumentModel, l10n.aiDocumentModelHint, _doc ?? now.documentModel, (v) => _doc = v),
          const SizedBox(height: AppSpacing.md),
          model('ai-light-model', l10n.aiLightModel, l10n.aiLightModelHint, _light ?? now.lightModel, (v) => _light = v),
          const SizedBox(height: AppSpacing.md),
          Wrap(spacing: AppSpacing.md, runSpacing: AppSpacing.md, children: [
            SizedBox(
              width: 260,
              child: TextField(
                key: const ValueKey('ai-daily-limit'),
                controller: _daily,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: l10n.aiDailyLimit,
                  helperText: l10n.aiUsedToday(now.callsToday),
                  hintText: l10n.aiNoLimit,
                ),
              ),
            ),
            SizedBox(
              width: 260,
              child: TextField(
                key: const ValueKey('ai-document-limit'),
                controller: _docs,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: l10n.aiDocumentLimit,
                  helperText: l10n.aiUsedToday(now.documentsToday),
                  hintText: l10n.aiNoLimit,
                ),
              ),
            ),
          ]),
          const SizedBox(height: AppSpacing.xs),
          Text(l10n.aiLimitsHint, style: muted),
          const SizedBox(height: AppSpacing.md),
          FilledButton.icon(
            key: const ValueKey('ai-limits-save'),
            onPressed: _busy ? null : () => _save(now),
            icon: const Icon(Icons.save_outlined),
            label: Text(l10n.actionSave),
          ),
        ]),
      ),
    );
  }
}

/// A model by name, with how strong and how dear it is.
String aiModelLabel(AppLocalizations l10n, String m) => switch (m) {
      'gemini-3.8-flash' => l10n.aiModelStrong(m),
      'gemini-3.5-flash' => l10n.aiModelMiddle(m),
      'gemini-3.5-flash-lite' || 'gemini-3.1-flash-lite' => l10n.aiModelLight(m),
      _ => m,
    };

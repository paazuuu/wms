import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../l10n/app_localizations.dart';
import '../api/api_error_text.dart';
import '../api/api_result.dart';
import '../theme/app_spacing.dart';
import 'ai_health_screen.dart';
import 'ai_keys.dart';

String aiKeyTierLabel(AppLocalizations l10n, AiKeyTier t) => switch (t) {
      AiKeyTier.free => l10n.akTierFree,
      AiKeyTier.paid => l10n.akTierPaid,
      AiKeyTier.unknown => l10n.akTierUnknown,
    };

/// Gemini APIキー on 管理 → AI設定 (0137): register keys, choose the one the AI
/// is called with — or the server's GEMINI_API_KEY — try one before using it,
/// and retire one. The key is never shown again after it is saved.
class AiKeysSection extends ConsumerWidget {
  const AiKeysSection({super.key});

  void _snack(BuildContext context, String text, {bool error = false}) {
    // Replace, not queue: "testing…" must give way to the result at once.
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(text),
        backgroundColor: error ? Theme.of(context).colorScheme.error : null,
      ));
  }

  Future<void> _activate(BuildContext context, WidgetRef ref, int? id) async {
    final l10n = AppLocalizations.of(context);
    final r = await ref.read(aiKeyRepositoryProvider).activate(id);
    if (!context.mounted) return;
    switch (r) {
      case ApiSuccess():
        ref.invalidate(aiKeysProvider);
        _snack(context, l10n.akSwitched);
      case ApiFailure(:final message):
        _snack(context, humanizeApiErrorMessage(l10n, message), error: true);
    }
  }

  Future<void> _test(BuildContext context, WidgetRef ref, int? id) async {
    final l10n = AppLocalizations.of(context);
    _snack(context, l10n.akTesting);
    final r = await ref.read(aiKeyRepositoryProvider).test(id);
    if (!context.mounted) return;
    ref.invalidate(aiKeysProvider);
    switch (r) {
      case ApiSuccess(:final data):
        _snack(
            context,
            data.ok
                ? l10n.ahPingOk(data.latencyMs, data.model)
                : l10n.ahPingFailed(aiErrorKindLabel(l10n, data.errorKind)),
            error: !data.ok);
      case ApiFailure(:final message):
        _snack(context, humanizeApiErrorMessage(l10n, message), error: true);
    }
  }

  Future<void> _retire(BuildContext context, WidgetRef ref, AiApiKey k) async {
    final l10n = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(l10n.akRetireQ(k.label)),
        content: Text(k.isActive ? l10n.akRetireActiveBody : l10n.akRetireBody),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: Text(l10n.actionCancel)),
          FilledButton(
            key: const ValueKey('ak-retire-confirm'),
            onPressed: () => Navigator.pop(c, true),
            child: Text(l10n.actionDelete),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    final r = await ref.read(aiKeyRepositoryProvider).retire(k.id);
    if (!context.mounted) return;
    switch (r) {
      case ApiSuccess():
        ref.invalidate(aiKeysProvider);
        _snack(context, l10n.akRetired);
      case ApiFailure(:final message):
        _snack(context, humanizeApiErrorMessage(l10n, message), error: true);
    }
  }

  Future<void> _edit(BuildContext context, WidgetRef ref, {AiApiKey? key}) async {
    final l10n = AppLocalizations.of(context);
    final saved = await showDialog<bool>(context: context, builder: (_) => _KeyDialog(existing: key));
    if (saved == true && context.mounted) {
      ref.invalidate(aiKeysProvider);
      _snack(context, key == null ? l10n.akAdded : l10n.aiSaved);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final muted = theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant);
    final async = ref.watch(aiKeysProvider);
    final keys = async.valueOrNull;
    final groupValue =
        keys == null ? null : (keys.usingServerKey ? 0 : keys.keys.where((k) => k.isActive).firstOrNull?.id ?? 0);

    Widget status(AiApiKey k) {
      if (k.lastOk == null) return Text(l10n.akNotUsedYet, style: muted);
      if (k.lastOk!) return Text(l10n.akLastOk, style: theme.textTheme.bodySmall?.copyWith(color: scheme.primary));
      return Text(l10n.akLastFailed(aiErrorKindLabel(l10n, k.lastErrorKind)),
          style: theme.textTheme.bodySmall?.copyWith(color: scheme.error));
    }

    return Card(
      key: const ValueKey('ai-keys'),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Icon(Icons.key_outlined),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: Text(l10n.akTitle, style: theme.textTheme.titleMedium)),
              FilledButton.tonalIcon(
                key: const ValueKey('ak-add'),
                onPressed: () => _edit(context, ref),
                icon: const Icon(Icons.add, size: 18),
                label: Text(l10n.akAdd),
              ),
            ]),
            const SizedBox(height: AppSpacing.xs),
            Text(l10n.akIntro, style: muted),
            const SizedBox(height: AppSpacing.md),
            if (async.hasError)
              Text(humanizeApiErrorMessage(l10n, '${async.error}'), style: TextStyle(color: scheme.error))
            else if (keys == null)
              const LinearProgressIndicator()
            else
              RadioGroup<int>(
                groupValue: groupValue,
                onChanged: (v) => _activate(context, ref, v == 0 ? null : v),
                child: Column(children: [
                  ListTile(
                    key: const ValueKey('ak-server'),
                    contentPadding: EdgeInsets.zero,
                    leading: const Radio<int>(value: 0),
                    title: Text(l10n.akServerKey),
                    subtitle: Text(l10n.akServerKeyHint, style: muted),
                    trailing: IconButton(
                      tooltip: l10n.ahPing,
                      icon: const Icon(Icons.network_check),
                      onPressed: keys.usingServerKey ? () => _test(context, ref, null) : null,
                    ),
                  ),
                  for (final k in keys.keys)
                    ListTile(
                      key: ValueKey('ak-key-${k.id}'),
                      contentPadding: EdgeInsets.zero,
                      leading: Radio<int>(value: k.id),
                      title: Wrap(spacing: AppSpacing.sm, crossAxisAlignment: WrapCrossAlignment.center, children: [
                        Text(k.label),
                        Text(k.keyHint ?? '', style: theme.textTheme.bodySmall?.copyWith(fontFamily: AppFonts.mono)),
                        Chip(
                          visualDensity: VisualDensity.compact,
                          label: Text(aiKeyTierLabel(l10n, k.tier), style: theme.textTheme.bodySmall),
                        ),
                        if (k.isActive)
                          Text(l10n.akInUse,
                              style: theme.textTheme.bodySmall
                                  ?.copyWith(color: scheme.primary, fontWeight: FontWeight.w700)),
                      ]),
                      subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(
                          [
                            k.model ?? l10n.akDefaultModel,
                            l10n.akCalls24h(k.calls24h, k.failed24h),
                            if (k.lastUsedAt != null) DateFormat('y/MM/dd HH:mm').format(k.lastUsedAt!),
                          ].join(' · '),
                          style: muted,
                        ),
                        status(k),
                      ]),
                      trailing: PopupMenuButton<String>(
                        key: ValueKey('ak-menu-${k.id}'),
                        onSelected: (v) => switch (v) {
                          'test' => _test(context, ref, k.id),
                          'edit' => _edit(context, ref, key: k),
                          _ => _retire(context, ref, k),
                        },
                        itemBuilder: (_) => [
                          PopupMenuItem(value: 'test', child: Text(l10n.ahPing)),
                          PopupMenuItem(value: 'edit', child: Text(l10n.akEdit)),
                          PopupMenuItem(value: 'retire', child: Text(l10n.actionDelete)),
                        ],
                      ),
                    ),
                ]),
              ),
            const SizedBox(height: AppSpacing.sm),
            Text(l10n.akFreeTierNote, style: muted),
          ],
        ),
      ),
    );
  }
}

/// Registers a key, or changes one: its name, tier, model, or the key itself.
class _KeyDialog extends ConsumerStatefulWidget {
  const _KeyDialog({this.existing});

  final AiApiKey? existing;

  @override
  ConsumerState<_KeyDialog> createState() => _KeyDialogState();
}

class _KeyDialogState extends ConsumerState<_KeyDialog> {
  late final _label = TextEditingController(text: widget.existing?.label ?? '');
  final _key = TextEditingController();
  late final _model = TextEditingController(text: widget.existing?.model ?? '');
  late AiKeyTier _tier = widget.existing?.tier ?? AiKeyTier.unknown;
  bool _activate = true;
  bool _show = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _label.dispose();
    _key.dispose();
    _model.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    final label = _label.text.trim();
    final key = _key.text.trim();
    final isNew = widget.existing == null;
    if (label.isEmpty || (isNew && key.isEmpty)) {
      setState(() => _error = l10n.akNeedLabelKey);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final repo = ref.read(aiKeyRepositoryProvider);
    final ApiResult<Object> r = isNew
        ? await repo.add(label: label, key: key, tier: _tier, model: _model.text.trim(), activate: _activate)
        : await repo.update(widget.existing!.id,
            label: label, tier: _tier, model: _model.text.trim(), newKey: key.isEmpty ? null : key);
    if (!mounted) return;
    switch (r) {
      case ApiSuccess():
        Navigator.pop(context, true);
      case ApiFailure(:final message):
        setState(() {
          _busy = false;
          _error = humanizeApiErrorMessage(l10n, message);
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isNew = widget.existing == null;
    return AlertDialog(
      title: Text(isNew ? l10n.akAdd : l10n.akEdit),
      content: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          TextField(
            key: const ValueKey('ak-label'),
            controller: _label,
            decoration: InputDecoration(labelText: l10n.akLabel, hintText: l10n.akLabelHint),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            key: const ValueKey('ak-key'),
            controller: _key,
            obscureText: !_show,
            autocorrect: false,
            enableSuggestions: false,
            style: const TextStyle(fontFamily: AppFonts.mono),
            decoration: InputDecoration(
              labelText: isNew ? l10n.akKey : l10n.akNewKey,
              helperText: isNew ? l10n.akKeyHelp : l10n.akNewKeyHelp(widget.existing?.keyHint ?? ''),
              helperMaxLines: 3,
              suffixIcon: IconButton(
                icon: Icon(_show ? Icons.visibility_off : Icons.visibility),
                onPressed: () => setState(() => _show = !_show),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          SegmentedButton<AiKeyTier>(
            key: const ValueKey('ak-tier'),
            segments: [
              for (final t in AiKeyTier.values) ButtonSegment(value: t, label: Text(aiKeyTierLabel(l10n, t))),
            ],
            selected: {_tier},
            onSelectionChanged: (s) => setState(() => _tier = s.first),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            key: const ValueKey('ak-model'),
            controller: _model,
            style: const TextStyle(fontFamily: AppFonts.mono),
            decoration: InputDecoration(labelText: l10n.akModel, hintText: l10n.akModelHint),
          ),
          if (isNew)
            CheckboxListTile(
              key: const ValueKey('ak-activate'),
              contentPadding: EdgeInsets.zero,
              value: _activate,
              onChanged: (v) => setState(() => _activate = v ?? false),
              title: Text(l10n.akActivateNow),
            ),
          if (_error != null) Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
        ]),
      ),
      actions: [
        TextButton(onPressed: _busy ? null : () => Navigator.pop(context, false), child: Text(l10n.actionCancel)),
        FilledButton(
          key: const ValueKey('ak-save'),
          onPressed: _busy ? null : _save,
          child: Text(l10n.actionSave),
        ),
      ],
    );
  }
}

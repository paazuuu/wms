import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/ai/ai_confidence.dart';
import '../../../core/api/api_error_text.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/ui/state_views.dart';
import '../../../core/ui/status_pill.dart';
import '../../../l10n/app_localizations.dart';
import '../../partners/application/trading_partner_providers.dart';
import '../../partners/domain/trading_partner.dart';
import '../../product/domain/product.dart';
import '../../product/presentation/product_picker_sheet.dart';
import '../../product_library/application/product_library_providers.dart';
import '../../product_library/domain/product_image.dart';
import '../../product_library/presentation/register_products_sheet.dart';
import '../application/notation_providers.dart';
import '../domain/notation.dart';
import 'notation_labels.dart';
import 'totals_notice.dart';
import 'warning_report.dart';

/// Teaching the system each trading company's way of writing things, before
/// their goods arrive (0105/0106).
///
///   * 事前学習 — a sample Excel, CSV, PDF or photo from one company is read
///     exactly as a real import would read it (headings mapped, read twice by
///     the AI, name and 品番 split, lines matched to our products) but nothing
///     is booked. What went wrong is shown line by line; columns and products
///     can be corrected; then what it showed is taught.
///   * 方言辞書 — every way of writing learned so far, each with its own id.
///   * 列見出し — the column headings known, everyone's and each company's.
///   * 履歴・傾向 — past runs, and per company what its documents get wrong.
class NotationTrainingScreen extends ConsumerWidget {
  const NotationTrainingScreen({super.key, this.pickFile});

  /// Injectable for tests; defaults to the platform picker.
  final Future<PlatformFile?> Function()? pickFile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return DefaultTabController(
      length: 5,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.ntTitle),
          bottom: TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              Tab(key: const ValueKey('nt-tab-train'), text: l10n.ntTabTrain),
              Tab(key: const ValueKey('nt-tab-dialects'), text: l10n.ntTabDialects),
              Tab(key: const ValueKey('nt-tab-columns'), text: l10n.ntTabColumns),
              Tab(key: const ValueKey('nt-tab-history'), text: l10n.ntTabHistory),
              Tab(key: const ValueKey('nt-tab-versions'), text: l10n.ntTabVersions),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _TrainTab(pickFile: pickFile),
            const _DialectsTab(),
            const _ColumnsTab(),
            const _HistoryTab(),
            const _VersionsTab(),
          ],
        ),
      ),
    );
  }
}

/// The companies whose documents can be taught (all active partners).
final _partnersProvider = FutureProvider.autoDispose<List<TradingPartner>>((ref) async {
  final r = await ref.watch(tradingPartnerRepositoryProvider).list();
  return r.when(success: (d) => d, failure: (f) => throw Exception(f.message));
});

class _PartnerDropdown extends ConsumerWidget {
  const _PartnerDropdown({required this.value, required this.onChanged, this.allowAll = false});

  final int? value;
  final ValueChanged<int?> onChanged;
  final bool allowAll;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final partners = ref.watch(_partnersProvider).valueOrNull ?? const <TradingPartner>[];
    final ids = partners.map((p) => p.id).toSet();
    return DropdownButtonFormField<int?>(
      key: ValueKey('nt-partner-${allowAll ? 'filter' : 'train'}'),
      initialValue: ids.contains(value) ? value : null,
      isExpanded: true,
      decoration: InputDecoration(labelText: l10n.ntPartner),
      items: [
        if (allowAll) DropdownMenuItem<int?>(value: null, child: Text(l10n.ntAllPartners)),
        for (final p in partners) DropdownMenuItem<int?>(value: p.id, child: Text(p.name)),
      ],
      onChanged: onChanged,
    );
  }
}

// ---------------------------------------------------------------------------
// 事前学習
// ---------------------------------------------------------------------------

class _TrainTab extends ConsumerStatefulWidget {
  const _TrainTab({this.pickFile});

  final Future<PlatformFile?> Function()? pickFile;

  @override
  ConsumerState<_TrainTab> createState() => _TrainTabState();
}

class _TrainTabState extends ConsumerState<_TrainTab> with AutomaticKeepAliveClientMixin {
  int? _partnerId;
  PlatformFile? _file;
  bool _busy = false;
  TrainingRead? _read;

  /// Columns corrected by hand since the last read.
  final Map<int, ColumnChoice> _overrides = {};

  @override
  bool get wantKeepAlive => true;

  void _snack(String m, {bool danger = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(m),
        backgroundColor: danger ? Theme.of(context).colorScheme.error : null,
      ));
  }

  Future<void> _pick() async {
    final f = widget.pickFile != null
        ? await widget.pickFile!()
        : (await FilePicker.platform.pickFiles(
            withData: true,
            type: FileType.custom,
            allowedExtensions: const ['xlsx', 'xlsm', 'xls', 'csv', 'pdf', 'jpg', 'jpeg', 'png', 'webp'],
          ))
            ?.files
            .firstOrNull;
    if (f != null) setState(() => _file = f);
  }

  Future<void> _readFile() async {
    final l10n = AppLocalizations.of(context);
    final f = _file;
    if (_partnerId == null) {
      _snack(l10n.ntChoosePartner, danger: true);
      return;
    }
    if (f == null || f.bytes == null) {
      _snack(l10n.ntChooseFile, danger: true);
      return;
    }
    setState(() => _busy = true);
    final r = await ref.read(notationRepositoryProvider).readSample(
          partnerId: _partnerId!,
          file: MultipartFile.fromBytes(f.bytes!, filename: f.name),
          overrides: Map.of(_overrides),
          columnHeaders: {for (final c in _read?.columns ?? const <ReadColumn>[]) c.index: c.header},
        );
    if (!mounted) return;
    setState(() => _busy = false);
    r.when(
      success: (read) {
        setState(() {
          _read = read;
          _overrides.clear();
        });
        ref.invalidate(trainingRunsProvider);
        ref.invalidate(trainingStatsProvider);
      },
      failure: (e) => _snack(humanizeApiErrorMessage(l10n, e.message), danger: true),
    );
  }

  Future<void> _pickProduct(ReadLineResult line) async {
    final l10n = AppLocalizations.of(context);
    final p = await showModalBottomSheet<Product>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => ProductPickerSheet(
        initialQuery: line.productCode ?? line.productName ?? line.rawJanCode ?? '',
        subtitle: l10n.qcSupplierNotation(_writing(line)),
      ),
    );
    if (p == null || !mounted || _read == null) return;
    setState(() {
      _read = _read!.copyWith(lines: [
        for (final l in _read!.lines)
          if (identical(l, line))
            l.withProduct(ResolvedProduct(
                id: p.id, janCode: p.janCode, name: p.name, sku: p.sku, maker: p.maker))
          else
            l,
      ]);
    });
  }

  static String _janOf(ReadLineResult l) => normalizeJanKey(l.janCode.isEmpty ? l.rawJanCode : l.janCode);

  /// Lines no product answers to yet that carry a JAN: they can become
  /// products in our format (0111).
  List<ReadLineResult> get _registrable => [
        for (final l in _read?.lines ?? const <ReadLineResult>[])
          if (!l.resolved && const {8, 13}.contains(_janOf(l).length)) l,
      ];

  Future<void> _registerProducts() async {
    final l10n = AppLocalizations.of(context);
    if (_read == null) return;
    final created = await showRegisterProductsSheet(
      context,
      partnerId: _partnerId,
      lines: [for (final l in _registrable) l.toProposeJson()],
    );
    if (created.isEmpty || !mounted || _read == null) return;
    final byRow = {for (final c in created) c.row: c};
    final byJan = {for (final c in created) normalizeJanKey(c.janCode): c};
    ReadLineResult tie(ReadLineResult l) {
      final c = l.resolved ? null : (byRow[l.row] ?? byJan[_janOf(l)]);
      return c == null ? l : l.withProduct(ResolvedProduct(id: c.productId, janCode: c.janCode, name: c.name, maker: l.maker));
    }

    setState(() => _read = _read!.copyWith(lines: [for (final l in _read!.lines) tie(l)]));
    ref.invalidate(dialectsProvider);
    _snack(l10n.rpRegistered(created.length));
  }

  Future<void> _learn() async {
    final l10n = AppLocalizations.of(context);
    final read = _read;
    if (read == null || _partnerId == null) return;
    setState(() => _busy = true);
    final r = await ref.read(notationRepositoryProvider).learn(
          partnerId: _partnerId!,
          trainingId: read.trainingId,
          lines: read.lines,
          columns: read.columns,
        );
    if (!mounted) return;
    setState(() => _busy = false);
    r.when(
      success: (res) {
        _snack([
          l10n.ntLearned(res.learned, res.added, res.conflicts),
          if (res.profiles > 0 || res.attributes > 0) l10n.ntLearnedLibrary(res.profiles, res.attributes),
        ].join('\n'));
        setState(() {
          _read = null;
          _file = null;
        });
        ref.invalidate(trainingRunsProvider);
        ref.invalidate(trainingStatsProvider);
        ref.invalidate(dialectsProvider);
        ref.invalidate(columnAliasesProvider);
      },
      failure: (e) => _snack(humanizeApiErrorMessage(l10n, e.message), danger: true),
    );
  }

  Future<void> _discard() async {
    final id = _read?.trainingId;
    if (id != null) await ref.read(notationRepositoryProvider).discard(id);
    if (!mounted) return;
    setState(() {
      _read = null;
      _overrides.clear();
    });
    ref.invalidate(trainingRunsProvider);
    ref.invalidate(trainingStatsProvider);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final read = _read;
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              Text(l10n.ntTrainIntro,
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
              const SizedBox(height: AppSpacing.md),
              _PartnerDropdown(
                value: _partnerId,
                onChanged: (v) => setState(() {
                  _partnerId = v;
                  _read = null;
                }),
              ),
              // How this company's documents are laid out, in plain words (0114).
              if (_partnerId != null && ref.watch(productLibraryCanManageProvider)) ...[
                const SizedBox(height: AppSpacing.sm),
                _ReadingNotes(key: ValueKey('nt-notes-$_partnerId'), partnerId: _partnerId!),
              ],
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      key: const ValueKey('nt-pick'),
                      onPressed: _busy ? null : _pick,
                      icon: const Icon(Icons.attach_file),
                      label: Text(_file?.name ?? l10n.ntPickFile, overflow: TextOverflow.ellipsis),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  FilledButton.icon(
                    key: const ValueKey('nt-read'),
                    onPressed: _busy ? null : _readFile,
                    icon: const Icon(Icons.auto_awesome),
                    label: Text(_overrides.isEmpty ? l10n.ntRead : l10n.ntReread),
                  ),
                ],
              ),
              if (_busy) ...[
                const SizedBox(height: AppSpacing.md),
                const LinearProgressIndicator(),
                const SizedBox(height: AppSpacing.xs),
                Text(l10n.ntReading, style: theme.textTheme.bodySmall),
              ],
              if (read != null) ...[
                const SizedBox(height: AppSpacing.lg),
                _Summary(read: read),
                if (read.totals != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  TotalsNotice(
                    totals: read.totals!,
                    onReport: () => showWarningReport(context, ref,
                        flag: 'total_mismatch', partnerId: _partnerId, line: read.totals!.toJson()),
                  ),
                ],
                if (_registrable.isNotEmpty && ref.watch(productLibraryCanManageProvider)) ...[
                  const SizedBox(height: AppSpacing.sm),
                  OutlinedButton.icon(
                    key: const ValueKey('nt-register-products'),
                    onPressed: _busy ? null : _registerProducts,
                    icon: const Icon(Icons.library_add_outlined),
                    label: Text(l10n.rpOpen(_registrable.length)),
                  ),
                ],
                const SizedBox(height: AppSpacing.lg),
                _ColumnsCard(
                  columns: read.columns,
                  overrides: _overrides,
                  onChange: (i, f) => setState(() {
                    if (f == null) {
                      _overrides.remove(i);
                    } else {
                      _overrides[i] = f;
                    }
                  }),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(l10n.ntLinesTitle(read.lines.length), style: theme.textTheme.titleSmall),
                const SizedBox(height: AppSpacing.sm),
                for (final line in read.lines)
                  _LineCard(
                    line: line,
                    onPick: _busy ? null : () => _pickProduct(line),
                    verified: read.verified,
                    spreadsheet: read.source != 'gemini',
                    onReport: (f) => showWarningReport(context, ref,
                        flag: f, partnerId: _partnerId, line: {...line.toProposeJson(), 'flags': line.flags}),
                  ),
              ],
            ],
          ),
        ),
        if (read != null)
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Row(
                children: [
                  TextButton(
                    key: const ValueKey('nt-discard'),
                    onPressed: _busy ? null : _discard,
                    child: Text(l10n.ntDiscard),
                  ),
                  const Spacer(),
                  FilledButton.icon(
                    key: const ValueKey('nt-learn'),
                    onPressed: _busy || read.resolvedCount == 0 ? null : _learn,
                    icon: const Icon(Icons.school_outlined),
                    label: Text(l10n.ntLearn(read.resolvedCount)),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// How the company wrote a line, in one string.
String _writing(ReadLineResult l) => [
      if (l.rawJanCode != null) 'JAN ${l.rawJanCode}',
      if (l.maker != null) l.maker!,
      if (l.productName != null) l.productName!,
      if (l.productCode != null) l.productCode!,
    ].join(' · ');

class _Summary extends StatelessWidget {
  const _Summary({required this.read});

  final TrainingRead read;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final flags = read.flagCounts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xs,
              children: [
                StatusPill(
                    key: const ValueKey('nt-summary-lines'),
                    tone: StatusTone.neutral,
                    label: l10n.ntSummaryLines(read.lines.length),
                    dense: true),
                StatusPill(
                    key: const ValueKey('nt-summary-resolved'),
                    tone: read.resolvedCount == read.lines.length ? StatusTone.success : StatusTone.info,
                    label: l10n.ntSummaryResolved(read.resolvedCount, read.lines.length),
                    dense: true),
                if (read.reviewCount > 0)
                  StatusPill(
                      key: const ValueKey('nt-summary-review'),
                      tone: StatusTone.warning,
                      label: l10n.ntSummaryReview(read.reviewCount),
                      dense: true),
                StatusPill(
                    tone: read.verified ? StatusTone.success : StatusTone.warning,
                    icon: Icons.fact_check_outlined,
                    label: switch (read.source) {
                      'gemini' => read.verified ? l10n.ntReadTwice : l10n.ntReadOnce,
                      'pdf_text' => l10n.ntReadPdfText,
                      _ => l10n.ntReadSheet,
                    },
                    dense: true),
              ],
            ),
            if (flags.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.md),
              Text(l10n.ntErrorsTitle, style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: AppSpacing.xs),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.xs,
                children: [
                  for (final e in flags)
                    StatusPill(
                      tone: NotationFlag.isProblem(e.key) ? StatusTone.warning : StatusTone.neutral,
                      label: '${flagLabel(AppLocalizations.of(context), e.key)} ${e.value}',
                      dense: true,
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ColumnsCard extends ConsumerWidget {
  const _ColumnsCard({required this.columns, required this.overrides, required this.onChange});

  final List<ReadColumn> columns;
  final Map<int, ColumnChoice> overrides;
  final void Function(int index, ColumnChoice? choice) onChange;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    if (columns.isEmpty) return const SizedBox.shrink();
    // Our product attributes (0110): a column can hold one of them.
    final attrs = ref.watch(productAttributesProvider).valueOrNull ?? const <ProductAttributeDef>[];
    final attrName = {for (final a in attrs) a.key: a.name};
    final fieldNames = ref.watch(customFieldLabelsProvider(Localizations.localeOf(context).languageCode));
    String label(ColumnChoice c) => c.field == ColumnField.multi && c.parts.length < 2
        ? l10n.ntFieldMultiPick
        : choiceLabel(l10n, c, attributeNames: attrName, custom: fieldNames);
    final choices = <ColumnChoice>[
      for (final f in ColumnField.values)
        if (f != ColumnField.attr) ColumnChoice(f),
      for (final a in attrs)
        if (a.active) ColumnChoice.attr(a.key),
    ];
    // A combined cell: which fields, in what order, split by what (0114).
    Future<void> pickParts(ReadColumn c, ColumnChoice? current) async {
      final picked = await showDialog<ColumnChoice>(
        context: context,
        builder: (_) => _PartsDialog(
          header: c.header,
          initial: current?.field == ColumnField.multi && current!.parts.length >= 2 ? current : null,
          fieldNames: fieldNames,
        ),
      );
      if (picked != null) onChange(c.index, picked == c.choice ? null : picked);
    }
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.ntColumnsTitle, style: theme.textTheme.titleSmall),
            Text(l10n.ntColumnsHint,
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            const SizedBox(height: AppSpacing.sm),
            for (final c in columns)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(c.header.isEmpty ? l10n.ntNoHeader : c.header,
                              style: theme.textTheme.bodyMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
                          Text(
                            [
                              columnSourceLabel(l10n, overrides.containsKey(c.index) ? 'override' : c.source),
                              if (c.conflict) l10n.ntAiThinks(columnFieldLabel(l10n, c.aiField, fieldNames)),
                            ].join(' · '),
                            style: theme.textTheme.bodySmall?.copyWith(
                                color: c.conflict ? theme.colorScheme.error : theme.colorScheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      flex: 2,
                      child: Builder(builder: (context) {
                        final current = overrides[c.index] ?? c.choice;
                        return DropdownButton<ColumnChoice?>(
                          key: ValueKey('nt-col-${c.index}'),
                          isExpanded: true,
                          value: current,
                          items: [
                            DropdownMenuItem<ColumnChoice?>(value: null, child: Text(l10n.ntFieldUnknown)),
                            for (final ch in choices)
                              DropdownMenuItem<ColumnChoice?>(value: ch, child: Text(label(ch))),
                            // An attribute not (yet) in the list, or a combined
                            // cell with its parts, still shows.
                            if (current != null && !choices.contains(current))
                              DropdownMenuItem<ColumnChoice?>(value: current, child: Text(label(current))),
                          ],
                          onChanged: (ch) {
                            if (ch?.field == ColumnField.multi) {
                              pickParts(c, current);
                              return;
                            }
                            onChange(c.index, ch == c.choice ? null : ch);
                          },
                        );
                      }),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _LineCard extends StatelessWidget {
  const _LineCard({required this.line, this.onPick, this.verified = true, this.spreadsheet = false, this.onReport});

  final ReadLineResult line;
  final VoidCallback? onPick;

  /// Says whether a warning on the line was right (0113).
  final ValueChanged<String>? onReport;
  final bool verified;
  final bool spreadsheet;

  Map<String, double> get _confidence => lineConfidence(
        line.flags,
        verified: verified,
        spreadsheet: spreadsheet,
        hasJan: line.rawJanCode != null || line.janCode.isNotEmpty,
        hasProduct: line.product != null,
      );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final p = line.product;
    return Card(
      key: ValueKey('nt-line-${line.row}'),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Ours, or that there is none yet.
            Row(
              children: [
                Expanded(
                  child: p == null
                      ? Text(l10n.ntNotMatched, style: theme.textTheme.titleSmall?.copyWith(color: scheme.error))
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(p.name, style: theme.textTheme.titleSmall),
                            Text(
                              [p.janCode, if (p.sku != null) l10n.qcOwnSku(p.sku!), if (p.maker != null) p.maker!]
                                  .join(' · '),
                              style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                            ),
                          ],
                        ),
                ),
                if (line.quantity > 0) Text(l10n.dashUnitsCount(line.quantity)),
                TextButton(
                  key: ValueKey('nt-pick-product-${line.row}'),
                  onPressed: onPick,
                  child: Text(p == null ? l10n.ntChooseProduct : l10n.ntChangeProduct),
                ),
              ],
            ),
            // The company's own writing, faded.
            Text(
              l10n.qcSupplierNotation(_writing(line)),
              key: ValueKey('nt-writing-${line.row}'),
              style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant.withValues(alpha: 0.55)),
            ),
            if (line.rawNameCode != null)
              Text(l10n.ntSplitFrom(line.rawNameCode!),
                  style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant.withValues(alpha: 0.55))),
            // Its attributes as the company wrote them (0110), learned onto
            // the product in the product library.
            if (line.attributes.isNotEmpty)
              Padding(
                key: ValueKey('nt-attrs-${line.row}'),
                padding: const EdgeInsets.only(top: 2),
                child: Wrap(spacing: AppSpacing.xs, runSpacing: AppSpacing.xs, children: [
                  for (final a in line.attributes)
                    StatusPill(tone: StatusTone.info, label: '${a.name}: ${a.value}', dense: true),
                ]),
              ),
            if (p != null)
              Text(matchedByLabel(l10n, line.matchedBy),
                  style: theme.textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant)),
            if (line.flags.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.xs),
              Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xs,
                children: [
                  for (final f in line.flags)
                    if (f != 'unresolved')
                      // A warning can be said to be right or wrong (0113).
                      InkWell(
                        key: ValueKey('nt-flag-${line.row}-$f'),
                        onTap: onReport == null || !NotationFlag.isWarning(f) ? null : () => onReport!(f),
                        child: StatusPill(
                          tone: NotationFlag.isWarning(f) ? StatusTone.warning : StatusTone.neutral,
                          label: flagLabel(l10n, f),
                          dense: true,
                        ),
                      ),
                ],
              ),
            ],
            for (final e in line.alternatives.entries)
              Text(l10n.ntOtherReading(alternativeLabel(l10n, e.key), e.value ?? '—'),
                  style: theme.textTheme.bodySmall?.copyWith(color: scheme.tertiary)),
            // How sure the reading is, field by field (§50).
            Padding(
              key: ValueKey('nt-confidence-${line.row}'),
              padding: const EdgeInsets.only(top: AppSpacing.xs),
              child: Row(children: [
                AiBandPill(confidence: _confidence),
                const SizedBox(width: AppSpacing.sm),
                Expanded(child: AiConfidenceRow(confidence: _confidence)),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 方言辞書
// ---------------------------------------------------------------------------

class _DialectsTab extends ConsumerWidget {
  const _DialectsTab();

  Future<void> _act(BuildContext context, WidgetRef ref, Future<dynamic> Function() op) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final r = await op();
    r.when(
      success: (_) => ref.invalidate(dialectsProvider),
      failure: (f) => messenger.showSnackBar(SnackBar(content: Text(humanizeApiErrorMessage(l10n, f.message)))),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final field = ref.watch(dialectFieldProvider);
    final repo = ref.read(notationRepositoryProvider);
    final fieldNames = ref.watch(customFieldLabelsProvider(Localizations.localeOf(context).languageCode));
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        Text(l10n.ntDialectsIntro,
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        const SizedBox(height: AppSpacing.md),
        _PartnerDropdown(
          value: ref.watch(dialectPartnerProvider),
          allowAll: true,
          onChanged: (v) => ref.read(dialectPartnerProvider.notifier).state = v,
        ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          children: [
            for (final f in const [null, 'jan', 'maker', 'name', 'code'])
              ChoiceChip(
                key: ValueKey('nt-dialect-field-${f ?? 'all'}'),
                label: Text(f == null ? l10n.ntAllFields : dialectFieldLabel(l10n, f, fieldNames)),
                selected: field == f,
                onSelected: (_) => ref.read(dialectFieldProvider.notifier).state = f,
              ),
            FilterChip(
              key: const ValueKey('nt-dialect-unconfirmed'),
              label: Text(l10n.ntUnconfirmedOnly),
              selected: ref.watch(dialectUnconfirmedProvider),
              onSelected: (v) => ref.read(dialectUnconfirmedProvider.notifier).state = v,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        TextField(
          key: const ValueKey('nt-dialect-search'),
          decoration: InputDecoration(prefixIcon: const Icon(Icons.search), hintText: l10n.ntDialectSearch),
          onSubmitted: (v) => ref.read(dialectSearchProvider.notifier).state = v,
        ),
        const SizedBox(height: AppSpacing.md),
        ...ref.watch(dialectsProvider).when(
              loading: () => [const LinearProgressIndicator()],
              error: (e, _) => [Text(humanizeApiErrorMessage(l10n, '$e'))],
              data: (rows) => rows.isEmpty
                  ? [Padding(padding: const EdgeInsets.all(AppSpacing.lg), child: Text(l10n.ntDialectsEmpty))]
                  : [
                      for (final d in rows)
                        Card(
                          key: ValueKey('nt-dialect-${d.id}'),
                          child: ListTile(
                            title: Text(d.rawValues.isEmpty ? d.rawValue : d.rawValues.join(' / ')),
                            subtitle: Text([
                              '${d.code} · ${dialectFieldLabel(l10n, d.field, fieldNames)}',
                              '→ ${d.field == 'maker' ? (d.makerName ?? '') : [d.productName, d.productJan].whereType<String>().join(' · ')}',
                              [d.partnerName ?? l10n.ntAllPartners, l10n.ntSeen(d.seenCount)].join(' · '),
                            ].join('\n')),
                            isThreeLine: true,
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (!d.confirmed)
                                  IconButton(
                                    tooltip: l10n.ntConfirm,
                                    icon: const Icon(Icons.check_circle_outline),
                                    onPressed: () => _act(context, ref, () => repo.confirmDialect(d.id)),
                                  )
                                else
                                  Icon(Icons.verified_outlined, color: theme.colorScheme.primary, size: 20),
                                if (d.field != 'maker')
                                  IconButton(
                                    tooltip: l10n.ntChangeProduct,
                                    icon: const Icon(Icons.swap_horiz),
                                    onPressed: () async {
                                      final p = await showModalBottomSheet<Product>(
                                        context: context,
                                        isScrollControlled: true,
                                        showDragHandle: true,
                                        builder: (_) => ProductPickerSheet(
                                            initialQuery: d.rawValue, subtitle: d.rawValue),
                                      );
                                      if (p != null && context.mounted) {
                                        await _act(context, ref, () => repo.confirmDialect(d.id, productId: p.id));
                                      }
                                    },
                                  ),
                                IconButton(
                                  tooltip: l10n.actionDelete,
                                  icon: const Icon(Icons.delete_outline),
                                  onPressed: () => _act(context, ref, () => repo.removeDialect(d.id)),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
            ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// 列見出し
// ---------------------------------------------------------------------------

class _ColumnsTab extends ConsumerWidget {
  const _ColumnsTab();

  Future<void> _add(BuildContext context, WidgetRef ref) async {
    final result = await showDialog<({String header, ColumnField field})>(
      context: context,
      builder: (_) => _AliasDialog(fieldNames: ref.read(customFieldLabelsProvider(Localizations.localeOf(context).languageCode))),
    );
    if (result == null) return;
    final r = await ref.read(notationRepositoryProvider).setColumnAlias(
        partnerId: ref.read(dialectPartnerProvider), header: result.header, field: result.field);
    r.when(success: (_) => ref.invalidate(columnAliasesProvider), failure: (_) {});
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final fieldNames = ref.watch(customFieldLabelsProvider(Localizations.localeOf(context).languageCode));
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        Text(l10n.ntColumnsIntro,
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Expanded(
              child: _PartnerDropdown(
                value: ref.watch(dialectPartnerProvider),
                allowAll: true,
                onChanged: (v) => ref.read(dialectPartnerProvider.notifier).state = v,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            FilledButton.tonalIcon(
              key: const ValueKey('nt-add-column'),
              onPressed: () => _add(context, ref),
              icon: const Icon(Icons.add),
              label: Text(l10n.ntAddColumn),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        ...ref.watch(columnAliasesProvider).when(
              loading: () => [const LinearProgressIndicator()],
              error: (e, _) => [Text(humanizeApiErrorMessage(l10n, '$e'))],
              data: (rows) => [
                for (final a in rows)
                  ListTile(
                    key: ValueKey('nt-alias-${a.id}'),
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(a.header),
                    subtitle: Text('${a.partnerName ?? l10n.ntCommon} · ${columnSourceLabel(l10n, a.isSeed ? 'global' : 'partner')}'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('→ ${a.field == ColumnField.attr ? l10n.ntAttr(a.attributeName ?? '') : a.field == ColumnField.multi ? choiceLabel(l10n, ColumnChoice.multi(a.parts, a.separator), custom: fieldNames) : columnFieldLabel(l10n, a.field, fieldNames)}'),
                        if (!a.isSeed)
                          IconButton(
                            tooltip: l10n.actionDelete,
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () async {
                              await ref.read(notationRepositoryProvider).removeColumnAlias(a.id);
                              ref.invalidate(columnAliasesProvider);
                            },
                          ),
                      ],
                    ),
                  ),
              ],
            ),
      ],
    );
  }
}

/// A heading and what it means. Owns its text controller, so the controller
/// outlives the dialog's closing animation.
class _AliasDialog extends StatefulWidget {
  const _AliasDialog({this.fieldNames = const {}});

  /// The names chosen in the field library (0112).
  final Map<String, String> fieldNames;

  @override
  State<_AliasDialog> createState() => _AliasDialogState();
}

class _AliasDialogState extends State<_AliasDialog> {
  final _header = TextEditingController();
  var _field = ColumnField.productName;

  @override
  void dispose() {
    _header.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.ntAddColumn),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            key: const ValueKey('nt-column-header'),
            controller: _header,
            decoration: InputDecoration(labelText: l10n.ntColumnHeader),
          ),
          DropdownButtonFormField<ColumnField>(
            key: const ValueKey('nt-column-field'),
            initialValue: _field,
            items: [
              for (final f in ColumnField.values)
                if (f != ColumnField.attr) DropdownMenuItem(value: f, child: Text(columnFieldLabel(l10n, f, widget.fieldNames))),
            ],
            onChanged: (v) => setState(() => _field = v ?? _field),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.actionCancel)),
        FilledButton(
          key: const ValueKey('nt-column-save'),
          onPressed: () {
            final h = _header.text.trim();
            if (h.isEmpty) return;
            Navigator.pop(context, (header: h, field: _field));
          },
          child: Text(l10n.actionSave),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// 履歴・傾向
// ---------------------------------------------------------------------------

class _HistoryTab extends ConsumerWidget {
  const _HistoryTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final df = DateFormat('yyyy-MM-dd HH:mm');
    final pct = NumberFormat.percentPattern();
    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(trainingStatsProvider);
        ref.invalidate(trainingRunsProvider);
        ref.invalidate(warningStatsProvider);
      },
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          // Were the warnings right? What the people checking said (0113).
          const _WarningStatsCard(),
          Text(l10n.ntStatsTitle, style: theme.textTheme.titleSmall),
          const SizedBox(height: AppSpacing.sm),
          ...ref.watch(trainingStatsProvider).when(
                loading: () => [const LinearProgressIndicator()],
                error: (e, _) => [Text(humanizeApiErrorMessage(l10n, '$e'))],
                data: (rows) => rows.isEmpty
                    ? [Text(l10n.ntHistoryEmpty)]
                    : [
                        for (final s in rows)
                          Card(
                            key: ValueKey('nt-stats-${s.partnerId}'),
                            child: Padding(
                              padding: const EdgeInsets.all(AppSpacing.md),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(s.partnerName ?? l10n.ntUnknownPartner, style: theme.textTheme.titleSmall),
                                  Text(
                                    l10n.ntStatsLine(s.runs, s.lines,
                                        s.lines == 0 ? '—' : pct.format(s.resolved / s.lines), s.dialects, s.columns),
                                    style: theme.textTheme.bodySmall,
                                  ),
                                  if (s.flags.isNotEmpty) ...[
                                    const SizedBox(height: AppSpacing.xs),
                                    Wrap(
                                      spacing: AppSpacing.xs,
                                      runSpacing: AppSpacing.xs,
                                      children: [
                                        for (final e in (s.flags.entries.toList()
                                          ..sort((a, b) => b.value.compareTo(a.value))))
                                          StatusPill(
                                            tone: NotationFlag.isProblem(e.key)
                                                ? StatusTone.warning
                                                : StatusTone.neutral,
                                            label: '${flagLabel(l10n, e.key)} ${e.value}',
                                            dense: true,
                                          ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                      ],
              ),
          const SizedBox(height: AppSpacing.lg),
          Text(l10n.ntRunsTitle, style: theme.textTheme.titleSmall),
          ...ref.watch(trainingRunsProvider).when(
                loading: () => [const SizedBox.shrink()],
                error: (e, _) => [Text(humanizeApiErrorMessage(l10n, '$e'))],
                data: (rows) => rows.isEmpty
                    ? [
                        SizedBox(
                          height: 200,
                          child: EmptyStateView(icon: Icons.school_outlined, title: l10n.ntHistoryEmpty),
                        ),
                      ]
                    : [
                        for (final r in rows)
                          ListTile(
                            key: ValueKey('nt-run-${r.id}'),
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(r.learned ? Icons.school : Icons.description_outlined),
                            title: Text(r.fileName ?? '#${r.id}'),
                            subtitle: Text([
                              r.partnerName ?? l10n.ntUnknownPartner,
                              if (r.createdAt != null) df.format(r.createdAt!),
                              l10n.ntSummaryResolved(r.resolvedCount, r.lineCount),
                            ].join(' · ')),
                            trailing: StatusPill(
                              tone: r.learned
                                  ? StatusTone.success
                                  : r.status == 'discarded'
                                      ? StatusTone.neutral
                                      : StatusTone.info,
                              label: r.learned
                                  ? l10n.ntStatusLearned
                                  : r.status == 'discarded'
                                      ? l10n.ntStatusDiscarded
                                      : l10n.ntStatusRead,
                              dense: true,
                            ),
                          ),
                      ],
              ),
        ],
      ),
    );
  }
}


// ---------------------------------------------------------------------------
// バージョン (0108, spec §60)
// ---------------------------------------------------------------------------

final _libraryVersionsProvider = FutureProvider.autoDispose.family<List<LibraryVersion>, int>((ref, partnerId) async {
  final r = await ref.watch(notationRepositoryProvider).libraryVersions(partnerId);
  return r.when(success: (d) => d, failure: (f) => throw Exception(f.message));
});

/// Each company's dictionary as numbered versions: taken by hand or each
/// time a sample is learned. Nothing is overwritten; an old version is
/// brought back alongside the current one, so documents in an old format
/// still read.
class _VersionsTab extends ConsumerWidget {
  const _VersionsTab();

  Future<void> _snapshot(BuildContext context, WidgetRef ref, int partnerId) async {
    final l10n = AppLocalizations.of(context);
    final note = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(l10n.ntSnapshot),
        content: TextField(key: const ValueKey('nt-snapshot-note'), controller: note, decoration: InputDecoration(labelText: l10n.ntSnapshotNote)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: Text(l10n.actionCancel)),
          FilledButton(key: const ValueKey('nt-snapshot-save'), onPressed: () => Navigator.pop(c, true), child: Text(l10n.actionSave)),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(notationRepositoryProvider).snapshotLibrary(partnerId, note: note.text.trim().isEmpty ? null : note.text.trim());
    ref.invalidate(_libraryVersionsProvider(partnerId));
  }

  Future<void> _restore(BuildContext context, WidgetRef ref, int partnerId, LibraryVersion v) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final r = await ref.read(notationRepositoryProvider).restoreLibrary(v.id);
    r.when(
      success: (res) {
        messenger.showSnackBar(SnackBar(content: Text(l10n.ntRestored(v.version, res.dialects, res.aliases, res.conflicts))));
        ref.invalidate(_libraryVersionsProvider(partnerId));
        ref.invalidate(dialectsProvider);
        ref.invalidate(columnAliasesProvider);
      },
      failure: (f) => messenger.showSnackBar(SnackBar(content: Text(humanizeApiErrorMessage(l10n, f.message)))),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final partnerId = ref.watch(dialectPartnerProvider);
    final df = DateFormat('yyyy-MM-dd HH:mm');
    String source(String s) => switch (s) {
          'training' => l10n.ntVersionTraining,
          'restore' => l10n.ntVersionRestore,
          _ => l10n.ntVersionManual,
        };
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        Text(l10n.ntVersionsIntro, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        const SizedBox(height: AppSpacing.md),
        Row(children: [
          Expanded(
            child: _PartnerDropdown(
              value: partnerId,
              allowAll: true,
              onChanged: (v) => ref.read(dialectPartnerProvider.notifier).state = v,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          FilledButton.tonalIcon(
            key: const ValueKey('nt-snapshot'),
            onPressed: partnerId == null ? null : () => _snapshot(context, ref, partnerId),
            icon: const Icon(Icons.bookmark_add_outlined),
            label: Text(l10n.ntSnapshot),
          ),
        ]),
        const SizedBox(height: AppSpacing.md),
        if (partnerId == null)
          Text(l10n.ntChoosePartner)
        else
          ...ref.watch(_libraryVersionsProvider(partnerId)).when(
                loading: () => [const LinearProgressIndicator()],
                error: (e, _) => [Text(humanizeApiErrorMessage(l10n, '$e'))],
                data: (rows) => rows.isEmpty
                    ? [Text(l10n.ntNoVersions)]
                    : [
                        for (var i = 0; i < rows.length; i++)
                          Card(
                            key: ValueKey('nt-version-${rows[i].id}'),
                            child: ListTile(
                              leading: CircleAvatar(child: Text('v${rows[i].version}')),
                              title: Text([
                                source(rows[i].source),
                                if (rows[i].note != null) rows[i].note!,
                              ].join(' · ')),
                              subtitle: Text([
                                if (rows[i].createdAt != null) df.format(rows[i].createdAt!.toLocal()),
                                l10n.ntVersionCounts(rows[i].dialectCount, rows[i].aliasCount),
                                if (rows[i].added > 0 || rows[i].removed > 0) '+${rows[i].added} / -${rows[i].removed}',
                              ].join(' · ')),
                              trailing: i == 0
                                  ? StatusPill(tone: StatusTone.success, label: l10n.ntVersionCurrent, dense: true)
                                  : TextButton(
                                      key: ValueKey('nt-restore-${rows[i].id}'),
                                      onPressed: () => _restore(context, ref, partnerId, rows[i]),
                                      child: Text(l10n.ntRestore),
                                    ),
                            ),
                          ),
                      ],
              ),
      ],
    );
  }
}

/// How each kind of warning has fared with the people who checked it: how
/// often it was right, how often wrong, and their latest notes (0113).
class _WarningStatsCard extends ConsumerWidget {
  const _WarningStatsCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final stats = ref.watch(warningStatsProvider).valueOrNull ?? const <WarningStat>[];
    return Card(
      key: const ValueKey('nt-warning-stats'),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(l10n.wrStatsTitle, style: theme.textTheme.titleSmall),
          Text(l10n.wrStatsHint, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          const SizedBox(height: AppSpacing.sm),
          if (stats.isEmpty)
            Text(l10n.wrStatsEmpty, style: theme.textTheme.bodySmall)
          else
            for (final s in stats) ...[
              Row(
                key: ValueKey('nt-warning-stat-${s.flag}'),
                children: [
                  Expanded(child: Text(flagLabel(l10n, s.flag), style: theme.textTheme.bodyMedium)),
                  StatusPill(tone: StatusTone.success, label: l10n.wrRightCount(s.right), dense: true),
                  const SizedBox(width: AppSpacing.xs),
                  StatusPill(tone: s.wrong > 0 ? StatusTone.warning : StatusTone.neutral, label: l10n.wrWrongCount(s.wrong), dense: true),
                ],
              ),
              for (final n in s.notes)
                Padding(
                  padding: const EdgeInsets.only(left: AppSpacing.md, top: 2),
                  child: Text(
                    '${n.verdict == 'wrong' ? '✕' : '✓'} ${n.note}${n.partnerName == null ? '' : '（${n.partnerName}）'}',
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ),
              const SizedBox(height: AppSpacing.xs),
            ],
        ]),
      ),
    );
  }
}

/// Which fields a combined cell holds, in order, and what splits them
/// (0114): "三菱鉛筆／ユニボール エア／UBA20105.24" is メーカー・品名・品番 by ／;
/// "8E ﾐﾂﾋﾞｼ UMR05S.15" is 読まない・メーカー・品番 by spaces.
class _PartsDialog extends StatefulWidget {
  const _PartsDialog({required this.header, this.initial, this.fieldNames = const {}});

  final String header;
  final ColumnChoice? initial;
  final Map<String, String> fieldNames;

  @override
  State<_PartsDialog> createState() => _PartsDialogState();
}

class _PartsDialogState extends State<_PartsDialog> {
  late final List<ColumnField> _parts = [...?widget.initial?.parts];
  late String? _separator = widget.initial?.separator;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final seps = <String?>[null, '／', '/', 'space', '・', '|'];
    return AlertDialog(
      title: Text(l10n.ntPartsTitle(widget.header.isEmpty ? l10n.ntNoHeader : widget.header)),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(l10n.ntPartsHint, style: theme.textTheme.bodySmall),
            const SizedBox(height: AppSpacing.sm),
            // The order chosen so far.
            Wrap(spacing: AppSpacing.xs, runSpacing: AppSpacing.xs, children: [
              for (final (i, p) in _parts.indexed)
                InputChip(
                  key: ValueKey('nt-part-$i'),
                  label: Text('${i + 1}. ${partLabel(l10n, p, widget.fieldNames)}'),
                  onDeleted: () => setState(() => _parts.removeAt(i)),
                ),
              if (_parts.isEmpty) Text(l10n.ntPartsEmpty, style: theme.textTheme.bodySmall),
            ]),
            const SizedBox(height: AppSpacing.md),
            Text(l10n.ntPartsAdd, style: theme.textTheme.labelMedium),
            Wrap(spacing: AppSpacing.xs, runSpacing: AppSpacing.xs, children: [
              for (final f in ColumnChoice.partFields)
                if (f == ColumnField.ignore || !_parts.contains(f))
                  ActionChip(
                    key: ValueKey('nt-part-add-${f.wire}'),
                    label: Text(partLabel(l10n, f, widget.fieldNames)),
                    onPressed: () => setState(() => _parts.add(f)),
                  ),
            ]),
            const SizedBox(height: AppSpacing.md),
            DropdownButtonFormField<String?>(
              key: const ValueKey('nt-part-sep'),
              initialValue: seps.contains(_separator) ? _separator : null,
              decoration: InputDecoration(labelText: l10n.ntSeparator),
              items: [for (final sp in seps) DropdownMenuItem<String?>(value: sp, child: Text(separatorLabel(l10n, sp)))],
              onChanged: (v) => setState(() => _separator = v),
            ),
          ]),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.actionCancel)),
        FilledButton(
          key: const ValueKey('nt-part-save'),
          onPressed: _parts.length < 2 ? null : () => Navigator.pop(context, ColumnChoice.multi([..._parts], _separator)),
          child: Text(l10n.actionSave),
        ),
      ],
    );
  }
}

/// A company's 書式メモ (0114): given to the AI with every document from it
/// — "JANは備考欄", "9A・8Eなどの区分記号は読まない", …
class _ReadingNotes extends ConsumerStatefulWidget {
  const _ReadingNotes({super.key, required this.partnerId});

  final int partnerId;

  @override
  ConsumerState<_ReadingNotes> createState() => _ReadingNotesState();
}

class _ReadingNotesState extends ConsumerState<_ReadingNotes> {
  final _c = TextEditingController();
  bool _filled = false;
  bool _busy = false;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    final r = await ref.read(tradingPartnerRepositoryProvider).setReadingNotes(widget.partnerId, _c.text);
    if (!mounted) return;
    setState(() => _busy = false);
    r.when(
      success: (_) {
        ref.invalidate(_partnersProvider);
        messenger.showSnackBar(SnackBar(content: Text(l10n.ntNotesSaved)));
      },
      failure: (f) => messenger.showSnackBar(SnackBar(content: Text(humanizeApiErrorMessage(l10n, f.message)))),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final partner = (ref.watch(_partnersProvider).valueOrNull ?? const <TradingPartner>[])
        .where((p) => p.id == widget.partnerId)
        .firstOrNull;
    if (partner != null && !_filled) {
      _filled = true;
      _c.text = partner.readingNotes ?? '';
    }
    return ExpansionTile(
      key: const ValueKey('nt-notes'),
      tilePadding: EdgeInsets.zero,
      initiallyExpanded: (partner?.readingNotes ?? '').isNotEmpty,
      title: Text(l10n.ntNotesTitle, style: theme.textTheme.titleSmall),
      subtitle: Text(l10n.ntNotesHint, style: theme.textTheme.bodySmall),
      children: [
        TextField(
          key: const ValueKey('nt-notes-text'),
          controller: _c,
          minLines: 2,
          maxLines: 5,
          maxLength: 2000,
          decoration: InputDecoration(hintText: l10n.ntNotesExample, border: const OutlineInputBorder()),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton.tonal(
            key: const ValueKey('nt-notes-save'),
            onPressed: _busy ? null : _save,
            child: Text(l10n.actionSave),
          ),
        ),
      ],
    );
  }
}

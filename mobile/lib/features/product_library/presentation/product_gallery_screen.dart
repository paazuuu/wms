import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/api/api_error_text.dart';
import '../../../core/api/api_result.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/ui/state_views.dart';
import '../../../core/ui/status_pill.dart';
import '../../../l10n/app_localizations.dart';
import '../application/product_library_providers.dart';
import '../domain/product_image.dart';
import 'product_profile_tabs.dart';

/// A picked picture: its bytes, file name and type.
typedef PickedPicture = ({Uint8List bytes, String name, String contentType});

Future<PickedPicture?> _pickWithPlatform(ImageSource source) async {
  final f = await ImagePicker().pickImage(source: source, maxWidth: 1600, maxHeight: 1600, imageQuality: 85);
  if (f == null) return null;
  final name = f.name.isEmpty ? 'photo.jpg' : f.name;
  final lower = name.toLowerCase();
  final type = lower.endsWith('.png')
      ? 'image/png'
      : lower.endsWith('.webp')
          ? 'image/webp'
          : 'image/jpeg';
  return (bytes: await f.readAsBytes(), name: name, contentType: type);
}

/// One product's pictures (0109), in the order they are shown. The first is
/// the product's face — put in front of its name on the receiving,
/// inspection, putaway, picking and shipping screens. A manager adds
/// pictures (camera or file, optionally straight to the front), drags them
/// into order, makes one the face, or takes one down.
class ProductGalleryScreen extends ConsumerStatefulWidget {
  const ProductGalleryScreen({
    super.key,
    required this.productId,
    this.productName,
    this.janCode,
    this.pickPicture,
    this.initialTab = 0,
  });

  final int productId;
  final String? productName;
  final String? janCode;

  /// 0 写真, 1 属性, 2 仕入先の呼び名.
  final int initialTab;

  /// Injectable for tests; defaults to the camera / photo library.
  final Future<PickedPicture?> Function(ImageSource source)? pickPicture;

  @override
  ConsumerState<ProductGalleryScreen> createState() => _ProductGalleryScreenState();
}

class _ProductGalleryScreenState extends ConsumerState<ProductGalleryScreen> with SingleTickerProviderStateMixin {
  bool _busy = false;
  late final TabController _tabs = TabController(length: 3, vsync: this, initialIndex: widget.initialTab)
    ..addListener(() {
      if (mounted) setState(() {});
    });

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  void _changed() {
    ref.invalidate(productGalleryProvider(widget.productId));
    ref.read(productFaceCacheProvider.notifier).invalidateProduct(widget.productId);
    ref.invalidate(productLibraryProvider);
  }

  Future<void> _run(Future<ApiResult<List<ProductImage>>> Function() call, {String? done}) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    final r = await call();
    if (!mounted) return;
    setState(() => _busy = false);
    r.when(
      success: (_) {
        _changed();
        if (done != null) messenger.showSnackBar(SnackBar(content: Text(done)));
      },
      failure: (f) => messenger.showSnackBar(SnackBar(content: Text(humanizeApiErrorMessage(l10n, f.message)))),
    );
  }

  Future<void> _add() async {
    final l10n = AppLocalizations.of(context);
    var first = false;
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, setSheet) => SafeArea(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            ListTile(
              key: const ValueKey('pl-from-camera'),
              leading: const Icon(Icons.photo_camera_outlined),
              title: Text(l10n.plFromCamera),
              onTap: () => Navigator.pop(c, ImageSource.camera),
            ),
            ListTile(
              key: const ValueKey('pl-from-gallery'),
              leading: const Icon(Icons.photo_library_outlined),
              title: Text(l10n.plFromGallery),
              onTap: () => Navigator.pop(c, ImageSource.gallery),
            ),
            CheckboxListTile(
              key: const ValueKey('pl-put-first'),
              value: first,
              onChanged: (v) => setSheet(() => first = v ?? false),
              title: Text(l10n.plPutFirst),
            ),
          ]),
        ),
      ),
    );
    if (source == null || !mounted) return;
    final picked = await (widget.pickPicture ?? _pickWithPlatform)(source);
    if (picked == null || !mounted) return;
    await _run(
      () => ref.read(productImageRepositoryProvider).upload(
            widget.productId,
            bytes: picked.bytes,
            fileName: picked.name,
            contentType: picked.contentType,
            first: first,
          ),
      done: l10n.plUploaded,
    );
  }

  Future<void> _withdraw(ProductImage image) async {
    final l10n = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        content: Text(l10n.plWithdrawConfirm),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: Text(l10n.actionCancel)),
          FilledButton(key: const ValueKey('pl-withdraw-ok'), onPressed: () => Navigator.pop(c, true), child: Text(l10n.plWithdraw)),
        ],
      ),
    );
    if (ok == true) await _run(() => ref.read(productImageRepositoryProvider).withdraw(image.id));
  }

  void _view(String url) => Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(backgroundColor: Colors.black, foregroundColor: Colors.white, title: Text(widget.productName ?? '')),
          body: Center(child: InteractiveViewer(maxScale: 5, child: Image.network(url, fit: BoxFit.contain))),
        ),
      ));

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final canManage = ref.watch(productLibraryCanManageProvider);
    final async = ref.watch(productGalleryProvider(widget.productId));
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.productName ?? l10n.plGalleryTitle),
        bottom: TabBar(
          controller: _tabs,
          tabs: [
            Tab(key: const ValueKey('pl-tab-photos'), text: l10n.plTabPhotos),
            Tab(key: const ValueKey('pl-tab-attributes'), text: l10n.plTabAttributes),
            Tab(key: const ValueKey('pl-tab-suppliers'), text: l10n.plTabSuppliers),
          ],
        ),
      ),
      floatingActionButton: canManage && _tabs.index == 0
          ? FloatingActionButton.extended(
              key: const ValueKey('pl-add-photo'),
              onPressed: _busy ? null : _add,
              icon: const Icon(Icons.add_a_photo_outlined),
              label: Text(l10n.plAddPhoto),
            )
          : null,
      body: TabBarView(
        controller: _tabs,
        children: [
          _photos(context, async, canManage),
          ProductAttributesTab(productId: widget.productId),
          ProductSuppliersTab(productId: widget.productId),
        ],
      ),
    );
  }

  Widget _photos(BuildContext context, AsyncValue<List<(ProductImage, String?)>> async, bool canManage) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return async.when(
        loading: () => LoadingView(message: l10n.loading),
        error: (e, _) => ErrorStateView(
            message: humanizeApiErrorMessage(l10n, '$e'), onRetry: () => ref.invalidate(productGalleryProvider(widget.productId))),
        data: (rows) {
          final header = Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.sm),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (widget.janCode != null) Text(widget.janCode!, style: theme.textTheme.bodySmall),
              if (_busy) const LinearProgressIndicator(),
              Text(canManage ? l10n.plReorderHint : l10n.plFaceHint,
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            ]),
          );
          if (rows.isEmpty) {
            return Column(children: [header, Expanded(child: EmptyStateView(icon: Icons.photo_outlined, title: l10n.plNoImages))]);
          }
          Widget tile(int i) {
            final (image, url) = rows[i];
            return Card(
              key: ValueKey('pl-image-${image.id}'),
              margin: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.xs),
              child: ListTile(
                contentPadding: const EdgeInsets.all(AppSpacing.sm),
                leading: GestureDetector(
                  onTap: url == null ? null : () => _view(url),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: url == null
                        ? Container(width: 72, height: 72, color: theme.colorScheme.surfaceContainerHighest, child: const Icon(Icons.image_not_supported_outlined))
                        : Image.network(url, width: 72, height: 72, fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(width: 72, height: 72, color: theme.colorScheme.surfaceContainerHighest)),
                  ),
                ),
                title: Row(children: [
                  Text('${image.position}', style: theme.textTheme.titleMedium),
                  const SizedBox(width: AppSpacing.sm),
                  if (image.isFace) StatusPill(tone: StatusTone.success, label: l10n.plFace, dense: true),
                ]),
                subtitle: image.caption == null ? null : Text(image.caption!),
                trailing: canManage
                    ? Row(mainAxisSize: MainAxisSize.min, children: [
                        if (!image.isFace)
                          IconButton(
                            key: ValueKey('pl-make-face-${image.id}'),
                            tooltip: l10n.plMakeFace,
                            icon: const Icon(Icons.vertical_align_top),
                            onPressed: _busy
                                ? null
                                : () => _run(() => ref.read(productImageRepositoryProvider).reorder(
                                      widget.productId,
                                      [image.id, for (final r in rows) if (r.$1.id != image.id) r.$1.id],
                                    )),
                          ),
                        IconButton(
                          key: ValueKey('pl-withdraw-${image.id}'),
                          tooltip: l10n.plWithdraw,
                          icon: const Icon(Icons.delete_outline),
                          onPressed: _busy ? null : () => _withdraw(image),
                        ),
                        ReorderableDragStartListener(index: i, child: const Icon(Icons.drag_handle)),
                      ])
                    : null,
              ),
            );
          }

          if (!canManage) {
            return ListView(padding: const EdgeInsets.only(bottom: 96), children: [header, for (var i = 0; i < rows.length; i++) tile(i)]);
          }
          return Column(children: [
            header,
            Expanded(
              child: ReorderableListView.builder(
                buildDefaultDragHandles: false,
                padding: const EdgeInsets.only(bottom: 96),
                itemCount: rows.length,
                itemBuilder: (_, i) => tile(i),
                onReorderItem: (from, to) {
                  final ids = [for (final r in rows) r.$1.id];
                  final moved = ids.removeAt(from);
                  ids.insert(to, moved);
                  _run(() => ref.read(productImageRepositoryProvider).reorder(widget.productId, ids));
                },
              ),
            ),
          ]);
        },
      );
  }
}

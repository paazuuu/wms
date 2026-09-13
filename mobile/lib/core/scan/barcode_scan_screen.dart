import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../l10n/app_localizations.dart';
import '../theme/app_spacing.dart';
import 'scan_feedback.dart';
import 'scan_session.dart';

/// Builds the camera preview. Injected in tests so the scan pipeline
/// (validation → duplicate suppression → feedback → history) can be driven
/// without a real camera; production passes null and gets [MobileScanner].
typedef ScanCameraBuilder = Widget Function(
    BuildContext context, ValueChanged<String> onCode);

/// The app's one barcode scanning surface (UI spec §11).
///
/// Everything §11 asks for lives here so no feature has to re-invent half of
/// it: camera, torch, vibration, success/error sound, a manual-entry fallback
/// for a damaged label, continuous scanning, duplicate suppression, a scan
/// history and a visible result.
///
/// Two modes, one widget:
/// * single-shot (default) — pops with the accepted code the instant it decodes,
///   with no confirmation step in between (§11: 成功後に不要な確認画面を挟まない).
/// * [continuous] — stays open and reports each accepted code to [onScan], for
///   working through a stack of labels.
///
/// Validation is the caller's: pass [expectedCode] to accept exactly one code
/// (picking's "only the right JAN confirms a quantity", §16), or [validate] for
/// anything richer. A rejected scan sounds the error tone and is listed in the
/// history — it never silently does nothing.
class BarcodeScanScreen extends StatefulWidget {
  const BarcodeScanScreen({
    super.key,
    this.title,
    this.expectedCode,
    this.validate,
    this.continuous = false,
    this.onScan,
    this.allowManualEntry = true,
    this.duplicateWindow = const Duration(seconds: 3),
    this.feedback = const ScanFeedback(),
    this.cameraBuilder,
  });

  /// App-bar title. Defaults to the generic "scan a barcode".
  final String? title;

  /// Accept only this code. Convenience over [validate] for the common
  /// "confirm you are holding the right item" case.
  final String? expectedCode;

  /// Returns null to accept, or the reason to show the operator. Consulted
  /// after [expectedCode].
  final String? Function(String code)? validate;

  /// Keep scanning instead of popping on the first accepted code.
  final bool continuous;

  /// Called with each accepted code. In single-shot mode the screen also pops
  /// with that code, so a caller can use either.
  final void Function(String code)? onScan;

  /// Offer typing the code when the label is unreadable.
  final bool allowManualEntry;

  /// How long the same code is ignored after being accepted.
  ///
  /// The default suits "confirm you are holding the right thing", where a
  /// second read of the same label means nothing. Counting flows (QC receiving,
  /// where one scan *is* one piece and scanning the same JAN twenty times is
  /// the job) should shorten it — but never to zero: the camera re-decodes the
  /// same label many times a second, far faster than a human can deliberately
  /// rescan, so a window of around a second still throws away the camera's
  /// repeats while keeping every real scan.
  final Duration duplicateWindow;

  /// Sound/vibration for each result. Injectable for tests.
  final ScanFeedback feedback;

  /// Test seam for the camera preview.
  final ScanCameraBuilder? cameraBuilder;

  @override
  State<BarcodeScanScreen> createState() => _BarcodeScanScreenState();
}

class _BarcodeScanScreenState extends State<BarcodeScanScreen> {
  MobileScannerController? _controller;
  late final ScanSession _session =
      ScanSession(duplicateWindow: widget.duplicateWindow);
  bool _torchOn = false;

  /// Set while popping so a late camera frame cannot fire a second scan.
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    if (widget.cameraBuilder == null) {
      _controller = MobileScannerController(
        formats: const [
          BarcodeFormat.code128,
          BarcodeFormat.code39,
          BarcodeFormat.ean13,
          BarcodeFormat.qrCode,
        ],
      );
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    final code = capture.barcodes
        .map((b) => b.rawValue)
        .firstWhere((v) => v != null && v.isNotEmpty, orElse: () => null);
    if (code != null) _handleCode(code);
  }

  /// The one path every code takes, whatever produced it — camera or keyboard.
  void _handleCode(String code) {
    if (_closing) return;
    final trimmed = code.trim();
    if (trimmed.isEmpty) return;
    final l10n = AppLocalizations.of(context);

    String? rejection;
    final expected = widget.expectedCode;
    if (expected != null && trimmed != expected.trim()) {
      rejection = l10n.scanWrongItem(expected);
    }
    rejection ??= widget.validate?.call(trimmed);

    final event = _session.register(trimmed, DateTime.now(),
        rejectionMessage: rejection);
    widget.feedback.forOutcome(event.outcome);
    setState(() {});

    if (event.outcome != ScanOutcome.accepted) return;
    widget.onScan?.call(trimmed);
    if (!widget.continuous) {
      _closing = true;
      Navigator.of(context).pop(trimmed);
    }
  }

  Future<void> _toggleTorch() async {
    final controller = _controller;
    if (controller == null) return;
    await controller.toggleTorch();
    if (mounted) setState(() => _torchOn = !_torchOn);
  }

  Future<void> _manualEntry() async {
    final code = await showDialog<String>(
      context: context,
      builder: (_) => const _ManualEntryDialog(),
    );
    if (code == null || !mounted) return;
    _handleCode(code);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final builder = widget.cameraBuilder;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(widget.title ?? l10n.scanBarcode,
            style: const TextStyle(color: Colors.white)),
        actions: [
          if (_controller != null)
            IconButton(
              tooltip: _torchOn ? l10n.torchOff : l10n.torchOn,
              icon: Icon(_torchOn ? Icons.flash_on : Icons.flash_off),
              onPressed: _toggleTorch,
            ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (builder != null)
                  builder(context, _handleCode)
                else
                  MobileScanner(controller: _controller!, onDetect: _onDetect),
                const _ScannerOverlay(),
                Positioned(
                  left: AppSpacing.lg,
                  right: AppSpacing.lg,
                  bottom: AppSpacing.lg,
                  child: Column(
                    children: [
                      Text(
                        widget.expectedCode == null
                            ? l10n.alignBarcode
                            : l10n.scanExpecting(widget.expectedCode!),
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white, fontSize: 15),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Code128 · Code39 · JAN(EAN-13) · QR',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white54, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          _ResultPanel(
            session: _session,
            continuous: widget.continuous,
            onManualEntry: widget.allowManualEntry ? _manualEntry : null,
            onDone: widget.continuous
                ? () => Navigator.of(context).pop(_session.last?.code)
                : null,
          ),
        ],
      ),
    );
  }
}

/// The visible half of §11: the last result, the running history, and the
/// fallbacks. Dark by design — it sits under a camera view, not on a page.
class _ResultPanel extends StatelessWidget {
  const _ResultPanel({
    required this.session,
    required this.continuous,
    this.onManualEntry,
    this.onDone,
  });

  final ScanSession session;
  final bool continuous;
  final VoidCallback? onManualEntry;
  final VoidCallback? onDone;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final last = session.last;

    return Container(
      width: double.infinity,
      color: const Color(0xFF111827),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (last == null)
                Text(l10n.scanNothingYet,
                    style: const TextStyle(color: Colors.white54, fontSize: 13))
              else
                _ResultLine(event: last, prominent: true),
              if (continuous) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(l10n.scanAcceptedCount(session.acceptedCount),
                    style:
                        const TextStyle(color: Colors.white70, fontSize: 12)),
                // History, most recent first, minus the line already shown big.
                for (final event in session.history.skip(1).take(4))
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: _ResultLine(event: event, prominent: false),
                  ),
              ],
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  if (onManualEntry != null)
                    Expanded(
                      child: SizedBox(
                        height: AppSpacing.minTouch,
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: const BorderSide(color: Colors.white38),
                          ),
                          onPressed: onManualEntry,
                          icon: const Icon(Icons.keyboard_alt_outlined),
                          label: Text(l10n.scanManualEntry),
                        ),
                      ),
                    ),
                  if (onManualEntry != null && onDone != null)
                    const SizedBox(width: AppSpacing.md),
                  if (onDone != null)
                    Expanded(
                      child: SizedBox(
                        height: AppSpacing.minTouch,
                        child: FilledButton.icon(
                          onPressed: onDone,
                          icon: const Icon(Icons.done),
                          label: Text(l10n.scanDone),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ResultLine extends StatelessWidget {
  const _ResultLine({required this.event, required this.prominent});

  final ScanEvent event;
  final bool prominent;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final (icon, color, label) = switch (event.outcome) {
      ScanOutcome.accepted =>
        (Icons.check_circle, const Color(0xFF34D399), l10n.scanResultOk),
      ScanOutcome.duplicate => (
          Icons.filter_none,
          const Color(0xFFFBBF24),
          l10n.scanResultDuplicate
        ),
      ScanOutcome.rejected =>
        (Icons.cancel, const Color(0xFFF87171), l10n.scanResultNg),
    };

    return Row(
      children: [
        Icon(icon, size: prominent ? 20 : 14, color: color),
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: Text(
            event.message ?? '${event.code} · $label',
            style: TextStyle(
              color: prominent ? Colors.white : Colors.white60,
              fontSize: prominent ? 15 : 12,
              fontFamily: AppFonts.mono,
              fontWeight: prominent ? FontWeight.w600 : FontWeight.w400,
            ),
            maxLines: prominent ? 2 : 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

/// §11's 手動入力Fallback — a smudged or torn label must not stop the job.
class _ManualEntryDialog extends StatefulWidget {
  const _ManualEntryDialog();

  @override
  State<_ManualEntryDialog> createState() => _ManualEntryDialogState();
}

class _ManualEntryDialogState extends State<_ManualEntryDialog> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final code = _controller.text.trim();
    if (code.isEmpty) return;
    Navigator.pop(context, code);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.scanManualEntry),
      content: TextField(
        controller: _controller,
        autofocus: true,
        style: const TextStyle(fontFamily: AppFonts.mono),
        decoration: InputDecoration(
          labelText: l10n.scanManualEntryHint,
          border: const OutlineInputBorder(),
        ),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.actionCancel),
        ),
        FilledButton(onPressed: _submit, child: Text(l10n.actionOk)),
      ],
    );
  }
}

/// Semi-transparent scrim with a clear rounded scan window and corner accents.
class _ScannerOverlay extends StatelessWidget {
  const _ScannerOverlay();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final side = constraints.maxWidth * 0.72;
        final window = Rect.fromCenter(
          center: Offset(constraints.maxWidth / 2, constraints.maxHeight / 2),
          width: side,
          height: side * 0.7,
        );
        return IgnorePointer(
          child: CustomPaint(
            painter: _OverlayPainter(window),
            child: const SizedBox.expand(),
          ),
        );
      },
    );
  }
}

class _OverlayPainter extends CustomPainter {
  _OverlayPainter(this.window);

  final Rect window;

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(window, const Radius.circular(16));
    // Scrim everywhere except the scan window.
    final scrim = Path()
      ..addRect(Offset.zero & size)
      ..addRRect(rrect)
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(scrim, Paint()..color = const Color(0x99000000));

    // Accent border.
    canvas.drawRRect(
      rrect,
      Paint()
        ..color = const Color(0xFF38BDF8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
  }

  @override
  bool shouldRepaint(covariant _OverlayPainter oldDelegate) =>
      oldDelegate.window != window;
}

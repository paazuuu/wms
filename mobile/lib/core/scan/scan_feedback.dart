import 'package:flutter/services.dart';

import 'scan_session.dart';

/// Sound + vibration for a scan result (UI spec §11: バイブレーション・成功音・
/// エラー音).
///
/// A picker works with the phone at arm's length and their eyes on the shelf,
/// so the confirmation has to be audible and felt, not just drawn. Uses
/// Flutter's own platform sounds rather than bundled audio: no new dependency,
/// nothing to license, and the tones are the ones the operator's OS already
/// uses for "done" and "no". [SystemSoundType.click] and `.alert` are the only
/// two the platform exposes, so success and failure are separated further by
/// clearly different haptics — a light tap versus a heavy one plus an error
/// buzz.
///
/// Injectable so widget tests can assert what the operator would have heard.
class ScanFeedback {
  const ScanFeedback();

  Future<void> success() async {
    await HapticFeedback.mediumImpact();
    await SystemSound.play(SystemSoundType.click);
  }

  Future<void> error() async {
    await HapticFeedback.heavyImpact();
    await SystemSound.play(SystemSoundType.alert);
    // A second pulse: one buzz reads as "got it", two as "no".
    await HapticFeedback.heavyImpact();
  }

  /// A rescan of something already counted. Deliberately quieter than [error]:
  /// nothing is wrong, the scan just did not do anything.
  Future<void> duplicate() async {
    await HapticFeedback.selectionClick();
  }

  /// Play whatever [outcome] deserves.
  Future<void> forOutcome(ScanOutcome outcome) => switch (outcome) {
        ScanOutcome.accepted => success(),
        ScanOutcome.rejected => error(),
        ScanOutcome.duplicate => duplicate(),
      };
}

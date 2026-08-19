/// Pure, framework-free detector for USB/Bluetooth handheld barcode scanners
/// operating in *keyboard-wedge* (HID) mode.
///
/// A wedge scanner emits the decoded barcode as a burst of very fast keystrokes
/// terminated by Enter — nothing distinguishes it from the keyboard except the
/// timing. This class buffers the characters and, on the terminator, decides
/// whether the burst looked like a scan (fast enough, long enough) so callers
/// can route it as a barcode instead of stray typing.
///
/// It is deliberately UI-agnostic (no Flutter imports) so the timing logic can
/// be unit-tested directly.
class ScanBuffer {
  ScanBuffer({
    this.interKeyTimeout = const Duration(milliseconds: 120),
    this.minLength = 2,
  });

  /// Maximum gap between two keystrokes that still counts as one burst. Human
  /// typing is far slower than a scanner, so a longer pause resets the buffer.
  final Duration interKeyTimeout;

  /// Shortest accepted code. Guards against a single stray key + Enter being
  /// mistaken for a scan.
  final int minLength;

  final StringBuffer _buffer = StringBuffer();
  DateTime? _lastKeyAt;

  /// Number of characters currently buffered.
  int get length => _buffer.length;

  /// Feed a single printable character. If too much time has elapsed since the
  /// previous key the in-progress buffer is discarded first (new burst).
  void feed(String char, DateTime now) {
    final last = _lastKeyAt;
    if (last != null && now.difference(last) > interKeyTimeout) {
      _buffer.clear();
    }
    _buffer.write(char);
    _lastKeyAt = now;
  }

  /// Called when a terminator (Enter) arrives. Returns the buffered code when
  /// the burst qualifies as a scan, otherwise `null`. Always clears the buffer.
  String? flush(DateTime now) {
    final last = _lastKeyAt;
    final code = _buffer.toString();
    reset();
    if (last == null) return null;
    // A slow trailing pause means the terminator is unrelated to the burst.
    if (now.difference(last) > interKeyTimeout) return null;
    if (code.length < minLength) return null;
    return code;
  }

  /// Discard any in-progress burst.
  void reset() {
    _buffer.clear();
    _lastKeyAt = null;
  }
}

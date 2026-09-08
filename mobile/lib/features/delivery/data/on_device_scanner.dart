// Picks the on-device OCR scanner per platform: the real Google ML Kit
// implementation on Android/iOS, and a no-op stub on the web (ML Kit has no web
// support). Import this instead of the ML Kit file directly so web builds do
// not pull in the mobile-only plugin.
export 'mlkit_delivery_note_scanner.dart'
    if (dart.library.html) 'mlkit_delivery_note_scanner_web.dart';

/// Static configuration for the mobile client.
///
/// The API base URL can be overridden at build time:
/// `flutter run --dart-define=API_BASE_URL=https://wms.example.com`
class AppConfig {
  const AppConfig._();

  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost/api/v1',
  );

  /// Supabase project that backs the delivery-reconciliation feature (schema +
  /// Edge Functions). Override at build time with
  /// `--dart-define=SUPABASE_URL=...`.
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://vjunicsfobglmncjucbb.supabase.co',
  );

  /// Supabase anon (publishable) key. Safe to ship in a client — it only lets
  /// the app reach the Edge Functions gateway; data is guarded server-side.
  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZqdW5pY3Nmb2JnbG1uY2p1Y2JiIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODgzNjMzNDYsImV4cCI6MjEwMzkzOTM0Nn0.lYwz_yl0zi9FvJ37XSGFUpEziiG36bsd_ra8iO5iZ1M',
  );

  /// Base URL for Supabase Edge Functions (the delivery API + OCR live here).
  static String get functionsBaseUrl => '$supabaseUrl/functions/v1';

  static const Duration connectTimeout = Duration(seconds: 15);
  static const Duration receiveTimeout = Duration(seconds: 30);
}

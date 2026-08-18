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

  static const Duration connectTimeout = Duration(seconds: 15);
  static const Duration receiveTimeout = Duration(seconds: 30);
}

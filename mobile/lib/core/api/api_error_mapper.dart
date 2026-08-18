import 'package:dio/dio.dart';

import 'api_result.dart';

/// Translates a [DioException] into a typed [ApiFailure], pulling the backend
/// `message` and Laravel `errors` map when present.
ApiFailure<T> mapDioError<T>(DioException error) {
  final response = error.response;
  final data = response?.data;

  String message = 'Something went wrong. Please try again.';
  Map<String, List<String>>? errors;

  if (data is Map<String, dynamic>) {
    if (data['message'] is String) {
      message = data['message'] as String;
    }
    if (data['errors'] is Map) {
      errors = (data['errors'] as Map).map(
        (key, value) => MapEntry(
          key.toString(),
          (value as List).map((e) => e.toString()).toList(),
        ),
      );
    }
  } else if (error.type == DioExceptionType.connectionError ||
      error.type == DioExceptionType.connectionTimeout) {
    message = 'No connection to the server.';
  }

  return ApiFailure<T>(
    message: message,
    statusCode: response?.statusCode,
    errors: errors,
  );
}

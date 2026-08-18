import 'package:equatable/equatable.dart';

/// Unified response envelope used across every repository so callers handle
/// success and failure the same way regardless of the endpoint. Mirrors the
/// backend `{ message, data, error }` shape.
sealed class ApiResult<T> extends Equatable {
  const ApiResult();

  R when<R>({
    required R Function(T data) success,
    required R Function(ApiFailure failure) failure,
  }) {
    return switch (this) {
      ApiSuccess<T>(:final data) => success(data),
      ApiFailure<T> f => failure(f),
    };
  }

  @override
  List<Object?> get props => const [];
}

class ApiSuccess<T> extends ApiResult<T> {
  const ApiSuccess(this.data);

  final T data;

  @override
  List<Object?> get props => [data];
}

class ApiFailure<T> extends ApiResult<T> {
  const ApiFailure({
    required this.message,
    this.statusCode,
    this.errors,
  });

  final String message;
  final int? statusCode;

  /// Field-level validation errors, keyed by input name.
  final Map<String, List<String>>? errors;

  @override
  List<Object?> get props => [message, statusCode, errors];
}

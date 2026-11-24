import 'dart:async';
import 'dart:math';

import 'package:dio/dio.dart';

import '../config.dart';

class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final String? title;

  const ApiException({
    required this.message,
    this.statusCode,
    this.title,
  });

  @override
  String toString() => message;
}

class ApiClient {
  late final Dio _dio;

  ApiClient({Dio? dio}) {
    _dio = dio ??
        Dio(
          BaseOptions(
            baseUrl: AppConfig.apiBaseUrl,
            connectTimeout: AppConfig.connectTimeout,
            receiveTimeout: AppConfig.receiveTimeout,
            headers: const {
              'Accept': 'application/json',
              'Content-Type': 'application/json',
            },
          ),
        );

    _dio.interceptors.add(_ExponentialRetryInterceptor(_dio));
  }

  Dio get raw => _dio;

  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    try {
      return await _dio.get<T>(path, queryParameters: queryParameters);
    } on DioException catch (err) {
      throw parseDioError(err);
    }
  }

  Future<Response<T>> post<T>(
    String path, {
    Object? data,
  }) async {
    try {
      return await _dio.post<T>(path, data: data);
    } on DioException catch (err) {
      throw parseDioError(err);
    }
  }

  static ApiException parseDioError(DioException err) {
    final statusCode = err.response?.statusCode;
    final data = err.response?.data;

    if (data is Map<String, dynamic>) {
      final detail = data['detail']?.toString();
      final title = data['title']?.toString();
      if (detail != null && detail.isNotEmpty) {
        return ApiException(
          message: detail,
          statusCode: statusCode,
          title: title,
        );
      }
    }

    switch (err.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return const ApiException(
          message: 'Request timed out while contacting Space Control API.',
          title: 'Network Timeout',
        );
      case DioExceptionType.connectionError:
        return const ApiException(
          message:
              'Unable to reach the backend server. Check that FastAPI is running and reachable.',
          title: 'Connection Error',
        );
      case DioExceptionType.badResponse:
        return ApiException(
          message: 'Server returned an error (${statusCode ?? 'unknown'}).',
          statusCode: statusCode,
          title: 'Server Error',
        );
      case DioExceptionType.cancel:
        return const ApiException(
          message: 'Request was cancelled.',
          title: 'Cancelled',
        );
      default:
        return ApiException(
          message: err.message ?? 'An unexpected network error occurred.',
          statusCode: statusCode,
          title: 'Unexpected Error',
        );
    }
  }
}

class _ExponentialRetryInterceptor extends Interceptor {
  final Dio dio;

  _ExponentialRetryInterceptor(this.dio);

  bool _shouldRetry(DioException err) {
    if (err.requestOptions.method.toUpperCase() != 'GET') {
      return false;
    }
    if (err.type == DioExceptionType.connectionTimeout ||
        err.type == DioExceptionType.receiveTimeout ||
        err.type == DioExceptionType.connectionError) {
      return true;
    }
    final status = err.response?.statusCode;
    return status == 502 || status == 503 || status == 504;
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final attempt = (err.requestOptions.extra['retry_attempt'] as int?) ?? 0;

    if (attempt < AppConfig.maxRetries && _shouldRetry(err)) {
      final nextAttempt = attempt + 1;
      final delayMs = 400 * pow(2, attempt).toInt();
      await Future<void>.delayed(Duration(milliseconds: delayMs));

      err.requestOptions.extra['retry_attempt'] = nextAttempt;
      try {
        final response = await dio.fetch<dynamic>(err.requestOptions);
        handler.resolve(response);
        return;
      } on DioException catch (retryErr) {
        handler.next(retryErr);
        return;
      }
    }

    handler.next(err);
  }
}
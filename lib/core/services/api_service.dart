import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:easy_split/core/constants/app_constants.dart';

/// Core HTTP client for all API calls.
/// Automatically attaches auth tokens and handles errors.
class ApiService {
  late final Dio _dio;
  final FlutterSecureStorage _storage;

  ApiService({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage() {
    final base = AppConstants.baseUrl.endsWith('/')
        ? AppConstants.baseUrl
        : '${AppConstants.baseUrl}/';
    _dio = Dio(
      BaseOptions(
        baseUrl: base,
        connectTimeout: const Duration(seconds: 120),
        receiveTimeout: const Duration(seconds: 120),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    _setupInterceptors();
  }

  String _cleanPath(String path) => path.startsWith('/') ? path.substring(1) : path;

  void _setupInterceptors() {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await _storage.read(key: AppConstants.authTokenKey);
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
        onError: (error, handler) async {
          if (error.response?.statusCode == 401) {
            // Token expired — clear and signal session expiry
            await _storage.delete(key: AppConstants.authTokenKey);
            await _storage.delete(key: AppConstants.userIdKey);
          }
          handler.next(error);
        },
      ),
    );
  }

  // ── HTTP Methods ──────────────────────────────────────────────

  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    try {
      final response = await _dio.get(
        _cleanPath(path),
        queryParameters: queryParameters,
      );
      return _handleResponse(response);
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  Future<List<int>> getBytes(String path) async {
    try {
      final response = await _dio.get<List<int>>(
        _cleanPath(path),
        options: Options(responseType: ResponseType.bytes),
      );
      return response.data ?? [];
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  Future<Map<String, dynamic>> post(
    String path, {
    Map<String, dynamic>? data,
  }) async {
    try {
      final response = await _dio.post(_cleanPath(path), data: data);
      return _handleResponse(response);
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  Future<Map<String, dynamic>> put(
    String path, {
    Map<String, dynamic>? data,
  }) async {
    try {
      final response = await _dio.put(_cleanPath(path), data: data);
      return _handleResponse(response);
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  Future<Map<String, dynamic>> patch(
    String path, {
    Map<String, dynamic>? data,
  }) async {
    try {
      final response = await _dio.patch(_cleanPath(path), data: data);
      return _handleResponse(response);
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  Future<Map<String, dynamic>> delete(String path) async {
    try {
      final response = await _dio.delete(_cleanPath(path));
      return _handleResponse(response);
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  Future<Map<String, dynamic>> uploadFile(
    String path, {
    required String filePath,
    required String fieldName,
    Map<String, dynamic>? extraData,
  }) async {
    try {
      final formData = FormData.fromMap({
        fieldName: await MultipartFile.fromFile(
          filePath,
          filename: filePath.split(Platform.pathSeparator).last,
        ),
        ...?extraData,
      });
      final response = await _dio.post(_cleanPath(path), data: formData);
      return _handleResponse(response);
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  // ── Helpers ───────────────────────────────────────────────────

  Map<String, dynamic> _handleResponse(Response response) {
    final data = response.data;
    if (data is Map<String, dynamic>) return data;
    if (data is String) return jsonDecode(data) as Map<String, dynamic>;
    return {'data': data};
  }

  AppException _mapError(DioException e) {
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.connectionError) {
      return const AppException(
        'Unable to connect to server (${AppConstants.baseUrl}). Please ensure backend is running (cd backend && npm run dev).',
        type: AppExceptionType.network,
      );
    }

    final statusCode = e.response?.statusCode;
    final message = _extractMessage(e.response?.data) ?? AppConstants.genericError;

    if (statusCode == 401) {
      return AppException(AppConstants.sessionExpired, type: AppExceptionType.unauthorized);
    }
    if (statusCode == 404) {
      return AppException(message, type: AppExceptionType.notFound);
    }
    if (statusCode == 422 || statusCode == 400) {
      return AppException(message, type: AppExceptionType.validation);
    }
    return AppException(message, type: AppExceptionType.server);
  }

  String? _extractMessage(dynamic data) {
    if (data is Map<String, dynamic>) {
      return data['message'] as String? ??
          data['error'] as String? ??
          data['msg'] as String?;
    }
    return null;
  }
}

// ── Exception Types ───────────────────────────────────────────────

enum AppExceptionType { network, unauthorized, notFound, validation, server }

class AppException implements Exception {
  final String message;
  final AppExceptionType type;

  const AppException(this.message, {this.type = AppExceptionType.server});

  @override
  String toString() => message;
}

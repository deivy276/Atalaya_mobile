import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/security/session_secure_storage.dart';
import '../../data/datasources/atalaya_api_client.dart';
import '../../data/repositories/atalaya_repository_impl.dart';
import '../../data/repositories/mock_atalaya_repository.dart';
import '../../domain/repositories/atalaya_repository.dart';

bool _mockModeEnabled() {
  const raw = String.fromEnvironment('ATALAYA_USE_MOCK', defaultValue: 'false');
  final normalized = raw.trim().toLowerCase();
  return normalized == 'true' || normalized == '1';
}

String _normalizeBaseUrl(String raw) {
  var normalized = raw.trim();
  while (normalized.endsWith('/')) {
    normalized = normalized.substring(0, normalized.length - 1);
  }
  return normalized;
}

String _defaultApiBaseUrl() {
  const configured = String.fromEnvironment('ATALAYA_API_BASE_URL', defaultValue: '');
  final normalizedConfigured = _normalizeBaseUrl(configured);
  if (normalizedConfigured.isNotEmpty) {
    return normalizedConfigured;
  }

  if (kIsWeb) {
    return 'http://localhost:8010';
  }

  switch (defaultTargetPlatform) {
    case TargetPlatform.android:
      return 'http://10.0.2.2:8010';
    case TargetPlatform.iOS:
    case TargetPlatform.macOS:
    case TargetPlatform.windows:
    case TargetPlatform.linux:
    case TargetPlatform.fuchsia:
      return 'http://127.0.0.1:8010';
  }
}

String _formatAuthorizationHeader(String token) {
  final trimmed = token.trim();
  final normalized = trimmed.toLowerCase();

  if (normalized.startsWith('bearer ') || normalized.startsWith('basic ')) {
    return trimmed;
  }

  if (trimmed.startsWith('sid:')) {
    return trimmed;
  }

  return 'Bearer $trimmed';
}

String _connectivityHint(String baseUrl) {
  final normalized = baseUrl.toLowerCase();

  if (kIsWeb) {
    return 'Web usa http://localhost:8010 por defecto. Asegúrate de levantar el backend, permitir CORS o pasar --dart-define=ATALAYA_API_BASE_URL=$baseUrl.';
  }

  if (normalized.contains('10.0.2.2') || normalized.contains('127.0.0.1') || normalized.contains('localhost')) {
    return 'Ese host funciona solo en emulador/desktop local. En un teléfono físico usa la IP LAN del servidor o un host público, por ejemplo --dart-define=ATALAYA_API_BASE_URL=https://atalaya-predictor-staging.onrender.com.';
  }

  return 'Verifica que el backend esté arriba y accesible desde este dispositivo.';
}

final sessionSecureStorageProvider = Provider<SessionSecureStorage>(
  (ref) => SessionSecureStorage(),
);

final apiBaseUrlProvider = Provider<String>((ref) => _defaultApiBaseUrl());

final dioProvider = Provider<Dio>((ref) {
  final baseUrl = ref.watch(apiBaseUrlProvider);
  final sessionStorage = ref.watch(sessionSecureStorageProvider);

  final dio = Dio(
    BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15),
      sendTimeout: const Duration(seconds: 15),
      headers: const <String, dynamic>{
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
    ),
  );

  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) async {
        try {
          final path = options.path.toLowerCase();
          final isLoginRequest = path.endsWith('/auth/login') || path == '/auth/login';

          if (isLoginRequest) {
            options.headers.remove('Authorization');
            handler.next(options);
            return;
          }

          final token = await sessionStorage.readToken();
          final expiresAt = await sessionStorage.readExpiresAt();
          final now = DateTime.now().toUtc();

          final hasValidSession =
              token != null &&
              token.trim().isNotEmpty &&
              expiresAt != null &&
              expiresAt.isAfter(now);

          if (hasValidSession) {
            options.headers['Authorization'] = _formatAuthorizationHeader(token);
          } else {
            options.headers.remove('Authorization');
            if (expiresAt != null && !expiresAt.isAfter(now)) {
              await sessionStorage.clearSession();
            }
          }
        } catch (_) {
          options.headers.remove('Authorization');
        }

        handler.next(options);
      },
      onError: (error, handler) async {
        final type = error.type;
        final isConnectivityError =
            type == DioExceptionType.connectionTimeout ||
            type == DioExceptionType.connectionError ||
            type == DioExceptionType.receiveTimeout ||
            type == DioExceptionType.sendTimeout;

        final statusCode = error.response?.statusCode;
        final requestPath = error.requestOptions.path.toLowerCase();
        final isLoginRequest = requestPath.endsWith('/auth/login') || requestPath == '/auth/login';

        if (statusCode == 401 && !isLoginRequest) {
          await sessionStorage.clearSession();
          handler.next(
            error.copyWith(
              message: 'Sesión expirada o no autorizada. Inicia sesión nuevamente.',
            ),
          );
          return;
        }

        if (isConnectivityError) {
          handler.next(
            error.copyWith(
              message: 'No se pudo conectar a $baseUrl. ${_connectivityHint(baseUrl)}',
            ),
          );
          return;
        }

        handler.next(error);
      },
    ),
  );

  ref.onDispose(() {
    dio.close(force: true);
  });

  return dio;
});

final atalayaApiClientProvider = Provider<AtalayaApiClient>(
  (ref) => AtalayaApiClient(ref.watch(dioProvider)),
);

final atalayaRepositoryProvider = Provider<AtalayaRepository>((ref) {
  if (_mockModeEnabled()) {
    return const MockAtalayaRepository();
  }

  return AtalayaRepositoryImpl(ref.watch(atalayaApiClientProvider));
});

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/datasources/atalaya_api_client.dart';
import '../../data/repositories/atalaya_repository_impl.dart';
import '../../domain/repositories/atalaya_repository.dart';

String _defaultApiBaseUrl() {
  const configured = String.fromEnvironment('ATALAYA_API_BASE_URL', defaultValue: '');
  if (configured.isNotEmpty) {
    return configured;
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

final apiBaseUrlProvider = Provider<String>((ref) => _defaultApiBaseUrl());

final dioProvider = Provider<Dio>((ref) {
  final baseUrl = ref.watch(apiBaseUrlProvider);

  final dio = Dio(
    BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15),
      sendTimeout: const Duration(seconds: 15),
      headers: const <String, dynamic>{
        'Accept': 'application/json',
      },
    ),
  );

  dio.interceptors.add(
    InterceptorsWrapper(
      onError: (error, handler) {
        final type = error.type;
        final isConnectivityError =
            type == DioExceptionType.connectionTimeout ||
            type == DioExceptionType.connectionError ||
            type == DioExceptionType.receiveTimeout ||
            type == DioExceptionType.sendTimeout;

        if (isConnectivityError) {
          final hint = kIsWeb
              ? 'Chrome/Web usa http://localhost:8010 por defecto. Asegúrate de levantar FastAPI y permitir CORS, o pasa --dart-define=ATALAYA_API_BASE_URL=http://localhost:8010.'
              : 'Verifica que el backend FastAPI esté arriba en $baseUrl. En Android emulador usa 10.0.2.2; en Windows/macOS/Linux usa 127.0.0.1; en un teléfono físico usa la IP LAN del servidor.';

          handler.next(
            error.copyWith(
              message: 'No se pudo conectar a $baseUrl. $hint',
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

final atalayaRepositoryProvider = Provider<AtalayaRepository>(
  (ref) => AtalayaRepositoryImpl(ref.watch(atalayaApiClientProvider)),
);

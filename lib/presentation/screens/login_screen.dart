import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/api_client_provider.dart';
import '../widgets/v2/login_card.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({
    super.key,
    required this.onLoginSuccess,
  });

  final Future<void> Function({
    required String token,
    required DateTime expiresAt,
  }) onLoginSuccess;

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  static const Duration _fallbackSessionTtl = Duration(hours: 12);

  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _isLoading = false;
  String? _errorText;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: LoginCard(
                usernameController: _usernameController,
                passwordController: _passwordController,
                isLoading: _isLoading,
                errorText: _errorText,
                onSubmit: _submit,
                onForgotPassword: _showForgotPasswordDialog,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();

    final username = _usernameController.text.trim();
    final password = _passwordController.text;

    if (username.isEmpty || password.isEmpty) {
      setState(() => _errorText = 'Ingresa usuario y contraseña.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorText = null;
    });

    try {
      final dio = ref.read(dioProvider);
      final response = await dio.post<dynamic>(
        '/auth/login',
        data: <String, dynamic>{
          'username': username,
          'password': password,
        },
      );

      final statusCode = response.statusCode ?? 0;
      final payload = _asStringKeyedMap(response.data);

      if (statusCode >= 200 && statusCode < 300) {
        final session = _buildSessionPayload(
          username: username,
          payload: payload,
        );

        if (!mounted) {
          return;
        }

        await widget.onLoginSuccess(
          token: session.token,
          expiresAt: session.expiresAt,
        );
        return;
      }

      if (!mounted) {
        return;
      }

      setState(
        () => _errorText = _extractErrorMessage(
          payload,
          defaultMessage: 'Credenciales inválidas.',
        ),
      );
    } on DioException catch (error) {
      if (!mounted) {
        return;
      }

      final payload = _asStringKeyedMap(error.response?.data);
      final fallbackMessage = error.message?.trim().isNotEmpty == true
          ? error.message!.trim()
          : 'No fue posible iniciar sesión.';

      setState(
        () => _errorText = _extractErrorMessage(
          payload,
          defaultMessage: fallbackMessage,
        ),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorText = 'Ocurrió un error inesperado al iniciar sesión.';
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  _SessionPayload _buildSessionPayload({
    required String username,
    required Map<String, dynamic>? payload,
  }) {
    final token = _extractToken(payload) ?? 'sid:$username:${DateTime.now().millisecondsSinceEpoch}';
    final expiresAt = _extractExpiresAt(payload) ?? DateTime.now().toUtc().add(_fallbackSessionTtl);

    return _SessionPayload(
      token: token,
      expiresAt: expiresAt,
    );
  }

  String? _extractToken(Map<String, dynamic>? payload) {
    for (final map in _candidateMaps(payload)) {
      for (final key in const <String>[
        'access_token',
        'accessToken',
        'token',
        'session_token',
        'sessionToken',
        'sid',
        'auth_token',
        'authToken',
      ]) {
        final value = map[key];
        if (value is String && value.trim().isNotEmpty) {
          return value.trim();
        }
      }
    }
    return null;
  }

  DateTime? _extractExpiresAt(Map<String, dynamic>? payload) {
    for (final map in _candidateMaps(payload)) {
      final expiresAtValue = map['expires_at'] ?? map['expiresAt'] ?? map['expiry'] ?? map['expires'];
      final expiresAt = _parseDateTimeValue(expiresAtValue);
      if (expiresAt != null) {
        return expiresAt;
      }

      final expiresInValue = map['expires_in'] ?? map['expiresIn'];
      final expiresIn = _parseDurationFromSeconds(expiresInValue);
      if (expiresIn != null) {
        return DateTime.now().toUtc().add(expiresIn);
      }

      final ttlHoursValue = map['ttl_hours'] ?? map['ttlHours'];
      final ttlHours = _parseDurationFromHours(ttlHoursValue);
      if (ttlHours != null) {
        return DateTime.now().toUtc().add(ttlHours);
      }

      final ttlMinutesValue = map['ttl_minutes'] ?? map['ttlMinutes'];
      final ttlMinutes = _parseDurationFromMinutes(ttlMinutesValue);
      if (ttlMinutes != null) {
        return DateTime.now().toUtc().add(ttlMinutes);
      }
    }

    return null;
  }

  String _extractErrorMessage(
    Map<String, dynamic>? payload, {
    required String defaultMessage,
  }) {
    for (final map in _candidateMaps(payload)) {
      for (final key in const <String>['detail', 'message', 'error', 'description']) {
        final value = map[key];
        if (value is String && value.trim().isNotEmpty) {
          return value.trim();
        }
      }
    }

    return defaultMessage;
  }

  List<Map<String, dynamic>> _candidateMaps(Map<String, dynamic>? payload) {
    if (payload == null) {
      return const <Map<String, dynamic>>[];
    }

    final maps = <Map<String, dynamic>>[payload];
    for (final key in const <String>['data', 'result', 'session', 'payload']) {
      final nested = _asStringKeyedMap(payload[key]);
      if (nested != null) {
        maps.add(nested);
      }
    }
    return maps;
  }

  Map<String, dynamic>? _asStringKeyedMap(dynamic value) {
    if (value is! Map) {
      return null;
    }

    return value.map(
      (key, dynamic entryValue) => MapEntry(key.toString(), entryValue),
    );
  }

  DateTime? _parseDateTimeValue(dynamic value) {
    if (value == null) {
      return null;
    }

    if (value is DateTime) {
      return value.toUtc();
    }

    if (value is String) {
      final trimmed = value.trim();
      if (trimmed.isEmpty) {
        return null;
      }

      final parsed = DateTime.tryParse(trimmed);
      if (parsed != null) {
        return parsed.toUtc();
      }

      final numeric = int.tryParse(trimmed);
      if (numeric != null) {
        return _parseEpoch(numeric);
      }
    }

    if (value is num) {
      return _parseEpoch(value.toInt());
    }

    return null;
  }

  DateTime? _parseEpoch(int value) {
    if (value <= 0) {
      return null;
    }

    if (value >= 1000000000000) {
      return DateTime.fromMillisecondsSinceEpoch(value, isUtc: true);
    }

    if (value >= 1000000000) {
      return DateTime.fromMillisecondsSinceEpoch(value * 1000, isUtc: true);
    }

    return null;
  }

  Duration? _parseDurationFromSeconds(dynamic value) {
    final numeric = _parseNumeric(value);
    if (numeric == null || numeric <= 0) {
      return null;
    }
    return Duration(seconds: numeric.round());
  }

  Duration? _parseDurationFromHours(dynamic value) {
    final numeric = _parseNumeric(value);
    if (numeric == null || numeric <= 0) {
      return null;
    }
    return Duration(minutes: (numeric * 60).round());
  }

  Duration? _parseDurationFromMinutes(dynamic value) {
    final numeric = _parseNumeric(value);
    if (numeric == null || numeric <= 0) {
      return null;
    }
    return Duration(minutes: numeric.round());
  }

  double? _parseNumeric(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }

    if (value is String) {
      return double.tryParse(value.trim().replaceAll(',', '.'));
    }

    return null;
  }

  Future<void> _showForgotPasswordDialog() async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Recuperar acceso'),
          content: const Text(
            'Por ahora, contacta al administrador para restablecer tu contraseña.',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Entendido'),
            ),
          ],
        );
      },
    );
  }
}

class _SessionPayload {
  const _SessionPayload({
    required this.token,
    required this.expiresAt,
  });

  final String token;
  final DateTime expiresAt;
}

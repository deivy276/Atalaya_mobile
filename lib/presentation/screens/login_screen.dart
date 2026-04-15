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
      final response = await dio.post<Map<String, dynamic>>(
        '/auth/login',
        data: <String, dynamic>{
          'username': username,
          'password': password,
        },
      );

      if (!mounted) {
        return;
      }

      final fallbackTtlHours = 12;
      final token = 'sid:${username}:${DateTime.now().millisecondsSinceEpoch}';
      final expiresAt = DateTime.now().toUtc().add(Duration(hours: fallbackTtlHours));

      if (response.statusCode == 200) {
        await widget.onLoginSuccess(token: token, expiresAt: expiresAt);
        return;
      }

      setState(() => _errorText = _extractErrorMessage(response.data, defaultMessage: 'Credenciales inválidas.'));
    } on DioException catch (error) {
      if (!mounted) {
        return;
      }
      final detail = error.response?.data;
      final message = detail is Map<String, dynamic>
          ? _extractErrorMessage(detail, defaultMessage: 'No fue posible iniciar sesión.')
          : (error.message ?? 'No fue posible iniciar sesión.');
      setState(() => _errorText = message);
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() => _errorText = 'Ocurrió un error inesperado al iniciar sesión.');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _extractErrorMessage(Map<String, dynamic>? data, {required String defaultMessage}) {
    final detail = data?['detail'];
    if (detail is String && detail.trim().isNotEmpty) {
      return detail.trim();
    }
    return defaultMessage;
  }

  Future<void> _showForgotPasswordDialog() async {
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Recuperar acceso'),
          content: const Text('Por ahora, contacta al administrador para restablecer tu contraseña.'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Entendido'),
            ),
          ],
        );
      },
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/feature_flags.dart';
import '../../core/security/session_secure_storage.dart';
import '../providers/api_client_provider.dart';
import '../providers/dashboard_controller.dart';
import 'dashboard_screen.dart';
import 'dashboard_v2_screen.dart';
import 'login_screen.dart';

class AuthGateScreen extends ConsumerStatefulWidget {
  const AuthGateScreen({super.key});

  @override
  ConsumerState<AuthGateScreen> createState() => _AuthGateScreenState();
}

class _AuthGateScreenState extends ConsumerState<AuthGateScreen> {
  final SessionSecureStorage _sessionStorage = SessionSecureStorage();

  bool _checkingSession = true;
  bool _isAuthenticated = false;

  @override
  void initState() {
    super.initState();
    _restoreSession();
  }

  @override
  Widget build(BuildContext context) {
    if (_checkingSession) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_isAuthenticated) {
      if (FeatureFlags.mobileDashboardV2) {
        return DashboardV2Screen(onLogout: _logout);
      }
      return DashboardScreen(onLogout: _logout);
    }

    return LoginScreen(onLoginSuccess: _saveSessionAndEnter);
  }

  Future<void> _restoreSession() async {
    final token = await _sessionStorage.readToken();
    final expiresAt = await _sessionStorage.readExpiresAt();
    final now = DateTime.now().toUtc();
    final isValid = token != null && token.trim().isNotEmpty && expiresAt != null && expiresAt.isAfter(now);

    if (!isValid) {
      await _sessionStorage.clearSession();
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _isAuthenticated = isValid;
      _checkingSession = false;
    });
  }

  Future<void> _saveSessionAndEnter({
    required String token,
    required DateTime expiresAt,
  }) async {
    await _sessionStorage.saveSession(token: token, expiresAt: expiresAt);
    if (!mounted) {
      return;
    }
    setState(() => _isAuthenticated = true);
  }

  Future<void> _logout() async {
    try {
      await ref.read(dioProvider).post('/auth/logout');
    } catch (_) {
      // Best effort logout request; local session must still be cleared.
    }
    await _sessionStorage.clearSession();
    ref.invalidate(dashboardControllerProvider);
    if (!mounted) {
      return;
    }
    setState(() => _isAuthenticated = false);
  }
}

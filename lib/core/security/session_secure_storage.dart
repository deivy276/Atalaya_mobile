import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SessionSecureStorage {
  SessionSecureStorage({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  static const String _sessionTokenKey = 'atalaya_session_token';
  static const String _sessionExpiresAtKey = 'atalaya_session_expires_at';

  final FlutterSecureStorage _storage;

  Future<void> saveSession({
    required String token,
    required DateTime expiresAt,
  }) async {
    await _storage.write(key: _sessionTokenKey, value: token);
    await _storage.write(
      key: _sessionExpiresAtKey,
      value: expiresAt.toUtc().toIso8601String(),
    );
  }

  Future<String?> readToken() => _storage.read(key: _sessionTokenKey);

  Future<DateTime?> readExpiresAt() async {
    final value = await _storage.read(key: _sessionExpiresAtKey);
    if (value == null || value.trim().isEmpty) {
      return null;
    }
    return DateTime.tryParse(value)?.toUtc();
  }

  Future<void> clearSession() async {
    await _storage.delete(key: _sessionTokenKey);
    await _storage.delete(key: _sessionExpiresAtKey);
  }
}

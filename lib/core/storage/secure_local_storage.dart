import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// A secure storage implementation for Supabase auth sessions.
/// Uses [FlutterSecureStorage] with Android Keystore and iOS Keychain.
/// Automatically migrates existing unencrypted sessions from [SharedPreferences] to ensure
/// existing users remain logged in seamlessly without losing their session.
class SecureLocalStorage extends LocalStorage {
  SecureLocalStorage({
    FlutterSecureStorage? storage,
    this.persistSessionKey = 'supabasePersistSessionKey',
  }) : _storage = storage ??
            const FlutterSecureStorage(
              iOptions: IOSOptions(
                accessibility: KeychainAccessibility.first_unlock,
              ),
              mOptions: MacOsOptions(
                usesDataProtectionKeychain: false,
              ),
            );

  final FlutterSecureStorage _storage;
  final String persistSessionKey;
  SharedPreferences? _prefs;

  @override
  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
  }

  @override
  Future<bool> hasAccessToken() async {
    final token = await accessToken();
    return token != null && token.isNotEmpty;
  }

  @override
  Future<String?> accessToken() async {
    try {
      final secureVal = await _storage.read(key: persistSessionKey);
      if (secureVal != null && secureVal.isNotEmpty) {
        return secureVal;
      }

      // Seamless migration from legacy SharedPreferences
      if (_prefs != null && _prefs!.containsKey(persistSessionKey)) {
        final legacyVal = _prefs!.getString(persistSessionKey);
        if (legacyVal != null && legacyVal.isNotEmpty) {
          await _storage.write(key: persistSessionKey, value: legacyVal);
          await _prefs!.remove(persistSessionKey);
          return legacyVal;
        }
      }
    } catch (e) {
      debugPrint('[SecureLocalStorage] Read error, fallback to legacy: $e');
      if (_prefs != null) {
        return _prefs!.getString(persistSessionKey);
      }
    }
    return null;
  }

  @override
  Future<void> persistSession(String persistSessionString) async {
    try {
      await _storage.write(
        key: persistSessionKey,
        value: persistSessionString,
      );
      // Clean up legacy SharedPreferences if present
      if (_prefs != null && _prefs!.containsKey(persistSessionKey)) {
        await _prefs!.remove(persistSessionKey);
      }
    } catch (e) {
      debugPrint('[SecureLocalStorage] Write error, fallback to legacy: $e');
      if (_prefs != null) {
        await _prefs!.setString(persistSessionKey, persistSessionString);
      }
    }
  }

  @override
  Future<void> removePersistedSession() async {
    try {
      await _storage.delete(key: persistSessionKey);
    } catch (e) {
      debugPrint('[SecureLocalStorage] Delete error: $e');
    }
    if (_prefs != null && _prefs!.containsKey(persistSessionKey)) {
      await _prefs!.remove(persistSessionKey);
    }
  }
}

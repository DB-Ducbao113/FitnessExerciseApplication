import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'google_oauth_stub.dart'
    if (dart.library.js_interop) 'google_oauth_web.dart';

const authCallbackUrl = 'io.supabase.flutter://callback';

/// Google Web Client ID (from Google Cloud Console -> Clients -> Web application)
const kGoogleWebClientId = String.fromEnvironment(
  'GOOGLE_WEB_CLIENT_ID',
  defaultValue: '741155040974-vj5atqn3ev6ehnnd15k1a93hi2thkj0o.apps.googleusercontent.com',
);

/// Google iOS Client ID (from Google Cloud Console -> Clients -> iOS)
const kGoogleIosClientId = String.fromEnvironment(
  'GOOGLE_IOS_CLIENT_ID',
  defaultValue: '741155040974-jvfb8ca41otk67f9pp1st5aqcp3mdqn9.apps.googleusercontent.com',
);

String _generateRawNonce([int length = 32]) {
  const charset = '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._~';
  final random = Random.secure();
  return List.generate(length, (_) => charset[random.nextInt(charset.length)]).join();
}

String _sha256Hex(String input) {
  return sha256.convert(utf8.encode(input)).toString();
}

Map<String, dynamic>? _decodeJwtPayload(String token) {
  try {
    final parts = token.split('.');
    if (parts.length != 3) return null;
    final normalized = base64Url.normalize(parts[1]);
    final decoded = utf8.decode(base64Url.decode(normalized));
    return jsonDecode(decoded) as Map<String, dynamic>;
  } catch (_) {
    return null;
  }
}

Future<AuthResponse> _signInWithIdTokenSafe({
  required String idToken,
  String? accessToken,
  String? rawNonce,
}) async {
  final payload = _decodeJwtPayload(idToken);
  final hasNonceInToken = payload != null && payload['nonce'] != null;

  debugPrint('🔑 Google ID Token nonce present in JWT: $hasNonceInToken');

  try {
    return await Supabase.instance.client.auth.signInWithIdToken(
      provider: OAuthProvider.google,
      idToken: idToken,
      accessToken: accessToken,
      nonce: (hasNonceInToken && rawNonce != null) ? rawNonce : null,
    );
  } on AuthException catch (e) {
    if (e.message.toLowerCase().contains('nonce')) {
      debugPrint('⚠️ Nonce check failed (${e.message}). Attempting automatic nonce retry...');
      return await Supabase.instance.client.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: accessToken,
        nonce: (hasNonceInToken && rawNonce != null) ? null : rawNonce,
      );
    }
    rethrow;
  }
}

Future<bool> startGoogleOAuthSignIn({
  String? webClientId,
  String? iosClientId,
}) async {
  final effectiveWebId = (webClientId != null && webClientId.isNotEmpty)
      ? webClientId
      : kGoogleWebClientId;
  final effectiveIosId = (iosClientId != null && iosClientId.isNotEmpty)
      ? iosClientId
      : kGoogleIosClientId;

  // 1. WEB FLOW: Directly obtain Google ID Token from Google Identity Services
  // This stays 100% on aetron.netlify.app without redirecting to supabase.co
  if (kIsWeb) {
    try {
      final rawNonce = _generateRawNonce();
      final hashedNonce = _sha256Hex(rawNonce);

      final idToken = await getGoogleIdTokenWeb(effectiveWebId, hashedNonce);
      if (idToken != null && idToken.isNotEmpty) {
        final res = await _signInWithIdTokenSafe(
          idToken: idToken,
          rawNonce: rawNonce,
        );
        return res.user != null;
      }
    } on AuthException catch (e) {
      debugPrint('❌ Supabase Auth with Google ID Token error: ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('❌ Google GIS Web ID Token error: $e');
    }

    // If popup was blocked or GIS failed, fallback to standard OAuth
    return await Supabase.instance.client.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: Uri.base.origin,
      authScreenLaunchMode: LaunchMode.platformDefault,
      scopes: 'email profile',
      queryParams: const {'prompt': 'select_account'},
    );
  }

  // 2. MOBILE FLOW (iOS / Android): Native Google Sign-In SDK
  try {
    final isIos = defaultTargetPlatform == TargetPlatform.iOS;
    final GoogleSignIn googleSignIn = GoogleSignIn(
      clientId: isIos && effectiveIosId.isNotEmpty ? effectiveIosId : null,
      serverClientId: effectiveWebId.isNotEmpty ? effectiveWebId : null,
      scopes: const ['email', 'profile'],
    );

    // Clear previous cached session on mobile for fresh account picker
    await googleSignIn.signOut().catchError((_) => null);

    final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
    if (googleUser == null) {
      // User cancelled
      return false;
    }

    final GoogleSignInAuthentication googleAuth =
        await googleUser.authentication;
    final idToken = googleAuth.idToken;
    final accessToken = googleAuth.accessToken;

    if (idToken == null) {
      throw const AuthException('No ID Token received from Google Sign-In.');
    }

    final res = await _signInWithIdTokenSafe(
      idToken: idToken,
      accessToken: accessToken,
    );

    return res.user != null;
  } on AuthException catch (e) {
    debugPrint('❌ Supabase Auth error with Google ID Token: ${e.message}');
    rethrow;
  } catch (e) {
    debugPrint('❌ Native Google Sign-In error: $e');
    rethrow;
  }
}



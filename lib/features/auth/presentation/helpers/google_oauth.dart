import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const authCallbackUrl = 'io.supabase.flutter://callback';

Future<bool> startGoogleOAuthSignIn() {
  return Supabase.instance.client.auth.signInWithOAuth(
    OAuthProvider.google,
    redirectTo: kIsWeb ? null : authCallbackUrl,
    scopes: 'email profile',
    queryParams: const {'prompt': 'select_account'},
  );
}

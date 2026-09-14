import 'dart:async';
import 'dart:js_interop';

@JS('aetronGoogleSignIn')
external JSPromise<JSString>? _jsAetronGoogleSignIn(
  JSString clientId, [
  JSString? nonce,
]);

Future<String?> getGoogleIdTokenWeb(String clientId, [String? nonce]) async {
  try {
    final promise = _jsAetronGoogleSignIn(
      clientId.toJS,
      nonce?.toJS,
    );
    if (promise == null) return null;
    final jsResult = await promise.toDart;
    return jsResult.toDart;
  } catch (e) {
    return null;
  }
}

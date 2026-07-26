const _internalEmailDomain = 'aetron.local';
final _usernamePattern = RegExp(r'^[a-z0-9][a-z0-9_.]{2,23}$');

String normalizeUsername(String value) => value.trim().toLowerCase();

String? validateUsername(String? value) {
  final username = normalizeUsername(value ?? '');
  if (username.isEmpty) return 'Enter a username';
  if (!_usernamePattern.hasMatch(username)) {
    return 'Use 3-24 lowercase letters, numbers, . or _';
  }
  return null;
}

String internalEmailForUsername(String username) {
  return '${normalizeUsername(username)}@$_internalEmailDomain';
}

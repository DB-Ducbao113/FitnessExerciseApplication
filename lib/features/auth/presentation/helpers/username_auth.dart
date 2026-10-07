const _internalEmailDomain = 'aetron.local';
final _usernamePattern = RegExp(r'^[a-z0-9][a-z0-9_.]{2,23}$');

String normalizeUsername(String value) => value.trim().toLowerCase();

String? validateUsername(String? value, {bool isVi = false}) {
  final username = normalizeUsername(value ?? '');
  if (username.isEmpty) {
    return isVi ? 'Vui lòng nhập tên tài khoản' : 'Enter a username';
  }
  if (username.length < 3) {
    return isVi
        ? 'Tên tài khoản tối thiểu 3 ký tự'
        : 'Username must be at least 3 characters';
  }
  if (username.length > 24) {
    return isVi
        ? 'Tên tài khoản tối đa 24 ký tự'
        : 'Username must be at most 24 characters';
  }
  if (!_usernamePattern.hasMatch(username)) {
    return isVi
        ? 'Dùng 3-24 chữ cái thường, số, dấu chấm (.) hoặc (_)'
        : 'Use 3-24 lowercase letters, numbers, . or _';
  }
  return null;
}

String internalEmailForUsername(String username) {
  return '${normalizeUsername(username)}@$_internalEmailDomain';
}

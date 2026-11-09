const newPasswordHint =
    'Từ 8 đến 128 ký tự, gồm chữ thường, chữ hoa, số và ký tự đặc biệt.';

final _lowercase = RegExp(r'\p{Ll}', unicode: true);
final _uppercase = RegExp(r'\p{Lu}', unicode: true);
final _digit = RegExp(r'\p{Nd}', unicode: true);
final _special = RegExp(r'[\p{P}\p{S}]', unicode: true);

String? newPasswordError(String password) {
  if (password.length < 8) return 'Mật khẩu cần ít nhất 8 ký tự.';
  if (password.length > 128) return 'Mật khẩu tối đa 128 ký tự.';
  if (!_lowercase.hasMatch(password) ||
      !_uppercase.hasMatch(password) ||
      !_digit.hasMatch(password) ||
      !_special.hasMatch(password)) {
    return 'Mật khẩu cần có chữ thường, chữ hoa, số và ký tự đặc biệt.';
  }
  return null;
}

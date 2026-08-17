class AuthTokens {
  const AuthTokens({required this.accessToken, required this.refreshToken});

  final String accessToken;
  final String refreshToken;

  bool get isComplete => accessToken.isNotEmpty && refreshToken.isNotEmpty;

  factory AuthTokens.fromJson(Map<String, dynamic> json) {
    return AuthTokens(
      accessToken: json['accessToken']?.toString() ?? '',
      refreshToken: json['refreshToken']?.toString() ?? '',
    );
  }
}

class LoginSession {
  const LoginSession({
    required this.tokens,
    required this.fullName,
    required this.userId,
    required this.phone,
  });

  final AuthTokens tokens;
  final String fullName;
  final int userId;
  final String phone;

  factory LoginSession.fromJson(
    Map<String, dynamic> json, {
    required String phone,
  }) {
    final rawId = json['id'];
    return LoginSession(
      tokens: AuthTokens.fromJson(json),
      fullName: json['fullName']?.toString() ?? '',
      userId: rawId is int ? rawId : int.tryParse('$rawId') ?? 0,
      phone: phone,
    );
  }
}

enum AuthRestoreStatus { authenticated, unauthenticated }

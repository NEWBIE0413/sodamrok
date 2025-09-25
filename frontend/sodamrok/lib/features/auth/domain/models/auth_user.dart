class AuthUser {
  const AuthUser({
    required this.id,
    required this.email,
    this.displayName = '',
    this.nickname = '',
    this.avatar,
  });

  final String id;
  final String email;
  final String displayName;
  final String nickname;
  final String? avatar;

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    return AuthUser(
      id: json['id']?.toString() ?? '',
      email: json['email'] as String? ?? '',
      displayName: json['display_name'] as String? ?? '',
      nickname: json['nickname'] as String? ?? '',
      avatar: json['avatar'] as String?,
    );
  }
}

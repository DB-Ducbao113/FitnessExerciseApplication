class AppUser {
  final String id;
  final String email;
  final bool profileCompleted;
  final DateTime createdAt;

  AppUser({
    required this.id,
    required this.email,
    required this.profileCompleted,
    required this.createdAt,
  });
}

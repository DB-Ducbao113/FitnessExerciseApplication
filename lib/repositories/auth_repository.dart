import 'package:fitness_exercise_application/models/app_user.dart';

abstract class AuthRepository {
  Future<AppUser?> getCurrentUser();
  Future<void> signOut();
}

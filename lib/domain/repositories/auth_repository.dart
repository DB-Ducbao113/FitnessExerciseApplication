import 'package:fitness_exercise_application/domain/entities/app_user.dart';

abstract class AuthRepository {
  Future<AppUser?> getCurrentUser();
  Future<void> signOut();
}

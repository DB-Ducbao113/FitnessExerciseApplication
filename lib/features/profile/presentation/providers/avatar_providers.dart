import 'dart:io';

import 'package:fitness_exercise_application/core/providers/app_providers.dart';
import 'package:fitness_exercise_application/features/profile/domain/entities/user_profile.dart';
import 'package:fitness_exercise_application/features/profile/presentation/providers/user_profile_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AvatarState {
  final bool isUploading;
  final String? errorMessage;

  const AvatarState({this.isUploading = false, this.errorMessage});

  AvatarState copyWith({bool? isUploading, String? errorMessage}) =>
      AvatarState(
        isUploading: isUploading ?? this.isUploading,
        errorMessage: errorMessage,
      );
}

final currentUserProfileProvider = Provider<AsyncValue<UserProfile?>>((ref) {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) {
    return const AsyncValue.data(null);
  }
  return ref.watch(userProfileProvider(userId));
});

final avatarUploadProvider =
    StateNotifierProvider<AvatarUploadNotifier, AvatarState>(
      (ref) => AvatarUploadNotifier(ref),
    );

class AvatarUploadNotifier extends StateNotifier<AvatarState> {
  final Ref _ref;
  final _picker = ImagePicker();

  AvatarUploadNotifier(this._ref) : super(const AvatarState());

  Future<void> pickAndUpload(ImageSource source) async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    final picked = await _picker.pickImage(
      source: source,
      imageQuality: 75,
      maxWidth: 800,
      maxHeight: 800,
    );
    if (picked == null) return;

    state = state.copyWith(isUploading: true, errorMessage: null);

    try {
      final file = File(picked.path);
      final remoteDatasource = _ref.read(userProfileRemoteDataSourceProvider);
      final publicUrl = await remoteDatasource.uploadAvatar(userId, file);

      await remoteDatasource.updateAvatarUrl(userId, publicUrl);
      _ref.invalidate(userProfileProvider(userId));

      state = state.copyWith(isUploading: false);
    } catch (e) {
      state = state.copyWith(
        isUploading: false,
        errorMessage: 'Upload failed: ${e.toString()}',
      );
    }
  }
}

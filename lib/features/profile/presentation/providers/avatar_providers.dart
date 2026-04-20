import 'dart:io';

import 'package:fitness_exercise_application/core/providers/app_providers.dart';
import 'package:fitness_exercise_application/features/profile/domain/entities/user_profile.dart';
import 'package:fitness_exercise_application/features/profile/presentation/providers/user_profile_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:photo_manager/photo_manager.dart';
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

    state = state.copyWith(errorMessage: null);

    final profile = _ref.read(currentUserProfileProvider).valueOrNull;
    if (profile == null) {
      state = state.copyWith(
        errorMessage: 'Complete your profile before adding a photo.',
      );
      return;
    }

    final permissionError = await _requestImagePermission(source);
    if (permissionError != null) {
      state = state.copyWith(errorMessage: permissionError);
      return;
    }

    try {
      final picked = await _picker.pickImage(
        source: source,
        imageQuality: 75,
        maxWidth: 800,
        maxHeight: 800,
      );
      if (picked == null) return;

      state = state.copyWith(isUploading: true, errorMessage: null);

      final file = File(picked.path);
      final remoteDatasource = _ref.read(userProfileRemoteDataSourceProvider);
      final repository = _ref.read(userProfileRepositoryProvider);
      final publicUrl = await remoteDatasource.uploadAvatar(userId, file);

      await remoteDatasource.updateAvatarUrl(userId, publicUrl);
      await repository.cacheLocal(
        profile.copyWith(avatarUrl: publicUrl, updatedAt: DateTime.now()),
      );
      _ref.invalidate(userProfileProvider(userId));

      state = state.copyWith(isUploading: false);
    } on StorageException catch (e) {
      state = state.copyWith(
        isUploading: false,
        errorMessage: _storageErrorMessage(e),
      );
    } on PostgrestException catch (e) {
      state = state.copyWith(
        isUploading: false,
        errorMessage: _profileUpdateErrorMessage(e),
      );
    } catch (e) {
      state = state.copyWith(
        isUploading: false,
        errorMessage: 'Could not upload your photo.',
      );
    }
  }

  Future<String?> _requestImagePermission(ImageSource source) async {
    if (source == ImageSource.camera) {
      final status = await Permission.camera.request();
      if (status.isGranted) return null;
      if (status.isPermanentlyDenied) {
        return 'Camera access is blocked. Allow it in Settings.';
      }
      return 'Camera access is needed to take a photo.';
    }

    if (Platform.isIOS) {
      final ps = await PhotoManager.requestPermissionExtend(
        requestOption: const PermissionRequestOption(
          iosAccessLevel: IosAccessLevel.readWrite,
        ),
      );
      if (ps.isAuth) return null;
      if (ps == PermissionState.limited) {
        return 'Full photo access is needed. Change Photos to Full Access in Settings.';
      }

      final status = await Permission.photos.status;
      if (status.isPermanentlyDenied) {
        return 'Photo access is blocked. Allow Full Access in Settings.';
      }
      return 'Photo access is needed to choose an image.';
    }

    return null;
  }

  String _storageErrorMessage(StorageException error) {
    final message = error.message.toLowerCase();
    if (message.contains('row-level security') ||
        message.contains('not allowed') ||
        message.contains('unauthorized')) {
      return 'Photo upload is blocked right now. Please sign in again.';
    }
    if (message.contains('bucket')) {
      return 'Photo storage is not ready yet. Please try again later.';
    }
    return 'Could not upload your photo.';
  }

  String _profileUpdateErrorMessage(PostgrestException error) {
    final message = error.message.toLowerCase();
    if (message.contains('row-level security') ||
        message.contains('permission')) {
      return 'Your profile could not be updated right now.';
    }
    return 'Could not update your profile photo.';
  }
}

import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fitness_exercise_application/features/profile/presentation/providers/user_profile_providers.dart';
import 'package:fitness_exercise_application/features/profile/domain/entities/user_profile.dart';

// ─── Avatar notifier state ────────────────────────────────────────
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

// ─── Single source of truth: current user's profile ──────────────
// This provider is watched by both ProfileScreen and AppHeader.
// When the avatar is updated here, both screens rebuild automatically.
final currentUserProfileProvider =
    StateNotifierProvider<CurrentUserProfileNotifier, AsyncValue<UserProfile?>>(
      (ref) => CurrentUserProfileNotifier(ref),
    );

class CurrentUserProfileNotifier
    extends StateNotifier<AsyncValue<UserProfile?>> {
  final Ref _ref;

  CurrentUserProfileNotifier(this._ref) : super(const AsyncValue.loading()) {
    _load();
  }

  Future<void> _load() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      state = const AsyncValue.data(null);
      return;
    }
    try {
      final repo = _ref.read(userProfileRepositoryProvider);
      final profile = await repo.getProfile(userId);
      state = AsyncValue.data(profile);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> refresh() => _load();

  /// After a local edit (e.g., profile setup screen saves to DB),
  /// call this to reload from the server.
  Future<void> invalidateAndRefresh() => _load();

  /// Update the profile in-memory immediately after avatar upload
  /// (optimistic update — no extra network round-trip needed).
  void patchAvatarUrl(String url) {
    final current = state.valueOrNull;
    if (current == null) return;
    state = AsyncValue.data(current.copyWith(avatarUrl: url));
  }
}

// ─── Avatar upload notifier ───────────────────────────────────────
final avatarUploadProvider =
    StateNotifierProvider<AvatarUploadNotifier, AvatarState>(
      (ref) => AvatarUploadNotifier(ref),
    );

class AvatarUploadNotifier extends StateNotifier<AvatarState> {
  final Ref _ref;
  final _picker = ImagePicker();

  AvatarUploadNotifier(this._ref) : super(const AvatarState());

  /// Pick from [source] (gallery or camera), upload, and update DB + state.
  Future<void> pickAndUpload(ImageSource source) async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    // 1. Pick image
    final picked = await _picker.pickImage(
      source: source,
      imageQuality: 75, // compress to ~75% quality before upload
      maxWidth: 800,
      maxHeight: 800,
    );
    if (picked == null) return; // user cancelled

    state = state.copyWith(isUploading: true, errorMessage: null);

    try {
      final file = File(picked.path);

      // 2. Upload to Supabase Storage → get public URL
      final remoteDatasource = _ref.read(userProfileRemoteDataSourceProvider);
      final publicUrl = await remoteDatasource.uploadAvatar(userId, file);

      // 3. Persist URL to user_profiles.avatar_url
      await remoteDatasource.updateAvatarUrl(userId, publicUrl);

      // 4. Optimistic update: patch in-memory state immediately
      _ref.read(currentUserProfileProvider.notifier).patchAvatarUrl(publicUrl);

      state = state.copyWith(isUploading: false);
    } catch (e) {
      state = state.copyWith(
        isUploading: false,
        errorMessage: 'Upload failed: ${e.toString()}',
      );
    }
  }
}

import 'dart:typed_data';

import 'package:fitness_exercise_application/features/profile/data/datasources/remote/user_profile_remote_datasource.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('avatar validation accepts JPEG magic bytes within size limit', () {
    final bytes = Uint8List.fromList([0xff, 0xd8, 0xff, 0xe0, 0x00]);
    expect(isValidAvatarJpeg(bytes), isTrue);
  });

  test('avatar validation rejects spoofed or oversized content', () {
    expect(
      isValidAvatarJpeg(Uint8List.fromList([0x89, 0x50, 0x4e, 0x47])),
      isFalse,
    );
    expect(isValidAvatarJpeg(Uint8List(5 * 1024 * 1024 + 1)), isFalse);
  });

  test('avatar path extraction supports private paths and old public URLs', () {
    expect(
      avatarStoragePathFromValue('user-1/avatar-123.jpg'),
      'user-1/avatar-123.jpg',
    );
    expect(
      avatarStoragePathFromValue(
        'https://project.supabase.co/storage/v1/object/public/avatars/user-1/avatar.jpg',
      ),
      'user-1/avatar.jpg',
    );
    expect(avatarStoragePathFromValue('../secret'), isNull);
  });
}

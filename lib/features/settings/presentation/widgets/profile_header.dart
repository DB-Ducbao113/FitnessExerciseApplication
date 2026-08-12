import 'dart:io';

import 'package:fitness_exercise_application/core/localization/app_translations.dart';
import 'package:fitness_exercise_application/features/profile/presentation/providers/avatar_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const _panel = Color(0xFF112033);
const _border = Color(0x2200E5FF);
const _muted = Color(0xFF8A96A9);
const _cyan = Color(0xFF19E2FF);
const _blue = Color(0xFF0D5DFF);

class ProfileHeader extends ConsumerWidget {
  final String name;
  final String handle;

  const ProfileHeader({super.key, required this.name, required this.handle});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentLang = ref.watch(appLanguageProvider);
    final avatar = ref.watch(currentAvatarDisplayProvider);
    final ImageProvider? avatarImage = avatar.localPath != null
        ? FileImage(File(avatar.localPath!))
        : avatar.remoteUrl != null && avatar.remoteUrl!.isNotEmpty
        ? NetworkImage(avatar.remoteUrl!)
        : null;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _panel,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 78,
            height: 78,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  _cyan.withValues(alpha: 0.18),
                  _blue.withValues(alpha: 0.12),
                ],
              ),
              border: Border.all(color: _cyan.withValues(alpha: 0.45)),
            ),
            child: Center(
              child: CircleAvatar(
                radius: 28,
                backgroundColor: const Color(0xFF102031),
                backgroundImage: avatarImage,
                child: avatarImage == null
                    ? ClipOval(
                        child: Image.asset(
                          'assets/screen.png',
                          width: 56,
                          height: 56,
                          fit: BoxFit.cover,
                        ),
                      )
                    : null,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppTranslations.get('account', currentLang),
                  style: const TextStyle(
                    color: _muted,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.8,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if (handle.trim().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    handle,
                    style: const TextStyle(
                      fontSize: 14,
                      color: _muted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

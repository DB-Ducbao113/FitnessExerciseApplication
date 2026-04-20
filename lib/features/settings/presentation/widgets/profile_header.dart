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
  final String email;

  const ProfileHeader({super.key, required this.name, required this.email});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(currentUserProfileProvider);
    final avatarUrl = profileAsync.valueOrNull?.avatarUrl;

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
                backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty
                    ? NetworkImage(avatarUrl)
                    : null,
                child: avatarUrl == null || avatarUrl.isEmpty
                    ? const Icon(Icons.person, size: 30, color: _cyan)
                    : null,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'ACCOUNT',
                  style: TextStyle(
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
                const SizedBox(height: 4),
                Text(
                  email,
                  style: const TextStyle(
                    fontSize: 14,
                    color: _muted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

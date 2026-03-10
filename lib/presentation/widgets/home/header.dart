import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fitness_exercise_application/presentation/providers/avatar_providers.dart';

/// AppHeader is now a [ConsumerWidget] so it can watch [currentUserProfileProvider]
/// and display the real user avatar from Supabase Storage.
/// Both ProfileScreen and AppHeader subscribe to [currentUserProfileProvider],
/// so updating the avatar in Profile automatically refreshes the header on Home.
class AppHeader extends ConsumerWidget {
  final VoidCallback? onMenuTap;

  const AppHeader({super.key, this.onMenuTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(currentUserProfileProvider);
    final user = Supabase.instance.client.auth.currentUser;

    final avatarUrl = profileAsync.valueOrNull?.avatarUrl;
    final displayName = user?.email?.split('@').first ?? 'User';

    return SizedBox(
      width: double.infinity,
      height: 200,
      child: Stack(
        children: [
          CustomPaint(
            painter: HeaderPainter(),
            size: const Size(double.infinity, 200),
          ),
          // Menu button
          Positioned(
            top: 20,
            left: 20,
            child: IconButton(
              onPressed: onMenuTap,
              icon: const Icon(Icons.menu, color: Colors.white),
            ),
          ),
          // Live avatar (top-right)
          Positioned(
            top: 25,
            right: 30,
            child: GestureDetector(
              onTap: onMenuTap, // navigate to profile on avatar tap
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: CircleAvatar(
                  radius: 32,
                  backgroundColor: const Color(0xffe8f7fd),
                  backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty
                      ? NetworkImage(avatarUrl)
                      : null,
                  child: avatarUrl == null || avatarUrl.isEmpty
                      ? const Icon(
                          Icons.person,
                          size: 32,
                          color: Color(0xff18b0e8),
                        )
                      : null,
                ),
              ),
            ),
          ),
          // Greeting text
          Positioned(
            left: 33,
            bottom: 20,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Hello',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w400,
                    fontSize: 20,
                    letterSpacing: 0.5,
                    shadows: [
                      Shadow(
                        color: Colors.black26,
                        blurRadius: 8,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  displayName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 26,
                    letterSpacing: 0.5,
                    shadows: [
                      Shadow(
                        color: Colors.black26,
                        blurRadius: 8,
                        offset: Offset(0, 2),
                      ),
                    ],
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

class HeaderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final gradient = const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xff00d4ff), Color(0xff0099ff), Color(0xff0066ff)],
    );

    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final paint = Paint()..shader = gradient.createShader(rect);
    canvas.drawRect(rect, paint);

    Paint circles1 = Paint()..color = Colors.white.withOpacity(0.15);
    Paint circles2 = Paint()..color = Colors.white.withOpacity(0.1);
    Paint circles3 = Paint()..color = Colors.white.withOpacity(0.08);

    canvas.drawCircle(Offset(size.width * 0.7, -20), 80, circles1);
    canvas.drawCircle(Offset(size.width * 0.85, 50), 60, circles2);
    canvas.drawCircle(Offset(size.width * 0.55, 140), 40, circles3);
    canvas.drawCircle(Offset(size.width - 30, size.height - 30), 50, circles2);
    canvas.drawCircle(Offset(20, size.height * 0.3), 30, circles3);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

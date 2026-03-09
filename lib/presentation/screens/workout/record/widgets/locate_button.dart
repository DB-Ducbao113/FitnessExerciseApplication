import 'package:flutter/material.dart';

class LocateButton extends StatelessWidget {
  final VoidCallback onPressed;
  final bool isFollowEnabled;

  const LocateButton({
    super.key,
    required this.onPressed,
    required this.isFollowEnabled,
  });

  @override
  Widget build(BuildContext context) {
    final iconColor = isFollowEnabled
        ? const Color(0xff18b0e8)
        : Colors.grey.shade700;

    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      elevation: 6,
      shadowColor: Colors.black.withValues(alpha: 0.25),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onPressed,
        child: SizedBox(
          width: 52,
          height: 52,
          child: Icon(Icons.my_location_rounded, color: iconColor, size: 24),
        ),
      ),
    );
  }
}

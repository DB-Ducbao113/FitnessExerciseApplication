import 'package:flutter/material.dart';

const _muted = Color(0xFF8A96A9);
const _cyan = Color(0xFF19E2FF);

class SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  const SettingsTile({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      minLeadingWidth: 0,
      leading: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: _cyan.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _cyan.withValues(alpha: 0.18)),
        ),
        child: Icon(icon, color: _cyan, size: 21),
      ),
      title: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 15,
          fontWeight: FontWeight.w800,
        ),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle!,
              style: const TextStyle(
                fontSize: 13,
                color: _muted,
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
            )
          : null,
      trailing:
          trailing ??
          Icon(
            Icons.chevron_right_rounded,
            color: Colors.white.withValues(alpha: 0.4),
          ),
      onTap: onTap,
    );
  }
}

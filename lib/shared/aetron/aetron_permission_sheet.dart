import 'package:fitness_exercise_application/shared/aetron/aetron_ui.dart';
import 'package:flutter/material.dart';

enum AetronPermissionKind { location, camera, photos, motion }

Future<bool> showAetronPermissionSheet(
  BuildContext context, {
  required AetronPermissionKind kind,
  String? actionLabel,
}) async {
  return await showModalBottomSheet<bool>(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (sheetContext) => _AetronPermissionSheet(
          kind: kind,
          actionLabel: actionLabel ?? 'CONTINUE',
          onCancel: () => Navigator.of(sheetContext).pop(false),
          onContinue: () => Navigator.of(sheetContext).pop(true),
        ),
      ) ??
      false;
}

class _AetronPermissionSheet extends StatelessWidget {
  const _AetronPermissionSheet({
    required this.kind,
    required this.actionLabel,
    required this.onCancel,
    required this.onContinue,
  });

  final AetronPermissionKind kind;
  final String actionLabel;
  final VoidCallback onCancel;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final content = switch (kind) {
      AetronPermissionKind.location => (
        Icons.location_on_rounded,
        'ENABLE LOCATION',
        'Location keeps your route, distance, pace, and GPS signal accurate during outdoor workouts.',
        'Used only while a workout is active.',
      ),
      AetronPermissionKind.camera => (
        Icons.photo_camera_rounded,
        'ENABLE CAMERA',
        'Camera access lets you take a profile photo directly in Aetron.',
        'Used only when you choose to update your profile image.',
      ),
      AetronPermissionKind.photos => (
        Icons.photo_library_rounded,
        'ENABLE PHOTO LIBRARY',
        'Photo access lets you choose a profile image from your library.',
        'Used only for the image you select.',
      ),
      AetronPermissionKind.motion => (
        Icons.directions_run_rounded,
        'ENABLE MOTION DATA',
        'Motion access supports step tracking when GPS is unavailable or not needed.',
        'Used only during a workout session.',
      ),
    };

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 22),
        decoration: BoxDecoration(
          color: AetronColors.panel,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
          border: Border(top: BorderSide(color: AetronColors.border)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.42),
              blurRadius: 28,
              offset: const Offset(0, -10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: AetronColors.muted.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: AetronColors.cyan.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AetronColors.border),
              ),
              child: Icon(content.$1, color: AetronColors.cyan, size: 26),
            ),
            const SizedBox(height: 16),
            Text(content.$2, style: AetronText.section.copyWith(fontSize: 12)),
            const SizedBox(height: 10),
            Text(
              content.$3,
              style: const TextStyle(
                color: AetronColors.text,
                fontSize: 15,
                height: 1.35,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              content.$4,
              style: const TextStyle(
                color: AetronColors.muted,
                fontSize: 12,
                height: 1.35,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: onCancel,
                    style: TextButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                      foregroundColor: AetronColors.muted,
                    ),
                    child: const Text('NOT NOW'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    onPressed: onContinue,
                    icon: const Icon(Icons.arrow_forward_rounded),
                    label: Text(actionLabel),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                      backgroundColor: AetronColors.cyan,
                      foregroundColor: AetronColors.space,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

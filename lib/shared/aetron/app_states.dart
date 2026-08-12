import 'package:fitness_exercise_application/shared/aetron/aetron_ui.dart';
import 'package:flutter/material.dart';

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.title,
    this.description,
    this.icon = Icons.inbox_outlined,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String? description;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AetronSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AetronColors.cyan.withValues(alpha: 0.1),
                shape: BoxShape.circle,
                border: Border.all(color: AetronColors.cyan.withValues(alpha: 0.25)),
              ),
              child: Icon(icon, color: AetronColors.cyanSoft, size: 36),
            ),
            const SizedBox(height: 20),
            Text(
              title.toUpperCase(),
              textAlign: TextAlign.center,
              style: AetronTypography.headingMedium.copyWith(
                color: AetronColors.textPrimary,
                letterSpacing: 1.1,
              ),
            ),
            if (description != null) ...[
              const SizedBox(height: 8),
              Text(
                description!,
                textAlign: TextAlign.center,
                style: AetronTypography.bodySmall.copyWith(
                  color: AetronColors.textSecondary,
                  height: 1.4,
                ),
              ),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 24),
              AppButton(
                label: actionLabel!,
                onPressed: onAction,
                fullWidth: false,
                height: 44,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class LoadingState extends StatelessWidget {
  const LoadingState({
    super.key,
    this.label = 'LOADING',
    this.message,
  });

  final String label;
  final String? message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AetronSpacing.lg),
        child: AetronLoadingPanel(label: label, message: message),
      ),
    );
  }
}

class ErrorState extends StatelessWidget {
  const ErrorState({
    super.key,
    required this.title,
    required this.message,
    this.onRetry,
    this.isOffline = false,
  });

  final String title;
  final String message;
  final VoidCallback? onRetry;
  final bool isOffline;

  @override
  Widget build(BuildContext context) {
    final accent = isOffline ? AetronColors.warning : AetronColors.error;
    final icon = isOffline ? Icons.cloud_off_rounded : Icons.error_outline_rounded;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AetronSpacing.lg),
        child: AppCard(
          borderColor: accent.withValues(alpha: 0.4),
          backgroundColor: AetronColors.panel.withValues(alpha: 0.9),
          padding: const EdgeInsets.all(AetronSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AetronRadius.medium),
                ),
                child: Icon(icon, color: accent, size: 26),
              ),
              const SizedBox(height: 16),
              Text(
                title.toUpperCase(),
                style: AetronTypography.headingMedium.copyWith(
                  color: AetronColors.textPrimary,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                style: AetronTypography.bodySmall.copyWith(
                  color: AetronColors.textSecondary,
                  height: 1.4,
                ),
              ),
              if (onRetry != null) ...[
                const SizedBox(height: 20),
                AppButton(
                  label: 'RETRY',
                  onPressed: onRetry,
                  variant: AppButtonVariant.outlined,
                  icon: Icons.refresh_rounded,
                  height: 44,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

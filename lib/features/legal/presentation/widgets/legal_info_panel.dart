import 'package:fitness_exercise_application/core/localization/app_translations.dart';
import 'package:fitness_exercise_application/shared/aetron/aetron_ui.dart';
import 'package:flutter/material.dart';

/// A restrained, document-appropriate information panel for Health & Fitness Disclaimers.
/// Styled with a dark slate surface, subtle cyan border, and high-readability body text.
class LegalInfoPanel extends StatelessWidget {
  const LegalInfoPanel({
    super.key,
    this.title,
    this.message,
    this.lang = AppLanguage.en,
  });

  final String? title;
  final String? message;
  final AppLanguage lang;

  @override
  Widget build(BuildContext context) {
    final displayTitle = title ??
        (lang == AppLanguage.vi
            ? 'Cảnh báo Sức khỏe & Thể thao'
            : 'Fitness & Health Disclaimer');
    final displayMessage = message ??
        (lang == AppLanguage.vi
            ? 'Aetron được thiết kế để hỗ trợ theo dõi và phân tích các hoạt động thể thao cá nhân. Ứng dụng không phải là thiết bị y tế và không đưa ra lời khuyên, chẩn đoán hay phác đồ điều trị y khoa. Bạn nên tham khảo ý kiến bác sĩ trước khi bắt đầu hoặc thay đổi bất kỳ chương trình tập luyện cường độ cao nào.'
            : 'Aetron is designed to help you track and understand your fitness activities. It is not a medical device and does not provide medical advice, diagnosis, or treatment. Always consult a physician before starting any vigorous exercise program.');

    return AppCard(
      padding: const EdgeInsets.all(AetronSpacing.md + 2),
      backgroundColor: AetronColors.panel,
      borderColor: AetronColors.cyan.withValues(alpha: 0.3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AetronColors.cyan.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.info_outline_rounded,
              color: AetronColors.cyan,
              size: 20,
            ),
          ),
          const SizedBox(width: AetronSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayTitle,
                  style: AetronTypography.headingSmall.copyWith(
                    color: AetronColors.textPrimary,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  displayMessage,
                  style: AetronTypography.body.copyWith(
                    color: AetronColors.textSecondary,
                    fontSize: 13.5,
                    height: 1.55,
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

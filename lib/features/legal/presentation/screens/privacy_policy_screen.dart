import 'package:fitness_exercise_application/core/legal/legal_documents.dart';
import 'package:fitness_exercise_application/core/localization/app_translations.dart';
import 'package:fitness_exercise_application/features/legal/presentation/widgets/legal_document_layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Full-screen, document-oriented Privacy Policy screen designed for calm, long-form reading.
class PrivacyPolicyScreen extends ConsumerWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentLang = ref.watch(appLanguageProvider);
    final sections = LegalDocuments.getPrivacyPolicy(currentLang);
    final title = AppTranslations.get('privacy_policy', currentLang);

    return LegalDocumentLayout(
      title: title,
      lastUpdated: 'July 2026',
      sections: sections,
      lang: currentLang,
      showDisclaimer: true,
    );
  }
}

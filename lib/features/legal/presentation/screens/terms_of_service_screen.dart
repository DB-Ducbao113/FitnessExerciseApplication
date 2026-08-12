import 'package:fitness_exercise_application/core/legal/legal_documents.dart';
import 'package:fitness_exercise_application/core/localization/app_translations.dart';
import 'package:fitness_exercise_application/features/legal/presentation/widgets/legal_document_layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Full-screen, document-oriented Terms of Service screen designed for calm, long-form reading.
class TermsOfServiceScreen extends ConsumerWidget {
  const TermsOfServiceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentLang = ref.watch(appLanguageProvider);
    final sections = LegalDocuments.getTermsOfService(currentLang);
    final title = AppTranslations.get('terms_of_service', currentLang);

    return LegalDocumentLayout(
      title: title,
      lastUpdated: 'July 2026',
      sections: sections,
      lang: currentLang,
      showDisclaimer: true,
    );
  }
}

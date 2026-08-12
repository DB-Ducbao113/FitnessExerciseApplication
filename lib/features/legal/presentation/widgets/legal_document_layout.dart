import 'package:fitness_exercise_application/core/legal/legal_documents.dart';
import 'package:fitness_exercise_application/core/localization/app_translations.dart';
import 'package:fitness_exercise_application/features/legal/presentation/widgets/legal_info_panel.dart';
import 'package:fitness_exercise_application/shared/aetron/aetron_ui.dart';
import 'package:flutter/material.dart';

/// Clean, document-oriented layout component for long-form legal reading.
/// Designed for high readability, calm aesthetics, and natural scrolling.
class LegalDocumentLayout extends StatelessWidget {
  const LegalDocumentLayout({
    super.key,
    required this.title,
    required this.lastUpdated,
    required this.sections,
    required this.lang,
    this.showDisclaimer = true,
  });

  final String title;
  final String lastUpdated;
  final List<LegalDocumentSection> sections;
  final AppLanguage lang;
  final bool showDisclaimer;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AetronColors.background,
      body: AetronBackground(
        withGrid: false,
        child: SafeArea(
          child: Column(
            children: [
              // Standard Document Header with Back Button
              AetronHeader(
                title: title.toUpperCase(),
                eyebrow: 'LEGAL DOCUMENT',
                leading: IconButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                  icon: const Icon(
                    Icons.arrow_back_rounded,
                    color: AetronColors.textPrimary,
                  ),
                ),
              ),

              // Main Document Scroll View
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AetronSpacing.page,
                    vertical: AetronSpacing.md,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Document Metadata Banner
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AetronColors.cyan.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(AetronRadius.small),
                              border: Border.all(
                                color: AetronColors.cyan.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Text(
                              'OFFICIAL DOCUMENT',
                              style: AetronTypography.caption.copyWith(
                                color: AetronColors.cyan,
                                fontWeight: FontWeight.w800,
                                fontSize: 10,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ),
                          const SizedBox(width: AetronSpacing.sm),
                          Text(
                            '${lang == AppLanguage.vi ? 'Cập nhật lần cuối' : 'Last updated'}: $lastUpdated',
                            style: AetronTypography.bodySmall.copyWith(
                              color: AetronColors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AetronSpacing.lg),

                      // Restrained Fitness & Health Disclaimer Info Panel
                      if (showDisclaimer) ...[
                        LegalInfoPanel(lang: lang),
                        const SizedBox(height: AetronSpacing.xl),
                      ],

                      // Compact "ON THIS PAGE" Table of Contents List
                      _TableOfContents(sections: sections, lang: lang),
                      const SizedBox(height: AetronSpacing.xxl),

                      const Divider(
                        color: AetronColors.borderSubtle,
                        height: 1,
                      ),
                      const SizedBox(height: AetronSpacing.xxl),

                      // Document Sections List (High-readability typography)
                      for (var i = 0; i < sections.length; i++) ...[
                        _LegalSectionBlock(
                          index: i + 1,
                          section: sections[i],
                        ),
                        if (i != sections.length - 1)
                          const SizedBox(height: AetronSpacing.xxl),
                      ],

                      const SizedBox(height: AetronSpacing.xxl),
                      Center(
                        child: Text(
                          '— ${lang == AppLanguage.vi ? 'Hết tài liệu' : 'End of Document'} —',
                          style: AetronTypography.caption.copyWith(
                            color: AetronColors.muted,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const SizedBox(height: AetronSpacing.page),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TableOfContents extends StatelessWidget {
  const _TableOfContents({
    required this.sections,
    required this.lang,
  });

  final List<LegalDocumentSection> sections;
  final AppLanguage lang;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AetronSpacing.md),
      backgroundColor: AetronColors.space.withValues(alpha: 0.6),
      borderColor: AetronColors.borderSubtle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.list_alt_rounded,
                color: AetronColors.textSecondary,
                size: 16,
              ),
              const SizedBox(width: 6),
              Text(
                'ON THIS PAGE',
                style: AetronTypography.caption.copyWith(
                  color: AetronColors.textSecondary,
                  fontWeight: FontWeight.w800,
                  fontSize: 11,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: AetronSpacing.xs),
          const Divider(color: AetronColors.borderSubtle, height: 12),
          const SizedBox(height: 4),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: sections.map((sec) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    Container(
                      width: 5,
                      height: 5,
                      decoration: const BoxDecoration(
                        color: AetronColors.cyan,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        sec.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AetronTypography.bodySmall.copyWith(
                          color: AetronColors.textSecondary,
                          fontSize: 12.5,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _LegalSectionBlock extends StatelessWidget {
  const _LegalSectionBlock({
    required this.index,
    required this.section,
  });

  final int index;
  final LegalDocumentSection section;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Title (18-20px Bold, Readable)
        Text(
          section.title,
          style: AetronTypography.headingMedium.copyWith(
            color: AetronColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w800,
            height: 1.3,
          ),
        ),
        const SizedBox(height: AetronSpacing.sm),

        // Section Body Content (Sentence Case, Line Height 1.6, Highly Readable)
        SelectableText(
          section.content,
          style: AetronTypography.body.copyWith(
            color: AetronColors.textPrimary.withValues(alpha: 0.9),
            fontSize: 14.5,
            height: 1.65,
            letterSpacing: 0.15,
          ),
        ),
      ],
    );
  }
}

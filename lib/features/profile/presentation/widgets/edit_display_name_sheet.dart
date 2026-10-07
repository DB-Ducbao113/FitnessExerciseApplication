import 'package:fitness_exercise_application/core/localization/app_translations.dart';
import 'package:fitness_exercise_application/shared/aetron/aetron_feedback.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Shows the Cyber Display Name edit modal bottom sheet
Future<bool?> showEditDisplayNameSheet(
  BuildContext context, {
  String? currentName,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (ctx) => EditDisplayNameSheet(initialName: currentName),
  );
}

class EditDisplayNameSheet extends ConsumerStatefulWidget {
  final String? initialName;

  const EditDisplayNameSheet({super.key, this.initialName});

  @override
  ConsumerState<EditDisplayNameSheet> createState() =>
      _EditDisplayNameSheetState();
}

class _EditDisplayNameSheetState extends ConsumerState<EditDisplayNameSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  bool _isSaving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    String fallbackName = '';
    try {
      final user = Supabase.instance.client.auth.currentUser;
      fallbackName = user?.userMetadata?['display_name'] as String? ??
          user?.userMetadata?['full_name'] as String? ??
          user?.userMetadata?['name'] as String? ??
          '';
    } catch (_) {
      // Supabase instance might not be initialized in test environments
    }
    _nameController = TextEditingController(
      text: widget.initialName?.trim() ?? fallbackName.trim(),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _saveName() async {
    if (!_formKey.currentState!.validate()) return;
    final lang = ref.read(appLanguageProvider);
    final newName = _nameController.text.trim();

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(data: {'display_name': newName}),
      );

      if (mounted) {
        Navigator.of(context).pop(true);
        showAetronNotice(
          context,
          message: AppTranslations.get('name_updated_success', lang),
          tone: AetronNoticeTone.success,
        );
      }
    } on AuthException catch (error) {
      if (mounted) {
        setState(() => _errorMessage = error.message);
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _errorMessage = lang == AppLanguage.vi
              ? 'Không thể lưu tên gọi. Vui lòng thử lại.'
              : 'Could not update display name. Try again.',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.kinetic;
    final currentLang = ref.watch(appLanguageProvider);
    final isVi = currentLang == AppLanguage.vi;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      padding: EdgeInsets.fromLTRB(20, 16, 20, 24 + bottomInset),
      decoration: BoxDecoration(
        color: colors.surface1,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: colors.borderSubtle,
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 28,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: colors.primary.withValues(alpha: 0.12),
            blurRadius: 24,
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top Grab Handle
            Align(
              alignment: Alignment.center,
              child: Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.borderSubtle,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 18),

            // Header Row
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: colors.primary.withValues(alpha: 0.12),
                    border: Border.all(
                      color: colors.primary.withValues(alpha: 0.45),
                    ),
                  ),
                  child: Icon(
                    Icons.badge_outlined,
                    color: colors.primary,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppTranslations.get('edit_display_name', currentLang),
                        style: TextStyle(
                          fontFamily: 'Plus Jakarta Sans',
                          color: colors.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isVi
                            ? 'Tên này sẽ hiển thị trên trang chủ và bảng xếp hạng'
                            : 'This name will appear on home and leaderboards',
                        style: TextStyle(
                          fontFamily: 'Plus Jakarta Sans',
                          color: colors.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Input Field
            TextFormField(
              controller: _nameController,
              autofocus: true,
              maxLength: 30,
              textCapitalization: TextCapitalization.words,
              style: TextStyle(
                fontFamily: 'Plus Jakarta Sans',
                color: colors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
              decoration: InputDecoration(
                labelText: AppTranslations.get('display_name', currentLang),
                labelStyle: TextStyle(
                  fontFamily: 'Plus Jakarta Sans',
                  color: colors.primary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
                hintText: AppTranslations.get('display_name_hint', currentLang),
                hintStyle: TextStyle(
                  fontFamily: 'Plus Jakarta Sans',
                  color: colors.textMuted,
                  fontSize: 14,
                ),
                prefixIcon: Icon(
                  Icons.person_outline_rounded,
                  color: colors.primary,
                  size: 20,
                ),
                suffixIcon: _nameController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 18),
                        color: colors.textSecondary,
                        onPressed: () {
                          setState(() {
                            _nameController.clear();
                          });
                        },
                      )
                    : null,
                filled: true,
                fillColor: colors.surface2,
                counterStyle: TextStyle(
                  fontFamily: 'Plus Jakarta Sans',
                  color: colors.textSecondary,
                  fontSize: 11,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(
                    color: colors.borderSubtle,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(
                    color: colors.primary,
                    width: 1.5,
                  ),
                ),
                errorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(
                    color: colors.error,
                    width: 1.2,
                  ),
                ),
                focusedErrorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(
                    color: colors.error,
                    width: 1.5,
                  ),
                ),
              ),
              validator: (value) {
                final trimmed = value?.trim() ?? '';
                if (trimmed.isEmpty) {
                  return AppTranslations.get(
                    'display_name_empty',
                    currentLang,
                  );
                }
                if (trimmed.length < 2) {
                  return isVi
                      ? 'Tên hiển thị phải có ít nhất 2 ký tự'
                      : 'Display name must have at least 2 characters';
                }
                return null;
              },
              onChanged: (_) => setState(() {}),
            ),

            if (_errorMessage != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: colors.error.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: colors.error.withValues(alpha: 0.4),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.error_outline_rounded,
                      color: colors.error,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: TextStyle(
                          fontFamily: 'Plus Jakarta Sans',
                          color: colors.error,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 18),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isSaving
                        ? null
                        : () => Navigator.of(context).pop(false),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: colors.textSecondary,
                      side: BorderSide(
                        color: colors.borderSubtle,
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Text(
                      AppTranslations.get('cancel', currentLang),
                      style: TextStyle(
                        fontFamily: 'Plus Jakarta Sans',
                        color: colors.textSecondary,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      gradient: LinearGradient(
                        colors: [colors.primary, colors.secondary],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: colors.primary.withValues(alpha: 0.35),
                          blurRadius: 14,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _saveName,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        foregroundColor: colors.onPrimary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: _isSaving
                          ? SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.2,
                                color: colors.onPrimary,
                              ),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.check_rounded, size: 18, color: colors.onPrimary),
                                const SizedBox(width: 6),
                                Text(
                                  AppTranslations.get(
                                    'save_changes',
                                    currentLang,
                                  ),
                                  style: TextStyle(
                                    fontFamily: 'Plus Jakarta Sans',
                                    color: colors.onPrimary,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ],
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

import 'package:fitness_exercise_application/shared/aetron/aetron_ui.dart';
import 'package:flutter/material.dart';

class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    this.controller,
    this.label,
    this.hintText,
    this.errorText,
    this.obscureText = false,
    this.keyboardType,
    this.prefixIcon,
    this.suffixIcon,
    this.enabled = true,
    this.readOnly = false,
    this.onChanged,
    this.validator,
    this.maxLines = 1,
    this.focusNode,
  });

  final TextEditingController? controller;
  final String? label;
  final String? hintText;
  final String? errorText;
  final bool obscureText;
  final TextInputType? keyboardType;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final bool enabled;
  final bool readOnly;
  final ValueChanged<String>? onChanged;
  final String? Function(String?)? validator;
  final int maxLines;
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label != null) ...[
          Text(
            label!.toUpperCase(),
            style: AetronTypography.label.copyWith(
              color: AetronColors.textSecondary,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 8),
        ],
        TextFormField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          enabled: enabled,
          readOnly: readOnly,
          onChanged: onChanged,
          validator: validator,
          maxLines: maxLines,
          focusNode: focusNode,
          style: AetronTypography.body.copyWith(color: AetronColors.textPrimary),
          decoration: InputDecoration(
            hintText: hintText,
            errorText: errorText,
            prefixIcon: prefixIcon,
            suffixIcon: suffixIcon,
            filled: true,
            fillColor: AetronColors.panelHigh,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            hintStyle: AetronTypography.body.copyWith(
              color: AetronColors.textSecondary.withValues(alpha: 0.6),
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AetronRadius.medium),
              borderSide: const BorderSide(color: AetronColors.borderSubtle),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AetronRadius.medium),
              borderSide: const BorderSide(color: AetronColors.borderSubtle),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AetronRadius.medium),
              borderSide: const BorderSide(color: AetronColors.cyan, width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AetronRadius.medium),
              borderSide: const BorderSide(color: AetronColors.danger),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AetronRadius.medium),
              borderSide: const BorderSide(color: AetronColors.danger, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}

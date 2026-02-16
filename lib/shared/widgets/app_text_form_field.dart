import 'package:flutter/material.dart';
import 'package:mendlify/core/utils/theme/app_colors.dart';
import 'package:flutter/services.dart';

class AppTextFormField extends StatelessWidget {
  const AppTextFormField({
    super.key,
    required this.controller,
    this.focusNode,
    this.onChanged,
    this.onSubmitted,
    this.validator,
    this.textInputAction,
    this.hint,
    this.obscureText,
    this.readOnly,
    this.suffixIcon,
    this.prefixIcon,
    this.enabled,
    this.keyboardType,
    this.inputFormatters,
    this.onTap,
  });

  final TextEditingController controller;
  final FocusNode? focusNode; // ← made optional
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final String? Function(String?)? validator;
  final TextInputAction? textInputAction;
  final String? hint;
  final bool? obscureText;
  final bool? readOnly;
  final Widget? suffixIcon;
  final Widget? prefixIcon;
  final bool? enabled;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      focusNode: focusNode, // ← safe now
      onChanged: onChanged,
      onFieldSubmitted: onSubmitted,
      validator: validator,
      textInputAction: textInputAction,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      style: const TextStyle(color: appMainTextColor),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: appTextColor),
        prefixIcon: prefixIcon,
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: appCardColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.0),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.0),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.0),
          borderSide: const BorderSide(color: appButtonColor, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          vertical: 16,
          horizontal: 20,
        ),
      ),
      obscureText: obscureText ?? false,
      readOnly: readOnly ?? false,
      enabled: enabled ?? true,
      onTap: onTap,
    );
  }
}

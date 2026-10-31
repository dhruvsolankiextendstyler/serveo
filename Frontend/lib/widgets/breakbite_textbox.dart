import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../utils/theme_provider.dart';

class ServeoTextBox extends StatefulWidget {
  final String hint;
  final String? label;
  final IconData? icon;
  final bool obscure;
  final TextInputType keyboard;
  final TextEditingController cont;
  final List<TextInputFormatter>? inputFormatters;
  final String? Function(String?)? validator;
  final void Function(String)? onChanged;
  final bool enabled;

  const ServeoTextBox({
    super.key,
    required this.hint,
    this.label,
    this.icon,
    required this.cont,
    this.obscure = false,
    this.keyboard = TextInputType.text,
    this.inputFormatters,
    this.validator,
    this.onChanged,
    this.enabled = true,
  });

  @override
  State<ServeoTextBox> createState() => _ServeoTextBoxState();
}

class _ServeoTextBoxState extends State<ServeoTextBox> {
  late bool _isObscured;

  @override
  void initState() {
    super.initState();
    _isObscured = widget.obscure;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF1F2937);
    const iconColor = Color(0xFFD97706);

    return TextFormField(
      obscureText: _isObscured,
      keyboardType: widget.keyboard,
      controller: widget.cont,
      inputFormatters: widget.inputFormatters,
      validator: widget.validator,
      onChanged: widget.onChanged,
      enabled: widget.enabled,
      style: TextStyle(
        color: primaryTextColor,
        fontSize: 14,
        fontWeight: FontWeight.normal,
      ),
      decoration: AppTheme.inputDecoration(
        isDark: isDark,
        hintText: widget.hint,
        labelText: widget.label,
        prefixIcon: widget.icon != null ? Icon(widget.icon, color: iconColor, size: 20) : null,
        suffixIcon: widget.obscure
            ? IconButton(
                icon: Icon(
                  _isObscured ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                  color: isDark ? Colors.white54 : const Color(0xFF9CA3AF),
                  size: 20,
                ),
                onPressed: () => setState(() => _isObscured = !_isObscured),
              )
            : null,
      ),
    );
  }
}

typedef BreakBiteTextBox = ServeoTextBox;
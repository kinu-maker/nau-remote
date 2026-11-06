import 'package:flutter/material.dart';

const kNauAppTitle = 'NAU Remote';
const kNauLoginDomain = 'nerdyau.com';

class NauColors {
  static const background = Color(0xFF15171C);
  static const panel = Color(0xFF1E2128);
  static const panelBorder = Color(0xFF2A2E37);
  static const sidebar = Color(0xFF101216);
  static const sidebarBorder = Color(0xFF262A33);
  static const navSelected = Color(0xFF1E2330);
  static const field = Color(0xFF15171C);
  static const fieldBorder = Color(0xFF3A4050);
  static const button = Color(0xFF23262E);
  static const text = Color(0xFFF2F3F5);
  static const textSecondary = Color(0xFFA9AFBB);
  static const textMuted = Color(0xFFC9CEDA);
  static const accent = Color(0xFF2A66E0);
  static const online = Color(0xFF5FE39B);
  static const offline = Color(0xFF6B7180);
  static const danger = Color(0xFFFFA79C);
  static const canvas = Color(0xFF0B0C0F);
  static const avatar = Color(0xFF2B3040);
}

TextStyle nauText(
    {double size = 14,
    FontWeight weight = FontWeight.w400,
    Color color = NauColors.text,
    double? height}) {
  return TextStyle(
      fontSize: size, fontWeight: weight, color: color, height: height);
}

class NauLogo extends StatelessWidget {
  final double size;
  const NauLogo({Key? key, this.size = 30}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: NauColors.accent,
        borderRadius: BorderRadius.circular(size * 0.26),
      ),
      alignment: Alignment.center,
      child: Icon(Icons.desktop_windows_outlined,
          size: size * 0.58, color: Colors.white),
    );
  }
}

class NauPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  const NauPanel(
      {Key? key,
      required this.child,
      this.padding = const EdgeInsets.fromLTRB(20, 18, 20, 18)})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: NauColors.panel,
        border: Border.all(color: NauColors.panelBorder),
        borderRadius: BorderRadius.circular(12),
      ),
      child: child,
    );
  }
}

class NauButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool primary;
  final double height;
  final IconData? icon;
  const NauButton(
      {Key? key,
      required this.label,
      required this.onPressed,
      this.primary = false,
      this.height = 40,
      this.icon})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    final background = primary ? NauColors.accent : NauColors.button;
    return SizedBox(
      height: height,
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          backgroundColor: background,
          disabledBackgroundColor: background.withOpacity(0.5),
          foregroundColor: NauColors.text,
          disabledForegroundColor: NauColors.textSecondary,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(
                color: primary ? NauColors.accent : NauColors.fieldBorder),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 18),
              const SizedBox(width: 8),
            ],
            Text(label,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: primary ? FontWeight.w700 : FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}

InputDecoration nauInputDecoration({String? hint, String? errorText}) {
  OutlineInputBorder border(Color color) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: color),
      );
  return InputDecoration(
    isDense: true,
    hintText: hint,
    errorText: errorText,
    errorMaxLines: 3,
    hintStyle: nauText(color: NauColors.textSecondary),
    filled: true,
    fillColor: NauColors.field,
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
    enabledBorder: border(NauColors.fieldBorder),
    focusedBorder: border(NauColors.accent),
    errorBorder: border(NauColors.danger),
    focusedErrorBorder: border(NauColors.danger),
  );
}

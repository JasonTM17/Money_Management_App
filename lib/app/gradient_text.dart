import 'package:flutter/material.dart';

/// Text with a linear gradient fill. Implements the `gradient-text` UI vocabulary token.
/// Typically used on H1 keywords in hero/heading blocks.
class GradientText extends StatelessWidget {
  final String text;
  final Gradient gradient;
  final TextStyle? style;
  final TextAlign? textAlign;

  const GradientText(
    this.text, {
    super.key,
    this.gradient = AppGradients.primary,
    this.style,
    this.textAlign,
  });

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (bounds) => gradient.createShader(bounds),
      child: Text(
        text,
        style: style,
        textAlign: textAlign,
      ),
    );
  }
}

/// Pre-built gradient presets matching the Stitch design system.
class AppGradients {
  /// Primary green gradient (#16A34A → #62DF7D)
  static const primary = LinearGradient(
    colors: [Color(0xFF62DF7D), Color(0xFF16A34A)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Income blue gradient
  static const income = LinearGradient(
    colors: [Color(0xFF60A5FA), Color(0xFF3B82F6)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Warning amber gradient
  static const warning = LinearGradient(
    colors: [Color(0xFFFBBF24), Color(0xFFF59E0B)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Hero section gradient (dark background)
  static const hero = LinearGradient(
    colors: [Color(0xFF62DF7D), Color(0xFF16A34A), Color(0xFF0D9488)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  const AppGradients._();
}

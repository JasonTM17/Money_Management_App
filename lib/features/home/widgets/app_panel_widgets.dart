import 'package:flutter/material.dart';

import '../../../app/app_theme.dart';

class SoftPanel extends StatelessWidget {
  const SoftPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.tint,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? tint;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final accent = tint ?? colorScheme.primary;
    final panelColor = isDark ? AppTheme.cardSlate : AppTheme.lightPanel;
    final baseBorder = isDark
        ? Colors.white.withValues(alpha: 0.07)
        : colorScheme.outlineVariant.withValues(alpha: 0.78);
    final borderColor = tint == null
        ? baseBorder
        : Color.alphaBlend(
            accent.withValues(alpha: isDark ? 0.14 : 0.10),
            baseBorder,
          );
    final backgroundColor = tint == null
        ? panelColor
        : Color.alphaBlend(
            accent.withValues(alpha: isDark ? 0.022 : 0.018),
            panelColor,
          );
    final decoration = BoxDecoration(
      borderRadius: BorderRadius.circular(AppTheme.cardRadius),
      color: backgroundColor,
      border: Border.all(color: borderColor),
      boxShadow: isDark
          ? null
          : [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.035),
                blurRadius: 18,
                offset: const Offset(0, 10),
              ),
            ],
    );
    final content = AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      decoration: decoration,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        child: Stack(
          children: [
            if (tint != null)
              Positioned(
                left: 0,
                top: 14,
                bottom: 14,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: isDark ? 0.68 : 0.58),
                    borderRadius: BorderRadius.circular(AppTheme.pillRadius),
                  ),
                  child: const SizedBox(width: 3),
                ),
              ),
            Material(
              type: MaterialType.transparency,
              child: Padding(padding: padding, child: child),
            ),
          ],
        ),
      ),
    );
    if (onTap == null) return content;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        onTap: onTap,
        child: content,
      ),
    );
  }
}

class SoftPanelDivider extends StatelessWidget {
  const SoftPanelDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Divider(color: Theme.of(context).dividerColor),
    );
  }
}

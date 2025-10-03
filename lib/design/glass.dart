import 'dart:ui';
import 'package:flutter/material.dart';
import 'tokens.dart';

class GlassCard extends StatelessWidget {
  final Widget child;
  final double tint;
  final double blur;
  final bool border;
  final VoidCallback? onTap;

  const GlassCard({super.key, required this.child, this.tint = 0.06, this.blur = DSXBlur.md, this.border = true, this.onTap});

  @override
  Widget build(BuildContext context) {
    final card = ClipRRect(
      borderRadius: BorderRadius.circular(DSXRadii.md),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(tint),
            borderRadius: BorderRadius.circular(DSXRadii.md),
            border: border ? Border.all(color: DSXColors.border) : null,
          ),
          child: child,
        ),
      ),
    );

    if (onTap != null) {
      return InkWell(
        borderRadius: BorderRadius.circular(DSXRadii.md),
        onTap: onTap,
        child: card,
      );
    }
    return card;
  }
}

enum GlassButtonKind { primary, ghost, danger }

class GlassButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final GlassButtonKind kind;
  final Widget? icon;

  const GlassButton.primary(this.label, {super.key, this.onPressed, this.icon}) : kind = GlassButtonKind.primary;
  const GlassButton.ghost(this.label, {super.key, this.onPressed, this.icon}) : kind = GlassButtonKind.ghost;
  const GlassButton.danger(this.label, {super.key, this.onPressed, this.icon}) : kind = GlassButtonKind.danger;

  @override
  Widget build(BuildContext context) {
    final Color bg;
    final Color fg;
    final Color br;
    switch (kind) {
      case GlassButtonKind.primary:
        bg = DSXColors.accent.withOpacity(0.15);
        fg = DSXColors.textPrimary;
        br = DSXColors.accent.withOpacity(0.35);
        break;
      case GlassButtonKind.danger:
        bg = DSXColors.danger.withOpacity(0.15);
        fg = DSXColors.textPrimary;
        br = DSXColors.danger.withOpacity(0.35);
        break;
      case GlassButtonKind.ghost:
      default:
        bg = Colors.white.withOpacity(0.08);
        fg = DSXColors.textPrimary;
        br = DSXColors.border;
        break;
    }

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(DSXRadii.sm),
        border: Border.all(color: br),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(DSXRadii.sm),
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  IconTheme(
                    data: IconThemeData(color: fg, size: 18),
                    child: icon!,
                  ),
                  const SizedBox(width: 8),
                ],
                Text(label, style: Theme.of(context).textTheme.labelLarge?.copyWith(color: fg)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class GradientGlassCard extends StatelessWidget {
  final Widget child;
  final List<Color> colors; // gradient colors
  final Alignment begin;
  final Alignment end;
  final double blur;

  const GradientGlassCard({super.key, required this.child, required this.colors, this.begin = Alignment.topLeft, this.end = Alignment.bottomRight, this.blur = DSXBlur.md});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(DSXRadii.md),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(begin: begin, end: end, colors: colors.map((c) => c.withOpacity(0.15)).toList()),
            borderRadius: BorderRadius.circular(DSXRadii.md),
            border: Border.all(color: DSXColors.border),
          ),
          child: child,
        ),
      ),
    );
  }
}

class GlassAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;
  const GlassAppBar({super.key, required this.title, this.actions});

  @override
  Size get preferredSize => const Size.fromHeight(56);

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: DSXBlur.sm, sigmaY: DSXBlur.sm),
        child: AppBar(
          title: Text(title),
          backgroundColor: Colors.white.withOpacity(0.04),
          elevation: 0,
          actions: actions,
        ),
      ),
    );
  }
} 
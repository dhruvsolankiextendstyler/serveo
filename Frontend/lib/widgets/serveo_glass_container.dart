import 'dart:ui';
import 'package:flutter/material.dart';
import '../utils/theme_provider.dart';

/// A reusable glassmorphic container that applies a subtle Gaussian blur to content underneath it,
/// combined with a semi-transparent surface, soft rounded corners, and a restrained outline.
class ServeoGlassContainer extends StatelessWidget {
  final Widget child;
  final double blur;
  final BorderRadius? borderRadius;
  final Color? color;
  final BoxBorder? border;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final List<BoxShadow>? boxShadow;
  final double? width;
  final double? height;
  final AlignmentGeometry? alignment;

  const ServeoGlassContainer({
    super.key,
    required this.child,
    this.blur = 14.0,
    this.borderRadius,
    this.color,
    this.border,
    this.padding,
    this.margin,
    this.boxShadow,
    this.width,
    this.height,
    this.alignment,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final r = borderRadius ?? BorderRadius.circular(AppTheme.radiusContainer);

    final surfaceColor = color ?? (isDark ? AppTheme.darkGlassBackground : AppTheme.lightGlassBackground);
    final surfaceBorder = border ??
        Border.all(
          color: isDark ? AppTheme.darkGlassBorder : AppTheme.lightGlassBorder,
          width: 1.0,
        );

    final defaultShadow = boxShadow ??
        [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ];

    return Container(
      width: width,
      height: height,
      margin: margin,
      alignment: alignment,
      decoration: BoxDecoration(
        borderRadius: r,
        boxShadow: defaultShadow,
      ),
      child: ClipRRect(
        borderRadius: r,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color: surfaceColor,
              borderRadius: r,
              border: surfaceBorder,
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Helper method to display a glassmorphic modal dialog with soft backdrop blur.
Future<T?> showGlassDialog<T>({
  required BuildContext context,
  required Widget Function(BuildContext) builder,
  bool barrierDismissible = true,
  Color? barrierColor,
}) {
  return showDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierColor: barrierColor ?? Colors.black.withValues(alpha: 0.5),
    builder: (ctx) {
      return BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: builder(ctx),
      );
    },
  );
}

/// Helper method to display a glassmorphic modal bottom sheet with soft backdrop blur.
Future<T?> showGlassBottomSheet<T>({
  required BuildContext context,
  required Widget Function(BuildContext) builder,
  bool isScrollControlled = true,
  Color? barrierColor,
}) {
  final isDark = Theme.of(context).brightness == Brightness.dark;

  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: isScrollControlled,
    backgroundColor: Colors.transparent,
    barrierColor: barrierColor ?? Colors.black.withValues(alpha: 0.4),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppTheme.radiusBottomSheet)),
    ),
    builder: (ctx) {
      return BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? AppTheme.darkGlassBackground : AppTheme.lightGlassBackground,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(AppTheme.radiusBottomSheet)),
            border: Border(
              top: BorderSide(
                color: isDark ? AppTheme.darkGlassBorder : AppTheme.lightGlassBorder,
                width: 1.0,
              ),
            ),
          ),
          child: builder(ctx),
        ),
      );
    },
  );
}

typedef BreakBiteGlassContainer = ServeoGlassContainer;


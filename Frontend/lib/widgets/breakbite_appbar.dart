import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../utils/theme_provider.dart';

class ServeoAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;

  const ServeoAppBar({
    super.key,
    this.title = "Serveo",
    this.actions,
  });

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final isDark = themeProvider.isDark;
    final isDesktop = MediaQuery.sizeOf(context).width >= 600;

    final List<Widget> headerActions = [];
    if (actions != null) {
      headerActions.addAll(actions!);
    }

    // Desktop/wide screens: place theme toggle in the top-right header area
    if (isDesktop) {
      headerActions.add(
        IconButton(
          icon: Icon(
            isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
            color: isDark ? Colors.amber : const Color(0xFF1F2937),
          ),
          tooltip: isDark ? "Switch to Light mode" : "Switch to Dark mode",
          onPressed: () => context.read<ThemeProvider>().toggleTheme(),
        ),
      );
      headerActions.add(const SizedBox(width: 8));
    }

    return AppBar(
      elevation: 0,
      scrolledUnderElevation: 0,
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.yellow.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.fastfood_outlined, color: Colors.yellow, size: 20),
          ),
          const SizedBox(width: 10),
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
      actions: headerActions.isNotEmpty ? headerActions : null,
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

typedef BreakBiteAppBar = ServeoAppBar;
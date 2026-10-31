import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../pages/order_tracking_page.dart';
import '../utils/order_provider.dart';
import '../utils/restaurant_provider.dart';
import '../utils/theme_provider.dart';
import 'serveo_glass_container.dart';

class ServeoAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;

  const ServeoAppBar({
    super.key,
    this.title = "Serveo",
    this.actions,
  });

  void _showNotificationCenter(BuildContext context) {
    final orderProvider = context.read<OrderProvider>();
    orderProvider.fetchNotifications();

    showGlassBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (modalCtx) {
        return Consumer<OrderProvider>(
          builder: (context, provider, _) {
            final isDark = Theme.of(context).brightness == Brightness.dark;
            final primaryTextColor = isDark ? Colors.white : const Color(0xFF111827);
            final secondaryTextColor = isDark ? Colors.white60 : const Color(0xFF6B7280);
            final borderColor = isDark ? Colors.white12 : const Color(0xFFE5E7EB);

            final notifications = provider.notifications;
            final unreadCount = provider.unreadNotificationCount;

            return Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.75,
              ),
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.notifications_outlined, color: Color(0xFFD97706), size: 22),
                            const SizedBox(width: 8),
                            Text(
                              "Notifications",
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: primaryTextColor,
                              ),
                            ),
                            if (unreadCount > 0) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.redAccent,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  "$unreadCount",
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        if (unreadCount > 0)
                          TextButton(
                            onPressed: () => provider.markAllNotificationsAsRead(),
                            child: const Text("Mark all read", style: TextStyle(fontSize: 12)),
                          ),
                      ],
                    ),
                  ),
                  Divider(color: borderColor, height: 16),

                  // Notifications list
                  if (notifications.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.notifications_off_outlined, size: 50, color: secondaryTextColor),
                          const SizedBox(height: 12),
                          Text(
                            "No notifications yet",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: primaryTextColor,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "Updates regarding your order and payment verification will appear here.",
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 13, color: secondaryTextColor),
                          ),
                        ],
                      ),
                    )
                  else
                    Flexible(
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: notifications.length,
                        separatorBuilder: (_, __) => Divider(color: borderColor, height: 1),
                        itemBuilder: (context, index) {
                          final notif = notifications[index];
                          final notifId = notif['_id']?.toString() ?? '';
                          final title = notif['title']?.toString() ?? 'Notification';
                          final message = notif['message']?.toString() ?? '';
                          final isRead = notif['isRead'] == true;
                          final orderId = notif['orderId']?.toString();
                          final type = notif['type']?.toString() ?? '';
                          final createdAt = notif['createdAt'] != null
                              ? notif['createdAt'].toString().replaceFirst('T', ' ').substring(0, 16)
                              : '';

                          IconData iconData = Icons.notifications;
                          Color iconColor = const Color(0xFFD97706);
                          if (type.contains('VERIFIED') || type.contains('READY') || type.contains('ACCEPTED')) {
                            iconData = Icons.check_circle_outline;
                            iconColor = Colors.green;
                          } else if (type.contains('REJECTED') || type.contains('CANCELLED')) {
                            iconData = Icons.cancel_outlined;
                            iconColor = Colors.redAccent;
                          } else if (type.contains('PREPARING')) {
                            iconData = Icons.soup_kitchen_outlined;
                            iconColor = Colors.blue;
                          }

                          return InkWell(
                            onTap: () {
                              if (!isRead && notifId.isNotEmpty) {
                                provider.markNotificationAsRead(notifId);
                              }
                              Navigator.pop(modalCtx);
                              if (orderId != null && orderId.isNotEmpty) {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => OrderTrackingPage(orderId: orderId),
                                  ),
                                );
                              }
                            },
                            child: Container(
                              color: isRead ? Colors.transparent : Colors.amber.withValues(alpha: 0.08),
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: iconColor.withValues(alpha: 0.15),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(iconData, color: iconColor, size: 20),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Expanded(
                                              child: Text(
                                                title,
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: isRead ? FontWeight.w600 : FontWeight.bold,
                                                  color: primaryTextColor,
                                                ),
                                              ),
                                            ),
                                            if (!isRead)
                                              Container(
                                                width: 8,
                                                height: 8,
                                                decoration: const BoxDecoration(
                                                  color: Colors.redAccent,
                                                  shape: BoxShape.circle,
                                                ),
                                              ),
                                          ],
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          message,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: secondaryTextColor,
                                            height: 1.35,
                                          ),
                                        ),
                                        if (createdAt.isNotEmpty) ...[
                                          const SizedBox(height: 4),
                                          Text(
                                            createdAt,
                                            style: TextStyle(fontSize: 10, color: secondaryTextColor.withValues(alpha: 0.8)),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final isDark = themeProvider.isDark;
    final isDesktop = MediaQuery.sizeOf(context).width >= 600;
    final orderProvider = context.watch<OrderProvider>();
    final unreadNotifs = orderProvider.unreadNotificationCount;

    final List<Widget> headerActions = [];

    // Notification bell with badge
    headerActions.add(
      Stack(
        alignment: Alignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            tooltip: "Notifications",
            onPressed: () => _showNotificationCenter(context),
          ),
          if (unreadNotifs > 0)
            Positioned(
              right: 8,
              top: 8,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: Colors.redAccent,
                  shape: BoxShape.circle,
                ),
                constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                child: Text(
                  unreadNotifs > 9 ? "9+" : "$unreadNotifs",
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        ],
      ),
    );

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

    RestaurantProvider? restProvider;
    try {
      restProvider = context.watch<RestaurantProvider>();
    } catch (_) {}
    final displayTitle = (title != "Serveo") ? title : (restProvider?.config.name ?? "Serveo");
    final customLogoUrl = restProvider?.config.logoUrl;

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
            child: customLogoUrl != null && customLogoUrl.isNotEmpty
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: Image.network(
                      customLogoUrl,
                      width: 20,
                      height: 20,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Icon(Icons.fastfood_outlined, color: Colors.yellow, size: 20),
                    ),
                  )
                : const Icon(Icons.fastfood_outlined, color: Colors.yellow, size: 20),
          ),
          const SizedBox(width: 10),
          Text(
            displayTitle,
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
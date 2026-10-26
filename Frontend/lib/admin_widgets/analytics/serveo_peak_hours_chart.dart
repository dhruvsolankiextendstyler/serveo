import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../admin_utils/admin_analytics_provider.dart';

class ServeoPeakHoursChart extends StatelessWidget {
  final PeakHoursData data;

  const ServeoPeakHoursChart({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final borderColor = isDark ? Colors.white12 : const Color(0xFFE5E7EB);

    final hours = data.hourlyVolume;
    final maxHourOrders = hours.map((e) => e.ordersCount).fold(0, (a, b) => math.max(a, b));
    final days = data.dayOfWeekVolume;
    final maxDayOrders = days.map((e) => e.ordersCount).fold(0, (a, b) => math.max(a, b));

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                )
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Peak Ordering Times (IST)",
                style: TextStyle(
                  color: isDark ? Colors.white : const Color(0xFF111827),
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (data.peakHour != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.flash_on, size: 14, color: Colors.blueAccent),
                      const SizedBox(width: 4),
                      Text(
                        "Peak: ${data.peakHour!.label}",
                        style: const TextStyle(
                          color: Colors.blueAccent,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),

          // Hourly distribution
          Text(
            "Hourly Distribution (24 Hours)",
            style: TextStyle(
              color: isDark ? Colors.white60 : const Color(0xFF6B7280),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 70,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: hours.map((h) {
                final isPeak = data.peakHour != null && data.peakHour!.hour == h.hour && h.ordersCount > 0;
                final heightFraction = maxHourOrders > 0 ? (h.ordersCount / maxHourOrders).clamp(0.08, 1.0) : 0.08;

                return Tooltip(
                  message: "${h.label}: ${h.ordersCount} orders (₹${h.volume})",
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Container(
                        width: 8,
                        height: 50 * heightFraction,
                        decoration: BoxDecoration(
                          color: isPeak
                              ? Colors.blueAccent
                              : h.ordersCount > 0
                                  ? const Color(0xFFD97706)
                                  : isDark
                                      ? Colors.white10
                                      : Colors.black12,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        h.hour % 6 == 0 ? "${h.hour}" : "",
                        style: TextStyle(
                          color: isDark ? Colors.white38 : const Color(0xFF9CA3AF),
                          fontSize: 8,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 20),

          // Day of week distribution
          Text(
            "Weekly Traffic Distribution",
            style: TextStyle(
              color: isDark ? Colors.white60 : const Color(0xFF6B7280),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: days.map((d) {
              final isPeak = data.peakDay != null && data.peakDay!.dayOfWeek == d.dayOfWeek && d.ordersCount > 0;
              final heightFraction = maxDayOrders > 0 ? (d.ordersCount / maxDayOrders).clamp(0.1, 1.0) : 0.1;

              return Column(
                children: [
                  Text(
                    "${d.ordersCount}",
                    style: TextStyle(
                      color: isPeak ? Colors.amber : (isDark ? Colors.white70 : const Color(0xFF4B5563)),
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    width: 28,
                    height: 40 * heightFraction,
                    decoration: BoxDecoration(
                      color: isPeak
                          ? Colors.amber
                          : d.ordersCount > 0
                              ? const Color(0xFFD97706).withValues(alpha: 0.8)
                              : isDark
                                  ? Colors.white10
                                  : Colors.black12,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    d.dayName.substring(0, 3),
                    style: TextStyle(
                      color: isPeak ? Colors.amber : (isDark ? Colors.white60 : const Color(0xFF6B7280)),
                      fontSize: 10,
                      fontWeight: isPeak ? FontWeight.bold : FontWeight.w500,
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

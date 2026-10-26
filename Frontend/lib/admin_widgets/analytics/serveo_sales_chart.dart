import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../admin_utils/admin_analytics_provider.dart';

class ServeoSalesChart extends StatefulWidget {
  final SalesTimeline timelineData;

  const ServeoSalesChart({super.key, required this.timelineData});

  @override
  State<ServeoSalesChart> createState() => _ServeoSalesChartState();
}

class _ServeoSalesChartState extends State<ServeoSalesChart> {
  int? _selectedIndex;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final timeline = widget.timelineData.timeline;
    final cardBg = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final borderColor = isDark ? Colors.white12 : const Color(0xFFE5E7EB);

    if (timeline.isEmpty || widget.timelineData.totalRevenue == 0 && widget.timelineData.totalOrders == 0) {
      return Container(
        height: 220,
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.bar_chart_rounded, size: 48, color: isDark ? Colors.white38 : Colors.black26),
              const SizedBox(height: 8),
              Text(
                "No sales recorded for this period",
                style: TextStyle(
                  color: isDark ? Colors.white60 : const Color(0xFF6B7280),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final maxRevenue = timeline.map((e) => e.revenue).fold(0, (a, b) => math.max(a, b));
    final selectedPoint = _selectedIndex != null && _selectedIndex! < timeline.length
        ? timeline[_selectedIndex!]
        : null;

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
          // Header & Tooltip Display
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.timelineData.grouping == "hourly" ? "Hourly Sales Trend" : "Daily Sales Trend",
                    style: TextStyle(
                      color: isDark ? Colors.white70 : const Color(0xFF4B5563),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    "₹${widget.timelineData.totalRevenue}",
                    style: TextStyle(
                      color: isDark ? Colors.white : const Color(0xFF111827),
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              if (selectedPoint != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD97706).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFD97706).withValues(alpha: 0.4)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        selectedPoint.label,
                        style: const TextStyle(
                          color: Color(0xFFD97706),
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        "₹${selectedPoint.revenue} • ${selectedPoint.ordersCount} orders",
                        style: TextStyle(
                          color: isDark ? Colors.white : const Color(0xFF1F2937),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                )
              else
                Text(
                  "Tap bars for details",
                  style: TextStyle(
                    color: isDark ? Colors.white38 : const Color(0xFF9CA3AF),
                    fontSize: 11,
                    fontStyle: FontStyle.italic,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),

          // Interactive Bar Chart Area
          SizedBox(
            height: 150,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final barCount = timeline.length;
                final availableWidth = constraints.maxWidth;
                final barWidth = math.max(4.0, math.min(22.0, (availableWidth / barCount) - 4));

                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: List.generate(barCount, (index) {
                    final point = timeline[index];
                    final heightFraction = maxRevenue > 0 ? (point.revenue / maxRevenue).clamp(0.04, 1.0) : 0.04;
                    final isSelected = _selectedIndex == index;

                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedIndex = isSelected ? null : index;
                        });
                      },
                      behavior: HitTestBehavior.opaque,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 1.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 250),
                              width: barWidth,
                              height: 120 * heightFraction,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.bottomCenter,
                                  end: Alignment.topCenter,
                                  colors: isSelected
                                      ? [Colors.yellow, Colors.amber]
                                      : point.revenue > 0
                                          ? [const Color(0xFFD97706), const Color(0xFFF59E0B)]
                                          : [
                                              isDark ? Colors.white10 : Colors.black12,
                                              isDark ? Colors.white10 : Colors.black12,
                                            ],
                                ),
                                borderRadius: BorderRadius.circular(barWidth / 2),
                                border: isSelected ? Border.all(color: Colors.white, width: 1.5) : null,
                                boxShadow: isSelected
                                    ? [
                                        BoxShadow(
                                          color: Colors.amber.withValues(alpha: 0.6),
                                          blurRadius: 8,
                                          offset: const Offset(0, 2),
                                        )
                                      ]
                                    : null,
                              ),
                            ),
                            const SizedBox(height: 6),
                            // X-axis label: display readable interval labels
                            SizedBox(
                              width: barWidth + 6,
                              child: Text(
                                _formatXLabel(index, barCount, point.label),
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                overflow: TextOverflow.clip,
                                style: TextStyle(
                                  color: isSelected
                                      ? const Color(0xFFD97706)
                                      : isDark
                                          ? Colors.white38
                                          : const Color(0xFF9CA3AF),
                                  fontSize: 9,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  String _formatXLabel(int index, int total, String original) {
    if (total <= 7) {
      return original;
    }
    // For 24 hours, display every 4th hour
    if (total == 24) {
      if (index % 4 == 0) return original.split(":")[0];
      return "";
    }
    // For 30 days, display every 5th day
    if (total >= 28) {
      if (index % 5 == 0) return original.split(" ")[0];
      return "";
    }
    // Default: display alternate
    if (index % 2 == 0) return original.split(" ")[0];
    return "";
  }
}

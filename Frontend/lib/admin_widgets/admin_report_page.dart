import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../admin_utils/admin_analytics_provider.dart';
import '../utils/theme_provider.dart';
import '../widgets/breakbite_spinner.dart';
import '../widgets/serveo_glass_container.dart';
import 'analytics/serveo_peak_hours_chart.dart';
import 'analytics/serveo_sales_chart.dart';

class AdminReportPage extends StatefulWidget {
  const AdminReportPage({super.key});

  @override
  State<AdminReportPage> createState() => _AdminReportPageState();
}

class _AdminReportPageState extends State<AdminReportPage> {
  late AdminAnalyticsProvider _analyticsProvider;
  bool _initialized = false;
  bool _showingUnderperforming = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _analyticsProvider = AdminAnalyticsProvider();
      _analyticsProvider.loadAnalytics();
      _initialized = true;
    }
  }

  @override
  void dispose() {
    _analyticsProvider.dispose();
    super.dispose();
  }

  Future<void> _pickCustomDateRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024, 1, 1),
      lastDate: now,
      initialDateRange: _analyticsProvider.customRange ??
          DateTimeRange(start: now.subtract(const Duration(days: 7)), end: now),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
                  primary: const Color(0xFFD97706),
                  onPrimary: Colors.white,
                ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      _analyticsProvider.setTimeframe('custom', customRange: picked);
    }
  }

  void _showNetSalesInfoDialog() {
    showGlassDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusDialog)),
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text("Net Sales Definition", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: const Text(
          "Net sales represents collected revenue after discounts, refunds, and adjustments.\n\n"
          "Note: The current database schema does not track promotional discounts or processed refunds, "
          "so net sales is presently equal to gross sales from verified and collected orders.",
          style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Understood", style: TextStyle(color: Color(0xFFD97706))),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _analyticsProvider,
      child: Consumer<AdminAnalyticsProvider>(
        builder: (context, provider, _) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          final bgColor = isDark ? const Color(0xFF121212) : const Color(0xFFF9FAFB);

          return Scaffold(
            backgroundColor: bgColor,
            body: RefreshIndicator(
              onRefresh: () => provider.refresh(),
              color: const Color(0xFFD97706),
              child: CustomScrollView(
                slivers: [
                  // 1. Sticky / Top Filter & Actions Header
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildTopBar(provider, isDark),
                          const SizedBox(height: 12),
                          _buildDateFilterChips(provider, isDark),
                          const SizedBox(height: 12),
                          _buildSelectedRangeSubtitle(provider, isDark),
                        ],
                      ),
                    ),
                  ),

                  // 2. Error Banner (if error occurred)
                  if (provider.errorMessage != null)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: _buildErrorBanner(provider),
                      ),
                    ),

                  // 3. Loading Indicator (Initial load)
                  if (provider.isLoading && provider.overview == null)
                    const SliverFillRemaining(
                      child: Center(child: ServeoSpinner()),
                    )
                  else if (provider.overview != null) ...[
                    // 4. Summary KPI Cards
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: _buildSummaryKpiSection(provider, isDark),
                      ),
                    ),

                    if (provider.overview!.totalOrders == 0)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFFEF3C7),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isDark ? Colors.white12 : const Color(0xFFFDE68A),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.info_outline, color: Color(0xFFD97706), size: 20),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    "No orders recorded for ${provider.overview!.selectedRange.label}. Select Yesterday, Last 7 Days, or This Month to view historical data.",
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isDark ? Colors.white70 : const Color(0xFF92400E),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                    const SliverToBoxAdapter(child: SizedBox(height: 16)),

                    // 5. Sales Overview Chart
                    if (provider.salesTimeline != null)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: ServeoSalesChart(timelineData: provider.salesTimeline!),
                        ),
                      ),

                    const SliverToBoxAdapter(child: SizedBox(height: 16)),

                    // 6. Order Performance & Status Breakdown
                    if (provider.orderPerformance != null)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: _buildOrderPerformanceCard(provider.orderPerformance!, isDark),
                        ),
                      ),

                    const SliverToBoxAdapter(child: SizedBox(height: 16)),

                    // 7. Payment Analytics
                    if (provider.paymentAnalytics != null)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: _buildPaymentAnalyticsCard(provider.paymentAnalytics!, isDark),
                        ),
                      ),

                    const SliverToBoxAdapter(child: SizedBox(height: 16)),

                    // 8. Peak Ordering Hours & Traffic
                    if (provider.peakHours != null)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: ServeoPeakHoursChart(data: provider.peakHours!),
                        ),
                      ),

                    const SliverToBoxAdapter(child: SizedBox(height: 16)),

                    // 9. Menu Item Performance (Best Sellers & Underperforming)
                    if (provider.itemInsights != null)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: _buildMenuItemsCard(provider.itemInsights!, provider, isDark),
                        ),
                      ),

                    const SliverToBoxAdapter(child: SizedBox(height: 32)),
                  ] else ...[
                    // Fallback state when overview is null and not loading (e.g. initial network error)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                provider.errorMessage != null
                                    ? Icons.cloud_off_outlined
                                    : Icons.bar_chart_outlined,
                                size: 56,
                                color: isDark ? Colors.white38 : Colors.grey.shade400,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                provider.errorMessage ?? "No analytics data available",
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white70 : Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                "Unable to load restaurant metrics for this timeframe. Tap Retry to reload.",
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: isDark ? Colors.white38 : Colors.black54,
                                ),
                              ),
                              const SizedBox(height: 20),
                              ElevatedButton.icon(
                                onPressed: () => provider.refresh(),
                                icon: const Icon(Icons.refresh, size: 18),
                                label: const Text("Retry"),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFD97706),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // --- TOP BAR & CONTROLS ---

  Widget _buildTopBar(AdminAnalyticsProvider provider, bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Analytics & Insights",
                style: TextStyle(
                  color: isDark ? Colors.white : const Color(0xFF111827),
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                "Real-time restaurant metrics & sales intelligence",
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: isDark ? Colors.white60 : const Color(0xFF6B7280),
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Export CSV Button
            ElevatedButton.icon(
              onPressed: provider.isExporting ? null : () => provider.exportCsv(context),
              icon: provider.isExporting
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                    )
                  : const Icon(Icons.file_download_outlined, size: 16, color: Colors.black),
              label: Text(
                provider.isExporting ? "Exporting..." : "Export CSV",
                style: const TextStyle(color: Colors.black, fontSize: 12, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.yellow,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
            const SizedBox(width: 6),
            // Refresh Button
            IconButton(
              icon: Icon(Icons.refresh, color: isDark ? Colors.white70 : const Color(0xFF4B5563)),
              tooltip: "Refresh metrics",
              onPressed: provider.isLoading ? null : () => provider.refresh(),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDateFilterChips(AdminAnalyticsProvider provider, bool isDark) {
    final filters = [
      {"id": "today", "label": "Today"},
      {"id": "yesterday", "label": "Yesterday"},
      {"id": "7d", "label": "Last 7 Days"},
      {"id": "30d", "label": "Last 30 Days"},
      {"id": "this_month", "label": "This Month"},
      {"id": "prev_month", "label": "Prev Month"},
      {"id": "custom", "label": "Custom Range"},
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: filters.map((f) {
          final isSelected = provider.selectedTimeframe == f['id'];

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(
                f['label']!,
                style: TextStyle(
                  color: isSelected
                      ? Colors.black
                      : isDark
                          ? Colors.white70
                          : const Color(0xFF4B5563),
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                ),
              ),
              selected: isSelected,
              selectedColor: Colors.yellow,
              backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: BorderSide(
                  color: isSelected ? Colors.yellow : (isDark ? Colors.white12 : const Color(0xFFE5E7EB)),
                ),
              ),
              onSelected: (selected) {
                if (f['id'] == 'custom') {
                  _pickCustomDateRange();
                } else {
                  provider.setTimeframe(f['id']!);
                }
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSelectedRangeSubtitle(AdminAnalyticsProvider provider, bool isDark) {
    final label = provider.overview?.selectedRange.label ?? provider.selectedTimeframe;
    return Row(
      children: [
        const Icon(Icons.calendar_today_outlined, size: 14, color: Color(0xFFD97706)),
        const SizedBox(width: 6),
        Text(
          "$label • Timezone: Asia/Kolkata (IST)",
          style: TextStyle(
            color: isDark ? Colors.white70 : const Color(0xFF6B7280),
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildErrorBanner(AdminAnalyticsProvider provider) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.redAccent.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.redAccent.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.redAccent),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              provider.errorMessage ?? "An error occurred",
              style: const TextStyle(color: Colors.redAccent, fontSize: 12),
            ),
          ),
          TextButton(
            onPressed: () => provider.refresh(),
            child: const Text("Retry", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // --- SUMMARY KPI CARDS ---

  Widget _buildSummaryKpiSection(AdminAnalyticsProvider provider, bool isDark) {
    final o = provider.overview!;
    final prevLabel = o.previousLabel;

    return Column(
      children: [
        // Primary Revenue & Order Metrics
        Row(
          children: [
            Expanded(
              child: _buildMetricCard(
                title: "Gross Sales",
                value: "₹${_formatCurrency(o.grossSales)}",
                pctChange: o.comparison.grossSalesChangePct,
                prevLabel: prevLabel,
                icon: Icons.currency_rupee,
                iconColor: Colors.green,
                isDark: isDark,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildMetricCard(
                title: "Net Sales",
                value: "₹${_formatCurrency(o.netSales)}",
                infoAction: _showNetSalesInfoDialog,
                icon: Icons.account_balance_wallet_outlined,
                iconColor: const Color(0xFFD97706),
                isDark: isDark,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _buildMetricCard(
                title: "Total Orders",
                value: "${o.totalOrders}",
                pctChange: o.comparison.totalOrdersChangePct,
                prevLabel: prevLabel,
                icon: Icons.receipt_long,
                iconColor: Colors.blueAccent,
                isDark: isDark,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildMetricCard(
                title: "Avg Order Value",
                value: "₹${o.averageOrderValue}",
                pctChange: o.comparison.aovChangePct,
                prevLabel: prevLabel,
                icon: Icons.trending_up,
                iconColor: Colors.purpleAccent,
                isDark: isDark,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _buildMetricCard(
                title: "Completed",
                value: "${o.completedOrders}",
                pctChange: o.comparison.completedOrdersChangePct,
                prevLabel: prevLabel,
                icon: Icons.check_circle_outline,
                iconColor: Colors.teal,
                isDark: isDark,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildMetricCard(
                title: "In Kitchen / Prep",
                value: "${o.pendingOrders}",
                icon: Icons.soup_kitchen_outlined,
                iconColor: Colors.amber,
                isDark: isDark,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _buildMetricCard(
                title: "Cancelled / Rejected",
                value: "${o.cancelledOrders}",
                icon: Icons.cancel_outlined,
                iconColor: Colors.redAccent,
                isDark: isDark,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildMetricCard(
                title: "Pending UPI Verification",
                value: "${o.pendingUpiVerifications}",
                icon: Icons.verified_user_outlined,
                iconColor: o.pendingUpiVerifications > 0 ? Colors.amber : Colors.grey,
                isAlert: o.pendingUpiVerifications > 0,
                isDark: isDark,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    double? pctChange,
    String? prevLabel,
    VoidCallback? infoAction,
    required IconData icon,
    required Color iconColor,
    bool isAlert = false,
    required bool isDark,
  }) {
    final cardBg = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final borderColor = isAlert
        ? Colors.amber.withValues(alpha: 0.8)
        : isDark
            ? Colors.white12
            : const Color(0xFFE5E7EB);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor, width: isAlert ? 1.5 : 1),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 6,
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
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 18, color: iconColor),
              ),
              if (infoAction != null)
                IconButton(
                  icon: const Icon(Icons.info_outline, size: 16, color: Colors.grey),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: infoAction,
                ),
              if (pctChange != null) _buildComparisonBadge(pctChange, prevLabel),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: isDark ? Colors.white60 : const Color(0xFF6B7280),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: isDark ? Colors.white : const Color(0xFF111827),
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComparisonBadge(double pct, String? prevLabel) {
    final isUp = pct > 0;
    final isZero = pct == 0.0;
    final color = isZero ? Colors.grey : (isUp ? Colors.green : Colors.redAccent);
    final icon = isZero ? Icons.remove : (isUp ? Icons.arrow_upward : Icons.arrow_downward);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: color),
          const SizedBox(width: 2),
          Text(
            "${pct.abs()}%",
            style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  // --- ORDER PERFORMANCE CARD ---

  Widget _buildOrderPerformanceCard(OrderPerformance perf, bool isDark) {
    final cardBg = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final borderColor = isDark ? Colors.white12 : const Color(0xFFE5E7EB);

    final completed = (perf.statusBreakdown["Completed"] ?? 0) + (perf.statusBreakdown["Collected"] ?? 0);
    final inPrep = (perf.statusBreakdown["Preparing"] ?? 0) + (perf.statusBreakdown["Ready"] ?? 0) + (perf.statusBreakdown["Accepted"] ?? 0);
    final pending = (perf.statusBreakdown["Pending"] ?? 0) + (perf.statusBreakdown["Processing"] ?? 0) + (perf.statusBreakdown["Pending Verification"] ?? 0);
    final cancelled = (perf.statusBreakdown["Cancelled"] ?? 0) + (perf.statusBreakdown["Payment Rejected"] ?? 0);

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
          Text(
            "Order Completion & Performance",
            style: TextStyle(
              color: isDark ? Colors.white : const Color(0xFF111827),
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 14),

          // Completion & Cancellation rates
          Row(
            children: [
              Expanded(
                child: _buildRateIndicator(
                  label: "Completion Rate",
                  rate: perf.completionRate,
                  color: Colors.green,
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _buildRateIndicator(
                  label: "Cancellation Rate",
                  rate: perf.cancellationRate,
                  color: Colors.redAccent,
                  isDark: isDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Status Breakdown Segment Bar
          Text(
            "Status Distribution",
            style: TextStyle(
              color: isDark ? Colors.white70 : const Color(0xFF4B5563),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              height: 12,
              child: Row(
                children: [
                  if (completed > 0)
                    Expanded(flex: completed, child: Container(color: Colors.green)),
                  if (inPrep > 0)
                    Expanded(flex: inPrep, child: Container(color: Colors.amber)),
                  if (pending > 0)
                    Expanded(flex: pending, child: Container(color: Colors.blueAccent)),
                  if (cancelled > 0)
                    Expanded(flex: cancelled, child: Container(color: Colors.redAccent)),
                  if (perf.totalOrders == 0)
                    Expanded(child: Container(color: isDark ? Colors.white10 : Colors.black12)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Legend
          Wrap(
            spacing: 12,
            runSpacing: 6,
            children: [
              _buildLegendItem("Completed ($completed)", Colors.green, isDark),
              _buildLegendItem("In Kitchen ($inPrep)", Colors.amber, isDark),
              _buildLegendItem("Queue ($pending)", Colors.blueAccent, isDark),
              _buildLegendItem("Cancelled ($cancelled)", Colors.redAccent, isDark),
            ],
          ),
          const SizedBox(height: 14),

          // Average prep time note & disclaimer
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.timer_outlined, size: 16, color: Color(0xFFD97706)),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        perf.averagePrepTimeMinutes != null
                            ? "Avg Prep Time: ${perf.averagePrepTimeMinutes} mins (created → collected)"
                            : "Avg Prep Time: N/A",
                        style: TextStyle(
                          color: isDark ? Colors.white : const Color(0xFF1F2937),
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        perf.prepTimeNote,
                        style: TextStyle(
                          color: isDark ? Colors.white60 : const Color(0xFF6B7280),
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRateIndicator({
    required String label,
    required double rate,
    required Color color,
    required bool isDark,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(
                color: isDark ? Colors.white60 : const Color(0xFF6B7280),
                fontSize: 11,
              ),
            ),
            Text(
              "$rate%",
              style: TextStyle(
                color: color,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        LinearProgressIndicator(
          value: (rate / 100).clamp(0.0, 1.0),
          backgroundColor: isDark ? Colors.white10 : Colors.black12,
          valueColor: AlwaysStoppedAnimation<Color>(color),
          borderRadius: BorderRadius.circular(4),
          minHeight: 6,
        ),
      ],
    );
  }

  Widget _buildLegendItem(String label, Color color, bool isDark) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            color: isDark ? Colors.white70 : const Color(0xFF4B5563),
            fontSize: 10,
          ),
        ),
      ],
    );
  }

  // --- PAYMENT ANALYTICS CARD ---

  Widget _buildPaymentAnalyticsCard(PaymentAnalytics pay, bool isDark) {
    final cardBg = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final borderColor = isDark ? Colors.white12 : const Color(0xFFE5E7EB);

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
                "Payment Activity & Channels",
                style: TextStyle(
                  color: isDark ? Colors.white : const Color(0xFF111827),
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                "Verified: ₹${pay.verifiedRevenue}",
                style: const TextStyle(
                  color: Colors.green,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Payment Methods Row
          Row(
            children: [
              Expanded(
                child: _buildPaymentMethodTile(
                  method: "UPI (QR)",
                  orders: pay.upi.totalOrders,
                  amount: pay.upi.verifiedAmount,
                  pendingClaims: pay.upi.pendingVerificationCount,
                  rejectedClaims: pay.upi.rejectedCount,
                  color: Colors.purpleAccent,
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildPaymentMethodTile(
                  method: "Cash on Delivery",
                  orders: pay.cod.totalOrders,
                  amount: pay.cod.totalAmount,
                  color: Colors.teal,
                  isDark: isDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Distribution bar
          Text(
            "Channel Distribution (Orders)",
            style: TextStyle(
              color: isDark ? Colors.white60 : const Color(0xFF6B7280),
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: SizedBox(
              height: 8,
              child: Row(
                children: [
                  if (pay.upi.totalOrders > 0)
                    Expanded(flex: pay.upi.totalOrders, child: Container(color: Colors.purpleAccent)),
                  if (pay.cod.totalOrders > 0)
                    Expanded(flex: pay.cod.totalOrders, child: Container(color: Colors.teal)),
                  if (pay.card.totalOrders > 0)
                    Expanded(flex: pay.card.totalOrders, child: Container(color: Colors.blueAccent)),
                  if (pay.grandTotalOrders == 0)
                    Expanded(child: Container(color: isDark ? Colors.white10 : Colors.black12)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentMethodTile({
    required String method,
    required int orders,
    required int amount,
    int pendingClaims = 0,
    int rejectedClaims = 0,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.03) : const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
              const SizedBox(width: 6),
              Text(
                method,
                style: TextStyle(
                  color: isDark ? Colors.white70 : const Color(0xFF374151),
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            "₹$amount",
            style: TextStyle(
              color: isDark ? Colors.white : const Color(0xFF111827),
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            "$orders orders",
            style: TextStyle(
              color: isDark ? Colors.white60 : const Color(0xFF6B7280),
              fontSize: 11,
            ),
          ),
          if (pendingClaims > 0) ...[
            const SizedBox(height: 4),
            Text(
              "⚠ $pendingClaims unverified claim(s)",
              style: const TextStyle(color: Colors.amber, fontSize: 10, fontWeight: FontWeight.bold),
            ),
          ],
          if (rejectedClaims > 0) ...[
            const SizedBox(height: 2),
            Text(
              "✖ $rejectedClaims rejected",
              style: const TextStyle(color: Colors.redAccent, fontSize: 10),
            ),
          ],
        ],
      ),
    );
  }

  // --- MENU ITEM INSIGHTS (BEST-SELLERS & UNDERPERFORMING) ---

  Widget _buildMenuItemsCard(ItemInsights insights, AdminAnalyticsProvider provider, bool isDark) {
    final cardBg = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final borderColor = isDark ? Colors.white12 : const Color(0xFFE5E7EB);

    final popular = insights.popularItems;
    final underperforming = insights.underperformingItems;

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
                "Menu Performance",
                style: TextStyle(
                  color: isDark ? Colors.white : const Color(0xFF111827),
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              // Segmented Toggle between Best Sellers and Underperforming
              Container(
                decoration: BoxDecoration(
                  color: isDark ? Colors.white10 : const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    _buildSubTabButton("Best Sellers", !_showingUnderperforming, () {
                      setState(() => _showingUnderperforming = false);
                    }),
                    _buildSubTabButton("Low Sales", _showingUnderperforming, () {
                      setState(() => _showingUnderperforming = true);
                    }),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          if (!_showingUnderperforming) ...[
            // Sort toggle for Popular items
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  "Sort by:",
                  style: TextStyle(
                    color: isDark ? Colors.white60 : const Color(0xFF6B7280),
                    fontSize: 11,
                  ),
                ),
                const SizedBox(width: 6),
                DropdownButton<String>(
                  value: provider.itemSortBy,
                  underline: const SizedBox(),
                  borderRadius: BorderRadius.circular(AppTheme.radiusDropdown),
                  dropdownColor: isDark ? const Color(0xFF252525) : Colors.white,
                  items: const [
                    DropdownMenuItem(value: "quantity", child: Text("Qty Sold", style: TextStyle(fontSize: 12))),
                    DropdownMenuItem(value: "salesValue", child: Text("Sales Value", style: TextStyle(fontSize: 12))),
                  ],
                  onChanged: (v) {
                    if (v != null) provider.setItemSortBy(v);
                  },
                ),
              ],
            ),
            const SizedBox(height: 6),
            if (popular.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Center(
                  child: Text(
                    "No items sold during this period",
                    style: TextStyle(color: isDark ? Colors.white60 : const Color(0xFF6B7280), fontSize: 13),
                  ),
                ),
              )
            else
              Column(
                children: List.generate(popular.length > 8 ? 8 : popular.length, (index) {
                  final item = popular[index];
                  return _buildPopularItemRow(index + 1, item, isDark);
                }),
              ),
          ] else ...[
            // Underperforming items section
            Text(
              "Active menu items with 0 sales in selected period. Items created in the last 3 days are labeled 'Recently Added'.",
              style: TextStyle(
                color: isDark ? Colors.white60 : const Color(0xFF6B7280),
                fontSize: 11,
              ),
            ),
            const SizedBox(height: 10),
            if (underperforming.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Center(
                  child: Text(
                    "Great news! Every active menu item has sales in this period.",
                    style: TextStyle(color: isDark ? Colors.white60 : const Color(0xFF6B7280), fontSize: 13),
                  ),
                ),
              )
            else
              Column(
                children: List.generate(underperforming.length > 8 ? 8 : underperforming.length, (index) {
                  final item = underperforming[index];
                  return _buildUnderperformingItemRow(item, isDark);
                }),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildSubTabButton(String label, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? Colors.yellow : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.black : Colors.grey,
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildPopularItemRow(int rank, PopularItem item, bool isDark) {
    final rankBg = rank == 1 ? Colors.amber : (rank == 2 ? Colors.blueGrey : (rank == 3 ? Colors.brown : Colors.transparent));
    final rankTextColor = rank <= 3 ? Colors.white : (isDark ? Colors.white60 : const Color(0xFF6B7280));

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: rankBg,
              shape: BoxShape.circle,
              border: rank > 3 ? Border.all(color: isDark ? Colors.white24 : Colors.black12) : null,
            ),
            child: Center(
              child: Text(
                "$rank",
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: rankTextColor),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.itemName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isDark ? Colors.white : const Color(0xFF111827),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  "${item.category} • ${item.ordersCount} orders",
                  style: TextStyle(
                    color: isDark ? Colors.white60 : const Color(0xFF6B7280),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                "₹${item.salesValue}",
                style: TextStyle(
                  color: isDark ? Colors.white : const Color(0xFF111827),
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                "${item.quantitySold} sold",
                style: const TextStyle(
                  color: Color(0xFFD97706),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildUnderperformingItemRow(UnderperformingItem item, bool isDark) {
    final isNew = item.status == "recently_added";
    final badgeColor = isNew ? Colors.blueAccent : Colors.orangeAccent;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(Icons.inventory_2_outlined, size: 20, color: isDark ? Colors.white38 : Colors.black26),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.itemName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isDark ? Colors.white : const Color(0xFF111827),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  item.category,
                  style: TextStyle(
                    color: isDark ? Colors.white60 : const Color(0xFF6B7280),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: badgeColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: badgeColor.withValues(alpha: 0.4)),
            ),
            child: Text(
              item.statusLabel,
              style: TextStyle(
                color: badgeColor,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatCurrency(int amount) {
    // Simple thousands separator formatting for INR
    final str = amount.toString();
    if (str.length <= 3) return str;
    final lastThree = str.substring(str.length - 3);
    final remaining = str.substring(0, str.length - 3);
    return "$remaining,$lastThree";
  }
}
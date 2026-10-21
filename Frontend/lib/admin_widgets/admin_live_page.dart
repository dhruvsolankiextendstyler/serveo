import 'dart:async';

import 'package:flutter/material.dart';
import 'package:frontend/admin_utils/admin_order_provider.dart';
import 'package:frontend/admin_widgets/admin_order_card.dart';
import 'package:frontend/admin_widgets/admin_stat_card.dart';
import 'package:provider/provider.dart';

class LivePage extends StatefulWidget{
  const LivePage({super.key});

  @override
  State<LivePage> createState() => _LivePageState();
}

class _LivePageState extends State<LivePage> {
  Timer? _pollingTimer;

  @override
  void initState() {
    super.initState();
    // Preserves existing 5-second polling interval
    _pollingTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted) {
        context.read<AdminOrderProvider>().fetchOrdersSilent();
      }
    });
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final orderProvider = context.watch<AdminOrderProvider>();
    final liveOrders = orderProvider.liveOrders;
    final completedOrdersCount = orderProvider.historyOrders.length;

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Stats Row
          Row(
            children: [
              AdminStatCard(
                title: "Processing",
                count: liveOrders.where((o) => o.status == 'Processing').length.toString(),
                color: Colors.orange,
              ),
              const SizedBox(width: 10),
              AdminStatCard(
                title: "Preparing",
                count: liveOrders.where((o) => o.status == 'Preparing').length.toString(),
                color: Colors.blue,
              ),
              const SizedBox(width: 10),
              AdminStatCard(
                title: "Completed",
                count: completedOrdersCount.toString(),
                color: Colors.green,
              ),
            ],
          ),
          const SizedBox(height: 20),

          // 2. Active Orders Header with Live Auto-Refresh Indicator
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Active Orders",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              Row(
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(
                      color: Colors.greenAccent,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    "Auto-refresh (5s)",
                    style: TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 3. Orders List or Empty State
          Expanded(
            child: liveOrders.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.check_circle_outline, color: Colors.white38, size: 48),
                        SizedBox(height: 12),
                        Text(
                          "No active orders right now",
                          style: TextStyle(color: Colors.white54, fontSize: 15),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: liveOrders.length,
                    itemBuilder: (context, index) {
                      return AdminOrderCard(order: liveOrders[index]);
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
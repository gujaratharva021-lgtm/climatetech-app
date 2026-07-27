import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/dark_palette.dart';
import '../../models/order_model.dart';
import '../../providers/order_provider.dart';
import '../../providers/marketplace_provider.dart' show LoadStatus;

class MyOrdersScreen extends ConsumerStatefulWidget {
  const MyOrdersScreen({super.key});

  @override
  ConsumerState<MyOrdersScreen> createState() => _MyOrdersScreenState();
}

class _MyOrdersScreenState extends ConsumerState<MyOrdersScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(orderProvider.notifier).loadMyOrders();
    });
  }

  Color _statusColor(OrderStatus s) {
    switch (s) {
      case OrderStatus.placed:
        return const Color(0xFF8A8F9C);
      case OrderStatus.confirmed:
        return const Color(0xFF5AA9E0);
      case OrderStatus.shipped:
        return DarkPalette.cyanAccent;
      case OrderStatus.delivered:
        return DarkPalette.leafGreen;
      case OrderStatus.cancelled:
        return const Color(0xFFE0605A);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(orderProvider);

    return Scaffold(
      backgroundColor: DarkPalette.navyDeep,
      appBar: AppBar(
        backgroundColor: DarkPalette.navyDeep,
        elevation: 0,
        title: const Text('My Orders', style: TextStyle(color: DarkPalette.textPrimary)),
        iconTheme: const IconThemeData(color: DarkPalette.textPrimary),
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(orderProvider.notifier).loadMyOrders(),
        child: _buildBody(state),
      ),
    );
  }

  Widget _buildBody(OrderState state) {
    if (state.myOrdersStatus == LoadStatus.loading && state.myOrders.isEmpty) {
      return const Center(child: CircularProgressIndicator(color: DarkPalette.leafGreen));
    }
    if (state.myOrdersStatus == LoadStatus.error && state.myOrders.isEmpty) {
      return ListView(
        children: [
          const SizedBox(height: 80),
          Icon(Icons.error_outline, color: Colors.white.withOpacity(0.3), size: 48),
          const SizedBox(height: 12),
          Center(
            child: Text(
              state.myOrdersError ?? 'Could not load your orders.',
              style: const TextStyle(color: DarkPalette.textSecondary),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      );
    }
    if (state.myOrders.isEmpty) {
      return ListView(
        children: [
          const SizedBox(height: 80),
          Icon(Icons.receipt_long_outlined, color: Colors.white.withOpacity(0.2), size: 56),
          const SizedBox(height: 12),
          const Center(
            child: Text('No orders yet', style: TextStyle(color: DarkPalette.textSecondary)),
          ),
        ],
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: state.myOrders.length,
      itemBuilder: (context, i) => _orderCard(state.myOrders[i]),
    );
  }

  Widget _orderCard(OrderModel order) {
    final color = _statusColor(order.status);
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => context.push('/orders/${order.id}'),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    order.commodityType.toUpperCase(),
                    style: const TextStyle(color: DarkPalette.textPrimary, fontSize: 14, fontWeight: FontWeight.w700),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    orderStatusLabel(order.status),
                    style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${order.quantity.toStringAsFixed(0)} ${order.unit} @ ₹${order.pricePerUnit.toStringAsFixed(0)}/${order.unit}',
              style: const TextStyle(color: DarkPalette.textSecondary, fontSize: 12.5),
            ),
            const SizedBox(height: 4),
            Text(
              'Total: ₹${order.totalAmount.toStringAsFixed(0)}',
              style: const TextStyle(color: DarkPalette.leafGreen, fontSize: 13, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.location_on_outlined, color: Colors.white.withOpacity(0.4), size: 14),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    order.deliveryAddress,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: DarkPalette.textMuted, fontSize: 11.5),
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, color: DarkPalette.textMuted, size: 18),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

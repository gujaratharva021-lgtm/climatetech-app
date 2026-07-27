import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/dark_palette.dart';
import '../../models/commodity_listing_model.dart';
import '../../models/order_model.dart';
import '../../providers/order_provider.dart';

class SellerOrdersScreen extends ConsumerStatefulWidget {
  const SellerOrdersScreen({super.key});

  @override
  ConsumerState<SellerOrdersScreen> createState() => _SellerOrdersScreenState();
}

class _SellerOrdersScreenState extends ConsumerState<SellerOrdersScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(orderProvider.notifier).loadSellerOrders();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(orderProvider);

    return Scaffold(
      backgroundColor: DarkPalette.navyDeep,
      appBar: AppBar(
        backgroundColor: DarkPalette.navyDeep,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: DarkPalette.textPrimary), onPressed: () => context.pop()),
        title: const Text('Orders (as Seller)', style: TextStyle(color: DarkPalette.textPrimary, fontSize: 16)),
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(orderProvider.notifier).loadSellerOrders(),
        color: DarkPalette.leafGreen,
        backgroundColor: DarkPalette.navyCard,
        child: Builder(builder: (context) {
          if (state.sellerOrdersStatus == LoadStatus.loading && state.sellerOrders.isEmpty) {
            return const Center(child: CircularProgressIndicator(color: DarkPalette.leafGreen));
          }
          if (state.sellerOrders.isEmpty) {
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: const [
                Padding(
                  padding: EdgeInsets.only(top: 120),
                  child: Center(
                    child: Text('No incoming orders yet.', style: TextStyle(color: DarkPalette.textMuted, fontSize: 13)),
                  ),
                ),
              ],
            );
          }
          return ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(18),
            itemCount: state.sellerOrders.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, i) => _orderCard(context, state.sellerOrders[i]),
          );
        }),
      ),
    );
  }

  Widget _orderCard(BuildContext context, OrderModel order) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => context.push('/orders/${order.id}'),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: Colors.white.withOpacity(0.04), borderRadius: BorderRadius.circular(14)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(commodityTypeIcon(order.commodityType), color: DarkPalette.leafGreen, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '${commodityTypeLabel(order.commodityType)} \u00b7 ${order.quantity.toStringAsFixed(0)} ${order.unit}',
                    style: const TextStyle(color: DarkPalette.textPrimary, fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                ),
                Text(
                  orderStatusLabel(order.status),
                  style: const TextStyle(color: DarkPalette.leafGreen, fontSize: 11, fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                if (order.status == OrderStatus.placed)
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () async {
                        final ok = await ref.read(orderProvider.notifier).confirmOrder(order.id);
                        if (ok && context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Order confirmed')));
                        }
                      },
                      child: const Text('Confirm'),
                    ),
                  ),
                if (order.status == OrderStatus.confirmed)
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () async {
                        final ok = await ref.read(orderProvider.notifier).shipOrder(order.id);
                        if (ok && context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Order marked shipped')));
                        }
                      },
                      child: const Text('Mark Shipped'),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

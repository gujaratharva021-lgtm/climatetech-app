
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/dark_palette.dart';
import '../../models/commodity_listing_model.dart';
import '../../models/rfq_model.dart';
import '../../providers/rfq_provider.dart';

class RFQHomeScreen extends ConsumerStatefulWidget {
  const RFQHomeScreen({super.key});

  @override
  ConsumerState<RFQHomeScreen> createState() => _RFQHomeScreenState();
}

class _RFQHomeScreenState extends ConsumerState<RFQHomeScreen> {
  String _selectedType = '';

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(rfqProvider);

    return Scaffold(
      backgroundColor: DarkPalette.navyDeep,
      appBar: AppBar(
        backgroundColor: DarkPalette.navyDeep,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: DarkPalette.textPrimary), onPressed: () => context.pop()),
        title: const Text('RFQ Marketplace', style: TextStyle(color: DarkPalette.textPrimary, fontSize: 16)),
        actions: [
          IconButton(
            icon: const Icon(Icons.receipt_long_outlined, color: DarkPalette.textPrimary),
            tooltip: 'My RFQs',
            onPressed: () => context.push('/rfq/my-rfqs'),
          ),
          IconButton(
            icon: const Icon(Icons.local_offer_outlined, color: DarkPalette.textPrimary),
            tooltip: 'My Bids',
            onPressed: () => context.push('/rfq/my-bids'),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: DarkPalette.leafGreen,
        foregroundColor: Colors.black,
        onPressed: () => context.push('/rfq/post'),
        child: const Icon(Icons.add),
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(rfqProvider.notifier).loadRFQs(),
        color: DarkPalette.leafGreen,
        backgroundColor: DarkPalette.navyCard,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _introBanner(),
              const SizedBox(height: 16),
              _commodityTypeChips(),
              const SizedBox(height: 16),
              if (state.browseStatus == LoadStatus.loading && state.rfqs.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 60),
                  child: Center(child: CircularProgressIndicator(color: DarkPalette.leafGreen)),
                )
              else if (state.browseStatus == LoadStatus.error && state.rfqs.isEmpty)
                _buildErrorState(state.browseError)
              else if (state.rfqs.isEmpty)
                _buildEmptyState()
              else
                _buildList(state.rfqs),
            ],
          ),
        ),
      ),
    );
  }

  Widget _introBanner() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: DarkPalette.leafGreen.withOpacity(0.08), borderRadius: BorderRadius.circular(16)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.gavel_rounded, color: DarkPalette.leafGreen, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Reverse auction: post what you need',
                    style: TextStyle(color: DarkPalette.textPrimary, fontSize: 13, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(
                  'Buyers post requirements here. Sellers bid with their best price. Tap + to post your own requirement.',
                  style: TextStyle(color: DarkPalette.textSecondary.withOpacity(0.9), fontSize: 12, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _commodityTypeChips() {
    final types = ['', ...commodityTypes];
    return SizedBox(
      height: 88,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: types.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, i) {
          final type = types[i];
          final label = type.isEmpty ? 'All' : commodityTypeLabel(type);
          final selected = _selectedType == type;
          return InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () {
              setState(() => _selectedType = type);
              ref.read(rfqProvider.notifier).setCommodityType(type);
            },
            child: Container(
              width: 84,
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
              decoration: BoxDecoration(
                color: selected ? DarkPalette.leafGreen.withOpacity(0.18) : Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(16),
                border: selected ? Border.all(color: DarkPalette.leafGreen, width: 1.5) : null,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    type.isEmpty ? Icons.apps_rounded : commodityTypeIcon(type),
                    color: selected ? DarkPalette.leafGreen : DarkPalette.textSecondary,
                    size: 26,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    label,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: selected ? DarkPalette.leafGreen : DarkPalette.textSecondary,
                      fontSize: 11,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildList(List<RFQModel> rfqs) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: rfqs.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, i) => _rfqCard(rfqs[i]),
    );
  }

  Widget _rfqCard(RFQModel rfq) {
    final daysLeft = rfq.deadline.difference(DateTime.now()).inHours;
    final deadlineLabel = daysLeft < 24 ? '${daysLeft}h left' : '${(daysLeft / 24).floor()}d left';

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => context.push('/rfq/${rfq.id}'),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: Colors.white.withOpacity(0.04), borderRadius: BorderRadius.circular(16)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(commodityTypeIcon(rfq.commodityType), color: DarkPalette.leafGreen, size: 16),
                const SizedBox(width: 6),
                Text(
                  commodityTypeLabel(rfq.commodityType),
                  style: const TextStyle(color: DarkPalette.leafGreen, fontSize: 12, fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: DarkPalette.cyanAccent.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(deadlineLabel, style: const TextStyle(color: DarkPalette.cyanAccent, fontSize: 10, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${rfq.quantity.toStringAsFixed(0)} ${rfq.unit} needed',
              style: const TextStyle(color: DarkPalette.textPrimary, fontSize: 15, fontWeight: FontWeight.w700),
            ),
            if (rfq.grade.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(rfq.grade, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: DarkPalette.textSecondary, fontSize: 12)),
            ],
            const SizedBox(height: 6),
            Row(
              children: [
                if (rfq.targetPrice > 0)
                  Text('Target: ₹${rfq.targetPrice.toStringAsFixed(0)}/${rfq.unit}',
                      style: const TextStyle(color: DarkPalette.textMuted, fontSize: 11.5)),
                if (rfq.targetPrice > 0 && rfq.location.isNotEmpty) const Text('  •  ', style: TextStyle(color: DarkPalette.textMuted, fontSize: 11.5)),
                if (rfq.location.isNotEmpty)
                  Expanded(
                    child: Text(rfq.location, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: DarkPalette.textMuted, fontSize: 11.5)),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.04), borderRadius: BorderRadius.circular(16)),
      child: const Center(child: Text('No open RFQs right now.', style: TextStyle(color: DarkPalette.textMuted, fontSize: 13))),
    );
  }

  Widget _buildErrorState(String? message) {
    return Padding(
      padding: const EdgeInsets.only(top: 60),
      child: Column(
        children: [
          const Icon(Icons.cloud_off_rounded, color: DarkPalette.textMuted, size: 40),
          const SizedBox(height: 12),
          Text(message ?? 'Could not load RFQs.', textAlign: TextAlign.center, style: const TextStyle(color: DarkPalette.textSecondary, fontSize: 13)),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => ref.read(rfqProvider.notifier).loadRFQs(),
            style: ElevatedButton.styleFrom(backgroundColor: DarkPalette.leafGreen, foregroundColor: Colors.black),
            child: const Text('Try again'),
          ),
        ],
      ),
    );
  }
}

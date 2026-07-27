import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/dark_palette.dart';
import '../../models/listing_model.dart';
import '../../providers/marketplace_provider.dart';
import '../../widgets/dark_text_field.dart';

class MarketplaceHomeScreen extends ConsumerStatefulWidget {
  const MarketplaceHomeScreen({super.key});

  @override
  ConsumerState<MarketplaceHomeScreen> createState() => _MarketplaceHomeScreenState();
}

class _MarketplaceHomeScreenState extends ConsumerState<MarketplaceHomeScreen> {
  final _searchController = TextEditingController();
  Timer? _debounce;
  String _selectedCategory = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(marketplaceProvider.notifier).loadListings();
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      ref.read(marketplaceProvider.notifier).setSearch(value.trim());
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(marketplaceProvider);

    return Scaffold(
      backgroundColor: DarkPalette.navyDeep,
      appBar: AppBar(
        backgroundColor: DarkPalette.navyDeep,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: DarkPalette.textPrimary),
          onPressed: () => context.pop(),
        ),
        title: const Text('Marketplace', style: TextStyle(color: DarkPalette.textPrimary, fontSize: 16)),
        actions: [
          IconButton(
            icon: const Icon(Icons.receipt_long_outlined, color: DarkPalette.textPrimary),
            tooltip: 'My listings',
            onPressed: () => context.push('/marketplace/my-listings'),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: DarkPalette.leafGreen,
        foregroundColor: Colors.black,
        onPressed: () => context.push('/marketplace/post'),
        child: const Icon(Icons.add),
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(marketplaceProvider.notifier).loadListings(),
        color: DarkPalette.leafGreen,
        backgroundColor: DarkPalette.navyCard,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _energyTradeEntryCard(context),
              const SizedBox(height: 12),
              _rfqEntryCard(context),
              const SizedBox(height: 12),
              _ordersEntryCard(context),
              const SizedBox(height: 12),
              _priceIndexEntryCard(context),
              const SizedBox(height: 12),
              _financingEntryCard(context),
              const SizedBox(height: 12),
              _carbonCertEntryCard(context),
              const SizedBox(height: 12),
              _aiAssistantEntryCard(context),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _energyTradeEntryCard(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => context.push('/energy-trade'),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: DarkPalette.cyanAccent.withOpacity(0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: DarkPalette.cyanAccent.withOpacity(0.25)),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(color: DarkPalette.cyanAccent.withOpacity(0.15), shape: BoxShape.circle),
              child: const Icon(Icons.bolt_rounded, color: DarkPalette.cyanAccent, size: 20),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('B2B Energy Trade',
                      style: TextStyle(color: DarkPalette.textPrimary, fontSize: 13, fontWeight: FontWeight.w700)),
                  SizedBox(height: 2),
                  Text('Coal, biomass, coke & carbon credits',
                      style: TextStyle(color: DarkPalette.textSecondary, fontSize: 11.5)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: DarkPalette.textMuted),
          ],
        ),
      ),
    );
  }

  Widget _rfqEntryCard(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => context.push('/rfq'),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: DarkPalette.leafGreen.withOpacity(0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: DarkPalette.leafGreen.withOpacity(0.25)),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(color: DarkPalette.leafGreen.withOpacity(0.15), shape: BoxShape.circle),
              child: const Icon(Icons.gavel_rounded, color: DarkPalette.leafGreen, size: 20),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('RFQ / Reverse Auction',
                      style: TextStyle(color: DarkPalette.textPrimary, fontSize: 13, fontWeight: FontWeight.w700)),
                  SizedBox(height: 2),
                  Text('Post requirements, get seller bids',
                      style: TextStyle(color: DarkPalette.textSecondary, fontSize: 11.5)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: DarkPalette.textMuted),
          ],
        ),
      ),
    );
  }

  Widget _priceIndexEntryCard(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => context.push('/price-index'),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(color: DarkPalette.cyanAccent.withOpacity(0.15), shape: BoxShape.circle),
              child: const Icon(Icons.show_chart_rounded, color: DarkPalette.cyanAccent, size: 20),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Live Price Index',
                      style: TextStyle(color: DarkPalette.textPrimary, fontSize: 13, fontWeight: FontWeight.w700)),
                  SizedBox(height: 2),
                  Text('Real-time commodity prices and trends',
                      style: TextStyle(color: DarkPalette.textSecondary, fontSize: 11.5)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: DarkPalette.textMuted),
          ],
        ),
      ),
    );
  }

  Widget _financingEntryCard(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => context.push('/financing'),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(color: DarkPalette.leafGreen.withOpacity(0.15), shape: BoxShape.circle),
              child: const Icon(Icons.account_balance_rounded, color: DarkPalette.leafGreen, size: 20),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Trade Finance',
                      style: TextStyle(color: DarkPalette.textPrimary, fontSize: 13, fontWeight: FontWeight.w700)),
                  SizedBox(height: 2),
                  Text('Request financing against your orders',
                      style: TextStyle(color: DarkPalette.textSecondary, fontSize: 11.5)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: DarkPalette.textMuted),
          ],
        ),
      ),
    );
  }
  Widget _carbonCertEntryCard(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => context.push('/carbon-certificates'),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(color: DarkPalette.leafGreen.withOpacity(0.15), shape: BoxShape.circle),
              child: const Icon(Icons.forest_rounded, color: DarkPalette.leafGreen, size: 20),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Carbon Certificates',
                      style: TextStyle(color: DarkPalette.textPrimary, fontSize: 13, fontWeight: FontWeight.w700)),
                  SizedBox(height: 2),
                  Text('Register credits and retire what you\'ve bought',
                      style: TextStyle(color: DarkPalette.textSecondary, fontSize: 11.5)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: DarkPalette.textMuted),
          ],
        ),
      ),
    );
  }
  Widget _aiAssistantEntryCard(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => context.push('/ai-assistant'),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: DarkPalette.leafGreen.withOpacity(0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: DarkPalette.leafGreen.withOpacity(0.25)),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(color: DarkPalette.leafGreen.withOpacity(0.15), shape: BoxShape.circle),
              child: const Icon(Icons.smart_toy_rounded, color: DarkPalette.leafGreen, size: 20),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('AI Trade Assistant',
                      style: TextStyle(color: DarkPalette.textPrimary, fontSize: 13, fontWeight: FontWeight.w700)),
                  SizedBox(height: 2),
                  Text('Chat about listings, RFQs, and orders',
                      style: TextStyle(color: DarkPalette.textSecondary, fontSize: 11.5)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: DarkPalette.textMuted),
          ],
        ),
      ),
    );
  }
  Widget _toolsRow(BuildContext context) {
    final tools = [
      (Icons.gavel_rounded, 'RFQ', '/rfq'),
      (Icons.receipt_long_rounded, 'Orders', '/orders'),
      (Icons.show_chart_rounded, 'Prices', '/price-index'),
      (Icons.account_balance_rounded, 'Finance', '/financing'),
      (Icons.forest_rounded, 'Carbon', '/carbon-certificates'),
      (Icons.smart_toy_rounded, 'AI Chat', '/ai-assistant'),
    ];
    return SizedBox(
      height: 84,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: tools.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, i) {
          final (icon, label, route) = tools[i];
          return InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => context.push(route),
            child: Container(
              width: 76,
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.04), borderRadius: BorderRadius.circular(14)),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, color: DarkPalette.leafGreen, size: 22),
                  const SizedBox(height: 6),
                  Text(label, textAlign: TextAlign.center, style: const TextStyle(color: DarkPalette.textSecondary, fontSize: 10.5)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
  Widget _ordersEntryCard(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => context.push('/orders'),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(color: DarkPalette.leafGreen.withOpacity(0.15), shape: BoxShape.circle),
              child: const Icon(Icons.receipt_long_rounded, color: DarkPalette.leafGreen, size: 20),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('My Orders & Payments',
                      style: TextStyle(color: DarkPalette.textPrimary, fontSize: 13, fontWeight: FontWeight.w700)),
                  SizedBox(height: 2),
                  Text('Track orders, pay, and manage deliveries',
                      style: TextStyle(color: DarkPalette.textSecondary, fontSize: 11.5)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: DarkPalette.textMuted),
          ],
        ),
      ),
    );
  }

  Widget _categoryChips() {
    final categories = ['', ...marketplaceCategories];
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final category = categories[i];
          final label = category.isEmpty ? 'All' : category;
          final selected = _selectedCategory == category;
          return InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () {
              setState(() => _selectedCategory = category);
              ref.read(marketplaceProvider.notifier).setCategory(category);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: selected ? DarkPalette.leafGreen : Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Center(
                child: Text(
                  label,
                  style: TextStyle(
                    color: selected ? Colors.black : DarkPalette.textSecondary,
                    fontSize: 12,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildGrid(List<ListingModel> listings) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: listings.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.72,
      ),
      itemBuilder: (context, i) => _listingCard(listings[i]),
    );
  }

  Widget _listingCard(ListingModel listing) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => context.push('/marketplace/listings/${listing.id}'),
      child: Container(
        decoration: BoxDecoration(color: Colors.white.withOpacity(0.04), borderRadius: BorderRadius.circular(16)),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: listing.imageUrls.isNotEmpty
                  ? Image.network(
                      listing.imageUrls.first,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      errorBuilder: (_, __, ___) => _imagePlaceholder(),
                    )
                  : _imagePlaceholder(),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '?${listing.price.toStringAsFixed(0)}/${listing.unit}',
                    style: const TextStyle(color: DarkPalette.leafGreen, fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    listing.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: DarkPalette.textPrimary, fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Qty: ${listing.quantity.toStringAsFixed(0)} ${listing.unit}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: DarkPalette.textMuted, fontSize: 11),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          listing.shopName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: DarkPalette.textMuted, fontSize: 11),
                        ),
                      ),
                      if (listing.verified) const Icon(Icons.verified, color: DarkPalette.cyanAccent, size: 14),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _imagePlaceholder() {
    return Container(
      color: Colors.white.withOpacity(0.06),
      child: const Center(child: Icon(Icons.image_outlined, color: DarkPalette.textMuted, size: 28)),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.04), borderRadius: BorderRadius.circular(16)),
      child: const Center(child: Text('No listings found.', style: TextStyle(color: DarkPalette.textMuted, fontSize: 13))),
    );
  }

  Widget _buildErrorState(String? message) {
    return Padding(
      padding: const EdgeInsets.only(top: 60),
      child: Column(
        children: [
          const Icon(Icons.cloud_off_rounded, color: DarkPalette.textMuted, size: 40),
          const SizedBox(height: 12),
          Text(
            message ?? 'Could not load listings.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: DarkPalette.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => ref.read(marketplaceProvider.notifier).loadListings(),
            style: ElevatedButton.styleFrom(backgroundColor: DarkPalette.leafGreen, foregroundColor: Colors.black),
            child: const Text('Try again'),
          ),
        ],
      ),
    );
  }
}



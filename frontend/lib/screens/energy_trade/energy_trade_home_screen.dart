import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/dark_palette.dart';
import '../../models/commodity_listing_model.dart';
import '../../providers/energy_trade_provider.dart';
import '../../widgets/dark_text_field.dart';

class EnergyTradeHomeScreen extends ConsumerStatefulWidget {
  const EnergyTradeHomeScreen({super.key});

  @override
  ConsumerState<EnergyTradeHomeScreen> createState() => _EnergyTradeHomeScreenState();
}

class _EnergyTradeHomeScreenState extends ConsumerState<EnergyTradeHomeScreen> {
  final _searchController = TextEditingController();
  Timer? _debounce;
  String _selectedType = '';

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      ref.read(energyTradeProvider.notifier).setSearch(value.trim());
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(energyTradeProvider);

    return Scaffold(
      backgroundColor: DarkPalette.navyDeep,
      appBar: AppBar(
        backgroundColor: DarkPalette.navyDeep,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: DarkPalette.textPrimary), onPressed: () => context.pop()),
        title: const Text('Energy Trade', style: TextStyle(color: DarkPalette.textPrimary, fontSize: 16)),
        actions: [
          IconButton(
            icon: const Icon(Icons.receipt_long_outlined, color: DarkPalette.textPrimary),
            tooltip: 'My listings',
            onPressed: () => context.push('/energy-trade/my-listings'),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: DarkPalette.leafGreen,
        foregroundColor: Colors.black,
        onPressed: () => context.push('/energy-trade/post'),
        child: const Icon(Icons.add),
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(energyTradeProvider.notifier).loadListings(),
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
              DarkTextField(
                hint: 'Search listings...',
                icon: Icons.search,
                controller: _searchController,
                onChanged: _onSearchChanged,
              ),
              const SizedBox(height: 14),
              _commodityTypeChips(),
              const SizedBox(height: 16),
              if (state.browseStatus == LoadStatus.loading && state.listings.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 60),
                  child: Center(child: CircularProgressIndicator(color: DarkPalette.leafGreen)),
                )
              else if (state.browseStatus == LoadStatus.error && state.listings.isEmpty)
                _buildErrorState(state.browseError)
              else if (state.listings.isEmpty)
                _buildEmptyState()
              else
                _buildGrid(state.listings),
            ],
          ),
        ),
      ),
    );
  }

  // Inline rather than a shared FeatureIntroBanner widget -- this app
  // doesn't have one, unlike the pattern some other Flutter projects use.
  Widget _introBanner() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: DarkPalette.leafGreen.withOpacity(0.08), borderRadius: BorderRadius.circular(16)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.bolt_rounded, color: DarkPalette.leafGreen, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('B2B energy commodity trading',
                    style: TextStyle(color: DarkPalette.textPrimary, fontSize: 13, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(
                  'Browse coal, biomass, coke, and carbon credit listings from verified sellers, or tap + to post your own.',
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
              ref.read(energyTradeProvider.notifier).setCommodityType(type);
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

  Widget _buildGrid(List<CommodityListingModel> listings) {
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

  Widget _listingCard(CommodityListingModel listing) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => context.push('/energy-trade/listings/${listing.id}'),
      child: Container(
        decoration: BoxDecoration(color: Colors.white.withOpacity(0.04), borderRadius: BorderRadius.circular(16)),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 1.2,
              child: listing.imageUrls.isNotEmpty
                  ? Image.network(listing.imageUrls.first, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _imagePlaceholder())
                  : _imagePlaceholder(),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(commodityTypeIcon(listing.commodityType), color: DarkPalette.leafGreen, size: 12),
                      const SizedBox(width: 4),
                      Text(
                        commodityTypeLabel(listing.commodityType),
                        style: const TextStyle(color: DarkPalette.leafGreen, fontSize: 10, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '₹${listing.pricePerUnit.toStringAsFixed(0)}/${listing.unit}',
                    style: const TextStyle(color: DarkPalette.textPrimary, fontSize: 14, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    listing.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: DarkPalette.textSecondary, fontSize: 12, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${listing.quantity.toStringAsFixed(0)} ${listing.unit} available',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: DarkPalette.textMuted, fontSize: 10.5),
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
            onPressed: () => ref.read(energyTradeProvider.notifier).loadListings(),
            style: ElevatedButton.styleFrom(backgroundColor: DarkPalette.leafGreen, foregroundColor: Colors.black),
            child: const Text('Try again'),
          ),
        ],
      ),
    );
  }
}

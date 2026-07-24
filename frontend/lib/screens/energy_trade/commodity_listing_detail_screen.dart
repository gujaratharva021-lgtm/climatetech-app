import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/dark_palette.dart';
import '../../models/commodity_listing_model.dart';
import '../../providers/energy_trade_provider.dart';
import '../marketplace/listing_detail_screen.dart' show waPhoneDigits;

class CommodityListingDetailScreen extends ConsumerStatefulWidget {
  final String listingId;
  const CommodityListingDetailScreen({super.key, required this.listingId});

  @override
  ConsumerState<CommodityListingDetailScreen> createState() => _CommodityListingDetailScreenState();
}

class _CommodityListingDetailScreenState extends ConsumerState<CommodityListingDetailScreen> {
  bool _loading = true;
  String? _error;
  CommodityListingModel? _listing;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final service = ref.read(energyTradeServiceProvider);
      final listing = await service.getListingDetail(widget.listingId);
      if (!mounted) return;
      setState(() {
        _listing = listing;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _launch(Uri uri, String failureFallback) async {
    bool launched = false;
    try {
      launched = await launchUrl(uri);
    } catch (_) {
      launched = false;
    }
    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(failureFallback)));
    }
  }

  Future<void> _call() async {
    final phone = _listing?.contactPhone ?? '';
    if (phone.isEmpty) return;
    await _launch(Uri(scheme: 'tel', path: phone), 'Could not open the dialer. Contact: $phone');
  }

  Future<void> _whatsApp() async {
    final phone = _listing?.contactPhone ?? '';
    if (phone.isEmpty) return;
    final waNumber = waPhoneDigits(phone);
    if (waNumber.isEmpty) return;
    await _launch(Uri.parse('https://wa.me/$waNumber'), 'Could not open WhatsApp. Contact: $phone');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DarkPalette.navyDeep,
      appBar: AppBar(
        backgroundColor: DarkPalette.navyDeep,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: DarkPalette.textPrimary), onPressed: () => context.pop()),
        title: const Text('Listing', style: TextStyle(color: DarkPalette.textPrimary, fontSize: 16)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: DarkPalette.leafGreen))
          : (_error != null || _listing == null)
              ? _buildErrorState()
              : _buildContent(_listing!),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded, color: DarkPalette.textMuted, size: 40),
            const SizedBox(height: 12),
            Text(_error ?? 'Could not load this listing.',
                textAlign: TextAlign.center, style: const TextStyle(color: DarkPalette.textSecondary, fontSize: 13)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _load,
              style: ElevatedButton.styleFrom(backgroundColor: DarkPalette.leafGreen, foregroundColor: Colors.black),
              child: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(CommodityListingModel listing) {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (listing.imageUrls.isNotEmpty)
            SizedBox(
              height: 260,
              child: PageView.builder(
                itemCount: listing.imageUrls.length,
                itemBuilder: (context, i) => Container(
                  color: DarkPalette.navyCard,
                  alignment: Alignment.center,
                  child: Image.network(
                    listing.imageUrls[i],
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => Container(
                      color: Colors.white.withOpacity(0.04),
                      child: const Center(child: Icon(Icons.image_not_supported_outlined, color: DarkPalette.textMuted)),
                    ),
                  ),
                ),
              ),
            )
          else
            Container(
              height: 180,
              color: Colors.white.withOpacity(0.04),
              child: const Center(child: Icon(Icons.image_not_supported_outlined, color: DarkPalette.textMuted, size: 40)),
            ),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(commodityTypeIcon(listing.commodityType), color: DarkPalette.leafGreen, size: 22),
                    const SizedBox(width: 8),
                    Text(commodityTypeLabel(listing.commodityType),
                        style: const TextStyle(color: DarkPalette.leafGreen, fontSize: 13, fontWeight: FontWeight.w700)),
                  ],
                ),
                const SizedBox(height: 8),
                Text(listing.title,
                    style: const TextStyle(color: DarkPalette.textPrimary, fontSize: 17, fontWeight: FontWeight.w600)),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.04), borderRadius: BorderRadius.circular(16)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _priceRow('Price per ${listing.unit}', '₹${listing.pricePerUnit.toStringAsFixed(2)}'),
                      const SizedBox(height: 8),
                      _detailRow('Available quantity', '${listing.quantity.toStringAsFixed(0)} ${listing.unit}'),
                      if (listing.minOrderQty > 0) ...[
                        const SizedBox(height: 6),
                        _detailRow('Minimum order', '${listing.minOrderQty.toStringAsFixed(0)} ${listing.unit}'),
                      ],
                      if (listing.grade.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        _detailRow('Grade / spec', listing.grade),
                      ],
                      if (listing.location.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        _detailRow('Location', listing.location),
                      ],
                    ],
                  ),
                ),
                if (listing.description.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  const Text('Description',
                      style: TextStyle(color: DarkPalette.textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  Text(listing.description,
                      style: const TextStyle(color: DarkPalette.textSecondary, fontSize: 13, height: 1.5)),
                ],
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.04), borderRadius: BorderRadius.circular(16)),
                  child: Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(color: DarkPalette.leafGreen.withOpacity(0.15), shape: BoxShape.circle),
                        child: Center(
                          child: Text(
                            listing.shopName.isNotEmpty ? listing.shopName[0].toUpperCase() : '?',
                            style: const TextStyle(color: DarkPalette.leafGreen, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Row(
                          children: [
                            Flexible(
                              child: Text(
                                listing.shopName,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: DarkPalette.textPrimary, fontSize: 13, fontWeight: FontWeight.w600),
                              ),
                            ),
                            if (listing.verified)
                              const Padding(
                                padding: EdgeInsets.only(left: 4),
                                child: Icon(Icons.verified, color: DarkPalette.cyanAccent, size: 14),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: listing.contactPhone.isEmpty ? null : _call,
                        icon: Icon(Icons.call_outlined, color: listing.contactPhone.isEmpty ? DarkPalette.textMuted : Colors.black),
                        label: const Text('Call'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: DarkPalette.leafGreen,
                          foregroundColor: Colors.black,
                          disabledBackgroundColor: Colors.white.withOpacity(0.06),
                          disabledForegroundColor: DarkPalette.textMuted,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: listing.contactPhone.isEmpty ? null : _whatsApp,
                        icon: Icon(Icons.chat_outlined, color: listing.contactPhone.isEmpty ? DarkPalette.textMuted : Colors.black),
                        label: const Text('WhatsApp'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: DarkPalette.cyanAccent,
                          foregroundColor: Colors.black,
                          disabledBackgroundColor: Colors.white.withOpacity(0.06),
                          disabledForegroundColor: DarkPalette.textMuted,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                // RFQ (request-for-quote / reverse auction) and direct
                // ordering already exist on the backend, but their screens
                // aren't built yet — this is a clearly-labeled placeholder
                // rather than a silently missing feature, so it's obvious
                // what's coming next instead of looking like an oversight.
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.03),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withOpacity(0.08)),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('RFQ & direct ordering coming soon',
                          style: TextStyle(color: DarkPalette.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
                      SizedBox(height: 4),
                      Text('For now, use Call or WhatsApp to negotiate directly with the seller.',
                          style: TextStyle(color: DarkPalette.textMuted, fontSize: 11.5, height: 1.4)),
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

  Widget _priceRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: DarkPalette.textSecondary, fontSize: 12)),
        Text(value, style: const TextStyle(color: DarkPalette.leafGreen, fontSize: 18, fontWeight: FontWeight.w700)),
      ],
    );
  }

  Widget _detailRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: DarkPalette.textMuted, fontSize: 11.5)),
        Flexible(
          child: Text(value,
              textAlign: TextAlign.end,
              style: const TextStyle(color: DarkPalette.textPrimary, fontSize: 12.5, fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }
}

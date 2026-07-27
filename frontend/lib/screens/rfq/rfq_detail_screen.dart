import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/dark_palette.dart';
import '../../models/commodity_listing_model.dart';
import '../../models/rfq_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/rfq_provider.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/dark_text_field.dart';

class RFQDetailScreen extends ConsumerStatefulWidget {
  final String rfqId;
  const RFQDetailScreen({super.key, required this.rfqId});

  @override
  ConsumerState<RFQDetailScreen> createState() => _RFQDetailScreenState();
}

class _RFQDetailScreenState extends ConsumerState<RFQDetailScreen> {
  final _priceController = TextEditingController();
  final _quantityController = TextEditingController();
  final _messageController = TextEditingController();

  RFQModel? _rfq;
  List<BidModel> _bids = [];
  bool _loading = true;
  bool _submittingBid = false;
  bool _acceptingBidId = false;
  String? _error;
  String? _bidError;

  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
  }

  @override
  void dispose() {
    _priceController.dispose();
    _quantityController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rfq = await ref.read(rfqServiceProvider).getRFQDetail(widget.rfqId);
      final userId = ref.read(authProvider).user?.id;
      List<BidModel> bids = [];
      if (userId != null && rfq.buyerId == userId) {
        bids = await ref.read(rfqProvider.notifier).loadBidsForRFQ(widget.rfqId);
      }
      if (!mounted) return;
      setState(() {
        _rfq = rfq;
        _bids = bids;
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

  Future<void> _submitBid() async {
    final price = double.tryParse(_priceController.text.trim());
    final quantity = double.tryParse(_quantityController.text.trim());
    if (price == null || price <= 0 || quantity == null || quantity <= 0) {
      setState(() => _bidError = 'Enter a valid price and quantity.');
      return;
    }
    setState(() {
      _submittingBid = true;
      _bidError = null;
    });
    final success = await ref.read(rfqProvider.notifier).submitBid(
          rfqId: widget.rfqId,
          price: price,
          quantity: quantity,
          message: _messageController.text.trim(),
        );
    if (!mounted) return;
    setState(() => _submittingBid = false);
    if (success) {
      _priceController.clear();
      _quantityController.clear();
      _messageController.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bid submitted.')));
      }
    } else {
      setState(() => _bidError = ref.read(rfqProvider).myBidsError ?? 'Could not submit bid.');
    }
  }

  Future<void> _acceptBid(String bidId) async {
    setState(() => _acceptingBidId = true);
    final success = await ref.read(rfqProvider.notifier).acceptBid(rfqId: widget.rfqId, bidId: bidId);
    if (!mounted) return;
    setState(() => _acceptingBidId = false);
    if (success) {
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bid accepted, RFQ awarded.')));
      }
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ref.read(rfqProvider).myRFQsError ?? 'Could not accept bid.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final userId = ref.watch(authProvider).user?.id;
    final isOwner = _rfq != null && userId != null && _rfq!.buyerId == userId;

    return Scaffold(
      backgroundColor: DarkPalette.navyDeep,
      appBar: AppBar(
        backgroundColor: DarkPalette.navyDeep,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: DarkPalette.textPrimary), onPressed: () => context.pop()),
        title: const Text('RFQ Detail', style: TextStyle(color: DarkPalette.textPrimary, fontSize: 16)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: DarkPalette.leafGreen))
          : _error != null
              ? _buildErrorState()
              : _rfq == null
                  ? const SizedBox.shrink()
                  : RefreshIndicator(
                      onRefresh: _load,
                      color: DarkPalette.leafGreen,
                      backgroundColor: DarkPalette.navyCard,
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _rfqSummaryCard(_rfq!),
                            const SizedBox(height: 20),
                            if (isOwner) _buildBidsSection() else if (_rfq!.status == RFQStatus.open) _buildBidForm(),
                          ],
                        ),
                      ),
                    ),
    );
  }

  Widget _rfqSummaryCard(RFQModel rfq) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.04), borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(commodityTypeIcon(rfq.commodityType), color: DarkPalette.leafGreen, size: 20),
              const SizedBox(width: 8),
              Text(commodityTypeLabel(rfq.commodityType),
                  style: const TextStyle(color: DarkPalette.leafGreen, fontSize: 13, fontWeight: FontWeight.w700)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: rfqStatusColor(rfq.status).withOpacity(0.15), borderRadius: BorderRadius.circular(20)),
                child: Text(rfqStatusLabel(rfq.status),
                    style: TextStyle(color: rfqStatusColor(rfq.status), fontSize: 11, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text('${rfq.quantity.toStringAsFixed(0)} ${rfq.unit} needed',
              style: const TextStyle(color: DarkPalette.textPrimary, fontSize: 20, fontWeight: FontWeight.w800)),
          if (rfq.targetPrice > 0) ...[
            const SizedBox(height: 4),
            Text('Target price: ₹${rfq.targetPrice.toStringAsFixed(0)}/${rfq.unit}',
                style: const TextStyle(color: DarkPalette.textSecondary, fontSize: 13)),
          ],
          if (rfq.grade.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text('Grade / spec', style: TextStyle(color: DarkPalette.textMuted, fontSize: 11)),
            const SizedBox(height: 2),
            Text(rfq.grade, style: const TextStyle(color: DarkPalette.textSecondary, fontSize: 13)),
          ],
          if (rfq.location.isNotEmpty) ...[
            const SizedBox(height: 10),
            Row(children: [
              const Icon(Icons.location_on_outlined, color: DarkPalette.textMuted, size: 14),
              const SizedBox(width: 4),
              Text(rfq.location, style: const TextStyle(color: DarkPalette.textSecondary, fontSize: 13)),
            ]),
          ],
          const SizedBox(height: 10),
          Row(children: [
            const Icon(Icons.event_outlined, color: DarkPalette.textMuted, size: 14),
            const SizedBox(width: 4),
            Text('Bids close ${rfq.deadline.day}/${rfq.deadline.month}/${rfq.deadline.year}',
                style: const TextStyle(color: DarkPalette.textSecondary, fontSize: 13)),
          ]),
        ],
      ),
    );
  }

  Widget _buildBidForm() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.04), borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Submit your bid', style: TextStyle(color: DarkPalette.textPrimary, fontSize: 14, fontWeight: FontWeight.w700)),
          const SizedBox(height: 14),
          DarkTextField(
            hint: 'Your price per unit (₹)',
            icon: Icons.currency_rupee,
            controller: _priceController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
          const SizedBox(height: 10),
          DarkTextField(
            hint: 'Quantity you can supply',
            icon: Icons.scale_outlined,
            controller: _quantityController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
          const SizedBox(height: 10),
          DarkTextField(
            hint: 'Message (optional)',
            icon: Icons.notes_rounded,
            controller: _messageController,
          ),
          if (_bidError != null) ...[
            const SizedBox(height: 10),
            Text(_bidError!, style: const TextStyle(color: Color(0xFFE0605A), fontSize: 12)),
          ],
          const SizedBox(height: 14),
          CustomButton(label: 'Submit bid', isLoading: _submittingBid, onPressed: _submitBid),
        ],
      ),
    );
  }

  Widget _buildBidsSection() {
    if (_bids.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: Colors.white.withOpacity(0.04), borderRadius: BorderRadius.circular(16)),
        child: const Center(child: Text('No bids yet.', style: TextStyle(color: DarkPalette.textMuted, fontSize: 13))),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Bids (${_bids.length})', style: const TextStyle(color: DarkPalette.textPrimary, fontSize: 14, fontWeight: FontWeight.w700)),
        const SizedBox(height: 10),
        ...(_bids.map(_bidCard)),
      ],
    );
  }

  Widget _bidCard(BidModel bid) {
    final canAccept = _rfq?.status == RFQStatus.open && bid.status == BidStatus.pending;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bid.status == BidStatus.accepted ? DarkPalette.leafGreen.withOpacity(0.08) : Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(14),
        border: bid.status == BidStatus.accepted ? Border.all(color: DarkPalette.leafGreen.withOpacity(0.4)) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Row(children: [
                  Flexible(child: Text(bid.shopName.isEmpty ? 'Seller' : bid.shopName, style: const TextStyle(color: DarkPalette.textPrimary, fontSize: 13, fontWeight: FontWeight.w600))),
                  if (bid.verified) const Padding(padding: EdgeInsets.only(left: 4), child: Icon(Icons.verified, color: DarkPalette.cyanAccent, size: 14)),
                ]),
              ),
              Text(bidStatusLabel(bid.status), style: TextStyle(color: DarkPalette.textMuted, fontSize: 11)),
            ],
          ),
          const SizedBox(height: 8),
          Text('₹${bid.price.toStringAsFixed(0)}/unit  ·  ${bid.quantity.toStringAsFixed(0)} units',
              style: const TextStyle(color: DarkPalette.textPrimary, fontSize: 15, fontWeight: FontWeight.w700)),
          if (bid.message.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(bid.message, style: const TextStyle(color: DarkPalette.textSecondary, fontSize: 12)),
          ],
          if (canAccept) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: CustomButton(
                label: 'Accept bid',
                isLoading: _acceptingBidId,
                onPressed: () => _acceptBid(bid.id),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Padding(
      padding: const EdgeInsets.only(top: 60),
      child: Column(
        children: [
          const Icon(Icons.cloud_off_rounded, color: DarkPalette.textMuted, size: 40),
          const SizedBox(height: 12),
          Text(_error ?? 'Could not load this RFQ.', textAlign: TextAlign.center, style: const TextStyle(color: DarkPalette.textSecondary, fontSize: 13)),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _load,
            style: ElevatedButton.styleFrom(backgroundColor: DarkPalette.leafGreen, foregroundColor: Colors.black),
            child: const Text('Try again'),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/dark_palette.dart';
import '../../models/commodity_listing_model.dart';
import '../../models/seller_model.dart';
import '../../providers/energy_trade_provider.dart';
import '../../providers/marketplace_provider.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/dark_text_field.dart';
import '../../widgets/gallery_photo_picker.dart';

/// Units a seller can price/quantify a commodity listing in. Kept to a
/// short, fixed list rather than free text -- unlike Grade (which is
/// inherently a free-text spec), Unit needs to be one of a few known values
/// so the price-index and RFQ features elsewhere in the app can group by it
/// meaningfully.
const List<String> _commodityUnits = ['ton', 'kg', 'MT', 'unit'];

class PostCommodityListingScreen extends ConsumerStatefulWidget {
  const PostCommodityListingScreen({super.key});

  @override
  ConsumerState<PostCommodityListingScreen> createState() => _PostCommodityListingScreenState();
}

class _PostCommodityListingScreenState extends ConsumerState<PostCommodityListingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  final _quantityController = TextEditingController();
  final _minOrderQtyController = TextEditingController();
  final _gradeController = TextEditingController();
  final _locationController = TextEditingController();

  String _commodityType = commodityTypes.first;
  String _unit = _commodityUnits.first;
  List<String> _imageUrls = [];
  String? _imageUrlsError;
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _quantityController.dispose();
    _minOrderQtyController.dispose();
    _gradeController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final formState = _formKey.currentState;
    if (formState == null) return;
    final formValid = formState.validate();
    final hasImages = _imageUrls.isNotEmpty;
    setState(() => _imageUrlsError = hasImages ? null : 'Add at least one photo');
    if (!formValid || !hasImages) return;

    setState(() {
      _submitting = true;
      _error = null;
    });

    final price = double.tryParse(_priceController.text.trim()) ?? 0;
    final quantity = double.tryParse(_quantityController.text.trim()) ?? 0;
    final minOrderQty = double.tryParse(_minOrderQtyController.text.trim()) ?? 0;

    final success = await ref.read(energyTradeProvider.notifier).createListing(
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim(),
          pricePerUnit: price,
          commodityType: _commodityType,
          quantity: quantity,
          unit: _unit,
          minOrderQty: minOrderQty,
          grade: _gradeController.text.trim(),
          imageUrls: _imageUrls,
          location: _locationController.text.trim(),
        );

    if (!mounted) return;
    if (success) {
      context.pop();
    } else {
      setState(() {
        _submitting = false;
        _error = ref.read(energyTradeProvider).myListingsError ?? 'Could not post your listing.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Reuses the eco-goods marketplace's seller-profile state rather than
    // fetching it separately -- an approved seller profile is a property
    // of the user, not of which section of the marketplace they're
    // trading in, so both sections share this one source of truth instead
    // of risking two independently-fetched copies drifting out of sync.
    final seller = ref.watch(marketplaceProvider.select((s) => s.mySeller));
    final isApproved = seller?.isApproved ?? false;

    return Scaffold(
      backgroundColor: DarkPalette.navyDeep,
      appBar: AppBar(
        backgroundColor: DarkPalette.navyDeep,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: DarkPalette.textPrimary), onPressed: () => context.pop()),
        title: const Text('Post a commodity listing', style: TextStyle(color: DarkPalette.textPrimary, fontSize: 16)),
      ),
      body: isApproved ? _buildForm() : _buildBecomeSellerPrompt(seller),
    );
  }

  Widget _buildBecomeSellerPrompt(SellerModel? seller) {
    final isPending = seller?.isPending ?? false;
    final isRejected = seller?.isRejected ?? false;

    String title;
    String message;
    if (isPending) {
      title = 'Application pending';
      message = "Your seller application is still under review. You can post listings once it's approved.";
    } else if (isRejected) {
      title = 'Application rejected';
      message = "Your seller application wasn't approved. Contact support if you think this is a mistake.";
    } else {
      title = 'Become a seller first';
      message = 'You need an approved seller profile before you can post listings on the marketplace.';
    }

    return RefreshIndicator(
      onRefresh: () => ref.read(marketplaceProvider.notifier).loadMySellerProfile(),
      color: DarkPalette.leafGreen,
      backgroundColor: DarkPalette.navyCard,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        child: Padding(
          padding: const EdgeInsets.only(top: 60),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.storefront_outlined, color: DarkPalette.textMuted, size: 40),
              const SizedBox(height: 16),
              Text(title, style: const TextStyle(color: DarkPalette.textPrimary, fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: DarkPalette.textSecondary, fontSize: 13, height: 1.5),
              ),
              const SizedBox(height: 24),
              if (!isPending)
                CustomButton(
                  label: isRejected ? 'Reapply as a seller' : 'Become a seller',
                  onPressed: () => context.push('/marketplace/become-seller'),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(18),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _label('Commodity'),
            _dropdown(
              _commodityType,
              commodityTypes,
              (v) => setState(() => _commodityType = v ?? _commodityType),
              labelBuilder: commodityTypeLabel,
            ),
            const SizedBox(height: 14),
            _label('Title'),
            DarkTextField(
              hint: 'e.g. Grade A steam coal, washed',
              icon: Icons.sell_outlined,
              controller: _titleController,
              validator: _required,
            ),
            const SizedBox(height: 14),
            _label('Description'),
            DarkTextField(hint: 'Describe the commodity', icon: Icons.notes_rounded, controller: _descriptionController),
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _label('Quantity available'),
                      DarkTextField(
                        hint: '0',
                        icon: Icons.scale_outlined,
                        controller: _quantityController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        validator: (v) {
                          final n = double.tryParse(v ?? '');
                          if (n == null || n <= 0) return 'Enter a valid quantity';
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _label('Unit'),
                      _dropdown(_unit, _commodityUnits, (v) => setState(() => _unit = v ?? _unit)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _label('Minimum order quantity (optional)'),
            DarkTextField(
              hint: '0',
              icon: Icons.production_quantity_limits_outlined,
              controller: _minOrderQtyController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 14),
            _label('Price per $_unit (₹)'),
            DarkTextField(
              hint: '0',
              icon: Icons.currency_rupee,
              controller: _priceController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              validator: (v) {
                final n = double.tryParse(v ?? '');
                if (n == null || n <= 0) return 'Enter a valid price';
                return null;
              },
            ),
            const SizedBox(height: 14),
            _label('Grade / quality spec (optional)'),
            DarkTextField(
              hint: 'e.g. GCV 4200 kcal/kg, Ash <15%',
              icon: Icons.high_quality_outlined,
              controller: _gradeController,
            ),
            const SizedBox(height: 14),
            _label('Location (optional)'),
            DarkTextField(hint: 'e.g. Dhanbad, Jharkhand', icon: Icons.location_on_outlined, controller: _locationController),
            const SizedBox(height: 14),
            _label('Photos'),
            GalleryPhotoPicker(urls: _imageUrls, onChanged: (urls) => setState(() => _imageUrls = urls)),
            if (_imageUrlsError != null) ...[
              const SizedBox(height: 6),
              Text(_imageUrlsError!, style: const TextStyle(color: Color(0xFFE0605A), fontSize: 12)),
            ],
            if (_error != null) ...[
              const SizedBox(height: 14),
              Text(_error!, style: const TextStyle(color: Color(0xFFE0605A), fontSize: 12)),
            ],
            const SizedBox(height: 24),
            CustomButton(label: 'Post listing', isLoading: _submitting, onPressed: _submit),
          ],
        ),
      ),
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text, style: const TextStyle(color: DarkPalette.textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
      );

  String? _required(String? v) => (v == null || v.trim().isEmpty) ? 'Required' : null;

  Widget _dropdown(
    String value,
    List<String> options,
    ValueChanged<String?> onChanged, {
    String Function(String)? labelBuilder,
  }) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      isExpanded: true,
      dropdownColor: DarkPalette.navyCard,
      style: const TextStyle(color: DarkPalette.textPrimary, fontSize: 13),
      decoration: InputDecoration(
        filled: true,
        fillColor: Colors.white.withOpacity(0.05),
        contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
      ),
      items: options.map((o) => DropdownMenuItem(value: o, child: Text(labelBuilder != null ? labelBuilder(o) : o))).toList(),
      onChanged: onChanged,
    );
  }
}

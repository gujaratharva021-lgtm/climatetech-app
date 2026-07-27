import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/dark_palette.dart';
import '../../models/commodity_listing_model.dart';
import '../../providers/rfq_provider.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/dark_text_field.dart';

const List<String> _rfqUnits = ['ton', 'kg', 'MT', 'unit'];

class PostRFQScreen extends ConsumerStatefulWidget {
  const PostRFQScreen({super.key});

  @override
  ConsumerState<PostRFQScreen> createState() => _PostRFQScreenState();
}

class _PostRFQScreenState extends ConsumerState<PostRFQScreen> {
  final _formKey = GlobalKey<FormState>();
  final _quantityController = TextEditingController();
  final _targetPriceController = TextEditingController();
  final _gradeController = TextEditingController();
  final _locationController = TextEditingController();

  String _commodityType = commodityTypes.first;
  String _unit = _rfqUnits.first;
  DateTime? _deadline;
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _quantityController.dispose();
    _targetPriceController.dispose();
    _gradeController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _pickDeadline() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(days: 7)),
      firstDate: now.add(const Duration(days: 1)),
      lastDate: now.add(const Duration(days: 365)),
      builder: (context, child) => Theme(
        data: ThemeData.dark().copyWith(colorScheme: const ColorScheme.dark(primary: DarkPalette.leafGreen)),
        child: child!,
      ),
    );
    if (date != null) {
      setState(() => _deadline = date);
    }
  }

  Future<void> _submit() async {
    final formState = _formKey.currentState;
    if (formState == null) return;
    final formValid = formState.validate();
    if (!formValid || _deadline == null) {
      if (_deadline == null) setState(() => _error = 'Pick a deadline for bids.');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    final success = await ref.read(rfqProvider.notifier).createRFQ(
          commodityType: _commodityType,
          quantity: double.tryParse(_quantityController.text.trim()) ?? 0,
          unit: _unit,
          targetPrice: double.tryParse(_targetPriceController.text.trim()) ?? 0,
          grade: _gradeController.text.trim(),
          location: _locationController.text.trim(),
          deadline: _deadline!,
        );

    if (!mounted) return;
    if (success) {
      context.pop();
    } else {
      setState(() {
        _submitting = false;
        _error = ref.read(rfqProvider).myRFQsError ?? 'Could not post your RFQ.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DarkPalette.navyDeep,
      appBar: AppBar(
        backgroundColor: DarkPalette.navyDeep,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: DarkPalette.textPrimary), onPressed: () => context.pop()),
        title: const Text('Post a requirement (RFQ)', style: TextStyle(color: DarkPalette.textPrimary, fontSize: 16)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(18),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _label('Commodity'),
              _dropdown(_commodityType, commodityTypes, (v) => setState(() => _commodityType = v ?? _commodityType),
                  labelBuilder: commodityTypeLabel),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _label('Quantity needed'),
                        DarkTextField(
                          hint: '0',
                          icon: Icons.scale_outlined,
                          controller: _quantityController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          validator: (v) {
                            final n = double.tryParse(v ?? '');
                            if (n == null || n <= 0) return 'Required';
                            return null;
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _label('Unit'),
                        _dropdown(_unit, _rfqUnits, (v) => setState(() => _unit = v ?? _unit)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _label('Target price per $_unit (optional, ₹)'),
              DarkTextField(
                hint: '0',
                icon: Icons.currency_rupee,
                controller: _targetPriceController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 14),
              _label('Grade / quality spec (optional)'),
              DarkTextField(
                hint: 'e.g. GCV 4200 kcal/kg, Ash <15%',
                icon: Icons.workspace_premium_outlined,
                controller: _gradeController,
              ),
              const SizedBox(height: 14),
              _label('Location (optional)'),
              DarkTextField(
                hint: 'e.g. Dhanbad, Jharkhand',
                icon: Icons.location_on_outlined,
                controller: _locationController,
              ),
              const SizedBox(height: 14),
              _label('Bid deadline'),
              InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: _pickDeadline,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.event_outlined, color: DarkPalette.textMuted, size: 18),
                      const SizedBox(width: 10),
                      Text(
                        _deadline == null
                            ? 'Select a date'
                            : '${_deadline!.day}/${_deadline!.month}/${_deadline!.year}',
                        style: TextStyle(
                          color: _deadline == null ? DarkPalette.textMuted : DarkPalette.textPrimary,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 14),
                Text(_error!, style: const TextStyle(color: Color(0xFFE0605A), fontSize: 12)),
              ],
              const SizedBox(height: 24),
              CustomButton(label: 'Post RFQ', isLoading: _submitting, onPressed: _submit),
            ],
          ),
        ),
      ),
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text, style: const TextStyle(color: DarkPalette.textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
      );

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

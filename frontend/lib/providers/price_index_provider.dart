import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/price_index_model.dart';
import '../services/price_index_service.dart';
import 'auth_provider.dart';
import 'marketplace_provider.dart' show LoadStatus;

final priceIndexApiServiceProvider = Provider<PriceIndexApiService>((ref) {
  return PriceIndexApiService(ref.read(apiServiceProvider));
});

class PriceIndexState {
  final LoadStatus status;
  final List<LiveIndexModel> indexes;
  final String? error;

  const PriceIndexState({
    this.status = LoadStatus.initial,
    this.indexes = const [],
    this.error,
  });

  PriceIndexState copyWith({
    LoadStatus? status,
    List<LiveIndexModel>? indexes,
    String? error,
  }) {
    return PriceIndexState(
      status: status ?? this.status,
      indexes: indexes ?? this.indexes,
      error: error,
    );
  }
}

class PriceIndexNotifier extends StateNotifier<PriceIndexState> {
  final PriceIndexApiService _service;

  PriceIndexNotifier(this._service) : super(const PriceIndexState()) {
    loadAll();
  }

  Future<void> loadAll() async {
    state = state.copyWith(status: LoadStatus.loading, error: null);
    try {
      final indexes = await _service.getAllPriceIndexes();
      state = state.copyWith(status: LoadStatus.loaded, indexes: indexes);
    } catch (e) {
      state = state.copyWith(status: LoadStatus.error, error: e.toString());
    }
  }

  Future<List<PriceHistoryPoint>> loadHistory(String commodityType, {int days = 90, String source = 'transacted'}) {
    return _service.getPriceHistory(commodityType, days: days, source: source);
  }
}

final priceIndexProvider = StateNotifierProvider<PriceIndexNotifier, PriceIndexState>((ref) {
  return PriceIndexNotifier(ref.read(priceIndexApiServiceProvider));
});

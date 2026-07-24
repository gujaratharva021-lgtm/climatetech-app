import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/commodity_listing_model.dart';
import '../services/energy_trade_service.dart';
import 'auth_provider.dart';
// LoadStatus already exists in marketplace_provider.dart -- reused here
// rather than redefined, since redefining it would be an ambiguous-name
// compile error the moment any screen imports both providers (which
// post_commodity_listing_screen.dart does, for its shared seller-profile
// state). Both imported (for use in this file) and re-exported (so files
// that only import this provider still see the name), which is the
// standard Dart pattern for sharing one declaration across libraries.
import 'marketplace_provider.dart' show LoadStatus;

export 'marketplace_provider.dart' show LoadStatus;

final energyTradeServiceProvider = Provider<EnergyTradeService>((ref) {
  return EnergyTradeService(ref.read(apiServiceProvider));
});

class EnergyTradeState {
  final LoadStatus browseStatus;
  final List<CommodityListingModel> listings;
  final String? browseError;

  final LoadStatus myListingsStatus;
  final List<CommodityListingModel> myListings;
  final String? myListingsError;

  const EnergyTradeState({
    this.browseStatus = LoadStatus.initial,
    this.listings = const [],
    this.browseError,
    this.myListingsStatus = LoadStatus.initial,
    this.myListings = const [],
    this.myListingsError,
  });

  EnergyTradeState copyWith({
    LoadStatus? browseStatus,
    List<CommodityListingModel>? listings,
    String? browseError,
    LoadStatus? myListingsStatus,
    List<CommodityListingModel>? myListings,
    String? myListingsError,
  }) {
    return EnergyTradeState(
      browseStatus: browseStatus ?? this.browseStatus,
      listings: listings ?? this.listings,
      browseError: browseError,
      myListingsStatus: myListingsStatus ?? this.myListingsStatus,
      myListings: myListings ?? this.myListings,
      myListingsError: myListingsError,
    );
  }
}

class EnergyTradeNotifier extends StateNotifier<EnergyTradeState> {
  final EnergyTradeService _service;

  String _commodityType = '';
  String _search = '';

  // Same stale-request guard MarketplaceNotifier uses for browseListings —
  // a fast filter change firing while the previous request is still in
  // flight shouldn't let that older response overwrite newer results.
  int _browseRequestId = 0;

  EnergyTradeNotifier(this._service) : super(const EnergyTradeState()) {
    loadListings();
  }

  Future<void> loadListings() async {
    final requestId = ++_browseRequestId;
    state = state.copyWith(browseStatus: LoadStatus.loading, browseError: null);
    try {
      final listings = await _service.browseListings(commodityType: _commodityType, search: _search);
      if (requestId != _browseRequestId) return;
      state = state.copyWith(browseStatus: LoadStatus.loaded, listings: listings);
    } catch (e) {
      if (requestId != _browseRequestId) return;
      state = state.copyWith(browseStatus: LoadStatus.error, browseError: e.toString());
    }
  }

  Future<void> setCommodityType(String commodityType) async {
    if (_commodityType == commodityType) return;
    _commodityType = commodityType;
    await loadListings();
  }

  Future<void> setSearch(String query) async {
    if (_search == query) return;
    _search = query;
    await loadListings();
  }

  Future<void> loadMyListings() async {
    state = state.copyWith(myListingsStatus: LoadStatus.loading, myListingsError: null);
    try {
      final listings = await _service.getMyListings();
      state = state.copyWith(myListingsStatus: LoadStatus.loaded, myListings: listings);
    } catch (e) {
      state = state.copyWith(myListingsStatus: LoadStatus.error, myListingsError: e.toString());
    }
  }

  Future<bool> createListing({
    required String title,
    String? description,
    required double pricePerUnit,
    required String commodityType,
    required double quantity,
    required String unit,
    double minOrderQty = 0,
    String? grade,
    List<String> imageUrls = const [],
    String? location,
  }) async {
    try {
      final created = await _service.createListing(
        title: title,
        description: description,
        pricePerUnit: pricePerUnit,
        commodityType: commodityType,
        quantity: quantity,
        unit: unit,
        minOrderQty: minOrderQty,
        grade: grade,
        imageUrls: imageUrls,
        location: location,
      );
      await loadMyListings();

      final matchesType = _commodityType.isEmpty || created.commodityType == _commodityType;
      final matchesSearch = _search.isEmpty || created.title.toLowerCase().contains(_search.toLowerCase());
      if (matchesType && matchesSearch) {
        state = state.copyWith(listings: [created, ...state.listings]);
      }
      return true;
    } catch (e) {
      state = state.copyWith(myListingsError: e.toString());
      return false;
    }
  }

  Future<bool> deleteListing(String id) async {
    try {
      await _service.deleteListing(id);
      state = state.copyWith(
        myListings: state.myListings.where((l) => l.id != id).toList(),
        listings: state.listings.where((l) => l.id != id).toList(),
      );
      return true;
    } catch (e) {
      state = state.copyWith(myListingsError: e.toString());
      return false;
    }
  }
}

final energyTradeProvider = StateNotifierProvider<EnergyTradeNotifier, EnergyTradeState>((ref) {
  return EnergyTradeNotifier(ref.read(energyTradeServiceProvider));
});

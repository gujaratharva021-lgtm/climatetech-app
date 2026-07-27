import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/rfq_model.dart';
import '../services/rfq_service.dart';
import 'auth_provider.dart';
import 'marketplace_provider.dart' show LoadStatus;

export 'marketplace_provider.dart' show LoadStatus;

final rfqServiceProvider = Provider<RFQService>((ref) {
  return RFQService(ref.read(apiServiceProvider));
});

class RFQState {
  final LoadStatus browseStatus;
  final List<RFQModel> rfqs;
  final String? browseError;

  final LoadStatus myRFQsStatus;
  final List<RFQModel> myRFQs;
  final String? myRFQsError;

  final LoadStatus myBidsStatus;
  final List<BidModel> myBids;
  final String? myBidsError;

  const RFQState({
    this.browseStatus = LoadStatus.initial,
    this.rfqs = const [],
    this.browseError,
    this.myRFQsStatus = LoadStatus.initial,
    this.myRFQs = const [],
    this.myRFQsError,
    this.myBidsStatus = LoadStatus.initial,
    this.myBids = const [],
    this.myBidsError,
  });

  RFQState copyWith({
    LoadStatus? browseStatus,
    List<RFQModel>? rfqs,
    String? browseError,
    LoadStatus? myRFQsStatus,
    List<RFQModel>? myRFQs,
    String? myRFQsError,
    LoadStatus? myBidsStatus,
    List<BidModel>? myBids,
    String? myBidsError,
  }) {
    return RFQState(
      browseStatus: browseStatus ?? this.browseStatus,
      rfqs: rfqs ?? this.rfqs,
      browseError: browseError,
      myRFQsStatus: myRFQsStatus ?? this.myRFQsStatus,
      myRFQs: myRFQs ?? this.myRFQs,
      myRFQsError: myRFQsError,
      myBidsStatus: myBidsStatus ?? this.myBidsStatus,
      myBids: myBids ?? this.myBids,
      myBidsError: myBidsError,
    );
  }
}

class RFQNotifier extends StateNotifier<RFQState> {
  final RFQService _service;

  String _commodityType = '';
  int _browseRequestId = 0;

  RFQNotifier(this._service) : super(const RFQState()) {
    loadRFQs();
  }

  Future<void> loadRFQs() async {
    final requestId = ++_browseRequestId;
    state = state.copyWith(browseStatus: LoadStatus.loading, browseError: null);
    try {
      final rfqs = await _service.browseRFQs(commodityType: _commodityType);
      if (requestId != _browseRequestId) return;
      state = state.copyWith(browseStatus: LoadStatus.loaded, rfqs: rfqs);
    } catch (e) {
      if (requestId != _browseRequestId) return;
      state = state.copyWith(browseStatus: LoadStatus.error, browseError: e.toString());
    }
  }

  Future<void> setCommodityType(String commodityType) async {
    if (_commodityType == commodityType) return;
    _commodityType = commodityType;
    await loadRFQs();
  }

  Future<void> loadMyRFQs() async {
    state = state.copyWith(myRFQsStatus: LoadStatus.loading, myRFQsError: null);
    try {
      final rfqs = await _service.getMyRFQs();
      state = state.copyWith(myRFQsStatus: LoadStatus.loaded, myRFQs: rfqs);
    } catch (e) {
      state = state.copyWith(myRFQsStatus: LoadStatus.error, myRFQsError: e.toString());
    }
  }

  Future<void> loadMyBids() async {
    state = state.copyWith(myBidsStatus: LoadStatus.loading, myBidsError: null);
    try {
      final bids = await _service.getMyBids();
      state = state.copyWith(myBidsStatus: LoadStatus.loaded, myBids: bids);
    } catch (e) {
      state = state.copyWith(myBidsStatus: LoadStatus.error, myBidsError: e.toString());
    }
  }

  Future<bool> createRFQ({
    required String commodityType,
    required double quantity,
    String unit = 'unit',
    double targetPrice = 0,
    String? grade,
    String? location,
    required DateTime deadline,
  }) async {
    try {
      await _service.createRFQ(
        commodityType: commodityType,
        quantity: quantity,
        unit: unit,
        targetPrice: targetPrice,
        grade: grade,
        location: location,
        deadline: deadline,
      );
      await loadMyRFQs();
      return true;
    } catch (e) {
      state = state.copyWith(myRFQsError: e.toString());
      return false;
    }
  }

  Future<bool> cancelRFQ(String id) async {
    try {
      await _service.cancelRFQ(id);
      await loadMyRFQs();
      return true;
    } catch (e) {
      state = state.copyWith(myRFQsError: e.toString());
      return false;
    }
  }

  Future<bool> submitBid({
    required String rfqId,
    required double price,
    required double quantity,
    String? message,
  }) async {
    try {
      await _service.submitBid(rfqId: rfqId, price: price, quantity: quantity, message: message);
      await loadMyBids();
      return true;
    } catch (e) {
      state = state.copyWith(myBidsError: e.toString());
      return false;
    }
  }

  Future<List<BidModel>> loadBidsForRFQ(String rfqId) async {
    return _service.listBidsForRFQ(rfqId);
  }

  Future<bool> acceptBid({required String rfqId, required String bidId}) async {
    try {
      await _service.acceptBid(rfqId: rfqId, bidId: bidId);
      await loadMyRFQs();
      return true;
    } catch (e) {
      state = state.copyWith(myRFQsError: e.toString());
      return false;
    }
  }
}

final rfqProvider = StateNotifierProvider<RFQNotifier, RFQState>((ref) {
  return RFQNotifier(ref.read(rfqServiceProvider));
});


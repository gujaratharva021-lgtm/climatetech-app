import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/financing_model.dart';
import '../services/financing_service.dart';
import 'auth_provider.dart';
import 'marketplace_provider.dart' show LoadStatus;

export 'marketplace_provider.dart' show LoadStatus;

final financingServiceProvider = Provider<FinancingService>((ref) {
  return FinancingService(ref.read(apiServiceProvider));
});

class FinancingState {
  final LoadStatus myRequestsStatus;
  final List<FinancingRequestModel> myRequests;
  final String? myRequestsError;

  const FinancingState({
    this.myRequestsStatus = LoadStatus.initial,
    this.myRequests = const [],
    this.myRequestsError,
  });

  FinancingState copyWith({
    LoadStatus? myRequestsStatus,
    List<FinancingRequestModel>? myRequests,
    String? myRequestsError,
  }) {
    return FinancingState(
      myRequestsStatus: myRequestsStatus ?? this.myRequestsStatus,
      myRequests: myRequests ?? this.myRequests,
      myRequestsError: myRequestsError,
    );
  }
}

class FinancingNotifier extends StateNotifier<FinancingState> {
  final FinancingService _service;

  FinancingNotifier(this._service) : super(const FinancingState());

  Future<void> loadMyRequests() async {
    state = state.copyWith(myRequestsStatus: LoadStatus.loading, myRequestsError: null);
    try {
      final requests = await _service.getMyFinancingRequests();
      state = state.copyWith(myRequestsStatus: LoadStatus.loaded, myRequests: requests);
    } catch (e) {
      state = state.copyWith(myRequestsStatus: LoadStatus.error, myRequestsError: e.toString());
    }
  }

  Future<bool> createRequest({required String orderId, required double requestedAmount, String? purpose}) async {
    try {
      await _service.createFinancingRequest(orderId: orderId, requestedAmount: requestedAmount, purpose: purpose);
      await loadMyRequests();
      return true;
    } catch (e) {
      state = state.copyWith(myRequestsError: e.toString());
      return false;
    }
  }
}

final financingProvider = StateNotifierProvider<FinancingNotifier, FinancingState>((ref) {
  return FinancingNotifier(ref.read(financingServiceProvider));
});

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/inspection_model.dart';
import '../services/inspection_service.dart';
import 'auth_provider.dart';
import 'marketplace_provider.dart' show LoadStatus;

export 'marketplace_provider.dart' show LoadStatus;

final inspectionServiceProvider = Provider<InspectionService>((ref) {
  return InspectionService(ref.read(apiServiceProvider));
});

class InspectionState {
  final LoadStatus myStatus;
  final List<InspectionModel> myInspections;
  final String? myError;

  final LoadStatus assignedStatus;
  final List<InspectionModel> assignedInspections;
  final String? assignedError;

  const InspectionState({
    this.myStatus = LoadStatus.initial,
    this.myInspections = const [],
    this.myError,
    this.assignedStatus = LoadStatus.initial,
    this.assignedInspections = const [],
    this.assignedError,
  });

  InspectionState copyWith({
    LoadStatus? myStatus,
    List<InspectionModel>? myInspections,
    String? myError,
    LoadStatus? assignedStatus,
    List<InspectionModel>? assignedInspections,
    String? assignedError,
  }) {
    return InspectionState(
      myStatus: myStatus ?? this.myStatus,
      myInspections: myInspections ?? this.myInspections,
      myError: myError,
      assignedStatus: assignedStatus ?? this.assignedStatus,
      assignedInspections: assignedInspections ?? this.assignedInspections,
      assignedError: assignedError,
    );
  }
}

class InspectionNotifier extends StateNotifier<InspectionState> {
  final InspectionService _service;

  InspectionNotifier(this._service) : super(const InspectionState());

  Future<void> loadMyInspections() async {
    state = state.copyWith(myStatus: LoadStatus.loading, myError: null);
    try {
      final list = await _service.getMyInspections();
      state = state.copyWith(myStatus: LoadStatus.loaded, myInspections: list);
    } catch (e) {
      state = state.copyWith(myStatus: LoadStatus.error, myError: e.toString());
    }
  }

  Future<void> loadAssignedInspections() async {
    state = state.copyWith(assignedStatus: LoadStatus.loading, assignedError: null);
    try {
      final list = await _service.getAssignedInspections();
      state = state.copyWith(assignedStatus: LoadStatus.loaded, assignedInspections: list);
    } catch (e) {
      state = state.copyWith(assignedStatus: LoadStatus.error, assignedError: e.toString());
    }
  }

  Future<bool> createRequest({required String orderId, required String inspectionType, String? notes}) async {
    try {
      await _service.createInspectionRequest(orderId: orderId, inspectionType: inspectionType, notes: notes);
      await loadMyInspections();
      return true;
    } catch (e) {
      state = state.copyWith(myError: e.toString());
      return false;
    }
  }

  Future<bool> scheduleInspection({required String id, required DateTime scheduledDate}) async {
    try {
      await _service.scheduleInspection(id: id, scheduledDate: scheduledDate);
      await loadAssignedInspections();
      return true;
    } catch (e) {
      state = state.copyWith(assignedError: e.toString());
      return false;
    }
  }

  Future<bool> completeInspection({
    required String id,
    required String result,
    String? grade,
    String? reportNotes,
  }) async {
    try {
      await _service.completeInspection(id: id, result: result, grade: grade, reportNotes: reportNotes);
      await loadAssignedInspections();
      return true;
    } catch (e) {
      state = state.copyWith(assignedError: e.toString());
      return false;
    }
  }

  Future<bool> cancelInspection(String id) async {
    try {
      await _service.cancelInspection(id);
      await loadMyInspections();
      return true;
    } catch (e) {
      state = state.copyWith(myError: e.toString());
      return false;
    }
  }
}

final inspectionProvider = StateNotifierProvider<InspectionNotifier, InspectionState>((ref) {
  return InspectionNotifier(ref.read(inspectionServiceProvider));
});
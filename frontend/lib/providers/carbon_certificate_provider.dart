import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/carbon_certificate_model.dart';
import '../services/carbon_certificate_service.dart';
import 'auth_provider.dart';
import 'marketplace_provider.dart' show LoadStatus;

export 'marketplace_provider.dart' show LoadStatus;

final carbonCertificateServiceProvider = Provider<CarbonCertificateService>((ref) {
  return CarbonCertificateService(ref.read(apiServiceProvider));
});

class CarbonCertificateState {
  final LoadStatus myCertificatesStatus;
  final List<CarbonCertificateModel> myCertificates;
  final String? myCertificatesError;

  final LoadStatus myRetirementsStatus;
  final List<CreditRetirementModel> myRetirements;
  final String? myRetirementsError;

  const CarbonCertificateState({
    this.myCertificatesStatus = LoadStatus.initial,
    this.myCertificates = const [],
    this.myCertificatesError,
    this.myRetirementsStatus = LoadStatus.initial,
    this.myRetirements = const [],
    this.myRetirementsError,
  });

  CarbonCertificateState copyWith({
    LoadStatus? myCertificatesStatus,
    List<CarbonCertificateModel>? myCertificates,
    String? myCertificatesError,
    LoadStatus? myRetirementsStatus,
    List<CreditRetirementModel>? myRetirements,
    String? myRetirementsError,
  }) {
    return CarbonCertificateState(
      myCertificatesStatus: myCertificatesStatus ?? this.myCertificatesStatus,
      myCertificates: myCertificates ?? this.myCertificates,
      myCertificatesError: myCertificatesError,
      myRetirementsStatus: myRetirementsStatus ?? this.myRetirementsStatus,
      myRetirements: myRetirements ?? this.myRetirements,
      myRetirementsError: myRetirementsError,
    );
  }
}

class CarbonCertificateNotifier extends StateNotifier<CarbonCertificateState> {
  final CarbonCertificateService _service;

  CarbonCertificateNotifier(this._service) : super(const CarbonCertificateState());

  Future<void> loadMyCertificates() async {
    state = state.copyWith(myCertificatesStatus: LoadStatus.loading, myCertificatesError: null);
    try {
      final certs = await _service.getMyCertificates();
      state = state.copyWith(myCertificatesStatus: LoadStatus.loaded, myCertificates: certs);
    } catch (e) {
      state = state.copyWith(myCertificatesStatus: LoadStatus.error, myCertificatesError: e.toString());
    }
  }

  Future<void> loadMyRetirements() async {
    state = state.copyWith(myRetirementsStatus: LoadStatus.loading, myRetirementsError: null);
    try {
      final retirements = await _service.getMyRetirements();
      state = state.copyWith(myRetirementsStatus: LoadStatus.loaded, myRetirements: retirements);
    } catch (e) {
      state = state.copyWith(myRetirementsStatus: LoadStatus.error, myRetirementsError: e.toString());
    }
  }

  Future<bool> createCertificate({
    required String registry,
    required String projectName,
    String? projectId,
    String? projectType,
    required int vintageYear,
    String? serialNumberRange,
    required double totalQuantity,
  }) async {
    try {
      await _service.createCertificate(
        registry: registry,
        projectName: projectName,
        projectId: projectId,
        projectType: projectType,
        vintageYear: vintageYear,
        serialNumberRange: serialNumberRange,
        totalQuantity: totalQuantity,
      );
      await loadMyCertificates();
      return true;
    } catch (e) {
      state = state.copyWith(myCertificatesError: e.toString());
      return false;
    }
  }

  Future<bool> retireCredits({
    required String certificateId,
    required double quantity,
    String? beneficiaryName,
    String? retirementReason,
  }) async {
    try {
      await _service.retireCredits(
        certificateId: certificateId,
        quantity: quantity,
        beneficiaryName: beneficiaryName,
        retirementReason: retirementReason,
      );
      await loadMyRetirements();
      await loadMyCertificates();
      return true;
    } catch (e) {
      state = state.copyWith(myRetirementsError: e.toString());
      return false;
    }
  }
}

final carbonCertificateProvider = StateNotifierProvider<CarbonCertificateNotifier, CarbonCertificateState>((ref) {
  return CarbonCertificateNotifier(ref.read(carbonCertificateServiceProvider));
});

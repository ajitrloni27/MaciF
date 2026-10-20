import 'package:flutter_riverpod/flutter_riverpod.dart';

class NetworkState {
  const NetworkState({
    this.mode = 'stable',
    this.latencyMs = 80,
    this.reliability = 98,
    this.deliveryImpact = 'Low risk',
    this.qualityLabel = 'Excellent',
    this.compareMode = true,
    this.activeStrategy = 'Balanced',
    this.bandwidthKbps = 512,
    this.chunkSize = 18,
    this.compressionLevel = 2,
    this.redundancy = 2,
    this.parityPackets = 2,
    this.profileLabel = 'Medium',
  });

  final String mode;
  final int latencyMs;
  final int reliability;
  final String deliveryImpact;
  final String qualityLabel;
  final bool compareMode;
  final String activeStrategy;
  final int bandwidthKbps;
  final int chunkSize;
  final int compressionLevel;
  final int redundancy;
  final int parityPackets;
  final String profileLabel;
}

class NetworkSimulatorController extends Notifier<NetworkState> {
  @override
  NetworkState build() => const NetworkState();

  void setReliability(double value) {
    final reliability = value.round();
    state = _fromValues(
      state.latencyMs,
      reliability,
      bandwidthKbps: state.bandwidthKbps,
    );
  }

  void setLatency(double value) {
    final latency = value.round();
    state = _fromValues(
      latency,
      state.reliability,
      bandwidthKbps: state.bandwidthKbps,
    );
  }

  void setBandwidth(double value) {
    final bandwidth = value.round();
    state = _fromValues(
      state.latencyMs,
      state.reliability,
      bandwidthKbps: bandwidth,
    );
  }

  void setRedundancy(double value) {
    state = NetworkState(
      mode: state.mode,
      latencyMs: state.latencyMs,
      reliability: state.reliability,
      deliveryImpact: state.deliveryImpact,
      qualityLabel: state.qualityLabel,
      compareMode: state.compareMode,
      activeStrategy: state.activeStrategy,
      bandwidthKbps: state.bandwidthKbps,
      chunkSize: state.chunkSize,
      compressionLevel: state.compressionLevel,
      redundancy: value.round().clamp(0, 6),
      parityPackets: value.round().clamp(0, 6),
      profileLabel: state.profileLabel,
    );
  }

  void setProfile(String profile) {
    late int bandwidthKbps;
    late int chunkSize;
    late int compressionLevel;
    late int redundancy;
    late int parityPackets;
    late String profileLabel;
    late String strategy;

    switch (profile) {
      case 'Ultra Low':
        bandwidthKbps = 32;
        chunkSize = 24;
        compressionLevel = 0;
        redundancy = 1;
        parityPackets = 1;
        profileLabel = 'Ultra Low';
        strategy = 'Ultra low-bandwidth';
        break;
      case 'Low':
        bandwidthKbps = 64;
        chunkSize = 20;
        compressionLevel = 1;
        redundancy = 1;
        parityPackets = 2;
        profileLabel = 'Low';
        strategy = 'Conservative';
        break;
      case 'High':
        bandwidthKbps = 512;
        chunkSize = 10;
        compressionLevel = 3;
        redundancy = 3;
        parityPackets = 3;
        profileLabel = 'High';
        strategy = 'High-throughput';
        break;
      case 'Medium':
      default:
        bandwidthKbps = 128;
        chunkSize = 18;
        compressionLevel = 2;
        redundancy = 2;
        parityPackets = 2;
        profileLabel = 'Medium';
        strategy = 'Balanced';
        break;
    }

    state = NetworkState(
      mode: state.mode,
      latencyMs: state.latencyMs,
      reliability: state.reliability,
      deliveryImpact: state.deliveryImpact,
      qualityLabel: state.qualityLabel,
      compareMode: state.compareMode,
      activeStrategy: strategy,
      bandwidthKbps: bandwidthKbps,
      chunkSize: chunkSize,
      compressionLevel: compressionLevel,
      redundancy: redundancy,
      parityPackets: parityPackets,
      profileLabel: profileLabel,
    );
  }

  void setCompareMode(bool value) {
    state = NetworkState(
      mode: state.mode,
      latencyMs: state.latencyMs,
      reliability: state.reliability,
      deliveryImpact: state.deliveryImpact,
      qualityLabel: state.qualityLabel,
      compareMode: value,
      activeStrategy: state.activeStrategy,
      bandwidthKbps: state.bandwidthKbps,
      chunkSize: state.chunkSize,
      compressionLevel: state.compressionLevel,
      redundancy: state.redundancy,
      parityPackets: state.parityPackets,
      profileLabel: state.profileLabel,
    );
  }

  void setMode(String mode) {
    if (mode == 'degraded') {
      state = NetworkState(
        mode: 'degraded',
        latencyMs: 320,
        reliability: 64,
        deliveryImpact: 'High risk',
        qualityLabel: 'Poor',
        compareMode: state.compareMode,
        activeStrategy: state.activeStrategy,
        bandwidthKbps: state.bandwidthKbps,
        chunkSize: state.chunkSize,
        compressionLevel: state.compressionLevel,
        redundancy: state.redundancy,
        parityPackets: state.parityPackets,
        profileLabel: state.profileLabel,
      );
    } else {
      state = NetworkState(
        mode: 'stable',
        latencyMs: 80,
        reliability: 98,
        deliveryImpact: 'Low risk',
        qualityLabel: 'Excellent',
        compareMode: state.compareMode,
        activeStrategy: state.activeStrategy,
        bandwidthKbps: state.bandwidthKbps,
        chunkSize: state.chunkSize,
        compressionLevel: state.compressionLevel,
        redundancy: state.redundancy,
        parityPackets: state.parityPackets,
        profileLabel: state.profileLabel,
      );
    }
  }

  NetworkState _fromValues(
    int latencyMs,
    int reliability, {
    required int bandwidthKbps,
  }) {
    final mode = reliability < 78 || latencyMs > 250 ? 'degraded' : 'stable';
    final risk = reliability < 65 || latencyMs > 420
        ? 'Critical risk'
        : mode == 'degraded'
        ? 'High risk'
        : 'Low risk';
    final quality = reliability < 65
        ? 'Failing'
        : reliability < 85
        ? 'Poor'
        : 'Excellent';
    return NetworkState(
      mode: mode,
      latencyMs: latencyMs,
      reliability: reliability,
      deliveryImpact: risk,
      qualityLabel: quality,
      compareMode: state.compareMode,
      activeStrategy: state.activeStrategy,
      bandwidthKbps: bandwidthKbps,
      chunkSize: state.chunkSize,
      compressionLevel: state.compressionLevel,
      redundancy: state.redundancy,
      parityPackets: state.parityPackets,
      profileLabel: state.profileLabel,
    );
  }
}

final networkSimulatorProvider =
    NotifierProvider<NetworkSimulatorController, NetworkState>(
      NetworkSimulatorController.new,
    );

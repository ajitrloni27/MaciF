import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/clinical_colors.dart';

class ClinicalAlertEvent {
  const ClinicalAlertEvent({
    required this.id,
    required this.severity,
    required this.title,
    this.body,
    this.timestamp,
    this.acknowledged = false,
  });

  final String id;
  final ClinicalSeverity severity;
  final String title;
  final String? body;
  final DateTime? timestamp;
  final bool acknowledged;

  ClinicalAlertEvent copyWith({
    String? id,
    ClinicalSeverity? severity,
    String? title,
    String? body,
    DateTime? timestamp,
    bool? acknowledged,
  }) {
    return ClinicalAlertEvent(
      id: id ?? this.id,
      severity: severity ?? this.severity,
      title: title ?? this.title,
      body: body ?? this.body,
      timestamp: timestamp ?? this.timestamp,
      acknowledged: acknowledged ?? this.acknowledged,
    );
  }
}

class AlertState {
  const AlertState({
    this.alerts = const <ClinicalAlertEvent>[],
  });

  final List<ClinicalAlertEvent> alerts;

  AlertState copyWith({
    List<ClinicalAlertEvent>? alerts,
  }) {
    return AlertState(
      alerts: alerts ?? this.alerts,
    );
  }
}

class AlertController extends Notifier<AlertState> {
  @override
  AlertState build() => const AlertState();

  void push({
    required String id,
    required ClinicalSeverity severity,
    required String title,
    String? body,
  }) {
    // Avoid duplicates of active alerts with the same ID
    if (state.alerts.any((a) => a.id == id)) {
      return;
    }
    state = state.copyWith(
      alerts: [
        ...state.alerts,
        ClinicalAlertEvent(
          id: id,
          severity: severity,
          title: title,
          body: body,
          timestamp: DateTime.now(),
        ),
      ],
    );
  }

  void dismiss(String id) {
    state = state.copyWith(
      alerts: state.alerts.where((a) => a.id != id).toList(),
    );
  }

  void acknowledge(String id) {
    state = state.copyWith(
      alerts: state.alerts.map((a) => a.id == id ? a.copyWith(acknowledged: true) : a).toList(),
    );
  }

  void clearAll() {
    state = const AlertState();
  }
}

final alertProvider = NotifierProvider<AlertController, AlertState>(
  AlertController.new,
);

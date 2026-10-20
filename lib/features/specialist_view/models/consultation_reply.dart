class ConsultationReply {
  const ConsultationReply({
    required this.caseId,
    required this.doctorName,
    required this.advice,
    required this.prescriptionNote,
    required this.followUp,
    required this.timestamp,
    this.id,
  });

  final String? id;
  final String caseId;
  final String doctorName;
  final String advice;
  final String prescriptionNote;
  final bool followUp;
  final DateTime timestamp;

  String get replyId => id ?? '${caseId}_${timestamp.millisecondsSinceEpoch}';

  Map<String, String> toWireMap() => {
        'id': replyId,
        'caseId': caseId,
        'doctorName': doctorName,
        'advice': advice,
        'prescriptionNote': prescriptionNote,
        'followUp': followUp ? '1' : '0',
        'timestamp': '${timestamp.millisecondsSinceEpoch}',
      };

  factory ConsultationReply.fromWireMap(Map<String, String> map) => ConsultationReply(
        id: map['id'],
        caseId: map['caseId'] ?? '',
        doctorName: map['doctorName'] ?? '',
        advice: map['advice'] ?? '',
        prescriptionNote: map['prescriptionNote'] ?? '',
        followUp: map['followUp'] == '1' || map['followUp']?.toLowerCase() == 'true',
        timestamp: DateTime.fromMillisecondsSinceEpoch(
          int.tryParse(map['timestamp'] ?? '') ?? 0,
        ),
      );

  String toPayload() {
    final cleanDoc = doctorName.replaceAll('|', '/');
    final cleanAdv = advice.replaceAll('|', '/');
    final cleanRx = prescriptionNote.replaceAll('|', '/');
    return 'CRP1|$replyId|$caseId|$cleanDoc|$cleanAdv|$cleanRx|${followUp ? '1' : '0'}|${timestamp.millisecondsSinceEpoch}';
  }

  factory ConsultationReply.fromPayload(String payload) {
    if (payload.startsWith('CRP1|')) {
      final parts = payload.split('|');
      return ConsultationReply(
        id: parts.length > 1 ? parts[1] : null,
        caseId: parts.length > 2 ? parts[2] : '',
        doctorName: parts.length > 3 ? parts[3] : '',
        advice: parts.length > 4 ? parts[4] : '',
        prescriptionNote: parts.length > 5 ? parts[5] : '',
        followUp: parts.length > 6 && (parts[6] == '1' || parts[6].toLowerCase() == 'true'),
        timestamp: DateTime.fromMillisecondsSinceEpoch(
          parts.length > 7 ? int.tryParse(parts[7]) ?? 0 : 0,
        ),
      );
    }
    return ConsultationReply(
      caseId: '',
      doctorName: 'Specialist',
      advice: payload,
      prescriptionNote: '',
      followUp: false,
      timestamp: DateTime.now(),
    );
  }
}

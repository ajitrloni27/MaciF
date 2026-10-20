enum TransmissionPriority {
  emergency(-1),
  urgent(0),
  routine(1),
  media(2);

  const TransmissionPriority(this.rank);

  final int rank;
}

class QueuedPayload {
  const QueuedPayload({
    required this.label,
    required this.payload,
    required this.priority,
  });

  final String label;
  final String payload;
  final TransmissionPriority priority;
}

List<QueuedPayload> prioritizePayloads(Iterable<QueuedPayload> items) {
  final sorted = items.toList()
    ..sort((a, b) => a.priority.rank.compareTo(b.priority.rank));
  return sorted;
}

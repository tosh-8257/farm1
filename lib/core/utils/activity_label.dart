/// Readable Recent Activity labels for system transactions (travel holds,
/// refunds) that have no counterparty. Returns null for normal peer transfers.
class ActivityLabel {
  const ActivityLabel(this.title, this.type);
  final String title;
  final String type;
}

ActivityLabel? systemActivityLabel(Map<dynamic, dynamic> tx) {
  final meta = tx['metadata'];
  if (meta is! Map) return null;
  final kind = '${meta['kind'] ?? ''}';
  final label = '${meta['label'] ?? ''}'.trim();
  switch (kind) {
    case 'travel_hotel':
      return ActivityLabel(label.isNotEmpty ? label : 'Hotel booking', 'Hotel booking');
    case 'travel_flight':
      return ActivityLabel(label.isNotEmpty ? label : 'Flight booking', 'Flight booking');
    case 'travel_refund':
      return ActivityLabel(label.isNotEmpty ? label : 'Travel refund', 'Refund');
    default:
      return null;
  }
}

/// A single RFID read, regardless of which physical scanner produced it
/// (Janam XR2 or AutoID uTouch2). The native Android side normalizes both
/// scanners' broadcasts into this same shape before it crosses the
/// EventChannel.
class RfidReadEvent {
  final String source; // "XR2" or "UTOUCH2"
  final String? epc;
  final String? data;
  final DateTime receivedAt;

  RfidReadEvent({
    required this.source,
    required this.epc,
    required this.data,
    required this.receivedAt,
  });

  /// The value that should actually be used as the tag identifier for
  /// scanning purposes. XR2 sends separate EPC/DATA; uTouch2 sends only
  /// one field (mirrored into both epc and data natively), so this just
  /// prefers epc and falls back to data.
  String get tagValue => (epc != null && epc!.isNotEmpty) ? epc! : (data ?? '');

  factory RfidReadEvent.fromMap(Map<dynamic, dynamic> map) {
    final millis = map['receivedAt'] as int?;
    return RfidReadEvent(
      source: (map['source'] as String?) ?? 'UNKNOWN',
      epc: map['epc'] as String?,
      data: map['data'] as String?,
      receivedAt: millis != null
          ? DateTime.fromMillisecondsSinceEpoch(millis)
          : DateTime.now(),
    );
  }

  @override
  String toString() =>
      '[$source] tag=$tagValue epc=$epc data=$data at=$receivedAt';
}

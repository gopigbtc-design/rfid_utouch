import 'dart:async';
import 'package:flutter/services.dart';
import '../models/rfid_read_event.dart';
import 'app_logger.dart';

/// Listens to the native Android EventChannel that both the Janam XR2
/// receiver and the AutoID uTouch2 receiver push into (see
/// MainActivity.kt). A single broadcast stream here serves the whole
/// app regardless of which physical scanner is attached.
class RfidReceiver {
  RfidReceiver._();
  static final RfidReceiver instance = RfidReceiver._();

  static const EventChannel _channel =
      EventChannel('com.isens.rfidscanner/rfid_events');

  Stream<RfidReadEvent>? _stream;

  Stream<RfidReadEvent> get stream {
    _stream ??= _channel.receiveBroadcastStream().map((event) {
      final map = event as Map<dynamic, dynamic>;
      final read = RfidReadEvent.fromMap(map);
      AppLogger.instance.log('RFID read: $read');
      return read;
    }).handleError((Object error) {
      AppLogger.instance.log('RFID stream error: $error');
    });
    return _stream!;
  }
}

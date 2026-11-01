import 'package:flutter/services.dart';

/// Wraps the native MethodChannel exposed by MainActivity.kt, giving
/// Dart access to device/receiver info and the self-test broadcasts
/// for both the XR2 and uTouch2 pipelines.
class DiagnosticsService {
  static const MethodChannel _channel =
      MethodChannel('com.isens.rfidscanner/diagnostics');

  /// Returns a map with (at minimum, depending on native app version):
  /// nativeCodeVersion, packageName, androidSdkInt, androidRelease,
  /// xr2ReceiverRegistered, xr2ScanAction, xr2ExtraEpcKey, xr2ExtraDataKey,
  /// xr2ReadCount, utouch2ReceiverRegistered, utouch2ScanAction,
  /// utouch2ExtraDataKey, utouch2ReadCount, lastSource, pendingBufferSize.
  Future<Map<String, dynamic>> getInfo() async {
    try {
      final result = await _channel.invokeMethod('getInfo');
      if (result is Map) {
        return result.map((key, value) => MapEntry(key.toString(), value));
      }
      return {'error': 'Unexpected response type: ${result.runtimeType}'};
    } on PlatformException catch (e) {
      return {'error': 'PlatformException: ${e.message}'};
    } on MissingPluginException catch (e) {
      return {
        'error':
            'MissingPluginException: the native code is not wired up for this build ($e)'
      };
    }
  }

  /// Fires a self-targeted test broadcast through the native receiver
  /// pipeline, without needing the physical scanner to trigger it.
  /// [target] is "xr2" (default) or "utouch2".
  Future<bool> sendTestBroadcast({String target = 'xr2'}) async {
    try {
      final result = await _channel
          .invokeMethod('sendTestBroadcast', {'target': target});
      return result == true;
    } catch (e) {
      return false;
    }
  }
}

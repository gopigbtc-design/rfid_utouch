package com.isens.rfidscanner

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Build
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.util.ArrayDeque

class MainActivity : FlutterActivity() {

    companion object {
        // Bump this string every time MainActivity.kt changes. Check it in
        // the Diagnostics screen after a rebuild+reinstall to confirm the
        // device is actually running the new code, not a stale APK.
        private const val NATIVE_CODE_VERSION = "2026-11-01.1-utouch2"

        private const val EVENT_CHANNEL = "com.isens.rfidscanner/rfid_events"
        private const val METHOD_CHANNEL = "com.isens.rfidscanner/diagnostics"

        // ---- Janam XR2 (DataWedge-style) broadcast scheme ----
        private const val XR2_SCAN_ACTION = "com.ubx.scan.rfid"
        private const val XR2_EXTRA_EPC = "rfid_epc"
        private const val XR2_EXTRA_DATA = "rfid_data"

        // ---- AutoID uTouch2 broadcast scheme ----
        private const val UTOUCH2_SCAN_ACTION = "com.android.server.scannerservice.broadcast"
        private const val UTOUCH2_EXTRA_DATA = "scannerdata"

        private const val MAX_BUFFER = 100
    }

    private var eventSink: EventChannel.EventSink? = null

    // Buffer scans that arrive before Flutter has attached its EventChannel listener.
    private val pendingBuffer = ArrayDeque<Map<String, Any?>>()

    // Diagnostics counters, exposed via the MethodChannel so the in-app
    // Diagnostics screen can show whether each receiver is alive and how
    // many reads it has seen since app start.
    private var xr2ReceiverRegistered = false
    private var utouch2ReceiverRegistered = false
    private var xr2ReadCount = 0
    private var utouch2ReadCount = 0
    private var lastSource: String? = null

    private val xr2Receiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            if (intent == null) return
            val epc = intent.getStringExtra(XR2_EXTRA_EPC)
            val data = intent.getStringExtra(XR2_EXTRA_DATA)
            xr2ReadCount++
            lastSource = "XR2"
            emitRead(
                source = "XR2",
                epc = epc,
                data = data ?: epc
            )
        }
    }

    private val utouch2Receiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            if (intent == null) return
            // uTouch2 has a single data field; it carries the tag value
            // directly (no separate EPC/DATA split like the XR2).
            val scannerData = intent.getStringExtra(UTOUCH2_EXTRA_DATA)
            utouch2ReadCount++
            lastSource = "UTOUCH2"
            emitRead(
                source = "UTOUCH2",
                epc = scannerData,
                data = scannerData
            )
        }
    }

    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        super.onCreate(savedInstanceState)
        registerReceivers()
    }

    private fun registerReceivers() {
        try {
            val xr2Filter = IntentFilter(XR2_SCAN_ACTION)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                registerReceiver(xr2Receiver, xr2Filter, Context.RECEIVER_EXPORTED)
            } else {
                registerReceiver(xr2Receiver, xr2Filter)
            }
            xr2ReceiverRegistered = true
        } catch (e: Exception) {
            xr2ReceiverRegistered = false
        }

        try {
            val utouch2Filter = IntentFilter(UTOUCH2_SCAN_ACTION)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                registerReceiver(utouch2Receiver, utouch2Filter, Context.RECEIVER_EXPORTED)
            } else {
                registerReceiver(utouch2Receiver, utouch2Filter)
            }
            utouch2ReceiverRegistered = true
        } catch (e: Exception) {
            utouch2ReceiverRegistered = false
        }
    }

    override fun onDestroy() {
        try { unregisterReceiver(xr2Receiver) } catch (e: Exception) { }
        try { unregisterReceiver(utouch2Receiver) } catch (e: Exception) { }
        super.onDestroy()
    }

    /**
     * Pushes a scan read into the EventChannel if Flutter is listening,
     * otherwise buffers it so no read is lost while the Dart side is
     * still attaching its listener (e.g. right after app launch).
     */
    private fun emitRead(source: String, epc: String?, data: String?) {
        val payload = mapOf(
            "source" to source,
            "epc" to epc,
            "data" to data,
            "receivedAt" to System.currentTimeMillis()
        )
        val sink = eventSink
        if (sink != null) {
            sink.success(payload)
        } else {
            if (pendingBuffer.size >= MAX_BUFFER) {
                pendingBuffer.poll()
            }
            pendingBuffer.offer(payload)
        }
    }

    private fun flushBuffer() {
        val sink = eventSink ?: return
        while (pendingBuffer.isNotEmpty()) {
            val item = pendingBuffer.poll()
            if (item != null) {
                sink.success(item)
            }
        }
    }

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, sink: EventChannel.EventSink?) {
                    eventSink = sink
                    flushBuffer()
                }

                override fun onCancel(arguments: Any?) {
                    eventSink = null
                }
            })

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, METHOD_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getInfo" -> {
                        result.success(
                            mapOf(
                                "nativeCodeVersion" to NATIVE_CODE_VERSION,
                                "packageName" to packageName,
                                "androidSdkInt" to Build.VERSION.SDK_INT,
                                "androidRelease" to Build.VERSION.RELEASE,
                                "xr2ReceiverRegistered" to xr2ReceiverRegistered,
                                "xr2ScanAction" to XR2_SCAN_ACTION,
                                "xr2ExtraEpcKey" to XR2_EXTRA_EPC,
                                "xr2ExtraDataKey" to XR2_EXTRA_DATA,
                                "xr2ReadCount" to xr2ReadCount,
                                "utouch2ReceiverRegistered" to utouch2ReceiverRegistered,
                                "utouch2ScanAction" to UTOUCH2_SCAN_ACTION,
                                "utouch2ExtraDataKey" to UTOUCH2_EXTRA_DATA,
                                "utouch2ReadCount" to utouch2ReadCount,
                                "lastSource" to lastSource,
                                "pendingBufferSize" to pendingBuffer.size
                            )
                        )
                    }
                    "sendTestBroadcast" -> {
                        // Fires a self-targeted test broadcast through the
                        // XR2 pipeline for in-app self-diagnosis. Pass
                        // {"target": "utouch2"} as the call argument to
                        // test the uTouch2 pipeline instead.
                        val args = call.arguments as? Map<*, *>
                        val target = (args?.get("target") as? String) ?: "xr2"
                        val testIntent = if (target == "utouch2") {
                            Intent(UTOUCH2_SCAN_ACTION).apply {
                                putExtra(UTOUCH2_EXTRA_DATA, "TEST-UTOUCH2-${System.currentTimeMillis()}")
                                setPackage(packageName)
                            }
                        } else {
                            Intent(XR2_SCAN_ACTION).apply {
                                putExtra(XR2_EXTRA_EPC, "TEST-XR2-${System.currentTimeMillis()}")
                                putExtra(XR2_EXTRA_DATA, "TEST-XR2-${System.currentTimeMillis()}")
                                setPackage(packageName)
                            }
                        }
                        sendBroadcast(testIntent)
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
    }
}

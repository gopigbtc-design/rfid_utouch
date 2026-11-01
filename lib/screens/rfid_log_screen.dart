import 'dart:async';
import 'package:flutter/material.dart';
import '../models/rfid_read_event.dart';
import '../services/rfid_receiver.dart';
import '../services/diagnostics_service.dart';
import '../services/app_logger.dart';
import '../theme/isens_theme.dart';
import '../utils/date_format.dart';

/// 3-tab troubleshooting screen: Diagnostics (device/native info +
/// self-test), Raw RFID Scans (live feed from both scanners), App Log
/// (in-memory app-wide log).
class RfidLogScreen extends StatefulWidget {
  const RfidLogScreen({super.key});

  @override
  State<RfidLogScreen> createState() => _RfidLogScreenState();
}

class _RfidLogScreenState extends State<RfidLogScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _diagnostics = DiagnosticsService();
  Map<String, dynamic> _info = {};
  bool _loadingInfo = true;
  bool _testingXr2 = false;
  bool _testingUtouch2 = false;

  final List<RfidReadEvent> _rawScans = [];
  StreamSubscription<RfidReadEvent>? _scanSub;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _refreshInfo();
    _scanSub = RfidReceiver.instance.stream.listen((event) {
      setState(() {
        _rawScans.insert(0, event);
        if (_rawScans.length > 200) _rawScans.removeLast();
      });
    });
    AppLogger.instance.addListener(_onAppLogChanged);
  }

  void _onAppLogChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _tabController.dispose();
    _scanSub?.cancel();
    AppLogger.instance.removeListener(_onAppLogChanged);
    super.dispose();
  }

  Future<void> _refreshInfo() async {
    setState(() => _loadingInfo = true);
    final info = await _diagnostics.getInfo();
    setState(() {
      _info = info;
      _loadingInfo = false;
    });
  }

  Future<void> _runSelfTest(String target) async {
    setState(() {
      if (target == 'utouch2') {
        _testingUtouch2 = true;
      } else {
        _testingXr2 = true;
      }
    });
    final ok = await _diagnostics.sendTestBroadcast(target: target);
    AppLogger.instance.log(
        'Self-test ($target) broadcast sent: ${ok ? "ok" : "failed to send"}');
    if (!mounted) return;
    setState(() {
      _testingXr2 = false;
      _testingUtouch2 = false;
    });
    await Future.delayed(const Duration(milliseconds: 400));
    await _refreshInfo();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Diagnostics'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: 'Diagnostics'),
            Tab(text: 'Raw RFID Scans'),
            Tab(text: 'App Log'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildDiagnosticsTab(),
          _buildRawScansTab(),
          _buildAppLogTab(),
        ],
      ),
    );
  }

  Widget _buildDiagnosticsTab() {
    if (_loadingInfo) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_info['error'] != null) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Error reading native diagnostics:',
                style: TextStyle(
                    color: IsensColors.danger, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(_info['error'].toString()),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _refreshInfo, child: const Text('Retry')),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Device & App Info',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                _infoRow('Native code version',
                    _info['nativeCodeVersion']?.toString() ?? 'unknown (old build)'),
                _infoRow('Package name', _info['packageName']?.toString()),
                _infoRow('Android version',
                    '${_info['androidRelease'] ?? '?'} (SDK ${_info['androidSdkInt'] ?? '?'})'),
                _infoRow('Last scan source', _info['lastSource']?.toString() ?? '-'),
                _infoRow('Buffered (unread) scans',
                    _info['pendingBufferSize']?.toString()),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: _refreshInfo,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Refresh'),
                ),
              ],
            ),
          ),
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Janam XR2',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                _statusRow('Receiver registered',
                    _info['xr2ReceiverRegistered'] == true),
                _infoRow('Intent action', _info['xr2ScanAction']?.toString()),
                _infoRow('Extra (EPC)', _info['xr2ExtraEpcKey']?.toString()),
                _infoRow('Extra (DATA)', _info['xr2ExtraDataKey']?.toString()),
                _infoRow('Reads received', _info['xr2ReadCount']?.toString()),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _testingXr2 ? null : () => _runSelfTest('xr2'),
                  icon: _testingXr2
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.bolt),
                  label: const Text('Run XR2 self-test'),
                ),
              ],
            ),
          ),
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('AutoID uTouch2',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                _statusRow('Receiver registered',
                    _info['utouch2ReceiverRegistered'] == true),
                _infoRow(
                    'Intent action', _info['utouch2ScanAction']?.toString()),
                _infoRow(
                    'Extra (DATA)', _info['utouch2ExtraDataKey']?.toString()),
                _infoRow(
                    'Reads received', _info['utouch2ReadCount']?.toString()),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed:
                      _testingUtouch2 ? null : () => _runSelfTest('utouch2'),
                  icon: _testingUtouch2
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.bolt),
                  label: const Text('Run uTouch2 self-test'),
                ),
              ],
            ),
          ),
        ),
        const Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'Self-Test sends a fake scan through the same native receiver '
            'and channel a real trigger-pull would use, without needing '
            'the scan engine at all. If it appears in the "Raw RFID '
            'Scans" tab, this app\'s receiver, EventChannel and UI are '
            'all working correctly - so a real trigger-pull not showing '
            'up points to the scanner app\'s broadcast settings not '
            'matching this app\'s expected action/extra key, not a bug '
            'in this app.',
            style: TextStyle(color: Colors.black54, fontSize: 13),
          ),
        ),
      ],
    );
  }

  Widget _infoRow(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 160,
            child: Text(label, style: const TextStyle(color: Colors.black54)),
          ),
          Expanded(
            child: Text(value ?? '-',
                style: const TextStyle(
                    fontFamily: 'monospace', fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }

  Widget _statusRow(String label, bool ok) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 160,
            child: Text(label, style: const TextStyle(color: Colors.black54)),
          ),
          Icon(ok ? Icons.check_circle : Icons.cancel,
              color: ok ? IsensColors.success : IsensColors.danger, size: 18),
          const SizedBox(width: 6),
          Text(ok ? 'Yes' : 'No'),
        ],
      ),
    );
  }

  Widget _buildRawScansTab() {
    if (_rawScans.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'No scans received yet. Pull the trigger on the scanner, '
            'or run a self-test from the Diagnostics tab.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.black54),
          ),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(8),
      itemCount: _rawScans.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, i) {
        final e = _rawScans[i];
        return ListTile(
          dense: true,
          leading: Chip(
            label: Text(e.source,
                style: const TextStyle(fontSize: 11, color: Colors.white)),
            backgroundColor:
                e.source == 'UTOUCH2' ? IsensColors.cyan : IsensColors.blue,
            padding: EdgeInsets.zero,
            visualDensity: VisualDensity.compact,
          ),
          title: Text(e.tagValue, style: const TextStyle(fontFamily: 'monospace')),
          subtitle: Text('epc=${e.epc ?? "-"}  data=${e.data ?? "-"}'),
          trailing: Text(fmtTime12Ms(e.receivedAt),
              style: const TextStyle(fontSize: 12)),
        );
      },
    );
  }

  Widget _buildAppLogTab() {
    final entries = AppLogger.instance.entries;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            children: [
              const Spacer(),
              TextButton.icon(
                onPressed: () => AppLogger.instance.clear(),
                icon: const Icon(Icons.delete_outline),
                label: const Text('Clear'),
              ),
            ],
          ),
        ),
        Expanded(
          child: entries.isEmpty
              ? const Center(child: Text('No log entries yet'))
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: entries.length,
                  itemBuilder: (context, i) {
                    final e = entries[i];
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: RichText(
                        text: TextSpan(
                          style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 12,
                              color: Colors.black87),
                          children: [
                            TextSpan(
                              text: '${fmtTime12(e.time)}  ',
                              style: const TextStyle(color: Colors.black45),
                            ),
                            TextSpan(text: e.message),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

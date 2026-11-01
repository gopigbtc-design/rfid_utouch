import 'dart:async';
import 'package:flutter/material.dart';
import '../models/rfid_read_event.dart';
import '../services/rfid_receiver.dart';
import '../services/api_service.dart';
import '../services/app_logger.dart';
import '../services/settings_service.dart';
import '../theme/isens_theme.dart';
import '../utils/date_format.dart';
import 'ppc_fill_screen.dart';
import 'rfid_log_screen.dart';
import 'settings_screen.dart';
import 'login_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _api = ApiService();
  final _settings = SettingsService();
  StreamSubscription<RfidReadEvent>? _sub;
  RfidReadEvent? _lastEvent;
  List<dynamic> _processes = [];
  dynamic _selectedProcess;
  bool _loadingProcesses = true;
  String? _scanStatus;

  @override
  void initState() {
    super.initState();
    _loadProcesses();
    _sub = RfidReceiver.instance.stream.listen(_onScan);
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _loadProcesses() async {
    setState(() => _loadingProcesses = true);
    try {
      final list = await _api.getProcesses();
      setState(() {
        _processes = list;
        _loadingProcesses = false;
      });
    } catch (e) {
      AppLogger.instance.log('Failed to load processes: $e');
      setState(() => _loadingProcesses = false);
    }
  }

  Future<void> _onScan(RfidReadEvent event) async {
    setState(() {
      _lastEvent = event;
      _scanStatus = null;
    });
    if (_selectedProcess == null) {
      setState(() => _scanStatus = 'Select a process before scanning.');
      return;
    }
    try {
      final result = await _api.submitScan(
        processCode: _selectedProcess['code'].toString(),
        tagValue: event.tagValue,
      );
      setState(() => _scanStatus =
          result['message']?.toString() ?? 'Scan recorded');
    } catch (e) {
      setState(() => _scanStatus = 'Scan failed: $e');
    }
  }

  Future<void> _logout() async {
    await _settings.clearSession();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ISENS RFID'),
        actions: [
          IconButton(
            icon: const Icon(Icons.bug_report_outlined),
            tooltip: 'Diagnostics',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const RfidLogScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: _logout,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadProcesses,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.nfc, color: IsensColors.blue),
                        const SizedBox(width: 10),
                        Text(
                          _lastEvent != null
                              ? 'Last scan: ${_lastEvent!.tagValue}'
                              : 'Waiting for a scan...',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    if (_lastEvent != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        'via ${_lastEvent!.source}  ·  ${fmtTime12(_lastEvent!.receivedAt)}',
                        style:
                            const TextStyle(color: Colors.black54, fontSize: 13),
                      ),
                    ],
                    if (_scanStatus != null) ...[
                      const SizedBox(height: 10),
                      Text(_scanStatus!,
                          style: TextStyle(
                            color: _scanStatus!.startsWith('Scan failed')
                                ? IsensColors.danger
                                : IsensColors.success,
                            fontWeight: FontWeight.w600,
                          )),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const PpcFillScreen()),
              ),
              icon: const Icon(Icons.add_box_outlined),
              label: const Text('PPC Fill - New Job Card'),
            ),
            const SizedBox(height: 20),
            const Text('Select process for scanning',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 8),
            if (_loadingProcesses)
              const Center(child: CircularProgressIndicator())
            else if (_processes.isEmpty)
              const Text('No processes loaded. Pull down to retry, or check Settings.',
                  style: TextStyle(color: Colors.black54))
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _processes.map((p) {
                  final selected = _selectedProcess != null &&
                      _selectedProcess['id'] == p['id'];
                  return ChoiceChip(
                    label: Text(p['name']?.toString() ?? p['code'].toString()),
                    selected: selected,
                    selectedColor: IsensColors.blue,
                    labelStyle: TextStyle(
                        color: selected ? Colors.white : Colors.black87),
                    onSelected: (_) => setState(() => _selectedProcess = p),
                  );
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../services/settings_service.dart';
import '../services/api_service.dart';
import '../services/app_logger.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _settings = SettingsService();
  final _api = ApiService();
  final _hostCtrl = TextEditingController();
  final _portCtrl = TextEditingController();
  bool _loading = true;
  bool _testing = false;
  String? _testResult;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    _hostCtrl.text = await _settings.getServerHost();
    _portCtrl.text = (await _settings.getServerPort()).toString();
    setState(() => _loading = false);
  }

  Future<void> _save() async {
    await _settings.setServerHost(_hostCtrl.text.trim());
    final port = int.tryParse(_portCtrl.text.trim()) ?? 8000;
    await _settings.setServerPort(port);
    AppLogger.instance.log(
        'Server settings saved: ${_hostCtrl.text.trim()}:$port');
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Settings saved')));
  }

  Future<void> _testConnection() async {
    setState(() {
      _testing = true;
      _testResult = null;
    });
    await _save();
    final ok = await _api.ping();
    setState(() {
      _testing = false;
      _testResult = ok ? 'Connected successfully' : 'Could not reach server';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Server Settings')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                TextField(
                  controller: _hostCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Server IP address',
                    hintText: 'e.g. 192.168.1.50',
                  ),
                  keyboardType: TextInputType.text,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _portCtrl,
                  decoration: const InputDecoration(labelText: 'Port'),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _testing ? null : _testConnection,
                        child: _testing
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2))
                            : const Text('Test Connection'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _save,
                        child: const Text('Save'),
                      ),
                    ),
                  ],
                ),
                if (_testResult != null) ...[
                  const SizedBox(height: 16),
                  Text(_testResult!,
                      style: TextStyle(
                        color: _testResult == 'Connected successfully'
                            ? Colors.green
                            : Colors.red,
                        fontWeight: FontWeight.w600,
                      )),
                ],
              ],
            ),
    );
  }
}

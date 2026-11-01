import 'dart:async';
import 'package:flutter/material.dart';
import '../models/rfid_read_event.dart';
import '../services/rfid_receiver.dart';
import '../services/api_service.dart';
import '../services/app_logger.dart';
import '../theme/isens_theme.dart';

/// PPC Fill: create a new Job Card for an InSquare. Scan or search for
/// the InSquare, then confirm to create the job card on the backend.
class PpcFillScreen extends StatefulWidget {
  const PpcFillScreen({super.key});

  @override
  State<PpcFillScreen> createState() => _PpcFillScreenState();
}

class _PpcFillScreenState extends State<PpcFillScreen> {
  final _api = ApiService();
  final _searchCtrl = TextEditingController();
  StreamSubscription<RfidReadEvent>? _sub;
  String? _scannedTag;
  List<dynamic> _matches = [];
  bool _searching = false;
  bool _submitting = false;
  String? _status;

  @override
  void initState() {
    super.initState();
    _sub = RfidReceiver.instance.stream.listen((event) {
      setState(() {
        _scannedTag = event.tagValue;
        _searchCtrl.text = event.tagValue;
      });
      _search(event.tagValue);
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _search(String query) async {
    if (query.trim().isEmpty) {
      setState(() => _matches = []);
      return;
    }
    setState(() => _searching = true);
    try {
      final results = await _api.searchInsquares(query.trim());
      setState(() => _matches = results);
    } catch (e) {
      AppLogger.instance.log('InSquare search failed: $e');
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _createJobCard(dynamic insquare) async {
    setState(() {
      _submitting = true;
      _status = null;
    });
    try {
      final id = insquare['id'] as int;
      await _api.createJobCard(insquareId: id);
      setState(() {
        _status = 'Job card created for ${insquare['code'] ?? id}';
        _matches = [];
        _scannedTag = null;
        _searchCtrl.clear();
      });
      AppLogger.instance.log('Job card created for insquare id=$id');
    } catch (e) {
      setState(() => _status = 'Failed: $e');
      AppLogger.instance.log('Job card creation failed: $e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('PPC Fill - New Job Card')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              color: IsensColors.navy.withOpacity(0.06),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Icon(Icons.nfc, color: IsensColors.navy),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _scannedTag != null
                            ? 'Last scan: $_scannedTag'
                            : 'Scan an InSquare tag, or search below',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _searchCtrl,
              decoration: const InputDecoration(
                labelText: 'Search InSquare (code or tag)',
                suffixIcon: Icon(Icons.search),
              ),
              onChanged: _search,
            ),
            const SizedBox(height: 12),
            if (_searching) const LinearProgressIndicator(),
            if (_status != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(_status!,
                    style: TextStyle(
                      color: _status!.startsWith('Failed')
                          ? IsensColors.danger
                          : IsensColors.success,
                      fontWeight: FontWeight.w600,
                    )),
              ),
            Expanded(
              child: ListView.builder(
                itemCount: _matches.length,
                itemBuilder: (context, i) {
                  final m = _matches[i];
                  return Card(
                    child: ListTile(
                      leading: const Icon(Icons.inventory_2_outlined),
                      title: Text(m['code']?.toString() ?? 'InSquare #${m['id']}'),
                      subtitle: Text('Status: ${m['status'] ?? 'unknown'}'),
                      trailing: _submitting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : ElevatedButton(
                              onPressed: () => _createJobCard(m),
                              child: const Text('Create'),
                            ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

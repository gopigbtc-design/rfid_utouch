import 'package:flutter/material.dart';
import 'theme/isens_theme.dart';
import 'services/settings_service.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';

void main() {
  runApp(const IsensApp());
}

class IsensApp extends StatelessWidget {
  const IsensApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ISENS RFID',
      debugShowCheckedModeBanner: false,
      theme: buildIsensTheme(),
      home: const _StartupGate(),
    );
  }
}

/// Decides whether to show Login or go straight to Home, based on
/// whether a saved auth token exists.
class _StartupGate extends StatefulWidget {
  const _StartupGate();

  @override
  State<_StartupGate> createState() => _StartupGateState();
}

class _StartupGateState extends State<_StartupGate> {
  final _settings = SettingsService();
  bool _checking = true;
  bool _hasToken = false;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    final token = await _settings.getAuthToken();
    setState(() {
      _hasToken = token != null && token.isNotEmpty;
      _checking = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return _hasToken ? const HomeScreen() : const LoginScreen();
  }
}

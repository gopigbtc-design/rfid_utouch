import 'package:shared_preferences/shared_preferences.dart';

/// Stores the Raspberry Pi backend's address and the logged-in auth token
/// locally on the device, so they survive app restarts.
class SettingsService {
  static const _kServerHost = 'server_host';
  static const _kServerPort = 'server_port';
  static const _kAuthToken = 'auth_token';
  static const _kUsername = 'username';

  Future<String> getServerHost() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kServerHost) ?? '';
  }

  Future<void> setServerHost(String host) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kServerHost, host.trim());
  }

  Future<int> getServerPort() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_kServerPort) ?? 8000;
  }

  Future<void> setServerPort(int port) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kServerPort, port);
  }

  Future<String> getBaseUrl() async {
    final host = await getServerHost();
    final port = await getServerPort();
    if (host.isEmpty) return '';
    return 'http://$host:$port';
  }

  Future<String?> getAuthToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kAuthToken);
  }

  Future<void> setAuthToken(String? token) async {
    final prefs = await SharedPreferences.getInstance();
    if (token == null) {
      await prefs.remove(_kAuthToken);
    } else {
      await prefs.setString(_kAuthToken, token);
    }
  }

  Future<String?> getUsername() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kUsername);
  }

  Future<void> setUsername(String? username) async {
    final prefs = await SharedPreferences.getInstance();
    if (username == null) {
      await prefs.remove(_kUsername);
    } else {
      await prefs.setString(_kUsername, username);
    }
  }

  Future<void> clearSession() async {
    await setAuthToken(null);
    await setUsername(null);
  }
}

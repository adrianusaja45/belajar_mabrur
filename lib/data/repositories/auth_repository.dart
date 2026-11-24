import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/api_config.dart';
import '../../core/api_exception.dart';
import '../models/user_model.dart';

class AuthRepository {
  static const Duration _requestTimeout = Duration(seconds: 15);
  static const String _tokenKey = 'auth_token';

  final FlutterSecureStorage _secureStorage;
  final http.Client _client;

  AuthRepository({
    FlutterSecureStorage? secureStorage,
    http.Client? client,
  })  : _secureStorage = secureStorage ?? const FlutterSecureStorage(),
        _client = client ?? http.Client();

  Future<UserModel> login(String username, String password) async {
    final response = await _sendRequest(
      () => _client.post(
        Uri.parse('${ApiConfig.baseUrl}/login'),
        headers: ApiConfig.headers,
        body: jsonEncode({"username": username, "password": password}),
      ),
      timeoutMessage: 'Server tidak merespons. Periksa koneksi Anda.',
      offlineMessage: 'Tidak dapat terhubung ke server. Periksa internet Anda.',
      fallbackMessage: 'Terjadi kesalahan saat masuk. Silakan coba lagi.',
    );

    final data = _decodeJsonObject(response.body);

    if (response.statusCode == 200) {
      final payload = data['data'];
      if (payload is! Map<String, dynamic>) {
        throw const ApiException('Format respons login tidak valid.');
      }

      final token = payload['token']?.toString() ?? '';
      final userMap = payload['user'];
      if (token.isEmpty || userMap is! Map<String, dynamic>) {
        throw const ApiException('Data sesi login tidak lengkap.');
      }

      final user = UserModel.fromJson(
        userMap,
        fallbackUsername: username,
      );

      await _saveUserData(user);
      await _saveToken(token);

      debugPrint("Login Berhasil - Role: ${user.role}, Group: ${user.groupId}");
      return user;
    }

    throw ApiException(
      _extractMessage(data, fallback: 'Nama pengguna atau kata sandi salah.'),
    );
  }

  Future<void> register(String name, String username, String password) async {
    final response = await _sendRequest(
      () => _client.post(
        Uri.parse('${ApiConfig.baseUrl}/register'),
        headers: ApiConfig.headers,
        body: jsonEncode({
          "name": name,
          "username": username,
          "password": password,
          "role": "user",
        }),
      ),
      timeoutMessage: 'Server tidak merespons. Silakan coba lagi.',
      offlineMessage: 'Tidak dapat terhubung ke server. Periksa internet Anda.',
      fallbackMessage: 'Pendaftaran gagal. Silakan coba lagi.',
    );

    final data = _decodeJsonObject(response.body);

    if (response.statusCode == 201 || response.statusCode == 200) {
      return;
    }

    throw ApiException(
      _extractMessage(
        data,
        fallback: 'Pendaftaran gagal. Silakan coba lagi.',
      ),
    );
  }

  Future<UserModel> getProfile() async {
    final token = await _requireToken();
    final response = await _sendRequest(
      () => _client.get(
        Uri.parse('${ApiConfig.baseUrl}/current'),
        headers: _authHeaders(token),
      ),
      timeoutMessage: 'Gagal memuat profil karena koneksi timeout.',
      offlineMessage: 'Tidak ada koneksi internet untuk memuat profil.',
      fallbackMessage: 'Gagal memuat profil. Silakan coba lagi.',
    );

    final data = _decodeJsonObject(response.body);

    if (response.statusCode == 200) {
      final userMap = data['data'];
      if (userMap is! Map<String, dynamic>) {
        throw const ApiException('Format data profil tidak valid.');
      }

      final user = UserModel.fromJson(userMap);
      await _saveUserData(user);
      return user;
    }

    if (response.statusCode == 401) {
      await logout();
    }
    throw ApiException(
      _extractMessage(data, fallback: 'Gagal memuat profil.'),
    );
  }

  Future<void> updateProfile(String name, String username) async {
    final token = await _requireToken();
    final response = await _sendRequest(
      () => _client.put(
        Uri.parse('${ApiConfig.baseUrl}/user/update'),
        headers: _authHeaders(token),
        body: jsonEncode({
          "name": name,
          "username": username,
        }),
      ),
      timeoutMessage: 'Koneksi timeout saat memperbarui profil.',
      offlineMessage: 'Periksa koneksi internet Anda.',
      fallbackMessage: 'Gagal memperbarui profil. Silakan coba lagi.',
    );

    if (response.statusCode == 200) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_name', name);
      await prefs.setString('user_username', username);
      return;
    }

    if (response.statusCode == 401) {
      await logout();
    }
    final data = _decodeJsonObject(response.body);
    throw ApiException(
      _extractMessage(data, fallback: 'Gagal memperbarui profil.'),
    );
  }

  Future<void> updatePassword(String oldPassword, String newPassword) async {
    final token = await _requireToken();
    final response = await _sendRequest(
      () => _client.put(
        Uri.parse('${ApiConfig.baseUrl}/user/password'),
        headers: _authHeaders(token),
        body: jsonEncode({
          "old_password": oldPassword,
          "new_password": newPassword,
        }),
      ),
      timeoutMessage: 'Koneksi timeout saat mengubah kata sandi.',
      offlineMessage: 'Periksa koneksi internet Anda.',
      fallbackMessage: 'Gagal mengubah kata sandi. Silakan coba lagi.',
    );

    if (response.statusCode == 200) {
      return;
    }

    if (response.statusCode == 401) {
      await logout();
    }
    final data = _decodeJsonObject(response.body);
    throw ApiException(
      _extractMessage(data, fallback: 'Gagal mengubah kata sandi.'),
    );
  }

  Future<UserModel?> getCachedUser() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getString('saved_user_id');
    final role = prefs.getString('user_role');
    if (id == null && role == null) return null;

    return UserModel(
      id: id ?? '',
      name: prefs.getString('user_name') ?? 'User',
      username: prefs.getString('user_username') ?? '-',
      role: role ?? 'user',
      groupId: prefs.getString('user_group_id') ?? 'default',
    );
  }

  Future<String> getGroupId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('user_group_id') ?? 'default';
  }

  Future<bool> hasToken() async {
    final token = await _readToken();
    return token != null && token.isNotEmpty;
  }

  Future<void> logout() async {
    try {
      await _secureStorage.delete(key: _tokenKey);
    } catch (e) {
      debugPrint('Secure storage delete error: $e');
    }

    // Keep sos_history_* keys so each group retains offline emergency history.
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove('user_role');
    await prefs.remove('saved_user_id');
    await prefs.remove('user_group_id');
    await prefs.remove('user_name');
    await prefs.remove('user_username');
  }

  Future<void> _saveUserData(UserModel user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_role', user.role);
    await prefs.setString('saved_user_id', user.id);
    await prefs.setString('user_group_id', user.groupId);
    await prefs.setString('user_name', user.name);
    await prefs.setString('user_username', user.username);
  }

  Future<void> _saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    try {
      await _secureStorage.write(key: _tokenKey, value: token);
      await prefs.remove(_tokenKey);
    } catch (e) {
      debugPrint('Secure storage write fallback: $e');
      await prefs.setString(_tokenKey, token);
    }
  }

  Future<String?> _readToken() async {
    try {
      final secureToken = await _secureStorage.read(key: _tokenKey);
      if (secureToken != null && secureToken.isNotEmpty) {
        return secureToken;
      }
    } catch (e) {
      debugPrint('Secure storage read error: $e');
    }

    // One-time migration from legacy SharedPreferences token.
    final prefs = await SharedPreferences.getInstance();
    final legacyToken = prefs.getString(_tokenKey);
    if (legacyToken != null && legacyToken.isNotEmpty) {
      try {
        await _secureStorage.write(key: _tokenKey, value: legacyToken);
        await prefs.remove(_tokenKey);
      } catch (e) {
        debugPrint('Secure storage migration error: $e');
      }
      return legacyToken;
    }

    return null;
  }

  Future<String> _requireToken() async {
    final token = await _readToken();
    if (token == null || token.isEmpty) {
      throw const ApiException(
          'Sesi Anda telah berakhir. Silakan masuk kembali.');
    }
    return token;
  }

  Map<String, String> _authHeaders(String token) => {
        ...ApiConfig.headers,
        'Authorization': 'Bearer $token',
      };

  Future<http.Response> _sendRequest(
    Future<http.Response> Function() request, {
    required String timeoutMessage,
    required String offlineMessage,
    required String fallbackMessage,
  }) async {
    try {
      return await request().timeout(_requestTimeout);
    } on ApiException {
      rethrow;
    } on TimeoutException {
      throw ApiException(timeoutMessage);
    } on SocketException {
      throw ApiException(offlineMessage);
    } catch (e) {
      debugPrint('AuthRepository request error: $e');
      throw ApiException(fallbackMessage);
    }
  }

  Map<String, dynamic> _decodeJsonObject(String body) {
    if (body.trim().isEmpty) return const {};
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      return const {};
    } on FormatException {
      throw const ApiException(
          'Server mengembalikan respons yang tidak valid.');
    }
  }

  String _extractMessage(
    Map<String, dynamic> data, {
    required String fallback,
  }) {
    final msg = data['message']?.toString().trim();
    if (msg != null && msg.isNotEmpty) {
      return msg;
    }
    return fallback;
  }
}

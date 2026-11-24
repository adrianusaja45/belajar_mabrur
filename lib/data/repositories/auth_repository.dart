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

  AuthRepository({FlutterSecureStorage? secureStorage})
      : _secureStorage = secureStorage ?? const FlutterSecureStorage();

  Future<UserModel> login(String username, String password) async {
    try {
      final response = await http
          .post(
            Uri.parse('${ApiConfig.baseUrl}/login'),
            headers: ApiConfig.headers,
            body: jsonEncode({"username": username, "password": password}),
          )
          .timeout(_requestTimeout);

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

        debugPrint(
            "Login Berhasil - Role: ${user.role}, Group: ${user.groupId}");
        return user;
      }

      throw ApiException(
        _extractMessage(data, fallback: 'Username atau password salah.'),
      );
    } on ApiException {
      rethrow;
    } on TimeoutException {
      throw const ApiException('Server tidak merespons. Periksa koneksi Anda.');
    } on SocketException {
      throw const ApiException(
          'Tidak dapat terhubung ke server. Periksa internet Anda.');
    } catch (e) {
      throw ApiException('Terjadi kesalahan saat masuk: $e');
    }
  }

  Future<void> register(String name, String username, String password) async {
    try {
      final response = await http
          .post(
            Uri.parse('${ApiConfig.baseUrl}/register'),
            headers: ApiConfig.headers,
            body: jsonEncode({
              "name": name,
              "username": username,
              "password": password,
              "role": "user",
            }),
          )
          .timeout(_requestTimeout);

      final data = _decodeJsonObject(response.body);

      if (response.statusCode == 201 || response.statusCode == 200) {
        return;
      }

      throw ApiException(
        _extractMessage(data,
            fallback: 'Pendaftaran gagal. Silakan coba lagi.'),
      );
    } on ApiException {
      rethrow;
    } on TimeoutException {
      throw const ApiException('Server tidak merespons. Silakan coba lagi.');
    } on SocketException {
      throw const ApiException(
          'Tidak dapat terhubung ke server. Periksa internet Anda.');
    } catch (e) {
      throw ApiException('Gagal mendaftar: $e');
    }
  }

  Future<UserModel> getProfile() async {
    final token = await _requireToken();

    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/current'),
        headers: {
          ...ApiConfig.headers,
          'Authorization': 'Bearer $token',
        },
      ).timeout(_requestTimeout);

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
    } on ApiException {
      rethrow;
    } on TimeoutException {
      throw const ApiException('Gagal memuat profil karena koneksi timeout.');
    } on SocketException {
      throw const ApiException(
          'Tidak ada koneksi internet untuk memuat profil.');
    } catch (e) {
      throw ApiException('Gagal memuat profil: $e');
    }
  }

  Future<void> updateProfile(String name, String username) async {
    final token = await _requireToken();

    try {
      final response = await http
          .put(
            Uri.parse('${ApiConfig.baseUrl}/user/update'),
            headers: {
              ...ApiConfig.headers,
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({
              "name": name,
              "username": username,
            }),
          )
          .timeout(_requestTimeout);

      if (response.statusCode == 200) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user_name', name);
        await prefs.setString('user_username', username);
        return;
      }

      final data = _decodeJsonObject(response.body);
      throw ApiException(
        _extractMessage(data, fallback: 'Gagal memperbarui profil.'),
      );
    } on ApiException {
      rethrow;
    } on TimeoutException {
      throw const ApiException('Koneksi timeout saat memperbarui profil.');
    } on SocketException {
      throw const ApiException('Periksa koneksi internet Anda.');
    } catch (e) {
      throw ApiException('Gagal memperbarui profil: $e');
    }
  }

  Future<void> updatePassword(String oldPassword, String newPassword) async {
    final token = await _requireToken();

    try {
      final response = await http
          .put(
            Uri.parse('${ApiConfig.baseUrl}/user/password'),
            headers: {
              ...ApiConfig.headers,
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({
              "old_password": oldPassword,
              "new_password": newPassword,
            }),
          )
          .timeout(_requestTimeout);

      if (response.statusCode == 200) {
        return;
      }

      final data = _decodeJsonObject(response.body);
      throw ApiException(
        _extractMessage(data, fallback: 'Gagal mengubah password.'),
      );
    } on ApiException {
      rethrow;
    } on TimeoutException {
      throw const ApiException('Koneksi timeout saat mengubah password.');
    } on SocketException {
      throw const ApiException('Periksa koneksi internet Anda.');
    } catch (e) {
      throw ApiException('Gagal mengubah password: $e');
    }
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

    // Keep sos_history_list so host retains emergency history on shared devices.
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
      throw const ApiException('Sesi habis, silakan login ulang.');
    }
    return token;
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

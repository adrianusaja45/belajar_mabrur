import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/api_config.dart';

class AuthRepository {
  
  // --- LOGIN ---
  Future<Map<String, dynamic>> login(String username, String password) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/login'),
        headers: ApiConfig.headers,
        body: jsonEncode({"username": username, "password": password}),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        String token = data['data']['token'];
        String role = data['data']['user']['role'] ?? 'user';
        String userId = data['data']['user']['id'].toString();
        String groupId = data['data']['user']['group_id']?.toString() ?? 'default';

        // Simpan data penting ke HP
        await _saveUserData(role, userId, groupId);
        await _saveToken(token);
        
        debugPrint("Login Berhasil - Role: $role, Group: $groupId");
        return data;
      } else {
        throw Exception(data['message'] ?? 'Login Gagal');
      }
    } catch (e) {
      throw Exception("Koneksi Error: $e");
    }
  }

  // --- REGISTER ---
  Future<Map<String, dynamic>> register(String name, String username, String password) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/register'),
        headers: ApiConfig.headers,
        body: jsonEncode({
          "name": name,
          "username": username,
          "password": password,
          "role": "user" 
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 201 || response.statusCode == 200) {
        return data;
      } else {
        throw Exception(data['message'] ?? 'Register Gagal');
      }
    } catch (e) {
      throw Exception("Koneksi Error: $e");
    }
  }

  // --- GET PROFILE ---
  Future<Map<String, dynamic>> getProfile() async {
    final token = await _getToken();
    
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/current'),
      headers: {
        ...ApiConfig.headers, // Copy header default
        'Authorization': 'Bearer $token', // Tambah token
      },
    );

    final data = jsonDecode(response.body);

    if (response.statusCode == 200) {
      String role = data['data']['role'] ?? 'user';
      String userId = data['data']['id'].toString();
      String groupId = data['data']['group_id']?.toString() ?? 'default';
      
      await _saveUserData(role, userId, groupId);
      return data['data']; 
    } else {
      if (response.statusCode == 401) await logout();
      throw Exception(data['message'] ?? 'Gagal memuat profil');
    }
  }

  // --- UPDATE PROFILE ---
  Future<void> updateProfile(String name, String username) async {
    final token = await _getToken();

    final response = await http.put(
      Uri.parse('${ApiConfig.baseUrl}/user/update'),
      headers: {
        ...ApiConfig.headers,
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        "name": name,
        "username": username,
      }),
    );

    if (response.statusCode != 200) {
      final body = jsonDecode(response.body);
      throw Exception(body['message'] ?? "Gagal memperbarui profil");
    }
  }

  // --- UPDATE PASSWORD ---
  Future<void> updatePassword(String oldPassword, String newPassword) async {
    final token = await _getToken();

    final response = await http.put(
      Uri.parse('${ApiConfig.baseUrl}/user/password'),
      headers: {
        ...ApiConfig.headers,
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        "old_password": oldPassword,
        "new_password": newPassword,
      }),
    );

    if (response.statusCode != 200) {
      final body = jsonDecode(response.body);
      throw Exception(body['message'] ?? "Gagal mengubah password");
    }
  }

  // --- HELPERS (Local Storage) ---
  
  Future<void> _saveUserData(String role, String id, String groupId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_role', role);
    await prefs.setString('saved_user_id', id);
    await prefs.setString('user_group_id', groupId);
  }

  Future<void> _saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', token);
  }

  /// Helper private untuk mengambil token (mengurangi duplikasi kode)
  Future<String> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    if (token == null || token.isEmpty) throw Exception('Sesi habis, silakan login ulang.');
    return token;
  }

  Future<String> getGroupId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('user_group_id') ?? 'default';
  }

  Future<bool> hasToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token') != null;
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }
}
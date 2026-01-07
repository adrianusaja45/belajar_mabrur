import 'dart:convert';
import 'package:flutter/material.dart'; // Digunakan untuk debugPrint
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/content_model.dart'; // Digunakan di getContents

class AuthRepository {
  final String baseUrl = "https://albirr.web.id/api";
  final String apiKey = "prod_Uo0j5rtuOcRH3vDPvgAfHHuQspJfMNOEfooSKOhZt7E";

  // --- LOGIN ---
  Future<Map<String, dynamic>> login(String username, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/login'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'X-API-KEY': apiKey.trim(),
        },
        body: jsonEncode({"username": username, "password": password}),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        String token = data['data']['token'];
        // Mengambil role 'host' atau 'user' sesuai data server
        String role = data['data']['user']['role'] ?? 'user';
        String userId = data['data']['user']['id'].toString();

        await _saveToken(token);
        await _saveUserData(role, userId);
        debugPrint("Login Berhasil - Role: $role");
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
        Uri.parse('$baseUrl/register'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'X-API-KEY': apiKey.trim(),
        },
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
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');

    if (token == null || token.isEmpty) throw Exception('Token tidak ditemukan.');

    final response = await http.get(
      Uri.parse('$baseUrl/current'),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'X-API-KEY': apiKey.trim(),
        'Authorization': 'Bearer $token',
      },
    );

    final data = jsonDecode(response.body);

    if (response.statusCode == 200) {
      String role = data['data']['role'] ?? 'user';
      String userId = data['data']['id'].toString();
      await _saveUserData(role, userId); // Sinkronisasi role lokal
      return data['data']; 
    } else {
      if (response.statusCode == 401) await logout();
      throw Exception(data['message'] ?? 'Gagal memuat profil');
    }
  }

  // --- [BARU] UPDATE PROFILE ---
  Future<void> updateProfile(String name, String username) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');

    if (token == null || token.isEmpty) throw Exception('Token tidak ditemukan.');

    final response = await http.put(
      Uri.parse('$baseUrl/user/update'),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'X-API-KEY': apiKey.trim(),
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        "name": name,
        "username": username,
      }),
    );

    if (response.statusCode != 200) {
      final body = jsonDecode(response.body);
      // Menangkap pesan error dari server jika ada (misal: username sudah dipakai)
      throw Exception(body['message'] ?? "Gagal memperbarui profil");
    }
  }

  // --- [BARU] UPDATE PASSWORD ---
  Future<void> updatePassword(String oldPassword, String newPassword) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');

    if (token == null || token.isEmpty) throw Exception('Token tidak ditemukan.');

    final response = await http.put(
      Uri.parse('$baseUrl/user/password'),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'X-API-KEY': apiKey.trim(),
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        "old_password": oldPassword,
        "new_password": newPassword,
      }),
    );

    if (response.statusCode != 200) {
      final body = jsonDecode(response.body);
      // API Anda mengembalikan 400 untuk Validation Error (misal: password lama salah)
      throw Exception(body['message'] ?? "Gagal mengubah password");
    }
  }

  // --- GET CONTENT ---
  Future<List<ContentModel>> getContents() async {
    final response = await http.get(
      Uri.parse('$baseUrl/content'),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'X-API-KEY': apiKey.trim(),
      },
    );

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      final List dataList = json['data'];
      // Memastikan ContentModel terpakai
      return dataList.map((e) => ContentModel.fromJson(e)).toList();
    } else {
      throw Exception('Gagal memuat konten');
    }
  }

  // --- HELPERS ---
  Future<void> _saveUserData(String role, String id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_role', role);
    await prefs.setString('saved_user_id', id);
  }

  Future<String> getRole() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('user_role') ?? 'user';
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear(); // Hapus semua data termasuk role dan token
  }

  Future<void> _saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', token);
  }

  Future<bool> hasToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token') != null;
  }
}
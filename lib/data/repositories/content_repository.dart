import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/api_config.dart';
import '../../core/api_exception.dart';
import '../models/content_model.dart';

class ContentRepository {
  static const Duration _requestTimeout = Duration(seconds: 15);
  static const String _cacheKey = 'cached_contents_json';

  final http.Client _client;

  ContentRepository({http.Client? client}) : _client = client ?? http.Client();

  Future<({List<ContentModel> items, bool fromCache})> getContents() async {
    try {
      final response = await _client
          .get(
            Uri.parse('${ApiConfig.baseUrl}/content'),
            headers: ApiConfig.headers,
          )
          .timeout(_requestTimeout);

      if (response.statusCode == 200) {
        final dynamic decoded;
        try {
          decoded = jsonDecode(response.body);
        } on FormatException {
          throw const ApiException(
            'Format data panduan dari server tidak valid.',
          );
        }

        if (decoded is! Map<String, dynamic> || decoded['data'] is! List) {
          throw const ApiException('Struktur data panduan tidak sesuai.');
        }

        final dataList = decoded['data'] as List;
        final items = dataList
            .whereType<Map<String, dynamic>>()
            .map(ContentModel.fromJson)
            .toList();

        await _saveCache(items);
        return (items: items, fromCache: false);
      }

      throw ApiException(
        'Gagal memuat panduan (kode ${response.statusCode}).',
      );
    } on ApiException {
      final cached = await _readCache();
      if (cached.isNotEmpty) return (items: cached, fromCache: true);
      rethrow;
    } on TimeoutException {
      final cached = await _readCache();
      if (cached.isNotEmpty) return (items: cached, fromCache: true);
      throw const ApiException('Server tidak merespons. Periksa koneksi Anda.');
    } on SocketException {
      final cached = await _readCache();
      if (cached.isNotEmpty) return (items: cached, fromCache: true);
      throw const ApiException(
        'Tidak ada koneksi internet untuk memuat panduan.',
      );
    } catch (e) {
      debugPrint('ContentRepository error: $e');
      final cached = await _readCache();
      if (cached.isNotEmpty) return (items: cached, fromCache: true);
      throw const ApiException('Gagal memuat panduan. Silakan coba lagi.');
    }
  }

  Future<void> _saveCache(List<ContentModel> items) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = jsonEncode(items.map((item) => item.toJson()).toList());
      await prefs.setString(_cacheKey, encoded);
    } catch (e) {
      debugPrint('Gagal menyimpan cache doa: $e');
    }
  }

  Future<List<ContentModel>> _readCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_cacheKey);
      if (raw == null || raw.isEmpty) return const [];
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded
          .whereType<Map>()
          .map((item) => ContentModel.fromJson(Map<String, dynamic>.from(item)))
          .toList();
    } catch (e) {
      debugPrint('Gagal membaca cache doa: $e');
      return const [];
    }
  }
}

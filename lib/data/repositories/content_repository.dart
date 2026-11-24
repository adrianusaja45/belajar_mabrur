import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../core/api_config.dart';
import '../../core/api_exception.dart';
import '../models/content_model.dart';

class ContentRepository {
  static const Duration _requestTimeout = Duration(seconds: 15);

  final http.Client _client;

  ContentRepository({http.Client? client}) : _client = client ?? http.Client();

  Future<List<ContentModel>> getContents() async {
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
              'Format data panduan dari server tidak valid.');
        }

        if (decoded is! Map<String, dynamic> || decoded['data'] is! List) {
          throw const ApiException('Struktur data panduan tidak sesuai.');
        }

        final dataList = decoded['data'] as List;
        return dataList
            .whereType<Map<String, dynamic>>()
            .map(ContentModel.fromJson)
            .toList();
      }

      throw ApiException('Gagal memuat panduan (HTTP ${response.statusCode}).');
    } on ApiException {
      rethrow;
    } on TimeoutException {
      throw const ApiException('Server tidak merespons. Periksa koneksi Anda.');
    } on SocketException {
      throw const ApiException(
          'Tidak ada koneksi internet untuk memuat panduan.');
    } catch (e) {
      debugPrint('ContentRepository error: $e');
      throw const ApiException('Gagal memuat panduan. Silakan coba lagi.');
    }
  }
}

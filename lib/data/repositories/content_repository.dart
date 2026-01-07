import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../core/api_config.dart';
import '../models/content_model.dart';

class ContentRepository {
  /// Mengambil daftar konten dari API.
  Future<List<ContentModel>> getContents() async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/content'),
        headers: ApiConfig.headers, // Menggunakan header dari config
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        final List dataList = json['data'];
        
        // Mapping List JSON ke List<ContentModel>
        return dataList.map((e) => ContentModel.fromJson(e)).toList();
      } else {
        throw Exception('Gagal memuat konten: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception("Content Error: $e");
    }
  }
}
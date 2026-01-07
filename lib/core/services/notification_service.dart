import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:googleapis_auth/auth_io.dart';
// Baris import http dihapus karena tidak digunakan

class NotificationService {
  /// Mengirim Notifikasi SOS ke Topic Group tertentu
  Future<void> sendSOS({
    required String senderName,
    required String groupId,
    required double lat,
    required double lng,
  }) async {
    try {
      // 1. Load Service Account (Rahasia)
      final jsonString = await rootBundle.loadString('assets/service_account.json');
      final Map<String, dynamic> jsonMap = jsonDecode(jsonString);
      final serviceAccount = ServiceAccountCredentials.fromJson(jsonMap);
      
      // 2. Dapatkan Akses HTTP Client yang sudah ter-otentikasi
      final client = await clientViaServiceAccount(
        serviceAccount, 
        ['https://www.googleapis.com/auth/firebase.messaging']
      );

      // 3. Susun Payload Data
      final notificationData = {
        "message": {
          "topic": "sos_group_$groupId", // Topik Dinamis
          "notification": {
            "title": "DARURAT (Group $groupId)", 
            "body": "$senderName butuh bantuan segera!"
          },
          "android": { "priority": "high" },
          "data": {
            "lat": lat.toString(),
            "lng": lng.toString(),
            "sender_name": senderName,
            "group_id": groupId,
            "type": "sos"
          }
        }
      };

      // 4. Kirim Request menggunakan client auth
      await client.post(
        Uri.parse('https://fcm.googleapis.com/v1/projects/${jsonMap['project_id']}/messages:send'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(notificationData),
      );

      // Jangan lupa tutup client setelah selesai
      client.close();
    } catch (e) {
      throw Exception("Gagal mengirim SOS: $e");
    }
  }
}
import 'package:cloud_firestore/cloud_firestore.dart';

class SosRepository {
  final FirebaseFirestore _firestore;

  SosRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _reports =>
      _firestore.collection('sos_reports');

  Future<void> createReport({
    required String groupId,
    required String senderName,
    required double lat,
    required double lng,
  }) async {
    await _reports.add({
      'group_id': groupId,
      'sender_name': senderName,
      'lat': lat,
      'lng': lng,
      'created_at': FieldValue.serverTimestamp(),
    });
  }

  Stream<List<Map<String, dynamic>>> watchReports(String groupId) {
    return _reports
        .where('group_id', isEqualTo: groupId)
        .snapshots()
        .map((snapshot) {
      final reports = snapshot.docs.map(_mapReport).toList();
      reports.sort(
        (a, b) => (b['created_at_millis'] as int)
            .compareTo(a['created_at_millis'] as int),
      );
      return reports;
    });
  }

  Map<String, dynamic> _mapReport(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data();
    final createdAt = data['created_at'];
    final timestamp = createdAt is Timestamp ? createdAt : null;

    return {
      'id': document.id,
      'lat': data['lat'],
      'lng': data['lng'],
      'time': timestamp == null ? '--:--' : _formatTime(timestamp.toDate()),
      'name': data['sender_name'] ?? 'Seseorang',
      'created_at_millis': timestamp?.millisecondsSinceEpoch ?? 0,
    };
  }

  String _formatTime(DateTime value) {
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}

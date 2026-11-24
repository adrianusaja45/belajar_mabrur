import 'package:belajar_mabrur/data/models/content_model.dart';
import 'package:belajar_mabrur/data/models/user_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('UserModel', () {
    test('parses host fields, sosTopic, and fallbacks accurately', () {
      final host = UserModel.fromJson(const {
        'id': 42,
        'name': 'Ust. Ahmad',
        'username': 'ahmad',
        'role': 'host',
        'group_id': 'kloter_7',
      });

      expect(host.id, '42');
      expect(host.name, 'Ust. Ahmad');
      expect(host.username, 'ahmad');
      expect(host.isHost, isTrue);
      expect(host.sosTopic, 'sos_group_kloter_7');

      final fallback =
          UserModel.fromJson(const {}, fallbackUsername: 'jamaah01');
      expect(fallback.name, 'jamaah01');
      expect(fallback.username, 'jamaah01');
      expect(fallback.role, 'user');
      expect(fallback.isHost, isFalse);
      expect(fallback.groupId, 'default');
    });
  });

  group('ContentModel', () {
    test('supports toJson and fromJson round-trip for offline cache', () {
      final source = ContentModel.fromJson({
        'id': '12',
        'name': 'Niat Ihram Umrah',
        'category': 'Ihram',
        'arabic': 'نَوَيْتُ الْعُمْرَةَ وَأَحْرَمْتُ بِهَا لِلَّهِ تَعَالَى',
        'latin': 'Nawaitul umrata wa ahramtu biha lillahi taala',
        'translate_id': 'Aku niat umrah dengan berihram karena Allah Taala.',
        'description': 'Dibaca saat mengambil miqat.',
      });

      final roundTrip = ContentModel.fromJson(source.toJson());
      expect(roundTrip.id, 12);
      expect(roundTrip.name, source.name);
      expect(roundTrip.category, 'Ihram');
      expect(roundTrip.arabic, source.arabic);
      expect(roundTrip.latin, source.latin);
      expect(roundTrip.translateId, source.translateId);
      expect(roundTrip.description, source.description);
    });
  });
}

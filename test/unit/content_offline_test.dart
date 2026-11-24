import 'dart:convert';
import 'dart:io';

import 'package:belajar_mabrur/core/api_exception.dart';
import 'package:belajar_mabrur/data/repositories/content_repository.dart';
import 'package:belajar_mabrur/logic/content/content_cubit.dart';
import 'package:belajar_mabrur/logic/content/content_state.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUpAll(() {
    dotenv.loadFromString(
      envString: 'API_BASE_URL=https://albirr.web.id/api\nAPI_KEY=test-key',
    );
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  final sampleApiBody = jsonEncode({
    'data': [
      {
        'id': 1,
        'name': 'Doa Niat Ihram',
        'category': 'Ihram',
        'arabic': 'لَبَّيْكَ اللَّهُمَّ عُمْرَةً',
        'latin': 'Labbaikallahumma umratan',
        'translate_id': 'Aku penuhi panggilan-Mu untuk umrah.',
        'description': 'Dibaca saat miqat.',
      },
      {
        'id': 2,
        'name': 'Doa Antara Rukun Yamani dan Hajar Aswad',
        'category': 'Thawaf',
        'arabic': 'رَبَّنَا آتِنَا فِي الدُّنْيَا حَسَنَةً',
        'latin': 'Rabbana atina fid-dunya hasanah',
        'translate_id': 'Ya Tuhan kami, berilah kami kebaikan di dunia.',
        'description': '',
      },
    ],
  });

  test('caches online contents and falls back to offline cache on network fail',
      () async {
    final onlineRepo = ContentRepository(
      client: MockClient(
        (_) async => http.Response.bytes(utf8.encode(sampleApiBody), 200),
      ),
    );

    final onlineResult = await onlineRepo.getContents();
    expect(onlineResult.fromCache, isFalse);
    expect(onlineResult.items.length, 2);

    final offlineRepo = ContentRepository(
      client: MockClient((_) async => throw const SocketException('Offline')),
    );

    final cachedResult = await offlineRepo.getContents();
    expect(cachedResult.fromCache, isTrue);
    expect(cachedResult.items.length, 2);
    expect(cachedResult.items.first.name, 'Doa Niat Ihram');
  });

  test('throws ApiException when offline and local cache is empty', () async {
    final offlineRepo = ContentRepository(
      client: MockClient((_) async => throw const SocketException('Offline')),
    );

    expect(
      offlineRepo.getContents,
      throwsA(isA<ApiException>()),
    );
  });

  test('ContentCubit filters category/query and preserves isFromCache flag',
      () async {
    final onlineRepo = ContentRepository(
      client: MockClient(
        (_) async => http.Response.bytes(utf8.encode(sampleApiBody), 200),
      ),
    );
    await onlineRepo.getContents();

    final offlineRepo = ContentRepository(
      client: MockClient((_) async => throw const SocketException('Offline')),
    );
    final cubit = ContentCubit(offlineRepo);

    await cubit.fetchContent();
    expect(cubit.state, isA<ContentLoaded>());
    var loaded = cubit.state as ContentLoaded;
    expect(loaded.isFromCache, isTrue);
    expect(loaded.displayList.length, 2);

    cubit.filterContent(category: 'Thawaf');
    loaded = cubit.state as ContentLoaded;
    expect(loaded.isFromCache, isTrue);
    expect(loaded.displayList.length, 1);
    expect(loaded.displayList.first.name, contains('Rukun Yamani'));

    cubit.filterContent(category: 'All', query: 'labbaik');
    loaded = cubit.state as ContentLoaded;
    expect(loaded.isFromCache, isTrue);
    expect(loaded.displayList.length, 1);
    expect(loaded.displayList.first.name, 'Doa Niat Ihram');

    await cubit.close();
  });
}

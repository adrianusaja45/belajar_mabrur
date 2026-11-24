import 'dart:convert';
import 'dart:io';

import 'package:belajar_mabrur/core/api_exception.dart';
import 'package:belajar_mabrur/data/repositories/auth_repository.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MemorySecureStorage extends FlutterSecureStorage {
  final Map<String, String> store = {};

  @override
  Future<void> write({
    required String key,
    required String? value,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (value == null) {
      store.remove(key);
    } else {
      store[key] = value;
    }
  }

  @override
  Future<String?> read({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    return store[key];
  }

  @override
  Future<void> delete({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    store.remove(key);
  }
}

void main() {
  setUpAll(() {
    dotenv.loadFromString(
      envString: 'API_BASE_URL=https://albirr.web.id/api\nAPI_KEY=test-key',
    );
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('login stores token securely and caches user profile', () async {
    final storage = _MemorySecureStorage();
    final repo = AuthRepository(
      secureStorage: storage,
      client: MockClient((_) async {
        return http.Response(
          jsonEncode({
            'data': {
              'token': 'jwt-token-123',
              'user': {
                'id': 7,
                'name': 'Ust. Karim',
                'username': 'karim',
                'role': 'host',
                'group_id': 'kloter_2',
              },
            },
          }),
          200,
        );
      }),
    );

    final user = await repo.login('karim', 'secret123');
    expect(user.isHost, isTrue);
    expect(storage.store['auth_token'], 'jwt-token-123');
    expect(await repo.hasToken(), isTrue);
    expect((await repo.getCachedUser())?.groupId, 'kloter_2');
  });

  test('updateProfile and updatePassword clear session on HTTP 401', () async {
    final storage = _MemorySecureStorage()..store['auth_token'] = 'expired';
    final repo = AuthRepository(
      secureStorage: storage,
      client: MockClient(
        (_) async =>
            http.Response(jsonEncode({'message': 'Unauthorized'}), 401),
      ),
    );

    await expectLater(
      repo.updateProfile('Nama Baru', 'namabaru'),
      throwsA(isA<ApiException>()),
    );
    expect(await repo.hasToken(), isFalse);

    storage.store['auth_token'] = 'expired2';
    await expectLater(
      repo.updatePassword('oldpass', 'newpass123'),
      throwsA(isA<ApiException>()),
    );
    expect(await repo.hasToken(), isFalse);
  });

  test('maps SocketException to clean Indonesian ApiException', () async {
    final repo = AuthRepository(
      secureStorage: _MemorySecureStorage(),
      client: MockClient((_) async => throw const SocketException('offline')),
    );

    await expectLater(
      repo.login('user', 'pass'),
      throwsA(
        isA<ApiException>().having(
          (e) => e.message,
          'message',
          contains('Periksa internet Anda'),
        ),
      ),
    );
  });
}

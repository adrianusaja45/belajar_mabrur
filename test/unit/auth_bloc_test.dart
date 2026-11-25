import 'package:belajar_mabrur/core/api_exception.dart';
import 'package:belajar_mabrur/data/models/user_model.dart';
import 'package:belajar_mabrur/data/repositories/auth_repository.dart';
import 'package:belajar_mabrur/logic/auth/auth_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeAuthRepository extends AuthRepository {
  bool tokenPresent = false;
  UserModel? cachedUser;
  UserModel? profileResponse;
  Object? profileError;
  bool clearTokenOnProfileError = false;
  UserModel? loginResponse;
  Object? loginError;
  bool logoutCalled = false;
  String? lastSosTopic;

  @override
  Future<UserModel> login(String username, String password) async {
    if (loginError != null) throw loginError!;
    tokenPresent = true;
    cachedUser = loginResponse;
    return loginResponse!;
  }

  @override
  Future<UserModel> getProfile() async {
    if (profileError != null) {
      if (clearTokenOnProfileError) {
        tokenPresent = false;
        cachedUser = null;
      }
      throw profileError!;
    }
    return profileResponse!;
  }

  @override
  Future<bool> hasToken() async => tokenPresent;

  @override
  Future<UserModel?> getCachedUser() async => cachedUser;

  @override
  Future<String> getGroupId() async =>
      UserModel.normalizeGroupId(cachedUser?.groupId);

  @override
  Future<String?> getLastSubscribedSosTopic() async => lastSosTopic;

  @override
  Future<void> setLastSubscribedSosTopic(String? topic) async {
    lastSosTopic = (topic == null || topic.trim().isEmpty) ? null : topic;
  }

  @override
  Future<void> logout() async {
    logoutCalled = true;
    tokenPresent = false;
    cachedUser = null;
  }
}

void main() {
  const hostUser = UserModel(
    id: '1',
    name: 'Ust. Salman',
    username: 'salman',
    role: 'host',
    groupId: 'g10',
  );

  const jamaahUser = UserModel(
    id: '2',
    name: 'Budi',
    username: 'budi',
    role: 'user',
    groupId: 'g10',
  );

  test('login subscribes host to group topic and unsubscribes jamaah',
      () async {
    final repo = _FakeAuthRepository()..loginResponse = hostUser;
    final subscribed = <String>[];
    final unsubscribed = <String>[];

    final bloc = AuthBloc(
      authRepository: repo,
      subscribeToTopic: (topic) async => subscribed.add(topic),
      unsubscribeFromTopic: (topic) async => unsubscribed.add(topic),
    );

    bloc.add(const LoginRequested('salman', 'secret123'));
    await expectLater(
      bloc.stream,
      emitsInOrder([
        isA<AuthLoading>(),
        isA<AuthSuccess>().having((s) => s.user, 'user', hostUser),
      ]),
    );
    expect(subscribed, ['sos_group_g10']);
    expect(unsubscribed, isEmpty);

    repo.loginResponse = jamaahUser;
    bloc.add(const LoginRequested('budi', 'secret123'));
    await expectLater(
      bloc.stream,
      emitsInOrder([
        isA<AuthLoading>(),
        isA<AuthSuccess>().having((s) => s.user, 'user', jamaahUser),
      ]),
    );
    expect(unsubscribed, ['sos_group_g10']);
    await bloc.close();
  });

  test('CheckAuthStatus keeps cached session when offline and token exists',
      () async {
    final repo = _FakeAuthRepository()
      ..tokenPresent = true
      ..cachedUser = jamaahUser
      ..profileError = const ApiException('Tidak ada koneksi internet.');

    final bloc = AuthBloc(
      authRepository: repo,
      subscribeToTopic: (_) async {},
      unsubscribeFromTopic: (_) async {},
    );

    bloc.add(CheckAuthStatus());
    await expectLater(
      bloc.stream,
      emits(
        isA<AuthSuccess>()
            .having((s) => s.user, 'user', jamaahUser)
            .having((s) => s.message, 'message', 'Mode offline'),
      ),
    );
    await bloc.close();
  });

  test('CheckAuthStatus emits AuthUnauthenticated when 401 cleared token',
      () async {
    final repo = _FakeAuthRepository()
      ..tokenPresent = true
      ..cachedUser = jamaahUser
      ..profileError = const ApiException('Sesi habis.')
      ..clearTokenOnProfileError = true;

    final bloc = AuthBloc(
      authRepository: repo,
      subscribeToTopic: (_) async {},
      unsubscribeFromTopic: (_) async {},
    );

    bloc.add(CheckAuthStatus());
    await expectLater(bloc.stream, emits(isA<AuthUnauthenticated>()));
    await bloc.close();
  });

  test('LogoutRequested unsubscribes FCM topic and logs out repository',
      () async {
    final repo = _FakeAuthRepository()
      ..tokenPresent = true
      ..cachedUser = hostUser;
    final unsubscribed = <String>[];

    final bloc = AuthBloc(
      authRepository: repo,
      subscribeToTopic: (_) async {},
      unsubscribeFromTopic: (topic) async => unsubscribed.add(topic),
    );

    bloc.add(LogoutRequested());
    await expectLater(bloc.stream, emits(isA<AuthUnauthenticated>()));
    expect(unsubscribed, ['sos_group_g10']);
    expect(repo.logoutCalled, isTrue);
    await bloc.close();
  });

  test('ungrouped host does not subscribe and group switch unsubscribes old',
      () async {
    const ungroupedHost = UserModel(
      id: '3',
      name: 'Ust. Baru',
      username: 'baru',
      role: 'host',
      groupId: '',
    );
    const hostGroup20 = UserModel(
      id: '1',
      name: 'Ust. Salman',
      username: 'salman',
      role: 'host',
      groupId: 'g20',
    );

    final repo = _FakeAuthRepository()..loginResponse = ungroupedHost;
    final subscribed = <String>[];
    final unsubscribed = <String>[];

    final bloc = AuthBloc(
      authRepository: repo,
      subscribeToTopic: (topic) async => subscribed.add(topic),
      unsubscribeFromTopic: (topic) async => unsubscribed.add(topic),
    );

    bloc.add(const LoginRequested('baru', 'secret123'));
    await expectLater(
      bloc.stream,
      emitsInOrder([
        isA<AuthLoading>(),
        isA<AuthSuccess>().having((s) => s.user.hasGroup, 'hasGroup', isFalse),
      ]),
    );
    expect(subscribed, isEmpty);
    expect(unsubscribed, isEmpty);

    repo.loginResponse = hostUser;
    bloc.add(const LoginRequested('salman', 'secret123'));
    await expectLater(
      bloc.stream,
      emitsInOrder([isA<AuthLoading>(), isA<AuthSuccess>()]),
    );
    expect(subscribed, ['sos_group_g10']);

    repo.profileResponse = hostGroup20;
    bloc.add(ProfileRefreshRequested());
    await expectLater(
      bloc.stream,
      emits(isA<AuthSuccess>().having((s) => s.user.groupId, 'groupId', 'g20')),
    );
    expect(unsubscribed, ['sos_group_g10']);
    expect(subscribed, ['sos_group_g10', 'sos_group_g20']);
    await bloc.close();
  });
}

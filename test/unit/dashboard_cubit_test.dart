import 'dart:async';

import 'package:belajar_mabrur/data/repositories/sos_repository.dart';
import 'package:belajar_mabrur/logic/dashboard/dashboard_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeSosRepository implements SosRepository {
  final StreamController<List<Map<String, dynamic>>> controller =
      StreamController<List<Map<String, dynamic>>>.broadcast();

  @override
  Future<void> createReport({
    required String groupId,
    required String senderName,
    required double lat,
    required double lng,
  }) async {}

  @override
  Stream<List<Map<String, dynamic>>> watchReports(String groupId) =>
      controller.stream;
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test(
      'streams real-time SOS reports, handles errors, and filters cleared items',
      () async {
    final repo = _FakeSosRepository();
    final cubit = DashboardCubit(sosRepository: repo);

    await cubit.startWatchingSos('kloter_1');
    expect(cubit.state.isSosLoading, isTrue);

    final oldMillis = DateTime.now().millisecondsSinceEpoch - 60000;
    repo.controller.add([
      {
        'id': 'doc1',
        'name': 'Ahmad',
        'lat': 21.4225,
        'lng': 39.8262,
        'time': '10:00',
        'created_at_millis': oldMillis,
      },
    ]);
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(cubit.state.isSosLoading, isFalse);
    expect(cubit.state.sosError, isNull);
    expect(cubit.state.sosHistory.length, 1);
    expect(cubit.state.sosHistory.first['name'], 'Ahmad');

    repo.controller.addError(Exception('network down'));
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(cubit.state.sosError, isNotNull);
    expect(cubit.state.sosHistory.length, 1);

    await cubit.clearHistory();
    expect(cubit.state.sosHistory, isEmpty);

    final newerMillis = DateTime.now().millisecondsSinceEpoch + 5000;
    repo.controller.add([
      {
        'id': 'doc2',
        'name': 'Fatimah',
        'lat': 21.4230,
        'lng': 39.8265,
        'time': '10:05',
        'created_at_millis': newerMillis,
      },
      {
        'id': 'doc1',
        'name': 'Ahmad',
        'lat': 21.4225,
        'lng': 39.8262,
        'time': '10:00',
        'created_at_millis': oldMillis,
      },
    ]);
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(cubit.state.sosHistory.length, 1);
    expect(cubit.state.sosHistory.first['name'], 'Fatimah');

    await cubit.close();
    await repo.controller.close();
  });

  test('changeTab updates active tab index without dropping SOS history',
      () async {
    final repo = _FakeSosRepository();
    final cubit = DashboardCubit(sosRepository: repo);

    await cubit.addSosToHistory({
      'name': 'Budi',
      'lat': 21.42,
      'lng': 39.82,
      'time': '11:00',
    });
    cubit.changeTab(2);

    expect(cubit.state.tabIndex, 2);
    expect(cubit.state.sosHistory.length, 1);

    await cubit.close();
    await repo.controller.close();
  });

  test('handles pendingSosModal, resetOnLogout, and per-group cache isolation',
      () async {
    final repo = _FakeSosRepository();
    final cubit = DashboardCubit(sosRepository: repo);

    cubit.setPendingSosModal(lat: 21.4225, lng: 39.8262, senderName: 'Ali');
    expect(cubit.state.tabIndex, 1);
    expect(cubit.state.pendingSosModal?['name'], 'Ali');

    final consumed = cubit.consumePendingSosModal();
    expect(consumed?['name'], 'Ali');
    expect(cubit.state.pendingSosModal, isNull);

    await cubit.startWatchingSos('grup_a');
    repo.controller.add([
      {
        'id': 'a1',
        'name': 'Jamaah A',
        'lat': 21.42,
        'lng': 39.82,
        'time': '09:00',
        'created_at_millis': DateTime.now().millisecondsSinceEpoch,
      },
    ]);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(cubit.state.sosHistory.length, 1);

    cubit.changeTab(3);
    await cubit.resetOnLogout();
    expect(cubit.state.tabIndex, 0);
    expect(cubit.state.sosHistory, isEmpty);

    await cubit.startWatchingSos('grup_b');
    expect(cubit.state.sosHistory, isEmpty);

    await cubit.close();
    await repo.controller.close();
  });
}

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/repositories/sos_repository.dart';
import 'dashboard_state.dart';

class DashboardCubit extends Cubit<DashboardState> {
  final SosRepository _sosRepository;
  StreamSubscription<List<Map<String, dynamic>>>? _sosSubscription;
  String _activeGroupId = '';
  int _clearedBeforeMillis = 0;

  DashboardCubit({SosRepository? sosRepository})
      : _sosRepository = sosRepository ?? SosRepository(),
        super(const DashboardState(tabIndex: 0, sosHistory: []));

  String _historyKey(String groupId) => 'sos_history_$groupId';
  String _clearedBeforeKey(String groupId) => 'sos_cleared_before_$groupId';

  void changeTab(int index) {
    if (isClosed) return;
    emit(
      DashboardState(
        tabIndex: index,
        sosHistory: state.sosHistory,
        isSosLoading: state.isSosLoading,
        sosError: state.sosError,
        pendingSosModal: state.pendingSosModal,
      ),
    );
  }

  void setPendingSosModal({
    required double lat,
    required double lng,
    required String senderName,
  }) {
    if (isClosed) return;
    emit(
      DashboardState(
        tabIndex: 1,
        sosHistory: state.sosHistory,
        isSosLoading: state.isSosLoading,
        sosError: state.sosError,
        pendingSosModal: {
          'lat': lat,
          'lng': lng,
          'name': senderName,
        },
      ),
    );
  }

  Map<String, dynamic>? consumePendingSosModal() {
    final pending = state.pendingSosModal;
    if (pending == null) return null;
    if (!isClosed) {
      emit(
        DashboardState(
          tabIndex: state.tabIndex,
          sosHistory: state.sosHistory,
          isSosLoading: state.isSosLoading,
          sosError: state.sosError,
          pendingSosModal: null,
        ),
      );
    }
    return pending;
  }

  Future<List<Map<String, dynamic>>> _loadCachedHistory(String groupId) async {
    final prefs = await SharedPreferences.getInstance();
    _clearedBeforeMillis = prefs.getInt(_clearedBeforeKey(groupId)) ?? 0;

    final String? historyRaw = prefs.getString(_historyKey(groupId));
    if (historyRaw == null || historyRaw.isEmpty) return const [];

    try {
      final decoded = jsonDecode(historyRaw);
      if (decoded is! List) return const [];
      return decoded
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    } catch (_) {
      // Ignore corrupt local cache so app startup remains safe.
      return const [];
    }
  }

  Future<void> startWatchingSos(String groupId) async {
    await _sosSubscription?.cancel();
    _activeGroupId = groupId;
    final cached = await _loadCachedHistory(groupId);

    if (isClosed) return;
    emit(
      DashboardState(
        tabIndex: state.tabIndex,
        sosHistory: cached,
        isSosLoading: cached.isEmpty,
        sosError: null,
        pendingSosModal: state.pendingSosModal,
      ),
    );

    _sosSubscription = _sosRepository.watchReports(groupId).listen(
      (reports) async {
        final visible = reports.where((report) {
          final millis = report['created_at_millis'];
          if (millis is int && millis > 0 && millis <= _clearedBeforeMillis) {
            return false;
          }
          return true;
        }).toList();

        final storage = await SharedPreferences.getInstance();
        await storage.setString(_historyKey(groupId), jsonEncode(visible));

        if (isClosed) return;
        emit(
          DashboardState(
            tabIndex: state.tabIndex,
            sosHistory: visible,
            isSosLoading: false,
            sosError: null,
            pendingSosModal: state.pendingSosModal,
          ),
        );
      },
      onError: (Object error) {
        debugPrint('Stream SOS Firestore error: $error');
        if (isClosed) return;
        emit(
          DashboardState(
            tabIndex: state.tabIndex,
            sosHistory: state.sosHistory,
            isSosLoading: false,
            sosError:
                'Koneksi riwayat SOS terputus. Menampilkan data terakhir.',
            pendingSosModal: state.pendingSosModal,
          ),
        );
      },
    );
  }

  Future<void> stopWatchingSos() async {
    await _sosSubscription?.cancel();
    _sosSubscription = null;
    _activeGroupId = '';
    if (isClosed) return;
    emit(
      DashboardState(
        tabIndex: state.tabIndex,
        sosHistory: const [],
        isSosLoading: false,
        sosError: null,
        pendingSosModal: state.pendingSosModal,
      ),
    );
  }

  Future<void> resetOnLogout() async {
    await _sosSubscription?.cancel();
    _sosSubscription = null;
    _activeGroupId = '';
    _clearedBeforeMillis = 0;
    if (isClosed) return;
    emit(const DashboardState(tabIndex: 0, sosHistory: []));
  }

  Future<void> addSosToHistory(
    Map<String, dynamic> data, {
    String? groupId,
  }) async {
    final targetGroup = groupId ?? _activeGroupId;
    final updatedHistory = List<Map<String, dynamic>>.from(state.sosHistory);
    if (updatedHistory.isNotEmpty) {
      final latest = updatedHistory.first;
      final isDuplicate = latest['name'] == data['name'] &&
          latest['lat'] == data['lat'] &&
          latest['lng'] == data['lng'] &&
          latest['time'] == data['time'];
      if (isDuplicate) return;
    }
    updatedHistory.insert(0, data);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_historyKey(targetGroup), jsonEncode(updatedHistory));

    if (isClosed) return;
    emit(
      DashboardState(
        tabIndex: state.tabIndex,
        sosHistory: updatedHistory,
        isSosLoading: false,
        sosError: state.sosError,
        pendingSosModal: state.pendingSosModal,
      ),
    );
  }

  Future<void> clearHistory() async {
    // shortcut: clear hides reports locally by timestamp, add Firestore resolve status when multi-host sync is needed
    _clearedBeforeMillis = DateTime.now().millisecondsSinceEpoch;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_clearedBeforeKey(_activeGroupId), _clearedBeforeMillis);
    await prefs.remove(_historyKey(_activeGroupId));
    if (isClosed) return;
    emit(
      DashboardState(
        tabIndex: state.tabIndex,
        sosHistory: const [],
        isSosLoading: false,
        sosError: null,
        pendingSosModal: state.pendingSosModal,
      ),
    );
  }

  @override
  Future<void> close() async {
    await _sosSubscription?.cancel();
    return super.close();
  }
}

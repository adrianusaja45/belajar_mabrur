import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/repositories/sos_repository.dart';
import 'dashboard_state.dart';

class DashboardCubit extends Cubit<DashboardState> {
  static const String _historyKey = 'sos_history_list';
  static const String _clearedBeforeKey = 'sos_cleared_before_millis';

  final SosRepository _sosRepository;
  StreamSubscription<List<Map<String, dynamic>>>? _sosSubscription;
  int _clearedBeforeMillis = 0;

  DashboardCubit({SosRepository? sosRepository})
      : _sosRepository = sosRepository ?? SosRepository(),
        super(const DashboardState(tabIndex: 0, sosHistory: [])) {
    loadHistoryFromStorage();
  }

  void changeTab(int index) {
    if (isClosed) return;
    emit(
      DashboardState(
        tabIndex: index,
        sosHistory: state.sosHistory,
        isSosLoading: state.isSosLoading,
        sosError: state.sosError,
      ),
    );
  }

  Future<void> loadHistoryFromStorage() async {
    final prefs = await SharedPreferences.getInstance();
    _clearedBeforeMillis = prefs.getInt(_clearedBeforeKey) ?? 0;

    final String? historyRaw = prefs.getString(_historyKey);
    if (historyRaw == null || historyRaw.isEmpty) return;

    try {
      final decoded = jsonDecode(historyRaw);
      if (decoded is! List) return;
      final loadedHistory = decoded
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
      if (isClosed) return;
      emit(
        DashboardState(
          tabIndex: state.tabIndex,
          sosHistory: loadedHistory,
          isSosLoading: state.isSosLoading,
          sosError: state.sosError,
        ),
      );
    } catch (_) {
      // Ignore corrupt local cache so app startup remains safe.
    }
  }

  Future<void> startWatchingSos(String groupId) async {
    await _sosSubscription?.cancel();
    final prefs = await SharedPreferences.getInstance();
    _clearedBeforeMillis = prefs.getInt(_clearedBeforeKey) ?? 0;

    if (isClosed) return;
    emit(
      DashboardState(
        tabIndex: state.tabIndex,
        sosHistory: state.sosHistory,
        isSosLoading: state.sosHistory.isEmpty,
        sosError: null,
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
        await storage.setString(_historyKey, jsonEncode(visible));

        if (isClosed) return;
        emit(
          DashboardState(
            tabIndex: state.tabIndex,
            sosHistory: visible,
            isSosLoading: false,
            sosError: null,
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
          ),
        );
      },
    );
  }

  Future<void> stopWatchingSos() async {
    await _sosSubscription?.cancel();
    _sosSubscription = null;
  }

  Future<void> addSosToHistory(Map<String, dynamic> data) async {
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
    await prefs.setString(_historyKey, jsonEncode(updatedHistory));

    if (isClosed) return;
    emit(
      DashboardState(
        tabIndex: state.tabIndex,
        sosHistory: updatedHistory,
        isSosLoading: false,
        sosError: state.sosError,
      ),
    );
  }

  Future<void> clearHistory() async {
    // shortcut: clear hides reports locally by timestamp, add Firestore resolve status when multi-host sync is needed
    _clearedBeforeMillis = DateTime.now().millisecondsSinceEpoch;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_clearedBeforeKey, _clearedBeforeMillis);
    await prefs.remove(_historyKey);
    if (isClosed) return;
    emit(
      DashboardState(
        tabIndex: state.tabIndex,
        sosHistory: const [],
        isSosLoading: false,
        sosError: null,
      ),
    );
  }

  @override
  Future<void> close() async {
    await _sosSubscription?.cancel();
    return super.close();
  }
}

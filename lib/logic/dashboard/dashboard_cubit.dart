import 'dart:convert';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/repositories/sos_repository.dart';
import 'dashboard_state.dart';

class DashboardCubit extends Cubit<DashboardState> {
  final SosRepository _sosRepository;

  DashboardCubit({SosRepository? sosRepository})
      : _sosRepository = sosRepository ?? SosRepository(),
        super(DashboardState(tabIndex: 0, sosHistory: [])) {
    loadHistoryFromStorage();
  }

  void changeTab(int index) {
    if (isClosed) return;
    emit(DashboardState(tabIndex: index, sosHistory: state.sosHistory));
  }

  Future<void> loadHistoryFromStorage() async {
    final prefs = await SharedPreferences.getInstance();
    final String? historyRaw = prefs.getString('sos_history_list');
    if (historyRaw == null || historyRaw.isEmpty) return;

    try {
      final decoded = jsonDecode(historyRaw);
      if (decoded is! List) return;
      final loadedHistory = decoded
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
      if (isClosed) return;
      emit(DashboardState(tabIndex: state.tabIndex, sosHistory: loadedHistory));
    } catch (_) {
      // Ignore corrupt local cache so app startup remains safe.
    }
  }

  Future<void> loadHistoryFromFirestore(String groupId) async {
    final reports = await _sosRepository.getReports(groupId);
    final history = reports
        .map((report) =>
            Map<String, dynamic>.from(report)..remove('_created_at_millis'))
        .toList();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('sos_history_list', jsonEncode(history));

    if (isClosed) return;
    emit(DashboardState(tabIndex: state.tabIndex, sosHistory: history));
  }

  Future<void> addSosToHistory(Map<String, dynamic> data) async {
    final updatedHistory = List<Map<String, dynamic>>.from(state.sosHistory);
    updatedHistory.insert(0, data);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('sos_history_list', jsonEncode(updatedHistory));

    if (isClosed) return;
    emit(DashboardState(tabIndex: state.tabIndex, sosHistory: updatedHistory));
  }

  Future<void> clearHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('sos_history_list');
    if (isClosed) return;
    emit(DashboardState(tabIndex: state.tabIndex, sosHistory: []));
  }
}

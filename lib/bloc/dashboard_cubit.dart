import 'dart:convert';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DashboardState {
  final int tabIndex;
  final List<Map<String, dynamic>> sosHistory;
  DashboardState({required this.tabIndex, required this.sosHistory});
}

class DashboardCubit extends Cubit<DashboardState> {
  DashboardCubit() : super(DashboardState(tabIndex: 0, sosHistory: [])) {
    loadHistoryFromStorage();
  }

  void changeTab(int index) {
    emit(DashboardState(tabIndex: index, sosHistory: state.sosHistory));
  }

  Future<void> loadHistoryFromStorage() async {
    final prefs = await SharedPreferences.getInstance();
    final String? historyRaw = prefs.getString('sos_history_list');
    if (historyRaw != null) {
      final List<Map<String, dynamic>> loadedHistory = 
          List<Map<String, dynamic>>.from(jsonDecode(historyRaw));
      emit(DashboardState(tabIndex: state.tabIndex, sosHistory: loadedHistory));
    }
  }

  Future<void> addSosToHistory(Map<String, dynamic> data) async {
    final updatedHistory = List<Map<String, dynamic>>.from(state.sosHistory);
    updatedHistory.insert(0, data); // Tambah data baru di paling atas
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('sos_history_list', jsonEncode(updatedHistory));
    
    emit(DashboardState(tabIndex: state.tabIndex, sosHistory: updatedHistory));
  }

  // --- FITUR BARU: HAPUS RIWAYAT ---
  Future<void> clearHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('sos_history_list'); // Hapus dari memori HP
    emit(DashboardState(tabIndex: state.tabIndex, sosHistory: [])); // Kosongkan UI
  }
}
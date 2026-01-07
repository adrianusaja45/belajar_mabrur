import 'dart:convert';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dashboard_state.dart';

class DashboardCubit extends Cubit<DashboardState> {
  DashboardCubit() : super(DashboardState(tabIndex: 0, sosHistory: [])) {
    // Saat inisialisasi, langsung muat riwayat dari memori HP
    loadHistoryFromStorage();
  }

  /// Pindah Tab di BottomNavigationBar
  void changeTab(int index) {
    emit(DashboardState(tabIndex: index, sosHistory: state.sosHistory));
  }

  /// Memuat riwayat SOS dari SharedPreferences (Persistence)
  Future<void> loadHistoryFromStorage() async {
    final prefs = await SharedPreferences.getInstance();
    final String? historyRaw = prefs.getString('sos_history_list');
    if (historyRaw != null) {
      final List<Map<String, dynamic>> loadedHistory = 
          List<Map<String, dynamic>>.from(jsonDecode(historyRaw));
      emit(DashboardState(tabIndex: state.tabIndex, sosHistory: loadedHistory));
    }
  }

  /// Menambah item SOS baru ke list dan menyimpannya ke memori HP
  Future<void> addSosToHistory(Map<String, dynamic> data) async {
    final updatedHistory = List<Map<String, dynamic>>.from(state.sosHistory);
    updatedHistory.insert(0, data); // Insert di paling atas (terbaru)
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('sos_history_list', jsonEncode(updatedHistory));
    
    emit(DashboardState(tabIndex: state.tabIndex, sosHistory: updatedHistory));
  }

  /// Menghapus semua riwayat SOS dari aplikasi dan memori HP
  Future<void> clearHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('sos_history_list'); 
    emit(DashboardState(tabIndex: state.tabIndex, sosHistory: [])); 
  }
}
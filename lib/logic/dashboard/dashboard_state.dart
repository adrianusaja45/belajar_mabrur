/// State sederhana untuk Dashboard.
/// Menyimpan index tab yang aktif dan list riwayat SOS.
class DashboardState {
  final int tabIndex;
  final List<Map<String, dynamic>> sosHistory;
  
  DashboardState({required this.tabIndex, required this.sosHistory});
}
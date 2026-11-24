class DashboardState {
  final int tabIndex;
  final List<Map<String, dynamic>> sosHistory;
  final bool isSosLoading;
  final String? sosError;
  final Map<String, dynamic>? pendingSosModal;

  const DashboardState({
    required this.tabIndex,
    required this.sosHistory,
    this.isSosLoading = false,
    this.sosError,
    this.pendingSosModal,
  });
}

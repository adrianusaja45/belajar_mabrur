import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/services/location_services.dart';
import '../core/services/notification_service.dart';
import '../core/theme/app_theme.dart';
import '../data/repositories/auth_repository.dart';
import '../data/repositories/sos_repository.dart';
import '../logic/auth/auth_bloc.dart';
import '../logic/dashboard/dashboard_cubit.dart';
import '../logic/dashboard/dashboard_state.dart';

final GlobalKey<MapSosTabState> mapSosKey = GlobalKey<MapSosTabState>();

class MapSosTab extends StatefulWidget {
  MapSosTab({Key? key}) : super(key: key ?? mapSosKey);

  @override
  MapSosTabState createState() => MapSosTabState();
}

class MapSosTabState extends State<MapSosTab> {
  final LocationService _locationService = LocationService();
  final NotificationService _notifService = NotificationService();

  final Completer<GoogleMapController> _controller = Completer();
  final Set<Marker> _markers = {};

  String _userRole = 'user';
  bool _isLoading = false;
  bool _isResetting = false;

  @override
  void initState() {
    super.initState();
    _loadUserRole();
    _initPosition();
  }

  Future<void> _loadUserRole() async {
    final authBlocState = context.read<AuthBloc>().state;
    final authRepository = context.read<AuthRepository>();
    final dashboardCubit = context.read<DashboardCubit>();

    String role;
    String groupId;
    if (authBlocState is AuthSuccess) {
      role = authBlocState.user.role;
      groupId = authBlocState.user.groupId;
    } else {
      final prefs = await SharedPreferences.getInstance();
      role = prefs.getString('user_role') ?? 'user';
      groupId = await authRepository.getGroupId();
    }

    if (mounted) setState(() => _userRole = role);

    if (role == 'host' && mounted) {
      try {
        await dashboardCubit.loadHistoryFromFirestore(groupId);
      } catch (e) {
        debugPrint('Gagal memuat riwayat SOS dari Firestore: $e');
      }
    }
  }

  Future<void> _initPosition() async {
    try {
      final position = await _locationService.getCurrentPosition();
      if (position != null && mounted) {
        await _updateMapLocation(position.latitude, position.longitude);
      }
    } catch (e) {
      debugPrint("Gagal init lokasi: $e");
    }
  }

  Future<void> _updateMapLocation(double lat, double lng) async {
    if (!mounted) return;
    final LatLng newPos = LatLng(lat, lng);
    setState(() {
      _markers.removeWhere((m) => m.markerId.value == 'my_loc');

      _markers.add(
        Marker(
          markerId: const MarkerId('my_loc'),
          position: newPos,
          infoWindow: const InfoWindow(title: 'Lokasi Saya'),
          icon:
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
        ),
      );
    });
    final controller = await _controller.future;
    controller.animateCamera(CameraUpdate.newLatLngZoom(newPos, 15.0));
  }

  Future<void> _resetToMyLocation() async {
    setState(() => _isResetting = true);
    try {
      final position = await _locationService.getCurrentPosition();
      if (position != null) {
        await _updateMapLocation(position.latitude, position.longitude);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Gagal mendapatkan lokasi terkini."),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isResetting = false);
    }
  }

  Future<void> _sendSOS() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final authState = context.read<AuthBloc>().state;
      final authRepository = context.read<AuthRepository>();
      final sosRepository = context.read<SosRepository>();
      final dashboardCubit = context.read<DashboardCubit>();

      final user = authState is AuthSuccess
          ? authState.user
          : await authRepository.getCachedUser();
      final String senderName =
          (user != null && user.name.isNotEmpty) ? user.name : "Seseorang";
      final String groupId = user?.groupId ?? await authRepository.getGroupId();

      final position = await _locationService.getCurrentPosition();
      if (position == null) {
        throw Exception("Lokasi tidak ditemukan. Pastikan GPS aktif.");
      }

      final String timeStamp = DateTime.now().toString().substring(11, 16);
      await dashboardCubit.addSosToHistory({
        'lat': position.latitude,
        'lng': position.longitude,
        'time': timeStamp,
        'name': senderName,
      });

      // Firestore failure must not block the emergency FCM broadcast.
      Object? firestoreError;
      try {
        await sosRepository.createReport(
          groupId: groupId,
          senderName: senderName,
          lat: position.latitude,
          lng: position.longitude,
        );
      } catch (e) {
        firestoreError = e;
        debugPrint("Gagal menyimpan riwayat SOS ke Firestore: $e");
      }

      Object? fcmError;
      try {
        await _notifService.sendSOS(
          senderName: senderName,
          groupId: groupId,
          lat: position.latitude,
          lng: position.longitude,
        );
      } catch (e) {
        fcmError = e;
        debugPrint("Gagal mengirim notifikasi FCM SOS: $e");
      }

      if (!mounted) return;
      if (fcmError != null && firestoreError != null) {
        throw Exception("SOS gagal terkirim. Periksa koneksi internet Anda.");
      }

      final String feedbackMessage;
      final Color feedbackColor;
      if (fcmError == null && firestoreError == null) {
        feedbackMessage = "SOS Berhasil Terkirim!";
        feedbackColor = AppColors.success;
      } else if (fcmError == null) {
        feedbackMessage =
            "SOS terkirim ke pembimbing, namun riwayat cloud gagal tersimpan.";
        feedbackColor = AppColors.warning;
      } else {
        feedbackMessage =
            "Riwayat SOS tersimpan, namun notifikasi darurat gagal terkirim.";
        feedbackColor = AppColors.warning;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(feedbackMessage),
          backgroundColor: feedbackColor,
        ),
      );
    } catch (e) {
      debugPrint("Gagal kirim SOS: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Gagal: $e"),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void showSOSModal(double lat, double lng, String senderName) {
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) => SafeArea(
        child: Container(
          decoration: const BoxDecoration(
            color: AppColors.background,
            borderRadius:
                BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
          ),
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.borderChip,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              const Icon(
                Icons.warning_amber_rounded,
                size: 56,
                color: AppColors.error,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                "${senderName.toUpperCase()} BUTUH BANTUAN!",
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.error,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                "Lokasi: $lat, $lng",
                style: const TextStyle(color: AppColors.textPrimary),
              ),
              const SizedBox(height: AppSpacing.xxl),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.textOnPrimary,
                  minimumSize: const Size(double.infinity, 52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                ),
                onPressed: () {
                  Navigator.pop(context);
                  _goToSOSLocation(lat, lng, senderName);
                },
                icon: const Icon(Icons.directions),
                label: const Text("Tuju Lokasi Darurat"),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _goToSOSLocation(
    double lat,
    double lng,
    String senderName,
  ) async {
    final LatLng sosPos = LatLng(lat, lng);
    setState(() {
      _markers.add(
        Marker(
          markerId: MarkerId('sos_${DateTime.now().millisecondsSinceEpoch}'),
          position: sosPos,
          infoWindow: InfoWindow(title: "SOS: $senderName"),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        ),
      );
    });
    final controller = await _controller.future;
    controller.animateCamera(CameraUpdate.newLatLngZoom(sosPos, 17.0));
  }

  void _confirmClearHistory(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text("Hapus Riwayat?"),
        content: const Text("Semua data SOS akan dihapus dari perangkat ini."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text(
              "Batal",
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () {
              context.read<DashboardCubit>().clearHistory();
              Navigator.pop(dialogContext);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("Riwayat berhasil dihapus."),
                  backgroundColor: AppColors.success,
                ),
              );
            },
            child: const Text(
              "HAPUS",
              style: TextStyle(
                color: AppColors.error,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          RepaintBoundary(
            child: GoogleMap(
              initialCameraPosition: const CameraPosition(
                target: LatLng(-6.175, 106.82),
                zoom: 12,
              ),
              markers: _markers,
              myLocationEnabled: true,
              myLocationButtonEnabled: false,
              zoomControlsEnabled: false,
              buildingsEnabled: false,
              indoorViewEnabled: false,
              tiltGesturesEnabled: false,
              onMapCreated: (c) => _controller.complete(c),
            ),
          ),
          if (_userRole == 'host') _buildHostSosPanel(),
          if (_userRole != 'host')
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.xl,
                    0,
                    AppSpacing.xl,
                    AppSpacing.xl,
                  ),
                  child: _buildUserSosButton(),
                ),
              ),
            ),
          SafeArea(
            child: Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: FloatingActionButton(
                  heroTag: "btnReset",
                  tooltip: 'Pusatkan ke lokasi saya',
                  backgroundColor: AppColors.background,
                  foregroundColor: AppColors.primary,
                  onPressed: _isResetting ? null : _resetToMyLocation,
                  child: _isResetting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.primary,
                          ),
                        )
                      : const Icon(Icons.my_location),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserSosButton() {
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.textOnPrimary,
        minimumSize: const Size(double.infinity, 60),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.full),
        ),
      ),
      onPressed: _isLoading ? null : _sendSOS,
      icon: _isLoading
          ? const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                color: AppColors.textOnPrimary,
                strokeWidth: 2.5,
              ),
            )
          : const Icon(
              Icons.sos,
              size: 32,
              color: AppColors.textOnPrimary,
            ),
      label: Text(
        _isLoading ? "MENGIRIM..." : "TEKAN UNTUK SOS",
        style: const TextStyle(
          color: AppColors.textOnPrimary,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildHostSosPanel() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double maxHeight =
            constraints.maxHeight > 0 ? constraints.maxHeight : 700;
        // Match collapsed height to handle + header so the first list item never clips in half.
        final double collapsedSize = (74 / maxHeight).clamp(0.09, 0.22);
        final double midSize = collapsedSize < 0.45 ? 0.48 : 0.60;

        return DraggableScrollableSheet(
          initialChildSize: collapsedSize,
          minChildSize: collapsedSize,
          maxChildSize: 0.8,
          snap: true,
          snapSizes: [collapsedSize, midSize, 0.8],
          builder: (context, scrollController) {
            return BlocSelector<DashboardCubit, DashboardState,
                List<Map<String, dynamic>>>(
              selector: (state) => state.sosHistory,
              builder: (context, history) {
                return Material(
                  color: AppColors.background,
                  elevation: 8,
                  shadowColor: Colors.black26,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(AppRadius.lg),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: SafeArea(
                    top: false,
                    child: ListView(
                      controller: scrollController,
                      padding: EdgeInsets.zero,
                      children: [
                        const SizedBox(height: AppSpacing.md),
                        Center(
                          child: Container(
                            width: 40,
                            height: 4,
                            decoration: BoxDecoration(
                              color: AppColors.borderChip,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.xl,
                            vertical: 6,
                          ),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(minHeight: 44),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  "Riwayat SOS",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                if (history.isNotEmpty)
                                  TextButton.icon(
                                    style: TextButton.styleFrom(
                                      foregroundColor: AppColors.error,
                                      minimumSize: const Size(48, 44),
                                      tapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                    ),
                                    onPressed: () =>
                                        _confirmClearHistory(context),
                                    icon: const Icon(Icons.delete_outline,
                                        size: 20),
                                    label: const Text(
                                      "Hapus",
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        const Divider(height: 1, color: AppColors.borderSubtle),
                        const SizedBox(height: AppSpacing.sm),
                        if (history.isEmpty)
                          const SizedBox(
                            height: 180,
                            child: Center(
                              child: Text(
                                "Belum ada laporan masuk.",
                                style:
                                    TextStyle(color: AppColors.textSecondary),
                              ),
                            ),
                          )
                        else
                          ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: history.length,
                            separatorBuilder: (context, index) =>
                                const Divider(color: AppColors.borderSubtle),
                            itemBuilder: (context, index) {
                              final data = history[index];
                              final sender =
                                  data['name']?.toString() ?? "Seseorang";
                              return ListTile(
                                minTileHeight: 56,
                                leading: const CircleAvatar(
                                  backgroundColor: AppColors.error,
                                  child: Icon(
                                    Icons.emergency,
                                    color: AppColors.textOnPrimary,
                                  ),
                                ),
                                title: Text(
                                  "$sender - ${data['time']}",
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                subtitle: Text(
                                  "Lokasi: ${data['lat']}, ${data['lng']}",
                                  style: const TextStyle(
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                                onTap: () {
                                  final lat =
                                      double.tryParse(data['lat'].toString());
                                  final lng =
                                      double.tryParse(data['lng'].toString());
                                  if (lat != null && lng != null) {
                                    _goToSOSLocation(lat, lng, sender);
                                  }
                                },
                              );
                            },
                          ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

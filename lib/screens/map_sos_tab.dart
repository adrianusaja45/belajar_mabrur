import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/repositories/auth_repository.dart';
import '../data/repositories/sos_repository.dart';
import '../logic/auth/auth_bloc.dart';
import '../logic/dashboard/dashboard_cubit.dart';
import '../core/services/location_services.dart';
import '../core/services/notification_service.dart';
import '../core/constants.dart'; // IMPORT CONSTANTS

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

      _markers.add(Marker(
        markerId: const MarkerId('my_loc'),
        position: newPos,
        infoWindow: const InfoWindow(title: 'Lokasi Saya'),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
      ));
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
          const SnackBar(content: Text("Gagal mendapatkan lokasi terkini.")),
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
      if (fcmError == null && firestoreError == null) {
        feedbackMessage = "SOS Berhasil Terkirim!";
      } else if (fcmError == null) {
        feedbackMessage =
            "SOS terkirim ke pembimbing, namun riwayat cloud gagal tersimpan.";
      } else {
        feedbackMessage =
            "Riwayat SOS tersimpan, namun notifikasi darurat gagal terkirim.";
      }

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(feedbackMessage)));
    } catch (e) {
      debugPrint("Gagal kirim SOS: $e");
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Gagal: $e")));
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
              color: AppConstants.backgroundColor, // CONSTANT
              borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                  width: 50,
                  height: 5,
                  decoration: BoxDecoration(
                      color: AppConstants.textSecondary.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(10))),
              const SizedBox(height: 20),
              const Icon(Icons.warning_amber_rounded,
                  size: 60, color: AppConstants.errorColor), // CONSTANT
              Text("${senderName.toUpperCase()} BUTUH BANTUAN!",
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppConstants.errorColor) // CONSTANT
                  ),
              const SizedBox(height: 10),
              Text("Lokasi: $lat, $lng",
                  style: const TextStyle(
                      color: AppConstants.textPrimary)), // CONSTANT
              const SizedBox(height: 30),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppConstants.primaryColor, // CONSTANT
                    foregroundColor: AppConstants.textWhite, // CONSTANT
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15))),
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
      double lat, double lng, String senderName) async {
    final LatLng sosPos = LatLng(lat, lng);
    setState(() {
      _markers.add(Marker(
          markerId: MarkerId('sos_${DateTime.now().millisecondsSinceEpoch}'),
          position: sosPos,
          infoWindow: InfoWindow(title: "SOS: $senderName"),
          icon:
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed)));
    });
    final controller = await _controller.future;
    controller.animateCamera(CameraUpdate.newLatLngZoom(sosPos, 17.0));
  }

  void _confirmClearHistory(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Hapus Riwayat?"),
        content: const Text("Semua data SOS akan dihapus dari perangkat ini."),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Batal")),
          TextButton(
            onPressed: () {
              context.read<DashboardCubit>().clearHistory();
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Riwayat berhasil dihapus.")));
            },
            child: const Text("HAPUS",
                style: TextStyle(
                    color: AppConstants.errorColor,
                    fontWeight: FontWeight.bold)), // CONSTANT
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
          GoogleMap(
              initialCameraPosition: const CameraPosition(
                  target: LatLng(-6.175, 106.82), zoom: 12),
              markers: _markers,
              myLocationEnabled: true,
              myLocationButtonEnabled: false,
              zoomControlsEnabled: false,
              onMapCreated: (c) => _controller.complete(c)),

          if (_userRole == 'host') _buildHostSosPanel(),
          if (_userRole != 'host')
            Positioned(
                bottom: 30, left: 20, right: 20, child: _buildUserSosButton()),

          // --- TOMBOL RESET POSISI ---
          Positioned(
            top: 50,
            right: 20,
            child: FloatingActionButton(
              heroTag: "btnReset",
              mini: true,
              backgroundColor: AppConstants.backgroundColor, // CONSTANT
              foregroundColor: AppConstants.primaryColor, // CONSTANT
              onPressed: _isResetting ? null : _resetToMyLocation,
              child: _isResetting
                  ? const SizedBox(
                      width: 15,
                      height: 15,
                      child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppConstants.primaryColor)) // CONSTANT
                  : const Icon(Icons.my_location),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserSosButton() {
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
          backgroundColor: AppConstants.primaryColor, // CONSTANT
          minimumSize: const Size(double.infinity, 65),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(35))),
      onPressed: _isLoading ? null : _sendSOS,
      icon: _isLoading
          ? const CircularProgressIndicator(
              color: AppConstants.textWhite) // CONSTANT
          : const Icon(Icons.sos,
              size: 35, color: AppConstants.textWhite), // CONSTANT
      label: Text(_isLoading ? "MENGIRIM..." : "TEKAN UNTUK SOS",
          style: const TextStyle(
              color: AppConstants.textWhite,
              fontSize: 20,
              fontWeight: FontWeight.bold) // CONSTANT
          ),
    );
  }

  Widget _buildHostSosPanel() {
    final history = context.watch<DashboardCubit>().state.sosHistory;

    return DraggableScrollableSheet(
      initialChildSize: 0.12,
      minChildSize: 0.12,
      maxChildSize: 0.8,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
              color: AppConstants.backgroundColor, // CONSTANT
              borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
              boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 10)]),
          child: ListView(
            controller: scrollController,
            padding: EdgeInsets.zero,
            children: [
              const SizedBox(height: 12),
              Center(
                  child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                          color:
                              AppConstants.textSecondary.withValues(alpha: 0.3),
                          borderRadius:
                              BorderRadius.circular(10)))), // CONSTANT

              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("Riwayat SOS",
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16)),
                    if (history.isNotEmpty)
                      InkWell(
                        onTap: () => _confirmClearHistory(context),
                        child: const Row(
                          children: [
                            Icon(Icons.delete_outline,
                                color: AppConstants.errorColor,
                                size: 20), // CONSTANT
                            SizedBox(width: 4),
                            Text("Hapus",
                                style: TextStyle(
                                    color: AppConstants.errorColor,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12)), // CONSTANT
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              const Divider(height: 1),

              if (history.isEmpty)
                const SizedBox(
                    height: 200,
                    child: Center(
                        child: Text("Belum ada laporan masuk.",
                            style: TextStyle(
                                color:
                                    AppConstants.textSecondary)))) // CONSTANT
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: history.length,
                  separatorBuilder: (context, index) => const Divider(),
                  itemBuilder: (context, index) {
                    final data = history[index];
                    String sender = data['name'] ?? "Seseorang";
                    return ListTile(
                      leading: const CircleAvatar(
                          backgroundColor: AppConstants.errorColor,
                          child: Icon(Icons.emergency,
                              color: AppConstants.textWhite)), // CONSTANT
                      title: Text("$sender - ${data['time']}",
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text("Lokasi: ${data['lat']}, ${data['lng']}"),
                      onTap: () {
                        final lat = double.tryParse(data['lat'].toString());
                        final lng = double.tryParse(data['lng'].toString());
                        if (lat != null && lng != null) {
                          _goToSOSLocation(lat, lng, sender);
                        }
                      },
                    );
                  },
                ),
            ],
          ),
        );
      },
    );
  }
}

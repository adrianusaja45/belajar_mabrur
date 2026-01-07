import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

// --- IMPORT LOGIC & SERVICES (Clean Architecture) ---
import '../data/repositories/auth_repository.dart';
import '../logic/dashboard/dashboard_cubit.dart';
import '../core/services/location_services.dart'; // Pastikan path ini benar (location_service.dart bukan services.dart)
import '../core/services/notification_service.dart'; 

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
  
  // Set marker ini akan menampung banyak titik sekaligus
  final Set<Marker> _markers = {};
  
  String _userRole = 'user';
  bool _isLoading = false;
  bool _isResetting = false; 

  @override
  void initState() {
    super.initState();
    _loadUserRole();
    _initHostPosition(); // Ubah nama fungsi biar jelas
  }

  Future<void> _loadUserRole() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) setState(() => _userRole = prefs.getString('user_role') ?? 'user');
  }

  // 1. UPDATE POSISI HOST (TITIK BIRU)
  // Fungsi ini hanya mengupdate marker "my_loc" tanpa menghapus marker SOS
  Future<void> _initHostPosition() async {
    try {
      final position = await _locationService.getCurrentPosition();
      if (position != null && mounted) {
        final LatLng hostPos = LatLng(position.latitude, position.longitude);
        
        setState(() {
          // Hapus marker lokasi lama (host) agar tidak duplikat
          _markers.removeWhere((m) => m.markerId.value == 'my_loc');
          
          // Tambahkan marker host baru
          _markers.add(Marker(
            markerId: const MarkerId('my_loc'), 
            position: hostPos, 
            infoWindow: const InfoWindow(title: 'Posisi Saya (Host)'),
            // Warna Biru (Azure) untuk membedakan dengan SOS (Merah)
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
          ));
        });

        // Awal buka aplikasi, arahkan kamera ke Host
        final controller = await _controller.future;
        controller.animateCamera(CameraUpdate.newLatLngZoom(hostPos, 15.0));
      }
    } catch (e) {
      debugPrint("Gagal init lokasi: $e");
    }
  }

  // --- FITUR RESET POSISI ---
  Future<void> _resetToMyLocation() async {
    setState(() => _isResetting = true);
    try {
      final position = await _locationService.getCurrentPosition();
      if (position != null) {
        final LatLng hostPos = LatLng(position.latitude, position.longitude);
        
        setState(() {
          _markers.removeWhere((m) => m.markerId.value == 'my_loc');
          _markers.add(Marker(
            markerId: const MarkerId('my_loc'), 
            position: hostPos, 
            infoWindow: const InfoWindow(title: 'Posisi Saya'),
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
          ));
        });

        // Kembalikan kamera ke Host
        final controller = await _controller.future;
        controller.animateCamera(CameraUpdate.newLatLngZoom(hostPos, 15.0));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Gagal mendapatkan lokasi terkini.")));
    } finally {
      if (mounted) setState(() => _isResetting = false);
    }
  }

  // --- FITUR KIRIM SOS ---
  Future<void> _sendSOS() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    
    try {
      final userProfile = await context.read<AuthRepository>().getProfile();
      final String senderName = userProfile['name'] ?? "Seseorang";
      final String groupId = userProfile['group_id']?.toString() ?? 'default';

      final position = await _locationService.getCurrentPosition();
      if (position == null) throw Exception("Lokasi tidak ditemukan. Pastikan GPS aktif.");

      await _notifService.sendSOS(
        senderName: senderName,
        groupId: groupId,
        lat: position.latitude,
        lng: position.longitude,
      );

      if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("SOS Berhasil Terkirim!")));
    } catch (e) {
      debugPrint("Gagal kirim SOS: $e");
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Gagal: $e")));
    } finally {
      if(mounted) setState(() => _isLoading = false);
    }
  }

  // --- MODAL POPUP SOS ---
  void showSOSModal(double lat, double lng, String senderName) {
    if (!mounted) return;
    showModalBottomSheet(
      context: context, isScrollControlled: true, useSafeArea: true, backgroundColor: Colors.transparent,
      builder: (context) => SafeArea(
        child: Container(
          decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 50, height: 5, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10))),
              const SizedBox(height: 20),
              const Icon(Icons.warning_amber_rounded, size: 60, color: Colors.red),
              Text(
                "${senderName.toUpperCase()} BUTUH BANTUAN!", 
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.red)
              ),
              const SizedBox(height: 10),
              Text("Lokasi: $lat, $lng", style: const TextStyle(color: Colors.black54)),
              const SizedBox(height: 30),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFA01C1C), 
                  foregroundColor: Colors.white, 
                  minimumSize: const Size(double.infinity, 50), 
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))
                ),
                onPressed: () { Navigator.pop(context); _goToSOSLocation(lat, lng, senderName); },
                icon: const Icon(Icons.directions),
                label: const Text("Tuju Lokasi Darurat"),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 2. UPDATE POSISI SOS (TITIK MERAH)
  // Fungsi ini dipanggil saat klik notifikasi atau riwayat
  Future<void> _goToSOSLocation(double lat, double lng, String senderName) async {
    final LatLng sosPos = LatLng(lat, lng);
    
    setState(() {
      // Kita HANYA menghapus marker SOS lama (jika ada), marker 'my_loc' BIARKAN SAJA
      _markers.removeWhere((m) => m.markerId.value == 'sos_target');
      
      // Tambah marker SOS baru (Merah)
      _markers.add(Marker(
        markerId: const MarkerId('sos_target'), 
        position: sosPos, 
        infoWindow: InfoWindow(title: "SOS: $senderName", snippet: "Butuh Bantuan!"),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed) // Merah
      ));
    });

    final controller = await _controller.future;
    
    // Arahkan kamera fokus ke SOS, tapi Host tetap ada di peta (jika dalam radius zoom)
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
            child: const Text("Batal")
          ),
          TextButton(
            onPressed: () {
              context.read<DashboardCubit>().clearHistory();
              Navigator.pop(context);
              
              // Opsional: Hapus marker SOS dari peta juga saat riwayat dihapus
              setState(() {
                _markers.removeWhere((m) => m.markerId.value == 'sos_target');
              });

              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Riwayat berhasil dihapus."))
              );
            },
            child: const Text("HAPUS", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
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
            initialCameraPosition: const CameraPosition(target: LatLng(-6.175, 106.82), zoom: 12), 
            markers: _markers, // Variable ini sekarang bisa berisi 2 marker
            myLocationEnabled: true, 
            myLocationButtonEnabled: false, 
            zoomControlsEnabled: false, 
            onMapCreated: (c) => _controller.complete(c)
          ),
          
          if (_userRole == 'host') _buildHostSosPanel(),
          if (_userRole != 'host') Positioned(bottom: 30, left: 20, right: 20, child: _buildUserSosButton()),
          
          // Tombol Reset ke Lokasi Saya
          Positioned(
            top: 50, right: 20,
            child: FloatingActionButton(
              heroTag: "btnReset",
              mini: true,
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFFA01C1C),
              onPressed: _isResetting ? null : _resetToMyLocation,
              child: _isResetting 
                  ? const SizedBox(width: 15, height: 15, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFA01C1C)))
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
        backgroundColor: const Color(0xFFA01C1C), 
        minimumSize: const Size(double.infinity, 65), 
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(35))
      ),
      onPressed: _isLoading ? null : _sendSOS,
      icon: _isLoading 
          ? const CircularProgressIndicator(color: Colors.white) 
          : const Icon(Icons.sos, size: 35, color: Colors.white),
      label: Text(
        _isLoading ? "MENGIRIM..." : "TEKAN UNTUK SOS", 
        style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)
      ),
    );
  }

  Widget _buildHostSosPanel() {
    final history = context.watch<DashboardCubit>().state.sosHistory;
    
    return DraggableScrollableSheet(
      initialChildSize: 0.12, minChildSize: 0.12, maxChildSize: 0.8,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(25)), boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 10)]),
          child: ListView(
            controller: scrollController,
            padding: EdgeInsets.zero,
            children: [
              const SizedBox(height: 12),
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10)))),
              
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "Riwayat SOS", 
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)
                    ),
                    if (history.isNotEmpty)
                      InkWell(
                        onTap: () => _confirmClearHistory(context),
                        child: const Row(
                          children: [
                            Icon(Icons.delete_outline, color: Colors.red, size: 20),
                            SizedBox(width: 4),
                            Text("Hapus", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 12)),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              const Divider(height: 1),
              
              if (history.isEmpty)
                const SizedBox(height: 200, child: Center(child: Text("Belum ada laporan masuk.", style: TextStyle(color: Colors.grey))))
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
                      leading: const CircleAvatar(backgroundColor: Colors.red, child: Icon(Icons.emergency, color: Colors.white)),
                      title: Text("$sender - ${data['time']}", style: const TextStyle(fontWeight: FontWeight.bold)), 
                      subtitle: Text("Lokasi: ${data['lat']}, ${data['lng']}"),
                      onTap: () => _goToSOSLocation(double.parse(data['lat'].toString()), double.parse(data['lng'].toString()), sender),
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
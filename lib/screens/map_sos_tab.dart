import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/api_exception.dart';
import '../core/services/location_services.dart';
import '../core/services/notification_service.dart';
import '../core/theme/app_theme.dart';
import '../data/models/user_model.dart';
import '../data/repositories/auth_repository.dart';
import '../data/repositories/sos_repository.dart';
import '../logic/auth/auth_bloc.dart';
import '../logic/dashboard/dashboard_cubit.dart';
import '../logic/dashboard/dashboard_state.dart';

class MapSosTab extends StatefulWidget {
  final Widget? mapOverride;
  final bool loadInitialLocation;

  const MapSosTab({
    super.key,
    this.mapOverride,
    this.loadInitialLocation = true,
  });

  @override
  MapSosTabState createState() => MapSosTabState();
}

class MapSosTabState extends State<MapSosTab> {
  final LocationService _locationService = LocationService();
  final NotificationService _notifService = NotificationService();

  final Completer<GoogleMapController> _controller = Completer();
  final Set<Marker> _markers = {};

  String _userRole = 'user';
  String _groupId = '';
  bool _isLoading = false;
  bool _isResetting = false;

  bool get _hasGroup => UserModel.normalizeGroupId(_groupId).isNotEmpty;

  @override
  void initState() {
    super.initState();
    _loadUserRole();
    if (widget.loadInitialLocation) {
      _initPosition();
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _consumePendingSos();
    });
  }

  void _consumePendingSos() {
    if (!mounted) return;
    final pending = context.read<DashboardCubit>().consumePendingSosModal();
    if (pending == null) return;
    final lat = double.tryParse(pending['lat']?.toString() ?? '');
    final lng = double.tryParse(pending['lng']?.toString() ?? '');
    if (lat != null && lng != null) {
      showSOSModal(lat, lng, pending['name']?.toString() ?? 'Seseorang');
    }
  }

  Future<void> _loadUserRole() async {
    final authBlocState = context.read<AuthBloc>().state;
    final authRepository = context.read<AuthRepository>();

    String role;
    String groupId;
    if (authBlocState is AuthSuccess) {
      role = authBlocState.user.role;
      groupId = authBlocState.user.groupId;
    } else {
      final cached = await authRepository.getCachedUser();
      role = cached?.role ?? 'user';
      groupId = cached?.groupId ?? await authRepository.getGroupId();
    }

    await _applyUserContext(role, groupId);
  }

  Future<void> _applyUserContext(String role, String rawGroupId) async {
    final normalizedGroup = UserModel.normalizeGroupId(rawGroupId);
    if (mounted) {
      setState(() {
        _userRole = role;
        _groupId = normalizedGroup;
      });
    }

    if (!mounted) return;
    final dashboardCubit = context.read<DashboardCubit>();
    if (role == 'host' && normalizedGroup.isNotEmpty) {
      await dashboardCubit.startWatchingSos(normalizedGroup);
    } else {
      await dashboardCubit.stopWatchingSos();
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
    if (!mounted) return;
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

  Future<void> _confirmAndSendSOS() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Kirim Sinyal Darurat?'),
        content: const Text(
          'Lokasi GPS Anda saat ini akan dikirim ke pembimbing grup untuk meminta bantuan segera.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text(
              'Batal',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: AppColors.textOnPrimary,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Ya, Kirim SOS'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await _sendSOS();
    }
  }

  Future<void> _openGoogleMapsRoute(double lat, double lng) async {
    final uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng',
    );
    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (launched) return;
      final fallback = await launchUrl(
        uri,
        mode: LaunchMode.platformDefault,
      );
      if (!fallback && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tidak dapat membuka Google Maps di perangkat ini.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } catch (e) {
      debugPrint('Gagal membuka rute Google Maps: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tidak dapat membuka Google Maps di perangkat ini.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
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
      final String groupId = UserModel.normalizeGroupId(
        user?.groupId ?? await authRepository.getGroupId(),
      );
      if (groupId.isEmpty) {
        throw const ApiException(
          "Anda belum terdaftar dalam grup. Hubungi pembimbing atau admin.",
        );
      }

      final position = await _locationService.getCurrentPosition();
      if (position == null) {
        throw const ApiException("Lokasi tidak ditemukan. Pastikan GPS aktif.");
      }

      final String timeStamp = DateTime.now().toString().substring(11, 16);
      await dashboardCubit.addSosToHistory(
        {
          'lat': position.latitude,
          'lng': position.longitude,
          'time': timeStamp,
          'name': senderName,
        },
        groupId: groupId,
      );

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
        throw const ApiException(
          "SOS gagal terkirim. Periksa koneksi internet Anda.",
        );
      }

      final String feedbackMessage;
      final Color feedbackColor;
      if (fcmError == null && firestoreError == null) {
        feedbackMessage = "Sinyal SOS berhasil terkirim.";
        feedbackColor = AppColors.success;
      } else if (fcmError == null) {
        feedbackMessage =
            "Sinyal SOS terkirim ke pembimbing, namun riwayat server gagal tersimpan.";
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
        final message = e is ApiException
            ? e.message
            : "Gagal mengirim sinyal SOS. Silakan coba lagi.";
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
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
                "$senderName membutuhkan bantuan",
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.error,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                "Koordinat: ${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}",
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
                  _openGoogleMapsRoute(lat, lng);
                },
                icon: const Icon(Icons.directions),
                label: const Text("Buka Rute Google Maps"),
              ),
              const SizedBox(height: AppSpacing.md),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary),
                  minimumSize: const Size(double.infinity, 48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                ),
                onPressed: () {
                  Navigator.pop(context);
                  _goToSOSLocation(lat, lng, senderName);
                },
                icon: const Icon(Icons.location_searching),
                label: const Text("Lihat di Peta"),
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
    if (!mounted) return;
    final LatLng sosPos = LatLng(lat, lng);
    setState(() {
      _markers.removeWhere((m) => m.markerId.value == 'active_sos');
      _markers.add(
        Marker(
          markerId: const MarkerId('active_sos'),
          position: sosPos,
          infoWindow: InfoWindow(title: "SOS: $senderName"),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        ),
      );
    });
    final controller = await _controller.future;
    if (!mounted) return;
    controller.animateCamera(CameraUpdate.newLatLngZoom(sosPos, 17.0));
  }

  void _confirmClearHistory(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text("Hapus Riwayat SOS?"),
        content: const Text(
          "Riwayat SOS di perangkat ini akan disembunyikan. Laporan darurat baru tetap masuk secara otomatis.",
        ),
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
                  content: Text("Riwayat SOS berhasil dibersihkan."),
                  backgroundColor: AppColors.success,
                ),
              );
            },
            child: const Text(
              "Hapus Riwayat",
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
    return MultiBlocListener(
      listeners: [
        BlocListener<DashboardCubit, DashboardState>(
          listenWhen: (previous, current) =>
              current.pendingSosModal != null &&
              current.pendingSosModal != previous.pendingSosModal,
          listener: (_, __) => _consumePendingSos(),
        ),
        BlocListener<AuthBloc, AuthState>(
          listenWhen: (previous, current) =>
              current is AuthSuccess &&
              (previous is! AuthSuccess ||
                  previous.user.role != current.user.role ||
                  previous.user.groupId != current.user.groupId),
          listener: (_, state) {
            if (state is AuthSuccess) {
              _applyUserContext(state.user.role, state.user.groupId);
            }
          },
        ),
      ],
      child: Scaffold(
        body: Stack(
          children: [
            RepaintBoundary(
              child: widget.mapOverride ??
                  GoogleMap(
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
                    onMapCreated: (c) {
                      if (!_controller.isCompleted) {
                        _controller.complete(c);
                      }
                    },
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
      ),
    );
  }

  Widget _buildUserSosButton() {
    final bool canSendSos = _hasGroup;
    final Color foregroundColor =
        canSendSos ? AppColors.textOnPrimary : AppColors.textSecondary;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!canSendSos) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.infoSurface,
              borderRadius: BorderRadius.circular(AppRadius.sm),
              border: Border.all(
                color: AppColors.infoText.withValues(alpha: 0.35),
              ),
            ),
            child: const Row(
              children: [
                Icon(
                  Icons.info_outline,
                  size: 20,
                  color: AppColors.infoText,
                ),
                SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    "Anda belum terdaftar dalam grup. Hubungi pembimbing atau admin agar sinyal SOS dapat digunakan.",
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.infoText,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: AppColors.textOnPrimary,
            disabledBackgroundColor:
                canSendSos ? AppColors.primary : AppColors.surface,
            disabledForegroundColor: foregroundColor,
            side: canSendSos
                ? null
                : const BorderSide(color: AppColors.borderChip),
            minimumSize: const Size(double.infinity, 60),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.full),
            ),
          ),
          onPressed: (_isLoading || !canSendSos) ? null : _confirmAndSendSOS,
          icon: _isLoading
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    color: AppColors.textOnPrimary,
                    strokeWidth: 2.5,
                  ),
                )
              : Icon(
                  Icons.sos,
                  size: 32,
                  color: foregroundColor,
                ),
          label: Text(
            _isLoading ? "Mengirim sinyal SOS..." : "Kirim Sinyal SOS",
            style: TextStyle(
              color: foregroundColor,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
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
            return BlocSelector<
                DashboardCubit,
                DashboardState,
                ({
                  List<Map<String, dynamic>> history,
                  bool isLoading,
                  String? error,
                })>(
              selector: (state) => (
                history: state.sosHistory,
                isLoading: state.isSosLoading,
                error: state.sosError,
              ),
              builder: (context, sosState) {
                final history = sosState.history;
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
                                if (_hasGroup && history.isNotEmpty)
                                  TextButton.icon(
                                    style: TextButton.styleFrom(
                                      foregroundColor: AppColors.error,
                                      minimumSize: const Size(48, 44),
                                      tapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                    ),
                                    onPressed: () =>
                                        _confirmClearHistory(context),
                                    icon: const Icon(
                                      Icons.delete_outline,
                                      size: 20,
                                    ),
                                    label: const Text(
                                      "Hapus",
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        const Divider(height: 1, color: AppColors.borderSubtle),
                        if (_hasGroup && sosState.error != null)
                          Container(
                            margin: const EdgeInsets.fromLTRB(
                              AppSpacing.lg,
                              AppSpacing.md,
                              AppSpacing.lg,
                              0,
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.md,
                              vertical: AppSpacing.xs,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.errorSurface,
                              borderRadius: BorderRadius.circular(AppRadius.sm),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.cloud_off_outlined,
                                  size: 18,
                                  color: AppColors.error,
                                ),
                                const SizedBox(width: AppSpacing.sm),
                                Expanded(
                                  child: Text(
                                    sosState.error!,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.error,
                                    ),
                                  ),
                                ),
                                TextButton(
                                  onPressed: () => context
                                      .read<DashboardCubit>()
                                      .startWatchingSos(_groupId),
                                  style: TextButton.styleFrom(
                                    foregroundColor: AppColors.error,
                                    minimumSize: const Size(44, 44),
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  child: const Text(
                                    'Coba Lagi',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        const SizedBox(height: AppSpacing.sm),
                        if (!_hasGroup)
                          const SizedBox(
                            height: 180,
                            child: Center(
                              child: Padding(
                                padding: EdgeInsets.symmetric(
                                  horizontal: AppSpacing.xxl,
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.group_off_outlined,
                                      size: 40,
                                      color: AppColors.textSecondary,
                                    ),
                                    SizedBox(height: AppSpacing.sm),
                                    Text(
                                      "Anda belum terdaftar dalam grup.",
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                    SizedBox(height: AppSpacing.xs),
                                    Text(
                                      "Hubungi admin untuk menetapkan grup agar riwayat SOS jamaah dapat dipantau.",
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          )
                        else if (sosState.isLoading && history.isEmpty)
                          const SizedBox(
                            height: 180,
                            child: Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  CircularProgressIndicator(),
                                  SizedBox(height: AppSpacing.md),
                                  Text(
                                    'Memuat riwayat SOS...',
                                    style: TextStyle(
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        else if (history.isEmpty)
                          const SizedBox(
                            height: 180,
                            child: Center(
                              child: Padding(
                                padding: EdgeInsets.symmetric(
                                  horizontal: AppSpacing.xxl,
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.shield_outlined,
                                      size: 40,
                                      color: AppColors.textSecondary,
                                    ),
                                    SizedBox(height: AppSpacing.sm),
                                    Text(
                                      "Belum ada sinyal SOS dari grup Anda.",
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                    SizedBox(height: AppSpacing.xs),
                                    Text(
                                      "Laporan darurat jamaah akan muncul otomatis di sini.",
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
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
                              final lat =
                                  double.tryParse(data['lat'].toString());
                              final lng =
                                  double.tryParse(data['lng'].toString());
                              final coordText = (lat != null && lng != null)
                                  ? '${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}'
                                  : '${data['lat']}, ${data['lng']}';
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
                                  "Koordinat: $coordText",
                                  style: const TextStyle(
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                                trailing: (lat != null && lng != null)
                                    ? IconButton(
                                        tooltip: 'Buka rute Google Maps',
                                        icon: const Icon(
                                          Icons.directions,
                                          color: AppColors.primary,
                                        ),
                                        onPressed: () =>
                                            _openGoogleMapsRoute(lat, lng),
                                      )
                                    : null,
                                onTap: () {
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

import 'package:belajar_mabrur/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:zego_uikit_prebuilt_live_audio_room/zego_uikit_prebuilt_live_audio_room.dart';

import '../../core/constants.dart';
import '../../core/theme/app_theme.dart';
import '../../meet/conference_config.dart';
import 'audio_room_controller.dart';

class AudioRoomScreen extends StatefulWidget {
  final String roomID;
  final bool isHost;
  final String userID;
  final String displayName;
  final String hostUserID;

  const AudioRoomScreen({
    super.key,
    required this.roomID,
    required this.userID,
    required this.displayName,
    required this.hostUserID,
    this.isHost = false,
  });

  @override
  State<AudioRoomScreen> createState() => _AudioRoomScreenState();
}

class _AudioRoomScreenState extends State<AudioRoomScreen> {
  bool _initialHostSeatReady = false;
  bool _suppressedInitialHostAutoUnmute = false;
  DateTime? _hostInitialSeatTime;
  String? _activeRequestUserId;
  BuildContext? _activeRequestDialogContext;

  @override
  void initState() {
    super.initState();
    AudioRoomController.instance.setSession(roomID: widget.roomID);
  }

  BuildContext? _resolveActiveContext() {
    final navContext = navigatorKey.currentContext;
    if (navContext != null && navContext.mounted) {
      return navContext;
    }
    return mounted ? context : null;
  }

  void _showRoomSnackBar(String message) {
    final activeContext = _resolveActiveContext();
    if (activeContext == null) return;
    ScaffoldMessenger.maybeOf(activeContext)?.showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _muteInitialHostAutoUnmuteIfNeeded() {
    if (!widget.isHost || _suppressedInitialHostAutoUnmute) return;
    _suppressedInitialHostAutoUnmute = true;
    // Zego SDK mengaktifkan mic otomatis saat takeOnSeat(0) meski turnOnMicrophoneWhenJoining false.
    ZegoUIKitPrebuiltLiveAudioRoomController()
        .audioVideo
        .microphone
        .turnOn(false);
  }

  Future<void> _showSpeakRequestDialog({
    required String userId,
    required String userName,
  }) async {
    if (!widget.isHost) return;
    final requesterName =
        userName.trim().isNotEmpty ? userName.trim() : 'Jamaah';

    if (_activeRequestUserId != null) {
      _showRoomSnackBar(
        '$requesterName juga meminta izin berbicara. Lihat di daftar peserta.',
      );
      return;
    }

    final dialogContext = _resolveActiveContext();
    if (dialogContext == null) return;

    _activeRequestUserId = userId;
    bool? approved;
    try {
      approved = await showDialog<bool>(
        context: dialogContext,
        barrierDismissible: true,
        builder: (ctx) {
          _activeRequestDialogContext = ctx;
          return AlertDialog(
            title: const Text('Permintaan Izin Bicara'),
            content: Text('$requesterName meminta izin untuk berbicara.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text(
                  'Tolak',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Izinkan'),
              ),
            ],
          );
        },
      );
    } finally {
      if (_activeRequestUserId == userId) {
        _activeRequestUserId = null;
        _activeRequestDialogContext = null;
      }
    }

    final seatHost = ZegoUIKitPrebuiltLiveAudioRoomController().seat.host;
    if (approved == true) {
      await seatHost.acceptTakingRequest(userId);
    } else if (approved == false) {
      await seatHost.rejectTakingRequest(userId);
    }
  }

  void _dismissSpeakRequestDialog(String userId) {
    if (_activeRequestUserId != userId) return;
    final dialogCtx = _activeRequestDialogContext;
    _activeRequestUserId = null;
    _activeRequestDialogContext = null;
    if (dialogCtx != null &&
        dialogCtx.mounted &&
        Navigator.of(dialogCtx).canPop()) {
      Navigator.of(dialogCtx).pop();
    }
  }

  Future<bool> _hostLeaveDialog(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text("Akhiri Ruang Audio"),
        content: const Text(
          "Mengakhiri ruang akan menutup sesi bimbingan suara untuk semua jamaah. Lanjutkan?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text(
              "Batal",
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: AppColors.textOnPrimary,
            ),
            child: const Text("Akhiri Ruang"),
          ),
        ],
      ),
    );

    return result ?? false;
  }

  Future<bool> _userLeaveDialog(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text("Keluar dari Ruang Audio"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "Apakah Anda yakin ingin keluar dari sesi bimbingan suara ini?",
            ),
            const SizedBox(height: AppSpacing.md),
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.infoSurface,
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, size: 18, color: AppColors.infoText),
                  SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      "Gunakan tombol perkecil di bagian atas agar tetap mendengar suara sambil membuka doa atau peta.",
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.infoText,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text(
              "Batal",
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text("Keluar"),
          ),
        ],
      ),
    );

    return result ?? false;
  }

  @override
  void dispose() {
    // Keep room state intact while minimized into PiP overlay.
    if (!ZegoUIKitPrebuiltLiveAudioRoomController().minimize.isMinimizing) {
      AudioRoomController.instance.clearSession();
    }

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          ZegoUIKitPrebuiltLiveAudioRoom(
            appID: AppConstants.zegoAppID,
            appSign: AppConstants.zegoAppSign,
            roomID: widget.roomID,
            userID: widget.userID,
            userName: widget.displayName,
            config: ConferenceConfig.get(
              context: context,
              isHost: widget.isHost,
              hostUserID: widget.hostUserID,
              currentUserID: widget.userID,
              roomID: widget.roomID,
            ),
            events: ZegoUIKitPrebuiltLiveAudioRoomEvents(
              onLeaveConfirmation: (event, defaultAction) async {
                debugPrint('onLeaveConfirmation triggered');
                final validContext = navigatorKey.currentContext ?? context;

                if (widget.isHost) {
                  return await _hostLeaveDialog(validContext);
                } else {
                  return await _userLeaveDialog(validContext);
                }
              },
              onEnded: (event, defaultAction) {
                _activeRequestUserId = null;
                _activeRequestDialogContext = null;
                AudioRoomController.instance.clearSession();
                // Zego calls minimize.hide() before defaultAction, so skip pop when leaving from PiP.
                if (event.isFromMinimizing) {
                  return;
                }
                defaultAction.call();
              },
              audioVideo: ZegoLiveAudioRoomAudioVideoEvents(
                onMicrophoneStateChanged: (isOn) {
                  // shortcut: jendela 2 detik menangkap auto-unmute SDK setelah takeOnSeat(0), hapus jika SDK menghormati turnOnMicrophoneWhenJoining untuk host.
                  if (widget.isHost &&
                      isOn &&
                      !_suppressedInitialHostAutoUnmute &&
                      _hostInitialSeatTime != null &&
                      DateTime.now().difference(_hostInitialSeatTime!) <
                          const Duration(seconds: 2)) {
                    _muteInitialHostAutoUnmuteIfNeeded();
                  }
                },
              ),
              seat: ZegoLiveAudioRoomSeatEvents(
                onChanged: (takenSeats, untakenSeats) {
                  if (widget.isHost &&
                      !_initialHostSeatReady &&
                      takenSeats.values.any((u) => u.id == widget.userID)) {
                    _initialHostSeatReady = true;
                    _hostInitialSeatTime = DateTime.now();
                    final controller =
                        ZegoUIKitPrebuiltLiveAudioRoomController();
                    if (!controller.seat.isRoomSeatLocked) {
                      controller.seat.host.close();
                    }
                    if (controller.audioVideo.microphone.localState) {
                      _muteInitialHostAutoUnmuteIfNeeded();
                    }
                  }
                },
                host: ZegoLiveAudioRoomSeatHostEvents(
                  onTakingRequested: (audience) {
                    if (widget.isHost) {
                      _showSpeakRequestDialog(
                        userId: audience.id,
                        userName: audience.name,
                      );
                    }
                  },
                  onTakingRequestCanceled: (audience) {
                    if (widget.isHost) {
                      _dismissSpeakRequestDialog(audience.id);
                    }
                  },
                ),
                audience: ZegoLiveAudioRoomSeatAudienceEvents(
                  onTakingRequestRejected: () {
                    _showRoomSnackBar(
                      'Permintaan izin berbicara ditolak oleh pembimbing.',
                    );
                  },
                  onTakingRequestFailed: () {
                    _showRoomSnackBar(
                      'Gagal meminta izin berbicara. Pastikan pembimbing berada di ruang.',
                    );
                  },
                  onTakingFailed: () {
                    _showRoomSnackBar(
                      'Slot pembicara sedang penuh. Coba lagi beberapa saat.',
                    );
                  },
                ),
              ),
              user: ZegoLiveAudioRoomUserEvents(
                onLeave: (user) {
                  if (user.id == widget.hostUserID && !widget.isHost) {
                    if (!mounted) return;

                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content:
                            Text("Pembimbing telah mengakhiri ruang audio."),
                      ),
                    );

                    Navigator.pop(context);
                  }
                },
              ),
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.only(
                  left: AppSpacing.lg,
                  right: AppSpacing.lg,
                  top: 50,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Semantics(
                      button: true,
                      label: 'Salin ID Ruang ${widget.roomID}',
                      child: Tooltip(
                        message: 'Salin ID Ruang',
                        child: Material(
                          color: Colors.black.withValues(alpha: 0.72),
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(AppRadius.md),
                            onTap: () {
                              Clipboard.setData(
                                ClipboardData(text: widget.roomID),
                              );
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('ID Ruang disalin.'),
                                  duration: Duration(seconds: 1),
                                ),
                              );
                            },
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(minHeight: 44),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 10,
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      'ID Ruang: ${widget.roomID}',
                                      style: const TextStyle(
                                        color: AppColors.textOnPrimary,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        decoration: TextDecoration.none,
                                      ),
                                    ),
                                    const SizedBox(width: AppSpacing.sm),
                                    const Icon(
                                      Icons.copy,
                                      color: AppColors.textOnPrimary,
                                      size: 18,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

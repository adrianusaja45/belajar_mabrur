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
  @override
  void initState() {
    super.initState();
    AudioRoomController.instance.setSession(roomID: widget.roomID);
  }

  Future<bool> _hostLeaveDialog(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text("End Room"),
        content: const Text(
          "End room akan mengakhiri sesi untuk semua pengguna. Lanjutkan?",
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
            child: const Text("End Room"),
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
        title: const Text("Keluar Room"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Apakah Anda yakin ingin keluar dari room?"),
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
                      "💡 Gunakan tombol minimize di atas untuk tetap mendengar",
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
                AudioRoomController.instance.clearSession();
                // Zego calls minimize.hide() before defaultAction, so skip pop when leaving from PiP.
                if (event.isFromMinimizing) {
                  return;
                }
                defaultAction.call();
              },
              user: ZegoLiveAudioRoomUserEvents(
                onLeave: (user) {
                  if (user.id == widget.hostUserID && !widget.isHost) {
                    if (!mounted) return;

                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("Host telah mengakhiri room."),
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
                      label: 'Salin Room ID ${widget.roomID}',
                      child: Tooltip(
                        message: 'Salin Room ID',
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
                                  content: Text('Room ID disalin!'),
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
                                      'Room ID: ${widget.roomID}',
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

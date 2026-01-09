import 'package:flutter/material.dart';
import 'package:zego_uikit_prebuilt_live_audio_room/zego_uikit_prebuilt_live_audio_room.dart';
import '../../core/constants.dart';

class ConferenceConfig {
  static ZegoUIKitPrebuiltLiveAudioRoomConfig get({
    required BuildContext context,
    required bool isHost,
    required String hostUserID,
    required String currentUserID,
    required String roomID,
  }) {
    final config = isHost
        ? ZegoUIKitPrebuiltLiveAudioRoomConfig. host()
        : ZegoUIKitPrebuiltLiveAudioRoomConfig.audience();

   

    /// ============================
    /// TOP MENU BAR BUTTONS
    /// ============================
    config.topMenuBar.buttons = const [
      ZegoLiveAudioRoomMenuBarButtonName.minimizingButton,
      ZegoLiveAudioRoomMenuBarButtonName.showMemberListButton,
    ];

    /// ============================
    /// SEAT LAYOUT - 3x3 Grid dengan spacing
    /// ============================
    config.seat.layout = ZegoLiveAudioRoomLayoutConfig(
      rowConfigs: [
        ZegoLiveAudioRoomLayoutRowConfig(count: 3, seatSpacing: 16),
        ZegoLiveAudioRoomLayoutRowConfig(count: 3, seatSpacing: 16),
        ZegoLiveAudioRoomLayoutRowConfig(count: 3, seatSpacing: 16),
      ],
      rowSpacing: 16,
    );

    /// ============================
    /// SEAT CARD PUTIH
    /// ============================
    config.seat.backgroundBuilder = (_, __, ___, ____) {
      return Container(
        decoration: BoxDecoration(
          color: AppConstants.surfaceColor,
          borderRadius:  BorderRadius.circular(12),
          border: Border.all(color: Colors.grey. shade300, width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
      );
    };

    /// ============================
    /// AVATAR CUSTOM - HANYA AVATAR + BADGE
    /// ============================
    config.seat.avatarBuilder = (context, size, user, __) {
      if (user == null) return const SizedBox();

      final isHostUser = user.id == hostUserID;
      final avatarRadius = size. shortestSide * 0.28;
      final hostBadgeSize = size.shortestSide * 0.18;

      return Center(
        child: Stack(
          alignment: Alignment.center,
          children: [
            CircleAvatar(
              radius: avatarRadius,
              backgroundColor: AppConstants.primaryColor. withOpacity(0.15),
              child: Text(
                user.name.isNotEmpty ? user.name[0].toUpperCase() : "? ",
                style: TextStyle(
                  fontSize: avatarRadius * 0.8,
                  color: AppConstants.primaryColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            /// HOST BADGE (Kuning, Atas Kanan)
            if (isHostUser)
              Positioned(
                right: -4,
                top: -4,
                child: Container(
                  width: hostBadgeSize,
                  height: hostBadgeSize,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFD700),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white,
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius:  2,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    "H",
                    style: TextStyle(
                      fontSize: hostBadgeSize * 0.5,
                      color: Colors. black,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
    };

    /// ============================
    /// MATIKAN SOUND WAVE
    /// ============================
    config.seat.showSoundWaveInAudioMode = false;

    return config;
  }
}
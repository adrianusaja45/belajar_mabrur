import 'package:flutter/material.dart';

import 'package:zego_uikit_prebuilt_live_audio_room/zego_uikit_prebuilt_live_audio_room.dart';

import '../../core/constants.dart';
import '../../core/theme/app_theme.dart';

class ConferenceConfig {
  static ZegoUIKitPrebuiltLiveAudioRoomConfig get({
    required BuildContext context,
    required bool isHost,
    required String hostUserID,
    required String currentUserID,
    required String roomID,
  }) {
    final config = isHost
        ? ZegoUIKitPrebuiltLiveAudioRoomConfig.host()
        : ZegoUIKitPrebuiltLiveAudioRoomConfig.audience();

    config.turnOnMicrophoneWhenJoining = false;

    config.useSpeakerWhenJoining = true;

    config.seat.closeWhenJoining = true;

    config.topMenuBar.buttons = [
      ZegoLiveAudioRoomMenuBarButtonName.minimizingButton,
    ];

    config.bottomMenuBar.hostButtons = const [
      ZegoLiveAudioRoomMenuBarButtonName.toggleMicrophoneButton,
      ZegoLiveAudioRoomMenuBarButtonName.showMemberListButton,
      ZegoLiveAudioRoomMenuBarButtonName.leaveButton,
    ];

    config.bottomMenuBar.speakerButtons = const [
      ZegoLiveAudioRoomMenuBarButtonName.toggleMicrophoneButton,
      ZegoLiveAudioRoomMenuBarButtonName.showMemberListButton,
      ZegoLiveAudioRoomMenuBarButtonName.leaveButton,
    ];

    config.bottomMenuBar.audienceButtons = const [
      ZegoLiveAudioRoomMenuBarButtonName.applyToTakeSeatButton,
      ZegoLiveAudioRoomMenuBarButtonName.showMemberListButton,
      ZegoLiveAudioRoomMenuBarButtonName.leaveButton,
    ];

    // Mencegah jamaah mengambil slot pembicara langsung tanpa ACC pembimbing.
    config.popUpMenu.seatClicked.hiddenMenus = const [
      ZegoLiveAudioRoomPopupItemValue.takeOnSeat,
    ];

    config.innerText = ZegoUIKitPrebuiltLiveAudioRoomInnerText(
      takeSeatMenuButton: 'Mulai Berbicara',
      switchSeatMenuButton: 'Pindah Posisi',
      removeSpeakerMenuDialogButton: 'Turunkan %0 dari Pembicara',
      muteSpeakerMenuDialogButton: 'Bisukan %0',
      cancelMenuDialogButton: 'Batal',
      removeUserMenuDialogButton: 'Keluarkan %0 dari Ruang',
      memberListTitle: 'Peserta',
      memberListRoleYou: 'Anda',
      memberListRoleHost: 'Pembimbing',
      memberListRoleSpeaker: 'Pembicara',
      removeSpeakerFailedToast: 'Gagal menurunkan %0',
      messageEmptyToast: 'Tulis pesan...',
      applyToTakeSeatButton: 'Minta Izin Bicara',
      cancelTheTakeSeatApplicationButton: 'Batal Minta Izin',
      memberListAgreeButton: 'Izinkan',
      memberListDisagreeButton: 'Tolak',
      inviteToTakeSeatMenuDialogButton: 'Undang %0 untuk Berbicara',
      assignAsCoHostMenuDialogButton: 'Jadikan %0 Asisten Pembimbing',
      revokeCoHostPrivilegesMenuDialogButton: 'Cabut Izin Asisten %0',
      microphonePermissionSettingDialogInfo: ZegoLiveAudioRoomDialogInfo(
        title: 'Mikrofon Tidak Dapat Digunakan',
        message:
            'Aktifkan izin mikrofon di pengaturan perangkat untuk berbicara.',
        cancelButtonName: 'Batal',
        confirmButtonName: 'Pengaturan',
      ),
      removeFromSeatDialogInfo: ZegoLiveAudioRoomDialogInfo(
        title: 'Turunkan Pembicara',
        message: 'Turunkan %0 kembali menjadi pendengar?',
        cancelButtonName: 'Batal',
        confirmButtonName: 'Turunkan',
      ),
      leaveSeatDialogInfo: ZegoLiveAudioRoomDialogInfo(
        title: 'Selesai Berbicara',
        message: 'Kembali menjadi pendengar dengan mikrofon nonaktif?',
        cancelButtonName: 'Batal',
        confirmButtonName: 'Ya',
      ),
      hostInviteTakeSeatDialog: ZegoLiveAudioRoomDialogInfo(
        title: 'Undangan Berbicara',
        message: 'Pembimbing mengundang Anda untuk berbicara.',
        cancelButtonName: 'Tolak',
        confirmButtonName: 'Terima',
      ),
    );

    config.background = Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppConstants.primaryColor.withValues(alpha: 0.1),
            AppConstants.primaryColor.withValues(alpha: 0.05),
          ],
        ),
      ),
    );

    config.seat.layout = ZegoLiveAudioRoomLayoutConfig(
      rowConfigs: [
        ZegoLiveAudioRoomLayoutRowConfig(count: 3, seatSpacing: 16),
        ZegoLiveAudioRoomLayoutRowConfig(count: 3, seatSpacing: 16),
        ZegoLiveAudioRoomLayoutRowConfig(count: 3, seatSpacing: 16),
      ],
      rowSpacing: 16,
    );

    config.seat.backgroundBuilder = (_, __, ___, ____) {
      return Container(
        decoration: BoxDecoration(
          color: AppConstants.surfaceColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.borderSubtle, width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
      );
    };

    config.seat.avatarBuilder = (context, size, user, __) {
      if (user == null) return const SizedBox();

      final isHostUser = user.id == hostUserID;

      final avatarRadius = size.shortestSide * 0.28;

      final hostBadgeSize = size.shortestSide * 0.18;

      return Center(
        child: Stack(
          alignment: Alignment.center,
          children: [
            CircleAvatar(
              radius: avatarRadius,
              backgroundColor:
                  AppConstants.primaryColor.withValues(alpha: 0.15),
              child: Text(
                user.name.isNotEmpty ? user.name[0].toUpperCase() : "?",
                style: TextStyle(
                  fontSize: avatarRadius * 0.8,
                  color: AppConstants.primaryColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
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
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 2,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    "H",
                    style: TextStyle(
                      fontSize: hostBadgeSize * 0.5,
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
    };

    config.seat.showSoundWaveInAudioMode = true;

    return config;
  }
}

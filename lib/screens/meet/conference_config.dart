import 'package:flutter/material.dart';
import 'package:zego_uikit_prebuilt_video_conference/zego_uikit_prebuilt_video_conference.dart';
import '../../core/constants.dart';

class ConferenceConfig {
  static ZegoUIKitPrebuiltVideoConferenceConfig get({
    required BuildContext context,
    required bool isHost,
    required String hostUserID,
    required String currentUserID,
  }) {
    ZegoUIKitPrebuiltVideoConferenceConfig config = ZegoUIKitPrebuiltVideoConferenceConfig();

    config.layout = ZegoLayout.gallery();
    config.turnOnCameraWhenJoining = false;
    config.audioVideoViewConfig.showCameraStateOnView = false;
    config.audioVideoViewConfig.showUserNameOnView = false;
    config.audioVideoViewConfig.backgroundBuilder = (_, __, ___, ____) => 
        Container(color: Colors.white);

    config.avatarBuilder = (context, size, user, extraInfo) => _buildAvatar(size, user, hostUserID);

    config.bottomMenuBarConfig.hideAutomatically = false;
    config.bottomMenuBarConfig.hideByClick = false;
    config.bottomMenuBarConfig.style = ZegoMenuBarStyle.light;
    config.bottomMenuBarConfig.buttons = [
      ZegoMenuBarButtonName.toggleMicrophoneButton,
      ZegoMenuBarButtonName.leaveButton,
      ZegoMenuBarButtonName.switchAudioOutputButton,
    ];
    
    config.topMenuBarConfig.isVisible = false;

    config.onLeaveConfirmation = (BuildContext context) async {
      if (isHost) {
        return await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text("Akhiri Pertemuan?"),
            content: const Text("Sesi ini akan ditutup untuk semua peserta."),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Batal")),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text("AKHIRI", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ) ?? false;
      }
      return true;
    };

    return config;
  }

  static Widget _buildAvatar(Size size, ZegoUIKitUser? user, String hostUserID) {
    if (user == null) return const SizedBox();

    double dynamicRadius = size.width < size.height ? size.width * 0.20 : size.height * 0.20;
    if (dynamicRadius > 45) dynamicRadius = 45;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(4.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: dynamicRadius,
              // PERBAIKAN DI SINI: Gunakan withValues(alpha: ...)
              backgroundColor: AppConstants.primaryColor.withValues(alpha: 0.1),
              child: FittedBox(
                child: Text(
                  user.name.isNotEmpty ? user.name[0].toUpperCase() : "?",
                  style: TextStyle(
                    color: AppConstants.primaryColor, 
                    fontWeight: FontWeight.bold, 
                    fontSize: dynamicRadius
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  user.name,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black, decoration: TextDecoration.none),
                ),
              ),
            ),
            if (user.id == hostUserID)
              const Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    "PEMBIMBING",
                    style: TextStyle(color: AppConstants.primaryColor, fontWeight: FontWeight.bold, decoration: TextDecoration.none),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
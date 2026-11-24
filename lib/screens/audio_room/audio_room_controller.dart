import 'package:flutter/material.dart';
import 'package:zego_uikit_prebuilt_live_audio_room/zego_uikit_prebuilt_live_audio_room.dart';

class AudioRoomController {
  AudioRoomController._internal();

  static final AudioRoomController instance = AudioRoomController._internal();

  String? roomID;
  String? userID;
  String? displayName;
  String? hostUserID;
  bool isHost = false;

  bool get isRoomActive =>
      roomID != null ||
      ZegoUIKitPrebuiltLiveAudioRoomController().minimize.isMinimizing;

  void setSession({
    required String roomID,
    required String userID,
    required String displayName,
    required String hostUserID,
    required bool isHost,
  }) {
    this.roomID = roomID;
    this.userID = userID;
    this.displayName = displayName;
    this.hostUserID = hostUserID;
    this.isHost = isHost;
    debugPrint('AudioRoomController: Session set -> Room: $roomID');
  }

  void clearSession() {
    roomID = null;
    userID = null;
    displayName = null;
    hostUserID = null;
    isHost = false;
  }

  Future<void> leaveRoom(BuildContext context) async {
    final zegoController = ZegoUIKitPrebuiltLiveAudioRoomController();
    if (!isRoomActive && !zegoController.minimize.isMinimizing) {
      return;
    }

    debugPrint('AudioRoomController: Cleaning up session for Room: $roomID');
    try {
      if (context.mounted) {
        await zegoController.leave(context, showConfirmation: false);
      }
    } catch (e) {
      debugPrint('AudioRoomController: Failed to leave Zego room: $e');
    } finally {
      clearSession();
    }
  }
}

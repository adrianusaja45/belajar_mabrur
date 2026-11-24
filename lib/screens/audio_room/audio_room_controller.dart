import 'package:flutter/material.dart';
import 'package:zego_uikit_prebuilt_live_audio_room/zego_uikit_prebuilt_live_audio_room.dart';

class AudioRoomController {
  AudioRoomController._internal();

  static final AudioRoomController instance = AudioRoomController._internal();

  String? roomID;

  bool get isRoomActive =>
      roomID != null ||
      ZegoUIKitPrebuiltLiveAudioRoomController().minimize.isMinimizing;

  void setSession({required String roomID}) {
    this.roomID = roomID;
    debugPrint('AudioRoomController: Session set -> Room: $roomID');
  }

  void clearSession() {
    roomID = null;
  }

  Future<void> leaveRoom(BuildContext context) async {
    if (!isRoomActive) return;

    final zegoController = ZegoUIKitPrebuiltLiveAudioRoomController();
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

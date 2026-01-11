import 'package:flutter/material.dart';

class AudioRoomController {
  AudioRoomController._internal();

  static final AudioRoomController instance = AudioRoomController._internal();

  // Session Data
  String? roomID;
  String? userID;
  String? displayName;
  String? hostUserID;
  bool isHost = false;

  // Cek apakah sedang ada room aktif
  bool get isRoomActive => roomID != null;

  // Set session info (Dipanggil saat Join Room)
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
    
    debugPrint('AudioRoomController: Session Set -> Room: $roomID');
  }

  // Clear session info (Dipanggil saat Leave Room atau Logout)
  void leaveRoom() {
    debugPrint('AudioRoomController: Cleaning up session for Room: $roomID');

    // Clear session data
    roomID = null;
    userID = null;
    displayName = null;
    hostUserID = null;
    isHost = false;
  }
}
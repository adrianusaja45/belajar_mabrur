

import 'package:flutter/material.dart';

class AudioRoomController {
  AudioRoomController._internal();

  static final AudioRoomController instance = AudioRoomController._internal();

  // session
  String? roomID;
  String? userID;
  String? displayName;
  String? hostUserID;
  bool isHost = false;

  bool _isMinimized = false;
  bool get isMinimized => _isMinimized;

  // set session info (dipanggil oleh AudioRoomScreen saat init)
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
  }

  // logic bergantung pada app Anda: 
  void joinRoom() {
    _isMinimized = false;
    // bisa tambahkan analytics / backend call utk menandai user join
    debugPrint('AudioRoomController: joinRoom $roomID / $userID / $displayName');
  }

  void leaveRoom() {
    _isMinimized = false;
    // bersihkan session state & lakukan cleanup
    debugPrint('AudioRoomController: leaveRoom $roomID / $userID');
    
    // Clear session data
    roomID = null;
    userID = null;
    displayName = null;
    hostUserID = null;
    isHost = false;

    // Jika Anda perlu memanggil Zego SDK explicit untuk leave, lakukan di sini. 
    // Ex: ZegoUIKit().leaveRoom();
  }

  void minimize() {
    _isMinimized = true;
    debugPrint('AudioRoomController: minimize (PIP active)');
    // jangan leaveRoom(), biarkan Zego SDK tetap running di background
  }

  void restore() {
    _isMinimized = false;
    debugPrint('AudioRoomController: restore (PIP closed)');
  }
}
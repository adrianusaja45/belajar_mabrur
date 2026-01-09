import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zego_uikit_prebuilt_live_audio_room/zego_uikit_prebuilt_live_audio_room.dart';
import '../../core/constants.dart';
import '../../meet/conference_config.dart';
import 'audio_room_controller.dart';
import 'pip_audio_overlay.dart';

class AudioRoomScreen extends StatefulWidget {
  final String roomID;
  final bool isHost;
  final String userID;
  final String displayName;
  final String hostUserID;

  const AudioRoomScreen({
    super.key,
    required this. roomID,
    required this. userID,
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

    AudioRoomController.instance.setSession(
      roomID: widget.roomID,
      userID: widget.userID,
      displayName: widget. displayName,
      hostUserID: widget.hostUserID,
      isHost: widget.isHost,
    );

    AudioRoomController.instance.joinRoom();

    if (widget.isHost) {
      _markRoomAsCreated();
    }
  }

  Future<void> _markRoomAsCreated() async {
    final prefs = await SharedPreferences. getInstance();
    final roomCreatedKey = 'room_${widget.roomID}_created';
    final roomHostKey = 'room_${widget.roomID}_host';

    await prefs.setBool(roomCreatedKey, true);
    await prefs.setString(roomHostKey, widget. displayName);

    debugPrint('AudioRoomScreen: Room ${widget.roomID} marked as created by ${widget.displayName}');
  }

  Future<void> _clearRoomFlag() async {
    final prefs = await SharedPreferences.getInstance();
    final roomCreatedKey = 'room_${widget.roomID}_created';
    final roomHostKey = 'room_${widget.roomID}_host';

    await prefs.remove(roomCreatedKey);
    await prefs.remove(roomHostKey);

    debugPrint('AudioRoomScreen: Room ${widget.roomID} flag cleared');
  }

  /// Dialog untuk HOST - End Room atau Batal
  Future<bool> _hostLeaveDialog(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text("End Room"),
        content: const Text("End room akan mengakhiri sesi untuk semua pengguna.  Lanjutkan? "),
        actions: [
          TextButton(
            onPressed:  () => Navigator.pop(context, false),
            child: const Text("Batal", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child:  const Text("End Room", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    return result ??  false;
  }

  /// Dialog untuk USER - Konfirmasi keluar
  Future<bool> _userLeaveDialog(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text("Keluar Room"),
        content: const Text("Apakah Anda yakin ingin keluar dari room? "),
        actions: [
          TextButton(
            onPressed:  () => Navigator.pop(context, false),
            child: const Text("Batal", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Keluar"),
          ),
        ],
      ),
    );

    return result ?? false;
  }

  @override
  void dispose() {
    if (! AudioRoomController.instance.isMinimized) {
      if (widget.isHost) {
        _clearRoomFlag();
      }

      AudioRoomController.instance. leaveRoom();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppConstants.backgroundColor,
      body: Stack(
        children: [
          /// ZEGO AUDIO ROOM
          ZegoUIKitPrebuiltLiveAudioRoom(
            appID: AppConstants.zegoAppID,
            appSign: AppConstants.zegoAppSign,
            roomID: widget. roomID,
            userID:  widget.userID,
            userName: widget.displayName,
            config: ConferenceConfig. get(
              context: context,
              isHost: widget.isHost,
              hostUserID: widget.hostUserID,
              currentUserID: widget.userID,
              roomID: widget.roomID,
            ),
            events: ZegoUIKitPrebuiltLiveAudioRoomEvents(
              onLeaveConfirmation: (event, defaultAction) async {
                final ctx = event.context;

                debugPrint('onLeaveConfirmation triggered - isHost: ${widget.isHost}');

                // HANDLE MINIMIZE BUTTON CLICK
                // Minimize button akan trigger ini dengan minimize state
                if (AudioRoomController.instance.isMinimized) {
                  debugPrint('Minimize clicked - showing PIP');
                  AudioRoomController.instance.minimize();
                  if (ctx.mounted) {
                    PIPAudioOverlay.show(ctx);
                  }
                  return false; // Don't leave room
                }

                // HANDLE LEAVE/BACK BUTTON CLICK
                if (widget.isHost) {
                  // Host:  Show "End Room" dialog
                  return await _hostLeaveDialog(ctx);
                } else {
                  // User: Show "Confirm Leave" dialog
                  return await _userLeaveDialog(ctx);
                }
              },
              user: ZegoLiveAudioRoomUserEvents(
                onLeave: (user) {
                  if (user.id == widget.hostUserID && ! widget.isHost) {
                    if (! mounted) return;

                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("Host telah mengakhiri room. "),
                      ),
                    );

                    Navigator.pop(context);
                  }
                },
              ),
            ),
          ),

          /// OVERLAY - CUSTOM TOP BAR TRANSPARAN
          Positioned(
            top: 0,
            left:  0,
            right: 0,
            height: 56,
            child: Container(
              color: Colors.transparent,
            ),
          ),

          /// ROOM ID KETERANGAN - DI ATAS LAYAR
          Positioned(
            top: 16,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors. black. withOpacity(0.6),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Room ID:  ${widget.roomID}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.isHost ?  'Host' : 'User',
                      style: TextStyle(
                        color: widget.isHost
                            ? const Color(0xFFFFD700)
                            : Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
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
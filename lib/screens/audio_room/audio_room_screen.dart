import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Untuk Clipboard
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zego_uikit_prebuilt_live_audio_room/zego_uikit_prebuilt_live_audio_room.dart';
import 'package:belajar_mabrur/main.dart';
import '../../core/constants.dart';
import '../../meet/conference_config.dart';

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

    if (widget.isHost) {
      _markRoomAsCreated();
    }
  }

  Future<void> _markRoomAsCreated() async {
    final prefs = await SharedPreferences.getInstance();
    final roomCreatedKey = 'room_${widget.roomID}_created';
    final roomHostKey = 'room_${widget.roomID}_host';

    await prefs.setBool(roomCreatedKey, true);
    await prefs.setString(roomHostKey, widget.displayName);

    debugPrint(
        'AudioRoomScreen: Room ${widget.roomID} marked as created by ${widget.displayName}');
  }

  Future<void> _clearRoomFlag() async {
    final prefs = await SharedPreferences.getInstance();
    final roomCreatedKey = 'room_${widget.roomID}_created';
    final roomHostKey = 'room_${widget.roomID}_host';

    await prefs.remove(roomCreatedKey);
    await prefs.remove(roomHostKey);

    debugPrint('AudioRoomScreen:  Room ${widget.roomID} flag cleared');
  }

  Future<bool> _hostLeaveDialog(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text("End Room"),
        content: const Text(
            "End room akan mengakhiri sesi untuk semua pengguna.  Lanjutkan? "),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Batal", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child:
                const Text("End Room", style: TextStyle(color: Colors.white)),
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
      builder: (_) => AlertDialog(
        title: const Text("Keluar Room"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Apakah Anda yakin ingin keluar dari room? "),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info, size: 16, color: Colors.blue),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "💡 Gunakan tombol minimize di atas untuk tetap mendengar",
                      style: TextStyle(fontSize: 11, color: Colors.blue),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
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
    if (widget.isHost) {
      _clearRoomFlag();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
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

              // --- PERBAIKAN DI SINI ---
              // Gunakan context dari navigatorKey global.
              // Jika null (jarang terjadi), fallback ke context lokal.
              final validContext = navigatorKey.currentContext ?? context;

              if (widget.isHost) {
                return await _hostLeaveDialog(validContext);
              } else {
                return await _userLeaveDialog(validContext);
              }
            },
            user: ZegoLiveAudioRoomUserEvents(
              onLeave: (user) {
                if (user.id == widget.hostUserID && !widget.isHost) {
                  if (!mounted) return;
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

        // ============================================
        // ROOM INFO OVERLAY (Room ID Badge)
        // ============================================
        // ============================================
// ROOM INFO OVERLAY (Room ID & Role Badge)
// ============================================
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.only(
                left: 16,
                right: 16,
                top:
                    50, // Tambah margin atas agar tidak bertabrakan dengan tombol Zego
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  // ROOM INFO BADGE
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Room ID: ${widget.roomID}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            decoration: TextDecoration.none,
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () {
                            Clipboard.setData(
                                ClipboardData(text: widget.roomID));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Room ID disalin! '),
                                duration: Duration(seconds: 1),
                              ),
                            );
                          },
                          child: const Icon(
                            Icons.copy,
                            color: Colors.white70,
                            size: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

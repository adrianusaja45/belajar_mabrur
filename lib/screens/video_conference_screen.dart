import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:zego_uikit_prebuilt_video_conference/zego_uikit_prebuilt_video_conference.dart';
import 'package:zego_uikit/zego_uikit.dart'; 

class AppConfig {
  static const int zegoAppID = 331924508;
  static const String zegoAppSign = "6b3e9cfa30bcd9589b1e72e4de8e01dde3784c75d0fa02ca425a1fec31428890";
}

class VideoConferenceAudioOnlyScreen extends StatefulWidget {
  final String roomID;
  final bool isHost;
  final String userID;
  final String userName;
  final String hostUserID;

  const VideoConferenceAudioOnlyScreen({
    super.key,
    required this.roomID,
    this.isHost = false,
    required this.userID,
    required this.userName,
    required this.hostUserID,
  });

  @override
  State<VideoConferenceAudioOnlyScreen> createState() => _VideoConferenceAudioOnlyScreenState();
}

class _VideoConferenceAudioOnlyScreenState extends State<VideoConferenceAudioOnlyScreen> {
  StreamSubscription<List<ZegoUIKitUser>>? _userLeaveSubscription;
  final ZegoUIKitPrebuiltVideoConferenceController _controller = ZegoUIKitPrebuiltVideoConferenceController();

  @override
  void initState() {
    super.initState();
    _startUserLeaveListener();
  }

  void _startUserLeaveListener() {
    // Listener untuk mendeteksi jika Host keluar
    _userLeaveSubscription = ZegoUIKit().getUserLeaveStream().listen((users) {
      if (!mounted) return;
      for (var user in users) {
        if (user.id == widget.hostUserID && !widget.isHost) {
          _forceLeave();
        }
      }
    });
  }

  @override
  void dispose() {
    _userLeaveSubscription?.cancel();
    ZegoUIKit().leaveRoom(); 
    super.dispose();
  }

  void _forceLeave() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Pertemuan telah diakhiri oleh Host."),
        backgroundColor: Color(0xFFA01C1C),
        behavior: SnackBarBehavior.floating,
      ),
    );
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  void _showMemberListManually(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
          ),
          child: DraggableScrollableSheet(
            initialChildSize: 0.6,
            maxChildSize: 0.9,
            minChildSize: 0.4,
            expand: false,
            builder: (context, scrollController) {
              return Column(
                children: [
                  const SizedBox(height: 12),
                  Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10))),
                  const Padding(
                    padding: EdgeInsets.all(15),
                    child: Text("Daftar Peserta", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                  const Divider(),
                  Expanded(
                    child: ZegoMemberList(
                      itemBuilder: (context, size, user, extraInfo) {
                        return _customMemberListItem(user);
                      },
                    ),
                  ),
                ],
              );
            }
          ),
        );
      },
    );
  }

  Widget _customMemberListItem(ZegoUIKitUser user) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: const Color(0xFFA01C1C).withOpacity(0.1),
        child: Text(
          user.name.isNotEmpty ? user.name[0].toUpperCase() : "?",
          style: const TextStyle(color: Color(0xFFA01C1C), fontWeight: FontWeight.bold),
        ),
      ),
      title: Text(
        user.name + (user.id == widget.userID ? " (Anda)" : ""),
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      subtitle: Text(user.id == widget.hostUserID ? "Host / Pembimbing" : "Peserta"),
      trailing: (widget.isHost && user.id != widget.userID)
          ? IconButton(
              icon: const Icon(Icons.person_remove, color: Colors.red),
              onPressed: () => _confirmKickUser(user),
            )
          : (user.id == widget.hostUserID ? const Icon(Icons.star, color: Colors.amber) : null),
    );
  }

  void _confirmKickUser(ZegoUIKitUser user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Keluarkan Peserta?"),
        content: Text("Keluarkan ${user.name} dari ruangan?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Batal")),
          TextButton(
            onPressed: () {
              ZegoUIKit().removeUserFromRoom([user.id]);
              Navigator.pop(context);
            },
            child: const Text("KELUARKAN", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Stack(
          children: [
            ZegoUIKitPrebuiltVideoConference(
              appID: AppConfig.zegoAppID,
              appSign: AppConfig.zegoAppSign,
              userID: widget.userID,
              userName: widget.userName,
              conferenceID: widget.roomID,
              controller: _controller,
              config: _getWhiteThemeConfig(context),
            ),
            Positioned(top: 0, left: 0, right: 0, child: _buildCustomHeader(context)),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomHeader(BuildContext context) {
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        color: Color(0xFFA01C1C),
        boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2))],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Audio Conference", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                Text("Room ID: ${widget.roomID}", style: const TextStyle(color: Colors.white70, fontSize: 12)),
              ],
            ),
          ),
          const ZegoScreenSharingToggleButton(),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.people_alt, color: Colors.white, size: 28),
            onPressed: () => _showMemberListManually(context),
          ),
        ],
      ),
    );
  }

  ZegoUIKitPrebuiltVideoConferenceConfig _getWhiteThemeConfig(BuildContext context) {
    ZegoUIKitPrebuiltVideoConferenceConfig config = ZegoUIKitPrebuiltVideoConferenceConfig();

    // 1. LAYOUT GALLERY (Versi 2.10.1 Compatible)
    // Tidak menggunakan parameter addApplyDataExtraInfo yang error
    config.layout = ZegoLayout.gallery();

    config.turnOnCameraWhenJoining = false;
    config.audioVideoViewConfig.showCameraStateOnView = false;
    config.audioVideoViewConfig.showUserNameOnView = false;
    config.audioVideoViewConfig.backgroundBuilder = (context, size, user, extraInfo) => Container(color: Colors.white);

    // 2. AVATAR DINAMIS (Anti-Overflow / Pixel Merah)
    config.avatarBuilder = (context, size, user, extraInfo) {
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
                backgroundColor: const Color(0xFFA01C1C).withOpacity(0.1),
                child: FittedBox(
                  child: Text(
                    user.name.isNotEmpty ? user.name[0].toUpperCase() : "?",
                    style: TextStyle(color: const Color(0xFFA01C1C), fontWeight: FontWeight.bold, fontSize: dynamicRadius),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              // Flexible + FittedBox mencegah overflow
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
              if (user.id == widget.hostUserID)
                const Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      "PEMBIMBING",
                      style: TextStyle(color: Color(0xFFA01C1C), fontWeight: FontWeight.bold, decoration: TextDecoration.none),
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    };

    // 3. MENU BAWAH TETAP TERLIHAT (No Auto-Hide)
    config.bottomMenuBarConfig.hideAutomatically = false; 
    config.bottomMenuBarConfig.hideByClick = false;       
    config.bottomMenuBarConfig.buttons = [
      ZegoMenuBarButtonName.toggleMicrophoneButton,
      ZegoMenuBarButtonName.leaveButton,
      ZegoMenuBarButtonName.switchAudioOutputButton,
    ];
    config.bottomMenuBarConfig.style = ZegoMenuBarStyle.light;

    config.topMenuBarConfig.isVisible = false;
    
    config.onLeaveConfirmation = (BuildContext context) async {
      if (widget.isHost) {
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
}
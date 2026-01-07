import 'dart:async';
import 'package:flutter/material.dart';
import 'package:zego_uikit_prebuilt_video_conference/zego_uikit_prebuilt_video_conference.dart';
// import 'package:zego_uikit/zego_uikit.dart'; <--- SUDAH DIHAPUS (Redundant)

import '../../core/constants.dart';
import 'meet/conference_config.dart';

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
  
  // HAPUS CONTROLLER INI KARENA DEPRECATED DAN TIDAK DIPAKAI
  // final ZegoUIKitPrebuiltVideoConferenceController _controller = ZegoUIKitPrebuiltVideoConferenceController();

  @override
  void initState() {
    super.initState();
    _startUserLeaveListener();
  }

  void _startUserLeaveListener() {
    _userLeaveSubscription = ZegoUIKit().getUserLeaveStream().listen((users) {
      if (!mounted) return;
      for (var user in users) {
        if (user.id == widget.hostUserID && !widget.isHost) {
          _forceLeave();
        }
      }
    });
  }

  void _forceLeave() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Pertemuan telah diakhiri oleh Host."),
        backgroundColor: AppConstants.primaryColor,
        behavior: SnackBarBehavior.floating,
      ),
    );
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  void dispose() {
    _userLeaveSubscription?.cancel();
    ZegoUIKit().leaveRoom();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Stack(
          children: [
            // 1. ZEGO CORE WIDGET
            ZegoUIKitPrebuiltVideoConference(
              appID: AppConstants.zegoAppID,
              appSign: AppConstants.zegoAppSign,
              userID: widget.userID,
              userName: widget.userName,
              conferenceID: widget.roomID,
              
              // HAPUS BARIS INI: controller: _controller, 
              
              config: ConferenceConfig.get(
                context: context, 
                isHost: widget.isHost, 
                hostUserID: widget.hostUserID,
                currentUserID: widget.userID
              ),
            ),
            
            // 2. CUSTOM HEADER (Overlay)
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
        color: AppConstants.primaryColor,
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
            initialChildSize: 0.6, maxChildSize: 0.9, minChildSize: 0.4, expand: false,
            builder: (context, scrollController) {
              return Column(
                children: [
                  const SizedBox(height: 12),
                  Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10))),
                  const Padding(padding: EdgeInsets.all(15), child: Text("Daftar Peserta", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
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
        // PERBAIKAN: GANTI withOpacity MENJADI withValues
        backgroundColor: AppConstants.primaryColor.withValues(alpha: 0.1),
        child: Text(
          user.name.isNotEmpty ? user.name[0].toUpperCase() : "?",
          style: const TextStyle(color: AppConstants.primaryColor, fontWeight: FontWeight.bold),
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
}
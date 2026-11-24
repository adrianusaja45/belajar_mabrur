import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../data/models/user_model.dart';
import '../data/repositories/auth_repository.dart';
import '../logic/auth/auth_bloc.dart';
import 'audio_room/audio_room_screen.dart';

class JoinTab extends StatefulWidget {
  const JoinTab({super.key});

  @override
  State<JoinTab> createState() => _JoinTabState();
}

class _JoinTabState extends State<JoinTab> {
  final TextEditingController _roomIDController = TextEditingController();
  late final String _fallbackUserId;
  UserModel? _cachedUser;
  bool _isHost = false;

  @override
  void initState() {
    super.initState();
    _fallbackUserId = const Uuid().v4().replaceAll('-', '');
    _loadCachedUserIfNeeded();
  }

  @override
  void dispose() {
    _roomIDController.dispose();
    super.dispose();
  }

  Future<void> _loadCachedUserIfNeeded() async {
    if (context.read<AuthBloc>().state is AuthSuccess) return;
    final cached = await context.read<AuthRepository>().getCachedUser();
    if (mounted && cached != null) {
      setState(() => _cachedUser = cached);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, authState) {
        final UserModel? user =
            authState is AuthSuccess ? authState.user : _cachedUser;
        final String userName = user?.name ?? 'User';
        final String userRole = user?.role ?? 'user';
        final String userId =
            (user != null && user.id.isNotEmpty) ? user.id : _fallbackUserId;
        final bool canHost = userRole == 'host';
        final bool effectiveIsHost = canHost && _isHost;

        return Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            title: const Text(
              "Audio Conference",
              style: TextStyle(
                color: Color(0xFFA01C1C),
                fontWeight: FontWeight.bold,
              ),
            ),
            backgroundColor: Colors.white,
            elevation: 0,
            centerTitle: true,
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              children: [
                const Icon(
                  Icons.mic_external_on,
                  size: 80,
                  color: Color(0xFFA01C1C),
                ),
                const SizedBox(height: 30),
                _buildUserCard(userName, userRole),
                const SizedBox(height: 30),
                _buildInfoCard(effectiveIsHost),
                const SizedBox(height: 20),
                TextField(
                  controller: _roomIDController,
                  decoration: InputDecoration(
                    labelText: "Masukkan Room ID",
                    hintText: "Contoh: 112",
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    prefixIcon: const Icon(
                      Icons.meeting_room,
                      color: Color(0xFFA01C1C),
                    ),
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 10),
                if (canHost)
                  SwitchListTile(
                    title: const Text(
                      "Buka sebagai Host? ",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      effectiveIsHost
                          ? "Anda akan membuat room baru"
                          : "Masuk sebagai peserta",
                    ),
                    value: effectiveIsHost,
                    activeThumbColor: const Color(0xFFA01C1C),
                    onChanged: (val) => setState(() => _isHost = val),
                  )
                else
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 10),
                    child: Text(
                      "Anda akan bergabung sebagai Peserta",
                      style: TextStyle(
                        color: Colors.grey,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                const SizedBox(height: 30),
                _buildJoinButton(
                  userName: userName,
                  userId: userId,
                  isHostUser: effectiveIsHost,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildUserCard(String userName, String userRole) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.account_circle, color: Colors.grey),
          const SizedBox(width: 10),
          Text(
            userName.isNotEmpty ? userName : "User",
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: userRole == 'host'
                  ? const Color(0xFFA01C1C)
                  : Colors.blueGrey,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              userRole.toUpperCase(),
              style: const TextStyle(color: Colors.white, fontSize: 10),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(bool isHostMode) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFA01C1C).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFA01C1C).withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.info, color: Color(0xFFA01C1C)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "🎙️ Audio Room Zego",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFA01C1C),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isHostMode
                      ? "Sebagai Host, Anda bisa membuat room baru"
                      : "Sebagai Peserta, Anda bisa langsung join room",
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildJoinButton({
    required String userName,
    required String userId,
    required bool isHostUser,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFA01C1C),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        onPressed: () => _joinRoom(
          userName: userName,
          userId: userId,
          isHostUser: isHostUser,
        ),
        child: const Text(
          "GABUNG AUDIO ROOM",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Future<void> _joinRoom({
    required String userName,
    required String userId,
    required bool isHostUser,
  }) async {
    final roomID = _roomIDController.text.trim();
    if (roomID.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Silakan isi Room ID")),
      );
      return;
    }

    final standardizedHostID = "host_$roomID";
    final myUserID = isHostUser ? standardizedHostID : userId;
    final displayName = userName.isNotEmpty ? userName : "User_$roomID";

    if (isHostUser) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('room_${roomID}_created', true);
      await prefs.setString('room_${roomID}_host', displayName);
      debugPrint('Host created room $roomID');
    }

    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AudioRoomScreen(
          roomID: roomID,
          isHost: isHostUser,
          userID: myUserID,
          displayName: displayName,
          hostUserID: standardizedHostID,
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../core/theme/app_theme.dart';
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
          backgroundColor: AppColors.background,
          appBar: AppBar(
            title: const Text(
              "Audio Conference",
              style: TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          body: SafeArea(
            top: false,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Column(
                children: [
                  const Icon(
                    Icons.mic_external_on,
                    size: 76,
                    color: AppColors.primary,
                  ),
                  const SizedBox(height: AppSpacing.xxl),
                  _buildUserCard(userName, userRole),
                  const SizedBox(height: AppSpacing.xl),
                  _buildInfoCard(effectiveIsHost),
                  const SizedBox(height: AppSpacing.xl),
                  TextField(
                    controller: _roomIDController,
                    decoration: const InputDecoration(
                      labelText: "Masukkan Room ID",
                      hintText: "Contoh: 112",
                      prefixIcon: Icon(
                        Icons.meeting_room,
                        color: AppColors.primary,
                      ),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  if (canHost)
                    SwitchListTile(
                      title: const Text(
                        "Buka sebagai Host?",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      subtitle: Text(
                        effectiveIsHost
                            ? "Anda akan membuat room baru"
                            : "Masuk sebagai peserta",
                        style: const TextStyle(color: AppColors.textSecondary),
                      ),
                      value: effectiveIsHost,
                      activeThumbColor: AppColors.primary,
                      onChanged: (val) => setState(() => _isHost = val),
                    )
                  else
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
                      child: Text(
                        "Anda akan bergabung sebagai Peserta",
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  const SizedBox(height: AppSpacing.xxl),
                  _buildJoinButton(
                    userName: userName,
                    userId: userId,
                    isHostUser: effectiveIsHost,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildUserCard(String userName, String userRole) {
    final isHostRole = userRole == 'host';
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.account_circle, color: AppColors.textSecondary),
          const SizedBox(width: AppSpacing.sm),
          Flexible(
            child: Text(
              userName.isNotEmpty ? userName : "User",
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.xs,
            ),
            decoration: BoxDecoration(
              color: isHostRole ? AppColors.accentGold : AppColors.badgeNeutral,
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Text(
              userRole.toUpperCase(),
              style: const TextStyle(
                color: AppColors.textOnPrimary,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(bool isHostMode) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.backgroundWarm,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.35),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: AppColors.primary),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "🎙️ Audio Room Zego",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  isHostMode
                      ? "Sebagai Host, Anda bisa membuat room baru"
                      : "Sebagai Peserta, Anda bisa langsung join room",
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
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
        onPressed: () => _joinRoom(
          userName: userName,
          userId: userId,
          isHostUser: isHostUser,
        ),
        child: const Text(
          "GABUNG AUDIO ROOM",
          style: TextStyle(fontWeight: FontWeight.bold),
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
        const SnackBar(
          content: Text("Silakan isi Room ID"),
          backgroundColor: AppColors.error,
        ),
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

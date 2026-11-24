import 'package:belajar_mabrur/screens/home_tab.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../core/theme/app_theme.dart';
import '../logic/auth/auth_bloc.dart';
import '../logic/dashboard/dashboard_cubit.dart';
import '../logic/dashboard/dashboard_state.dart';
import 'account_tab.dart';
import 'audio_room/audio_room_controller.dart';
import 'join_tab.dart';
import 'login_screen.dart';
import 'map_sos_tab.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) async {
        if (state is AuthUnauthenticated || state is AuthInitial) {
          if (AudioRoomController.instance.isRoomActive) {
            await AudioRoomController.instance.leaveRoom(context);
          }

          if (!context.mounted) return;
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const LoginScreen()),
            (route) => false,
          );
        }
      },
      child: Scaffold(
        body: BlocBuilder<DashboardCubit, DashboardState>(
          builder: (context, state) {
            return IndexedStack(
              index: state.tabIndex,
              children: [
                const RepaintBoundary(child: HomeTab()),
                RepaintBoundary(child: MapSosTab()),
                const RepaintBoundary(child: JoinTab()),
                const RepaintBoundary(child: AccountTab()),
              ],
            );
          },
        ),
        bottomNavigationBar: BlocBuilder<DashboardCubit, DashboardState>(
          builder: (context, state) {
            return Container(
              decoration: const BoxDecoration(
                border: Border(
                  top: BorderSide(color: AppColors.borderSubtle, width: 1),
                ),
              ),
              child: BottomNavigationBar(
                currentIndex: state.tabIndex,
                onTap: (index) {
                  context.read<DashboardCubit>().changeTab(index);
                },
                items: const [
                  BottomNavigationBarItem(
                    icon: Icon(Icons.home),
                    label: 'Home',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.map_outlined),
                    label: 'SOS Map',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.video_call),
                    label: 'Meet',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.person),
                    label: 'Account',
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

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
          await context.read<DashboardCubit>().resetOnLogout();
          if (context.mounted && AudioRoomController.instance.isRoomActive) {
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
              children: const [
                RepaintBoundary(child: HomeTab()),
                RepaintBoundary(child: MapSosTab()),
                RepaintBoundary(child: JoinTab()),
                RepaintBoundary(child: AccountTab()),
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
                    icon: Icon(Icons.menu_book_outlined),
                    activeIcon: Icon(Icons.menu_book),
                    label: 'Panduan',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.map_outlined),
                    activeIcon: Icon(Icons.map),
                    label: 'Peta SOS',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.headset_mic_outlined),
                    activeIcon: Icon(Icons.headset_mic),
                    label: 'Ruang Audio',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.person_outline),
                    activeIcon: Icon(Icons.person),
                    label: 'Akun',
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

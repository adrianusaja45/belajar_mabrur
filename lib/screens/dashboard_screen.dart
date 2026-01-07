import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/dashboard_cubit.dart';
import '../bloc/auth_bloc.dart';
import 'home_tab.dart';
import 'account_tab.dart';
import 'join_tab.dart'; 
import 'map_sos_tab.dart';
import 'login_screen.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // PENTING: BlocProvider DIHAPUS agar menggunakan instansi global dari main.dart
    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        // 1. LOGIKA REDIRECT KE LOGIN JIKA LOGOUT
        if (state is AuthInitial) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const LoginScreen()),
            (route) => false,
          );
        }

        // 2. LOGIKA AUTO-SUBSCRIBE UNTUK ROLE HOST
        if (state is AuthSuccess) {
          if (state.role == 'host') {
            FirebaseMessaging.instance.subscribeToTopic("role_host");
            debugPrint("Dashboard: User adalah Host, Subscribed ke role_host");
          } else {
            FirebaseMessaging.instance.unsubscribeFromTopic("role_host");
            debugPrint("Dashboard: User bukan Host, Unsubscribed dari role_host");
          }
        }
      },
      child: Scaffold(
        // Menggunakan DashboardState karena Cubit sudah diupdate
        body: BlocBuilder<DashboardCubit, DashboardState>(
          builder: (context, state) {
            return IndexedStack(
              index: state.tabIndex,
              children: [
                const HomeTab(),    
                MapSosTab(),  
                const JoinTab(),    
                const AccountTab(), 
              ],
            );
          },
        ),
        bottomNavigationBar: BlocBuilder<DashboardCubit, DashboardState>(
          builder: (context, state) {
            return Container(
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: Colors.black12, width: 0.5)),
              ),
              child: BottomNavigationBar(
                currentIndex: state.tabIndex,
                onTap: (index) {
                  context.read<DashboardCubit>().changeTab(index);
                },
                type: BottomNavigationBarType.fixed,
                backgroundColor: Colors.white,
                selectedItemColor: const Color(0xFFA01C1C),
                unselectedItemColor: Colors.grey,
                showUnselectedLabels: true,
                items: const [
                  BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.map_outlined),
                    activeIcon: Icon(Icons.map_sharp),
                    label: 'SOS Map',
                  ),
                  BottomNavigationBarItem(icon: Icon(Icons.video_call), label: 'Meet'),
                  BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Account'),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
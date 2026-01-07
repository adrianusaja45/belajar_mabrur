import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../repositories/auth_repository.dart'; // Import Repo untuk akses getGroupId
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
      // Tambahkan 'async' agar bisa mengambil data Group ID dari repository
      listener: (context, state) async {
        
        // 1. LOGIKA REDIRECT KE LOGIN JIKA LOGOUT
        if (state is AuthInitial) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const LoginScreen()),
            (route) => false,
          );
        }

        // 2. LOGIKA AUTO-SUBSCRIBE DINAMIS BERDASARKAN GROUP
        if (state is AuthSuccess) {
          if (state.role == 'host') {
            // Ambil Group ID dari Repository (Local Storage)
            final authRepo = context.read<AuthRepository>();
            String groupId = await authRepo.getGroupId();
            
            // Buat Nama Topik Dinamis
            String groupTopic = "sos_group_$groupId";

            // Subscribe ke Topik Grup Spesifik
            await FirebaseMessaging.instance.subscribeToTopic(groupTopic);
            debugPrint("Dashboard: Host Subscribed ke topik: $groupTopic");
            
            // Opsional: Unsubscribe dari role_host global jika tidak dipakai lagi
            // FirebaseMessaging.instance.unsubscribeFromTopic("role_host");
          } else {
            // Jika user biasa, pastikan tidak subscribe (atau unsubscribe jika perlu)
            // User biasa mengirim ke topik, tidak perlu mendengar (kecuali fitur chat grup)
            final authRepo = context.read<AuthRepository>();
            String groupId = await authRepo.getGroupId();
            String groupTopic = "sos_group_$groupId";
            
            await FirebaseMessaging.instance.unsubscribeFromTopic(groupTopic);
            debugPrint("Dashboard: User Unsubscribed dari topik: $groupTopic");
          }
        }
      },
      child: Scaffold(
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
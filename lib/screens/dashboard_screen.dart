import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
// IMPORT PATH DIPERBAIKI SESUAI STRUKTUR BARU
import '../data/repositories/auth_repository.dart'; 
import '../logic/dashboard/dashboard_cubit.dart'; // Import State Management
import '../logic/dashboard/dashboard_state.dart';
import '../logic/auth/auth_bloc.dart';
import 'home_tab.dart';
import 'account_tab.dart';
import 'join_tab.dart'; 
import 'map_sos_tab.dart';
import 'login_screen.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) async {
        
        // 1. Redirect jika Logout
        if (state is AuthInitial) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const LoginScreen()),
            (route) => false,
          );
        }

        // 2. Logic Subscribe FCM Dinamis
        if (state is AuthSuccess) {
          final authRepo = context.read<AuthRepository>();
          String groupId = await authRepo.getGroupId();
          String groupTopic = "sos_group_$groupId";

          if (state.role == 'host') {
            await FirebaseMessaging.instance.subscribeToTopic(groupTopic);
            debugPrint("Dashboard: Host Subscribed ke topik: $groupTopic");
          } else {
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
                  BottomNavigationBarItem(icon: Icon(Icons.map_outlined), label: 'SOS Map'),
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
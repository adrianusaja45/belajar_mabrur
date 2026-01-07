import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:permission_handler/permission_handler.dart';
import '../logic/auth/auth_bloc.dart';
import 'login_screen.dart';
import 'dashboard_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    // 1. Beri jeda untuk branding
    await Future.delayed(const Duration(seconds: 2));

    // 2. REQUEST KOLEKTIF (Mencegah PlatformException)
    // Kita tetap lanjut meskipun ada izin yang ditolak agar user bisa masuk ke login
    try {
      await [
        Permission.location,
        Permission.microphone,
        Permission.camera,
        Permission.notification,
        Permission.bluetoothConnect,
      ].request();
    } catch (e) {
      debugPrint("Gagal meminta izin: $e");
    }

    // 3. Pemicu Cek Auth Status
    if (mounted) {
      context.read<AuthBloc>().add(CheckAuthStatus());
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is AuthSuccess) {
          Navigator.pushReplacement(
            context, 
            MaterialPageRoute(builder: (_) => const DashboardScreen())
          );
        } else if (state is AuthInitial || state is AuthFailure) {
          Navigator.pushReplacement(
            context, 
            MaterialPageRoute(builder: (_) => const LoginScreen())
          );
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFA01C1C), // Merah Albirr
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Tambahkan error handling jika asset tidak ditemukan
              Image.asset(
                'assets/logo_splashcreen.png', 
                width: 150,
                errorBuilder: (context, error, stackTrace) => 
                    const Icon(Icons.mosque, size: 100, color: Colors.white),
              ),
              const SizedBox(height: 30),
              const CircularProgressIndicator(color: Colors.white),
            ],
          ),
        ),
      ),
    );
  }
}
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:permission_handler/permission_handler.dart';
import '../core/theme/app_theme.dart';
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
    await Future.delayed(const Duration(seconds: 2));

    // Request permissions together to avoid PlatformException and continue even if denied.
    try {
      await [
        Permission.location,
        Permission.microphone,
        Permission.notification,
        Permission.bluetoothConnect,
      ].request();
    } catch (e) {
      debugPrint("Gagal meminta izin: $e");
    }

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
            MaterialPageRoute(builder: (_) => const DashboardScreen()),
          );
        } else if (state is AuthUnauthenticated || state is AuthFailure) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const LoginScreen()),
          );
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.primary,
        body: SafeArea(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset(
                  'assets/logo_splashcreen.png',
                  width: 150,
                  semanticLabel: 'Logo Belajar Mabrur',
                  errorBuilder: (context, error, stackTrace) => const Icon(
                    Icons.mosque,
                    size: 100,
                    color: AppColors.textOnPrimary,
                  ),
                ),
                const SizedBox(height: 30),
                Semantics(
                  label: 'Memuat aplikasi Belajar Mabrur',
                  child: const CircularProgressIndicator(
                    color: AppColors.textOnPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

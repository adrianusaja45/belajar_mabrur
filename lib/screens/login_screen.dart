import 'package:belajar_mabrur/data/repositories/auth_repository.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../logic/auth/auth_bloc.dart';
import 'register_screen.dart';
import 'dashboard_screen.dart'; 

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController usernameController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  bool _isObscure = true; 

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: BlocConsumer<AuthBloc, AuthState>(
          listener: (context, state) async {
            if (state is AuthSuccess) {
              
              // 1. Ambil Repo (Synchronous - Aman)
              final authRepo = context.read<AuthRepository>();
              
              // 2. Operasi Async (Menimbulkan Gap)
              final groupId = await authRepo.getGroupId();
              
              // 3. CEK CONTEXT.MOUNTED (Perbaikan Utama)
              // Pastikan context masih valid setelah await selesai
              if (!context.mounted) return;
              
              // Nama topik dinamis
              final topicName = "sos_group_$groupId"; 

              if (state.role == 'host') {
                await FirebaseMessaging.instance.subscribeToTopic(topicName);
                debugPrint("HOST: Subscribed ke topik $topicName");
              } else {
                await FirebaseMessaging.instance.unsubscribeFromTopic(topicName);
                debugPrint("USER: Unsubscribed dari topik $topicName");
              }

              // Karena ada await lagi di atas (Firebase), cek mounted lagi jika paranoid,
              // tapi biasanya context.mounted sebelumnya sudah cukup untuk memutus flow jika widget mati.
              // Namun untuk strict linting:
              if (!context.mounted) return;

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(state.message), backgroundColor: Colors.green),
              );
              
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const DashboardScreen())
              );
            }
            
            else if (state is AuthFailure) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(state.error), backgroundColor: const Color(0xFFA01C1C)),
              );
            }
          },
          builder: (context, state) {
            if (state is AuthLoading) {
              return const Center(child: CircularProgressIndicator());
            }

            return Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset('assets/logo_login.png', height: 100),
                    const SizedBox(height: 30),
                    const Text(
                      "Silakan Login",
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFFA01C1C)),
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: usernameController,
                      decoration: const InputDecoration(
                        labelText: "Username",
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.person),
                      ),
                    ),
                    const SizedBox(height: 15),
                    TextField(
                      controller: passwordController,
                      decoration: InputDecoration(
                        labelText: "Password",
                        border: const OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.lock),
                        suffixIcon: IconButton(
                          icon: Icon(_isObscure ? Icons.visibility : Icons.visibility_off, color: Colors.grey),
                          onPressed: () => setState(() => _isObscure = !_isObscure),
                        ),
                      ),
                      obscureText: _isObscure,
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFA01C1C)),
                        onPressed: () {
                          context.read<AuthBloc>().add(
                                LoginRequested(usernameController.text, passwordController.text),
                              );
                        },
                        child: const Text("LOGIN", style: TextStyle(color: Colors.white)),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text("Belum punya akun? "),
                        GestureDetector(
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const RegisterScreen())),
                          child: const Text("Register", style: TextStyle(color: Color(0xFFA01C1C), fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
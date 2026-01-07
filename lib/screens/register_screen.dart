import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/auth_bloc.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController nameController = TextEditingController();
  final TextEditingController usernameController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  bool _isObscure = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: BlocConsumer<AuthBloc, AuthState>(
          listener: (context, state) {
            // [UBAH DISINI] Cek state RegisterSuccess
            if (state is RegisterSuccess) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("Registrasi Berhasil! Silakan Login."),
                  backgroundColor: Colors.green,
                ),
              );
              Navigator.pop(context); // Ini akan membawa user kembali ke Login Screen
            } else if (state is AuthFailure) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(state.error), backgroundColor: const Color(0xFFA01C1C)),
              );
            }
          },
          builder: (context, state) {
            return Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Logo
                      Image.asset('assets/logo_login.png', height: 100),
                      const SizedBox(height: 20),

                      // Judul Halaman
                      const Text(
                        "Register Akun",
                        style: TextStyle(
                          fontSize: 24, 
                          fontWeight: FontWeight.bold, 
                          color: Color(0xFFA01C1C)
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        "Lengkapi data diri Anda",
                        style: TextStyle(color: Colors.grey),
                      ),
                      const SizedBox(height: 30),
                      
                      // Input Nama
                      TextFormField(
                        controller: nameController,
                        decoration: const InputDecoration(
                          labelText: "Nama Lengkap",
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.badge),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) return 'Nama tidak boleh kosong';
                          return null;
                        },
                      ),
                      const SizedBox(height: 15),

                      // Input Username
                      TextFormField(
                        controller: usernameController,
                        decoration: const InputDecoration(
                          labelText: "Username",
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.person),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) return 'Username tidak boleh kosong';
                          if (value.contains(' ')) return 'Username tidak boleh ada spasi';
                          return null;
                        },
                      ),
                      const SizedBox(height: 15),

                      // Input Password
                      TextFormField(
                        controller: passwordController,
                        decoration: InputDecoration(
                          labelText: "Password",
                          border: const OutlineInputBorder(),
                          prefixIcon: const Icon(Icons.lock),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _isObscure ? Icons.visibility : Icons.visibility_off,
                              color: Colors.grey,
                            ),
                            onPressed: () {
                              setState(() {
                                _isObscure = !_isObscure;
                              });
                            },
                          ),
                        ),
                        obscureText: _isObscure,
                        validator: (value) {
                          if (value == null || value.isEmpty) return 'Password tidak boleh kosong';
                          if (value.length < 6) return 'Password minimal 6 karakter';
                          return null;
                        },
                      ),
                      const SizedBox(height: 25),

                      // Tombol Register
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFA01C1C)),
                          // Disable tombol saat loading
                          onPressed: state is AuthLoading 
                            ? null 
                            : () {
                              if (_formKey.currentState!.validate()) {
                                context.read<AuthBloc>().add(
                                      RegisterRequested(
                                        nameController.text,
                                        usernameController.text,
                                        passwordController.text,
                                      ),
                                    );
                              }
                            },
                          child: state is AuthLoading
                              ? const CircularProgressIndicator(color: Colors.white)
                              : const Text("REGISTER", style: TextStyle(color: Colors.white)),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Clickable Text Login
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text("Sudah punya akun? "),
                          GestureDetector(
                            onTap: () => Navigator.pop(context),
                            child: const Text(
                              "Login",
                              style: TextStyle(
                                color: Color(0xFFA01C1C),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../data/repositories/auth_repository.dart';
import '../logic/auth/auth_bloc.dart';

class AccountTab extends StatefulWidget {
  const AccountTab({super.key});

  @override
  State<AccountTab> createState() => _AccountTabState();
}

class _AccountTabState extends State<AccountTab> {
  late Future<Map<String, dynamic>> _profileFuture;

  @override
  void initState() {
    super.initState();
    _refreshProfile();
  }

  void _refreshProfile() {
    setState(() {
      _profileFuture = context.read<AuthRepository>().getProfile();
    });
  }

  // --- DIALOG EDIT PROFILE ---
  void _showEditProfileDialog(String currentName, String currentUsername) {
    final nameController = TextEditingController(text: currentName);
    final usernameController = TextEditingController(text: currentUsername);
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (dialogContext) { // Renamed context to dialogContext
        return StatefulBuilder(
          builder: (builderContext, setDialogState) { // Renamed context to builderContext
            return AlertDialog(
              title: const Text("Edit Profil"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: "Nama Lengkap"),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: usernameController,
                    decoration: const InputDecoration(labelText: "Username"),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext), 
                  child: const Text("Batal")
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFA01C1C)),
                  onPressed: isLoading ? null : () async {
                    setDialogState(() => isLoading = true);
                    try {
                      // 1. Panggil API (Async)
                      await context.read<AuthRepository>().updateProfile(
                        nameController.text, 
                        usernameController.text
                      );
                      
                      // 2. CEK MOUNTED YANG BENAR (Async Gap Fix)
                      // Gunakan 'builderContext.mounted' karena kita ada di dalam builder dialog
                      if (!builderContext.mounted) return; 

                      // 3. Gunakan context yang sudah dipastikan aman
                      Navigator.pop(builderContext); 
                      _refreshProfile(); 
                      
                      // Cek lagi mounted untuk context utama (untuk snackbar)
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Profil berhasil diperbarui"))
                      );
                    } catch (e) {
                      // Pastikan dialog masih ada sebelum menampilkan error di dalamnya (opsional)
                      // Atau gunakan context utama untuk snackbar
                      if (!mounted) return; 
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red)
                      );
                    } finally {
                      // Cek mounted sebelum setState (setDialogState) pada dialog
                      // Hanya jalankan jika dialog belum ditutup
                      if (builderContext.mounted) {
                        setDialogState(() => isLoading = false);
                      }
                    }
                  },
                  child: isLoading 
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) 
                    : const Text("SIMPAN", style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          }
        );
      },
    );
  }

  // --- DIALOG GANTI PASSWORD ---
  void _showChangePasswordDialog() {
    final oldPassController = TextEditingController();
    final newPassController = TextEditingController();
    bool isLoading = false;
    bool obscureOld = true;
    bool obscureNew = true;

    showDialog(
      context: context,
      builder: (dialogContext) { // Renamed to dialogContext
        return StatefulBuilder(
          builder: (builderContext, setDialogState) { // Renamed to builderContext
            return AlertDialog(
              title: const Text("Ganti Password"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: oldPassController,
                    obscureText: obscureOld,
                    decoration: InputDecoration(
                      labelText: "Password Lama",
                      suffixIcon: IconButton(
                        icon: Icon(obscureOld ? Icons.visibility : Icons.visibility_off),
                        onPressed: () => setDialogState(() => obscureOld = !obscureOld),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: newPassController,
                    obscureText: obscureNew,
                    decoration: InputDecoration(
                      labelText: "Password Baru",
                      suffixIcon: IconButton(
                        icon: Icon(obscureNew ? Icons.visibility : Icons.visibility_off),
                        onPressed: () => setDialogState(() => obscureNew = !obscureNew),
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext), 
                  child: const Text("Batal")
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFA01C1C)),
                  onPressed: isLoading ? null : () async {
                    setDialogState(() => isLoading = true);
                    try {
                      await context.read<AuthRepository>().updatePassword(
                        oldPassController.text, 
                        newPassController.text
                      );
                      
                      // PERBAIKAN: Gunakan builderContext.mounted
                      if (!builderContext.mounted) return;

                      Navigator.pop(builderContext);
                      
                      // Gunakan context utama (AccountTab) untuk snackbar
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Password berhasil diubah"))
                      );
                    } catch (e) {
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text("Gagal: $e"), backgroundColor: Colors.red)
                      );
                    } finally {
                      if (builderContext.mounted) {
                        setDialogState(() => isLoading = false);
                      }
                    }
                  },
                  child: isLoading 
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) 
                    : const Text("UBAH", style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          }
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: FutureBuilder<Map<String, dynamic>>(
        future: _profileFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text("Gagal memuat profil: ${snapshot.error}"),
                ElevatedButton(onPressed: _refreshProfile, child: const Text("Coba Lagi"))
              ],
            ));
          }

          final userData = snapshot.data!;
          final name = userData['name'] ?? 'User';
          final username = userData['username'] ?? '-';
          final role = userData['role'] ?? 'user'; 
          final isHost = role == 'host'; 

          return SingleChildScrollView(
            child: Column(
              children: [
                // Header Profil
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.only(top: 80, bottom: 40),
                  decoration: const BoxDecoration(
                    color: Color(0xFFA01C1C),
                    borderRadius: BorderRadius.vertical(bottom: Radius.circular(30)),
                  ),
                  child: Column(
                    children: [
                      const CircleAvatar(
                        radius: 50,
                        backgroundColor: Colors.white,
                        child: Icon(Icons.person, size: 60, color: Colors.grey),
                      ),
                      const SizedBox(height: 15),
                      Text(name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
                      Text("@$username", style: const TextStyle(color: Colors.white70)),
                      const SizedBox(height: 5),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(10)
                        ),
                        child: Text(role.toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 10)),
                      )
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // --- Menu Opsi ---
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: [
                      if (isHost) ...[
                        _buildMenuTile(
                          icon: Icons.edit,
                          title: "Edit Profil",
                          onTap: () => _showEditProfileDialog(name, username),
                        ),
                        const SizedBox(height: 10),
                        _buildMenuTile(
                          icon: Icons.lock_reset,
                          title: "Ganti Password",
                          onTap: _showChangePasswordDialog,
                        ),
                        const SizedBox(height: 10),
                      ],

                      _buildMenuTile(
                        icon: Icons.logout,
                        title: "Logout",
                        color: Colors.red[50],
                        textColor: const Color(0xFFA01C1C),
                        onTap: () {
                          showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text("Konfirmasi"),
                              content: const Text("Apakah Anda yakin ingin keluar?"),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(context), child: const Text("Batal")),
                                TextButton(
                                  onPressed: () {
                                    Navigator.pop(context);
                                    context.read<AuthBloc>().add(LogoutRequested());
                                  },
                                  child: const Text("Ya, Logout", style: TextStyle(color: Color(0xFFA01C1C))),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildMenuTile({
    required IconData icon, 
    required String title, 
    required VoidCallback onTap, 
    Color? color, 
    Color? textColor
  }) {
    return ListTile(
      tileColor: color ?? Colors.grey[100],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      leading: Icon(icon, color: textColor ?? Colors.black87),
      title: Text(title, style: TextStyle(color: textColor ?? Colors.black87, fontWeight: FontWeight.bold)),
      trailing: const Icon(Icons.chevron_right, color: Colors.grey),
      onTap: onTap,
    );
  }
}
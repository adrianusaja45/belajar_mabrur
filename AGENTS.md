# AGENTS.md: Panduan Kerja AI untuk Belajar Mabrur

## Arah Desain & Standar UI
- Untuk setiap pekerjaan UI, baca `DESIGN.md` terlebih dahulu sebagai arah desain (data desain: identitas Merah Marun Albirr `#A01C1C`, Light Mode saja, dial `ENERGY 1 / RHYTHM 2 / MOTION 1`), lalu terapkan filter plugin `antislop`.
- Gunakan token warna, radius, dan spacing dari `lib/core/theme/app_theme.dart` (`AppColors`, `AppRadius`, `AppSpacing`). Jangan menulis hex warna hardcoded atau warna gagal kontras WCAG AA (`< 4.5:1` teks normal, `< 3.0:1` komponen non-teks).
- Pastikan seluruh kontrol interaktif memiliki area sentuh minimal `44 x 44 px`, `SafeArea` pada header/overlay, umpan balik sentuh (`InkWell` / tombol native), serta `tooltip` atau `Semantics`.
- Seluruh copy antarmuka menggunakan Bahasa Indonesia yang konsisten, tanpa em dash, tanpa emoji dekoratif, dan tanpa istilah vendor teknis untuk pengguna akhir.

## Batasan Teknis & Keamanan
- Jangan mengubah versi paket `zego_*` di `pubspec.yaml` atau konfigurasi inti `ZegoUIKitPrebuiltLiveAudioRoom` tanpa konfirmasi eksplisit pengguna.
- Pertahankan proteksi `onEnded` (`event.isFromMinimizing`) dan guard `minimize.isMinimizing` pada `AudioRoomScreen` agar mode PiP/minimize dan logout tetap aman.
- Jangan meng-commit file rahasia (`.env`, `assets/service_account.json`, `android/local.properties`, `ios/Runner/AppKeys.swift`, `google-services.json`, `GoogleService-Info.plist`).
- Pengiriman FCM SOS saat ini berjalan dari sisi klien (`NotificationService`) bersama pencatatan Firestore (`SosRepository`); kegagalan Firestore tidak boleh memblokir pengiriman sinyal darurat FCM.

## Prinsip Ringkas (Plugin Ponytail)
- Terapkan plugin `ponytail` pada setiap perubahan kode: pilih perubahan paling ringkas yang tuntas, pakai ulang helper atau pola yang sudah ada, hapus kode mati, dan hindari abstraksi, wrapper, atau dependensi baru yang tidak diminta.
- Jangan pernah memangkas validasi pada batas kepercayaan, penanganan error yang mencegah kehilangan data, keamanan, aksesibilitas, maupun kebutuhan eksplisit pengguna.
- Bila memakai shortcut dengan batasan yang diketahui, tandai dengan komentar 1 baris berformat `// shortcut: <batasan>, <kapan upgrade>`.

## Verifikasi Wajib Sebelum Selesai
- Jalankan `flutter analyze --no-pub` (target 0 issues).
- Jalankan `dart format` pada seluruh file Dart yang diubah.
- Jalankan `flutter test` dan verifikasi kontras warna dengan `contrast-check.py` bila mengubah palet.

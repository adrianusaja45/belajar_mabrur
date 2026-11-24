# Belajar Mabrur (Albirr Mobile App)

<p align="center">
  <img src="assets/logo_splashcreen.png" alt="Belajar Mabrur Logo" width="140"/>
</p>

<p align="center">
  <strong>Aplikasi Mobile Pendamping Ibadah Haji dan Umrah</strong><br>
  <em>Panduan Doa Offline, Ruang Audio Bimbingan Langsung, dan Peta Darurat SOS Real-Time</em>
</p>

---

## Tentang Proyek

**Belajar Mabrur** (Albirr) adalah aplikasi mobile berbasis Flutter untuk membantu jamaah Haji dan Umrah menjalankan rangkaian ibadah secara mandiri maupun terpimpin. Aplikasi ini menghubungkan jamaah dengan pembimbing ibadah (*Muthawif* / *Host*) melalui ruang suara langsung dan pemantauan sinyal darurat SOS berbasis lokasi.

Arah desain antarmuka terdokumentasi di [DESIGN.md](DESIGN.md) dan panduan kerja pengembangan di [AGENTS.md](AGENTS.md).

---

## Fitur Utama

### 1. Panduan Doa dan Manasik (Tab Panduan)
- **Kumpulan doa per tahapan:** mencakup kategori *Ihram*, *Thawaf*, *Sa'i*, dan *Tahallul*.
- **Teks Arab RTL dan pengatur huruf:** lafaz Arab ditampilkan rata kanan (`TextDirection.rtl`, tinggi baris `1.9`) lengkap dengan transliterasi Latin, terjemahan Bahasa Indonesia, keterangan, serta tombol pengatur ukuran huruf `A-` / `A+` yang tersimpan di perangkat.
- **Cache doa offline:** daftar doa disimpan otomatis di `SharedPreferences` sehingga tetap dapat dibaca ketika perangkat berada di luar jangkauan sinyal, lengkap dengan auto-login sesi tersimpan saat offline.
- **Pencarian dan filter kategori:** mendukung pencarian berdasarkan judul, transliterasi, atau terjemahan, serta reset filter satu ketukan.

### 2. Peta Darurat dan Pelacakan Lokasi (Tab Peta SOS)
- **Konfirmasi cepat SOS (Jamaah):** mencegah pengiriman darurat tidak sengaja melalui dialog konfirmasi singkat sebelum mengirim koordinat GPS.
- **Pengiriman ganda FCM dan Firestore:** mengirim notifikasi darurat melalui Firebase Cloud Messaging sekaligus mencatat laporan ke koleksi `sos_reports` Firestore (kegagalan Firestore tidak memblokir pengiriman FCM).
- **Stream riwayat real-time (Pembimbing):** pembimbing memantau laporan SOS grup secara langsung melalui stream Firestore tanpa perlu memuat ulang aplikasi.
- **Tombol rute Google Maps:** membuka rute langsung menuju koordinat jamaah di aplikasi Google Maps melalui `url_launcher`, selain fokus penanda pada peta dalam aplikasi.

### 3. Ruang Audio Bimbingan Langsung (Tab Ruang Audio)
- **Bimbingan suara real-time:** komunikasi suara langsung berbasis ZEGOCLOUD Live Audio Room.
- **Pemisahan peran:** pembimbing (*Host*) dapat membuka ruang suara dan mengelola peserta, sedangkan jamaah bergabung dengan ID Ruang dan dapat meminta izin berbicara.
- **Mode perkecil (Picture-in-Picture):** jamaah dapat memperkecil ruang audio ke overlay mengambang agar tetap mendengarkan bimbingan sambil membuka panduan doa atau peta SOS.

### 4. Manajemen Akun dan Autentikasi (Tab Akun)
- **Masuk dan daftar akun:** autentikasi berbasis REST API dengan penyimpanan token menggunakan `flutter_secure_storage`.
- **Profil dan kata sandi:** pembimbing dapat mengubah data profil dan kata sandi langsung dari aplikasi.
- **Pengaturan peran:** memisahkan hak akses antarmuka antara peran Jamaah (`user`) dan Pembimbing (`host`).

---

## Arsitektur Proyek

Proyek ini memakai arsitektur berlapis dengan manajemen state **BLoC / Cubit**:

```text
belajar_mabrur/
├── assets/                          # Aset logo aplikasi dan kredensial lokal (gitignored)
├── lib/
│   ├── core/                        # Konfigurasi API, tema WCAG AA, exception, & services
│   │   ├── api_config.dart
│   │   ├── api_exception.dart
│   │   ├── constants.dart
│   │   ├── services/
│   │   │   ├── location_services.dart
│   │   │   └── notification_service.dart
│   │   └── theme/
│   │       └── app_theme.dart
│   ├── data/
│   │   ├── models/                  # ContentModel, UserModel
│   │   └── repositories/            # AuthRepository, ContentRepository, SosRepository
│   ├── logic/
│   │   ├── auth/                    # AuthBloc, AuthEvent, AuthState
│   │   ├── content/                 # ContentCubit, ContentState
│   │   └── dashboard/               # DashboardCubit, DashboardState
│   ├── meet/
│   │   └── conference_config.dart   # Konfigurasi UI & layout ruang audio
│   ├── screens/                     # Layar aplikasi (Splash, Login, Register, Dashboard, Tabs, AudioRoom)
│   └── main.dart                    # Entry point, setup FCM, dan overlay PiP
├── test/
│   ├── unit/                        # Unit test model, AuthBloc, cache doa offline, DashboardCubit
│   └── widget_test.dart             # Widget test layar utama, R-27 states, Arab RTL, A-/A+
├── DESIGN.md                        # Spesifikasi desain, palet WCAG AA, dan dial UI
├── AGENTS.md                        # Panduan teknis, batasan Zego, dan standar kualitas
├── .env.example                     # Template environment variables
└── pubspec.yaml                     # Manifest dependensi Flutter
```

---

## Tech Stack dan Dependensi

| Kategori | Paket / Teknologi | Keterangan |
|---|---|---|
| **Framework** | Flutter (`>= 3.0.0`) | SDK mobile lintas platform (Android dan iOS) |
| **State Management** | `flutter_bloc`, `equatable` | Pengelolaan state reaktif untuk auth, konten, dan dashboard |
| **Ruang Audio** | `zego_uikit_prebuilt_live_audio_room` | Streaming suara langsung dengan mode PiP mini overlay |
| **Peta dan Lokasi** | `google_maps_flutter`, `geolocator`, `url_launcher` | Peta interaktif, GPS, dan navigasi rute ke Google Maps eksternal |
| **Notifikasi dan Cloud** | `firebase_core`, `firebase_messaging`, `cloud_firestore`, `flutter_local_notifications`, `googleapis_auth` | Push notification SOS (FCM HTTP v1) dan stream riwayat SOS Firestore |
| **Jaringan dan Penyimpanan** | `http`, `flutter_secure_storage`, `shared_preferences` | Klien REST API, penyimpanan token aman, cache doa offline, dan preferensi huruf |
| **Konfigurasi dan Izin** | `flutter_dotenv`, `permission_handler` | Variabel lingkungan `.env` dan izin lokasi, mikrofon, kamera, serta notifikasi |

---

## Panduan Memulai

### Prasyarat
1. **Flutter SDK** `>= 3.0.0` dan **Dart SDK** `>= 3.0.0`.
2. **Android Studio** (Android SDK / perangkat fisik) atau **Xcode** untuk iOS.
3. **Git**.

### Langkah Instalasi
1. **Clone repositori dan pasang dependensi:**
   ```bash
   git clone https://github.com/<your-username>/belajar_mabrur.git
   cd belajar_mabrur
   flutter pub get
   ```
2. **Siapkan berkas `.env`** (salin dari `.env.example`, jangan di-commit):
   ```env
   API_BASE_URL=https://albirr.web.id/api
   API_KEY=your_api_key_here
   ZEGO_APP_ID=your_zego_app_id
   ZEGO_APP_SIGN=your_zego_app_sign
   ```
3. **Siapkan konfigurasi rahasia lokal (semua sudah masuk `.gitignore`):**
   - **Android:** tempatkan `google-services.json` di `android/app/` dan tambahkan `GOOGLE_MAPS_API_KEY=...` di `android/local.properties`. Untuk build rilis Play Store, tambahkan `android/key.properties` dan keystore `.jks`.
   - **iOS:** tempatkan `GoogleService-Info.plist` di `ios/Runner/`.
   - **FCM SOS:** tempatkan `service_account.json` di `assets/service_account.json`.
4. **Jalankan aplikasi dan pengujian:**
   ```bash
   flutter analyze --no-pub
   flutter test
   flutter run
   ```

---

## Izin Akses Perangkat
- **Lokasi (`ACCESS_FINE_LOCATION`, `ACCESS_COARSE_LOCATION`):** memperoleh koordinat GPS untuk peta dan sinyal darurat SOS.
- **Mikrofon (`RECORD_AUDIO`):** berbicara pada ruang audio bimbingan.
- **Notifikasi (`POST_NOTIFICATIONS`):** menerima peringatan SOS grup secara langsung.
- **Internet dan Jaringan (`INTERNET`, `ACCESS_NETWORK_STATE`):** sinkronisasi panduan doa, autentikasi, ruang audio, dan sinyal SOS.

---

## Alur Kerja Git
- `main`: branch rilis stabil.
- `dev`: branch integrasi pengembangan.
- `feature/*`: branch fitur atau perbaikan sebelum digabung ke `dev`.

---

## Lisensi
Hak cipta dimiliki oleh pengembang dan inisiator **Belajar Mabrur / Albirr**.

# DESIGN.md: Belajar Mabrur (Albirr)

## Design Read

Reading this as: Aplikasi mobile pendamping ibadah Haji dan Umrah untuk jamaah dan pembimbing (Muthawif), dengan gaya utilitas ibadah yang tenang, tegas, dan mudah dibaca di bawah cahaya terang, dial ENERGY 1 / RHYTHM 2 / MOTION 1.

Dial: ENERGY 1 / RHYTHM 2 / MOTION 1

- **ENERGY 1 (Calm)**: Antarmuka tenang, tidak ramai dekorasi, menjaga fokus dan kekhusyukan ibadah.
- **RHYTHM 2 (Balanced)**: Struktur layar konsisten antar tab dengan variasi komposisi yang jelas sesuai tugas layar (daftar doa, peta darurat, ruang audio, profil).
- **MOTION 1 (Hover / Tap Feedback Only)**: Umpan balik sentuhan yang cepat dan jelas tanpa animasi dekoratif berulang atau pengalih perhatian.

## Brand Identity & Personality

- **Produk**: Belajar Mabrur (Albirr), pendamping ibadah Haji dan Umrah.
- **Audiens**: Jamaah (termasuk pengguna lanjut usia yang membaca teks Arab di luar ruangan) dan pembimbing ibadah (Host / Muthawif) yang memantau grup secara real-time.
- **Motif Identitas**: Garis arsitektural bersih dari logo Albirr (Ka'bah, kubah, dan bulan sabit dalam Merah Marun `#A01C1C`) dipadukan ruang kosong terstruktur dan satu aksen emas hangat untuk penanda khusus.
- **Mode Tema (R-21)**: **Light Mode saja**. Keputusan produk: aplikasi dipakai di luar ruangan di bawah sinar matahari terang (area Masjidil Haram, Masjid Nabawi, Arafah, Mina), sehingga latar terang berkontras tinggi lebih mudah dibaca dibanding tema gelap.

## Color Palette (Terverifikasi WCAG AA via `contrast-check.py`)

Aktif maksimal 2 warna inti + netral + 1 aksen disengaja (R-29).

### Core & Neutral
- **Primary (Merah Marun Albirr)**: `#A01C1C`
  - di atas `#FFFFFF`: 7.84:1 (PASS AAA)
  - di atas `#FAFAF8`: 7.50:1 (PASS AAA)
  - di atas `#F5F5F5`: 7.19:1 (PASS AAA)
- **Background Utama**: `#FFFFFF`
- **Background Sekunder (Netral Hangat)**: `#FAFAF8`
- **Surface Kartu**: `#F5F5F5`
- **Border Halus**: `#E0DDD8` (elemen pemisah non-teks) dan `#BDBDBD` (batas input yang memerlukan kejelasan)
- **Text Primary**: `#1F1F1F` (mendekati hitam pekat tanpa silau berlebih)
- **Text Secondary**: `#616161`
  - di atas `#FFFFFF`: 6.19:1 (PASS AA)
  - di atas `#F5F5F5`: 5.68:1 (PASS AA)
- **Text di atas Primary**: `#FFFFFF` (7.84:1 PASS) dan `#F5E8E8` untuk subjudul (6.57:1 PASS)

### Deliberate Accent (1 Warna, Penggunaan Terbatas)
- **Warm Gold**: `#8A6300`
  - di atas `#FFFFFF`: 5.43:1 (PASS AA)
  - di atas `#FAFAF8`: 5.20:1 (PASS AA)
  - Penggunaan: hanya pada penanda bermakna (misalnya badge peran Host atau penanda kategori aktif tertentu), bukan tersebar di semua tombol atau ikon.

### Semantic Status
- **Success**: latar `#1B6E3A` dengan teks `#FFFFFF` (6.29:1 PASS AA)
- **Error / SOS**: latar `#B71C1C` dengan teks `#FFFFFF` (6.57:1 PASS AA)
- **Info**: teks `#1557B0` di atas latar `#EDF4FC` (6.27:1 PASS AA)
- **Neutral Role Badge**: latar `#455A64` dengan teks `#FFFFFF` (7.24:1 PASS AA)

## Typography

- **UI / Latin**: Tipografi sans-serif bawaan platform (Roboto di Android, SF Pro di iOS) dengan skala jelas dan berat terstruktur agar mudah dibaca di berbagai ukuran layar tanpa beban unduhan font berlebih.
- **Teks Doa Arab**:
  - Wajib menggunakan `TextDirection.rtl` dan perataan kanan (`TextAlign.right`).
  - Tinggi baris (`height`) minimal `1.8` sampai `2.0` agar harakat tidak saling bertumpuk.
  - Mendukung pengatur ukuran huruf (`A-` / `A+`) bagi jamaah lanjut usia serta responsif terhadap pengaturan ukuran teks sistem (font scaling hingga 200%).
- **Aturan**: Hindari huruf kapital penuh dengan spasi lebar dekoratif (`HOW IT WORKS`) dan hindari teks di bawah `12sp` untuk informasi penting.

## Spacing, Radius, & Layout Tokens

- **Spacing Scale**: `4`, `8`, `12`, `16`, `20`, `24`, `32` (basis kelipatan 4px; padding tepi layar standar `16px` pada mobile).
- **Border Radius (R-11, tidak semua pill)**:
  - `sm = 8`: kotak catatan, banner info, badge peran
  - `md = 12`: kartu doa, input teks, tombol utama
  - `lg = 16`: bottom sheet, dialog, panel mengambang
  - `full = 999`: hanya untuk tombol darurat SOS melingkar/kapsul khusus agar langsung dikenali secara fungsional
- **Elevation / Shadow (R-12)**: Permukaan standar rata dengan border halus; bayangan ringan hanya digunakan pada elemen yang benar-benar melayang di atas peta (`MapSosTab` sheet & tombol GPS).
- **Safe Area & Tap Targets (R-03, R-39)**:
  - Setiap kontrol interaktif memiliki area sentuh minimal `44 x 44 px` dengan jarak antar kontrol.
  - Elemen overlay di peta dan header profil wajib menghormati `SafeArea`.

## Copywriting & Interaction Rules

- **Bahasa**: Bahasa Indonesia yang konsisten, sopan, singkat, dan mudah dipahami jamaah (hindari campuran istilah teknis seperti "Zego", "End Room", atau pesan exception mentah).
- **CTA Spesifik (R-15)**: Gunakan label aksi yang jelas ("Masuk", "Daftar Akun", "Gabung Ruang Audio", "Buka Ruang Audio", "Kirim Sinyal SOS", "Coba Lagi").
- **Tanpa Emoji Dekoratif & Tanpa Em Dash (R-02, R-04)**: Gunakan ikon fungsional yang relevan dengan fitur (ikon audio untuk Ruang Audio, bukan kamera video) dan tanda baca standar.
- **UI States Lengkap (R-27)**: Setiap layar yang memuat data menyediakan state memuat (loading), kosong (empty beserta alasan & aksi berikutnya), dan gagal (error dengan bahasa manusiawi & tombol coba lagi).

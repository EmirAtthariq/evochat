# EvoChat — Mobile App

Aplikasi mobile Flutter untuk chatbot AI internal. Menyediakan chat dengan asisten AI berbasis knowledge base, riwayat percakapan, dan helpdesk WhatsApp sesuai domisili cabang.

## Tech Stack

- **Framework**: Flutter (Dart SDK `^3.11.4`)
- **Platform**: Android & iOS (folder `android/` dan `ios/` sudah di-generate, termasuk konfigurasi native splash screen)
- **Routing**: `go_router ^14.0.0`
- **Auth & Session**: `supabase_flutter ^2.0.0`
- **HTTP Client**: `http ^1.2.0`
- **Markdown Rendering**: `flutter_markdown ^0.7.7+1`
- **Typing Indicator**: `simple_typing_indicator ^1.0.1` — animasi titik-titik sebelum token pertama jawaban bot datang
- **Deep Link Eksternal**: `url_launcher ^6.3.1` — buka WhatsApp dari layar Helpdesk
- **Splash Screen**: `flutter_native_splash ^2.4.8`

## Struktur Folder

```
lib/
├── main.dart                    # Entry point, init Supabase, cek sesi awal
├── env_config.dart              # TIDAK ikut ter-commit (gitignored) — isi baseUrl, Supabase URL & publishable key
├── env_config.dart.example      # Template untuk env_config.dart, ini yang ter-commit
├── app/
│   ├── router.dart              # Konfigurasi go_router
├── screens/
│   ├── login_screen.dart        # Login page
│   ├── dashboard_screen.dart    # Home, greeting dinamis sesuai jam, sidebar info user & logout
│   ├── chat_screen.dart         # Chat dengan riwayat, streaming, feedback, typing indicator
│   └── helpdesk_screen.dart     # Kontak WhatsApp sesuai domisili
├── services/
│   ├── chat_service.dart        # Kirim pesan, streaming, riwayat, hapus percakapan, feedback up/down
│   ├── helpdesk_service.dart    # Ambil kontak WhatsApp sesuai domisili
│   └── profile_service.dart     # Ambil data profil user (nama, email, domisili)
└── widgets/
    └── app_bar.dart             # AppBar custom (EvoChatAppBar)
```

## Setup

### 1. Install dependency

```
flutter pub get
```

### 2. Konfigurasi environment (Supabase & base URL)

Kredensial dan `baseUrl` sudah disentralisasi di `lib/env_config.dart`, yang **tidak ikut ter-commit** (masuk `.gitignore`). Copy dari template lalu isi nilai asli:

```bash
cp lib/env_config.dart.example lib/env_config.dart
```

Isi `lib/env_config.dart`:

```dart
class EnvConfig {
  static const String supabaseUrl = 'https://xxx.supabase.co';
  static const String baseUrl = 'http://192.168.56.1:3000';
  static const String supabasePublishableKey = 'sb_publishable_xxxxx'; // publishable key, BUKAN secret key
}
```

`main.dart` dan ketiga screen (`chat_screen.dart`, `dashboard_screen.dart`, `helpdesk_screen.dart`) sama-sama import `EnvConfig` dan pakai `EnvConfig.baseUrl` / `EnvConfig.supabaseUrl` / `EnvConfig.supabasePublishableKey` — jadi ganti satu file ini cukup untuk switch environment (dev/staging/prod) tanpa edit source code lain. Gunakan IP jaringan lokal (bukan `localhost`) untuk `baseUrl` kalau testing dari emulator/device fisik.

### 3. Splash screen (opsional, jika logo berubah)

```
dart run flutter_native_splash:create
```

### 4. Jalankan aplikasi

```
flutter run
```

## Alur Autentikasi

1. `main.dart` mengecek sesi Supabase yang tersimpan sebelum `runApp()`
2. Sesi valid → `initialLocation = '/dashboard'`; tidak valid → `/login`
3. Login pakai `supabase.auth.signInWithPassword()`
4. `accessToken` dikirim sebagai header `Authorization: Bearer <token>` di setiap request ke API backend

## Fitur Utama

### Dashboard

- Greeting dinamis sesuai jam saat ini: "Selamat pagi/siang/sore/malam" (berdasarkan `DateTime.now().hour`)
- Nama, email, domisili dari `/api/profile`; gagal dimuat → auto-retry sekali, lalu tombol "Coba lagi" manual
- Sidebar: info akun, 5 percakapan terakhir (tap langsung buka di `/chat` dengan `conversationId` lewat `extra`), tombol logout
- Menu kartu ke Chat dan Helpdesk

### Chat

- Kirim pertanyaan, jawaban diterima streaming (real-time per potongan teks)
- Typing indicator (titik-titik animasi) tampil sebelum token pertama datang, hilang otomatis saat `onFirstToken` terpanggil
- Riwayat percakapan per user, dibuka lewat bottom sheet draggable
- Swipe kiri pada riwayat untuk menghapus (dialog konfirmasi, optimistic update, rollback kalau gagal)
- Tombol "Percakapan Baru"
- Jawaban AI dirender markdown
- Pemisah tanggal antar pesan ("Hari Ini", "Kemarin", atau tanggal lengkap)
- **Feedback (👍/👎)**: tiap jawaban bot (kecuali sapaan awal) kirim ke `/api/messages/[id]/feedback`. Tap ulang tombol yang sama = toggle ke `null`. Optimistic update + auto-rollback dan snackbar kalau gagal.
- Setelah stream selesai, app fetch ulang isi percakapan untuk dapat `id` pesan asli dari server — tombol feedback baru aktif setelah itu.

### Helpdesk

- Daftar kontak WhatsApp sesuai domisili cabang user (di-assign manual di tabel `profiles`)
- Tap kontak buka WhatsApp lewat `url_launcher` (`LaunchMode.externalApplication`)

## Model Data Penting

```dart
class ChatMessage {
  String text;
  final bool isUser;
  final DateTime time;
  final bool isWelcomeMessage; // pesan sapaan UI, tidak dikirim ke API
  String? id;                  // id pesan di server, null sampai fetch ulang selesai
  String? feedback;            // 'up' | 'down' | null
}
```

Pesan sapaan pembuka tidak dikirim ke `/api/chat` supaya tidak memengaruhi konsistensi jawaban model.

`ChatService.sendMessage` membedakan `onFirstToken` (matikan typing indicator, mulai bubble baru) dari `onToken` (append token berikutnya ke bubble yang sama) — dan `onDone` yang di-`await` supaya urutan penyimpanan `conversationId` konsisten untuk percakapan baru.

## Troubleshooting

| Gejala | Kemungkinan Penyebab |
|---|---|
| Error 401 saat chat | Sesi login expired atau token tidak terkirim |
| AI menjawab "tidak ada informasi" padahal ada di dokumen | Riwayat percakapan lama tercemar jawaban gagal sebelumnya — mulai percakapan baru |
| Tidak bisa konek ke server | Cek `baseUrl` di `env_config.dart`, pastikan device/emulator satu jaringan dengan server |
| Nama tidak muncul di dashboard | `/api/profile` gagal; sudah retry otomatis 1x, kalau masih gagal tap "Coba lagi" atau cek log `flutter run` |
| Tombol feedback tidak muncul | Wajar untuk pesan baru selesai stream sebelum fetch ulang, atau pesan sapaan awal (tidak punya `id`) |
| Tap feedback tidak tersimpan / balik sendiri | Request ke `/api/messages/[id]/feedback` gagal (401/500) — UI rollback + snackbar error |

## Known Issues

- Belum ada refresh token / auto re-login setelah token expired dalam waktu lama
- Belum ada test suite atau CI

## Roadmap

- [ ] Refresh token / auto re-login
- [ ] Unit/widget test dasar untuk `chat_service.dart` dan alur feedback

# WIP!!!---EvoChat — Mobile App

Aplikasi mobile Flutter untuk chatbot AI. Menyediakan chat dengan asisten AI berbasis knowledge base internal, riwayat percakapan, dan helpdesk WhatsApp sesuai domisili cabang.

## Tech Stack

- **Framework**: Flutter (Dart SDK `^3.11.4`)
- **Platform**: Android & iOS (folder `android/` dan `ios/` sudah di-generate, termasuk konfigurasi native splash screen)
- **Routing**: `go_router`
- **Auth & Session**: `supabase_flutter`
- **HTTP Client**: `http`
- **Markdown Rendering**: `flutter_markdown`
- **Splash Screen**: `flutter_native_splash`
- **URL Launcher**: `url_launcher` (untuk membuka WhatsApp)
- **Indikator mengetik**: `simple_typing_indicator`

## Struktur Folder

```
lib/
├── main.dart                    # Entry point, init Supabase, cek sesi awal
├── app/
│   ├── auth_state.dart          # ChangeNotifier untuk state login (belum dipakai di router/screen manapun)
│   ├── router.dart              # Konfigurasi go_router
├── screens/
│   ├── login_screen.dart        # Login page
│   ├── dashboard_screen.dart    # Home, Menu, sidebar dengan info user & logout
│   ├── chat_screen.dart         # Chat dengan riwayat & percakapan baru
│   └── helpdesk_screen.dart     # Kontak WhatsApp sesuai domisili
├── services/
│   ├── chat_service.dart        # Kirim pesan, streaming, riwayat, hapus percakapan
│   ├── helpdesk_service.dart    # Ambil kontak WhatsApp
│   └── profile_service.dart     # Ambil data profil user
└── widgets/
    └── app_bar.dart             # AppBar custom (EvoChatAppBar)
```

## Setup

### 1. Install dependency

```bash
flutter pub get
```

### 2. Konfigurasi Supabase

Isi kredensial Supabase di `main.dart` (memakai parameter `publishableKey`, bukan `anonKey`):

```dart
await Supabase.initialize(
  url: 'https://xxx.supabase.co',
  publishableKey: 'sb_publishable_xxxxx', // publishable key, BUKAN secret key
);
```

> Saat ini kredensial di atas masih **hardcoded langsung di `main.dart`** (belum pakai `.env`/`--dart-define`), jadi kalau mau ganti project Supabase, edit langsung di file tersebut.

### 3. Konfigurasi base URL server

Base URL server backend saat ini **di-hardcode terpisah di tiap screen** (`ChatScreen`, `DashboardScreen`, `HelpdeskScreen`), bukan di satu tempat terpusat — jadi kalau server pindah alamat, harus diganti manual di ketiga file:

```dart
// lib/screens/chat_screen.dart, dashboard_screen.dart, helpdesk_screen.dart
final _chatService = ChatService(baseUrl: 'http://192.168.56.1:3000');
```

> Catatan: gunakan IP jaringan lokal (bukan `localhost`) jika testing dari emulator/device fisik yang perlu mengakses server di komputer development.

### 4. Splash screen (opsional, jika logo berubah)

```bash
dart run flutter_native_splash:create
```

### 5. Jalankan aplikasi

```bash
flutter run
```

## Alur Autentikasi

1. `main.dart` mengecek sesi Supabase yang tersimpan sebelum `runApp()`
2. Jika sesi valid → langsung ke `/dashboard`, jika tidak → ke `/login`
3. Login menggunakan `supabase.auth.signInWithPassword()`
4. Token sesi (`accessToken`) dikirim sebagai header `Authorization: Bearer <token>` di setiap request ke API backend

## Fitur Utama

### Chat
- Kirim pertanyaan ke chatbot, jawaban diterima secara streaming (real-time, kata per kata)
- Riwayat percakapan tersimpan per user, bisa dibuka kembali lewat ikon riwayat
- Swipe kiri pada riwayat untuk menghapus percakapan
- Tombol "Percakapan Baru" untuk memulai chat dari awal
- Jawaban AI dirender sebagai markdown (bold, list, dll)

### Helpdesk
- Menampilkan daftar kontak WhatsApp sesuai domisili cabang user (di-assign manual di database, tabel `profiles`)
- Tap kontak langsung membuka WhatsApp dengan nomor terkait

### Dashboard
- Menampilkan nama & email user (dari tabel `profiles`)
- Sidebar berisi info akun dan tombol logout
- Menu ke Chat dan Helpdesk

## Model Data Penting

```dart
class ChatMessage {
  String text;
  final bool isUser;
  final bool isWelcomeMessage; // pesan sapaan UI, tidak dikirim ke API
}
```

> Penting: pesan sapaan pembuka ("Halo! Saya asisten EvoChat...") sengaja tidak ikut dikirim sebagai bagian dari history ke `/api/chat`, karena dapat memengaruhi konsistensi jawaban model AI.

## Troubleshooting Umum

| Gejala | Kemungkinan Penyebab |
|---|---|
| Error 401 saat chat | Sesi login expired atau token tidak terkirim |
| AI menjawab "tidak ada informasi" padahal ada di dokumen | Riwayat percakapan lama tercemar jawaban gagal sebelumnya — mulai percakapan baru |
| Tidak bisa konek ke server | Periksa `baseUrl`, pastikan device/emulator satu jaringan dengan server |
| Nama tidak muncul di dashboard | Cek log `flutter run`, kemungkinan `/api/profile` gagal dipanggil sementara |

## Belum Diimplementasikan

- Refresh token / auto re-login setelah token expired dalam waktu lama

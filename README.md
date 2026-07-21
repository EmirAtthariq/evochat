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

## Struktur Folder

``` text
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
│   ├── chat_service.dart        # Kirim pesan, streaming, riwayat, hapus percakapan, kirim feedback up/down
│   ├── helpdesk_service.dart    # Ambil kontak WhatsApp sesuai domisili
│   └── profile_service.dart     # Ambil data profil user (nama, email, domisili)
└── widgets/
    └── app_bar.dart             # AppBar custom (EvoChatAppBar)
```

## Setup

### 1. Install dependency

```bash
flutter pub get
```

### 2. Konfigurasi Supabase

Kredensial Supabase memakai parameter `publishableKey` (bukan `anonKey`):

```dart
await Supabase.initialize(
  url: 'https://xxx.supabase.co',
  publishableKey: 'sb_publishable_xxxxx', // publishable key, BUKAN secret key
);
```

> **Perhatian**: saat ini kredensial di `main.dart` **sudah diisi nilai asli project Supabase (bukan sekadar placeholder)** dan ikut ter-commit ke repo. Ini bukan masalah kebocoran data sensitif karena publishable key memang didesain untuk dipakai di client, tapi sebaiknya tetap dipindah ke `--dart-define`/file env yang di-gitignore supaya gampang ganti project (dev/staging/prod) tanpa edit source code. Kalau mau ganti ke project Supabase lain, edit langsung 2 baris di atas.

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

- Kirim pertanyaan ke chatbot, jawaban diterima secara streaming (real-time, potongan teks per potongan)
- Riwayat percakapan tersimpan per user, bisa dibuka kembali lewat ikon riwayat (bottom sheet draggable)
- Swipe kiri pada riwayat untuk menghapus percakapan (dengan dialog konfirmasi, optimistic update lalu rollback kalau gagal)
- Tombol "Percakapan Baru" untuk memulai chat dari awal
- Jawaban AI dirender sebagai markdown (bold, list, dll)
- Pemisah tanggal antar pesan ("Hari Ini", "Kemarin", atau tanggal lengkap), mirip WhatsApp
- **Feedback jawaban (👍/👎)**: tiap jawaban bot (bukan pesan sapaan awal) punya tombol thumbs up/down yang mengirim ke `/api/messages/[id]/feedback`. Tap ulang tombol yang sama untuk membatalkan feedback (toggle ke `null`). Update dilakukan optimistic di UI dan otomatis rollback + tampilkan snackbar kalau request gagal.
- Setelah jawaban bot selesai di-stream, app langsung fetch ulang isi percakapan supaya dapat `id` pesan asli dari server (dibutuhkan supaya tombol feedback bisa aktif)

### Helpdesk

- Menampilkan daftar kontak WhatsApp sesuai domisili cabang user (di-assign manual di database, tabel `profiles`)
- Tap kontak langsung membuka WhatsApp dengan nomor terkait

### Dashboard

- Menampilkan nama, email, dan domisili user (dari `/api/profile`); kalau gagal dimuat, otomatis retry sekali lalu tampilkan tombol "Coba lagi" manual
- Sidebar (drawer) berisi info akun (nama, email, domisili), **5 percakapan terakhir** (tap langsung membuka percakapan itu di `/chat`), dan tombol logout
- Menu kartu ke Chat dan Helpdesk

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

> Penting: pesan sapaan pembuka ("Halo! Saya asisten EvoChat...") sengaja tidak ikut dikirim sebagai bagian dari history ke `/api/chat`, karena dapat memengaruhi konsistensi jawaban model AI.
>
> `id` pada pesan assistant baru terisi setelah stream selesai dan app fetch ulang `/api/conversations/[id]/messages` — sebelum itu tombol feedback belum bisa ditekan (disembunyikan sampai `id != null`).

## Troubleshooting Umum

| Gejala | Kemungkinan Penyebab |
| --- | --- |
| Error 401 saat chat | Sesi login expired atau token tidak terkirim |
| AI menjawab "tidak ada informasi" padahal ada di dokumen | Riwayat percakapan lama tercemar jawaban gagal sebelumnya — mulai percakapan baru |
| Tidak bisa konek ke server | Periksa `baseUrl`, pastikan device/emulator satu jaringan dengan server |
| Nama tidak muncul di dashboard | `/api/profile` gagal dipanggil; app sudah retry otomatis 1x, kalau masih gagal tap "Coba lagi" atau cek log `flutter run` |
| Tombol feedback (👍/👎) tidak muncul | Wajar untuk pesan yang baru selesai stream sebelum fetch ulang selesai, atau untuk pesan sapaan awal (`isWelcomeMessage`) yang memang tidak punya `id` |
| Tap feedback tidak tersimpan / balik sendiri | Request ke `/api/messages/[id]/feedback` gagal (401/500) — UI otomatis rollback dan tampilkan snackbar error |

## Belum Diimplementasikan

- Refresh token / auto re-login setelah token expired dalam waktu lama

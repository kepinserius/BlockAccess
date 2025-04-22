# BlockAccess - Kartu Akses Blockchain untuk Keamanan Fisik

Aplikasi untuk mengelola akses pintu (gedung, coworking space, lab) berbasis blockchain. Cukup scan QR untuk buka pintu yang diotorisasi oleh smart contract.

## Fitur

- **QR Code Access**: Scan QR unik untuk membuka akses fisik.
- **Blockchain Log**: Semua akses dicatat di kontrak pintar.
- **Multi-Role Access**: Admin bisa memberi/revoke hak akses.
- **Time-Restricted Access**: Akses hanya berlaku di waktu tertentu.
- **Offline Mode**: Cache otorisasi untuk koneksi buruk.
- **Dark Mode**: Tampilan aplikasi yang nyaman di kondisi cahaya rendah.
- **Biometric Authentication**: Keamanan tambahan dengan sidik jari atau Face ID.
- **Location-Based Access**: Akses otomatis saat berada di dekat pintu.
- **Notifications**: Pemberitahuan untuk aktivitas akses.
- **Multi-Language**: Dukungan untuk berbagai bahasa.

## Tech Stack

- **Frontend**: Flutter
- **Blockchain**: Polygon
- **Smart Contract**: Solidity
- **Hardware**: ESP32 sebagai kontrol pintu
- **QR Scanner**: Flutter camera + QR plugin
- **Backend Services**: Firebase (Authentication, Firestore, Storage)

## Struktur Proyek

- `app/` - Aplikasi Flutter
- `contracts/` - Smart contracts Solidity
- `hardware/` - Kode untuk ESP32

## Panduan Instalasi

### Prasyarat

1. **Flutter SDK**
   - Unduh dan instal Flutter SDK dari [flutter.dev](https://flutter.dev/docs/get-started/install)
   - Tambahkan Flutter ke PATH sistem Anda
   - Verifikasi instalasi dengan perintah: `flutter doctor`

2. **Android Studio / Visual Studio Code**
   - Android Studio: [developer.android.com/studio](https://developer.android.com/studio)
   - Visual Studio Code: [code.visualstudio.com](https://code.visualstudio.com/)
   - Instal plugin Flutter dan Dart di IDE pilihan Anda

3. **NodeJS dan NPM**
   - Unduh dan instal dari [nodejs.org](https://nodejs.org/)
   - Verifikasi instalasi: `node -v` dan `npm -v`

4. **Truffle atau Hardhat** (untuk smart contract)
   - Instal Truffle: `npm install -g truffle`
   - Atau instal Hardhat: `npm install -g hardhat`

5. **Arduino IDE** (untuk ESP32)
   - Unduh dan instal dari [arduino.cc](https://www.arduino.cc/en/software)
   - Tambahkan dukungan ESP32 melalui Board Manager

### Menyiapkan Aplikasi Flutter

1. **Instal Dependensi**
   ```bash
   cd app
   flutter pub get
   ```

2. **Konfigurasi Environment**
   - Buat file `.env` di direktori `app/` dengan konten:
   ```
   POLYGON_RPC_URL=https://rpc-mumbai.maticvigil.com/
   CONTRACT_ADDRESS=YOUR_CONTRACT_ADDRESS
   ```

3. **Jalankan Aplikasi**
   ```bash
   flutter run
   ```

### Menyiapkan Firebase

1. **Buat Proyek Firebase**
   - Kunjungi [Firebase Console](https://console.firebase.google.com/)
   - Klik "Add project" dan ikuti petunjuk

2. **Tambahkan Aplikasi ke Firebase**
   - Di dashboard Firebase, klik ikon Android/iOS
   - Ikuti petunjuk untuk mendaftarkan aplikasi
   - Unduh file konfigurasi (`google-services.json` untuk Android, `GoogleService-Info.plist` untuk iOS)

3. **Tempatkan File Konfigurasi**
   - Android: Simpan `google-services.json` di `app/android/app/`
   - iOS: Simpan `GoogleService-Info.plist` di `app/ios/Runner/`

4. **Aktifkan Layanan Firebase**
   - Authentication: Aktifkan metode Email/Password dan Google
   - Firestore Database: Buat database di mode test
   - Storage: Siapkan bucket penyimpanan

### Deploy Smart Contract

1. **Siapkan Akun Polygon**
   - Buat akun di [MetaMask](https://metamask.io/)
   - Tambahkan jaringan Mumbai Testnet
   - Dapatkan MATIC testnet dari [faucet](https://faucet.polygon.technology/)

2. **Konfigurasi Deployment**
   - Buat file `.env` di direktori root dengan:
   ```
   PRIVATE_KEY=YOUR_WALLET_PRIVATE_KEY
   POLYGON_MUMBAI_RPC_URL=https://rpc-mumbai.maticvigil.com/
   ```

3. **Deploy Kontrak**
   - Menggunakan Truffle:
   ```bash
   cd contracts
   truffle migrate --network mumbai
   ```
   - Atau menggunakan Hardhat:
   ```bash
   cd contracts
   npx hardhat run scripts/deploy.js --network mumbai
   ```

4. **Perbarui Alamat Kontrak**
   - Salin alamat kontrak yang di-deploy
   - Perbarui `CONTRACT_ADDRESS` di file `.env` aplikasi

### Menyiapkan ESP32

1. **Instal Library yang Diperlukan**
   - Buka Arduino IDE
   - Instal library berikut melalui Library Manager:
     - WiFi
     - HTTPClient
     - ArduinoJson
     - QRCode
     - Adafruit GFX
     - Adafruit SSD1306

2. **Konfigurasi ESP32**
   - Buka file `hardware/esp32_door_controller/esp32_door_controller.ino`
   - Perbarui konfigurasi berikut:
   ```cpp
   const char* ssid = "YourWiFiSSID";
   const char* password = "YourWiFiPassword";
   const char* apiUrl = "https://your-api-endpoint.com/check-access";
   const char* apiKey = "your-api-key";
   String deviceId = "esp32-001";
   String doorId = "1";
   String doorName = "Main Entrance";
   ```

3. **Upload ke ESP32**
   - Hubungkan ESP32 ke komputer
   - Pilih board dan port yang benar di Arduino IDE
   - Klik tombol Upload

## Panduan Penggunaan

### Untuk Pengguna

1. **Login**
   - Buka aplikasi BlockAccess
   - Masukkan alamat wallet atau gunakan akun demo
   - Untuk pengujian, gunakan "0x1234567890abcdef" sebagai alamat wallet

2. **Melihat Akses**
   - Tab "My Access" menampilkan semua akses yang Anda miliki
   - Tab "Doors" menampilkan semua pintu yang tersedia
   - Tab "History" menampilkan riwayat akses Anda

3. **Menggunakan Akses**
   - Klik tombol "Scan QR" di layar utama
   - Arahkan kamera ke kode QR pada pintu
   - Sistem akan memverifikasi akses Anda
   - Jika diizinkan, pintu akan terbuka

4. **Melihat Profil**
   - Klik ikon profil di menu navigasi
   - Lihat statistik akses Anda
   - Kelola pengaturan keamanan

5. **Berbagi Akses**
   - Klik menu "Share Access"
   - Pilih pintu yang ingin dibagikan
   - Masukkan ID penerima
   - Tentukan periode akses
   - Klik "Generate QR Code"
   - Bagikan kode QR dengan penerima

### Untuk Admin

1. **Login sebagai Admin**
   - Gunakan alamat wallet dengan akhiran "admin"
   - Untuk pengujian, gunakan "0x1234567890abcdefadmin"

2. **Mengelola Akses**
   - Buka panel Admin dari menu navigasi
   - Tab "Grant Access" untuk memberikan akses baru
   - Tab "Manage Access" untuk mengelola akses yang ada
   - Tab "Access Logs" untuk melihat semua log akses

3. **Memberikan Akses**
   - Pilih pengguna (masukkan ID)
   - Pilih pintu dari daftar
   - Tentukan periode akses (tanggal mulai dan berakhir)
   - Klik "Grant Access"

4. **Mencabut Akses**
   - Buka tab "Manage Access"
   - Temukan akses yang ingin dicabut
   - Klik tombol "Revoke Access"

5. **Melihat Log**
   - Buka tab "Access Logs"
   - Filter log berdasarkan pintu, pengguna, atau tanggal
   - Klik pada log untuk melihat detail

## Pengembangan Lanjutan

### Menambahkan Pintu Baru

1. **Di Aplikasi**
   - Tambahkan data pintu baru di `access_provider.dart`

2. **Di Smart Contract**
   - Panggil fungsi untuk mendaftarkan pintu baru

3. **Di ESP32**
   - Konfigurasi ESP32 baru dengan ID dan nama pintu yang sesuai

### Kustomisasi UI

- Tema dan warna dapat diubah di `app_theme.dart`
- Animasi dapat disesuaikan di folder `animations/`

### Menambahkan Fitur Baru

- Ikuti struktur provider-screen yang ada
- Tambahkan provider baru untuk logika bisnis
- Tambahkan screen baru untuk antarmuka pengguna

## Troubleshooting

### Aplikasi Flutter

- **Masalah Dependensi**: Jalankan `flutter clean` lalu `flutter pub get`
- **Masalah Firebase**: Verifikasi file konfigurasi dan aktifkan layanan yang diperlukan
- **Masalah Koneksi Blockchain**: Periksa alamat kontrak dan RPC URL

### ESP32

- **Masalah Koneksi WiFi**: Verifikasi SSID dan password
- **Masalah API**: Periksa URL dan kunci API
- **Masalah Hardware**: Periksa koneksi pin dan komponen

### Smart Contract

- **Masalah Deployment**: Pastikan ada cukup MATIC untuk gas
- **Masalah Transaksi**: Periksa log error dan gas limit

## Lisensi

Proyek ini dilisensikan di bawah MIT License - lihat file LICENSE untuk detail.

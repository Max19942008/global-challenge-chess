# Global Challenge Chess

| Papka | Vazifasi |
| --- | --- |
| `packages/chess-core` | Umumiy paket: chess.js o'ramasi, soat hisobi, WebSocket protokoli turlari (`v: 1`). Server va veb mijoz aynan shu kodni ishlatadi. |
| `apps/server` | Onlayn o'yin serveri: raqib qidirish, bot taklifi, serverdagi soat, Glicko-2 reyting, qayta ulanish. Redis + Postgres. [README](apps/server/README.md) |
| `apps/mobile` | Flutter ilova (Android/iOS, brauzerda sinash uchun web). Uch til (uz/ru/en), bot (Stockfish 19), ikki kishi, onlayn o'yin. |
| `apps/web` | Birinchi bosqichdagi Next.js veb versiya (bot + ikki kishi, faqat o'zbekcha). |
| `docs/protocol.md` | WebSocket protokoli — server va har qanday mijoz uchun shartnoma. |

## Yangi kompyuterda sozlash

Kerakli dasturlar:

| Dastur | Versiya |
| --- | --- |
| Git | istalgan |
| Node.js | 24 |
| Flutter | 3.47.9 (boshqa versiyada kutubxonalar mos kelmasligi mumkin) |
| JDK | 17 |
| Android Studio | Android SDK + NDK 28.2 |
| Chrome | ilovani brauzerda sinash uchun |

`flutter doctor` nima yetishmayotganini ko'rsatadi.

```bash
git clone https://github.com/Max19942008/global-challenge-chess.git
cd global-challenge-chess
npm install
cd apps/mobile
flutter pub get
```

Ishni sinxron saqlash: ish boshida `git pull`, oxirida `git push`.

## Imzo kaliti

Kalit repo'da **yo'q** va bo'lmasligi kerak. Release build uchun ikki fayl kerak:

- `upload-keystore.jks` — kalitning o'zi (istalgan papkada, repo'dan tashqarida);
- `apps/mobile/android/key.properties` — parollar va kalit yo'li:

```properties
storePassword=...
keyPassword=...
keyAlias=upload
storeFile=C:/yo'l/upload-keystore.jks
```

Yangi kompyuterda: ikkala faylni ko'chiring va `storeFile` ni yangi joyga o'zgartiring.

Yangi kalit yaratish (masalan, eskisi kerak bo'lmasa):

```bash
keytool -genkeypair -v -keystore upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

- **Play'ga birinchi yuklashdan oldin** kalitni istalgancha almashtirish mumkin — Google uni birinchi AAB bilan qayd qiladi.
- **Keyin** kalit yo'qolsa: Play App Signing yoqilgan (yangi ilovalarda majburiy), shuning uchun Play Console → *Test and release → App integrity → Upload key certificate* → **Request upload key reset**. Google 1–2 kunda yangi kalitni tasdiqlaydi.
- Kalitning zaxira nusxasini kamida ikki joyda saqlang (masalan, fleshka va shaxsiy bulut).

## Ishga tushirish

```bash
npm install
npm run server                         # ws://localhost:8080
cd apps/mobile
flutter run -d chrome --wasm           # ilova brauzerda
flutter test                           # ilova testlari (server yoqiq bo'lsa, integratsiya testi ham)
npm test                               # (repo ildizida) chess-core + server testlari
```

## Telefonda sinash (bitta Wi-Fi'da)

```bash
flutter build apk --release --split-per-abi --dart-define=SERVER_URL=ws://<kompyuter IP>:8080
```

## Google Play uchun

Server internetda, HTTPS bilan turishi kerak (`apps/server/README.md` → Deploy). Keyin:

```bash
flutter build appbundle --release --dart-define=SERVER_URL=wss://<server domeni>
```

Imzo kaliti `C:\Users\BSP_017\shaxmat-keys\` da (repo'da emas). Paket nomi: `com.globalchallenge.chess`.

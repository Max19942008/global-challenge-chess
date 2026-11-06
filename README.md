# Global Challenge Chess

| Papka | Vazifasi |
| --- | --- |
| `packages/chess-core` | Umumiy paket: chess.js o'ramasi, soat hisobi, WebSocket protokoli turlari (`v: 1`). Server va veb mijoz aynan shu kodni ishlatadi. |
| `apps/server` | Onlayn o'yin serveri: raqib qidirish, bot taklifi, serverdagi soat, Glicko-2 reyting, qayta ulanish. Redis + Postgres. [README](apps/server/README.md) |
| `apps/mobile` | Flutter ilova (Android/iOS, brauzerda sinash uchun web). Uch til (uz/ru/en), bot (Stockfish 19), ikki kishi, onlayn o'yin. |
| `apps/web` | Birinchi bosqichdagi Next.js veb versiya (bot + ikki kishi, faqat o'zbekcha). |
| `docs/protocol.md` | WebSocket protokoli — server va har qanday mijoz uchun shartnoma. |

## Ishga tushirish (shu kompyuterda)

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

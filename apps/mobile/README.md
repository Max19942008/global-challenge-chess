# Global Challenge Chess — Flutter app

Android, iOS and web (for trying it on a PC).

```
lib/
  main.dart, main_app.dart   entry point, theme, localization
  locale_controller.dart     saved language (uz / ru / en)
  game/                      rules on top of dartchess
  engine/                    Stockfish bot (native on phones, WASM in a browser)
  online/                    WebSocket client, lobby, online game screen
  screens/                   menu, language picker, bot / two-player game
  ui/                        theme, shared widgets, game layout
  l10n/                      translations (ARB) and generated code
```

## Run

```bash
flutter run                               # phone or emulator
flutter run -d chrome --wasm              # browser (WASM is required by dartchess)
flutter test
```

The game server address is set at build time (default `ws://localhost:8080`):

```bash
flutter build apk --release --split-per-abi --dart-define=SERVER_URL=ws://<PC IP>:8080
flutter build appbundle --release --dart-define=SERVER_URL=wss://<server domain>
```

Release signing reads `android/key.properties` (not in the repository).

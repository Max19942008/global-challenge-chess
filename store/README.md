# Google Play materiallari

| Fayl | Play Console'da qayerga |
| --- | --- |
| `listing-en.md`, `listing-uz.md`, `listing-ru.md` | Main store listing → nom, qisqa va to'liq tavsif (har til uchun "Manage translations") |
| `../apps/mobile/store/icon-512.png` | App icon (512×512) |
| `feature-graphic-{en,uz,ru}.png` | Feature graphic (1024×500) |
| `screenshots/{en,uz,ru}/*.png` | Phone screenshots (1080×2160, 5 ta: menyu, lobbi, reyting, AI bilan, onlayn). Qayta yaratish: `apps/mobile` da `flutter test tool/store_screenshots_test.dart --update-goldens` |
| `../docs/privacy.md` | Privacy policy — URL: https://max19942008.github.io/global-challenge-chess/privacy |

## Store settings
- **App or game:** Game · **Category:** Board
- **Free**, reklama yo'q (Contains ads: **No**)
- **Contact email:** bobur.rakhimboevv@gmail.com
- **Website:** https://github.com/Max19942008/global-challenge-chess

## App content javoblari

**Privacy policy:** yuqoridagi URL.

**Ads:** No.

**App access:** All functionality is available without special access (login yo'q).

**Target audience:** 13+ (13–15, 16–17, 18+). 13 yoshdan kichiklarni tanlamang — "Families" siyosati qo'shimcha talablar qo'yadi.

**Content rating (IARC anketasi):** kategoriya *Game*. Zo'ravonlik, qo'rqinchli, jinsiy, so'kinish, giyohvand, qimor — hammasiga **No**. "Users can interact" — **Yes** (onlayn raqib bilan o'ynash va chaqiruv yuborish; chat yo'q, lekin o'yinchi o'zi tanlagan ism va profil rasmi boshqalarga ko'rinadi). "Shares location" — No. "Digital purchases" — No. Kutiladigan natija: PEGI 3 / Everyone (interaktiv elementlar belgisi bilan).

**Data safety:**
- Does your app collect or share user data? **Yes** (collect), share — **No** (boshqa o'yinchilar ilova ichida ko'rishi "sharing" hisoblanmaydi; uchinchi tomonga hech narsa berilmaydi)
- Encrypted in transit: **Yes** (`wss://` / `https://`)
- Users can request deletion: **Yes** (privacy policy'dagi email; rasmni ilovaning o'zida o'chirish mumkin)
- Yig'iladigan turlar:
  - *Personal info → User IDs* (mehmon ID) — Collected, not shared, **required**, purpose: **App functionality, Account management**
  - *Personal info → Name* (o'yinchi ko'rinadigan ismi/taxallusi; avtomatik "Guest-…", o'zgartirsa bo'ladi) — Collected, not shared, **required**, purpose: **App functionality, Account management**
  - *Photos and videos → Photos* (profil rasmi, faqat o'zi qo'shsa) — Collected, not shared, **optional**, purpose: **App functionality, Account management**
  - *App activity → App interactions* (onlayn o'yin yurishlari, natijalar, g'alaba/mag'lubiyat soni, lobbidagi holat) — Collected, not shared, **required**, purpose: **App functionality**
- Boshqa hech narsa (joylashuv, kontaktlar, email, telefon, qurilma ID, analitika) yo'q.
- Ephemeral? — **No** (ma'lumotlar serverda saqlanadi).

**Government app:** No. **Financial features:** None. **Health:** No. **News:** No.

## Yuklashdan oldin
1. Server internetda, `wss://` bilan ishlashi kerak — https://worldchesschallenge.online (deploy: `deploy/README.md`).
2. AAB: `flutter build appbundle --release --dart-define=SERVER_URL=wss://worldchesschallenge.online/ws`
3. Shaxsiy (personal) developer akkaunt bo'lsa: avval **Closed testing**, kamida 12 tester, 14 kun.

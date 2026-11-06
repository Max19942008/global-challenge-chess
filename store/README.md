# Google Play materiallari

| Fayl | Play Console'da qayerga |
| --- | --- |
| `listing-en.md`, `listing-uz.md`, `listing-ru.md` | Main store listing → nom, qisqa va to'liq tavsif (har til uchun "Manage translations") |
| `../apps/mobile/store/icon-512.png` | App icon (512×512) |
| `feature-graphic-{en,uz,ru}.png` | Feature graphic (1024×500) |
| `screenshots/{en,uz,ru}/*.png` | Phone screenshots (1080×1920, 4 ta) |
| `../docs/privacy.md` | Privacy policy — URL: https://max19942008.github.io/global-challenge-chess/privacy |

## Store settings
- **App or game:** Game · **Category:** Board
- **Free**, reklama yo'q (Contains ads: **No**)
- **Contact email:** o'zingizning emailingiz (majburiy, sahifada ko'rinadi)
- **Website:** https://github.com/Max19942008/global-challenge-chess

## App content javoblari

**Privacy policy:** yuqoridagi URL.

**Ads:** No.

**App access:** All functionality is available without special access (login yo'q).

**Target audience:** 13+ (13–15, 16–17, 18+). 13 yoshdan kichiklarni tanlamang — "Families" siyosati qo'shimcha talablar qo'yadi.

**Content rating (IARC anketasi):** kategoriya *Game*. Zo'ravonlik, qo'rqinchli, jinsiy, so'kinish, giyohvand, qimor — hammasiga **No**. "Users can interact" — **Yes** (onlayn raqib bilan o'ynash; chat yo'q, faqat avtomatik ism ko'rinadi). "Shares location" — No. "Digital purchases" — No. Kutiladigan natija: PEGI 3 / Everyone.

**Data safety:**
- Does your app collect or share user data? **Yes** (collect), share — **No**
- Encrypted in transit: **Yes** (server `wss://` bo'lganda)
- Users can request deletion: **Yes** (privacy policy'dagi havola)
- Yig'iladigan turlar:
  - *Personal info → User IDs* — Collected, not shared, required, purpose: **App functionality, Account management**
  - *App activity → App interactions* (onlayn o'yin yurishlari va natijalari) — Collected, not shared, required, purpose: **App functionality**
- Boshqa hech narsa (joylashuv, kontaktlar, qurilma ID, analitika) yo'q.

**Government app:** No. **Financial features:** None. **Health:** No. **News:** No.

## Yuklashdan oldin
1. Server internetda, `wss://` bilan ishlashi kerak.
2. AAB: `flutter build appbundle --release --dart-define=SERVER_URL=wss://<domen>`
3. Shaxsiy (personal) developer akkaunt bo'lsa: avval **Closed testing**, kamida 12 tester, 14 kun.

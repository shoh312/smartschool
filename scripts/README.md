# Maktab kompyuterini avtomatik ishlatish

Bu papka SmartSchool ni maktabda **qarovsiz** ishlatish uchun. Maqsad
bitta: har kuni akademiyaga borib o'tirmaslik.

Nimadan himoya qiladi:

| Nima bo'ladi | Ilgari | Endi |
|---|---|---|
| Elektr o'chib yonadi | tizim o'lik qoladi | o'zi ko'tariladi |
| Windows yangilanib qayta yuklanadi | tizim o'lik qoladi | o'zi ko'tariladi |
| Server ichidan buziladi | tizim o'lik qoladi | nazoratchi qayta ko'taradi |
| Kamera oqimi uziladi | — | kod o'zi qayta ulanadi |
| Kamera jim bo'lib qoladi | hech kim bilmaydi | Telegramga xabar keladi |
| Disk buziladi | hamma narsa ketadi | kechagi zaxira bor |

---

## 1. O'rnatish (bir marta, maktab kompyuterida)

**Administrator** huquqi bilan PowerShell oching va:

```powershell
powershell -ExecutionPolicy Bypass -File C:\...\smartschool\scripts\install_service.ps1
```

To'rtta Windows vazifasi yaratiladi:

| Vazifa | Qachon |
|---|---|
| `SmartSchool Backend` | kompyuter yonganda, doim |
| `SmartSchool PublicServer` | kompyuter yonganda, doim |
| `SmartSchool Healthcheck` | har 10 daqiqada |
| `SmartSchool Backup` | har kuni soat 02:00 |

Serverlar **SYSTEM** nomidan ishlaydi. Bu ataylab: maktabda elektr kelganda
kompyuter o'zi yonadi, lekin hech kim kelib parol kiritmaydi. Foydalanuvchi
hisobiga bog'langan vazifa esa ertalabgacha kutib turardi.

PostgreSQL bilan navbat maxsus sozlanmagan. Kompyuter yonganda baza hali
tayyor bo'lmasligi mumkin — nazoratchi shunchaki qayta uriradi va baza
tayyor bo'lgan zahoti server ko'tariladi. Ya'ni kutish vaqtini taxmin qilish
kerak emas.

Darhol ishga tushirish (qayta yuklamasdan):

```powershell
Start-ScheduledTask -TaskName 'SmartSchool Backend'
Start-ScheduledTask -TaskName 'SmartSchool PublicServer'
```

Tekshirish:

```powershell
Get-ScheduledTask -TaskName 'SmartSchool*' | Select-Object TaskName, State
```

Olib tashlash:

```powershell
powershell -ExecutionPolicy Bypass -File scripts\install_service.ps1 -Uninstall
```

---

## 2. Telegram xabarlari

Ularsiz ham hammasi ishlaydi — faqat nosozlikni o'zingiz jurnaldan
qidirasiz. Xabar bo'lsa, o'qituvchidan oldin siz bilasiz.

**Bot yaratish:**

1. Telegramda [@BotFather](https://t.me/BotFather) ga yozing → `/newbot`
2. Nom bering → sizga token beradi (`123456789:AAA...` ko'rinishida)
3. O'z botingizga bitta xabar yozing (aks holda u sizga yoza olmaydi)
4. `chat_id` ni olish: brauzerda
   `https://api.telegram.org/bot<TOKEN>/getUpdates` ni oching va
   `"chat":{"id":...}` ni toping

**Sozlash:**

```powershell
Copy-Item scripts\alerts.example.json scripts\alerts.json
notepad scripts\alerts.json
```

```json
{
  "school_name": "Akademiya nomi",
  "telegram_bot_token": "123456789:AAA...",
  "telegram_chat_id": "123456789"
}
```

Sinash:

```powershell
powershell -ExecutionPolicy Bypass -File scripts\healthcheck.ps1
Get-Content logs\healthcheck.log -Tail 5
```

`alerts.json` ichida token bor — u `.gitignore` da, hech qachon
repozitoriyga tushmaydi.

**Nima tekshiriladi:** ikkala server, kamera faolligi (dars vaqtida 90
daqiqa hech kimni ko'rmasa), zaxira yoshi (48 soatdan eski bo'lsa), disk
joyi (5 GB dan kam bo'lsa).

**Nechta xabar keladi:** buzilganda bitta, tuzalganda bitta, va buzuq
holatda qolsa sutkasiga bitta eslatma. Har 10 daqiqada emas — aks holda
telefoningiz kunda 144 ta xabar olardi va siz ularni o'qishni bas qilardingiz.

---

## 3. Masofadan kirish

Buzilganda mashinaga o'tirmaslik uchun. **RustDesk** tavsiya qilaman —
bepul, ochiq kodli, o'rnatish oson.

Maktab kompyuterida:

```powershell
winget install --id RustDesk.RustDesk
```

Keyin RustDesk oynasida:

1. **Doimiy parol** qo'ying (Settings → Security → Permanent password) —
   aks holda har safar kimdir kompyuter oldida turib parolni aytishi kerak
2. Kompyuter ID sini yozib oling
3. Avtomatik ishga tushishni yoqing (Settings → General → Start on boot)

Muqobil: **AnyDesk** (xuddi shunday), yoki **Tailscale** (butun tarmoqqa
kirish, lekin sozlash murakkabroq).

Xavfsizlik: parolni kuchli qiling va hech kimga bermang. Bu kompyuterda
150 bolaning ma'lumoti bor.

---

## 4. Zaxira nusxa

Har kecha 02:00 da avtomatik. Ikkala baza va yuz suratlari olinadi,
14 kunlik tarix saqlanadi.

Qo'lda olish:

```powershell
powershell -ExecutionPolicy Bypass -File scripts\backup.ps1
```

Boshqa diskka (**tavsiya qilinadi** — bir disk buzilsa ikkalasi ham
ketmasin):

```powershell
powershell -ExecutionPolicy Bypass -File scripts\backup.ps1 -Destination D:\smartschool-backups
```

Tiklash (diqqat — ustiga yozadi):

```powershell
psql -U postgres -d smartschool -f <fayl>.sql
```

---

## 5. Muammo bo'lsa qayerga qarash kerak

Hammasi `logs\` papkasida:

| Fayl | Nima yozilgan |
|---|---|
| `backend.supervisor.log` | server necha marta qayta ko'tarilgan |
| `backend.err.log` | serverning o'z xatolari |
| `public_server.supervisor.log` | ochiq server nazoratchisi |
| `healthcheck.log` | har 10 daqiqalik tekshiruv natijasi |

Birinchi qaraydigan joy — `*.supervisor.log`. Agar u yerda har necha
daqiqada "qayta uriniladi" yozilgan bo'lsa, server ko'tarila olmayapti va
sababi `*.err.log` da turadi.

---

## Maktabga aytiladigan narsa

Texnika hammasini hal qilmaydi. Akademiyada **bitta mas'ul odam** bo'lsin,
uning yagona vazifasi: siz aytganda kompyuterni qayta yoqish. Buni
shartnomaga yozing.

Va birinchi oy davomatni **qo'lda ham** dublyaj qilishsin. Tizim bir kun
ishlamay qolsa, akademiya davomatsiz qolmasligi kerak.

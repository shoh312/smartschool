# Ochiq serverni Ubuntu ga qo'yish

Bu papkadagi fayllar **faqat ochiq server** uchun. Maktab serveri o'z joyida,
maktab ichidagi kompyuterda qoladi — uni internetga chiqarish shart emas va
chiqarmagan ham ma'qul: o'quvchilar surati, kameralar va xodimlar hisoblari
o'sha yerda turadi.

Internetga chiqadigan qism faqat shu: ota-ona va o'quvchi ko'radigan
ma'lumot.

---

## 1. Nima kerak

| | |
|---|---|
| Server | Ubuntu 22.04 yoki 24.04, 1 GB RAM yetadi |
| Domen | masalan `maktab.example.tj`, A-yozuvi server IP siga qaratilgan |
| Portlar | 80 va 443 ochiq |

Domen shart: HTTPS sertifikati IP manzilga berilmaydi, HTTPSsiz esa parol va
tokenlar ochiq matnda uzatiladi.

---

## 2. Kodni serverga qo'yish

```bash
sudo mkdir -p /opt/smartschool
sudo git clone <repo> /opt/smartschool          # yoki scp bilan ko'chiring
cd /opt/smartschool/public_server
```

## 3. O'rnatish

```bash
sudo bash deploy/install.sh
```

Skript quyidagilarni qiladi: kerakli paketlar, `smartschool` xizmat
foydalanuvchisi, PostgreSQL roli va bazasi, Python muhiti, systemd xizmati.
Qayta ishga tushirish xavfsiz — har qadam avval tekshiradi.

`.env` ni **o'zi to'ldirmaydi** (maxfiy ma'lumot):

```bash
sudo nano /opt/smartschool/public_server/.env
```

`SMARTSCHOOL_PUBLIC_AUTH_SECRET` uchun:

```bash
openssl rand -hex 32
```

## 4. Ishga tushirish

```bash
sudo systemctl start smartschool-public
sudo systemctl status smartschool-public
sudo journalctl -u smartschool-public -f
```

**Migratsiya buyrug'i kerak emas.** Jadvallar birinchi ishga tushishda o'zi
yaratiladi (`app/main.py` dagi `create_all` va `ensure_database_schema`),
keyingi yangilanishlarda ham yetishmayotgan ustunlar o'zi qo'shiladi.

## 5. Maktab kaliti

Maktab serveri o'zini shu kalit bilan tanitadi. Serverda faqat xeshi
saqlanadi, ya'ni kalit **bir marta** ko'rsatiladi:

```bash
sudo -u smartschool /opt/smartschool/public_server/venv/bin/python \
     deploy/bootstrap_school.py "Maktab nomi"
```

Chiqqan qiymatlarni **maktab serverining** `backend/.env` iga yozing:

```
PUBLIC_SERVER_URL=https://maktab.example.tj
PUBLIC_SERVER_API_KEY=<chiqqan kalit>
```

so'ng maktab serverini qayta ishga tushiring.

## 6. HTTPS

```bash
sudo cp deploy/nginx.conf /etc/nginx/sites-available/smartschool-public
sudo nano /etc/nginx/sites-available/smartschool-public     # domenni yozing
sudo ln -s /etc/nginx/sites-available/smartschool-public /etc/nginx/sites-enabled/
sudo nginx -t && sudo systemctl reload nginx

sudo apt install -y certbot python3-certbot-nginx
sudo certbot --nginx -d maktab.example.tj
```

## 7. Ilovani ulash

Ilovada endi manzil **sozlamadan** o'zgartiriladi — APK ni qayta yig'ish
shart emas:

> Танзимот → Суроғаи сервер → `https://maktab.example.tj`

Kiritilgach ilovani qayta oching.

---

## Mavjud ma'lumotni ko'chirish

Yangi maktab uchun shart emas — server bo'sh bazadan boshlayveradi va
ma'lumot maktab serveridan sinxronizatsiya orqali oqib keladi.

Hozirgi sinov ma'lumotini ko'chirmoqchi bo'lsangiz:

```bash
# Windows kompyuterda
pg_dump -U postgres -d smartschool_public -f public.sql

# serverda
scp public.sql user@server:/tmp/
sudo -u postgres psql -d smartschool_public -f /tmp/public.sql
```

**Diqqat:** `SMARTSCHOOL_PUBLIC_AUTH_SECRET` o'zgargani uchun eski tokenlar
kuchsizlanadi — ota-onalar va o'quvchilar qaytadan kirishadi. Parollar
ishlayveradi, ular boshqa maxfiy kalit bilan xeshlangan.

---

## Tekshirish ro'yxati

```bash
curl https://maktab.example.tj/                    # {"message": ...}
sudo systemctl is-enabled smartschool-public       # enabled
```

Maktab serverida sinxronizatsiya ketayotganini ko'rish:

```sql
select status, count(*) from sync_outbox group by status;
```

`pending` soni doim o'sib borsa — kalit yoki manzil noto'g'ri. `last_error`
ustunini o'qing.

Ilovada: o'quvchi hisobi bilan **uy internetidan** (maktab Wi-Fi sidan emas)
kirib ko'ring. Aynan shu yo'l ilgari ishlamagan.

---

## Nimalar qilinmagan

Bularni bilib turing:

- **Zaxira nusxa** — serverda `pg_dump` ni cron ga qo'ying. Windowsdagi
  `scripts/backup.ps1` faqat mahalliy bazalarni oladi.
- **CORS** hamon `*`. Mobil ilova uchun ahamiyatsiz (brauzer emas), lekin
  keyinchalik veb-panel qo'shilsa toraytirish kerak.
- **Alembic** ochiq serverda yo'q — sxema `create_all` va qo'lda `ALTER`
  bilan boshqariladi. Yangi o'rnatma uchun bu yetarli, ma'lumot ko'paygach
  qayta ko'rib chiqiladi.

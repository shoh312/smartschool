# Ochiq serverni Docker bilan qo'yish

Bu yo'l `install.sh` ga muqobil: PostgreSQL, Python muhiti va xizmatni
alohida o'rnatish o'rniga hammasi ikkita konteynerda turadi. Bo'sh hostingda
sinash uchun eng tez yo'l.

Bu yerda **faqat ochiq server** bor. Maktab serveri (kameralar, o'quvchilar
surati, xodimlar hisoblari) maktabning o'z kompyuterida qoladi va
internetga chiqarilmaydi.

---

## 1. Serverga nima kerak

| | |
|---|---|
| OS | Ubuntu 22.04 / 24.04 (yoki Docker ishlaydigan har qanday Linux) |
| RAM | 1 GB yetadi |
| Docker | `curl -fsSL https://get.docker.com \| sudo sh` |

Domen shart emas — IP bilan ham ishlaydi. Ammo HTTPS haqidagi 6-bo'limni
o'qing: parol va SMS kodlari ochiq matnda ketmasin.

---

## 2. Kodni ko'chirish

```bash
sudo mkdir -p /opt/smartschool
sudo chown $USER /opt/smartschool
git clone <repo> /opt/smartschool      # yoki scp bilan
cd /opt/smartschool/public_server
```

## 3. `.env` ni to'ldirish

```bash
cp .env.example .env
nano .env
```

Ikkita qator **majburiy** — bo'sh qolsa `docker compose` ishga tushmaydi
(ataylab shunday: standart maxfiy kalit bilan ishlayotgan server — bu
istalgan odam istalgan ota-ona nomidan token yasay oladigan server):

```bash
openssl rand -hex 32     # SMARTSCHOOL_PUBLIC_AUTH_SECRET uchun
openssl rand -hex 16     # POSTGRES_PASSWORD uchun
```

## 4. Ishga tushirish

```bash
docker compose up -d --build
docker compose ps
docker compose logs -f app
```

Jadvallar birinchi ishga tushishda o'zi yaratiladi — alohida migratsiya
buyrug'i yo'q.

Tekshirish:

```bash
curl http://localhost:8200/docs
```

---

## 5. Hozirgi bazani ko'chirish

Yangi maktab uchun bu **shart emas** — ma'lumot maktab serveridan
sinxronizatsiya orqali o'zi oqib keladi. Hozirgi sinov ma'lumotini
ko'chirmoqchi bo'lsangiz:

**Windows kompyuterda** (hozirgi bazadan nusxa):

```powershell
pg_dump -U postgres -d smartschool_public --no-owner --no-privileges -f public.sql
```

`--no-owner --no-privileges` muhim: nusxadagi egalik `postgres` ga tegishli,
konteynerdagi foydalanuvchi esa `smartschool`. Busiz tiklashda ruxsat
xatolari chiqadi.

Faylni serverga ko'chiring (`scp public.sql user@IP:/opt/smartschool/`), so'ng:

```bash
cd /opt/smartschool/public_server

# 1. Faqat bazani ko'taring -- ilova hali ishga tushmasin.
docker compose up -d db

# 2. Nusxani tiklang.
docker compose exec -T db psql -U smartschool -d smartschool_public < /opt/smartschool/public.sql

# 3. Endi ilovani ham ko'taring.
docker compose up -d
```

**Tartib muhim.** Ilova ishga tushganda jadvallarni o'zi yaratadi, keyin
nusxadagi `CREATE TABLE` lar "allaqachon bor" deb xato beradi. Shuning uchun
avval baza, keyin tiklash, oxirida ilova.

Tekshirish:

```bash
docker compose exec db psql -U smartschool -d smartschool_public -c "\dt"
docker compose exec db psql -U smartschool -d smartschool_public -c "SELECT count(*) FROM students;"
```

---

## 6. Maktab kalitini yaratish

Maktab serveri ochiq serverga shu kalit bilan tanitadi. Serverda faqat
**xeshi** saqlanadi, ya'ni kalit bir marta ko'rsatiladi — yozib oling:

```bash
docker compose exec app python deploy/bootstrap_school.py "CICT_Academy"
```

Chiqqan qiymatlarni **maktab serverining** `backend/.env` iga yozing:

```
PUBLIC_SERVER_URL=http://<server-ip>:8200
PUBLIC_SERVER_API_KEY=<chiqqan kalit>
```

so'ng maktab serverini qayta ishga tushiring.

> Bazani ko'chirgan bo'lsangiz, maktab allaqachon bazada bo'lishi mumkin —
> u holda yangi kalit yaratish shart emas, eskisi ishlayveradi.

## 7. Ilovani ulash

Ilovada manzil sozlamadan o'zgartiriladi, APK ni qayta yig'ish shart emas:

> Танзимот → Суроғаи сервер → `http://<server-ip>:8200`

Manzilni portsiz (`http://<server-ip>`) yozmoqchi bo'lsangiz,
`docker-compose.yml` dagi `"8200:8200"` ni `"80:8200"` ga o'zgartiring va
`docker compose up -d` ni qayta ishga tushiring.

---

## 8. HTTPS — domen sotib olmasdan

IP bilan ham ishlaydi, lekin HTTPSsiz **telefon raqami, SMS tasdiqlash kodi,
parol va token ochiq matnda uzatiladi**. Yo'ldagi har kim o'qiy oladi, va
ushlangan token bilan o'sha bolaning baholari muddatsiz ko'riladi.

Domen sotib olish shart emas — bepul DNS nomi yetadi. IP `5.61.12.34` bo'lsa,
`5-61-12-34.sslip.io` avtomatik o'sha IP ga ishora qiladi (ro'yxatdan o'tish
kerak emas). Shundan keyin:

```bash
sudo apt install -y nginx certbot python3-certbot-nginx
sudo cp deploy/nginx.conf /etc/nginx/sites-available/smartschool-public
sudo nano /etc/nginx/sites-available/smartschool-public   # server_name va proxy portini yozing (8200)
sudo ln -s /etc/nginx/sites-available/smartschool-public /etc/nginx/sites-enabled/
sudo nginx -t && sudo systemctl reload nginx
sudo certbot --nginx -d 5-61-12-34.sslip.io
```

nginx 80/443 da tursin, `docker-compose.yml` esa `"127.0.0.1:8200:8200"` ga
o'zgartirilsin — shunda ilovaga faqat nginx orqali kiriladi.

---

## Kundalik buyruqlar

```bash
docker compose logs -f app          # jurnal
docker compose restart app          # qayta ishga tushirish
docker compose up -d --build        # kod yangilangach
docker compose down                 # to'xtatish (baza saqlanadi)
docker compose down -v              # baza bilan birga o'chirish -- EHTIYOT BO'LING
```

Baza nusxasini olish:

```bash
docker compose exec -T db pg_dump -U smartschool smartschool_public > backup-$(date +%F).sql
```

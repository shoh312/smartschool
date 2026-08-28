# Maktab serverini Ubuntu ga qo'yish (Docker)

Bu server maktabning **o'z tarmog'ida** qoladi va u yerdan chiqmaydi:
ichida o'quvchilarning yuz shakllari, kameralarning paroli va xodimlar
hisoblari bor. Internetga chiqadigan yagona narsa — ochiq serverga
sinxronizatsiya.

Bu qo'llanma **bo'sh bazadan** boshlashni tushuntiradi: o'quvchilar,
sinflar va baholar ilova orqali yangidan kiritiladi. Eski ma'lumotni
ko'chirish kerak bo'lsa, oxiridagi qo'shimchani o'qing.

---

## 1. Kompyuterni tayyorlash

Kamera bilan **bir tarmoqda** bo'lishi shart. Aks holda tanish umuman
ishlamaydi — buni birinchi tekshiring:

```bash
ping -c 3 192.168.0.64
```

Javob kelmasa, tarmoqni to'g'rilamaguncha davom etmang.

```bash
curl -fsSL https://get.docker.com | sh
systemctl enable --now docker
apt install -y git
docker compose version
```

## 2. Kodni olish

```bash
git clone https://github.com/shoh312/smartschool.git /opt/smartschool
cd /opt/smartschool/backend
ls Dockerfile docker-compose.yml
```

## 3. `.env` ni to'ldirish

```bash
cd /opt/smartschool/backend
nano .env
```

```
POSTGRES_PASSWORD=<openssl rand -hex 16>
SMARTSCHOOL_AUTH_SECRET=<openssl rand -hex 32>
JWT_SECRET=<openssl rand -hex 32>

# Birinchi direktor. Faqat bo'sh bazada ishlatiladi.
SMARTSCHOOL_ADMIN_EMAIL=director@cict.tj
SMARTSCHOOL_ADMIN_PASSWORD=<parolni shu yerga yozing>

PUBLIC_SERVER_URL=http://<ochiq-server-ip>:8200
PUBLIC_SERVER_API_KEY=<bootstrap_school.py chiqargan kalit>

GEMINI_API_KEY=<eski serverdan ko'chiring>
SMS_PROVIDER=robita
SMS_ROBITA_LOGIN=<eski serverdan>
SMS_ROBITA_PASSWORD=<eski serverdan>
```

`SMARTSCHOOL_ADMIN_EMAIL` yozilmasa `director@smartschool.com` ishlatiladi.
`SMARTSCHOOL_ADMIN_PASSWORD` bo'sh qolsa server tasodifiy parol yaratadi va
uni birinchi ishga tushishda bir marta jurnalga yozadi.

Uch kalitni shu yerda yarating:

```bash
echo "POSTGRES_PASSWORD=$(openssl rand -hex 16)"
echo "SMARTSCHOOL_AUTH_SECRET=$(openssl rand -hex 32)"
echo "JWT_SECRET=$(openssl rand -hex 32)"
```

Baza bo'shdan boshlagani uchun bu kalitlarning eskisi bilan bir xil bo'lishi
**shart emas** — hech kimning ochiq seansi yo'q.

`GEMINI_API_KEY` va SMS ma'lumotlari esa tashqi xizmatlarning hisoblari,
ular eski serverdagi `.env` dan ko'chiriladi.

```bash
chmod 600 .env
```

## 4. Ishga tushirish

```bash
docker compose up -d --build
```

Birinchi yig'ish **5–10 daqiqa** — `insightface` va `onnxruntime` katta.

```bash
docker compose logs -f app
```

Birinchi ishga tushishda yuz modellari yuklanadi (~300 MB, bir-ikki daqiqa),
so'ng volume da saqlanib qoladi va boshqa yuklanmaydi.

`.env` da parolni yozgan bo'lsangiz, o'sha parol bilan kiriladi. Yozmagan
bo'lsangiz jurnalda bir marta chiqadi:

```
=== BIRINCHI DIREKTOR YARATILDI ===
  login : director@cict.tj
  parol : xxxxxxxxxxxxx
  Bu parol qayta ko'rsatilmaydi -- hozir yozib oling.
===================================
```

Bunday holatda **darrov yozib oling** — u boshqa hech qayerda saqlanmaydi.

Tekshirish:

```bash
curl -s -o /dev/null -w "%{http_code}\n" http://localhost:8000/docs
```

## 5. Kompyuter yonganda o'zi ishga tushsin

Bu server sutka bo'yi ishlamaydi: kechqurun o'chadi, ertalab darsdan oldin
yonadi. Har yoqilganda kimdir terminal ochib buyruq yozishi kerak bo'lsa,
bir kuni yozilmay qoladi — va o'sha kuni kamera hech kimni ko'rmaydi.

```bash
cp /opt/smartschool/backend/deploy/smartschool-school.service /etc/systemd/system/
systemctl daemon-reload
systemctl enable smartschool-school
systemctl start smartschool-school
systemctl status smartschool-school
```

Tekshirish — kompyuterni qayta yuklab ko'ring:

```bash
reboot
```

Yonganidan bir-ikki daqiqa keyin (yuz modellari va konteynerlar ko'tarilishi
uchun):

```bash
docker compose ps
curl -s -o /dev/null -w "%{http_code}\n" http://localhost:8000/docs
```

`200` chiqsa — server o'zi ko'tarilibdi, boshqa hech narsa qilish shart emas.

> Konteynerlarda `restart: unless-stopped` ham turibdi, ya'ni ikki qavat
> himoya: Docker o'zi ko'taradi, xizmat esa ustidan tekshirib chiqadi.

## 6. Ilovani ulash

Telefon serverni LAN da o'zi topishi kerak. Topmasa, qo'lda:

> Танзимот → Суроғаи сервер → `http://<yangi-ip>:8000`

Direktor sifatida kiring va **birinchi ish sifatida parolni o'zgartiring.**

## 7. Ma'lumotni kiritish

Endi ilova orqali kiritiladi: maktab sozlamalari, sinflar, o'qituvchilar,
o'quvchilar (surat bilan — yuz shakli o'shanda hisoblanadi), kamera va
guruh rejimidagi jadval.

Kamera qo'shilgach jurnalda quyidagilar ko'rinadi:

```
[+] Camera N: detection thread started
[+] Camera N: loaded M students for class_id=...
```

## 8. Eski serverni to'xtatish

Yangi serverda hammasi ishlayotganiga ishonch hosil qilgach — kamera
taniyapti, ilova ulanyapti — eski Windows mashinasidagi serverni
**to'xtating**.

Ikkalasi bir vaqtda ishlasa, ikkita kamera oqimi bitta kamerani tortqilaydi
va ikkita davomat tizimi bir-biriga xalaqit beradi. Bu bugun bir marta
sodir bo'lgan va soatlab chalkashlik keltirgan.

---

## Kundalik buyruqlar

```bash
docker compose logs -f app          # jurnal
docker compose restart app          # qayta ishga tushirish
docker compose up -d --build        # kod yangilangach
docker compose down                 # to'xtatish (baza saqlanadi)
```

Baza nusxasini olish — haftada bir marta qilish tavsiya etiladi, chunki
yuz shakllari faqat shu yerda:

```bash
docker compose exec -T db pg_dump -U smartschool smartschool > /opt/backup-$(date +%F).sql
```

---

## Qo'shimcha: eski ma'lumotni ko'chirish

Kerak bo'lib qolsa. Tartib qat'iy — ilova oldin tursa jadvallarni o'zi
yaratadi va tiklash to'qnashadi.

Windows'da:

```powershell
& "C:\Program Files\PostgreSQL\18\bin\pg_dump.exe" -U postgres -d smartschool --no-owner --no-privileges -f C:\Users\gameboy\Desktop\school.sql
scp C:\Users\gameboy\Desktop\school.sql root@<yangi-ip>:/opt/
```

Yangi serverda:

```bash
cd /opt/smartschool/backend
docker compose up -d db                    # avval faqat baza
docker compose exec -T db psql -U smartschool -d smartschool < /opt/school.sql
docker compose up -d --build               # keyin ilova
```

Bu holatda `SMARTSCHOOL_AUTH_SECRET` va `JWT_SECRET` **eski serverdagi bilan
bir xil** bo'lishi kerak, aks holda hamma foydalanuvchi tizimdan chiqib
ketadi.

Yuz shakllari ko'chganini tekshiring:

```bash
docker compose exec db psql -U smartschool -d smartschool -c "SELECT count(*) FROM students WHERE face_encoding IS NOT NULL;"
```

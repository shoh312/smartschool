# Maktab serveri -- kameralarni ko'radigan, yuzlarni taniydigan qism.
#
# Bu konteyner maktabning o'z tarmog'ida turadi va u yerdan chiqmaydi:
# ichida o'quvchilarning yuz shakllari, kameralarning paroli va xodimlar
# hisoblari bor. Internetga faqat ochiq serverga sinxronizatsiya chiqadi.
#
# Ikki bosqichli yig'ish. Sabab -- maktabdagi tarmoq sekin va beqaror:
# insightface va boshqa og'ir kutubxonalarni yuklab olish o'nlab daqiqa
# davom etadi, va tarmoq bir tekis ishlamagani uchun pip o'rtada uzilib
# qolishi mumkin. Agar build-essential/cmake o'rnatish bilan pip install
# bitta qatlamda bo'lsa, pip qayta uringanda compiler o'rnatish ham
# boshidan takrorlanadi. Bu yerda ular alohida "builder" bosqichida --
# shu qatlam Docker keshida qoladi va pip qayta urinishi arzon bo'ladi.
FROM python:3.11-slim AS builder

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

WORKDIR /app

# insightface o'z Cython kengaytmasini yig'adi, shuning uchun compiler
# kerak. Bu bosqich final image ga kirmaydi -- faqat quyida yig'ilgan
# venv ko'chiriladi.
#
# Acquire::Retries -- pip uchun qo'shilgan --retries kabi, apt ham shu
# beqaror tarmoqda paket ro'yxatini yoki .deb faylni yuklab olayotganda
# uzilib qolishi mumkin.
RUN apt-get update -o Acquire::Retries=10 \
    && apt-get install -y --no-install-recommends \
        build-essential \
        cmake \
    && rm -rf /var/lib/apt/lists/*

COPY requirements-docker.txt .

# --retries/--timeout -- maktab tarmog'idagi vaqtinchalik uzilishlarga
# chidash uchun (pip standart timeout'i 15s, sekin tarmoqda bu yetarli
# emas). --retries pip ning o'zi qayta urinishini, --timeout esa har bir
# urinish qancha kutishini oshiradi.
RUN python -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"
RUN pip install --no-cache-dir --retries 10 --timeout 120 -r requirements-docker.txt

FROM python:3.11-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PATH="/opt/venv/bin:$PATH"

WORKDIR /app

# OpenCV ning kutubxonalari (libgl1, libxcb1 va qolganlari) shu yerda.
# Ular oyna chizish uchun kerak va bu serverda hech qachon oyna chizilmaydi
# -- lekin insightface `opencv-python` ni talab qiladi, headless variantini
# emas, va u ishga tushishning o'zida shu kutubxonalarni qidiradi. Ularsiz
# konteyner `ImportError: libxcb.so.1` bilan qulab tushadi. libgomp1 esa
# onnxruntime ishga tushganda kerak bo'ladi.
RUN apt-get update -o Acquire::Retries=10 \
    && apt-get install -y --no-install-recommends \
        libgl1 \
        libglib2.0-0 \
        libgomp1 \
        libsm6 \
        libxcb1 \
        libxext6 \
        libxrender1 \
    && rm -rf /var/lib/apt/lists/*

COPY --from=builder /opt/venv /opt/venv
COPY . .

# Root emas. Yuz modellari va yuklangan suratlar uchun uy papkasi kerak --
# insightface modellarni ~/.insightface ga yozadi va compose uni volume
# qilib biriktiradi, aks holda har qayta yig'ishda 300 MB qaytadan
# yuklanardi.
RUN useradd --create-home --uid 10001 smartschool \
    && mkdir -p /home/smartschool/.insightface /app/uploads \
    && chown -R smartschool:smartschool /app /home/smartschool
USER smartschool

EXPOSE 8000

# Port .env dan olinadi: maktabning mashinasida 8000 boshqa xizmat tomonidan
# band bo'lishi mumkin, va host tarmog'ida ishlaganimiz uchun uni chetlab
# o'tib bo'lmaydi. Shell orqali chaqirilyapti -- exec shaklida ${...}
# almashtirilmaydi va uvicorn portni "${SCHOOL_SERVER_PORT:-8000}" degan
# matn deb qabul qiladi.
CMD ["sh", "-c", "exec uvicorn app.main:app --host 0.0.0.0 --port ${SCHOOL_SERVER_PORT:-8000}"]

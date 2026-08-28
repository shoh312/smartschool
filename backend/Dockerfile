# Maktab serveri -- kameralarni ko'radigan, yuzlarni taniydigan qism.
#
# Bu konteyner maktabning o'z tarmog'ida turadi va u yerdan chiqmaydi:
# ichida o'quvchilarning yuz shakllari, kameralarning paroli va xodimlar
# hisoblari bor. Internetga faqat ochiq serverga sinxronizatsiya chiqadi.

FROM python:3.11-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

WORKDIR /app

COPY requirements-docker.txt .

# Yig'ish uchun kerakli paketlar o'rnatiladi, kutubxonalar yig'iladi, so'ng
# yig'uvchi paketlar o'sha qatlamning o'zida o'chiriladi. Alohida RUN da
# o'chirilsa image kichraymaydi -- Docker'da o'chirilgan fayl ham oldingi
# qatlamda saqlanib qolaveradi.
#
# insightface o'z Cython kengaytmasini yig'adi, shuning uchun compiler
# kerak. libgomp1 esa qoladi: onnxruntime ishga tushganda uni qidiradi.
#
# OpenCV ning kutubxonalari (libgl1, libxcb1 va qolganlari) ham shu yerda.
# Ular oyna chizish uchun kerak va bu serverda hech qachon oyna chizilmaydi
# -- lekin insightface `opencv-python` ni talab qiladi, headless variantini
# emas, va u ishga tushishning o'zida shu kutubxonalarni qidiradi. Ularsiz
# konteyner `ImportError: libxcb.so.1` bilan qulab tushadi.
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        build-essential \
        cmake \
        libgl1 \
        libglib2.0-0 \
        libgomp1 \
        libsm6 \
        libxcb1 \
        libxext6 \
        libxrender1 \
    && pip install --no-cache-dir -r requirements-docker.txt \
    && apt-get purge -y build-essential cmake \
    && apt-get autoremove -y \
    && rm -rf /var/lib/apt/lists/*

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

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
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        build-essential \
        cmake \
        libglib2.0-0 \
        libgomp1 \
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

CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]

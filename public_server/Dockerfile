# The Public Server -- the only part of SmartFlow that faces the internet.
#
# The school server stays on the school's own machine: it holds the pupils'
# photographs, the camera credentials and the staff accounts, and none of
# that belongs on a rented box. What ships here is the half a parent sees.

FROM python:3.11-slim

# Faster, quieter, and no stale .pyc files baked into the image.
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

WORKDIR /app

# Dependencies first, in their own layer: the code changes on every deploy
# and the dependency list almost never does, so this keeps rebuilds to
# seconds instead of minutes.
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

# Not root. A web process that is compromised should not also own the
# filesystem it runs on.
RUN useradd --create-home --uid 10001 smartschool \
    && chown -R smartschool:smartschool /app
USER smartschool

EXPOSE 8200

# Run uvicorn directly rather than through main.py, so the worker count and
# the port stay configurable from compose without editing Python.
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8200"]

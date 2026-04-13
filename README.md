# may-flyway

MAY platformu veritabanı migration projesi.

## Teknolojiler

- **Flyway 10** — Migration tool
- **PostgreSQL 17** — Veritabanı
- **Docker Compose** — Container orchestration

## Schema

- **Schema:** `MAY`
- **App User:** `MAY_APP`

## Tablolar

```
USERS ──< USERS_ROLE >── ROLE ──< ROLE_PERMISSION >── PERMISSION
```

Her tablo için `_HIS` history tablosu ve trigger mevcuttur.

## Kullanım

```bash
# Build
docker compose build

# Build (with version)
VERSION=1.0.1 docker compose build

# Push
docker compose push

# Migrate
docker compose up
```

Detaylı komutlar için [docker-commands.txt](docker-commands.txt) dosyasına bakınız.

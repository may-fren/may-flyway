# Project Context

## 1. Genel Proje Tanımı & Amaç

**MAY**, çeşitli yönetim süreçlerini yönetmek için geliştirilmiş bir platformdur. Bu repo, platformun **veritabanı şemasını ve migration dosyalarını** barındırır.

- **Repo:** `may-flyway`
- **Veritabanı:** PostgreSQL 17
- **Schema:** `MAY`
- **Migration Tool:** Flyway 10
- **Container Orchestration:** Docker Compose

**Kardeş projeler:**
- `may-database` — PostgreSQL veritabanı (Docker Compose)

---

## 2. Mimari Kararlar & Prensipler

- **Flyway ile versiyon kontrolü** — migration dosyaları `V{n}__{açıklama}.sql` formatında, `migrations/` klasöründe tutulur
- **Docker Compose tabanlı çalıştırma** — `docker compose build` ile imaj oluşturulur, `docker compose up` ile migrate edilir
- **Versiyonlama** — `VERSION` environment variable ile imaj versiyonu belirlenir (varsayılan: `1.0.0`)
- **History tabloları** — her tablo için `{TABLO}_HIS` suffix'li history tablosu mevcuttur; INSERT/UPDATE/DELETE trigger'ları ile otomatik doldurulur
- **Audit alanları** — her tabloda: `CREATED_BY`, `CREATED_DATE`, `CREATED_IP`, `UPDATED_BY`, `UPDATED_DATE`, `UPDATED_IP`
- **History ek alanları** — `_HIS` tablolarında ek olarak: `ORIGINAL_ID`, `DML_OPERATION`, `DML_BY`, `DML_DATE`, `DML_IP`
- **Sequence stratejisi** — her tablo için ayrı PostgreSQL sequence (`SEQ_{TABLO_ADI}`, `SEQ_{TABLO_ADI}_HIS`)
- **Constraint isimlendirme** — `PK_`, `UK_`, `FK_`, `CK_`, `IDX_` prefix'leri kullanılır
- **Status değerleri** — `ACTIVE`, `INACTIVE` (USERS tablosunda ayrıca `BLOCKED`)
- **Uygulama kullanıcısı** — `MAY_APP` DB kullanıcısına schema üzerinde tam yetki verilmiştir

---

## 3. Veritabanı Şeması

### 3.1 Tablo İlişkileri

```
USERS ──< USERS_ROLE >── ROLE ──< ROLE_PERMISSION >── PERMISSION
```

### 3.2 Migration Geçmişi

| Migration | Dosya | Açıklama |
|---|---|---|
| V1 | `V1__initial_schema.sql` | Tüm tablolar, trigger'lar, seed verileri ve yetkiler (tek dosya) |

### 3.3 Tablolar & Temel Kolonlar

#### USERS
| Kolon | Tip | Açıklama |
|---|---|---|
| ID | BIGINT | PK, `SEQ_USERS` |
| USERNAME | VARCHAR(100) | UK |
| EMAIL | VARCHAR(150) | UK |
| PASSWORD_HASH | VARCHAR(255) | |
| FIRST_NAME | VARCHAR(100) | |
| LAST_NAME | VARCHAR(100) | |
| PHONE | VARCHAR(20) | nullable |
| STATUS | VARCHAR(20) | `ACTIVE`, `INACTIVE`, `BLOCKED` |
| LAST_LOGIN_DATE | TIMESTAMP | nullable |
| ERROR_LOGIN_COUNT | INTEGER | default 0 |

#### ROLE
| Kolon | Tip | Açıklama |
|---|---|---|
| ID | BIGINT | PK, `SEQ_ROLE` |
| NAME | VARCHAR(100) | UK |
| DESCRIPTION | VARCHAR(500) | nullable |
| STATUS | VARCHAR(20) | `ACTIVE`, `INACTIVE` |

#### PERMISSION
| Kolon | Tip | Açıklama |
|---|---|---|
| ID | BIGINT | PK, `SEQ_PERMISSION` |
| NAME | VARCHAR(100) | UK |
| DESCRIPTION | VARCHAR(500) | nullable |
| MODULE | VARCHAR(100) | UK(MODULE, ACTION) |
| ACTION | VARCHAR(50) | `CREATE`, `READ`, `UPDATE`, `DELETE`, `LIST`, `EXPORT`, `IMPORT` |
| STATUS | VARCHAR(20) | `ACTIVE`, `INACTIVE` |

#### USERS_ROLE
| Kolon | Tip | Açıklama |
|---|---|---|
| ID | BIGINT | PK |
| USERS_ID | BIGINT | FK → USERS, UK(USERS_ID, ROLE_ID) |
| ROLE_ID | BIGINT | FK → ROLE |
| ASSIGNED_BY | VARCHAR(100) | |
| ASSIGNED_DATE | TIMESTAMP | |

#### ROLE_PERMISSION
| Kolon | Tip | Açıklama |
|---|---|---|
| ID | BIGINT | PK |
| ROLE_ID | BIGINT | FK → ROLE, UK(ROLE_ID, PERMISSION_ID) |
| PERMISSION_ID | BIGINT | FK → PERMISSION |

---

## 4. Bileşenler

### 4.1 Dosya Yapısı

```
may-flyway/
├── Dockerfile              # flyway/flyway:10 imajı, migrations kopyalama
├── flyway.conf             # DB bağlantı ayarları (env var destekli)
├── docker-compose.yml      # Docker Compose ile build/push/run
├── docker-commands.txt     # Docker ve Compose komutları referansı
└── migrations/
    └── V1__initial_schema.sql
```

### 4.2 Flyway Konfigürasyonu

```
flyway.url=jdbc:postgresql://${DB_HOST:-localhost}:${DB_PORT:-5432}/postgres?currentSchema=MAY
flyway.user=${DB_USER:-postgres}
flyway.password=${DB_PASSWORD:-123456789}
flyway.schemas=MAY
flyway.locations=filesystem:/flyway/sql
flyway.baselineOnMigrate=true
flyway.validateOnMigrate=false
flyway.outOfOrder=false
```

### 4.3 Docker Compose Konfigürasyonu

```yaml
services:
  flyway:
    build: .
    image: ozanemrahyakupoglu/may-flyway:${VERSION:-1.0.0}
    container_name: may-flyway
    environment:
      DB_HOST: host.docker.internal
      DB_PORT: 5432
      DB_USER: postgres
      DB_PASSWORD: 123456789
```

### 4.4 Trigger Yapısı (Her Tablo İçin Tekrarlayan Pattern)

Her tabloda üç bileşen vardır:
1. `FN_{TABLO}_HIS()` — plpgsql trigger fonksiyonu, INSERT/UPDATE/DELETE durumlarını ayrı ayrı handle eder
2. `TRG_{TABLO}_HIS` — AFTER INSERT OR UPDATE OR DELETE, FOR EACH ROW
3. `{TABLO}_HIS` tablosu — ana tablo kolonları + `ORIGINAL_ID`, `DML_OPERATION`, `DML_BY`, `DML_DATE`, `DML_IP`

---

## 5. Mevcut Migration Durumu

| Tablo | Durum | Notlar |
|---|---|---|
| USERS | ✅ Tamamlandı | History trigger dahil |
| ROLE | ✅ Tamamlandı | History trigger dahil |
| PERMISSION | ✅ Tamamlandı | History trigger dahil |
| USERS_ROLE | ✅ Tamamlandı | History trigger dahil |
| ROLE_PERMISSION | ✅ Tamamlandı | History trigger dahil |
| Seed Verileri | ✅ Tamamlandı | Permissions, Roles, Users, Role-Permissions, User-Roles |
| DB Yetkileri | ✅ Tamamlandı | `MAY_APP` kullanıcısına tam yetki |

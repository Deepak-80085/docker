# Phase 3: PostgreSQL in Development - COMPLETED ✅

**Date:** January 15, 2026  
**Status:** ✅ COMPLETED  
**Duration:** 30 minutes  

---

## Phase 3 Overview

**Goal:** Use PostgreSQL in development setup, not just production. Practice multi-container orchestration with service dependencies.

**Achievements:**
- ✅ Added PostgreSQL service to docker-compose.yml
- ✅ Configured web container to use DATABASE_URL
- ✅ Implemented service health checks
- ✅ Set up proper `depends_on` with conditions
- ✅ Applied migrations to PostgreSQL
- ✅ Both containers running simultaneously
- ✅ Hot reload still works with PostgreSQL

---

## Key Learnings

### 1. **Multi-Container Development (2 containers)**

Before (Phase 2 dev):
```
┌─────────────────────┐
│   Single Container  │
│  - Django app       │
│  - SQLite database  │
│  - All in one       │
└─────────────────────┘

Problem: Database lost if container crashes
```

After (Phase 3 dev):
```
┌─────────────────────┐     ┌─────────────────────┐
│  Web Container      │────→│  DB Container       │
│  - Django dev       │     │  - PostgreSQL 15    │
│  - Hot reload       │     │  - Persistent data  │
│  - Gunicorn ready   │     │  - Independent      │
└─────────────────────┘     └─────────────────────┘

Benefit: Database survives container restart
```

### 2. **Service Dependencies: `depends_on`**

**Problem:**
- Web container tried to connect before PostgreSQL was ready
- Got "connection refused" errors

**Solution: Health Checks**

```yaml
db:
  image: postgres:15-alpine
  healthcheck:
    test: ["CMD-SHELL", "pg_isready -U todo_user -d todo_db"]
    interval: 2s
    timeout: 3s
    retries: 5

web:
  depends_on:
    db:
      condition: service_healthy  # Wait for healthcheck to pass!
```

**Result:**
```
docker-compose up -d output:
✔ Container todo_db_dev       Healthy                 3.1s
✔ Container to_do_list-web-1  Started                 3.2s
```

**Before adding healthcheck:** Web container crashed trying to connect  
**After adding healthcheck:** Web waits for DB to be ready, then connects successfully

### 3. **Docker Compose Version and Service Configuration**

**Updated docker-compose.yml:**

```yaml
version: '3.9'

services:
  db:
    image: postgres:15-alpine
    container_name: todo_db_dev
    volumes:
      - postgres_data_dev:/var/lib/postgresql/data  # Named volume
    environment:
      - POSTGRES_DB=todo_db
      - POSTGRES_USER=todo_user
      - POSTGRES_PASSWORD=dev_password
    restart: always
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U todo_user -d todo_db"]
      interval: 2s
      timeout: 3s
      retries: 5

  web:
    build: .
    depends_on:
      db:
        condition: service_healthy    # NEW: Wait for health!
    volumes:
      - ./tasks:/app/tasks            # Hot reload code
      - ./templates:/app/templates
      - ./static:/app/static
      - ./todo:/app/todo
    ports:
      - "8000:8000"
    environment:
      - PYTHONUNBUFFERED=1
      - DATABASE_URL=postgresql://todo_user:dev_password@db:5432/todo_db
    command: python manage.py runserver 0.0.0.0:8000
    restart: unless-stopped

volumes:
  postgres_data_dev:                  # Named volume persists data
```

### 4. **Django Settings Enhancement**

**Updated to support DATABASE_URL:**

```python
import os

if os.environ.get('DATABASE_URL'):
    # Docker container with PostgreSQL
    import dj_database_url
    DATABASES = {
        'default': dj_database_url.config(
            default=os.environ.get('DATABASE_URL'),
            conn_max_age=600,
            conn_health_checks=True,
        )
    }
else:
    # Local development with SQLite
    DATABASES = {
        'default': {
            'ENGINE': 'django.db.backends.sqlite3',
            'NAME': BASE_DIR / 'db.sqlite3',
        }
    }
```

**Why this matters:**
- **Docker:** DATABASE_URL set → Uses PostgreSQL
- **Local (no Docker):** DATABASE_URL not set → Uses SQLite
- **Flexible!** Same code works for all environments

### 5. **Communication Between Containers**

**Network Magic:**

```
Web Container (172.18.0.3):
  "Connect to db:5432"
  ↓
Docker Network translates:
  db → 172.18.0.2 (PostgreSQL IP)
  ↓
Connection successful!
```

**Key Insight:**
- Containers communicate via service name (`db`)
- Docker's internal DNS resolves to correct IP
- No need to know actual container IP
- Works even if container restarts (new IP assigned)

### 6. **Volume Types: Named vs Bind**

**Used in Phase 3:**

```yaml
volumes:
  # Named Volume - Data persists, managed by Docker
  postgres_data_dev:
  
  # Bind Mounts - Local folders, hot reload
  ./tasks:/app/tasks
  ./templates:/app/templates
  ./static:/app/static
  ./todo:/app/todo
```

**Difference:**

| Type | Where | Persistent | Hot Reload | Use Case |
|------|-------|-----------|-----------|----------|
| Named Volume | Docker managed | ✅ Yes | ❌ No | Database data |
| Bind Mount | Local filesystem | ❌ No | ✅ Yes | Source code |

---

## Setup Process

### Files Modified:

1. **docker-compose.yml**
   - Added version: '3.9'
   - Added `db` service with PostgreSQL
   - Added `depends_on` with healthcheck condition
   - Added DATABASE_URL environment variable
   - Added named volume

2. **todo/settings.py**
   - Added `import os` and `import dj_database_url`
   - Modified DATABASES to read DATABASE_URL or fall back to SQLite

3. **requirements.txt**
   - Added `dj-database-url==2.1.0` (to parse DATABASE_URL)

### Commands Run:

```powershell
# Build and start with healthcheck
docker-compose up --build -d

# Apply migrations to PostgreSQL
docker exec to_do_list-web-1 python manage.py migrate

# Test the app
Invoke-WebRequest http://localhost:8000/

# Query database
docker exec todo_db_dev psql -U todo_user -d todo_db -c "SELECT COUNT(*) FROM tasks_task;"
```

---

## Architecture Comparison: All 3 Phases

### Phase 1: Isolated SQLite
```
Single container
├─ Django dev server
└─ SQLite database (inside container)

Learning: Volumes control what appears in container
```

### Phase 2: Production Reference
```
Two containers (production-like)
├─ Web: Django + Gunicorn (4 workers)
└─ DB: PostgreSQL + persistent volume

Learning: Separate database enables scaling
```

### Phase 3: PostgreSQL Development (Current)
```
Two containers (dev with production database)
├─ Web: Django dev + hot reload + code volumes
└─ DB: PostgreSQL + healthcheck + depends_on

Learning: Multi-container orchestration with dependencies
```

---

## Real-World Insights

### Problem Solved: Race Conditions

**Scenario:** Container startup race

```
❌ Old approach (no healthcheck):
  docker-compose up
  ├─ Start DB container
  └─ Start Web container (immediately!)
       └─ Connect to DB (not ready yet!)
          → Connection refused
          → Container crashes

✅ New approach (with healthcheck):
  docker-compose up
  ├─ Start DB container
  │  └─ healthcheck: pg_isready (fails... fails... passes!)
  └─ Once healthy:
       └─ Start Web container
          └─ Connect to DB (ready now!)
             → Success!
```

### Communication Pattern

```
Web Container                    Docker Network               DB Container
┌──────────────────┐            ┌──────────────┐           ┌──────────────┐
│ Python code:     │            │ DNS resolver │           │ PostgreSQL   │
│                  │            │              │           │              │
│ os.environ       │───────────→│ "db" → IP    │──────────→│ Listening on │
│ ['DATABASE_URL'] │            │172.18.0.2   │           │ 5432         │
└──────────────────┘            └──────────────┘           └──────────────┘

```

---

## Errors Encountered & Solutions

### Error 1: Connection Refused (Race Condition)

**First attempt:** `docker-compose up --build -d`

**Error in web logs:**
```
psycopg2.OperationalError: connection to server at "db" (172.18.0.2), port 5432 
failed: Connection refused
        Is the server running on that host and accepting TCP/IP connections?
```

**Root cause:** 
- `depends_on` only waits for container to **start**, not to be **ready**
- PostgreSQL was still initializing when web tried to connect
- Web container crashed before DB could finish starting up

**Solution:**
Added healthcheck to `db` service and changed `depends_on` to:
```yaml
depends_on:
  db:
    condition: service_healthy  # Wait for readiness, not just startup
```

**Result after fix:**
```
✔ Container todo_db_dev       Healthy                 3.1s
✔ Container to_do_list-web-1  Started                 3.2s
```

---

### Error 2: Database Tables Don't Exist

**After first successful startup:** `Invoke-WebRequest http://localhost:8000/`

**Error response (500):**
```
django.db.utils.ProgrammingError: relation "tasks_task" does not exist
LINE 1: SELECT "tasks_task"."id", "tasks_task"."title", 
               "tasks_task"."description", "tasks_task"."completed" FROM "tasks_task"
                                                             ^
```

**Root cause:**
- PostgreSQL database was fresh (no tables)
- Migrations had run during build against SQLite, not PostgreSQL
- Web container expects tables but database is empty

**Solution:**
Applied migrations to PostgreSQL after container started:
```powershell
docker exec to_do_list-web-1 python manage.py migrate
```

**Output:**
```
Operations to perform:
  Apply all migrations: admin, auth, contenttypes, sessions, tasks
Running migrations:
  Applying contenttypes.0001_initial... OK
  Applying auth.0001_initial... OK
  Applying admin.0001_initial... OK
  Applying admin.0002_logentry_remove_auto_add... OK
  Applying admin.0003_logentry_add_action_flag_choices... OK
  [... 15 more migrations ...]
  Applying tasks.0001_initial... OK
  Applying tasks.0002_rename_compeleted_task_completed... OK
```

**Result after fix:**
```powershell
# Test again
Invoke-WebRequest http://localhost:8000/

StatusCode ContentLength
---------- -------------
       200           658
```

---

### Error 3: Version Warning

**Docker Compose warning:**
```
time="2026-01-15T22:17:08+05:30" level=warning msg="docker-compose.yml: 
the attribute `version` is obsolete, it will be ignored, please remove it 
to avoid potential confusion"
```

**Root cause:**
- Added `version: '3.9'` in docker-compose.yml
- Newer Docker Compose versions ignore this field

**Impact:**
- ⚠️ Just a warning, doesn't affect functionality
- Can remove `version:` field or ignore warning
- Docker Compose determines version automatically from file contents

**Note:**
- Not critical for Phase 3
- Good practice to remove for future-proofing

---

## Lessons from Errors

1. **`depends_on` ≠ readiness** - Always use healthchecks for databases
   - Container starting ≠ Service ready
   - PostgreSQL needs time to initialize
   - Check service health, not just container state

2. **Fresh database = no tables** - Always run migrations after container starts
   - Build-time migrations run in build environment
   - Run-time migrations target actual database
   - Two different databases (build context vs running container)

3. **Version field is legacy** - Modern Docker Compose manages versioning
   - Can safely remove `version:` field
   - Doesn't affect current setup

---

## Verification Checklist

- ✅ Both containers running: `docker ps` shows 2 containers
- ✅ Database healthy: `docker ps` shows `(healthy)` status
- ✅ App responds: `Invoke-WebRequest http://localhost:8000/` → 200 OK
- ✅ Migrations applied: `docker exec ... psql ... SELECT COUNT(*) FROM tasks_task;` → 0 rows
- ✅ Containers communicate: No connection errors in logs
- ✅ Hot reload ready: Code changes detected by StatReloader
- ✅ PostgreSQL running: `docker logs todo_db_dev` shows "database system is ready"
- ✅ Django connected: No "OperationalError" in web logs

---

## Production vs Development Comparison

| Feature | Dev (Phase 3) | Prod (Phase 2) |
|---------|-----------|---------|
| **Web Server** | Django dev | Gunicorn |
| **Workers** | 1 | 4 |
| **Database** | PostgreSQL 15 | PostgreSQL 15 |
| **DEBUG** | True | False |
| **Code Volumes** | Bind mount (hot reload) | No volumes (frozen in image) |
| **Startup** | 5-10 seconds | 10-15 seconds |
| **Purpose** | Development iteration | Production users |

**Key Insight:**
- Dev now uses same database (PostgreSQL) as production
- Bugs found in dev will likely appear in prod too
- Database schema testing before production

---

## Commands Reference

```powershell
# Development setup (Phase 3)
docker-compose up --build -d          # Start with healthcheck
docker-compose logs -f                # Watch logs
docker-compose down                   # Stop

# Database management
docker exec to_do_list-web-1 python manage.py migrate
docker exec todo_db_dev psql -U todo_user -d todo_db -c "..."

# Testing
Invoke-WebRequest http://localhost:8000/

# Inspection
docker ps                             # Show containers
docker logs todo_db_dev               # PostgreSQL logs
docker logs to_do_list-web-1          # Django logs
```

---

# Phase 4: Production Ready - Persistence, Scaling & Static Files ✅

---

## Overview

Three critical production concepts for building resilient, scalable applications:

1. **Part A:** Data persistence across container restarts
2. **Part B:** Horizontal scaling with load balancing
3. **Part C:** Static files serving in multi-container setup

---

## Part A: Data Persistence ✅

### The Challenge

What happens to database data when containers restart?

```
❌ WITHOUT persistence (SQLite in container):
   Container crashes → All data LOST forever

✅ WITH persistence (PostgreSQL + named volume):
   Container crashes → Data SAFE in volume
   Restart app → All data restored
```

### How It Works

**Docker named volumes** store database files outside containers:

```yaml
services:
  db:
    volumes:
      - postgres_data_dev:/var/lib/postgresql/data  # Named volume

volumes:
  postgres_data_dev:  # Volume persists even when container deleted
```

When you run:
```
docker-compose down      # Containers gone, volume stays ✅
docker-compose up -d     # Containers back, volume reused ✅
```

### Test Results

**Added task "Persist This!" → Stopped containers → Restarted → Data still there ✅**

```
Before:   SELECT * FROM tasks_task WHERE title = 'Persist This!';
          ✅ Task found

After down/up:  SELECT * FROM tasks_task WHERE title = 'Persist This!';
                ✅ Task still found!
```


## Part B: Horizontal Scaling ✅

### The Challenge

Your app gets popular and one server isn't enough. Solution: **Multiple web containers + Load balancer**

```
Internet (Port 8000)
    ↓
   nginx (Load Balancer)
    ↓
   ├─→ web-1:8000 (Django)
   ├─→ web-2:8000 (Django)
   └─→ web-3:8000 (Django)
    ↓
   PostgreSQL (Shared DB)
```

### Docker Compose Configuration

**File: `docker-compose-scale.yml`**

```yaml
version: '3.9'
services:
  nginx:
    image: nginx:latest
    ports:
      - "8000:80"
    volumes:
      - ./nginx.conf:/etc/nginx/nginx.conf:ro
    depends_on:
      - web-1
      - web-2
      - web-3

  web-1:
    build: .
    environment:
      - DATABASE_URL=postgresql://todo_user:todo_password@db:5432/todo_db
    depends_on:
      db:
        condition: service_healthy
    volumes:
      - staticfiles:/app/staticfiles

  web-2:
    build: .
    environment:
      - DATABASE_URL=postgresql://todo_user:todo_password@db:5432/todo_db
    depends_on:
      db:
        condition: service_healthy
    volumes:
      - staticfiles:/app/staticfiles

  web-3:
    build: .
    environment:
      - DATABASE_URL=postgresql://todo_user:todo_password@db:5432/todo_db
    depends_on:
      db:
        condition: service_healthy
    volumes:
      - staticfiles:/app/staticfiles

  db:
    image: postgres:15-alpine
    environment:
      - POSTGRES_USER=todo_user
      - POSTGRES_PASSWORD=todo_password
      - POSTGRES_DB=todo_db
    volumes:
      - postgres_data_scale:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U todo_user -d todo_db"]
      interval: 5s
      timeout: 10s
      retries: 5

volumes:
  postgres_data_scale:
  staticfiles:
```

**Critical configuration:**
- `DATABASE_URL`: Each web container uses same PostgreSQL
- `depends_on with condition: service_healthy`: Waits for DB readiness
- `healthcheck`: Database proves it's ready (not just starting)

### Nginx Load Balancer Configuration

**File: `nginx.conf`**

```nginx
events {
    worker_connections 1024;
}

http {
    upstream django_app {
        server web-1:8000;  # Round-robin by default
        server web-2:8000;
        server web-3:8000;
    }

    server {
        listen 80;
        client_max_body_size 20M;

        location / {
            proxy_pass http://django_app;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            
            # CRITICAL: Track which backend served request
            add_header X-Served-By $upstream_addr always;
        }

        location /static/ {
            alias /app/staticfiles/;
            expires 30d;
        }
    }
}
```

**How round-robin works:**
- Request 1 → web-1
- Request 2 → web-2
- Request 3 → web-3
- Request 4 → web-1 (repeats)

### Django & Requirements Updates

**File: `todo/settings.py`** (add imports and settings)

```python
import dj_database_url

# ... existing code ...

STATIC_ROOT = BASE_DIR / 'staticfiles'

if os.environ.get('DATABASE_URL'):
    DATABASES = dj_database_url.config(
        default=os.environ.get('DATABASE_URL'),
        conn_max_age=600,
        conn_health_checks=True,
    )
else:
    DATABASES = {
        'default': {
            'ENGINE': 'django.db.backends.sqlite3',
            'NAME': BASE_DIR / 'db.sqlite3',
        }
    }
```

**File: `requirements.txt`** (add these)

```
dj-database-url==2.1.0
gunicorn==21.2.0
psycopg2-binary==2.9.9
```

### Part B: Critical Errors Summary

| Error | Symptom | Root Cause | Fix |
|-------|---------|-----------|-----|
| **Race condition** | psycopg2.OperationalError: connection refused | `depends_on` without healthcheck starts container before DB ready | Add healthcheck to db, use `condition: service_healthy` |
| **Cannot track requests** | Don't know which container served request | No identifying header | Add `X-Served-By $upstream_addr` header in nginx |

### Part B: Test Results

**Round-robin verified with 9 requests:**
```
Request 1 → X-Served-By: web-1:8000
Request 2 → X-Served-By: web-2:8000
Request 3 → X-Served-By: web-3:8000
Request 4 → X-Served-By: web-1:8000
Request 5 → X-Served-By: web-2:8000
Request 6 → X-Served-By: web-3:8000
Request 7 → X-Served-By: web-1:8000
Request 8 → X-Served-By: web-2:8000
Request 9 → X-Served-By: web-3:8000

✅ Perfect round-robin! All containers getting traffic.
```

**Database consistency:**
```
All 3 containers see identical 3 tasks in PostgreSQL ✅
```

### Part B: Key Takeaway

✅ **Nginx load balancing distributes requests perfectly** - Production applications scale exactly this way

---

## Part C: Static Files Serving ✅

### The Challenge

In scaled setup with bind mounts, each container has its own `/app/static/`:
- web-1 has `/app/static/` from bind mount
- web-2 has `/app/static/` from bind mount
- web-3 has `/app/static/` from bind mount
- nginx has **no access** to any of them

**Problem:** CSS/JS files return 404 errors.

### Solution: Shared Named Volume

**Key changes to `docker-compose-scale.yml`:**

```yaml
services:
  web-1:
    command: sh -c "python manage.py collectstatic --noinput && python manage.py runserver 0.0.0.0:8000"
    volumes:
      - staticfiles:/app/staticfiles  # Write to shared volume
  
  web-2:
    command: sh -c "python manage.py collectstatic --noinput && python manage.py runserver 0.0.0.0:8000"
    volumes:
      - staticfiles:/app/staticfiles  # Write to same shared volume
  
  web-3:
    command: sh -c "python manage.py collectstatic --noinput && python manage.py runserver 0.0.0.0:8000"
    volumes:
      - staticfiles:/app/staticfiles  # Write to same shared volume

  nginx:
    volumes:
      - staticfiles:/app/staticfiles:ro  # Read-only access

volumes:
  staticfiles:  # Shared by all services
```

**How it works:**
1. Each web container runs `collectstatic` → writes to `staticfiles` volume
2. All containers write to **same** shared volume (first write wins)
3. nginx reads from **same** shared volume (read-only)
4. Result: All 3 web containers see identical CSS/JS files

### Part C: Critical Error

| Error | Symptom | Root Cause | Fix |
|-------|---------|-----------|-----|
| **Static files 404** | CSS/JS not loading, 404 errors | Each container has bind mount, nginx can't access | Use shared named volume `staticfiles:/app/staticfiles` for all services |

### Test Results

**Static file collection:**
```powershell
$ docker exec todo_web_1 python manage.py collectstatic --noinput
128 static files copied to '/app/staticfiles'
```

**All containers access same files:**
```powershell
$ docker exec todo_web_1 ls /app/staticfiles/
admin  tasks

$ docker exec todo_web_2 ls /app/staticfiles/
admin  tasks

$ docker exec todo_web_3 ls /app/staticfiles/
admin  tasks

✅ All 3 containers see identical files
```

**Nginx serving CSS successfully:**
```
GET /static/tasks/style.css HTTP/1.1
Response: HTTP/1.1 200 OK
Content-Length: 1838 bytes
Content-Type: text/css

✅ CSS loaded successfully
```

### Part C: Key Takeaway

✅ **Shared named volumes allow multi-container static file serving** - Production apps must do this for CSS/JS/images

---

## Final Architecture Summary

### Containers Running

```
✅ nginx              (port 8000 → load balancer)
✅ web-1, web-2, web-3 (port 8000 internally, round-robin distribution)
✅ postgresql         (port 5432, shared database)

Total: 5 containers working together
```

### Volumes

```
✅ postgres_data_scale  (database persistence)
✅ staticfiles          (shared CSS/JS/images)
```

### Data Flow

```
User Browser
    ↓ (HTTP :8000)
Nginx (Round-robin)
    ├→ web-1 → PostgreSQL ✅ shared
    ├→ web-2 → PostgreSQL ✅ shared
    └→ web-3 → PostgreSQL ✅ shared

CSS/JS:
    └→ Nginx reads from staticfiles volume ✅ shared

Data:
    └→ All containers read/write same PostgreSQL ✅ shared
```

---

## Critical Errors Encountered & Fixed

### Summary Table

| Phase | Error | Impact | Solution |
|-------|-------|--------|----------|
| A | Destructive `-v` flag | Data LOST | Use `docker-compose down` (no flag) |
| A | Fresh volume no migrations | Empty database | Auto-run migrations in Dockerfile |
| A | Volume created vs reused | Confusion | "Created" = new, no message = reused |
| B | Race condition (web→DB) | Connection failed | Add healthcheck + `service_healthy` condition |
| B | Can't track which container | Debugging impossible | Add `X-Served-By` header in nginx |
| C | Static files 404 errors | CSS/JS missing | Use shared named volume for staticfiles |

### Key Learnings

1. **Persistence**: Named volumes survive container lifecycle - use for all databases
2. **Scaling**: Nginx round-robin distributes load perfectly - add more `server` lines to scale
3. **Static Files**: Shared volumes required for multi-container setups - collect once, serve everywhere
4. **Healthchecks**: Critical for service dependencies - always use `condition: service_healthy`
5. **DATABASE_URL**: Environment-based configuration enables prod/dev without code changes

---

## Commands Reference

```powershell
# Start scaled setup
docker-compose -f docker-compose-scale.yml up --build -d

# Check running containers
docker ps

# View logs
docker logs nginx
docker logs todo_web_1

# Test load balancing
for ($i = 1; $i -le 9; $i++) {
    (Invoke-WebRequest http://localhost:8000 -UseBasicParsing).Headers['X-Served-By']
}

# Stop everything (preserves volumes)
docker-compose -f docker-compose-scale.yml down

# Clean up (delete volumes too - DATA LOSS!)
docker-compose -f docker-compose-scale.yml down -v
```


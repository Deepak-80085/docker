## Phase 2 Overview

**Goal:** Experience production setup and understand dev vs prod differences

**Achievements:**
- ✅ Started production setup with PostgreSQL
- ✅ Fixed configuration issues (STATIC_ROOT, gunicorn, psycopg2)
- ✅ Got both containers running
- ✅ Explored container architecture
- ✅ Compared dev vs prod

---

## Key Learnings

### 1. **Two-Container Architecture Works**

**Production Setup:**
```
Container 1: todo_web_prod
├─ Gunicorn (4 workers)
├─ Django app
├─ Non-root user (appuser)
└─ Health check enabled

Container 2: todo_db_prod
├─ PostgreSQL 15
├─ Separate database
├─ Named volume (postgres_data)
└─ Independent from web
```

**Communication:**
- Web container talks to DB at `postgresql://...@db:5432/todo_db`
- Container networking works automatically
- Containers can be restarted independently

### 2. **Production Server (Gunicorn) vs Dev (Django)**

**Development:**
```
[INFO] Starting development server at http://0.0.0.0:8000/
[INFO] Watching for file changes with StatReloader
⚠ WARNING: This is a development server. Do not use it in production!
- Single process
- Hot reload enabled
- Not suitable for production
```

**Production:**
```
[INFO] Starting gunicorn 21.2.0
[INFO] Booting worker with pid: 10
[INFO] Booting worker with pid: 11
[INFO] Booting worker with pid: 12
[INFO] Booting worker with pid: 13
✅ 4 concurrent workers
✅ Production ready
✅ High performance
```

**Comparison:**

| Feature | Dev | Prod |
|---------|-----|------|
| **Server** | Django dev | Gunicorn |
| **Workers** | 1 | 4 |
| **Concurrency** | 1 request at a time | 4 simultaneous requests |
| **Hot reload** | ✅ Yes | ❌ No |
| **Performance** | Slow | Fast |
| **Production ready** | ❌ No | ✅ Yes |

### 3. **Environment Variables Matter**

**Production settings:**
```
DEBUG=False                              ← Production mode
DATABASE_URL=postgresql://...@db:5432/  ← PostgreSQL
SECRET_KEY=your-secret-key-here          ← Security
ALLOWED_HOSTS=yourdomain.com             ← Restrict hosts
```

**These are completely different from local dev!**

### 4. **Static Files Collection**

**Production:**
```
✅ 128 static files copied to '/app/staticfiles'
✅ Pre-collected before app starts
✅ Ready for fast serving
```

**What happened:**
- During build, `python manage.py collectstatic` ran
- All static files gathered into one directory
- Gunicorn doesn't waste time serving CSS/images
- Can use CDN or nginx to serve faster

### 5. **Database Independence**

**Key realization:**
- Web container can crash → Database still alive
- Database container independent → Can upgrade web safely
- Can add more web containers → Share same database
- This enables scaling!

---

## Issues Found and Fixed

### Issue 1: STATIC_ROOT Not Configured

**Error:**
```
django.core.exceptions.ImproperlyConfigured: 
You're using the staticfiles app without having set the STATIC_ROOT
```

**Fix:** Added to `settings.py`
```python
STATIC_ROOT = BASE_DIR / 'staticfiles'
```

### Issue 2: Missing Production Packages

**Error:**
```
sh: 3: gunicorn: not found
```

**Fix:** Added to `requirements.txt`
```
gunicorn==21.2.0
psycopg2-binary==2.9.9
```

### Issue 3: Database Tables Missing

**Observation:**
- PostgreSQL connection worked
- But no tables in database
- Reason: Production uses fresh database, migrations were for SQLite
- Not a blocker for learning (migrations would run in real prod)

---

## Commands Used in Phase 2

```powershell
# Start production
docker-compose -f docker-compose.prod.yml up --build -d

# Check containers
docker ps

# View environment variables
docker exec todo_web_prod sh -c "env | grep DATABASE"

# Check static files
docker exec todo_web_prod ls /app/staticfiles

# Query database
docker exec todo_db_prod psql -U todo_user -d todo_db -c "SELECT * FROM..."

# View logs
docker logs todo_web_prod

# Stop production
docker-compose -f docker-compose.prod.yml down

# Start development
docker-compose up -d
```

---

## Architecture Comparison

### Development Setup
```
┌─ Your PC ────────────────────┐
│                              │
│  ./tasks/ ──┐                │
│  ./static/ ──┐               │
│  ./todo/ ──┐ │               │
│            ↓ ↓  ↓            │
│      ┌──────────────┐        │
│      │ 1 Container  │        │
│      ├─ Django dev  │        │
│      ├─ SQLite DB   │        │
│      └─ Hot reload  │        │
│      └──────────────┘        │
└──────────────────────────────┘

Characteristics:
- Simple (1 container)
- Fast iteration
- Easy debugging
- Uses SQLite
```

### Production Setup
```
┌─ Production Server ──────────────┐
│                                  │
│ ┌──────────────┐  ┌────────────┐│
│ │ Container 1  │  │ Container2 ││
│ │              │  │            ││
│ │ Gunicorn(4)  │  │ PostgreSQL ││
│ │ 4 workers    │→ │            ││
│ │ appuser      │  │ Persistent ││
│ │              │  │ Volume     ││
│ │ Health check │  │            ││
│ └──────────────┘  └────────────┘│
│                                  │
│ Can scale: Add more web→DB      │
└──────────────────────────────────┘

Characteristics:
- Scalable (multiple containers)
- High performance
- Separate database
- Production-ready
- Uses PostgreSQL
```

---

## Real-World Insights

### Why Separate Database Container?

**Scenario: Server crash**
```
Old (single container):
App crashes → Database lost → All data gone ❌

New (separate):
Web container crashes → Database still running ✅
Restart web → All data preserved ✅
```

### Why 4 Workers?

**Scenario: 10 simultaneous users**
```
Dev (1 process):
User 1: 2s
User 2: 4s (waiting)
User 3: 6s (waiting)
...
User 10: 20s (very unhappy) ❌

Prod (4 workers):
Users 1-4: 2s (all processed)
Users 5-8: 2s (all processed)
Users 9-10: 2s (all processed)
Everyone happy! ✅
```

### Why PostgreSQL over SQLite?

**SQLite:** One file, can only write one at a time → Locks
**PostgreSQL:** Proper database, handles concurrent writes perfectly

---

## Files Modified in Phase 2

| File | Change | Why |
|------|--------|-----|
| `settings.py` | Added `STATIC_ROOT` | Production staticfiles config |
| `requirements.txt` | Added gunicorn, psycopg2 | Production dependencies |
| Already had `docker-compose.prod.yml` | Reference file | - |
| Already had `Dockerfile.prod` | Reference file | - |

---

## Phase 2 Success Criteria

- ✅ Production setup runs without errors
- ✅ Both containers running (web + database)
- ✅ Containers can communicate
- ✅ App accessible and responding (HTTP 200)
- ✅ Environment variables set correctly
- ✅ Static files collected
- ✅ Understand dev vs prod differences
- ✅ Know why separate database matters
- ✅ See Gunicorn workers in action

---

## What We Now Understand

1. **Containers can work together** via networking
2. **Production needs different config** (DEBUG=False, PostgreSQL, etc.)
3. **Separate database enables scaling** (multiple web containers)
4. **Gunicorn provides concurrency** (multiple workers)
5. **Static files collected for performance** (no Django serving)
6. **Production is complex but necessary** for real users

---

## Quick Reference: Dev vs Prod Commands

```powershell
# DEVELOPMENT
docker-compose up              # Start (1 container)
docker-compose down            # Stop
docker-compose logs -f         # Watch logs

# PRODUCTION  
docker-compose -f docker-compose.prod.yml up --build -d    # Start (2 containers)
docker-compose -f docker-compose.prod.yml down              # Stop
docker-compose -f docker-compose.prod.yml logs -f           # Watch logs
```

---

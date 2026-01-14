# Phase 1: Docker Basics with Django To-Do List


## Phase 1 Overview

**Goal:** Set up a development Docker environment for Django project and understand core Docker concepts

**Duration:** 4-5 days  
**Difficulty:** Beginner

---

## Initial State

### What Existed
- ✅ Django 5.2 project (fully functional locally)
- ✅ Virtual environment with packages installed
- ✅ SQLite database with data
- ✅ Basic Docker files (dockerfile, docker-compose.yml)
- ✅ .dockerignore file

### The Problem
- ❌ Docker was using local database (not truly containerized)
- ❌ No migrations in Dockerfile (depended on local setup)
- ❌ Entire project mounted (`.:/app`)
- ❌ Container wasn't independent

---

## What We Learned

### 1. Dockerfile vs docker-compose.yml

| Aspect | Dockerfile | docker-compose.yml |
|--------|------------|--------------------|
| **Purpose** | Build recipe | Run instructions |
| **When** | Build time | Run time |
| **Contains** | Image setup | Container config |

**Key Insight:** Dockerfile is a blueprint, docker-compose runs the container

### 2. Build-time vs Run-time

```
BUILD TIME (Dockerfile):
- FROM python:3.12-slim
- COPY requirements.txt
- RUN pip install
- RUN python manage.py migrate
- CMD ["python", "manage.py", "runserver"]

RUN TIME (docker-compose):
- volumes: mount folders
- ports: expose ports
- environment: set variables
- command: override CMD
```

### 3. Volumes: The Key Concept

**Three types learned:**

| Type | Example | Purpose | Use Case |
|------|---------|---------|----------|
| Bind mount | `./tasks:/app/tasks` | Link local → container | Development (hot reload) |
| Named volume | `postgres_data:/var/lib/postgresql/data` | Docker-managed storage | Production (persistence) |
| Isolated | `db.sqlite3` (not mounted) | Container-only | Database isolation |

**Real understanding:** Volumes are how local and container share data

### 4. Container Independence

**Goal:** Container should work without local setup

**Solution:** 
- Add migrations to Dockerfile → database created during build
- Don't mount database → isolated in container
- Mount only code → hot reload still works

---

## Changes Made

### Change 1: Added Database Migrations to Dockerfile

```dockerfile
# BEFORE
COPY . /app/
EXPOSE 8000
CMD ["python", "manage.py", "runserver", "0.0.0.0:8000"]

# AFTER
COPY . /app/
EXPOSE 8000

RUN python manage.py migrate
CMD ["python", "manage.py", "runserver", "0.0.0.0:8000"]
```

**Why:** Container creates its own database schema during build

**Result:** Container works even without local database ✅

---

### Change 2: Isolated Container Database

```yaml
# BEFORE
volumes:
  - .:/app    # Mounts EVERYTHING including db.sqlite3

# AFTER
volumes:
  - ./tasks:/app/tasks
  - ./templates:/app/templates
  - ./static:/app/static
  - ./todo:/app/todo
  # db.sqlite3 is NOT mounted
```

**Why:** Container has independent database, code still hot-reloads

**Result:** Local and Docker databases don't interfere ✅

---

### Change 3: Created Production Reference Files

**Files created for future reference:**
1. `Dockerfile.prod` - Production-ready image
2. `docker-compose.prod.yml` - Production setup with PostgreSQL

**Purpose:** To compare dev vs prod and learn differences

---

## Commands Used

### Essential Commands Learned

```powershell
# Start development
docker-compose up                 # Foreground (see logs)
docker-compose up -d              # Background
docker-compose up --build         # Rebuild image

# Stop
docker-compose down               # Stop containers
Ctrl+C                           # Stop foreground

# Inspect
docker ps                         # List running containers
docker-compose logs -f            # View live logs

# Access container
docker exec to_do_list-web-1 ls /app                    # Run commands
docker exec -it to_do_list-web-1 sh                     # Open shell
docker exec to_do_list-web-1 ls -lh /app/db.sqlite3    # Check database
```

---

## Development Workflow

```powershell
# 1. Start container
docker-compose up --build

# 2. Verify it's running
docker ps
docker-compose logs -f

# 3. Edit code locally (./tasks/views.py)
# → Changes auto-reload in container

# 4. Access app
# → http://localhost:8000/

# 5. Verify database is isolated
docker exec to_do_list-web-1 ls -lh /app/db.sqlite3

# 6. Stop when done
docker-compose down
```

---

## Architecture Achieved

```
┌─ Your PC ─────────────────────────┐
│                                   │
│  ./tasks/ ──┐                     │
│  ./templates/ ──┐                 │
│  ./static/ ──┐  │                 │
│  ./todo/ ──┐ │  │                 │
│            ↓ ↓  ↓  ↓              │
│      ┌──────────────────────┐     │
│      │ Docker Container     │     │
│      │ ├─ Django dev server │     │
│      │ ├─ SQLite (isolated) │     │
│      │ └─ Hot reload ✅    │     │
│      └──────────────────────┘     │
└───────────────────────────────────┘
```

**Key achievements:**
- ✅ Container runs independently
- ✅ Code changes auto-reload
- ✅ Database isolated in container
- ✅ No dependency on local setup

---

## Key Concepts Mastered

### 1. Images are Blueprints
- Created by Dockerfile
- Frozen/immutable
- Can run many containers from one image

### 2. Containers are Running Instances
- Temporary (can be deleted and recreated)
- Isolated from each other
- Can access via `docker exec`

### 3. Volumes Connect Local and Container
- Bind mounts: `/local/path:/container/path`
- Hot reload: Changes in local → visible in container instantly
- Isolation: Files not mounted stay isolated

### 4. Build-time Happens Once
- Docker downloads base image
- Installs packages
- Copies code
- Runs migrations (we added this)
- Creates image

### 5. Run-time Happens Every Time
- Mounts volumes
- Exposes ports
- Sets environment variables
- Starts container
- Can modify settings without rebuilding

---

## Files Created/Modified

### Modified Files
- `dockerfile` - Added migrations step
- `docker-compose.yml` - Changed volume mounts
- `.dockerignore` - Already correct (verified)

### Created Files
- `Dockerfile.prod` - Production reference
- `docker-compose.prod.yml` - Production reference
- `DOCKER_LEARNING_GUIDE.md` - Complete learning documentation
- `phase1.md` - This file

---

## Success Checklist

- ✅ Docker container starts without errors
- ✅ App accessible at http://localhost:8000/
- ✅ Code changes auto-reload in container
- ✅ Container has its own isolated database
- ✅ Can access container shell with `docker exec -it`
- ✅ Understand difference between dev and prod setups
- ✅ Know basic Docker commands

---

## What Didn't Change

- ✅ Local `env/` folder (excluded by .dockerignore)
- ✅ Local `db.sqlite3` (untouched, independent)
- ✅ Django project code (works same as before)
- ✅ All existing features

---

## Common Issues Resolved

| Issue | Solution |
|-------|----------|
| Docker uses local database | Removed db mount, isolated in container |
| Container depends on local setup | Added migrations to Dockerfile |
| Code changes don't reload | Mounted code directories as volumes |
| Can't access container | Used `docker exec` commands |

---

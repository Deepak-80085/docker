# Docker Learning Guide - Django To-Do List Project

**Date:** January 10, 2026  
**Project:** Django To-Do List Application  
**Purpose:** Development Docker Setup for Learning

---

## Table of Contents
1. [Project Overview](#project-overview)
2. [Initial Project State](#initial-project-state)
3. [Docker Concepts Explained](#docker-concepts-explained)
4. [Changes Made](#changes-made)
5. [Development vs Production](#development-vs-production)


---

## Project Overview

### What This Project Is
- **Django 5.2** to-do list application
- **SQLite** database (development)
- **Single app** called `tasks` for managing to-do items
- **Templates** for HTML rendering
- **Static files** for CSS styling

### Project Structure
```
to_do_list/
├── dockerfile                  # Dev Docker image definition
├── Dockerfile.prod            # Prod Docker image definition (reference)
├── docker-compose.yml         # Dev container orchestration
├── docker-compose.prod.yml    # Prod container orchestration (reference)
├── .dockerignore              # Files to exclude from Docker image
├── requirements.txt           # Python dependencies
├── manage.py                  # Django management script
├── db.sqlite3                 # Local database (NOT in Docker)
├── env/                       # Local virtual environment (NOT in Docker)
├── tasks/                     # Django app
│   ├── models.py             # Task model
│   ├── views.py              # Business logic
│   ├── urls.py               # App routes
│   └── migrations/           # Database migrations
├── templates/                 # HTML templates
│   ├── base.html
│   └── tasks/
├── static/                    # CSS, JS, images
│   └── tasks/
│       └── style.css
└── todo/                      # Django project settings
    ├── settings.py           # Configuration
    ├── urls.py               # Main routes
    └── wsgi.py               # Production server interface
```

---

## Initial Project State

### What Was Already Set Up
1. **Django project** fully functional locally
2. **Virtual environment** (`env/`) with packages installed
3. **SQLite database** with existing data
4. **Docker configuration** that was sharing local database
5. **`.dockerignore`** file already excluding some files

### Initial Problem
- Docker was using the **local database** (not truly isolated)
- No migrations in Dockerfile (dependent on local setup)
- Mounting entire project folder (`.:/app`)

---

## Docker Concepts Explained

### 1. **Dockerfile vs docker-compose.yml**

| File | Purpose | When It Runs |
|------|---------|--------------|
| **Dockerfile** | Recipe to BUILD an image | `docker build` or `docker-compose build` |
| **docker-compose.yml** | Instructions to RUN containers | `docker-compose up` |

**Analogy:**
- **Dockerfile** = Recipe card (how to make a cake)
- **docker-compose.yml** = Party instructions (how many cakes, where to serve)

### 2. **Image vs Container**

```
Image (Dockerfile)               Container (docker-compose)
===============                  ==========================
Blueprint/Template    ─────→     Running instance
Frozen/Immutable                 Active/Running
Can create many                  Can run many from 1 image
```

**Analogy:**
- **Image** = App in the App Store
- **Container** = App running on your phone

### 3. **Volumes - The Confusing Part**

**Without volumes:**
```
Local: ./tasks/views.py (v1)
Container: /app/tasks/views.py (v1 - frozen in image)

You edit ./tasks/views.py to v2
Container still has v1 (need to rebuild image)
```

**With volumes:**
```
Local: ./tasks/views.py (v1)
Container: /app/tasks/views.py → LINKED to local file

You edit ./tasks/views.py to v2
Container sees v2 immediately (hot reload)
```

**Types of mounts:**

| Type | Syntax | Purpose | Dev/Prod |
|------|--------|---------|----------|
| **Bind mount** | `./tasks:/app/tasks` | Link local folder to container | Dev only |
| **Named volume** | `postgres_data:/var/lib/postgresql/data` | Persistent storage managed by Docker | Prod |
| **Anonymous volume** | `/app/db.sqlite3` | Isolate file from host | Dev/Prod |

### 4. **Build-time vs Run-time**

```
BUILD TIME (Dockerfile):
- FROM python:3.12-slim        ← Download base image
- COPY requirements.txt        ← Copy from local
- RUN pip install             ← Execute during build
- COPY . /app/                ← Copy all code
- RUN python manage.py migrate ← Create database schema
- CMD [...]                   ← Save as default command

RUN TIME (docker-compose):
- volumes:                    ← Mount local folders
- ports:                      ← Open network ports
- environment:                ← Set env variables
- command:                    ← Override CMD (if needed)
```

### 5. **.dockerignore - What NOT to Copy**

```
.dockerignore content:
├── env/           ← Local virtual environment (huge, not needed)
├── venv/          ← Alternative venv name
├── db.sqlite3     ← Local database (should be isolated)
├── __pycache__/   ← Python compiled files (regenerated)
├── *.pyc          ← Compiled Python files
├── .git/          ← Git history (not needed in container)
```

**Why exclude?**
- Smaller image size (faster builds)
- Avoid conflicts (local vs container Python versions)
- Security (don't include secrets in image)

---

## Changes Made

### Change 1: Added Migrations to Dockerfile

**Before:**
```dockerfile
COPY . /app/
EXPOSE 8000
CMD ["python", "manage.py", "runserver", "0.0.0.0:8000"]
```

**After:**
```dockerfile
COPY . /app/
EXPOSE 8000

# Run migrations and start the application
RUN python manage.py migrate
CMD ["python", "manage.py", "runserver", "0.0.0.0:8000"]
```

**Why?**
- Without this, Docker assumes database already exists
- With this, database schema is created during image build
- Makes container self-contained

**Problem Solved:** Container works even without local database

---

### Change 2: Isolated Container Database

**Before:**
```yaml
volumes:
  - .:/app    # ← Mounts EVERYTHING including db.sqlite3
```

**After:**
```yaml
volumes:
  - ./tasks:/app/tasks
  - ./templates:/app/templates
  - ./static:/app/static
  - ./todo:/app/todo
  # db.sqlite3 is NOT mounted → isolated in container
```

**Why?**
- Container has its own database (truly isolated)
- Code is still mounted (hot reload works)
- Local and Docker databases don't interfere

**Problem Solved:** Container is independent, not using local database

---

### Change 3: Created Production Reference Files

**Created:**
1. `Dockerfile.prod` - Production-ready image
2. `docker-compose.prod.yml` - Production orchestration

**Key differences (Dev vs Prod):**

| Feature | Development | Production |
|---------|-------------|------------|
| **Volumes** | ✅ Code mounted | ❌ No volumes (frozen) |
| **Server** | Django dev server | Gunicorn (4 workers) |
| **Database** | SQLite (inside container) | PostgreSQL (separate container) |
| **User** | root | appuser (non-root) |
| **Healthcheck** | ❌ None | ✅ Auto-restart on failure |
| **System deps** | None | postgresql-client, curl |
| **Static files** | Dynamic | Pre-collected |

---

## Development vs Production

### Development Setup (Current)

**Architecture:**
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

**Start command:**
```powershell
docker-compose up
```

**Characteristics:**
- ✅ Code changes reflect immediately
- ✅ Easy debugging
- ✅ Fast iteration
- ❌ Not secure
- ❌ Not scalable
- ❌ Single-threaded

---

### Production Setup (Reference)

**Architecture:**
```
┌─ Production Server ───────────────────────┐
│                                           │
│  ┌──────────────────┐  ┌─────────────────┐│
│  │ Web Container #1 │  │ DB Container    ││
│  │ ├─ Gunicorn      │  │ PostgreSQL      ││
│  │ ├─ 4 workers     │→ │ ├─ ACID         ││
│  │ └─ Non-root user │  │ ├─ Concurrent   ││
│  └──────────────────┘  │ └─ Volume       ││
│                        └─────────────────┘│
│  ┌──────────────────┐                     │
│  │ Web Container #2 │→                    │
│  └──────────────────┘                     │
│                                           │
│  ┌──────────────────┐                     │
│  │ Load Balancer    │                     │
│  └──────────────────┘                     │
└───────────────────────────────────────────┘
```

**Start command:**
```powershell
docker-compose -f docker-compose.prod.yml up -d
```

**Characteristics:**
- ✅ Handles 1000+ concurrent users
- ✅ Auto-recovery (healthcheck)
- ✅ Secure (non-root user)
- ✅ Scalable (multiple containers)
- ✅ Separate database
- ❌ No hot reload (must rebuild to update)

---

### When to Use Each

| Scenario | Use Dev | Use Prod |
|----------|---------|----------|
| Writing code | ✅ | ❌ |
| Testing locally | ✅ | ❌ |
| Learning Docker | ✅ | ❌ |
| Deploying to server | ❌ | ✅ |
| CI/CD pipeline | ❌ | ✅ |
| Real users | ❌ | ✅ |

---

## Commands Reference

### Basic Docker Commands (What We Used)

```powershell
# Check Docker is installed and running
docker --version
docker ps                    # List running containers

# Start development environment
docker-compose up            # Start in foreground (see logs)
docker-compose up -d         # Start in background (detached)
docker-compose up --build    # Rebuild image and start

# Stop containers
docker-compose down          # Stop and remove containers
Ctrl+C                       # Stop foreground process

# View logs (we used this to check if app was running)
docker-compose logs -f       # Follow live logs
```

### Accessing Running Containers (What We Used)

```powershell
# Check files inside container (we used this to verify database location)
docker exec to_do_list-web-1 ls /app
docker exec to_do_list-web-1 ls -lh /app/db.sqlite3

# Check which Python environment container is using
docker exec to_do_list-web-1 python -c "import sys; print(sys.prefix)"

# Open shell inside container (for exploring)
docker exec -it to_do_list-web-1 sh
```

### Cleaning Up (Optional)

```powershell
# Stop and remove containers (we used this)
docker-compose down

# If you want to clean up completely
docker system prune -a  # Remove all unused images and containers
```

### Our Development Workflow (What We Did)

```powershell
# 1. Check Docker is running
docker --version
docker ps

# 2. Start development environment
docker-compose up --build

# 3. Verify container is running
docker ps

# 4. Check logs to see Django is running
docker-compose logs -f

# 5. Access app in browser
#    http://localhost:8000/

# 6. Verify database isolation
docker exec to_do_list-web-1 ls -lh /app/db.sqlite3

# 7. Stop when done
docker-compose down
```

---

## Common Issues You Might Face

### Issue: "Port 8000 already in use"

**Problem:** Another process is using port 8000

**Solution:**
```powershell
# Stop the container and try again
docker-compose down
docker-compose up
```

---

### Issue: "Changes not reflecting in container"

**Problem:** Code not mounted properly

**Solution:**
```powershell
# Rebuild the container
docker-compose down
docker-compose up --build
```

---

### Issue: "Can't connect to Docker"

**Problem:** Docker Desktop not running

**Solution:**
Start Docker Desktop application and wait for it to fully start

---

## What's Next?

### 1. **Keep This Project as Reference**
- ✅ This is your Docker basics reference
- ✅ Experiment with different settings
- ✅ Try modifying the code and see hot reload work

### 2. **When You're Ready: Start a New Project**

**Recommended: Build a portfolio website or blog**
- Apply Docker from scratch
- Use production setup (PostgreSQL, Gunicorn)
- Learn deployment (GitHub, Azure, etc.) step by step

---

## Key Learnings Summary

### What You Learned

1. **Dockerfile vs docker-compose.yml**
   - Dockerfile = Build the image (recipe)
   - docker-compose = Run the container (party instructions)

2. **Volumes = Sharing Files**
   - Bind mounts for development (hot reload)
   - Named volumes for persistence (databases)
   - Isolation when needed (no mount)

3. **Build-time vs Run-time**
   - `COPY`, `RUN` happen during build
   - `volumes`, `ports`, `command` happen at runtime

4. **Development vs Production**
   - Dev: Fast iteration, hot reload, SQLite
   - Prod: Scalability, security, PostgreSQL

5. **Container Independence**
   - Images are self-contained
   - Containers are isolated
   - Volumes connect local and container

---

## Useful Resources

### Documentation
- [Docker Documentation](https://docs.docker.com/) - Official Docker docs
- [Docker Compose Documentation](https://docs.docker.com/compose/) - For docker-compose.yml

### Tools You Have
- Docker Desktop (Windows) - What you're using
- VS Code Docker Extension - Helpful for managing containers

---

## Quick Reference Card

```
┌─────────────────────────────────────────────────────────┐
│ DOCKER QUICK REFERENCE                                  │
├─────────────────────────────────────────────────────────┤
│ Start dev:        docker-compose up                     │
│ Stop:             docker-compose down                   │
│ Rebuild:          docker-compose up --build             │
│ Logs:             docker-compose logs -f                │
│ Shell:            docker exec -it to_do_list-web-1 sh   │
│ List containers:  docker ps                             │
│ List images:      docker images                         │
│                                                          │
│ App URL:          http://localhost:8000/                │
│ Admin:            http://localhost:8000/admin/          │
└─────────────────────────────────────────────────────────┘
```

---

## Project Status

✅ **Development setup complete and working**
- Docker container runs independently
- Code hot reload enabled
- Database isolated in container
- Ready for learning and experimentation

📝 **Production setup documented**
- Reference files created (Dockerfile.prod, docker-compose.prod.yml)
- Ready to apply to new project


# GopherEngine

> A backend code execution engine built in Go — the kind of system that powers LeetCode's judge, but built from scratch to understand how it actually works.

---

## Why I Built This

Online judges like LeetCode and HackerRank let you submit code in any language and get results back in seconds. I wanted to understand the core engineering behind that:

- How do you run **untrusted user code safely** without affecting the host system?
- How do you handle **many submissions concurrently** without blocking or crashing?
- How do you design a **non-blocking API** that accepts jobs and lets clients poll for results?

This project is my answer. It implements the backend engine of a code execution platform — isolated execution via Docker, concurrent job processing via a worker pool, and a clean REST API for job submission and status tracking.

---

## How It Works

```
Client
  │
  ├── POST /process  (code + language)
  │       │
  │       ▼
  │   Job created with unique ID
  │   Job pushed into Channel (queue, capacity: 100)
  │   ID returned immediately to client
  │
  └── GET /status?id=...
          │
          ▼
      Job result returned (queued / completed / failed)

Channel
  │
  ├── Worker 1 ──► pulls job ──► spins up Docker container ──► runs code ──► saves result
  ├── Worker 2 ──► pulls job ──► spins up Docker container ──► runs code ──► saves result
  ├── Worker 3 ──► (waiting)
  ├── Worker 4 ──► (waiting)
  └── Worker 5 ──► (waiting)
```

The API is **non-blocking** — you submit code and get an ID back instantly. The actual execution happens asynchronously in the background. You poll `/status` to get the result when it's ready.

---

## Architecture

### Core Components

| Component | File | Responsibility |
|-----------|------|----------------|
| HTTP Server | `main.go` | Initializes Gin server, queue, and routes |
| Request Handlers | `internal/api/handlers.go` | Handles POST /process and GET /status |
| Router | `internal/api/routes.go` | Maps endpoints to handlers |
| Queue & Workers | `internal/queue/queue.go` | Job channel, worker pool, Docker execution |
| Job Model | `internal/model/job.go` | Job data structure |

### Key Design Decisions

**Worker Pool over unlimited goroutines**
Spawning a new goroutine per job is dangerous under high load — memory usage becomes unbounded. A fixed worker pool (5 workers) caps concurrency, giving predictable resource usage and backpressure via the buffered channel.

**Buffered Channel as Queue**
Go channels are first-class concurrency primitives. A buffered channel of size 100 acts as the job queue — workers block on it when idle and pick up jobs as they arrive. No external queue dependency needed.

**Mutex-protected Result Map**
Multiple workers write results concurrently to a shared map. A `sync.RWMutex` ensures safe concurrent access — write lock for workers saving results, read lock for status checks.

**Docker for Isolation**
Each code submission runs inside a fresh, isolated Docker container with the appropriate language runtime. The container is destroyed after execution (`--rm` flag), ensuring no state leaks between submissions.

---

## Supported Languages

| Language | Docker Image |
|----------|-------------|
| Python | `python:3.9-slim` |
| JavaScript | `node:14-alpine` |
| TypeScript | `node:14-alpine` |
| Go | `golang:1.16-alpine` |
| C++ | `gcc:latest` |
| C | `gcc:latest` |

---

## API Reference

### Submit Code
```
POST /process
Content-Type: application/x-www-form-urlencoded

content=print("hello world")&language=python
```

**Response:**
```json
{ "id": "20260320194424.972923414" }
```

### Check Status
```
GET /status?id=20260320194424.972923414
```

**Response:**
```json
{
  "id": "20260320194424.972923414",
  "language": "python",
  "content": "print(\"hello world\")",
  "result": "Output: hello world\n",
  "status": "completed",
  "done_time": "2026-03-20T19:44:30Z"
}
```

**Status values:** `queued` → `completed` / `failed`

---

## Running Locally

### Prerequisites
- Docker

### Steps

```bash
# Clone the repo
git clone https://github.com/kanika1206/CodeEngine-GopherQueueSystem.git
cd CodeEngine-GopherQueueSystem

# Build the image
docker build -t queue_system_golang .

# Run (requires Docker socket access for code execution)
docker run -p 8080:8080 -v /var/run/docker.sock:/var/run/docker.sock queue_system_golang
```

> **Note:** Docker socket mounting requires a native Linux environment. Recommended: run on a Linux VM or server for full code execution functionality.

### Test it

```bash
# Submit a job
curl -X POST http://localhost:8080/process \
  -d "content=print('hello world')&language=python"

# Check status (replace with your ID)
curl "http://localhost:8080/status?id=YOUR_ID_HERE"
```

---

## Tech Stack

- **Language:** Go 1.22
- **Web Framework:** Gin
- **Concurrency:** Goroutines, Channels, sync.RWMutex
- **Execution:** Docker (per-language isolated containers)
- **Containerization:** Docker (multi-stage build)

---

## What I Learned

- How to design **async job processing** systems with a producer-consumer pattern
- Go's concurrency model — goroutines and channels as first-class primitives
- **Docker-in-Docker** patterns and their limitations in different environments
- Mutex strategies for safe concurrent map access (`RWMutex` for read-heavy workloads)
- Building production-style REST APIs with Gin

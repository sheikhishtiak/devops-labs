# Lab 01 — Process Investigation
**Day 02 | DevOps Sprint**
**Author:** Ahmed
**Goal:** Find and control Linux processes entirely from the command line.

---

## Concepts Covered

| Tool | Purpose |
|---|---|
| `ps aux` | Snapshot of all running processes |
| `systemctl` | Manage systemd services (start / stop / reload / status) |
| `kill` | Send signals directly to a process by PID |
| `ss` | Inspect open network sockets and listening ports |

---

## Setup — Install nginx

```bash
sudo apt update && sudo apt install -y nginx
sudo systemctl start nginx
```

- `apt update` refreshes the local package index so apt knows about the latest versions.
- `-y` skips the interactive yes/no prompt — required for non-interactive/scripted installs.
- `systemctl start nginx` starts nginx in case it didn't auto-start after install.

---

## Exercise 1 — Find nginx with `ps aux`

```bash
ps aux | grep "[n]ginx"
```

- `ps aux` lists every process on the system for all users:
  - `a` = all users
  - `u` = show user/owner column
  - `x` = include processes not attached to a terminal (TTY)
- The bracket trick `[n]ginx` prevents grep from matching its own process in the output. Without it, you'd see a ghost `grep nginx` line alongside the real results.

**Action:** Note the PID in column 2 of the master process line. The master process owns all worker processes — killing it stops nginx entirely.

---

## Exercise 2 — Verify status with `systemctl`

```bash
sudo systemctl status nginx
```

- Shows whether systemd considers the service **active**, its main PID, memory usage, and recent log lines pulled from journald.
- Cross-check: the PID here should match the master PID you saw in `ps aux`.

---

## Exercise 3 — Reload config without restarting (zero-downtime)

```bash
sudo systemctl reload nginx
sudo systemctl status nginx
```

- `reload` sends **SIGHUP** to the master process, which re-reads `nginx.conf` and gracefully hands off connections to freshly spawned workers.
- The master PID stays the same — no downtime, no dropped connections.
- This is the **production-safe** way to apply config changes, as opposed to `restart` which tears down and re-creates the process.

**Verify:** Run `systemctl status` again — the master PID should be identical to before the reload.

---

## Exercise 4 — Stop nginx with `kill` (not systemctl)

```bash
NGINX_PID=$(ps aux | grep "[n]ginx: master" | awk '{print $2}')
echo "Nginx master PID: $NGINX_PID"
sudo kill -SIGTERM "$NGINX_PID"
sleep 2
ps aux | grep "[n]ginx" || echo "nginx stopped"
sudo systemctl status nginx || true
```

**Breaking it down line by line:**

| Command | What it does |
|---|---|
| `grep "[n]ginx: master"` | Isolates the master process line (not the workers) |
| `awk '{print $2}'` | Extracts column 2, which is the PID field |
| `kill -SIGTERM "$NGINX_PID"` | Sends signal 15 — graceful shutdown request |
| `sleep 2` | Waits 2 seconds for the process to finish shutting down |
| `\|\| echo "nginx stopped"` | Fallback so the script doesn't abort when grep finds zero matches |
| `\|\| true` | Keeps the script alive even though `status` returns non-zero for a stopped service |

**SIGTERM vs SIGKILL:**

- `SIGTERM` (15) = *"please shut down gracefully"* — nginx finishes active requests before exiting.
- `SIGKILL` (9) = immediate, forceful termination — no cleanup. Use only as a last resort.
- Always try `SIGTERM` first in production.

---

## Exercise 5 — Restart nginx via systemctl

```bash
sudo systemctl start nginx
sleep 1
```

- `start` re-launches the nginx master and worker processes under systemd supervision.
- systemd assigns a **new PID** — verify this by checking `systemctl status` after the start.
- `sleep 1` gives the process table time to fully update before the next command reads it.

---

## Exercise 6 — Check what port nginx is listening on

```bash
sudo ss -tlnp | grep nginx
```

**`ss` flag breakdown:**

| Flag | Meaning |
|---|---|
| `-t` | TCP sockets only |
| `-l` | Listening sockets only (servers waiting for connections) |
| `-n` | Show port numbers, not service names (`80` instead of `http`) |
| `-p` | Show the process name and PID that owns each socket |

**Expected output:**
```
LISTEN  0  511  0.0.0.0:80  0.0.0.0:*  users:(("nginx",pid=XXXX,...))
LISTEN  0  511     [::]:80     [::]:*  users:(("nginx",pid=XXXX,...))
```

- `0.0.0.0:80` = listening on all IPv4 interfaces, port 80 (standard HTTP)
- `[::]:80` = same for IPv6

**Alternative (older systems where `ss` is unavailable):**
```bash
sudo netstat -tlnp | grep nginx
```

---

## Key Takeaways

1. **`ps aux | grep "[n]ginx"`** — the bracket trick is a real-world pattern you'll see in production scripts and interviews.
2. **`reload` vs `restart`** — reload = zero-downtime config update; restart = full process teardown. Default to reload in prod.
3. **SIGTERM before SIGKILL** — always give a process a chance to clean up gracefully.
4. **PID tracking** — after a reload the PID stays the same; after a restart it changes. This distinction matters when scripting health checks.
5. **`ss` over `netstat`** — `netstat` is deprecated on modern Linux. `ss` is faster and more feature-rich.

---

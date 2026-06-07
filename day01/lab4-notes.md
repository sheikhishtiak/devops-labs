# Day 01 — Lab 4: Simulate a Real Deployment Permission Failure

**Host:** `ip-172-31-42-216` (AWS EC2)
**OS:** Ubuntu 26.04 LTS
**Working directory:** `/opt/myapp/`
**Duration:** ~45 minutes
**Status:** ✅ Complete

---

## Goal

Experience the exact permission error that causes real deployment failures, learn to diagnose it from first principles, and practice two different fixes — each representing a different real-world strategy.

---

## Setup

```bash
sudo mkdir -p /opt/myapp/config
sudo touch /opt/myapp/config/app.conf
sudo bash -c 'echo "port=9000" > /opt/myapp/config/app.conf'
sudo useradd -m -s /bin/bash deployuser
```

This creates:
- A mock application directory owned by `root`
- A config file with a single setting (`port=9000`)
- A new system user `deployuser` — simulating a CI/CD service account or a deployment pipeline user

---

## 1. The Error — What Happened and Why

```bash
sudo -u deployuser cat /opt/myapp/config/app.conf
# cat: /opt/myapp/config/app.conf: Permission denied
```

**Why it failed — the full chain:**

Linux checks permissions at every level of the path, not just the file itself. To read `/opt/myapp/config/app.conf`, a user needs:

1. Execute (`x`) on `/opt/` — to enter it
2. Execute (`x`) on `/opt/myapp/` — to enter it
3. Execute (`x`) on `/opt/myapp/config/` — to enter it
4. Read (`r`) on `/opt/myapp/config/app.conf` — to read the file

`sudo mkdir` creates directories owned by `root:root`. By default that means `755` — owner full, group and others read+execute. So `/opt/` and the directory tree were actually traversable. The failure was that `deployuser` had **no ownership and no group membership** that granted access to the specific file or a parent dir that was locked down.

**The exact reason:** `/opt/myapp/` and everything inside it was owned by `root`. `deployuser` is not `root`, not in `root`'s group, so it falls into the "others" category. As long as "others" has no read permission on the file or a parent directory is mode `700`, access is denied.

**Real-world parallel:** This is the #1 cause of "works on my machine, fails in CI" failures. The developer runs the pipeline as themselves (often with broad permissions). The CI runner executes as a restricted service account like `jenkins`, `gitlab-runner`, or `deployuser` — and hits this wall.

---

## 2. Diagnosis — How I Found the Problem

```bash
ls -la /opt/myapp/
ls -la /opt/myapp/config/
```

**What to look for in the output:**

```
drwxr-xr-x  3 root root 4096 ... /opt/myapp/
drwxr-xr-x  2 root root 4096 ... /opt/myapp/config/
-rw-r--r--  1 root root    9 ... app.conf
```

Reading the diagnosis:
- Owner: `root` — `deployuser` is not root
- Group: `root` — `deployuser` is not in the `root` group
- Others permissions: `r--` on the file, `r-x` on directories

Wait — `r--` on the file and `r-x` on the directories means "others" *can* read the file. So why did it fail?

The answer is in the **directory permissions**. If `myapp/` was created with a more restrictive mode (e.g. `750` or `700`), others can't even enter the directory to reach the file. The `ls -la` output reveals exactly which level of the path is blocking access.

**This is the diagnostic pattern to memorize:**
> Walk the path from `/` to the file. At each level, ask: does this user have execute permission to pass through? Does the final file have read permission? The first `no` is your bug.

**Additional diagnostic tool:**

```bash
stat /opt/myapp/config/app.conf
# Shows: owner UID, group GID, and octal mode — more precise than ls
```

---

## 3. The Fixes

### Fix 1 — `chown`: Transfer Ownership to deployuser

```bash
sudo chown -R deployuser:deployuser /opt/myapp
sudo -u deployuser cat /opt/myapp/config/app.conf
# port=9000
```

**What `-R` does:** Recursively changes ownership of `/opt/myapp/` and everything inside it. One command covers all nested directories and files.

**Why this works:** `deployuser` is now the owner of the entire tree. Owner permissions apply, which are `rwx` on directories and `rw-` or `r--` on files — more than enough to read `app.conf`.

**When to use Fix 1 in production:**
- The service owns its own files exclusively (e.g. a single-tenant app)
- You're running a single deploy user per application (common pattern)
- Example: your `nginx` process owns `/var/www/html/`, your `postgres` process owns `/var/lib/postgresql/`

**Downside of Fix 1:** If multiple services or users need access to the same files, giving one user full ownership excludes the others. That's when Fix 2 is the right tool.

---

### Fix 2 — Group-Based Access (the Production Standard)

```bash
sudo groupadd appgroup
sudo usermod -aG appgroup deployuser
sudo chown -R root:appgroup /opt/myapp
sudo chmod -R 750 /opt/myapp
sudo -u deployuser cat /opt/myapp/config/app.conf
# port=9000
```

**Breaking down each command:**

| Command | What it does |
|---|---|
| `groupadd appgroup` | Creates a new group to represent "has access to this app" |
| `usermod -aG appgroup deployuser` | Adds `deployuser` to `appgroup`. The `-a` flag means *append* — without it, you'd remove the user from all other groups |
| `chown -R root:appgroup /opt/myapp` | Root still owns the files; `appgroup` is the owning group |
| `chmod -R 750 /opt/myapp` | Owner: `rwx`, Group: `r-x`, Others: `---` |

**Permission breakdown for `750`:**

```
Owner (root):      rwx  = 7  → full control
Group (appgroup):  r-x  = 5  → read and traverse, cannot write
Others:            ---  = 0  → completely locked out
```

**Why this works:** `deployuser` is now in `appgroup`. The group has `r-x` on all directories (can traverse) and `r--` on files (can read). Access granted.

**When to use Fix 2 in production:**
- Multiple users or services need access to the same files (a deploy user + a monitoring agent + a log shipper, for example)
- You want to control access by role, not by individual account
- Example: `chown -R root:www-data /var/www/html && chmod -R 750` is standard for web servers — root owns it, the `www-data` group (nginx/apache) can read it, nobody else can touch it

**Important note about `usermod -aG`:** Group membership changes take effect on the *next login*. In a script or CI pipeline, the new group won't be active in the current shell session. You can force it with `newgrp appgroup` or by re-logging in. This catches people in production — they add the user to a group, retry immediately, and it still fails.

---

## Which Fix I Used and Why

I ran both fixes sequentially to understand both patterns, but **Fix 2 is the one I'd use in a real deployment.**

Here's why:

Fix 1 (`chown`) is fast but brittle. If you later add a second service that needs to read the same config — a log rotation daemon, a secrets-fetching sidecar, a monitoring agent — you have to keep reassigning ownership or start adding those users to the owner's group anyway. You end up at Fix 2 eventually.

Fix 2 (group-based) maps to how production systems are actually structured. In any real environment, access is controlled by role:
- `appgroup` → deploy users, app processes
- `loggroup` → log shippers, monitoring agents  
- `admingroup` → engineers who need direct access

The file stays owned by `root` (or a service account). Groups determine who can read, write, or execute. Permissions are auditable and scalable.

---

## Cleanup

```bash
sudo userdel -r deployuser 2>/dev/null
sudo groupdel appgroup 2>/dev/null
sudo rm -rf /opt/myapp
```

The `2>/dev/null` suppresses errors if the user or group doesn't exist — safe to run idempotently.

---

## Mental Model: The Three-Question Permission Diagnosis

When you hit `Permission denied` on any file in production, ask these three questions in order:

```
1. Who is the process running as?
   → ps aux | grep <process>  OR  whoami  OR  id

2. Who owns the file and what are the permissions?
   → ls -la /path/to/file
   → ls -la /path/to/  (check the directory too)

3. Is the process user the owner, in the owning group, or neither?
   → id <username>   shows all group memberships
   → If neither → they fall into "others" permissions
```

If the user is "others" and the file is `750`, access denied. You now know exactly which lever to pull.

---

## Key Concepts Locked In

**`chown -R` vs `chmod -R`:** `chown` changes *who* owns the file. `chmod` changes *what* the owner/group/others can do. You often need both together when setting up a new service directory.

**The `-a` flag on `usermod` is not optional.** `usermod -G appgroup deployuser` (without `-a`) removes the user from every other group and puts them only in `appgroup`. That will break SSH, sudo, and anything else that depends on existing group membership. Always use `-aG`.

**`/opt/` is the right place for third-party and custom application files.** The FHS (Filesystem Hierarchy Standard) reserves `/opt/` for add-on application software. When you deploy a custom app in production, it goes here — not in `/usr/` (system packages), not in `/home/` (user files).

**Principle of Least Privilege in practice:** `chmod 750` on app directories is correct. "Others" should have zero access to application config, especially anything that might contain ports, hostnames, or secrets. The default `755` that `mkdir` creates is too permissive for production application directories.

---

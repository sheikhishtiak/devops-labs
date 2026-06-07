# Day 01 — Lab 3: Permission Break-and-Fix

**Host:** `ip-172-31-42-216` (AWS EC2)
**OS:** Ubuntu 26.04 LTS
**Working directory:** `~/devops-labs/day01`
**Duration:** ~60 minutes
**Status:** ✅ Complete

---

## Why This Lab Matters

Broken permissions are one of the top causes of deployment failures in real environments. A script that can't execute, a secret file that's world-readable, or a shared directory with no sticky bit — all three are incidents waiting to happen. This lab drills the three most common permission scenarios a DevOps engineer hits in production.

---

## Files Created

| File | Purpose |
|---|---|
| `deploy.sh` | A simulated deployment script |
| `app.conf` | A standard application config file |
| `secret.conf` | A secrets file holding DB password and API key |

---

## Step 1 — Create the Files

```bash
cat > deploy.sh << 'EOF'
#!/bin/bash
echo "Deploying application..."
cat app.conf
echo "Deploy complete."
EOF

cat > secret.conf << 'EOF'
db_password=supersecret123
api_key=abc123xyz
EOF
```

After creation, both files default to `644` — readable by everyone, executable by no one.

---

## Step 2 — The Execute Bit Failure (and Fix)

```bash
./deploy.sh
# bash: ./deploy.sh: Permission denied
```

**Why it failed:** A new file has no execute bit by default. The kernel refuses to run it even though you own it.

```bash
chmod +x deploy.sh
./deploy.sh
# Deploying application...
# Deploy complete.
```

**What `+x` does:** Adds the execute bit for owner, group, and others (equivalent to going from `644` → `755` in most umask environments).

---

## Step 3 — Lock Down the Secrets File

```bash
chmod 600 secret.conf
ls -l secret.conf
# -rw------- 1 ubuntu ubuntu 45 Jun  7 03:23 secret.conf
```

**Permission breakdown:**

| Who | Bits | Meaning |
|---|---|---|
| Owner (ubuntu) | `rw-` | Can read and write |
| Group | `---` | No access |
| Others | `---` | No access |

**Why 600 for secrets:** If this were `644`, any user on the system could `cat` your DB password. In a shared EC2 or container environment, that's a real risk. `600` is the standard for private keys (`~/.ssh/id_rsa` ships this way for the same reason).

---

## Step 4 — Sticky Bit on a Shared Directory

```bash
mkdir /tmp/shared-workspace
chmod 1777 /tmp/shared-workspace
ls -ld /tmp/shared-workspace
# drwxrwxrwt 2 ubuntu ubuntu 4096 Jun  7 03:XX /tmp/shared-workspace
```

**What the sticky bit (`t`) does:** In a world-writable directory (`777`), normally any user can delete any other user's files. The sticky bit prevents that — you can only delete files you own, even if you have write access to the directory.

**Real-world example:** `/tmp` itself uses `1777`. Multiple processes write temp files there. Without the sticky bit, any process could delete another's temp files — a reliability and security problem.

**The `1` in `1777`:** The leading digit sets special bits. `1` = sticky. `2` = setgid. `4` = setuid.

---

## Step 5 — Numeric chmod Drill

```bash
chmod 644 app.conf        # Standard config: owner rw, group r, others r
chmod 755 deploy.sh       # Standard script: owner rwx, group rx, others rx
chmod 700 secret.conf     # Private: owner rwx only, no one else
```

**Final `ls -l` output (verified on EC2):**

```
-rw-r--r-- 1 ubuntu ubuntu   48 Jun  7 03:04 app.conf
-rwxr-xr-x 1 ubuntu ubuntu   81 Jun  7 03:21 deploy.sh
-rwx------ 1 ubuntu ubuntu   45 Jun  7 03:23 secret.conf
```

---

## Challenge — Predict `rwxr-x---` Without a Table

**Problem:** What is the numeric value of `rwxr-x---`?

**Working it out from scratch:**

```
Owner:  rwx  = 4 + 2 + 1 = 7
Group:  r-x  = 4 + 0 + 1 = 5
Others: ---  = 0 + 0 + 0 = 0

Answer: 750
```

**Verify by setting it and reading back:**

```bash
chmod 750 deploy.sh
stat -c %a deploy.sh
# 750
```

**Mental model I use:** Each permission group (owner/group/others) is a 3-bit binary number. `rwx` = `111` = 7. `r-x` = `101` = 5. `r--` = `100` = 4. `---` = `000` = 0. Once you see the binary pattern, you stop needing to memorize the table.

---

## Permission Reference Card

| Octal | Binary | Symbolic | Common Use |
|---|---|---|---|
| 7 | 111 | rwx | Owner of executable |
| 6 | 110 | rw- | Owner of config/data file |
| 5 | 101 | r-x | Group/others on executable |
| 4 | 100 | r-- | Group/others on config file |
| 0 | 000 | --- | No access |

| Numeric | Symbolic | Typical target |
|---|---|---|
| 700 | rwx------ | Private scripts, SSH keys |
| 600 | rw------- | Secret files, private keys |
| 755 | rwxr-xr-x | Public scripts, binaries |
| 644 | rw-r--r-- | Config files, web assets |
| 750 | rwxr-x--- | Scripts accessible to group only |
| 1777 | drwxrwxrwt | Shared temp directories |

---

## Key Concepts Locked In

**Execute bit is not inherited.** Every script you create needs `chmod +x` before it will run. This catches people constantly in CI/CD pipelines — a script works locally but fails in the pipeline because the execute bit wasn't committed to Git.

**Git and permissions.** Git tracks the execute bit but not full permission modes. If you `chmod 755` a script and commit it, Git records that it's executable. If you forget, the pipeline clone will have a non-executable script.

**Secrets in files vs. environment variables.** `chmod 600` reduces risk but doesn't eliminate it — root can still read anything. In production, secrets belong in a secrets manager (AWS Secrets Manager, HashiCorp Vault), not flat files. The `600` pattern is acceptable for local dev and learning environments.

**The `t` vs `T` distinction.** If a directory shows `T` (capital) instead of `t`, the sticky bit is set but the execute bit is NOT — meaning the directory itself isn't traversable. That's usually a misconfiguration. You want lowercase `t`.

---

## Final Directory State

```bash
ubuntu@ip-172-31-42-216:~/devops-labs/day01$ ls -l
total 28
-rw-rw-r-- 1 ubuntu ubuntu    0 Jun  7 02:56 NOTES.md
-rw-r--r-- 1 ubuntu ubuntu   48 Jun  7 03:04 app.conf
-rw-rw-r-- 1 ubuntu ubuntu   48 Jun  7 03:04 app.conf.backup
-rwxr-xr-x 1 ubuntu ubuntu   81 Jun  7 03:21 deploy.sh
-rw-rw-r-- 1 ubuntu ubuntu 5618 Jun  7 02:50 filesystem_map.md
drwxrwxr-x 3 ubuntu ubuntu 4096 Jun  7 03:05 logs
-rwx------ 1 ubuntu ubuntu   45 Jun  7 03:23 secret.conf
```

✅ `app.conf` → `644` — readable by all, writable by owner only  
✅ `deploy.sh` → `755` — executable by all, writable by owner only  
✅ `secret.conf` → `700` — owner full access, nobody else  

---

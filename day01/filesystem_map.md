# Filesystem Map — Lab 1 Observations

**Host:** `ip-172-31-42-216` (AWS EC2)
**OS:** Ubuntu 26.04 LTS (Resolute Raccoon)
**Kernel:** `7.0.0-1004-aws` — Linux x86_64
**Date:** 2026-06-06

---

## Overview

This file documents five directories I explored during Lab 1 of my DevOps filesystem navigation sprint. For each directory I note what I found, what surprised me, and why it matters operationally.

---

## 1. `/proc` — The Kernel's Live Dashboard

**Command used:** `ls /proc | head -20` → `cat /proc/cpuinfo | head -20`

**What I saw:**
- A wall of numbers: `1`, `10`, `11`, `12`… These are **running process IDs (PIDs)** — one directory per process, generated live by the kernel.
- `cpuinfo` revealed: **Intel Xeon Platinum 8259CL @ 2.50GHz**, 2 vCPUs, AVX-512 flags, and the string `hypervisor` — confirming this is a virtualized environment.

**What surprised me:**
`/proc` looks like a normal directory but **nothing in it is stored on disk**. It's a virtual filesystem the kernel writes to RAM only. When you read `/proc/cpuinfo` you're reading the kernel's live memory, not a file. I didn't expect a directory to be that kind of live interface.

**Why it matters as a DevOps engineer:**
- `cat /proc/meminfo` → check RAM without installing tools
- `cat /proc/net/dev` → inspect network interface stats
- `ls /proc/<PID>/` → inspect any running process (open files, limits, cgroup membership)
- Useful in containers where you may not have `top`, `ps`, or `htop`

---

## 2. `/etc` — The Configuration Nerve Center

**Command used:** `ls /etc | head -30`

**What I saw:**
- Config files for cron jobs (`cron.d/`, `cron.daily/`, `crontab`)
- Security artifacts: `ca-certificates/`, `credstore/`, `credstore.encrypted/`
- Shell init: `bash.bashrc`, `bash_completion.d/`
- Boot-time identity: `os-release`, `hostname`

**What surprised me:**
I expected `/etc` to be a flat list of `.conf` files. I didn't expect to find **cron scheduling**, **certificate stores**, and **encrypted credential storage** all living here as peers. The `credstore.encrypted/` entry especially stood out — it signals that secret material lives right alongside everyday config, which is a real attack surface if permissions are wrong.

**Why it matters as a DevOps engineer:**
- `/etc/hosts` → override DNS locally (critical in testing)
- `/etc/ssh/sshd_config` → harden or debug SSH access
- `/etc/crontab` and `/etc/cron.d/` → find scheduled jobs running as root
- `/etc/sudoers` → audit privilege escalation paths
- `/etc/ca-certificates/` → manage TLS trust stores

---

## 3. `/var/log` — The System's Memory

**Command used:** `ls /var/log`

**What I saw:**
```
auth.log       syslog         kern.log       dpkg.log
cloud-init.log cloud-init-output.log          journal/
apt/           amazon/        btmp           wtmp
```

**What surprised me:**
I expected generic system logs. What I didn't expect was **`amazon/`** — a vendor-specific AWS log directory sitting right inside `/var/log`. This is where the EC2 SSM agent, CloudWatch agent, and other AWS services write. Also surprising: `btmp` and `wtmp` are **binary files** — not human-readable text. They track failed logins (`btmp`) and login history (`wtmp`) and require `lastb` / `last` to read.

**Why it matters as a DevOps engineer:**
- `tail -f /var/log/syslog` → live system event stream
- `cat /var/log/auth.log` → audit SSH logins and sudo usage
- `cat /var/log/cloud-init-output.log` → debug EC2 user-data script failures
- `/var/log/amazon/` → AWS agent health, CloudWatch log forwarding status
- `journalctl` reads from `/var/log/journal/` → structured systemd log access

---

## 4. `/dev` — Hardware as Files

**Command used:** `ls /dev | head -20`

**What I saw:**
```
autofs  block  btrfs-control  char  console  core
cpu     disk   dma_heap       dri   fb0       fd
full    fuse   gpt-auto-root  hpet
```

**What surprised me:**
Everything in `/dev` looks like a file but none of them are real files — they're **device nodes**: the kernel's way of exposing hardware and virtual devices as readable/writable paths. `fd` (file descriptors), `fuse` (filesystem in userspace), `cpu` (processor interface), `disk/` (block device tree) — all of these are how user-space programs talk to hardware using normal `read()`/`write()` system calls. The fact that `gpt-auto-root` shows up confirms the disk uses a GPT partition scheme, consistent with what `df -h` showed (`nvme0n1p13`, `nvme0n1p15`).

**Why it matters as a DevOps engineer:**
- `/dev/null` → discard output (`command > /dev/null 2>&1`)
- `/dev/urandom` → generate random data (key generation, testing)
- `/dev/disk/by-id/` → stable disk identifiers for volume mounts in fstab
- `/dev/nvme0n1` → the raw block device backing the root filesystem

---

## 5. `/etc/passwd` — User Identity Without Secrets

**Command used:** `cat /etc/passwd | head -5`

**What I saw:**
```
root:x:0:0:root:/root:/bin/bash
daemon:x:1:1:daemon:/usr/sbin:/usr/sbin/nologin
bin:x:2:2:bin:/bin:/usr/sbin/nologin
sys:x:3:3:sys:/dev:/usr/sbin/nologin
sync:x:4:65534:sync:/bin:/bin/sync
```

**What surprised me:**
The `x` in field 2 means the actual password hash is **not here** — it was moved to `/etc/shadow`, which is only readable by root. This is a security split I didn't know was standard. Also surprising: most system users have `/usr/sbin/nologin` as their shell — meaning they exist as service accounts but **cannot log in interactively**. The `sync` user is an exception: it can run `/bin/sync` which flushes filesystem buffers, a legacy setup.

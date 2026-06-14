### Linux Filesystem Hierarchy

**What it is and why it matters in DevOps**

The filesystem hierarchy is the standard layout of directories on every Linux system — where the OS keeps programs, configs, logs, and temporary data. It is standardized by the FHS (Filesystem Hierarchy Standard), which is why an Ubuntu box and a Red Hat box look almost identical at the top level. In your first 30 days you will hunt for a service's config in `/etc`, read its logs in `/var/log`, and check why a disk filled up under `/var` — all of that requires knowing this map cold. When a deploy fails, the answer is almost always "the file is not where the app expects it, or the wrong place filled up." You can't grep a log if you don't know where logs live.

**Core concepts — the minimum I must know cold**

The map (memorize this tree):

```
/                    root of everything — every path starts here
├── /bin  /sbin      essential commands (sbin = admin commands). On Ubuntu 22.04 these are symlinks to /usr/bin and /usr/sbin
├── /etc             SYSTEM CONFIGURATION. Text files only. nginx, ssh, cron — all configured here
├── /home            regular users' personal directories (/home/ubuntu)
├── /root            the root user's home — NOT the same as /
├── /var             VARIABLE data — grows over time. Logs, caches, mail, databases
│   └── /var/log     where logs live. First place you look in any incident
├── /tmp             temporary files, world-writable, cleared on reboot
├── /usr             installed programs and read-only program data
│   └── /usr/local   software YOU install manually (not via apt)
├── /opt             optional third-party apps (vendors dump whole apps here)
├── /proc            VIRTUAL — kernel/process info as fake files (/proc/cpuinfo)
├── /sys             VIRTUAL — kernel device/hardware interface
├── /dev             device files (disks = /dev/xvda, null = /dev/null)
├── /boot            kernel and bootloader files — don't touch as a junior
├── /lib             shared libraries (also symlinked into /usr on Ubuntu)
├── /mnt  /media     mount points for attached disks/USB
└── /srv             data served by the system (rarely used in practice)
```

Key terms in plain English:

- **Root (`/`)** — the single top of the tree. Linux has no drive letters like C:\. Every disk gets attached ("mounted") somewhere under `/`.
- **Mount point** — a directory where a disk or filesystem is attached. Check what's mounted where:

```bash
df -h
```

- **Absolute vs relative path** — absolute starts with `/` (`/var/log/syslog`); relative starts from where you are (`log/syslog`). Scripts should use absolute paths — relative paths break when cron runs the script from a different directory.
- **Virtual filesystems** — `/proc` and `/sys` are not on disk. The kernel generates them live. That's why `du -sh /proc` gives nonsense numbers.
- Navigation and inspection commands:

```bash
pwd                     # print where I am
cd /var/log             # go somewhere (cd with no args = go home)
ls -lah /etc            # -l long, -a hidden files, -h human sizes
file /usr/bin/python3   # what kind of file is this?
which nginx             # where does this command live on my PATH?
tree -L 2 /var          # tree view, 2 levels deep (apt install tree)
```

- Finding things — the two finders, know the difference:

```bash
find /etc -name "*.conf"        # searches the disk live — accurate but slower
locate nginx.conf               # searches a prebuilt index — fast but can be stale
sudo updatedb                   # refresh locate's index (locate needs: apt install plocate)
```

Gotcha: `find` syntax is `find WHERE WHAT` — path comes first. `find -name foo /etc` fails.

- The disk-full toolkit (you will use this in week one):

```bash
df -h                           # disk usage per mounted filesystem
sudo du -sh /var/* | sort -h    # which directory under /var is eating space
```

Gotcha: `df` shows the whole filesystem; `du` measures directories. They can disagree if a deleted file is still held open by a process.

**The trap**

Beginners treat the hierarchy as trivia and skip it, then waste 20 minutes during an incident searching for "where are nginx logs" while the senior on the call already typed `cd /var/log/nginx`. The hierarchy is not trivia — it is the difference between navigating and guessing. The specific killer mistake: putting application data or logs in `/home` or `/tmp` (where reboots or cleanup jobs destroy them) instead of `/var`, or hand-editing files in `/usr` that the package manager owns and will silently overwrite on the next upgrade.

**Memory anchor**

Think of a hospital: `/etc` is the policy binder at the front desk, `/var` is the ever-growing patient records room, `/tmp` is the waiting area cleared every night, `/home` are the staff lockers, and `/proc` is the live heart-rate monitor — not a real room at all.

**Cold-knowledge checklist**

1. System configuration files live in `/etc`.
2. Logs live in `/var/log`; `/var` is the directory that grows and fills disks.
3. `/tmp` is cleared on reboot — never store anything that must survive there.
4. `/root` is root's home directory; `/` is the top of the entire tree.
5. `/proc` and `/sys` are virtual filesystems generated live by the kernel, not real files on disk.
6. Manually installed software goes in `/usr/local`; apt-managed software goes in `/usr`; vendor app bundles go in `/opt`.
7. `df -h` shows disk usage per filesystem; `du -sh <dir>` shows the size of a directory.
8. `find /path -name "pattern"` searches live; `locate` searches a stale index refreshed by `updatedb`.

**3 interview Q&A**

**Q1: A server's disk is at 98%. Walk me through finding what's filling it.**
A: I'd run `df -h` to confirm which filesystem is full — usually `/` or `/var`. Then `sudo du -sh /var/* | sort -h` to drill down to the biggest directory, repeating one level deeper each time. Nine times out of ten it's logs in `/var/log` or a cache, and the fix is log rotation, not just deleting files. I'd also check `lsof | grep deleted` for deleted files still held open, since those consume space `du` can't see.

**Q2: What's the difference between /etc, /var, and /usr?**
A: `/etc` holds configuration — small text files that tell programs how to behave. `/var` holds variable data that grows during operation — logs, caches, spools. `/usr` holds the installed programs themselves and their read-only data. Short version: `/usr` is the software, `/etc` is its settings, `/var` is what it produces while running.

**Q3: Why does `du -sh /proc` show strange output?**
A: `/proc` isn't a real directory on disk — it's a virtual filesystem the kernel generates on the fly to expose process and system information as files. The "files" in it have no real disk size, so disk tools report meaningless or zero values. Same applies to `/sys`.

**Repetition dose**

- Difficulty rating: **LIGHT** — concrete, visual, low abstraction; reinforced constantly by every later topic.
- Studied today (Day 0 = Fri Jun 12). Rep this on **Day 1 (Sat Jun 13)** and **Day 7 (Fri Jun 19)**. A rep = close all notes, recite the 8-item checklist, and run the disk-full drill (`df -h` → `du -sh` → `find`) from memory on your EC2 box. Mark COLD only after passing the Day 7 rep with zero lookups.

---

**Compare alternatives**

The nearest confusion isn't another tool — it's Windows mental models. Windows splits disks into drive letters (C:, D:); Linux mounts every disk into one tree, so a second disk might appear as `/data` with no visible "drive." Also juniors confuse `/usr/local/bin` vs `/usr/bin`: apt installs to `/usr/bin`, your manual installs go to `/usr/local/bin` — keeping them separate means upgrades never clobber your custom tools.

**Production war story**

A payments API went down at 3 a.m. with "no space left on device." `df -h` showed `/var` at 100%. The app had debug logging accidentally left on after a release, and `/var/log/app/` had grown 40 GB in two days with no logrotate config. The on-call engineer compressed old logs to free emergency space, restarted the service, then shipped a logrotate rule the next morning. Root cause wasn't the logging — it was that nobody knew `/var` was on a small dedicated partition until it filled.

**Troubleshooting drill**

- *Symptom:* "No space left on device" but `df -h` shows 60% free.
  → Diagnostic: `df -i`
  → Look for: IUse% at 100%. You've run out of **inodes** (the per-file metadata slots — each file consumes one), usually caused by millions of tiny files, often in `/tmp` or a cache dir. Free space is irrelevant if there are no inodes left.

- *Symptom:* You deleted a huge log file but `df -h` still shows the disk full.
  → Diagnostic: `sudo lsof +L1` (lists open files with zero links, i.e., deleted but held open)
  → Look for: a process (often the app or nginx) still holding the deleted file. The space frees only when that process is restarted or its file handle closes — `sudo systemctl restart <service>`.

**Cheatsheet block**

```bash
df -h                          # disk usage per filesystem, human-readable
df -i                          # inode usage (the "disk full but not full" case)
sudo du -sh /var/* | sort -h   # biggest directories under /var, sorted
find /etc -name "*.conf"       # find files by name, live search
ls -lah                        # list with hidden files and human sizes
file <path>                    # identify file type (binary? text? symlink?)
which <command>                # path of the executable that will run
tree -L 2 /etc/nginx           # quick visual of a directory's layout
```

**Resume bullet**

> Diagnosed and resolved disk-capacity incidents on Ubuntu servers by isolating runaway log growth with df/du analysis and implementing directory-level monitoring, reducing time-to-diagnosis from minutes of guesswork to a repeatable 3-command procedure.

---

## SESSION END CHECKLIST

**1. Commit to GitHub:**
- File: `phase-1/01-linux-filesystem-hierarchy/notes.md`
- Contents: paste this entire study sheet (everything above the session end checklist).

**2. Git commands:**

```bash
cd ~/devops-journey   # your repo root — adjust if named differently
mkdir -p phase-1/01-linux-filesystem-hierarchy
# create/paste the file, then:
git add phase-1/01-linux-filesystem-hierarchy/notes.md
git commit -m "Phase 1.1: Linux Filesystem Hierarchy — cold notes, drills, cheatsheet"
git push origin main
```

**3. PROGRESS UPDATE block:**

```
## PROGRESS UPDATE — 2026-06-12
| Topic | Status | Next rep due | GitHub artifact |
|-------|--------|--------------|-----------------|
| Linux Filesystem Hierarchy | STUDIED | Day 1 = 2026-06-13 | phase-1/01-linux-filesystem-hierarchy/notes.md |

Committed today: phase-1/01-linux-filesystem-hierarchy/notes.md
Next session recommendation: MODE: LAB on Linux Filesystem Hierarchy (disk-full investigation on your EC2 box), or MODE: NOTES on File and Directory Operations — the next blocker in dependency order.
```

**4. Next logical session:** Run a hands-on LAB on this same topic tomorrow — it doubles as your Day 1 rep and produces a second artifact.

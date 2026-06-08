# Lab 02 — Package Management
**Day 02 | DevOps Sprint**
**Author:** Ahmed
**Goal:** Install, inspect, and remove packages cleanly using `apt` and `dpkg`.

---

## Concepts Covered

| Tool | Purpose |
|---|---|
| `apt update` | Refresh the local package index from upstream repositories |
| `apt install` | Download and install a package and its dependencies |
| `apt search` | Search the package index by keyword |
| `apt show` | Display detailed metadata about a package |
| `apt remove` | Uninstall a package (keeps config files) |
| `apt autoremove` | Clean up orphaned dependencies no longer needed |
| `dpkg -L` | List every file installed to disk by a given package |
| `which` | Locate the executable path of an installed binary |

---

## Exercise 1 — Update the Package Index

```bash
sudo apt update
```

- Contacts all configured repositories (in `/etc/apt/sources.list`) and downloads the latest package metadata.
- Does **not** install or upgrade anything — just updates the index so `apt install` knows what's available.
- The output shows how many packages can be upgraded. Example: `12 packages can be upgraded.`
- Always run this before installing anything to avoid installing stale versions.

---

## Exercise 2 — Install `tree` and `htop`

```bash
sudo apt install -y tree htop
```

- Installs both packages in a single command — apt resolves and installs any shared dependencies automatically.
- `-y` flag suppresses the confirmation prompt, enabling non-interactive/scripted use.

**What these tools do:**
- `tree` — displays directory structures as an indented visual tree (used in Exercise 3 below).
- `htop` — interactive process viewer; a more readable alternative to `top`. Press `q` to quit.

---

## Exercise 3 — Verify Installation and Inspect Installed Files

### Locate the binaries

```bash
which tree     # → /usr/bin/tree
which htop     # → /usr/bin/htop
```

`which` searches your `$PATH` and returns the full path to the executable. If a binary isn't found, the package either wasn't installed or its directory isn't in `$PATH`.

---

### Inspect every file `tree` installed with `dpkg -L`

```bash
dpkg -L tree
```

**Actual output from this lab:**

```
/.
/usr
/usr/bin
/usr/bin/tree
/usr/share
/usr/share/doc
/usr/share/doc/tree
/usr/share/doc/tree/README.gz
/usr/share/doc/tree/TODO
/usr/share/doc/tree/changelog.Debian.gz
/usr/share/doc/tree/copyright
/usr/share/man
/usr/share/man/man1
/usr/share/man/man1/tree.1.gz
```

**What each path means:**

| Path | Purpose |
|---|---|
| `/usr/bin/tree` | The actual executable binary |
| `/usr/share/doc/tree/` | Package documentation (README, changelog, license) |
| `/usr/share/man/man1/tree.1.gz` | Compressed man page — read with `man tree` |

**Key insight:** `dpkg -L` shows you exactly what a package wrote to your filesystem — useful for auditing, troubleshooting, and understanding package scope. The `tree` package is minimal: one binary, one man page, a few docs.

---

### Where does nginx's binary live?

```bash
which nginx       # → not in $PATH by default
ls /usr/sbin/nginx
```

- nginx installs its binary to **`/usr/sbin/nginx`**, not `/usr/bin/`.
- `/usr/sbin/` is the standard location for system administration binaries — tools intended to be run by root or via `sudo`, not regular users.
- `/usr/sbin/` is typically not in a non-root user's `$PATH`, which is why `which nginx` returns nothing even though nginx is installed and running.

**Verify directly:**
```bash
ls -la /usr/sbin/nginx
# → -rwxr-xr-x 1 root root ... /usr/sbin/nginx
```

---

## Exercise 4 — Use the Tools

```bash
tree /etc/nginx
```

Displays the nginx configuration directory as a tree, making it easy to see how config files are organized. Sample output:

```
/etc/nginx
├── conf.d
├── modules-available
├── modules-enabled
├── nginx.conf
├── sites-available
│   └── default
├── sites-enabled
│   └── default -> /etc/nginx/sites-available/default
├── snippets
│   ├── fastcgi-php.conf
│   └── snakeoil.conf
└── ...
```

Notice `sites-enabled/default` is a **symlink** pointing to `sites-available/default` — this is nginx's pattern for enabling/disabling sites without deleting config files.

```bash
htop
# Press q to quit
```

`htop` provides a real-time, color-coded view of CPU usage per core, memory usage, and all running processes. More readable than `top` and supports mouse interaction.

---

## Exercise 5 — Search for a Package Before Installing

### Search by keyword

```bash
apt search "log monitor"
```

**Actual output from this lab:**

```
certspotter/resolute 0.18.0-1build1 amd64
  Certificate Transparency Log Monitor

prelude-lml-rules/resolute 5.2.0-1build1 all
  Security Information and Events Management System [ LML Rules ]

sagan-rules/resolute 1:20170725-1.1build1 all
  Real-time System & Event Log Monitoring System [rules]

squidtaild/resolute 2.1a6-7 all
  Squid log monitoring program

tenshi/resolute 0.13-8build1 all
  log monitoring and reporting tool
```

- Results are sorted by relevance to the search term.
- Format: `package-name/distro-codename version architecture`
- The Ubuntu codename shown here is **resolute** (Ubuntu 26.04 LTS).

---

### Inspect package metadata before installing

```bash
apt show logwatch
```

**Actual output from this lab:**

```
Package: logwatch
Version: 7.12-3ubuntu2
Priority: optional
Section: admin
Installed-Size: 2454 kB
Depends: default-mta | mail-transport-agent, libhtml-parser-perl, perl:any
Recommends: libdate-manip-perl
Download-Size: 399 kB
Description: log analyser with nice output written in Perl
 Logwatch is a modular log analyser that runs every night
 and mails you the results. It can also be run from command line.
```

**What to read in `apt show` output:**

| Field | What it tells you |
|---|---|
| `Version` | Exact version available in the repo |
| `Installed-Size` | Disk space used after install (2.4 MB here) |
| `Download-Size` | Network download size (399 KB — much smaller than installed) |
| `Depends` | Hard requirements — apt installs these automatically |
| `Recommends` | Optional but suggested packages |
| `Section: admin` | Category — confirms this is a sysadmin tool |

**Takeaway:** Always run `apt show <package>` before installing unfamiliar tools. It reveals dependencies, disk usage, and whether the package matches what you actually need.

---

## Exercise 6 — Remove `tree` Cleanly

```bash
sudo apt remove tree
sudo apt autoremove
```

- `apt remove` uninstalls the package but **keeps configuration files** on disk (useful if you plan to reinstall).
- Use `apt purge` instead if you want to remove config files too.
- `apt autoremove` scans for packages that were installed as dependencies but are no longer needed by anything — cleans them up automatically.

### Verify removal

```bash
which tree || echo "tree has been removed"
```

**Actual output from this lab:**
```
tree has been removed
```

- `which tree` exits with code 1 (not found) when the binary is gone.
- `|| echo` catches that non-zero exit and prints the confirmation message instead of failing silently.

---

## Key Takeaways

1. **Always `apt update` first** — installing without updating can pull stale or mismatched package versions.
2. **`dpkg -L` is your package audit tool** — it shows exactly what files a package owns on disk. Useful for understanding scope, and for cleanup if you ever need to manually remove remnants.
3. **`/usr/bin/` vs `/usr/sbin/`** — user-facing tools land in `/usr/bin/`; system/admin tools land in `/usr/sbin/`. Know the difference to avoid confusion with `which`.
4. **`apt show` before you install** — check dependencies and disk size before pulling in an unknown package, especially on small instances.
5. **`remove` vs `purge` vs `autoremove`** — three different levels of cleanup. Know which one you need before running it in production.

---

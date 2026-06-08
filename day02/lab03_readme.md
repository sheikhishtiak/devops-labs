# Lab 03 — Text Processing Pipeline

**Sprint:** 50-Day DevOps Sprint  
**Day:** 2  
**Duration:** ~60 minutes  
**Environment:** AWS EC2 — Ubuntu 22.04 (`ip-172-31-42-216`)  
**Directory:** `~/devops-labs/day02/`

---

## Overview

This lab builds a text processing pipeline using core Linux CLI tools: `grep`, `awk`, `cut`, `sort`, `uniq`, `wc`, and shell redirection operators. The goal is to process real system data — specifically `/etc/passwd` and web server access logs — and culminates in a reusable shell script (`lab03_pipeline.sh`) that generates a structured log analysis report.

---

## Skills Practiced

| Tool | Purpose |
|------|---------|
| `grep` | Pattern matching and filtering lines |
| `awk` | Field extraction and conditional filtering |
| `cut` | Extracting specific fields by delimiter |
| `sort` | Alphabetical and numeric sorting |
| `uniq -c` | Deduplication with occurrence counts |
| `wc -l` | Line counting |
| `>`, `2>`, `&>`, `tee` | Output redirection |
| Pipes `\|` | Chaining commands into pipelines |

---

## Part A — Basic Tool Practice

### 1. `grep` on `/etc/passwd`

```bash
grep "root" /etc/passwd              # Lines containing root
grep -v "nologin\|false" /etc/passwd # Users with real shells
grep -c "bash" /etc/passwd           # Count users using bash
```

**Output (real EC2 instance):**

```
# grep "root" /etc/passwd
root:x:0:0:root:/root:/bin/bash

# grep -v "nologin\|false" /etc/passwd
root:x:0:0:root:/root:/bin/bash
sync:x:4:65534:sync:/bin:/bin/sync
ubuntu:x:1000:1000:Ubuntu:/home/ubuntu:/bin/bash
deployuser:x:1001:1001::/home/deployuser:/bin/bash

# grep -c "bash" /etc/passwd
3
```

**What I observed:** Only 3 accounts use `/bin/bash`: `root`, `ubuntu`, and `deployuser` (a custom service account created in a prior lab). The `sync` account uses `/bin/sync`, a special shell for data sync operations. The vast majority of system accounts (29 out of 35) use `/usr/sbin/nologin`, which is the correct security posture — they exist for service isolation, not interactive login.

---

### 2. `awk` on `/etc/passwd`

```bash
awk -F: '{print $1, $3, $7}' /etc/passwd   # username, UID, shell
awk -F: '$3 >= 1000 {print $1}' /etc/passwd # regular user accounts only
```

**Key output:**

```
root 0 /bin/bash
...
ubuntu 1000 /bin/bash
deployuser 1001 /bin/bash
```

**What I observed:** `awk -F:` splits each line on `:`, making it easy to reference specific fields by position (`$1` = username, `$3` = UID, `$7` = shell). The UID threshold of 1000 correctly filters to human/interactive accounts on this Ubuntu system. UIDs below 1000 belong to system/service accounts.

---

### 3. `cut` on `/etc/passwd`

```bash
cut -d: -f1,7 /etc/passwd       # Username and shell
cut -d: -f1 /etc/passwd | sort  # Sorted list of all usernames
```

**Sample output:**

```
root:/bin/bash
daemon:/usr/sbin/nologin
...
ubuntu:/bin/bash
deployuser:/bin/bash
```

**Comparison with `awk`:** `cut` is faster to write for simple field extraction but less flexible than `awk`. `awk` supports conditionals and arithmetic; `cut` only selects fields.

---

### 4. `sort` + `uniq` — Login Shell Frequency

```bash
awk -F: '{print $7}' /etc/passwd | sort | uniq -c | sort -rn
```

**Output:**

```
29 /usr/sbin/nologin
 3 /bin/bash
 2 /bin/false
 1 /bin/sync
```

**What I observed:** This one-liner is a classic frequency analysis pattern. The pipeline is:
1. Extract field 7 (shell) with `awk`
2. Sort alphabetically so identical values are adjacent
3. Count consecutive duplicates with `uniq -c`
4. Re-sort numerically in reverse (`-rn`) to get most frequent first

This same pattern is used in Part B for log analysis (response codes, IP addresses, URLs).

---

## Part B — Log Analysis Pipeline

### Setup

```bash
sudo apt install -y nginx

for i in {1..20}; do
  curl -s http://localhost/ > /dev/null
  curl -s http://localhost/nonexistent > /dev/null
done
```

This generates 40 log entries: 20 hits to `/` (200 OK) and 20 hits to `/nonexistent` (404 Not Found).

---

### Analysis Commands

```bash
LOG="/var/log/nginx/access.log"

wc -l $LOG                                            # Total requests
awk '{print $9}' $LOG | sort | uniq -c | sort -rn     # Response code breakdown
awk '{print $1}' $LOG | sort | uniq -c | sort -rn | head -10  # Top IPs
awk '{print $7}' $LOG | sort | uniq -c | sort -rn | head -10  # Top URLs
grep '" 404 ' $LOG                                    # Only 404 errors
grep -B 5 -A 5 '" 500 ' $LOG                          # 500 errors with context
```

**Output from my instance:**

```
Total requests: 40

=== Response Code Breakdown ===
20 404
20 200

=== Top 5 IP Addresses ===
40 ::1

=== Top 5 Requested URLs ===
20 /nonexistent
20 /
```

**What I observed:** All 40 requests came from `::1` (IPv6 loopback — localhost), confirming the `curl` loop ran locally. The response code split is exactly 50/50 as expected. The `awk '{print $9}'` trick works because Nginx's Combined Log Format always puts the HTTP status code in field 9.

---

## Part C — Redirection Practice

```bash
# Save stdout to a file
ps aux > /tmp/process_snapshot.txt

# Save only stderr
sudo apt install nonexistent-package 2> /tmp/apt_errors.txt

# Capture both stdout and stderr
sudo apt install nonexistent-package &> /tmp/apt_full_output.txt

# See output AND save it simultaneously
ps aux | grep nginx | tee /tmp/nginx_processes.txt

# Suppress permission errors while saving results
find / -name "*.conf" 2>/dev/null > /tmp/all_configs.txt
```

**Redirection operator reference:**

| Operator | What it does |
|----------|-------------|
| `>` | Redirect stdout to file (overwrite) |
| `>>` | Redirect stdout to file (append) |
| `2>` | Redirect stderr to file |
| `&>` | Redirect both stdout and stderr |
| `2>/dev/null` | Discard error messages |
| `tee` | Write to file AND display on screen |

---

## The Script — `lab03_pipeline.sh`

```bash
#!/bin/bash
# lab03_pipeline.sh — process log analysis pipeline
# Usage: ./lab03_pipeline.sh /path/to/access.log

LOG_FILE="${1:-/var/log/nginx/access.log}"

if [ ! -f "$LOG_FILE" ]; then
  echo "ERROR: Log file not found: $LOG_FILE" >&2
  exit 1
fi

echo "=== Log Analysis Report ==="
echo "File: $LOG_FILE"
echo "Total requests: $(wc -l < $LOG_FILE)"
echo ""
echo "=== Response Code Breakdown ==="
awk '{print $9}' "$LOG_FILE" | sort | uniq -c | sort -rn
echo ""
echo "=== Top 5 IP Addresses ==="
awk '{print $1}' "$LOG_FILE" | sort | uniq -c | sort -rn | head -5
echo ""
echo "=== Top 5 Requested URLs ==="
awk '{print $7}' "$LOG_FILE" | sort | uniq -c | sort -rn | head -5
```

### Script Features

- **Default argument:** `${1:-/var/log/nginx/access.log}` — uses the provided path or falls back to the nginx default
- **Guard clause:** Exits with a clear error message if the log file doesn't exist, writing to `stderr` with `>&2`
- **Exit code:** Returns `1` on failure so calling scripts or CI pipelines can detect errors
- **Reusable:** Accepts any Combined Log Format file (Nginx, Apache) as input

### Running the Script

```bash
chmod +x lab03_pipeline.sh

# Use default path
./lab03_pipeline.sh

# Pass a custom log file
./lab03_pipeline.sh /var/log/apache2/access.log
```

**Actual output from my EC2 instance:**

```
=== Log Analysis Report ===
File: /var/log/nginx/access.log
Total requests: 40

=== Response Code Breakdown ===
     20 404
     20 200

=== Top 5 IP Addresses ===
     40 ::1

=== Top 5 Requested URLs ===
     20 /nonexistent
     20 /
```

---

## Key Takeaways

1. **`sort | uniq -c | sort -rn` is the universal frequency analysis pattern.** Memorize it. It works on log files, CSV columns, any list.

2. **`awk` field positions are consistent** — Combined Log Format is standardized, so `$1` is always IP, `$7` is always URL, `$9` is always status code. No parsing library needed.

3. **Always redirect errors to stderr** (`>&2`) in scripts. This keeps stdout clean for piping and lets callers separate data from error messages.

4. **`2>/dev/null`** is essential when running `find` across the full filesystem — permission denied noise would otherwise bury real results.

5. **Guard clauses with `exit 1`** make scripts safe to use in pipelines and CI — the caller knows something went wrong via the non-zero exit code.

---

## Files

| File | Description |
|------|-------------|
| `lab03_pipeline.sh` | Main log analysis script |
| `README.md` | This documentation |

---

*Part of the 50-Day DevOps Sprint — Day 2*

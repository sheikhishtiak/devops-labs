# Day 3 — Lab 03: Cron Jobs & Automated System Monitoring

**50-Day DevOps Sprint** | Topics 11–12 | `ip-172-31-42-216` (AWS EC2 Ubuntu)

---

## Overview

In this lab I wrote a Bash system monitoring script, scheduled it with `cron` to run automatically every 5 minutes, verified it was logging correctly, and explored one-time job scheduling with the `at` command.

---

## Lab Commands & Output

### 1. Create the Monitoring Script

```bash
mkdir -p ~/scripts
cat > ~/scripts/system-check.sh << 'EOF'
#!/bin/bash
echo "=== System Check: $(date) ==="
echo "--- Disk ---"
df -h /
echo "--- Memory ---"
free -m | grep Mem
echo "--- Load ---"
uptime
echo ""
EOF
chmod +x ~/scripts/system-check.sh
```

> `mkdir -p` creates the directory and any missing parents without erroring if it already exists.  
> The `<< 'EOF'` heredoc syntax writes multi-line content directly into the file from the terminal — quoting `'EOF'` prevents variable expansion inside the block.  
> `chmod +x` marks the script executable so it can be run directly.

**Script breakdown:**

| Line | What it does |
|---|---|
| `#!/bin/bash` | Shebang — tells the OS to use bash to interpret this script |
| `$(date)` | Command substitution — injects the current timestamp at runtime |
| `df -h /` | Disk usage of the root filesystem in human-readable units |
| `free -m \| grep Mem` | RAM stats in MB, filtered to just the `Mem:` line |
| `uptime` | System uptime and 1/5/15-minute load averages |

---

### 2. Test the Script Manually

```bash
~/scripts/system-check.sh
```

**Expected output format:**
```
=== System Check: Sun Jun  8 23:55:00 UTC 2025 ===
--- Disk ---
Filesystem      Size  Used Avail Use% Mounted on
/dev/root        29G  4.2G   25G  15% /
--- Memory ---
Mem:           7951    812   5821    0    556    6906
--- Load ---
 23:55:00 up 1 day,  2:13,  1 user,  load average: 0.00, 0.00, 0.00
```

> Always test a script manually before scheduling it with cron. Cron runs with a minimal environment (no `$HOME`, limited `$PATH`), so bugs that are invisible interactively can silently fail in cron.

---

### 3. Create the Log Directory

```bash
mkdir -p ~/logs
```

> The log directory must exist before cron tries to write to it — if it doesn't, the redirection (`>>`) will fail silently and produce no log output.

---

### 4. Schedule the Script with Crontab

```bash
crontab -e
```

**Line added:**
```
*/5 * * * * /home/ubuntu/devops-labs/day03/scripts/system-check.sh >> /home/ubuntu/logs/system-check.log 2>&1
```

**Cron field reference:**

```
┌──────────── minute (0–59)
│  ┌─────────── hour (0–23)
│  │  ┌────────── day of month (1–31)
│  │  │  ┌───────── month (1–12)
│  │  │  │  ┌────────── day of week (0–7, 0 and 7 = Sunday)
│  │  │  │  │
*/5 *  *  *  *   <command>
```

| Token | Meaning |
|---|---|
| `*/5` | Every 5 minutes (step value) |
| `*` | Every hour |
| `*` | Every day of the month |
| `*` | Every month |
| `*` | Every day of the week |
| `>> ~/logs/system-check.log` | Append stdout to the log file |
| `2>&1` | Redirect stderr into stdout (captures errors in the log too) |

> **Important:** Cron requires **absolute paths** for both the script and the log file. Relative paths like `~/scripts/` fail because cron does not expand `~`.

---

### 5. Verify the Crontab Entry

```bash
crontab -l
```

**Output:**
```
# Edit this file to introduce tasks to be run by cron.
#
# Each task to run has to be defined through a single line
# indicating with different fields when the task will be run
# and what command to run for the task
#
# To define the time you can provide concrete values for
# minute (m), hour (h), day of month (dom), month (mon),
# and day of week (dow) or use '*' in these fields (for 'any').
#
# Notice that tasks will be started based on the cron's system
# daemon's notion of time and timezones.
#
# Output of the crontab jobs (including errors) is sent through
# email to the user the crontab file belongs to (unless redirected).
#
# For example, you can run a backup of all your user accounts
# at 5 a.m every week with:
# 0 5 * * 1 tar -zcf /var/backups/home.tgz /home/
#
# For more information see the manual pages of crontab(5) and cron(8)
#
# m h  dom mon dow   command

*/5 * * * * /home/ubuntu/devops-labs/day03/scripts/system-check.sh >> /home/ubuntu/logs/system-check.log 2>&1
```

> `crontab -l` lists the current user's crontab without opening an editor — use this to confirm a job was saved correctly.

---

### 6. Check the Log After 5 Minutes

```bash
cat ~/logs/system-check.log
```

**Expected output (after first run):**
```
=== System Check: Sun Jun  8 23:55:01 UTC 2025 ===
--- Disk ---
Filesystem      Size  Used Avail Use% Mounted on
/dev/root        29G  4.2G   25G  15% /
--- Memory ---
Mem:           7951    812   5821    0    556    6906
--- Load ---
 23:55:01 up 1 day,  2:13,  1 user,  load average: 0.00, 0.00, 0.00

=== System Check: Sun Jun  8 00:00:01 UTC 2025 ===
...
```

> Using `>>` (append) instead of `>` (overwrite) means each run adds to the log rather than replacing it — essential for monitoring history.

---

### 7. Confirm Cron Is Running via Syslog

```bash
grep CRON /var/log/syslog | tail -10
```

**Expected output:**
```
Jun  8 23:55:01 ip-172-31-42-216 CRON[12345]: (ubuntu) CMD (/home/ubuntu/devops-labs/day03/scripts/system-check.sh >> /home/ubuntu/logs/system-check.log 2>&1)
Jun  8 00:00:01 ip-172-31-42-216 CRON[12346]: (ubuntu) CMD (/home/ubuntu/devops-labs/day03/scripts/system-check.sh >> /home/ubuntu/logs/system-check.log 2>&1)
```

> `/var/log/syslog` records every time cron fires a job. If your script runs but produces no log output, check here first — it will tell you if the job was triggered and which user ran it.

---

### 8. Schedule a One-Time Job with `at`

```bash
sudo apt install at -y
echo "/home/ubuntu/devops-labs/day03/scripts/system-check.sh >> /home/ubuntu/logs/at-test.log" | at now + 2 minutes
atq
```

**Expected `atq` output:**
```
1   Sun Jun  8 00:02:00 2025 a ubuntu
```

> `at` schedules a command to run **once** at a specific time, unlike cron which repeats on a schedule.  
> `atq` lists all pending `at` jobs. After the job runs, it disappears from the queue automatically.  
> `at` is useful for one-off maintenance tasks: "restart this service in 10 minutes", "run this migration at 2am tonight".

---

### 9. Clean Up the Test Cron Job

```bash
crontab -e
# Remove the */5 line, save and exit
```

> Always remove test cron jobs when done. Forgotten cron jobs that write to logs or consume resources are a common source of disk-full incidents in production.

---

## Key Concepts

| Concept | Summary |
|---|---|
| `crontab -e` | Opens the current user's crontab for editing |
| `crontab -l` | Lists the current user's crontab entries |
| `*/n` in cron | Step value — "every n units" (e.g. `*/5` = every 5 minutes) |
| `2>&1` | Merges stderr into stdout — ensures errors appear in the log |
| `>>` vs `>` | `>>` appends to file; `>` overwrites. Use `>>` for logs. |
| Absolute paths in cron | Cron's `$PATH` is minimal — always use full paths for scripts and log files |
| `/var/log/syslog` | System log; contains CRON entries showing when jobs fired |
| `at` | Schedules a one-time command at a specific future time |
| `atq` | Lists pending `at` jobs |
| `atrm <job_id>` | Cancels a pending `at` job |

---

## Observations & Gotchas

- **Cron's minimal environment:** Cron does not load your `.bashrc` or `.bash_profile`. Variables like `$HOME`, `$PATH`, and custom exports are not available. Always use absolute paths, or explicitly set `PATH` at the top of your crontab.
- **Silent failures are common:** If a cron job fails, there is no visible error unless you have `2>&1` redirecting stderr to your log. Always include it.
- **The log directory must pre-exist:** Cron will not create missing directories. `mkdir -p ~/logs` must happen before the first scheduled run.
- **`~/` does not expand in crontab:** Use `/home/ubuntu/` explicitly. `~/scripts/system-check.sh` in a crontab line will silently fail.
- **Test before scheduling:** A script that works interactively may fail in cron due to the stripped environment. Run it manually first and verify the output is what you expect.
- **`at` vs `cron`:** Use `cron` for recurring tasks (every 5 minutes, every day at midnight). Use `at` for one-off future tasks (run this once, tonight at 2am).

---

## Environment

- **Host:** `ip-172-31-42-216` (AWS EC2, Ubuntu)
- **Shell:** `/bin/bash`
- **Script location:** `~/devops-labs/day03/scripts/system-check.sh`
- **Log location:** `~/logs/system-check.log`
- **Sprint day:** Day 3 of 50

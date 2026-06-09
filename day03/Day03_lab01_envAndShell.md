# Day 3 — Lab 01: Environment Variables & Shell Configuration

**50-Day DevOps Sprint** | Topic 9 | `ip-172-31-42-216` (AWS EC2 Ubuntu)

---

## Overview

In this lab I explored how Linux environment variables work — how to inspect them, create and export them, pass them to child processes, persist them across sessions via `.bashrc`, and manipulate the `PATH` variable.

---

## Lab Commands & Output

### 1. Print Current Environment (sorted, first 30 entries)

```bash
env | sort | head -30
```

**Output:**
```
DATABASE_UTL=postgress://localhost:5432/mydb
DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1000/bus
DEBUGINFOD_URLS=https://debuginfod.ubuntu.com
EDITOR=vim
HOME=/home/ubuntu
JAVA_HOME=/usr/lib/jvm/java-11-openjdk-amd64
LANG=C.UTF-8
LOGNAME=ubuntu
MY_VAR=hello
OLDPWD=/home/ubuntu/devops-labs
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/games:/usr/local/games:/snap/bin:/opt/mytools/bin:/opt/mytools/bin:/usr/lib/jvm/java-11-openjdk-amd64/bin
PWD=/home/ubuntu/devops-labs/day03
SHELL=/bin/bash
SHLVL=1
SSH_CLIENT=47.230.224.1 60153 22
SSH_CONNECTION=47.230.224.1 60153 172.31.42.216 22
SSH_TTY=/dev/pts/0
TERM=xterm-256color
USER=ubuntu
XDG_DATA_DIRS=/usr/local/share:/usr/share:/var/lib/snapd/desktop
XDG_RUNTIME_DIR=/run/user/1000
XDG_SESSION_CLASS=user
XDG_SESSION_ID=1
XDG_SESSION_TYPE=tty
```

**Notable variables already set on this instance:**
| Variable | Value | Notes |
|---|---|---|
| `EDITOR` | `vim` | Default text editor |
| `JAVA_HOME` | `/usr/lib/jvm/java-11-openjdk-amd64` | JDK 11 configured |
| `DATABASE_UTL` | `postgress://localhost:5432/mydb` | Pre-existing custom var (note: typo in name) |
| `MY_VAR` | `hello` | Pre-existing custom var from earlier session |
| `SSH_CLIENT` | `47.230.224.1 60153 22` | Confirms active SSH session |

---

### 2. Inspect the PATH

```bash
echo $PATH
```

**Output:**
```
/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/games:/usr/local/games:/snap/bin:/opt/mytools/bin:/opt/mytools/bin:/usr/lib/jvm/java-11-openjdk-amd64/bin
```

> **Note:** `/opt/mytools/bin` appears **twice** — a duplicate entry from a previous session. Harmless but worth cleaning up in production.

---

### 3. Create and Export a Session Variable

```bash
export MY_NAME="Ahmed"
echo "Hello, $MY_NAME"
```

**Output:**
```
Hello, Ahmed
```

> `export` makes the variable available to the current shell and any child processes it spawns. Without `export`, child processes cannot see it.

---

### 4. Verify Child Process Inherits the Variable

```bash
bash -c 'echo "Child sees: $MY_NAME"'
```

**Output:**
```
Child sees: Ahmed
```

> The `bash -c` command spawns a **child process**. Because `MY_NAME` was exported, the child shell inherits it. This is how environment variables propagate to scripts and subprocesses.

---

### 5. Unset the Variable and Confirm It's Gone

```bash
unset MY_NAME
echo $MY_NAME
```

**Output:**
```
(empty — no output)
```

> `unset` removes the variable from the current shell environment entirely. The empty echo confirms it no longer exists.

---

### 6. Persist a Variable Across Sessions via `.bashrc`

```bash
echo 'export DEVOPS_LAB="day03"' >> ~/.bashrc
source ~/.bashrc
echo $DEVOPS_LAB
```

**Output:**
```
day03
```

> Appending an `export` to `~/.bashrc` makes it load automatically on every new interactive shell session. `source ~/.bashrc` reloads the file immediately without needing to log out and back in.

---

### 7. Inspect Shell Config Files

```bash
cat ~/.bashrc
cat ~/.bash_profile   # may not exist on all systems
cat /etc/environment
```

> **Key config files:**
> - `~/.bashrc` — loaded for every **interactive non-login** shell (most common for daily use)
> - `~/.bash_profile` — loaded for **login shells** (SSH sessions, console logins). May source `.bashrc` inside it.
> - `/etc/environment` — system-wide, non-shell variable definitions. Sets variables for **all users and all processes** (not just bash).

---

### 8. Add a Fake Directory to PATH and Verify

```bash
export PATH="$PATH:/opt/fake"
echo $PATH | tr ':' '\n'
```

**Output:**
```
/usr/local/sbin
/usr/local/bin
/usr/sbin
/usr/bin
/sbin
/bin
/usr/games
/usr/local/games
/snap/bin
/opt/mytools/bin
/opt/mytools/bin
/usr/lib/jvm/java-11-openjdk-amd64/bin
/opt/mytools/bin
/usr/lib/jvm/java-11-openjdk-amd64/bin
/opt/fake
```

> `tr ':' '\n'` replaces every colon delimiter with a newline, making each PATH directory easy to read. `/opt/fake` is confirmed at the bottom.  
> **Observation:** There are now several duplicate entries (`/opt/mytools/bin` appears three times). This happened because `source ~/.bashrc` was run in an already-configured shell, appending entries that were already present.

---

## Key Concepts

| Concept | Summary |
|---|---|
| `export VAR=value` | Creates a variable and marks it for export to child processes |
| `unset VAR` | Removes a variable from the current shell environment |
| `env` | Prints all exported (environment) variables |
| `set` | Prints all shell variables (including unexported ones) |
| `~/.bashrc` | Per-user config loaded by interactive non-login shells |
| `~/.bash_profile` | Per-user config loaded by login shells (SSH, console) |
| `/etc/environment` | System-wide key=value pairs, no shell syntax, affects all users |
| `$PATH` | Colon-separated list of directories the shell searches for executables |
| `source <file>` (or `. <file>`) | Runs file in the **current** shell (not a subshell), so exports take effect immediately |

---

## Observations & Gotchas

- **`export` vs just assigning:** `MY_VAR=hello` is a shell variable only; child processes won't see it. `export MY_VAR=hello` promotes it to an environment variable.
- **Duplicate PATH entries:** Sourcing `.bashrc` multiple times in the same shell session appended duplicate entries. In production, guard PATH additions with a check: `[[ ":$PATH:" != *":/opt/mytools/bin:"* ]] && export PATH="$PATH:/opt/mytools/bin"`
- **Session vs persistence:** Variables set with `export` last only for the current session. To survive reboots and new logins, they must be written to `~/.bashrc`, `~/.bash_profile`, or `/etc/environment`.
- **`DATABASE_UTL` typo:** The pre-existing variable on this instance has a typo (`UTL` instead of `URL`). In a real application this would cause a connection failure — worth noting as a real-world debugging scenario.

---

## Environment

- **Host:** `ip-172-31-42-216` (AWS EC2, Ubuntu)
- **Shell:** `/bin/bash`
- **Lab directory:** `~/devops-labs/day03/`
- **Sprint day:** Day 3 of 50

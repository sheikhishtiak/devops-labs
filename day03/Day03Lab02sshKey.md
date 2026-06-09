# Day 3 — Lab 02: SSH Keys, Config, and Remote Access

**50-Day DevOps Sprint** | Topic 10 | `ip-172-31-42-216` (AWS EC2 Ubuntu)

---

## Overview

In this lab I practiced the full SSH key lifecycle — generating an Ed25519 key pair, inspecting the `.ssh/` directory, configuring a named SSH alias, hardening the SSH daemon, running remote commands non-interactively, and transferring files with `scp`.

> **Security note:** Specific server IPs, key contents, and sensitive config values are intentionally omitted from this document.

---

## Lab Commands & Output

### 1. Generate an Ed25519 Key Pair

```bash
ssh-keygen -t ed25519 -C "devops-lab-key" -f ~/.ssh/devops_lab_key
```

**Output:**
```
Generating public/private ed25519 key pair.
Enter passphrase for "/home/ubuntu/.ssh/devops_lab_key" (empty for no passphrase):
Enter same passphrase again:
Your identification has been saved in /home/ubuntu/.ssh/devops_lab_key
Your public key has been saved in /home/ubuntu/.ssh/devops_lab_key.pub
The key fingerprint is:
SHA256:5PDIM0fEsEgsfHytGO+9PqIVWQ17Xhari0ppnznOFnI devops-lab-key
The key's randomart image is:
+--[ED25519 256]--+
| . o. .+o   .    |
|  o.=..oo+   o   |
|   o.=o.= o +    |
|    ..oX o +     |
|     .B.S o      |
|      o*E. .     |
|      =o.o.      |
|     +.+=o       |
|    ...=Bo       |
+----[SHA256]-----+
```

> **Why Ed25519?** It is faster, smaller, and cryptographically stronger than the older RSA-4096 standard. It is the current best-practice algorithm for new SSH keys.  
> The `-C` flag adds a human-readable comment to the public key (used as a label).  
> The `-f` flag specifies the output filename rather than using the default `~/.ssh/id_ed25519`.

---

### 2. Inspect the `.ssh/` Directory

```bash
ls -la ~/.ssh/
```

**Output:**
```
total 36
drwx------ 2 ubuntu ubuntu 4096 Jun  8 23:38 .
drwxr-x--- 5 ubuntu ubuntu 4096 Jun  8 23:36 ..
-rw------- 1 ubuntu ubuntu  395 Jun  7 01:36 authorized_keys
-rw------- 1 ubuntu ubuntu  411 Jun  8 23:38 devops_lab_key
-rw-r--r-- 1 ubuntu ubuntu   96 Jun  8 23:38 devops_lab_key.pub
-rw------- 1 ubuntu ubuntu  419 Jun  7 01:49 id_ed25519
-rw-r--r-- 1 ubuntu ubuntu  105 Jun  7 01:49 id_ed25519.pub
-rw------- 1 ubuntu ubuntu  978 Jun  7 01:51 known_hosts
-rw-r--r-- 1 ubuntu ubuntu  142 Jun  7 01:51 known_hosts.old
```

**File permissions breakdown:**

| File | Permissions | Why |
|---|---|---|
| `.ssh/` directory | `drwx------` (700) | Only owner can read, write, enter. SSH refuses to run if looser. |
| `devops_lab_key` (private) | `-rw-------` (600) | Only owner can read/write. Must never be world-readable. |
| `devops_lab_key.pub` (public) | `-rw-r--r--` (644) | Public key is safe to share — readable by anyone. |
| `authorized_keys` | `-rw-------` (600) | Holds public keys of clients allowed to log in. Must be owner-only. |
| `known_hosts` | `-rw-------` (600) | Stores fingerprints of servers you've connected to before. |

> Two key pairs exist on this instance: the lab-specific `devops_lab_key` (generated today) and `id_ed25519` (generated on Jun 7, the instance's default key).

---

### 3. Create an SSH Config Entry

```bash
cat >> ~/.ssh/config << 'EOF'
Host devops-lab
    HostName <SERVER_IP>
    User ubuntu
    IdentityFile ~/.ssh/devops_lab_key
    Port 22
EOF
chmod 600 ~/.ssh/config
```

> The `~/.ssh/config` file lets you define named aliases for SSH connections. Instead of typing `ssh -i ~/.ssh/devops_lab_key ubuntu@<IP>` every time, this allows `ssh devops-lab`.
>
> `chmod 600` is required — SSH will refuse to use a config file that is group- or world-readable.

**Config block explained:**

| Directive | Purpose |
|---|---|
| `Host devops-lab` | The alias used in the `ssh` command |
| `HostName` | The actual IP or FQDN of the target server |
| `User` | Remote username to log in as |
| `IdentityFile` | Which private key to use for this host |
| `Port` | SSH port (default is 22; change if server uses a non-standard port) |

---

### 4. Copy the Public Key to the Server

```bash
ssh-copy-id -i ~/.ssh/devops_lab_key.pub ubuntu@<SERVER_IP>
```

> `ssh-copy-id` appends the public key to `~/.ssh/authorized_keys` on the remote server. After this step, the server will accept logins authenticated with the corresponding private key — no password needed.

---

### 5. Connect Using the Alias

```bash
ssh devops-lab
```

> With the config entry and key deployed, a single short command replaces the full `ssh -i ~/.ssh/devops_lab_key ubuntu@<IP>` invocation. This is how DevOps engineers manage access to many servers cleanly.

---

### 6. Harden the SSH Daemon Config

```bash
sudo nano /etc/ssh/sshd_config
```

**Settings applied:**

| Directive | Value | Reason |
|---|---|---|
| `PermitRootLogin` | `no` | Prevents direct root login over SSH — attackers must first compromise a regular user |
| `PasswordAuthentication` | `no` | Disables password-based login entirely; key auth only |
| `MaxAuthTries` | `3` | Limits brute-force attempts before the connection is dropped |

> **⚠️ Always test from a second terminal** before restarting `sshd`. If the new config has an error or locks you out, the second session lets you recover without needing console access.

---

### 7. Restart and Verify the SSH Daemon

```bash
sudo systemctl restart sshd
sudo systemctl status sshd
```

> `systemctl restart sshd` applies the new config. `systemctl status sshd` confirms the service came back up cleanly (look for `Active: active (running)`). A failed restart here means a config syntax error — check with `sshd -t` to validate before restarting.

---

### 8. Run a Remote Command Without an Interactive Session

```bash
ssh devops-lab "uptime && whoami && hostname"
```

> Passing a quoted command to `ssh` executes it on the remote host and returns the output locally, then closes the connection — no interactive shell opened.  
> This is the foundation of how CI/CD pipelines, Ansible, and deployment scripts execute commands on remote servers.

---

### 9. Copy Files To and From the Server with `scp`

```bash
echo "test file" > /tmp/test.txt
scp /tmp/test.txt devops-lab:/tmp/from-local.txt
scp devops-lab:/tmp/from-local.txt /tmp/retrieved.txt
cat /tmp/retrieved.txt
```

> `scp` (Secure Copy Protocol) transfers files over SSH. Syntax is `scp <source> <destination>`, where either side can be a remote path in `host:/path` format.  
> The round-trip here (local → remote → local) verifies both upload and download paths work correctly.

---

## Key Concepts

| Concept | Summary |
|---|---|
| Ed25519 | Modern elliptic-curve SSH key algorithm; preferred over RSA for new keys |
| Public / Private key pair | Public key goes on the server (`authorized_keys`); private key stays on the client only |
| `~/.ssh/config` | Per-user SSH client config; defines host aliases, identity files, usernames, ports |
| `ssh-copy-id` | Safely appends a public key to a remote server's `authorized_keys` |
| `PermitRootLogin no` | Hardens sshd by blocking direct root SSH access |
| `PasswordAuthentication no` | Forces key-based auth only — eliminates password brute-force attack surface |
| `MaxAuthTries 3` | Limits failed auth attempts per connection |
| `ssh host "command"` | Runs a single command on a remote host non-interactively |
| `scp` | Copies files over SSH; respects `~/.ssh/config` aliases |
| `systemctl restart sshd` | Reloads the SSH daemon with updated config |

---

## Observations & Gotchas

- **Always have a second terminal open** before restarting `sshd`. A bad config can lock you out of your own server.
- **Private key permissions are enforced by SSH.** If `devops_lab_key` is readable by group or world, SSH will refuse to use it with a `UNPROTECTED PRIVATE KEY FILE` error.
- **The `.ssh/` directory itself must be 700.** Even if the files inside have correct permissions, a world-readable `.ssh/` directory will cause SSH to reject your key.
- **`ssh-copy-id` is idempotent** — running it multiple times won't duplicate the key in `authorized_keys`.
- **`scp` uses your SSH config.** Because `devops-lab` is defined in `~/.ssh/config`, `scp devops-lab:/path` works the same way `ssh devops-lab` does.
- **After disabling `PasswordAuthentication`**, ensure at least one key is in `authorized_keys` before logging out — otherwise you will permanently lose SSH access (requiring EC2 console recovery on AWS).

---

## Environment

- **Host:** `ip-172-31-42-216` (AWS EC2, Ubuntu)
- **Shell:** `/bin/bash`
- **Lab directory:** `~/devops-labs/day03/`
- **Sprint day:** Day 3 of 50

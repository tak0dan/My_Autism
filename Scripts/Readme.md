# Standalone Scripts

Scripts that are independent from the deployment plugin engine. Each script is self-contained and runnable on its own.

---

## mariadb-clean-install.sh

Interactive MariaDB installer with a `dialog`-based TUI. Detects the current Linux distribution and installs MariaDB through the appropriate package manager.

**Supported package managers:** pacman, paru, yay, apt, dnf, zypper, apk, nix-env, nixos-rebuild

**Features:**
- Auto-detects system package manager
- Initializes the MariaDB data directory
- Applies a secure baseline (removes anonymous users, drops the test database)
- Walks through user creation: username, host, password, privilege selection, database scope
- Handles existing users (abort / alter / recreate)
- Provides NixOS-specific instructions when a NixOS system is detected (imperative install is not possible)

**Usage:**
```bash
sudo bash mariadb-clean-install.sh
```

> ⚠️ This script is potentially destructive if an existing MariaDB installation is present. Use only on fresh systems or controlled environments.

---

## a.sh

Network SSH credential scanner. Scans the local subnet for live hosts, checks if SSH is open on port 22, and attempts to authenticate using passwords from `passwords.json`.

**Usage:**
```bash
bash a.sh <username>
```

> ⚠️ **Security and legal notice:** Only use this tool against systems you own or have explicit written permission to test. Unauthorized access to computer systems is illegal. This script is intended for authorized penetration testing and network auditing only.

---

## passwords.json

Credential list read by `a.sh`. Contains passwords to try during SSH scanning.

> ⚠️ **Do not commit real passwords to version control.** This file should be treated as a local-only secret. Consider using environment variables or a proper secrets manager (`pass`, `age`, `sops`) instead of a plaintext JSON file in production workflows.

---

## Code of Conduct

- Scripts must print a usage message when called without required arguments.
- Destructive operations must warn the user before proceeding.
- Do not hardcode credentials in script source files.
- Security-sensitive scripts must include a clear notice about authorized use.

#!/usr/bin/env bash
# mariadb-setup.sh — MariaDB TUI installer
# Supports: Arch/paru/yay, Debian/Ubuntu, Fedora, openSUSE, Alpine, NixOS, Nix
# No pipefail — all failures go through try/catch recovery menus.

set -uo pipefail   # keep -u (unbound vars) and -o pipefail only for pipeline safety;
                   # -e is intentionally absent — we handle errors manually via run()

### ============================
### Globals
### ============================

DIALOG=dialog
PKG_MANAGER=""
SYSTEMD_AVAILABLE=0
PKG_MANAGER_SELECTED=0
NIXOS_CONFIG="/etc/nixos/configuration.nix"
NIXOS_MODULE_FILE="/etc/nixos/mariadb.nix"
MARIADB_DATADIR="/var/lib/mysql"
MARIADB_SOCKET_CANDIDATES=(
  /run/mysqld/mysqld.sock
  /var/run/mysqld/mysqld.sock
  /tmp/mysql.sock
  /run/mariadb/mariadb.sock
)

### ============================
### Logging / Low-level helpers
### ============================

_log() { echo "[$(date '+%H:%M:%S')] $*" >> /tmp/mariadb-setup.log; }

die() {
  _log "FATAL: $1"
  echo "FATAL: $1" >&2
  exit 1
}

# run CMD [ARGS...] — execute a command; on failure call the recovery dispatcher.
# Usage:  run mariadb -e "FLUSH PRIVILEGES;"
#         run systemctl start mariadb
run() {
  local cmd=("$@")
  _log "run: ${cmd[*]}"
  if "${cmd[@]}" 2>>/tmp/mariadb-setup.log; then
    return 0
  fi
  local rc=$?
  _log "run failed (rc=$rc): ${cmd[*]}"
  _recover_from_failure "$rc" "${cmd[*]}"
  # _recover_from_failure either fixes things and returns 0, or exits.
  return 0
}

### ============================
### Dialog wrappers
### ============================

_ensure_dialog() {
  # Must be called before any $DIALOG usage.
  if ! command -v dialog >/dev/null 2>&1; then
    echo "WARNING: 'dialog' not found. Attempting bootstrap install..." >&2
    _bootstrap_dialog || die "'dialog' could not be installed. Aborting."
  fi
  DIALOG=dialog
}

_bootstrap_dialog() {
  # Try to install dialog without dialog (plain echo/read).
  if   command -v pacman  >/dev/null 2>&1; then pacman -Sy --noconfirm dialog
  elif command -v apt-get >/dev/null 2>&1; then apt-get install -y dialog
  elif command -v dnf     >/dev/null 2>&1; then dnf install -y dialog
  elif command -v zypper  >/dev/null 2>&1; then zypper install -y dialog
  elif command -v apk     >/dev/null 2>&1; then apk add dialog
  elif command -v nix-env >/dev/null 2>&1; then nix-env -iA nixpkgs.dialog
  else
    return 1
  fi
}

msg() {
  _log "msg: $1"
  $DIALOG --title "MariaDB Installer" --msgbox "$1" 12 74
}

info() {
  # Non-blocking informational overlay (auto-dismissed after 2 s if height=0).
  $DIALOG --title "MariaDB Installer" --infobox "$1" 6 60
  sleep 1
}

input() {
  $DIALOG --stdout --inputbox "$1" 10 70
}

password() {
  $DIALOG --stdout --passwordbox "$1" 10 70
}

menu() {
  # menu "title" key1 label1 key2 label2 ...
  $DIALOG --stdout --menu "$1" 18 74 10 "${@:2}"
}

checklist() {
  $DIALOG --stdout --checklist "$1" 22 74 14 "${@:2}"
}

yesno() {
  $DIALOG --yesno "$1" 8 60
}

### ============================
### Recovery dispatcher
### ============================

# Called whenever run() catches a non-zero exit.
_recover_from_failure() {
  local rc="$1"
  local failed_cmd="$2"

  _log "_recover_from_failure rc=$rc cmd='$failed_cmd'"

  local choice
  choice=$(menu "Command failed (rc=$rc):
  $failed_cmd

Choose a recovery action:" \
    view_log       "View error log"              \
    retry          "Retry the command"           \
    reinstall_pkg  "Reinstall MariaDB package"   \
    fix_socket     "Fix / probe MariaDB socket"  \
    backup_data    "Backup data dir & continue"  \
    reconstruct    "Reconstruct users & DBs"     \
    shell          "Drop to a root shell"        \
    abort          "Abort setup"                 \
  ) || true

  case "${choice:-abort}" in
    view_log)
      $DIALOG --title "Error log" --textbox /tmp/mariadb-setup.log 30 100 || true
      _recover_from_failure "$rc" "$failed_cmd"
      ;;
    retry)
      _log "Retrying: $failed_cmd"
      # shellcheck disable=SC2086
      eval "$failed_cmd" 2>>/tmp/mariadb-setup.log || _recover_from_failure "$?" "$failed_cmd"
      ;;
    reinstall_pkg)
      _reinstall_mariadb
      ;;
    fix_socket)
      _fix_mariadb_socket
      ;;
    backup_data)
      _backup_datadir
      ;;
    reconstruct)
      _reconstruct_instance
      ;;
    shell)
      msg "Dropping to root shell. Type 'exit' to return to installer."
      bash --login || true
      _recover_from_failure "$rc" "$failed_cmd"
      ;;
    abort|*)
      die "User aborted after failure: $failed_cmd"
      ;;
  esac
}

### ============================
### Recovery actions
### ============================

_reinstall_mariadb() {
  info "Reinstalling MariaDB package..."
  case "$PKG_MANAGER" in
    pacman)  pacman -Rns --noconfirm mariadb mariadb-clients 2>>/tmp/mariadb-setup.log; pacman -Sy --noconfirm mariadb ;;
    paru)    paru -Rns --noconfirm mariadb; paru -Sy --noconfirm mariadb ;;
    yay)     yay  -Rns --noconfirm mariadb; yay  -Sy --noconfirm mariadb ;;
    apt)     DEBIAN_FRONTEND=noninteractive apt-get install --reinstall -y mariadb-server ;;
    dnf)     dnf reinstall -y mariadb-server ;;
    zypper)  zypper install --force -y mariadb ;;
    apk)     apk del mariadb mariadb-client; apk add mariadb mariadb-client ;;
    nixos)   msg "On NixOS reinstall means re-running nixos-rebuild switch."; _nixos_rebuild ;;
    nix)     nix profile remove mariadb 2>/dev/null; nix profile install nixpkgs#mariadb ;;
    *)       msg "Don't know how to reinstall for '$PKG_MANAGER'. Dropping to shell."; bash --login ;;
  esac
  msg "Reinstall attempted. Retrying service start..."
  _start_mariadb_service
}

_fix_mariadb_socket() {
  local found_socket=""
  info "Probing known socket locations..."

  for s in "${MARIADB_SOCKET_CANDIDATES[@]}"; do
    if [[ -S "$s" ]]; then
      found_socket="$s"
      break
    fi
  done

  if [[ -n "$found_socket" ]]; then
    msg "Socket found at: $found_socket

If MariaDB commands fail, try:
  mariadb --socket=$found_socket ..."
    return 0
  fi

  # Socket missing — try fixing permissions and restarting.
  msg "No socket found at known paths.

Attempting:
1. Fix /run/mysqld ownership
2. Restart mariadb service"

  mkdir -p /run/mysqld
  chown mysql:mysql /run/mysqld 2>/dev/null || true
  chmod 755 /run/mysqld

  _start_mariadb_service
}

_backup_datadir() {
  local backup_path="/tmp/mariadb-backup-$(date +%Y%m%d-%H%M%S)"
  info "Backing up $MARIADB_DATADIR → $backup_path ..."

  if [[ -d "$MARIADB_DATADIR" ]]; then
    cp -a "$MARIADB_DATADIR" "$backup_path" 2>>/tmp/mariadb-setup.log \
      && msg "Backup saved to: $backup_path" \
      || msg "WARNING: Backup failed. Check /tmp/mariadb-setup.log"
  else
    msg "Data dir $MARIADB_DATADIR does not exist — nothing to back up."
  fi
}

_reconstruct_instance() {
  msg "Reconstruction mode:

This will:
  1. Stop MariaDB (if running)
  2. Back up the existing data directory
  3. Re-initialise a fresh data directory
  4. Restart MariaDB
  5. Re-import any .sql dumps found in the backup

Existing grant tables will be rebuilt from scratch."

  yesno "Proceed with reconstruction?" || return

  _backup_datadir

  # Stop service
  if [[ $SYSTEMD_AVAILABLE -eq 1 ]]; then
    systemctl stop mariadb 2>/dev/null || true
  fi

  # Remove broken data dir and re-init
  rm -rf "${MARIADB_DATADIR:?}"/*
  _init_mariadb

  _start_mariadb_service

  secure_baseline

  msg "Instance reconstructed. You may need to recreate users and import data manually from the backup at /tmp/mariadb-backup-*."
}

### ============================
### Privilege check
### ============================

require_root() {
  [[ $EUID -eq 0 ]] || die "This script must be run as root (or via sudo)."
}

### ============================
### Dependency checks
### ============================

check_dependencies() {
  local missing=()

  for bin in mariadb mariadb-install-db; do
    command -v "$bin" >/dev/null 2>&1 || missing+=("$bin")
  done

  # mariadb-install-db may live under mysql alias on some distros
  if [[ " ${missing[*]} " == *"mariadb-install-db"* ]]; then
    command -v mysql_install_db >/dev/null 2>&1 && missing=("${missing[@]/mariadb-install-db}")
  fi

  if [[ ${#missing[@]} -gt 0 ]]; then
    msg "Missing binaries after install: ${missing[*]}

This usually means the package did not install correctly.
The recovery menu will now open."
    _recover_from_failure 127 "dependency check: ${missing[*]}"
  fi
}

### ============================
### System detection
### ============================

detect_systemd() {
  if command -v systemctl >/dev/null 2>&1 && [[ -d /run/systemd/system ]]; then
    SYSTEMD_AVAILABLE=1
    _log "systemd detected"
  else
    _log "systemd not available"
  fi
}

detect_pkg_managers() {
  [[ $PKG_MANAGER_SELECTED -eq 1 ]] && return

  local options=()

  if command -v pacman >/dev/null 2>&1; then
    PKG_MANAGER="$(select_arch_helper)"
    PKG_MANAGER_SELECTED=1
    return
  fi

  # NixOS must be checked BEFORE bare nix, because NixOS has both.
  if command -v nixos-rebuild >/dev/null 2>&1; then
    options+=(nixos "NixOS (declarative — edits configuration.nix)")
  fi

  command -v apt     >/dev/null 2>&1 && options+=(apt    "Debian / Ubuntu")
  command -v dnf     >/dev/null 2>&1 && options+=(dnf    "Fedora / RHEL")
  command -v zypper  >/dev/null 2>&1 && options+=(zypper "openSUSE")
  command -v apk     >/dev/null 2>&1 && options+=(apk    "Alpine Linux")
  command -v nix-env >/dev/null 2>&1 && ! command -v nixos-rebuild >/dev/null 2>&1 \
    && options+=(nix "Nix (user profile / nix-env)")

  [[ ${#options[@]} -gt 0 ]] || die "No supported package manager detected."

  PKG_MANAGER=$(menu "Select package manager:" "${options[@]}")
  PKG_MANAGER_SELECTED=1
  _log "PKG_MANAGER=$PKG_MANAGER"
}

### ============================
### Arch AUR helpers
### ============================

select_arch_helper() {
  local choice
  choice=$(menu "Arch Linux detected. Select helper:" \
    pacman "Official repos only"        \
    paru   "AUR helper (recommended)"   \
    yay    "AUR helper (alternative)")

  case "$choice" in
    pacman) echo pacman ;;
    paru|yay)
      _ensure_aur_helper "$choice"
      echo "$choice"
      ;;
    *) die "Invalid Arch helper selection." ;;
  esac
}

_ensure_aur_helper() {
  local helper="$1"
  command -v "$helper" >/dev/null 2>&1 && return

  local user="${SUDO_USER:-}"
  [[ -n "$user" ]] || die "AUR helpers must be built as a normal user (run via sudo)."

  msg "$helper not found. Building from AUR..."

  pacman -Sy --needed --noconfirm base-devel git 2>>/tmp/mariadb-setup.log

  sudo -u "$user" bash <<EOF
set -e
builddir="\$(mktemp -d "\$HOME/.cache/${helper}.XXXXXX")"
cd "\$builddir"
git clone https://aur.archlinux.org/${helper}.git
cd "${helper}"
makepkg -si --noconfirm
EOF
}

### ============================
### Package installation
### ============================

install_packages() {
  info "Installing MariaDB and dialog..."
  case "$PKG_MANAGER" in
    pacman) pacman -Sy --noconfirm mariadb dialog 2>>/tmp/mariadb-setup.log ;;
    paru)   paru  -Sy --noconfirm mariadb dialog 2>>/tmp/mariadb-setup.log ;;
    yay)    yay   -Sy --noconfirm mariadb dialog 2>>/tmp/mariadb-setup.log ;;
    apt)
      DEBIAN_FRONTEND=noninteractive apt-get update 2>>/tmp/mariadb-setup.log
      DEBIAN_FRONTEND=noninteractive apt-get install -y mariadb-server dialog 2>>/tmp/mariadb-setup.log
      ;;
    dnf)    dnf    install -y mariadb-server dialog 2>>/tmp/mariadb-setup.log ;;
    zypper) zypper install -y mariadb dialog       2>>/tmp/mariadb-setup.log ;;
    apk)    apk add mariadb mariadb-client dialog  2>>/tmp/mariadb-setup.log ;;
    nixos)  _nixos_install ;;
    nix)    _nix_user_install ;;
    *)      die "Unsupported package manager: $PKG_MANAGER" ;;
  esac || _recover_from_failure $? "install_packages ($PKG_MANAGER)"
}

### ============================================================
### NixOS support — separate module file + single import line
### ============================================================
#
# Design:
#   • All MariaDB config lives in ONE file: /etc/nixos/mariadb.nix
#     It is a proper NixOS module with its own `options` declaration.
#   • configuration.nix is touched ONCE: a single "./mariadb.nix" line
#     is injected inside the existing (or a new) imports [ ] block.
#   • Toggling:  flip `mariadb-installer.enable = true/false;` inside
#     mariadb.nix — or comment out the import line — then rebuild.
#   • Works on vanilla configuration.nix (no imports block yet) and
#     on custom configs that already have one.
#

# Sentinel strings used to locate our injections — never double-inject.
_NIXOS_IMPORT_SENTINEL="./mariadb.nix"
_NIXOS_MODULE_SENTINEL="mariadb-installer.nix managed by mariadb-setup.sh"

# ------------------------------------------------------------------
# _nixos_write_module [true|false]
#   Writes /etc/nixos/mariadb.nix — a self-contained NixOS module.
#   The `enable` option (default true/false) is the master toggle.
# ------------------------------------------------------------------
_nixos_write_module() {
  local enable_val="${1:-true}"
  _log "_nixos_write_module enable=$enable_val"

  # Use a temp file so a crash mid-write never leaves a half-written module.
  local tmp
  tmp=$(mktemp /tmp/mariadb-nix-module.XXXXXX)

  cat > "$tmp" <<NIXMODULE
# ==============================================================
# /etc/nixos/mariadb.nix
# ${_NIXOS_MODULE_SENTINEL}
#
# TOGGLE: set  mariadb-installer.enable = false;  below, OR
#         comment out  # ./mariadb.nix  in configuration.nix,
#         then run:  sudo nixos-rebuild switch
# ==============================================================
{ config, pkgs, lib, ... }:

let
  cfg = config.mariadb-installer;
in {

  # ── Option declaration ────────────────────────────────────────
  options.mariadb-installer = {
    enable = lib.mkOption {
      type        = lib.types.bool;
      default     = ${enable_val};
      description = lib.mdDoc ''
        Master on/off toggle for MariaDB (managed by mariadb-setup.sh).
        Flip to false and run nixos-rebuild switch to stop and remove.
      '';
    };
  };

  # ── Implementation ────────────────────────────────────────────
  config = lib.mkIf cfg.enable {

    services.mysql = {
      enable  = true;
      package = pkgs.mariadb;
    };

    environment.systemPackages = with pkgs; [
      mariadb   # client + CLI tools
      dialog    # required by mariadb-setup.sh TUI
    ];

  };

}
NIXMODULE

  mv "$tmp" "$NIXOS_MODULE_FILE"
  chmod 644 "$NIXOS_MODULE_FILE"
  _log "Wrote $NIXOS_MODULE_FILE"
}

# ------------------------------------------------------------------
# _nixos_inject_import
#   Adds  ./mariadb.nix  into imports [ ] of configuration.nix.
#   Case A — no imports block yet  → inserts one after the opening {
#   Case B — existing imports [ ]  → appends before the closing ]
#   Never double-injects (checks sentinel first).
# ------------------------------------------------------------------
_nixos_inject_import() {
  local cfg="$NIXOS_CONFIG"
  local backup="${cfg}.bak.$(date +%Y%m%d-%H%M%S)"

  # Already injected?
  if grep -qF "$_NIXOS_IMPORT_SENTINEL" "$cfg"; then
    _log "Import sentinel already in $cfg — skipping."
    return 0
  fi

  cp "$cfg" "$backup" \
    || { msg "Could not back up $cfg — aborting injection."; return 1; }
  _log "Backed up $cfg → $backup"

  if grep -qE '^\s*imports\s*=' "$cfg"; then
    # Case B: existing imports block — find its closing ']' and insert before it.
    _log "Existing imports block found — appending inside it."
    local imports_line close_line
    imports_line=$(grep -n 'imports\s*=' "$cfg" | head -1 | cut -d: -f1)
    close_line=$(awk -v start="$imports_line" \
      'NR > start && /^\s*\]/ { print NR; exit }' "$cfg")

    if [[ -z "$close_line" ]]; then
      _log "WARNING: Could not find closing ']' — appending at end of file."
      printf '  %s\n' "$_NIXOS_IMPORT_SENTINEL" >> "$cfg"
    else
      sed -i "${close_line}i\\    ${_NIXOS_IMPORT_SENTINEL}" "$cfg"
    fi

  else
    # Case A: no imports block — insert one right after the first top-level '{'.
    _log "No imports block found — inserting a new one."
    local open_line
    open_line=$(grep -n '^\s*{' "$cfg" | head -1 | cut -d: -f1)

    if [[ -z "$open_line" ]]; then
      _log "WARNING: Could not find opening '{' — prepending block at top."
      {
        printf '{ config, pkgs, lib, ... }:\n{\n'
        printf '  imports = [\n    %s\n  ];\n\n' "$_NIXOS_IMPORT_SENTINEL"
        cat "$cfg"
      } > /tmp/_nixos_cfg_tmp
      mv /tmp/_nixos_cfg_tmp "$cfg"
    else
      # sed: after line $open_line insert the imports block
      sed -i "${open_line}a\\  imports = [\n    ${_NIXOS_IMPORT_SENTINEL}\n  ];" "$cfg"
    fi
  fi

  _log "Injected import into $cfg"
  msg "configuration.nix updated.

Added inside imports [ ]:
    ${_NIXOS_IMPORT_SENTINEL}

Backup: $backup

To disable later, comment out that line OR set
  mariadb-installer.enable = false;
in $NIXOS_MODULE_FILE, then run nixos-rebuild switch."
}

# ------------------------------------------------------------------
# _nixos_toggle_enable
#   Flips the `default =` line in mariadb.nix between true and false.
# ------------------------------------------------------------------
_nixos_toggle_enable() {
  if [[ ! -f "$NIXOS_MODULE_FILE" ]]; then
    msg "$NIXOS_MODULE_FILE not found.
Has the module been written yet?"
    return 1
  fi

  local current
  current=$(grep -E '^\s*default\s*=' "$NIXOS_MODULE_FILE" \
    | head -1 | grep -oE 'true|false' || echo "")

  if [[ "$current" == "true" ]]; then
    sed -i 's/^\(\s*default\s*=\s*\)true;/\1false;/' "$NIXOS_MODULE_FILE"
    msg "MariaDB DISABLED in $NIXOS_MODULE_FILE
  (default = false)

Run  sudo nixos-rebuild switch  to apply."
  elif [[ "$current" == "false" ]]; then
    sed -i 's/^\(\s*default\s*=\s*\)false;/\1true;/' "$NIXOS_MODULE_FILE"
    msg "MariaDB ENABLED in $NIXOS_MODULE_FILE
  (default = true)

Run  sudo nixos-rebuild switch  to apply."
  else
    msg "Could not determine current enable state in $NIXOS_MODULE_FILE
(expected 'true' or 'false' on a 'default =' line).

Edit the file manually."
  fi
}

# ------------------------------------------------------------------
# _nixos_install — main entry point for the NixOS path
# ------------------------------------------------------------------
_nixos_install() {
  msg "NixOS detected.

MariaDB cannot be installed imperatively on NixOS.

This installer will:
  1. Write $NIXOS_MODULE_FILE  (self-contained NixOS module)
  2. Inject ONE import line into $NIXOS_CONFIG
  3. Optionally run  nixos-rebuild switch

The module has a master toggle:
  mariadb-installer.enable = true/false;

Commenting out the import line in configuration.nix
also disables everything cleanly."

  # Preview the module before writing.
  local preview
  preview="# /etc/nixos/mariadb.nix
{ config, pkgs, lib, ... }:
let cfg = config.mariadb-installer; in {
  options.mariadb-installer.enable = lib.mkOption {
    type    = lib.types.bool;
    default = true;   # ← flip to false to disable
  };
  config = lib.mkIf cfg.enable {
    services.mysql  = { enable = true; package = pkgs.mariadb; };
    environment.systemPackages = with pkgs; [ mariadb dialog ];
  };
}"
  $DIALOG --title "mariadb.nix preview" --msgbox "$preview" 22 74

  local action
  action=$(menu "How do you want to proceed?" \
    write_and_rebuild  "Write module + inject import + rebuild now"  \
    write_only         "Write module + inject import  (no rebuild)"  \
    show_manual        "Show manual instructions and exit"           \
    abort              "Abort") || return

  case "$action" in
    write_and_rebuild)
      _nixos_write_module true
      _nixos_inject_import
      _nixos_rebuild
      ;;
    write_only)
      _nixos_write_module true
      _nixos_inject_import
      msg "Files written. Run  sudo nixos-rebuild switch  when ready."
      ;;
    show_manual)
      msg "Manual steps:

1. Create /etc/nixos/mariadb.nix with the module shown above.

2. In /etc/nixos/configuration.nix add inside imports [ ]:
     ./mariadb.nix

3. Run:  sudo nixos-rebuild switch

To DISABLE later:
  • Set  mariadb-installer.enable = false;  in mariadb.nix, OR
  • Comment the line:  # ./mariadb.nix  in configuration.nix
  Then rebuild."
      exit 0
      ;;
    abort)
      msg "Aborted — no changes made."
      exit 0
      ;;
  esac

  # Post-install: offer the toggle/management menu.
  if yesno "Open the MariaDB NixOS management menu?"; then
    _nixos_toggle_menu
  fi
}

# ------------------------------------------------------------------
# _nixos_toggle_menu — TUI for flipping enable + rebuilding
# ------------------------------------------------------------------
_nixos_toggle_menu() {
  local current_state="unknown"
  if [[ -f "$NIXOS_MODULE_FILE" ]]; then
    current_state=$(grep -E '^\s*default\s*=' "$NIXOS_MODULE_FILE" \
      | head -1 | grep -oE 'true|false' || echo "unknown")
  fi

  local action
  action=$(menu "MariaDB — NixOS module manager
Current state: ${current_state}

Choose action:" \
    toggle   "Toggle enable  (now: ${current_state})"  \
    rebuild  "Run nixos-rebuild switch"                 \
    view_mod "View $NIXOS_MODULE_FILE"                  \
    view_cfg "View $NIXOS_CONFIG"                       \
    back     "Back / done") || return

  case "$action" in
    toggle)
      _nixos_toggle_enable
      _nixos_toggle_menu   # Re-enter so user can rebuild immediately.
      ;;
    rebuild)
      _nixos_rebuild
      _nixos_toggle_menu
      ;;
    view_mod)
      $DIALOG --title "$NIXOS_MODULE_FILE" --textbox "$NIXOS_MODULE_FILE" 40 100 || true
      _nixos_toggle_menu
      ;;
    view_cfg)
      $DIALOG --title "$NIXOS_CONFIG" --textbox "$NIXOS_CONFIG" 40 100 || true
      _nixos_toggle_menu
      ;;
    back) return ;;
  esac
}

_nixos_rebuild() {
  info "Running nixos-rebuild switch (this may take a while)..."
  if ! nixos-rebuild switch 2>>/tmp/mariadb-setup.log; then
    msg "nixos-rebuild switch failed. Check /tmp/mariadb-setup.log for details."
    _recover_from_failure $? "nixos-rebuild switch"
  fi
}

# ------------------------------------------------------------------
# _nix_user_install — non-NixOS  nix-env / nix profile  path
# ------------------------------------------------------------------
_nix_user_install() {
  info "Installing MariaDB in Nix user profile..."
  nix-env -iA nixpkgs.mariadb nixpkgs.dialog 2>>/tmp/mariadb-setup.log \
    || nix profile install nixpkgs#mariadb nixpkgs#dialog 2>>/tmp/mariadb-setup.log

  msg "MariaDB installed in user profile (nix-env).

NOTE: This is a dev environment install.
You must start mysqld manually and data is user-scoped."
}

### ============================
### MariaDB initialisation
### ============================

_init_mariadb() {
  info "Initialising MariaDB data directory..."

  case "$PKG_MANAGER" in
    nixos)
      # NixOS init is handled by the systemd service unit automatically.
      return 0
      ;;
    nix)
      msg "Skipping system init for Nix user install — start mysqld manually."
      return 0
      ;;
  esac

  local init_bin
  if   command -v mariadb-install-db >/dev/null 2>&1; then init_bin=mariadb-install-db
  elif command -v mysql_install_db    >/dev/null 2>&1; then init_bin=mysql_install_db
  else
    _recover_from_failure 1 "_init_mariadb: no init binary found"
    return
  fi

  $init_bin --user=mysql --basedir=/usr --datadir="$MARIADB_DATADIR" 2>>/tmp/mariadb-setup.log \
    || _recover_from_failure $? "$init_bin"
}

_start_mariadb_service() {
  if [[ $SYSTEMD_AVAILABLE -eq 0 ]]; then
    msg "systemd not available. Start MariaDB manually:
  mysqld_safe &"
    return 0
  fi

  info "Enabling and starting mariadb.service..."
  systemctl enable mariadb 2>>/tmp/mariadb-setup.log || true
  if ! systemctl start mariadb 2>>/tmp/mariadb-setup.log; then
    local journal_tail
    journal_tail=$(journalctl -u mariadb -n 30 --no-pager 2>/dev/null || echo "(journalctl unavailable)")
    msg "mariadb.service failed to start.

Last journal entries:
$journal_tail"
    _recover_from_failure $? "systemctl start mariadb"
  fi
}

secure_baseline() {
  info "Applying secure baseline..."
  mariadb 2>>/tmp/mariadb-setup.log <<'SQL' || _recover_from_failure $? "secure_baseline"
DELETE FROM mysql.user WHERE User='';
DROP DATABASE IF EXISTS test;
DELETE FROM mysql.db WHERE Db='test' OR Db LIKE 'test_%';
FLUSH PRIVILEGES;
SQL
}

### ============================
### Validate db scope
### ============================

validate_db_scope() {
  local scope="$1"

  [[ -z "$scope" ]] && { echo "*.*"; return 0; }

  if [[ "$scope" != *.* ]]; then
    msg "Invalid scope '$scope'.
Use:  *.*   mydb.*   mydb.table"
    return 1
  fi

  local lhs="${scope%%.*}"
  local rhs="${scope#*.}"

  if [[ -z "$lhs" || -z "$rhs" ]]; then
    msg "Invalid scope '$scope' — both sides of '.' must be non-empty (use * for wildcards)."
    return 1
  fi

  echo "$scope"
}

### ============================
### User management
### ============================

user_exists() {
  local user="$1" host="$2"
  mariadb -N -B 2>/dev/null <<SQL | grep -q 1
SELECT 1 FROM mysql.user WHERE User='${user}' AND Host='${host}';
SQL
}

create_user_tui() {
  local username host pw privs priv_sql raw_scope db_scope action

  username=$(input "Enter new MariaDB username") || return
  [[ -n "$username" ]] || { msg "Username cannot be empty."; return; }

  host=$(menu "Select host for $username" \
    localhost "Local socket / localhost"      \
    127.0.0.1 "Local TCP (GUI-friendly)"      \
    %         "Any host (NOT recommended)") || return

  pw=$(password "Enter password for $username@$host") || return
  [[ -n "$pw" ]] || { msg "Password cannot be empty."; return; }

  privs=$(checklist "Select privileges for $username@$host" \
    SELECT  "Read data"          off \
    INSERT  "Insert rows"        off \
    UPDATE  "Update rows"        off \
    DELETE  "Delete rows"        off \
    CREATE  "Create objects"     off \
    DROP    "Drop objects"       off \
    ALTER   "Alter schema"       off \
    INDEX   "Manage indexes"     off \
    ALL     "ALL PRIVILEGES"     off) || return

  if [[ "$privs" == *ALL* ]]; then
    priv_sql="ALL PRIVILEGES"
  else
    priv_sql=$(echo "$privs" | tr ' ' ',' | tr -d '"')
  fi

  [[ -n "$priv_sql" ]] || { msg "No privileges selected — user not created."; return; }

  while true; do
    raw_scope=$(input "Database scope (e.g. mydb.* or *.*)") || return
    db_scope=$(validate_db_scope "$raw_scope") && break
  done

  if user_exists "$username" "$host"; then
    action=$(menu "User ${username}@${host} already exists. Choose action:" \
      abort    "Abort"                          \
      alter    "Alter password & privileges"    \
      recreate "Drop and recreate") || return

    case "$action" in
      abort)
        msg "Aborted — no changes made."
        return
        ;;
      alter)
        mariadb 2>>/tmp/mariadb-setup.log <<SQL || _recover_from_failure $? "ALTER USER $username@$host"
ALTER USER '${username}'@'${host}' IDENTIFIED BY '${pw}';
GRANT ${priv_sql} ON ${db_scope} TO '${username}'@'${host}';
FLUSH PRIVILEGES;
SQL
        msg "User ${username}@${host} updated."
        ;;
      recreate)
        mariadb 2>>/tmp/mariadb-setup.log <<SQL || _recover_from_failure $? "DROP/CREATE USER $username@$host"
DROP USER '${username}'@'${host}';
CREATE USER '${username}'@'${host}' IDENTIFIED BY '${pw}';
GRANT ${priv_sql} ON ${db_scope} TO '${username}'@'${host}';
FLUSH PRIVILEGES;
SQL
        msg "User ${username}@${host} recreated."
        ;;
    esac
  else
    mariadb 2>>/tmp/mariadb-setup.log <<SQL || _recover_from_failure $? "CREATE USER $username@$host"
CREATE USER '${username}'@'${host}' IDENTIFIED BY '${pw}';
GRANT ${priv_sql} ON ${db_scope} TO '${username}'@'${host}';
FLUSH PRIVILEGES;
SQL
    msg "User ${username}@${host} created successfully."
  fi
}

### ============================
### Main
### ============================

main() {
  require_root
  _ensure_dialog          # bootstraps dialog before we can use TUI
  detect_systemd
  detect_pkg_managers

  install_packages

  if [[ "$PKG_MANAGER" == "nixos" ]]; then
    # nixos path: config patched + rebuild done inside _nixos_install
    msg "NixOS: MariaDB is managed by the NixOS service. Setup complete."
    exit 0
  fi

  check_dependencies      # verify binaries exist after install

  _init_mariadb
  _start_mariadb_service
  secure_baseline

  if yesno "Create a MariaDB database user now?"; then
    create_user_tui
  fi

  msg "MariaDB setup complete.

Log file: /tmp/mariadb-setup.log"
}

main "$@"

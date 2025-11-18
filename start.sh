#!/usr/bin/env bash

# Post-login setup script
# - Start SSH server
# - Start D-Bus if available
# - Set DNS resolver to Google DNS (8.8.8.8)
# - Append OpenVPN3 helper aliases to the user's ~/.bashrc
# - Copy /data/app/.netrc into user home(s)
# - Configure git global user email and name
# - Install VS Code extensions

set -euo pipefail

log() {
  echo "[start] $*"
}

warn() {
  echo "[start][warn] $*" >&2
}

is_root() {
  [ "${EUID:-$(id -u)}" -eq 0 ]
}

# 1) Start SSH server
start_ssh() {
  if command -v sshd >/dev/null 2>&1; then
    if is_root; then
      # Create privilege separation directory if it doesn't exist
      mkdir -p /run/sshd
      
      # Check if SSH server is already running
      if pgrep -x sshd >/dev/null 2>&1; then
        log "SSH server is already running"
      else
        # Start SSH server
        if /usr/sbin/sshd; then
          log "SSH server started successfully"
        else
          warn "Failed to start SSH server; continuing"
        fi
      fi
    else
      warn "Not root; cannot start SSH server"
    fi
  else
    warn "SSH server not installed; skipping"
  fi
}

# 2) Start dbus if possible
start_dbus() {
  if command -v service >/dev/null 2>&1 && service --status-all >/dev/null 2>&1; then
    if service dbus status >/dev/null 2>&1; then
      log "dbus is already running"
    else
      if is_root; then
        if service dbus start >/dev/null 2>&1 || /etc/init.d/dbus start >/dev/null 2>&1; then
          log "dbus started via service/init.d"
        else
          warn "Failed to start dbus via service/init.d; continuing"
        fi
      else
        warn "Not root; skipping dbus start"
      fi
    fi
  elif [ -x /etc/init.d/dbus ]; then
    if is_root; then
      if /etc/init.d/dbus start >/dev/null 2>&1; then
        log "dbus started via init.d"
      else
        warn "Failed to start dbus via init.d; continuing"
      fi
    else
      warn "Not root; skipping dbus start"
    fi
  else
    # Fallback to dbus-daemon if present
    if command -v dbus-daemon >/dev/null 2>&1; then
      if is_root; then
        if pgrep -x dbus-daemon >/dev/null 2>&1; then
          log "dbus-daemon already running"
        else
          if dbus-daemon --system --fork >/dev/null 2>&1; then
            log "dbus-daemon started (system)"
          else
            warn "Failed to start dbus-daemon; continuing"
          fi
        fi
      else
        warn "Not root; skipping dbus-daemon start"
      fi
    else
      warn "dbus not installed; skipping"
    fi
  fi
}

# 3) Configure DNS resolver
set_dns() {
  local resolv="/etc/resolv.conf"
  if is_root; then
    if [ -e "$resolv" ] && [ ! -L "$resolv" ]; then
      cp -f "$resolv" "${resolv}.bak" || true
    fi
    # Overwrite with a minimal resolv.conf using Google DNS
    printf "# Managed by start.sh on $(date -u +'%Y-%m-%dT%H:%M:%SZ')\n" > "$resolv"
    printf "nameserver 8.8.8.8\n" >> "$resolv"
    log "Configured DNS resolver to 8.8.8.8"
  else
    warn "Not root; cannot modify /etc/resolv.conf"
  fi
}

# 4) Append aliases to bashrc for relevant users
append_aliases() {
  local target_users=()
  # Prefer invoking user if SUDO_USER set, otherwise current user
  if [ -n "${SUDO_USER:-}" ] && id -u "$SUDO_USER" >/dev/null 2>&1; then
    target_users+=("$SUDO_USER")
  else
    target_users+=("${USER:-root}")
  fi
  # Also add 'ubuntu' user if it exists and isn't already included
  if id -u ubuntu >/dev/null 2>&1; then
    local found=false
    for u in "${target_users[@]}"; do
      if [ "$u" = "ubuntu" ]; then found=true; break; fi
    done
    if [ "$found" = false ]; then target_users+=("ubuntu"); fi
  fi

  local aliases=(
    "alias vpn-sessions='openvpn3 sessions-list'"
    "alias vpn-start='openvpn3 session-start --config /data/app/client.ovpn'"
    "alias vpn-disconnect='openvpn3 session-manage --disconnect --config /data/app/client.ovpn'"
  )

  for u in "${target_users[@]}"; do
    local home_dir
    home_dir=$(getent passwd "$u" | cut -d: -f6)
    [ -n "$home_dir" ] || continue
    local bashrc="$home_dir/.bashrc"
    touch "$bashrc"

    for a in "${aliases[@]}"; do
      if grep -Fqx "$a" "$bashrc"; then
        :
      else
        echo "$a" >> "$bashrc"
      fi
    done

    # Ensure ownership if we're root
    if is_root; then
      chown "$u":"$u" "$bashrc" || true
    fi
    log "Ensured OpenVPN3 aliases in $bashrc"
  done
}

copy_netrc() {
  local src="/data/app/.netrc"
  if [ ! -f "$src" ]; then
    warn "No $src found; skipping .netrc copy"
    return 0
  fi

  local target_users=()
  if [ -n "${SUDO_USER:-}" ] && id -u "$SUDO_USER" >/dev/null 2>&1; then
    target_users+=("$SUDO_USER")
  else
    target_users+=("${USER:-root}")
  fi
  if id -u ubuntu >/dev/null 2>&1; then
    local found=false
    for u in "${target_users[@]}"; do
      if [ "$u" = "ubuntu" ]; then found=true; break; fi
    done
    if [ "$found" = false ]; then target_users+=("ubuntu"); fi
  fi

  for u in "${target_users[@]}"; do
    local home_dir
    home_dir=$(getent passwd "$u" | cut -d: -f6)
    [ -n "$home_dir" ] || continue
    local dst="$home_dir/.netrc"

    # Attempt copy; warn if not writable
    if cp -f "$src" "$dst" 2>/dev/null; then
      chmod 600 "$dst" 2>/dev/null || warn "Could not chmod 600 $dst"
      if is_root; then
        chown "$u":"$u" "$dst" 2>/dev/null || warn "Could not chown $dst to $u"
      fi
      log "Installed .netrc for user $u at $dst"
    else
      warn "Could not write $dst (insufficient permissions?). Try running as root or copy manually."
    fi
  done
}

configure_git() {
  local target_users=()
  if [ -n "${SUDO_USER:-}" ] && id -u "$SUDO_USER" >/dev/null 2>&1; then
    target_users+=("$SUDO_USER")
  else
    target_users+=("${USER:-root}")
  fi
  if id -u ubuntu >/dev/null 2>&1; then
    local found=false
    for u in "${target_users[@]}"; do
      if [ "$u" = "ubuntu" ]; then found=true; break; fi
    done
    if [ "$found" = false ]; then target_users+=("ubuntu"); fi
  fi

  for u in "${target_users[@]}"; do
    local home_dir
    home_dir=$(getent passwd "$u" | cut -d: -f6)
    [ -n "$home_dir" ] || continue

    # Run git config as the target user
    if is_root && [ "$u" != "root" ]; then
      su - "$u" -c 'git config --global user.email "yury.konkov@armenotech.com"' 2>/dev/null || warn "Could not set git email for user $u"
      su - "$u" -c 'git config --global user.name "Yury Konkov"' 2>/dev/null || warn "Could not set git name for user $u"
      log "Configured git user for $u"
    else
      git config --global user.email "yury.konkov@armenotech.com" 2>/dev/null || warn "Could not set git email"
      git config --global user.name "Yury Konkov" 2>/dev/null || warn "Could not set git name"
      log "Configured git user"
    fi
  done
}

install_vscode_extensions() {
  # Check if code CLI is available
  if ! command -v code >/dev/null 2>&1; then
    warn "code CLI not found; skipping VS Code extension installation"
    return 0
  fi

  local extensions=(
    "eamodio.gitlens"
    "GitHub.copilot"
    "mtxr.sqltools"
    "well-ar.plantuml"
    "mtxr.sqltools-driver-mysql"
    "mtxr.sqltools-driver-pg"
    "ms-kubernetes-tools.vscode-kubernetes-tools"
    "netcorext.uuid-generator"
    "humao.rest-client"
    "tooltitudeteam.tooltitude"
    "766b.go-outliner"
    "github.copilot-workspace"
  )

  local target_users=()
  if [ -n "${SUDO_USER:-}" ] && id -u "$SUDO_USER" >/dev/null 2>&1; then
    target_users+=("$SUDO_USER")
  else
    target_users+=("${USER:-root}")
  fi
  if id -u ubuntu >/dev/null 2>&1; then
    local found=false
    for u in "${target_users[@]}"; do
      if [ "$u" = "ubuntu" ]; then found=true; break; fi
    done
    if [ "$found" = false ]; then target_users+=("ubuntu"); fi
  fi

  for u in "${target_users[@]}"; do
    local home_dir
    home_dir=$(getent passwd "$u" | cut -d: -f6)
    [ -n "$home_dir" ] || continue

    log "Installing VS Code extensions for user $u..."
    for ext in "${extensions[@]}"; do
      # Run code as the target user
      if is_root && [ "$u" != "root" ]; then
        if su - "$u" -c "code --install-extension '$ext' --force" 2>/dev/null; then
          log "Installed extension $ext for user $u"
        else
          warn "Failed to install extension $ext for user $u"
        fi
      else
        if code --install-extension "$ext" --force 2>/dev/null; then
          log "Installed extension $ext"
        else
          warn "Failed to install extension $ext"
        fi
      fi
    done
  done
}

main() {
  start_ssh
  start_dbus
  set_dns
  append_aliases
  copy_netrc
  configure_git
  install_vscode_extensions
  log "Done. Open a new shell session to use the aliases."
  
  # Execute the command passed as arguments (from CMD in Dockerfile)
  if [ $# -gt 0 ]; then
    log "Executing: $*"
    exec "$@"
  fi
}

main "$@"

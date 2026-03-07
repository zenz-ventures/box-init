#!/usr/bin/env bash
set -euo pipefail

declare -a ACTION_PLANNED=()
declare -a ACTION_SKIPPED=()
declare -a ACTION_PERFORMED=()

add_planned()   { ACTION_PLANNED+=("$1"); }
add_skipped()   { ACTION_SKIPPED+=("$1"); }
add_performed() { ACTION_PERFORMED+=("$1"); }

show_summary() {
  printf "\n\033[36mPlanned:\033[0m\n"
  for item in "${ACTION_PLANNED[@]}"; do
    printf "  - %s\n" "$item"
  done

  if [ ${#ACTION_SKIPPED[@]} -gt 0 ]; then
    printf "\033[33mNot needed:\033[0m\n"
    for item in "${ACTION_SKIPPED[@]}"; do
      printf "  - %s\n" "$item"
    done
  fi

  printf "\033[32mPerformed:\033[0m\n"
  if [ ${#ACTION_PERFORMED[@]} -gt 0 ]; then
    for item in "${ACTION_PERFORMED[@]}"; do
      printf "  - %s\n" "$item"
    done
  else
    printf "  - No changes were required.\n"
  fi
}

log() {
  printf "\n[%s] %s\n" "$(date +%H:%M:%S)" "$1"
}

command_exists() {
  command -v "$1" >/dev/null 2>&1
}

ensure_sudo() {
  if ! command_exists sudo; then
    echo "sudo is required but not available."
    exit 1
  fi
}

install_prerequisites() {
  add_planned "Install prerequisites (git, curl, ca-certificates, openssh-client)."

  local needed=false
  for pkg in git curl openssh-client; do
    if ! command_exists "$pkg"; then
      needed=true
      break
    fi
  done

  if [ "$needed" = false ]; then
    log "Prerequisites already installed"
    add_skipped "Prerequisites were already installed."
    return
  fi

  log "Installing prerequisites"
  sudo apt-get update
  sudo DEBIAN_FRONTEND=noninteractive apt-get install -y \
    ca-certificates \
    curl \
    git \
    openssh-client

  add_performed "Installed prerequisites."
}

configure_git_identity() {
  add_planned "Configure git identity (user.name and user.email)."

  local name_set=false email_set=false

  if git config --global --get user.name >/dev/null 2>&1; then
    name_set=true
  fi
  if git config --global --get user.email >/dev/null 2>&1; then
    email_set=true
  fi

  if [ "$name_set" = true ] && [ "$email_set" = true ]; then
    log "Git identity already configured"
    add_skipped "Git identity was already configured."
    return
  fi

  log "Configuring git identity"

  if [ "$name_set" = false ]; then
    git_name=""
    while [ -z "$git_name" ]; do
      read -r -p "Git user.name: " git_name
      [ -n "$git_name" ] || echo "user.name cannot be empty."
    done
    git config --global user.name "$git_name"
  fi

  if [ "$email_set" = false ]; then
    git_email=""
    while [ -z "$git_email" ]; do
      read -r -p "Git user.email: " git_email
      [ -n "$git_email" ] || echo "user.email cannot be empty."
    done
    git config --global user.email "$git_email"
  fi

  add_performed "Configured git identity."
}

setup_ssh_key() {
  add_planned "Generate an SSH key for GitHub."

  mkdir -p "$HOME/.ssh"
  chmod 700 "$HOME/.ssh"

  if [ -f "$HOME/.ssh/id_ed25519" ]; then
    log "SSH key already exists at ~/.ssh/id_ed25519"
    add_skipped "SSH key already existed."
  else
    local email
    email="$(git config --global --get user.email)"
    log "Generating SSH key"
    ssh-keygen -t ed25519 -C "$email" -f "$HOME/.ssh/id_ed25519" -N ""
    add_performed "Generated SSH key."
  fi

  add_planned "Write SSH config for github.com."

  local ssh_config="$HOME/.ssh/config"
  if [ -f "$ssh_config" ] && grep -q "Host github.com" "$ssh_config"; then
    log "SSH config already has github.com entry"
    add_skipped "SSH config already had github.com entry."
  else
    cat >> "$ssh_config" <<'SSH_EOF'
Host github.com
  HostName github.com
  User git
  IdentityFile ~/.ssh/id_ed25519
  IdentitiesOnly yes
SSH_EOF
    add_performed "Wrote SSH config for github.com."
  fi

  chmod 600 "$ssh_config"
}

wait_for_github_access() {
  add_planned "Verify GitHub SSH access."

  echo
  echo "==== Add this public key to GitHub ===="
  echo
  cat "$HOME/.ssh/id_ed25519.pub"
  echo
  echo "https://github.com/settings/ssh/new"
  echo
  echo "======================================="

  while true; do
    read -r -p "Press Enter after adding the key to GitHub... "
    if ssh -T git@github.com 2>&1 | grep -q "successfully authenticated"; then
      log "GitHub SSH access confirmed"
      add_performed "Verified GitHub SSH access."
      return
    fi
    echo "SSH test failed. Make sure the key is added and try again."
  done
}

clone_and_handoff() {
  add_planned "Clone box-setup into ~/repos/box-setup."

  local repo_dir="$HOME/repos/box-setup"
  mkdir -p "$HOME/repos"

  if [ -d "$repo_dir" ]; then
    log "box-setup already cloned at $repo_dir -- pulling latest"
    if git -C "$repo_dir" pull; then
      add_performed "Pulled latest box-setup."
    else
      log "git pull failed (e.g. no upstream or conflicts); continuing with existing tree."
    fi
  else
    log "Cloning box-setup"
    git clone git@github.com:zenz-ventures/box-setup.git "$repo_dir"
    add_performed "Cloned box-setup."
  fi

  printf "\n\033[32mInit complete.\033[0m\n"
  show_summary

  local setup_script="$repo_dir/linux/setup.sh"
  if [ ! -f "$setup_script" ]; then
    echo "Error: setup script not found at $setup_script"
    exit 1
  fi

  log "Handing off to setup script"
  exec bash "$setup_script"
}

main() {
  echo "Initializing Linux environment..."

  ensure_sudo
  install_prerequisites
  configure_git_identity
  setup_ssh_key
  wait_for_github_access
  clone_and_handoff
}

main "$@"

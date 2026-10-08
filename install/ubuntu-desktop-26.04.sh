#!/bin/bash
set -e

# =============================================================================
# Ubuntu Desktop 26.04 Setup Script
# Christopher Kapic's dotfiles
#
# This script is idempotent and can be safely re-run.
# Run as your normal user (uses sudo for apt operations).
#
# The optional SSH/NetBird/no-sleep items turn an (old) laptop into a headless
# box you can SSH into over NetBird to run claude/codex remotely.
# =============================================================================

echo "============================================"
echo "  Ubuntu Desktop 26.04 Setup"
echo "  Christopher Kapic's dotfiles"
echo "============================================"
echo ""

# Read one SSH public key from the terminal into SSH_PUBLIC_KEY, re-prompting
# until it's valid. Private keys are rejected, and any extra pasted lines (e.g.
# the body of a multi-line private key) are discarded so they can't leak into
# later prompts. Pass "optional" to allow an empty answer.
SSH_PUBKEY_REGEX='^(ssh-ed25519|ssh-rsa|ecdsa-sha2-nistp(256|384|521)|sk-ssh-ed25519@openssh\.com|sk-ecdsa-sha2-nistp256@openssh\.com) [A-Za-z0-9+/]+=*( .*)?$'
read_ssh_public_key() {
  while true; do
    if ! read -rp "> " SSH_PUBLIC_KEY && [ -z "$SSH_PUBLIC_KEY" ]; then
      echo "Error: No input received."
      exit 1
    fi
    while read -r -t 0.2 _; do :; done
    if [ -z "$SSH_PUBLIC_KEY" ]; then
      [ "$1" = "optional" ] && return 0
      echo "Error: No SSH key provided."
    elif [[ "$SSH_PUBLIC_KEY" == *"PRIVATE KEY"* || "$SSH_PUBLIC_KEY" == PuTTY-User-Key-File-* ]]; then
      echo "Error: That is a PRIVATE key - never paste it anywhere. Paste the .pub file instead (e.g. ~/.ssh/id_ed25519.pub)."
    elif [[ "$SSH_PUBLIC_KEY" =~ $SSH_PUBKEY_REGEX ]] && ssh-keygen -l -f /dev/stdin <<< "$SSH_PUBLIC_KEY" &> /dev/null; then
      return 0
    else
      echo "Error: Not a valid SSH public key (expected e.g. 'ssh-ed25519 AAAA... comment'). Try again:"
    fi
    SSH_PUBLIC_KEY=
  done
}

# Interactive multi-select menu. Uses bash `read` rather than `stty raw` + `dd`
# (26.04 ships the Rust coreutils), and a Ctrl-C can't leave the terminal raw.
# Usage: multiselect RESULT_ARRAY DEFAULT TITLE ITEM...
# DEFAULT is 1 (all selected) or 0 (none selected).
multiselect() {
  local -n ms_result=$1
  local default=$2 title=$3
  shift 3
  local items=("$@") sel=() cursor=0 total=$# key rest i pointer check redraw=false
  for i in "${!items[@]}"; do sel+=("$default"); done

  while true; do
    $redraw && printf "\033[%dA" "$((total + 1))"
    redraw=true
    printf "%s (↑/k up, ↓/j down, space toggle, enter confirm):\n" "$title"
    for i in "${!items[@]}"; do
      if [ "$i" -eq "$cursor" ]; then pointer=">"; else pointer=" "; fi
      if [ "${sel[$i]}" = "1" ]; then check="[x]"; else check="[ ]"; fi
      printf " %s %s %s\033[K\n" "$pointer" "$check" "${items[$i]}"
    done

    IFS= read -rsn1 key
    case "$key" in
      $'\x1b')
        IFS= read -rsn2 -t 0.1 rest || true
        case "$rest" in
          "[A") if ((cursor > 0)); then cursor=$((cursor - 1)); fi ;;
          "[B") if ((cursor < total - 1)); then cursor=$((cursor + 1)); fi ;;
        esac
        ;;
      k) if ((cursor > 0)); then cursor=$((cursor - 1)); fi ;;
      j) if ((cursor < total - 1)); then cursor=$((cursor + 1)); fi ;;
      " ") sel[cursor]=$((1 - sel[cursor])) ;;
      "") break ;;  # Enter
    esac
  done
  echo ""

  ms_result=()
  for i in "${!items[@]}"; do
    if [ "${sel[$i]}" = "1" ]; then ms_result+=("${items[$i]}"); fi
  done
}

# --- Ensure the script is NOT run as root ---
if [ "$(id -u)" -eq 0 ]; then
  echo "Error: Do not run this script as root. Run as your normal user (sudo will be used where needed)."
  exit 1
fi

case "$(uname -m)" in
  x86_64)        ARCH=x86_64 ;;
  aarch64|arm64) ARCH=arm64 ;;
  *) echo "Error: Unsupported architecture: $(uname -m)"; exit 1 ;;
esac

# =============================================================================
# Step 1: Install base packages
# =============================================================================
echo "--- Installing base packages ---"
sudo apt-get update -qq
sudo apt-get install -y git curl wget build-essential unzip stow zsh fontconfig sccache

# =============================================================================
# Step 2: Install starship prompt (packaged in the Ubuntu archive since 25.04)
# =============================================================================
echo "--- Installing starship ---"
sudo apt-get install -y starship

# =============================================================================
# Step 3: Clone dotfiles
# =============================================================================
if ! [ -d "$HOME/dotfiles" ]; then
  echo "Cloning dotfiles..."
  git clone --depth=1 https://github.com/christopher-kapic/dotfiles.git "$HOME/dotfiles"
else
  echo "dotfiles already cloned."
fi

cd "$HOME/dotfiles"

# =============================================================================
# Step 4: Interactive stow package picker
# =============================================================================
skip_dirs=(".git" "templates" "fonts" "bettermouse" "install")

packages=()
for d in */; do
  d="${d%/}"
  skip=false
  for s in "${skip_dirs[@]}"; do
    if [ "$d" = "$s" ]; then skip=true; break; fi
  done
  $skip || packages+=("$d")
done

multiselect stow_selected 1 "Select packages to stow" "${packages[@]}"

# Ensure ~/.local/bin exists as a real directory so stow symlinks individual scripts
mkdir -p "$HOME/.local/bin"

# Stow selected packages (--restow for idempotency)
stowed_zsh=false
for pkg in "${stow_selected[@]}"; do
  echo "Stowing $pkg..."
  stow --restow --target="$HOME" "$pkg"
  if [ "$pkg" = "zsh" ]; then stowed_zsh=true; fi
done

if $stowed_zsh; then
  # The zsh config keeps its history in ~/.cache/zsh
  mkdir -p "$HOME/.cache/zsh"
  if ! [ -f "$HOME/.zshrc" ]; then
    echo "Copying zshrc template to ~/.zshrc (edit for machine-specific config)"
    cp "$HOME/dotfiles/templates/zshrc" "$HOME/.zshrc"
  else
    echo "~/.zshrc already exists, skipping template copy"
  fi
fi

# =============================================================================
# Step 5: Generate git user config
# =============================================================================
if ! [ -f "$HOME/.config/git/config.local" ]; then
  echo ""
  echo "--- Git User Setup ---"
  read -rp "Enter your full name for git: " GIT_NAME
  read -rp "Enter your email for git: " GIT_EMAIL
  mkdir -p "$HOME/.config/git"
  cat > "$HOME/.config/git/config.local" << EOF
[user]
	name = $GIT_NAME
	email = $GIT_EMAIL
EOF
  echo "Git user config written to ~/.config/git/config.local"
fi

# =============================================================================
# Step 6: Install fonts
# =============================================================================
echo "--- Installing fonts ---"
mkdir -p "$HOME/.local/share/fonts"
cp "$HOME/dotfiles/fonts/.config/fonts/"* "$HOME/.local/share/fonts" 2>/dev/null || true
fc-cache -f "$HOME/.local/share/fonts" 2>/dev/null || true

# =============================================================================
# Step 7: Set zsh as default shell
# Check the passwd entry rather than $SHELL, which stays stale until re-login.
# =============================================================================
if [ "$(getent passwd "$USER" | cut -d: -f7)" != "$(command -v zsh)" ]; then
  echo "Setting zsh as default shell..."
  chsh -s "$(command -v zsh)"
else
  echo "zsh is already the default shell."
fi

# =============================================================================
# Step 8: Install fnm and Node.js
# =============================================================================
# fnm-update installs the latest release binary to ~/.local/bin/fnm; re-run it
# later to upgrade.
"$HOME/dotfiles/scripts/.local/bin/fnm-update"
export PATH="$HOME/.local/bin:$PATH"
eval "$(fnm env --shell bash)"

# fnm install is a no-op (with a warning) if the version is already installed
fnm install 25
fnm default 25
echo "Node.js installed: $(node --version)"

# =============================================================================
# Step 9: Install Rust
# Check ~/.cargo directly: it may not be on PATH in this non-interactive shell.
# =============================================================================
if ! [ -x "$HOME/.cargo/bin/rustc" ]; then
  echo "Installing Rust..."
  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
else
  echo "Rust already installed: $("$HOME/.cargo/bin/rustc" --version)"
fi
source "$HOME/.cargo/env"

# =============================================================================
# Step 10: Install Neovim and LunaVim
# https://github.com/christopher-kapic/LunaVim
# The executable is still `lvim` and the config still lives in ~/.config/lvim.
# =============================================================================
# Neovim comes from the latest GitHub release rather than apt (which lags
# behind): nvim-update installs it to ~/.nvim and links ~/.local/bin/nvim.
# Re-running it later upgrades in place.
"$HOME/dotfiles/scripts/.local/bin/nvim-update"
export PATH="$HOME/.nvim/bin:$PATH"

LUNAVIM_INSTALLER_URL="https://raw.githubusercontent.com/christopher-kapic/LunaVim/master/scripts/install.sh"

if [ -d "$HOME/.local/share/lunavim/.git" ]; then
  echo "LunaVim already installed."
else
  # LunaVim's installer refuses to overwrite a LunarVim/CKLunarVim launcher
  # unless --force is given, so detect a prior install and migrate it.
  lunavim_args=()
  if [ -e "$HOME/.local/share/lunarvim" ] || [ -e "$HOME/.local/bin/lvim" ]; then
    echo "Existing LunarVim/CKLunarVim install detected - replacing the lvim launcher with LunaVim."
    echo "The old ~/.local/share/lunarvim directory is left on disk; remove it once you're happy."
    lunavim_args+=(--force)
  fi
  echo "Installing LunaVim..."
  curl -sL "$LUNAVIM_INSTALLER_URL" | bash -s -- "${lunavim_args[@]}"
fi

# =============================================================================
# Step 11: Optional packages
# =============================================================================
echo ""
echo "--- Optional packages ---"

opt_packages=("tmux" "ffmpeg" "gh" "htop" "jq" "lazygit" "opencode" "claude-code" "openssh-server" "netbird" "no-sleep (laptop server)")
multiselect opt_selected 0 "Select optional packages to install" "${opt_packages[@]}"

apt_pkgs=()
install_gh=false
install_lazygit=false
install_opencode=false
install_claude=false
install_openssh=false
install_netbird=false
install_nosleep=false

for pkg in "${opt_selected[@]}"; do
  case "$pkg" in
    gh)             install_gh=true ;;
    lazygit)        install_lazygit=true ;;
    opencode)       install_opencode=true ;;
    claude-code)    install_claude=true ;;
    openssh-server) install_openssh=true ;;
    netbird)        install_netbird=true ;;
    no-sleep*)      install_nosleep=true ;;
    *)              apt_pkgs+=("$pkg") ;;
  esac
done

if [ ${#apt_pkgs[@]} -gt 0 ]; then
  echo "Installing apt packages: ${apt_pkgs[*]}"
  sudo apt-get install -y "${apt_pkgs[@]}"
fi

if $install_gh; then
  if ! command -v gh &> /dev/null; then
    echo "Installing GitHub CLI..."
    sudo mkdir -p -m 755 /etc/apt/keyrings
    wget -qO- https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo tee /etc/apt/keyrings/githubcli-archive-keyring.gpg > /dev/null
    sudo chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
    sudo apt-get update -qq
    sudo apt-get install -y gh
  else
    echo "gh already installed."
  fi
fi

if $install_lazygit; then
  if ! command -v lazygit &> /dev/null; then
    echo "Installing lazygit..."
    LAZYGIT_VERSION=$(curl -s "https://api.github.com/repos/jesseduffield/lazygit/releases/latest" | grep -Po '"tag_name": "v\K[^"]*')
    curl -Lo /tmp/lazygit.tar.gz "https://github.com/jesseduffield/lazygit/releases/latest/download/lazygit_${LAZYGIT_VERSION}_Linux_${ARCH}.tar.gz"
    tar xf /tmp/lazygit.tar.gz -C /tmp lazygit
    sudo install /tmp/lazygit /usr/local/bin
    rm -f /tmp/lazygit /tmp/lazygit.tar.gz
  else
    echo "lazygit already installed."
  fi
fi

if $install_opencode; then
  if ! [ -x "$HOME/.opencode/bin/opencode" ] && ! command -v opencode &> /dev/null; then
    echo "Installing OpenCode..."
    curl -fsSL https://opencode.ai/install | bash
  else
    echo "OpenCode already installed."
  fi
fi

if $install_claude; then
  if ! [ -x "$HOME/.local/bin/claude" ] && ! command -v claude &> /dev/null; then
    echo "Installing Claude Code..."
    curl -fsSL https://claude.ai/install.sh | bash
  else
    echo "Claude Code already installed."
  fi
fi

if $install_openssh; then
  echo "Setting up OpenSSH server..."
  sudo apt-get install -y openssh-server
  sudo systemctl enable --now ssh
  if sudo ufw status 2>/dev/null | grep -q "Status: active"; then
    sudo ufw allow OpenSSH
  fi

  echo "Paste an SSH public key to authorize for '$USER' (one line), or press Enter to skip:"
  read_ssh_public_key optional
  if [ -n "$SSH_PUBLIC_KEY" ]; then
    mkdir -p "$HOME/.ssh"
    touch "$HOME/.ssh/authorized_keys"
    if grep -qxF "$SSH_PUBLIC_KEY" "$HOME/.ssh/authorized_keys"; then
      echo "SSH public key already present."
    else
      echo "$SSH_PUBLIC_KEY" >> "$HOME/.ssh/authorized_keys"
      echo "SSH public key installed."
    fi
    chmod 700 "$HOME/.ssh"
    chmod 600 "$HOME/.ssh/authorized_keys"
  fi

  # Key-only auth via a drop-in. sshd uses the first value it sees and the
  # sshd_config.d includes come first, so 00- wins over e.g. 50-cloud-init.conf.
  # Only offered once a key is authorized, so this can't lock you out.
  SSHD_HARDENING=/etc/ssh/sshd_config.d/00-dotfiles-hardening.conf
  if [ -f "$SSHD_HARDENING" ]; then
    echo "SSH already restricted to key-based auth."
  elif [ -s "$HOME/.ssh/authorized_keys" ]; then
    read -rp "Disable SSH password login and root login (key-based auth only)? [Y/n] " HARDEN_SSH
    if ! [[ "$HARDEN_SSH" =~ ^[Nn] ]]; then
      printf '%s\n' "PermitRootLogin no" "PasswordAuthentication no" "KbdInteractiveAuthentication no" \
        | sudo tee "$SSHD_HARDENING" > /dev/null
      if sudo sshd -t; then
        sudo systemctl try-restart ssh
        echo "SSH restricted to key-based auth."
      else
        sudo rm -f "$SSHD_HARDENING"
        echo "Warning: sshd rejected the hardening config; left SSH settings unchanged."
      fi
    fi
  fi
fi

if $install_netbird; then
  if ! command -v netbird &> /dev/null; then
    # The installer uses sudo itself and adds the tray UI on desktop systems
    echo "Installing NetBird..."
    curl -fsSL https://pkgs.netbird.io/install.sh | sh
  else
    echo "NetBird already installed."
  fi

  if sudo netbird status 2>/dev/null | grep -q "^Management: Connected"; then
    echo "NetBird already connected."
  else
    echo "Enter a NetBird setup key to connect now, or press Enter to skip (you can log in from the tray app instead):"
    read -rsp "> " NB_SETUP_KEY
    echo ""
    if [ -n "$NB_SETUP_KEY" ]; then
      read -rp "Management URL (press Enter for NetBird cloud): " NB_MANAGEMENT_URL
      nb_args=(up --setup-key "$NB_SETUP_KEY")
      [ -n "$NB_MANAGEMENT_URL" ] && nb_args+=(--management-url "$NB_MANAGEMENT_URL")
      sudo netbird "${nb_args[@]}"
    fi
  fi
fi

# Keep a laptop reachable over SSH with the lid closed: logind ignores the lid
# switch and the sleep targets are masked so nothing can suspend the machine.
if $install_nosleep; then
  echo "Disabling suspend and lid-close sleep..."
  sudo mkdir -p /etc/systemd/logind.conf.d
  printf '%s\n' "[Login]" "HandleLidSwitch=ignore" "HandleLidSwitchExternalPower=ignore" "HandleLidSwitchDocked=ignore" \
    | sudo tee /etc/systemd/logind.conf.d/00-dotfiles-no-sleep.conf > /dev/null
  sudo systemctl mask sleep.target suspend.target hibernate.target hybrid-sleep.target
  # Stop GNOME from trying to suspend on idle (no-op outside a GNOME session)
  gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-ac-type 'nothing' 2>/dev/null || true
  gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-battery-type 'nothing' 2>/dev/null || true
  echo "Sleep disabled. The lid-switch setting takes effect after a reboot."
fi

# =============================================================================
# Done!
# =============================================================================
echo ""
echo "============================================"
echo "  Setup complete!"
echo "============================================"
echo ""
echo "Summary:"
echo "  - Dotfiles stowed"
echo "  - Starship: installed via apt"
echo "  - Zsh: default shell (log out and back in if just changed)"
echo "  - Neovim: latest release in ~/.nvim (run nvim-update to upgrade)"
echo "  - LunaVim: installed"
echo "  - Node.js: installed via fnm"
echo "  - Rust: installed via rustup"
echo "  - Fonts: MesloLGS NF installed"

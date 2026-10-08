#!/bin/bash
set -e

# =============================================================================
# Ubuntu Desktop 24.04 Setup Script
# Christopher Kapic's dotfiles
#
# This script is idempotent and can be safely re-run.
# Run as your normal user (uses sudo for apt operations).
# =============================================================================

echo "============================================"
echo "  Ubuntu Desktop 24.04 Setup"
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

# --- Ensure the script is NOT run as root ---
if [ "$(id -u)" -eq 0 ]; then
  echo "Error: Do not run this script as root. Run as your normal user (sudo will be used where needed)."
  exit 1
fi

# =============================================================================
# Step 1: Install base packages
# =============================================================================
echo "--- Installing base packages ---"
sudo apt-get update -qq
sudo apt-get install -y git curl wget build-essential unzip stow zsh

# =============================================================================
# Step 2: Clone dotfiles
# =============================================================================
if ! [ -d "$HOME/dotfiles" ]; then
  echo "Cloning dotfiles..."
  git clone --depth=1 https://github.com/christopher-kapic/dotfiles.git "$HOME/dotfiles"
else
  echo "dotfiles already cloned."
fi

cd "$HOME/dotfiles"

# =============================================================================
# Step 3: Interactive stow package picker
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

# Selection state: all selected by default
selected=()
for i in "${!packages[@]}"; do selected+=("1"); done
cursor=0
total=${#packages[@]}

draw_menu() {
  if [ "$1" = "redraw" ]; then
    printf "\033[%dA" "$((total + 1))"
  fi
  printf "Select packages to stow (↑/k up, ↓/j down, space toggle, enter confirm):\r\n"
  for i in "${!packages[@]}"; do
    if [ "$i" -eq "$cursor" ]; then pointer=">"; else pointer=" "; fi
    if [ "${selected[$i]}" = "1" ]; then check="[x]"; else check="[ ]"; fi
    printf " %s %s %s\r\n" "$pointer" "$check" "${packages[$i]}"
  done
}

old_stty=$(stty -g)
stty raw -echo

draw_menu

while true; do
  char=$(dd bs=1 count=1 2>/dev/null)
  case "$char" in
    $'\x1b')
      dd bs=1 count=1 2>/dev/null  # [
      arrow=$(dd bs=1 count=1 2>/dev/null)
      case "$arrow" in
        A) ((cursor > 0)) && ((cursor--)) || true ;;
        B) ((cursor < total - 1)) && ((cursor++)) || true ;;
      esac
      ;;
    k) ((cursor > 0)) && ((cursor--)) || true ;;
    j) ((cursor < total - 1)) && ((cursor++)) || true ;;
    " ")
      if [ "${selected[$cursor]}" = "1" ]; then
        selected[$cursor]="0"
      else
        selected[$cursor]="1"
      fi
      ;;
    $'\r') break ;;  # Enter (carriage return in raw mode)
  esac
  draw_menu "redraw"
done

stty "$old_stty"
echo ""

# Ensure ~/.local/bin exists as a real directory so stow symlinks individual scripts
mkdir -p "$HOME/.local/bin"

# Stow selected packages (--restow for idempotency)
stowed_zsh=false
for i in "${!packages[@]}"; do
  if [ "${selected[$i]}" = "1" ]; then
    echo "Stowing ${packages[$i]}..."
    stow --restow --target="$HOME" "${packages[$i]}"
    if [ "${packages[$i]}" = "zsh" ]; then stowed_zsh=true; fi
  fi
done

# Copy zshrc template if zsh was stowed and ~/.zshrc doesn't exist
if $stowed_zsh && ! [ -f "$HOME/.zshrc" ]; then
  echo "Copying zshrc template to ~/.zshrc (edit for machine-specific config)"
  cp "$HOME/dotfiles/templates/zshrc" "$HOME/.zshrc"
elif $stowed_zsh && [ -f "$HOME/.zshrc" ]; then
  echo "~/.zshrc already exists, skipping template copy"
fi

# =============================================================================
# Step 4: Generate git user config
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
# Step 5: Install starship prompt
# =============================================================================
if ! command -v starship &> /dev/null; then
  echo "Installing starship..."
  curl -sS https://starship.rs/install.sh | sh -s -- --yes
else
  echo "starship already installed."
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
# =============================================================================
# Check the passwd entry rather than $SHELL, which stays stale until re-login.
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
# =============================================================================
# Check ~/.cargo directly: it may not be on PATH in this non-interactive shell.
if ! [ -x "$HOME/.cargo/bin/rustc" ]; then
  echo "Installing Rust..."
  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
else
  echo "Rust already installed: $("$HOME/.cargo/bin/rustc" --version)"
fi
source "$HOME/.cargo/env"

# =============================================================================
# Step 9: Install Neovim (latest from GitHub releases)
# =============================================================================
neovim_ok=
if command -v nvim &> /dev/null; then
  nvim_version=$(nvim --version 2>/dev/null | head -1 | sed -n 's/.*v\([0-9]*\)\.\([0-9]*\)\.\([0-9]*\).*/\1 \2 \3/p')
  read -r maj min pat <<< "$nvim_version"
  vnum=$((maj*10000 + min*100 + pat))
  if [ -n "$vnum" ] && [ "$vnum" -ge 1100 ]; then
    neovim_ok=1
    echo "Neovim already installed: $(nvim --version | head -1)"
  fi
fi
if [ -z "$neovim_ok" ]; then
  echo "Installing latest Neovim..."
  NVIM_LATEST=$(curl -s https://api.github.com/repos/neovim/neovim/releases/latest | grep '"tag_name"' | sed -E 's/.*"([^"]+)".*/\1/')
  NVIM_URL="https://github.com/neovim/neovim/releases/download/${NVIM_LATEST}/nvim-linux-x86_64.tar.gz"
  curl -Lo /tmp/nvim.tar.gz "$NVIM_URL"
  sudo tar -xzf /tmp/nvim.tar.gz -C /opt/
  rm -f /tmp/nvim.tar.gz
  sudo ln -sf /opt/nvim-linux-x86_64/bin/nvim /usr/local/bin/nvim
  echo "Neovim $(nvim --version | head -1) installed."
fi

# =============================================================================
# Step 10: Install LunaVim
# https://github.com/christopher-kapic/LunaVim
# The executable is still `lvim` and the config still lives in ~/.config/lvim.
# =============================================================================
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

opt_packages=("tmux" "ffmpeg" "gh" "htop" "jq" "lazygit" "opencode" "claude-code" "openssh-server" "netbird")

# Selection state: all deselected by default
opt_selected=()
for i in "${!opt_packages[@]}"; do opt_selected+=("0"); done
opt_cursor=0
opt_total=${#opt_packages[@]}

draw_opt_menu() {
  if [ "$1" = "redraw" ]; then
    printf "\033[%dA" "$((opt_total + 1))"
  fi
  printf "Select optional packages to install (↑/k up, ↓/j down, space toggle, enter confirm):\r\n"
  for i in "${!opt_packages[@]}"; do
    if [ "$i" -eq "$opt_cursor" ]; then pointer=">"; else pointer=" "; fi
    if [ "${opt_selected[$i]}" = "1" ]; then check="[x]"; else check="[ ]"; fi
    printf " %s %s %s\r\n" "$pointer" "$check" "${opt_packages[$i]}"
  done
}

old_stty2=$(stty -g)
stty raw -echo

draw_opt_menu

while true; do
  char=$(dd bs=1 count=1 2>/dev/null)
  case "$char" in
    $'\x1b')
      dd bs=1 count=1 2>/dev/null
      arrow=$(dd bs=1 count=1 2>/dev/null)
      case "$arrow" in
        A) ((opt_cursor > 0)) && ((opt_cursor--)) || true ;;
        B) ((opt_cursor < opt_total - 1)) && ((opt_cursor++)) || true ;;
      esac
      ;;
    k) ((opt_cursor > 0)) && ((opt_cursor--)) || true ;;
    j) ((opt_cursor < opt_total - 1)) && ((opt_cursor++)) || true ;;
    " ")
      if [ "${opt_selected[$opt_cursor]}" = "1" ]; then
        opt_selected[$opt_cursor]="0"
      else
        opt_selected[$opt_cursor]="1"
      fi
      ;;
    $'\r') break ;;
  esac
  draw_opt_menu "redraw"
done

stty "$old_stty2"
echo ""

# Install selected optional packages
apt_pkgs=()
install_gh=false
install_lazygit=false
install_openssh=false
install_netbird=false

for i in "${!opt_packages[@]}"; do
  if [ "${opt_selected[$i]}" = "1" ]; then
    case "${opt_packages[$i]}" in
      gh)          install_gh=true ;;
      lazygit)     install_lazygit=true ;;
      openssh-server) install_openssh=true ;;
      netbird)     install_netbird=true ;;
      opencode)
        if [ -x "$HOME/.opencode/bin/opencode" ] || command -v opencode &> /dev/null; then
          echo "OpenCode already installed."
        else
          echo "Installing OpenCode..."; curl -fsSL https://opencode.ai/install | bash
        fi
        ;;
      claude-code)
        if [ -x "$HOME/.local/bin/claude" ] || command -v claude &> /dev/null; then
          echo "Claude Code already installed."
        else
          echo "Installing Claude Code..."; curl -fsSL https://claude.ai/install.sh | bash
        fi
        ;;
      *)           apt_pkgs+=("${opt_packages[$i]}") ;;
    esac
  fi
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
    curl -Lo /tmp/lazygit.tar.gz "https://github.com/jesseduffield/lazygit/releases/latest/download/lazygit_${LAZYGIT_VERSION}_Linux_x86_64.tar.gz"
    tar xf /tmp/lazygit.tar.gz -C /tmp lazygit
    sudo install /tmp/lazygit /usr/local/bin
    rm -f /tmp/lazygit /tmp/lazygit.tar.gz
  else
    echo "lazygit already installed."
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
echo "  - Zsh: default shell (log out and back in if just changed)"
echo "  - Neovim: latest version installed"
echo "  - LunaVim: installed"
echo "  - Node.js: installed via fnm"
echo "  - Rust: installed via rustup"
echo "  - Fonts: MesloLGS NF installed"

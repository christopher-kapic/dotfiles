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
# Step 4: Install powerlevel10k
# =============================================================================
if ! [ -d "$HOME/.powerlevel10k" ]; then
  echo "Installing powerlevel10k..."
  git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$HOME/.powerlevel10k"
else
  echo "powerlevel10k already installed."
fi

# =============================================================================
# Step 5: Install fonts
# =============================================================================
echo "--- Installing fonts ---"
mkdir -p "$HOME/.local/share/fonts"
cp "$HOME/dotfiles/fonts/.config/fonts/"* "$HOME/.local/share/fonts" 2>/dev/null || true
fc-cache -f "$HOME/.local/share/fonts" 2>/dev/null || true

# =============================================================================
# Step 6: Set zsh as default shell
# =============================================================================
if [ "$(basename "$SHELL")" != "zsh" ]; then
  echo "Setting zsh as default shell..."
  chsh -s "$(which zsh)"
else
  echo "zsh is already the default shell."
fi

# =============================================================================
# Step 7: Install nvm and Node.js
# =============================================================================
export NVM_DIR="$HOME/.nvm"
if ! [ -s "$NVM_DIR/nvm.sh" ]; then
  echo "Installing nvm..."
  curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.4/install.sh | bash
fi
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

if ! command -v node &> /dev/null; then
  echo "Installing Node.js v25..."
  nvm install 25
else
  echo "Node.js already installed: $(node --version)"
fi

# =============================================================================
# Step 8: Install Rust
# =============================================================================
if ! command -v rustc &> /dev/null; then
  echo "Installing Rust..."
  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
  source "$HOME/.cargo/env"
else
  echo "Rust already installed: $(rustc --version)"
fi

# =============================================================================
# Step 9: Install Neovim (latest from GitHub releases)
# =============================================================================
neovim_ok=
if command -v nvim &> /dev/null; then
  nvim_version=$(nvim --version 2>/dev/null | head -1 | sed -n 's/.*v\([0-9]*\)\.\([0-9]*\)\.\([0-9]*\).*/\1 \2 \3/p')
  read -r maj min pat <<< "$nvim_version"
  vnum=$((maj*10000 + min*100 + pat))
  if [ -n "$vnum" ] && [ "$vnum" -ge 1105 ]; then
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
# Step 10: Install CKLunarVim
# =============================================================================
if ! command -v lvim &> /dev/null && ! [ -x "$HOME/.local/bin/lvim" ]; then
  echo "Installing CKLunarVim..."
  bash <(curl -s https://raw.githubusercontent.com/christopher-kapic/CKLunarVim/master/utils/installer/install.sh)
else
  echo "CKLunarVim already installed."
fi

# =============================================================================
# Step 11: Optional packages
# =============================================================================
echo ""
echo "--- Optional packages ---"

opt_packages=("tmux" "ffmpeg" "gh" "htop" "jq" "lazygit" "opencode" "claude-code")

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
npm_pkgs=()
install_gh=false
install_lazygit=false

for i in "${!opt_packages[@]}"; do
  if [ "${opt_selected[$i]}" = "1" ]; then
    case "${opt_packages[$i]}" in
      gh)          install_gh=true ;;
      lazygit)     install_lazygit=true ;;
      opencode)    npm_pkgs+=("opencode") ;;
      claude-code) npm_pkgs+=("@anthropic-ai/claude-code") ;;
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

if [ ${#npm_pkgs[@]} -gt 0 ]; then
  echo "Installing npm packages: ${npm_pkgs[*]}"
  npm install -g "${npm_pkgs[@]}"
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
echo "  - CKLunarVim: installed"
echo "  - Node.js: installed via nvm"
echo "  - Rust: installed via rustup"
echo "  - Fonts: MesloLGS NF installed"

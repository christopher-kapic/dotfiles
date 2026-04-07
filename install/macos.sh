#!/bin/bash
set -e

echo "Christopher Kapic's System Configuration"

if ! command -v brew &> /dev/null
then
  echo "homebrew could not be found - installing now..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

if ! xcode-select -p &> /dev/null; then
  echo "Installing Xcode Command Line Tools (needed for C compiler / plugin builds; this may take a while)"
  xcode-select --install
fi

if ! command -v stow &> /dev/null
then
  echo "stow could not be found - installing now..."
  brew install stow
fi

if ! [ -d "$HOME/dotfiles" ]; then
  git clone --depth=1 https://github.com/christopher-kapic/dotfiles.git $HOME/dotfiles
fi

cd "$HOME/dotfiles"

# --- Interactive stow package picker ---
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
  # Move cursor up to redraw in place
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

# Save terminal settings and enable raw input
old_stty=$(stty -g)
stty raw -echo

draw_menu

while true; do
  char=$(dd bs=1 count=1 2>/dev/null)
  case "$char" in
    $'\x1b')
      # Read escape sequence
      dd bs=1 count=1 2>/dev/null  # [
      arrow=$(dd bs=1 count=1 2>/dev/null)
      case "$arrow" in
        A) ((cursor > 0)) && ((cursor--)) || true ;;  # Up
        B) ((cursor < total - 1)) && ((cursor++)) || true ;;  # Down
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

# Restore terminal
stty "$old_stty"
echo ""

# Ensure ~/.local/bin exists as a real directory so stow symlinks individual scripts
mkdir -p "$HOME/.local/bin"

# Stow selected packages
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
# Git user configuration
# =============================================================================
echo ""
echo "--- Git User Configuration ---"
read -rp "Enter your Git name (or press Enter to skip): " GIT_NAME
if [ -n "$GIT_NAME" ]; then
  read -rp "Enter your Git email (or press Enter to skip): " GIT_EMAIL
  git config --file "$HOME/.gitconfig" user.name "$GIT_NAME"
  [ -n "$GIT_EMAIL" ] && git config --file "$HOME/.gitconfig" user.email "$GIT_EMAIL"
  echo "Git user configured."
else
  echo "Skipping Git user configuration."
fi

if ! [ -d "$HOME/.powerlevel10k" ]; then
  git clone --depth=1 https://github.com/romkatv/powerlevel10k.git $HOME/.powerlevel10k
fi

mkdir -p "$HOME/Library/Fonts"
cp "$HOME/dotfiles/fonts/.config/fonts/"* "$HOME/Library/Fonts" 2>/dev/null || true

# Install nvm
if ! command -v nvm &> /dev/null
then
  echo "nvm could not be found - installing now"
  curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.4/install.sh | bash
  export NVM_DIR="$HOME/.nvm"
  [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
  [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion
fi

if ! command -v node &> /dev/null
then
  echo "node could not be found - installing v25 now"
  nvm install 25
fi

if ! command -v gsed &> /dev/null
then
  echo "gsed (gnu-sed) could not be found - installing now..."
  brew install gsed
fi

if ! command -v rustc &> /dev/null
then
  echo "rust could not be found - installing now..."
  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
  source "$HOME/.cargo/env"
fi

# Neovim 0.11.5+ required for CKLunarVim
neovim_ok=
if command -v nvim &> /dev/null; then
  nvim_version=$(nvim --version 2>/dev/null | head -1 | sed -n 's/.*v\([0-9]*\)\.\([0-9]*\)\.\([0-9]*\).*/\1 \2 \3/p')
  read -r maj min pat <<< "$nvim_version"
  vnum=$((maj*10000 + min*100 + pat))
  if [ -n "$vnum" ] && [ "$vnum" -ge 1105 ]; then
    neovim_ok=1
  fi
fi
if [ -z "$neovim_ok" ]; then
  echo "neovim could not be found or is older than 0.11.5 - installing now..."
  brew install neovim
fi

if ! command -v lvim &> /dev/null && ! [ -x "$HOME/.local/bin/lvim" ]; then
  echo "CKLunarVim (lvim) could not be found - installing now..."
  bash <(curl -s https://raw.githubusercontent.com/christopher-kapic/CKLunarVim/master/utils/installer/install.sh)
fi

# =============================================================================
# Optional packages
# =============================================================================
echo ""
echo "--- Optional packages ---"

opt_packages=("tmux" "ffmpeg" "gh" "htop" "jq" "lazygit" "wget" "opencode" "claude-code")

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
brew_pkgs=()
for i in "${!opt_packages[@]}"; do
  if [ "${opt_selected[$i]}" = "1" ]; then
    case "${opt_packages[$i]}" in
      claude-code) echo "Installing Claude Code..."; curl -fsSL https://claude.ai/install.sh | bash ;;
      *)           brew_pkgs+=("${opt_packages[$i]}") ;;
    esac
  fi
done

if [ ${#brew_pkgs[@]} -gt 0 ]; then
  echo "Installing brew packages: ${brew_pkgs[*]}"
  brew install "${brew_pkgs[@]}"
fi

# =============================================================================
# Optional casks (GUI applications)
# =============================================================================
echo ""
echo "--- Optional applications (casks) ---"

cask_packages=("pika" "maccy" "monitorcontrol" "bettermouse" "brave-browser" "cyberduck" "firefox" "google-chrome" "rectangle")

cask_selected=()
for i in "${!cask_packages[@]}"; do cask_selected+=("0"); done
cask_cursor=0
cask_total=${#cask_packages[@]}

draw_cask_menu() {
  if [ "$1" = "redraw" ]; then
    printf "\033[%dA" "$((cask_total + 1))"
  fi
  printf "Select applications to install (↑/k up, ↓/j down, space toggle, enter confirm):\r\n"
  for i in "${!cask_packages[@]}"; do
    if [ "$i" -eq "$cask_cursor" ]; then pointer=">"; else pointer=" "; fi
    if [ "${cask_selected[$i]}" = "1" ]; then check="[x]"; else check="[ ]"; fi
    printf " %s %s %s\r\n" "$pointer" "$check" "${cask_packages[$i]}"
  done
}

old_stty3=$(stty -g)
stty raw -echo

draw_cask_menu

while true; do
  char=$(dd bs=1 count=1 2>/dev/null)
  case "$char" in
    $'\x1b')
      dd bs=1 count=1 2>/dev/null
      arrow=$(dd bs=1 count=1 2>/dev/null)
      case "$arrow" in
        A) ((cask_cursor > 0)) && ((cask_cursor--)) || true ;;
        B) ((cask_cursor < cask_total - 1)) && ((cask_cursor++)) || true ;;
      esac
      ;;
    k) ((cask_cursor > 0)) && ((cask_cursor--)) || true ;;
    j) ((cask_cursor < cask_total - 1)) && ((cask_cursor++)) || true ;;
    " ")
      if [ "${cask_selected[$cask_cursor]}" = "1" ]; then
        cask_selected[$cask_cursor]="0"
      else
        cask_selected[$cask_cursor]="1"
      fi
      ;;
    $'\r') break ;;
  esac
  draw_cask_menu "redraw"
done

stty "$old_stty3"
echo ""

casks_to_install=()
for i in "${!cask_packages[@]}"; do
  if [ "${cask_selected[$i]}" = "1" ]; then
    casks_to_install+=("${cask_packages[$i]}")
  fi
done

if [ ${#casks_to_install[@]} -gt 0 ]; then
  echo "Installing casks: ${casks_to_install[*]}"
  brew install --cask "${casks_to_install[@]}"
fi

echo "Configuring some MacOS settings..."
echo "Set dock to autohide with speed to 0.2s (1/2 of Doherty threshold)"
defaults write com.apple.dock autohide -bool true
defaults write com.apple.dock autohide-delay -float 0
defaults write com.apple.dock autohide-time-modifier -float 0.2

echo "Setting the dock to the left side of the screen (there is more horizontal than vertical real estate these days)"
defaults write com.apple.dock orientation left

echo "Setting the bottom right hot corner to show desktop"
defaults write com.apple.dock wvous-br-corner -int 4
defaults write com.apple.dock wvous-br-modifier -int 0

echo "Disable automatic space rearrangment"
defaults write com.apple.dock "mru-spaces" -bool "false"

defaults write com.apple.dock "expose-group-apps" -bool "true"
defaults write com.apple.dock "show-recents" -bool "false"
defaults write com.apple.dock "tilesize" -int "28"

killall Dock

echo "Configuring mouse settings"
# echo "Disable mouse acceleration"
# defaults write NSGlobalDomain com.apple.mouse.linear -bool "true"

# echo "Setting scroll direction natural off"
# defaults write -g com.apple.swipescrolldirection -bool false

echo "Set mouse speed (use BetterMouse for fine-grained control: https://better-mouse.com/ )"
defaults write NSGlobalDomain com.apple.mouse.scaling -float "0.5"

defaults write com.apple.Safari "ShowFullURLInSmartSearchField" -bool "true"

# Finder
echo "Configuring Finder settings"
defaults write com.apple.finder "ShowPathbar" -bool "true"
defaults write com.apple.finder "FXPreferredViewStyle" -string "Nlsv"
defaults write NSGlobalDomain "AppleShowAllExtensions" -bool "true"
defaults write com.apple.finder "_FXSortFoldersFirst" -bool "true"
defaults write NSGlobalDomain "NSToolbarTitleViewRolloverDelay" -float "0"
killall Finder

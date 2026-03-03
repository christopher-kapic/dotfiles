#!/bin/bash

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
skip_dirs=(".git" "templates" "fonts")

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
  echo "Select packages to stow (↑/k up, ↓/j down, space toggle, enter confirm):"
  for i in "${!packages[@]}"; do
    if [ "$i" -eq "$cursor" ]; then pointer=">"; else pointer=" "; fi
    if [ "${selected[$i]}" = "1" ]; then check="[x]"; else check="[ ]"; fi
    echo " $pointer $check ${packages[$i]}"
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
        A) ((cursor > 0)) && ((cursor--)) ;;  # Up
        B) ((cursor < total - 1)) && ((cursor++)) ;;  # Down
      esac
      ;;
    k) ((cursor > 0)) && ((cursor--)) ;;
    j) ((cursor < total - 1)) && ((cursor++)) ;;
    " ")
      if [ "${selected[$cursor]}" = "1" ]; then
        selected[$cursor]="0"
      else
        selected[$cursor]="1"
      fi
      ;;
    "") break ;;  # Enter
  esac
  draw_menu "redraw"
done

# Restore terminal
stty "$old_stty"
echo ""

# Stow selected packages
stowed_zsh=false
for i in "${!packages[@]}"; do
  if [ "${selected[$i]}" = "1" ]; then
    echo "Stowing ${packages[$i]}..."
    stow --target="$HOME" "${packages[$i]}"
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

if ! [ -d "$HOME/.powerlevel10k" ]; then
  git clone --depth=1 https://github.com/romkatv/powerlevel10k.git $HOME/.powerlevel10k
fi

cp $HOME/dotfiles/fonts/* $HOME/Library/Fonts

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
  echo "node could not be found - installing v20 now"
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
  bash <(curl -s https://sh.rustup.rs)
  source $HOME/.cargo/env
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

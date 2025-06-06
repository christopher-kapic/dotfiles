#!/bin/bash

echo "Christopher Kapic's System Configuration"

if ! command -v brew &> /dev/null
then
  echo "homebrew could not be found - installing now..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

if ! command -v stow &> /dev/null
then
  echo "stow could not be found - installing now..."
  brew install stow
fi

if ! [ -d "$HOME/dotfiles" ]; then
  git clone --depth=1 https://github.com/christopher-kapic/dotfiles.git $HOME/dotfiles
fi

stow --target=${HOME} $HOME/dotfiles/*/

if ! [ -d "$HOME/powerlevel10k" ]; then
  git clone --depth=1 https://github.com/romkatv/powerlevel10k.git $HOME/powerlevel10k
fi

cp $HOME/dotfiles/fonts/* $HOME/Library/Fonts

# Install nvm
if ! command -v nvm &> /dev/null
then
  echo "nvm could not be found - installing now"
  curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | bash
  export NVM_DIR="$HOME/.nvm"
  [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
  [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion
fi

if ! command -v node &> /dev/null
then
  echo "node could not be found - installing v20 now"
  nvm install 20
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


echo "Installing xcode tools (this will take a while)"
xcode-select --install

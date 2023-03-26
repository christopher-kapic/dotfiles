#!/bin/bash

echo "Installing MacOS dotfiles..."


if ! [ -d "~/.config" ]; then
  git clone --depth=1 https://github.com/christopher-kapic/dotfiles.git ~/.config
fi

if ! [ -e "~/.zshrc" ]; then
  cp ~/.config/zsh/.zshrc ~/.zshrc
fi


if ! [ -d "~/powerlevel10k" ]; then
  git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ~/powerlevel10k
fi

cp $HOME/.config/fonts/* $HOME/Library/Fonts

# Install nvm
if ! command -v nvm &> /dev/null
then
  echo "nvm could not be found - installing now"
  curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.1/install.sh | bash
  export NVM_DIR="$HOME/.nvm"
  [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
  [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion
fi

if ! command -v node &> /dev/null
then
  echo "nvm could not be found - installing now"
  nvm install 18
fi

if ! command -v brew &> /dev/null
then
  echo "homebrew could not be found - installing now..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

if ! command -v figlet &> /dev/null
then
  echo "figlet could not be found - installing now..."
  brew install figlet
fi

if ! command -v lolcat &> /dev/null
then
  echo "lolcat could not be found - installing now..."
  brew install lolcat
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

if ! command -v lvim &> /dev/null
then
  bash <(curl -s https://raw.githubusercontent.com/lunarvim/lunarvim/master/utils/installer/install.sh)
fi

figlet "Configuring some settings..." | lolcat
echo "Set dock to autohide with speed to 0.2s (1/2 of Doherty threshold)"
defaults write com.apple.dock autohide -bool true
defaults write com.apple.dock autohide-delay -float 0
defaults write com.apple.dock autohide-time-modifier -float 0.2
killall Dock

echo "Setting the dock to the left side of the screen (there is more horizontal than vertical real estate these days)"
defaults write com.apple.dock orientation left; killall Dock

echo "Setting the bottom right hot corner to show desktop"
defaults write com.apple.dock wvous-br-corner -int 4
defaults write com.apple.dock wvous-br-modifier -int 0
killall Dock

echo "Setting scroll direction natural off"
defaults write -g com.apple.swipescrolldirection -bool false

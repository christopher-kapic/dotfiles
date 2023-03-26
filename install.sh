#!/bin/bash

echo "Installing MacOS dotfiles..."

git clone --depth=1 https://github.com/christopher-kapic/dotfiles.git ~/.config
cp ~/.config/zsh/.zshrc ~/.zshrc

git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ~/powerlevel10k

cp $HOME/.config/fonts/* $HOME/Library/Fonts

# Install nvm
if ! command -v nvm &> /dev/null
then
  curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.1/install.sh | bash
  export NVM_DIR="$HOME/.nvm"
  [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
  [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion
fi

if ! command -v node &> /dev/null
then
  # Install NodeJS 16
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

echo "Configuring some settings..."
echo "Set dock speed to 0.2s (1/2 of Doherty threshold)"
defaults write com.apple.dock autohide-delay -float 0; defaults write com.apple.dock autohide-time-modifier -float 0.2;killall Dock

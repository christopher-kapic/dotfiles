#!/bin/bash

git clone --depth=1 https://github.com/christopher-kapic/dotfiles.git ~/.config
cp ~/.config/zsh/.zshrc ~/.zshrc

git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ~/powerlevel10k
echo 'source ~/powerlevel10k/powerlevel10k.zsh-theme' >> ~/.zshrc

cp ~/.config/fonts/* ~/Library/Fonts

# Install nvm
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.1/install.sh | bash

read -r -p "Install Homebrew? [y/N] " input

case $input in
      [yY][eE][sS]|[yY])
            /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
            ;;
      [nN][oO]|[nN])
            exit 1
            ;;
      *)
            exit 1
            ;;
esac
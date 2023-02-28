#!/bin/bash

echo "Installing MacOS dotfiles..."

git clone --depth=1 https://github.com/christopher-kapic/dotfiles.git ~/.config
cp ~/.config/zsh/.zshrc ~/.zshrc

git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ~/powerlevel10k
echo 'source ~/powerlevel10k/powerlevel10k.zsh-theme' >> ~/.zshrc

cp $HOME/.config/fonts/* $HOME/Library/Fonts

# Install nvm
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.1/install.sh | bash
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion

# Install NodeJS 16
nvm install 16

# read -r -p "Install Homebrew? [y/N] " input
# case $input in
#       [yY][eE][sS]|[yY])
#             /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
#             ;;
#       [nN][oO]|[nN])
#             ;;
#       *)
#             ;;
# esac

# install Rust for LunarVim
# Official:
# curl https://sh.rustup.rs -sSf | sh

bash <(curl -s https://sh.rustup.rs)
source $HOME/.cargo/env

# Install LunarVim
# Official:
# bash <(curl -s https://raw.githubusercontent.com/lunarvim/lunarvim/master/utils/installer/install.sh)

bash <(curl -s https://raw.githubusercontent.com/lunarvim/lunarvim/master/utils/installer/install.sh)
# curl https://raw.githubusercontent.com/lunarvim/lunarvim/master/utils/installer/install.sh | bash
# curl -o- https://raw.githubusercontent.com/lunarvim/lunarvim/master/utils/installer/install.sh | bash
# bash <(curl -s https://raw.githubusercontent.com/lunarvim/lunarvim/master/utils/installer/install.sh)
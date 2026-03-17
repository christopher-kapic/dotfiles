# Install Scripts

Installation scripts for bootstrapping new machines with Christopher Kapic's dotfiles and tools.

## Available Scripts

### macOS

Full macOS development environment setup: Homebrew, stow, dotfiles, nvm, Node.js, Rust, Neovim, CKLunarVim, and macOS system preferences (dock, Finder, mouse).

```bash
bash <(curl -s https://raw.githubusercontent.com/christopher-kapic/dotfiles/master/install/macos.sh)
```

Or if you already have the repo cloned:

```bash
bash ~/dotfiles/install/macos.sh
```

### Ubuntu Server 24.04

Interactive server hardening and setup script. Creates a new user, configures SSH (key-based auth only, no root login), sets up UFW firewall and fail2ban, installs latest Neovim from GitHub, installs CKLunarVim, and sets zsh as the default shell. Must be run as root.

```bash
bash <(curl -s https://raw.githubusercontent.com/christopher-kapic/dotfiles/master/install/ubuntu-server-24.04.sh)
```

Or if you already have the repo cloned:

```bash
sudo bash ~/dotfiles/install/ubuntu-server-24.04.sh
```

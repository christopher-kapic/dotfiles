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

### Ubuntu Desktop 24.04

Idempotent desktop setup script. Installs dev tools (stow, nvm, Node.js, Rust, Neovim, CKLunarVim), stows dotfiles with an interactive picker, installs fonts, and sets zsh as the default shell. Run as your normal user (not root).

```bash
bash <(curl -s https://raw.githubusercontent.com/christopher-kapic/dotfiles/master/install/ubuntu-desktop-24.04.sh)
```

Or if you already have the repo cloned:

```bash
bash ~/dotfiles/install/ubuntu-desktop-24.04.sh
```

### Ubuntu Server 24.04

Interactive server hardening and setup script. Creates a new user, configures SSH (key-based auth only, no root login), sets up UFW firewall and fail2ban, installs latest Neovim from GitHub, installs CKLunarVim, and sets zsh as the default shell. Must be run as root.

The script is idempotent: re-run it to add additional users. System-level setup (SSH hardening, UFW, fail2ban, Neovim) is skipped on subsequent runs, and only per-user setup (dotfiles, nvm/Node, Rust, CKLunarVim) runs for the new user.

```bash
bash <(curl -s https://raw.githubusercontent.com/christopher-kapic/dotfiles/master/install/ubuntu-server-24.04.sh)
```

Or if you already have the repo cloned:

```bash
sudo bash ~/dotfiles/install/ubuntu-server-24.04.sh
```

#### `--workstation` flag

Pass `--workstation` to also install CLI tools useful for SSH-based development: `tmux`, `htop`, `jq`, `gh` (GitHub CLI), `lazygit`, `opencode`, and `claude-code`. The apt/binary tools are installed system-wide; `opencode` and `claude-code` are installed into the new user's home directory.

```bash
bash <(curl -s https://raw.githubusercontent.com/christopher-kapic/dotfiles/master/install/ubuntu-server-24.04.sh) --workstation
```

Or locally:

```bash
sudo bash ~/dotfiles/install/ubuntu-server-24.04.sh --workstation
```

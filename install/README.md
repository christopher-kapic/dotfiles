# Install Scripts

Installation scripts for bootstrapping new machines with Christopher Kapic's dotfiles and tools.

## Available Scripts

### macOS

Full macOS development environment setup: Homebrew, stow, dotfiles, fnm, Node.js, Rust, Neovim, LunaVim, and macOS system preferences (dock, Finder, mouse).

The optional applications menu includes `alacritty`, which is built from source (`make app` in a temporary clone under `/tmp`, removed afterwards). `Alacritty.app` is copied to `/Applications` and the `alacritty` binary to `~/.local/bin/alacritty`.

```bash
bash <(curl -s https://raw.githubusercontent.com/christopher-kapic/dotfiles/master/install/macos.sh)
```

Or if you already have the repo cloned:

```bash
bash ~/dotfiles/install/macos.sh
```

### Ubuntu Desktop 26.04

Idempotent desktop setup script for Ubuntu 26.04 LTS. Same flow as the 24.04 script, but starship comes from apt, Neovim is installed from the latest GitHub release with [`nvim-update`](#nvim-update), and the release-download installs (lazygit) handle both x86_64 and arm64. Run as your normal user (not root).

The optional packages menu is set up for using an old laptop as a headless box you SSH into over NetBird:

- `openssh-server` enables the SSH service and optionally authorizes a public key. Once a key is authorized, it offers to switch SSH to key-only auth (no passwords, no root login) through `/etc/ssh/sshd_config.d/00-dotfiles-hardening.conf`.
- `netbird` installs NetBird and, if the machine isn't connected yet, optionally connects it with a setup key.
- `no-sleep (laptop server)` makes the machine ignore lid close and masks the suspend/hibernate targets, so it stays reachable with the lid shut. The lid setting takes effect after a reboot.

```bash
bash <(curl -s https://raw.githubusercontent.com/christopher-kapic/dotfiles/master/install/ubuntu-desktop-26.04.sh)
```

Or if you already have the repo cloned:

```bash
bash ~/dotfiles/install/ubuntu-desktop-26.04.sh
```

### Ubuntu Server 26.04

Server setup script for Ubuntu 26.04 LTS. Must be run as root. Same flow and `--workstation` flag as the 24.04 script (see below), with these changes:

- starship is installed from apt, and Neovim is installed for the new user from the latest GitHub release with [`nvim-update`](#nvim-update).
- SSH hardening goes in a drop-in file (`00-dotfiles-hardening.conf`) that takes priority over cloud-init's `50-cloud-init.conf`, and sshd validates it with `sshd -t` before restarting.
- On a re-run for an existing user who already has authorized keys, pasting another key is optional.
- It asks whether the machine is a laptop and, if so, disables sleep and lid-close suspend.
- NetBird offers to connect whenever the machine isn't connected, including when NetBird was already installed.

```bash
bash <(curl -s https://raw.githubusercontent.com/christopher-kapic/dotfiles/master/install/ubuntu-server-26.04.sh)
```

Or if you already have the repo cloned:

```bash
sudo bash ~/dotfiles/install/ubuntu-server-26.04.sh [--workstation]
```

### Ubuntu Desktop 24.04

Idempotent desktop setup script. Installs dev tools (stow, fnm, Node.js, Rust, Neovim, LunaVim), stows dotfiles with an interactive picker, installs fonts, and sets zsh as the default shell. Run as your normal user (not root).

The optional packages menu includes `openssh-server` (enables the SSH service and optionally authorizes a public key) and `netbird` (optionally connects with a setup key).

```bash
bash <(curl -s https://raw.githubusercontent.com/christopher-kapic/dotfiles/master/install/ubuntu-desktop-24.04.sh)
```

Or if you already have the repo cloned:

```bash
bash ~/dotfiles/install/ubuntu-desktop-24.04.sh
```

### Ubuntu Server 24.04

Interactive server hardening and setup script. Creates a new user, configures SSH (key-based auth only, no root login), sets up UFW firewall and fail2ban, installs latest Neovim from GitHub, installs LunaVim, and sets zsh as the default shell. Optionally installs NetBird at the end. Must be run as root.

The SSH key prompt only accepts a valid public key; pasting a private key is rejected.

The script is idempotent: re-run it to add additional users. System-level setup (UFW, fail2ban, Neovim) is skipped on subsequent runs, SSH hardening is re-applied (it always produces the same config), and only per-user setup (dotfiles, fnm/Node, Rust, LunaVim) runs for the new user. If the user already has an authorized key, pasting another one is optional.

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

### `nvim-update`

`scripts/.local/bin/nvim-update` (stowed onto your PATH as `nvim-update`) installs or upgrades Neovim from the latest GitHub release, because apt often lags behind. It works on Linux and macOS, on x86_64 and arm64.

- The release tarball is a whole tree (`bin/nvim`, `lib/nvim` parsers, `share/nvim/runtime`), not a single binary. The script extracts it to `~/.nvim`, which `~/.config/shell/path` already puts first on PATH, and symlinks `~/.local/bin/nvim` to `~/.nvim/bin/nvim`. Anything else at `~/.local/bin/nvim` is replaced.
- The tarball's sha256 is checked against the digest the GitHub API lists for it. The new version is extracted to a staging folder and test-run before the old install is removed.
- If the installed version is already the latest, the script does nothing. Pass `--force` to reinstall.

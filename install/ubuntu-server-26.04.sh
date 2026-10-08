#!/bin/bash
set -e

# =============================================================================
# Ubuntu Server 26.04 Setup Script
# Christopher Kapic's dotfiles
#
# This script is idempotent and can be re-run to add more users. System-level
# setup (UFW, fail2ban) is skipped once configured; SSH hardening and package
# installs converge to the same state; per-user setup runs for each new user.
#
# Run as root on Ubuntu Server 26.04. It will:
#   1. Create a new user with sudo access
#   2. Configure SSH (key-based auth only, no root login)
#   3. Set up UFW firewall
#   4. Set up fail2ban for SSH brute-force protection
#   5. Install zsh and starship from apt
#   6. Clone dotfiles and set up stow and zshrc for the new user
#   7. Install fnm/Node.js, Rust, Neovim (latest GitHub release) and LunaVim
#      for the new user
#   8. Optionally disable sleep / lid-close suspend (laptops used as servers)
#   9. Optionally install and connect NetBird
#
# Flags:
#   --workstation    Also install CLI tools useful for SSH-based development
#                    (tmux, gh, lazygit, htop, jq, opencode, claude-code).
# =============================================================================

# --- Parse flags ---
WORKSTATION=false
for arg in "$@"; do
  case "$arg" in
    --workstation) WORKSTATION=true ;;
    *) echo "Unknown argument: $arg"; exit 1 ;;
  esac
done

# --- Ensure the script is run as root ---
if [ "$(id -u)" -ne 0 ]; then
  echo "Error: This script must be run as root."
  exit 1
fi

case "$(uname -m)" in
  x86_64)        ARCH=x86_64 ;;
  aarch64|arm64) ARCH=arm64 ;;
  *) echo "Error: Unsupported architecture: $(uname -m)"; exit 1 ;;
esac

# Read one SSH public key from the terminal into SSH_PUBLIC_KEY, re-prompting
# until it's valid. Private keys are rejected, and any extra pasted lines (e.g.
# the body of a multi-line private key) are discarded so they can't leak into
# later prompts. Pass "optional" to allow an empty answer.
SSH_PUBKEY_REGEX='^(ssh-ed25519|ssh-rsa|ecdsa-sha2-nistp(256|384|521)|sk-ssh-ed25519@openssh\.com|sk-ecdsa-sha2-nistp256@openssh\.com) [A-Za-z0-9+/]+=*( .*)?$'
read_ssh_public_key() {
  while true; do
    if ! read -rp "> " SSH_PUBLIC_KEY && [ -z "$SSH_PUBLIC_KEY" ]; then
      echo "Error: No input received."
      exit 1
    fi
    while read -r -t 0.2 _; do :; done
    if [ -z "$SSH_PUBLIC_KEY" ]; then
      [ "$1" = "optional" ] && return 0
      echo "Error: No SSH key provided. Key-based authentication is required."
    elif [[ "$SSH_PUBLIC_KEY" == *"PRIVATE KEY"* || "$SSH_PUBLIC_KEY" == PuTTY-User-Key-File-* ]]; then
      echo "Error: That is a PRIVATE key - never paste it anywhere. Paste the .pub file instead (e.g. ~/.ssh/id_ed25519.pub)."
    elif [[ "$SSH_PUBLIC_KEY" =~ $SSH_PUBKEY_REGEX ]] && ssh-keygen -l -f /dev/stdin <<< "$SSH_PUBLIC_KEY" &> /dev/null; then
      return 0
    else
      echo "Error: Not a valid SSH public key (expected e.g. 'ssh-ed25519 AAAA... comment'). Try again:"
    fi
    SSH_PUBLIC_KEY=
  done
}

echo "============================================"
echo "  Ubuntu Server 26.04 Setup"
echo "  Christopher Kapic's dotfiles"
echo "============================================"
echo ""

# =============================================================================
# Step 1: Create a new user with sudo access
# =============================================================================
while true; do
  read -rp "Enter the username for the new user: " NEW_USER
  [[ "$NEW_USER" =~ ^[a-z_][a-z0-9_-]*$ ]] && break
  echo "Error: Usernames must start with a lowercase letter or _ and contain only a-z, 0-9, _ and -."
done

if id "$NEW_USER" &>/dev/null; then
  echo "User '$NEW_USER' already exists, skipping creation."
else
  echo "Creating user '$NEW_USER'..."
  adduser --gecos "" "$NEW_USER"
  usermod -aG sudo "$NEW_USER"
  echo "User '$NEW_USER' created and added to the sudo group."
fi
USER_HOME=$(getent passwd "$NEW_USER" | cut -d: -f6)

# =============================================================================
# Step 2: Install base packages
# =============================================================================
echo ""
echo "--- Installing base packages ---"
apt-get update -qq
apt-get install -y openssh-server ufw fail2ban python3-systemd zsh git curl wget build-essential unzip stow

# Starship prompt (packaged in the Ubuntu archive since 25.04)
apt-get install -y starship

# =============================================================================
# Step 3: Set up SSH key-based authentication
# Disables password authentication and root login for security.
# =============================================================================
echo ""
echo "--- SSH Key Setup ---"
mkdir -p "$USER_HOME/.ssh"
touch "$USER_HOME/.ssh/authorized_keys"

# A key is only required if the user doesn't have one yet
if [ -s "$USER_HOME/.ssh/authorized_keys" ]; then
  echo "'$NEW_USER' already has authorized SSH keys. Paste another public key to add it, or press Enter to skip:"
  read_ssh_public_key optional
else
  echo "Paste the SSH public key for '$NEW_USER' (one line, then press Enter):"
  read_ssh_public_key
fi

if [ -n "$SSH_PUBLIC_KEY" ]; then
  if grep -qxF "$SSH_PUBLIC_KEY" "$USER_HOME/.ssh/authorized_keys"; then
    echo "SSH public key already present for '$NEW_USER'."
  else
    echo "$SSH_PUBLIC_KEY" >> "$USER_HOME/.ssh/authorized_keys"
    echo "SSH public key installed for '$NEW_USER'."
  fi
fi
chmod 700 "$USER_HOME/.ssh"
chmod 600 "$USER_HOME/.ssh/authorized_keys"
chown -R "$NEW_USER:$NEW_USER" "$USER_HOME/.ssh"

# Harden the SSH daemon with a drop-in rather than editing sshd_config: sshd
# uses the first value it sees and the sshd_config.d includes come first, so
# 00- wins over e.g. 50-cloud-init.conf (which enables password auth on cloud
# images). The config is validated before sshd is restarted.
echo "Configuring SSH daemon..."
SSHD_HARDENING=/etc/ssh/sshd_config.d/00-dotfiles-hardening.conf
cat > "$SSHD_HARDENING" << 'EOF'
PermitRootLogin no
PasswordAuthentication no
KbdInteractiveAuthentication no
EOF
if ! sshd -t; then
  rm -f "$SSHD_HARDENING"
  echo "Error: sshd rejected the hardening config; SSH settings left unchanged."
  exit 1
fi
systemctl enable ssh
systemctl try-restart ssh
echo "SSH configured: root login disabled, password authentication disabled."

# =============================================================================
# Step 4: Ask about server purpose and configure UFW firewall
# UFW (Uncomplicated Firewall) blocks all incoming traffic except explicitly
# allowed ports. SSH (port 22) is always allowed.
# =============================================================================
echo ""
echo "--- Firewall (UFW) Setup ---"
if ufw status 2>/dev/null | grep -q "Status: active"; then
  echo "UFW is already active, skipping firewall configuration."
  ufw status verbose
else
  echo "What is the purpose of this server?"
  echo "  1) General purpose (SSH only)"
  echo "  2) Web server (SSH + HTTP/HTTPS)"
  echo "  3) Custom"
  read -rp "Select [1/2/3]: " SERVER_PURPOSE

  # Start with a clean default: deny all incoming, allow all outgoing
  ufw default deny incoming
  ufw default allow outgoing

  # SSH is always allowed
  ufw allow 22/tcp comment "SSH"

  case "$SERVER_PURPOSE" in
    2)
      ufw allow 80/tcp comment "HTTP"
      ufw allow 443/tcp comment "HTTPS"
      echo "Ports 80 (HTTP) and 443 (HTTPS) opened."
      ;;
    3)
      echo "Would you like to open HTTP (80) and HTTPS (443)? [y/N]"
      read -rp "> " OPEN_WEB
      if [[ "$OPEN_WEB" =~ ^[Yy] ]]; then
        ufw allow 80/tcp comment "HTTP"
        ufw allow 443/tcp comment "HTTPS"
        echo "Ports 80 and 443 opened."
      fi

      # Allow the user to specify additional ports as a comma-separated list
      echo "Enter additional ports to open (comma-separated, e.g. 8080,3000), or press Enter to skip:"
      read -rp "> " EXTRA_PORTS
      if [ -n "$EXTRA_PORTS" ]; then
        IFS=',' read -ra PORTS <<< "$EXTRA_PORTS"
        for port in "${PORTS[@]}"; do
          port=$(echo "$port" | tr -d ' ')
          if [[ "$port" =~ ^[0-9]+$ ]]; then
            ufw allow "$port/tcp" comment "Custom port"
            echo "Port $port opened."
          else
            echo "Skipping invalid port: $port"
          fi
        done
      fi
      ;;
    *)
      echo "Only SSH (port 22) will be open."
      ;;
  esac

  # Enable UFW (--force skips the interactive confirmation)
  ufw --force enable
  echo "UFW firewall enabled."
  ufw status verbose
fi

# =============================================================================
# Step 5: Set up fail2ban for SSH brute-force protection
# fail2ban monitors the journal and bans IPs that have too many failed login
# attempts. We configure a 24-hour ban time for SSH.
# =============================================================================
echo ""
echo "--- fail2ban Setup ---"
if [ -f /etc/fail2ban/jail.local ] && systemctl is-active --quiet fail2ban; then
  echo "fail2ban already configured and running, skipping."
else
  # A local jail config overrides defaults without modifying the upstream
  # jail.conf, so our settings survive package upgrades
  cat > /etc/fail2ban/jail.local << 'EOF'
[sshd]
enabled = true
port = ssh
filter = sshd
# Ban offending IPs for 24 hours (86400 seconds)
bantime = 86400
# Look at the last 10 minutes of logs to find failures
findtime = 600
# Ban after 5 failed attempts
maxretry = 5
backend = systemd
EOF

  systemctl enable fail2ban
  systemctl restart fail2ban
  echo "fail2ban configured: 24-hour ban after 5 failed SSH attempts."
fi

# =============================================================================
# Step 6: Set zsh as the default shell for the new user
# =============================================================================
echo ""
echo "--- Zsh Setup ---"
if [ "$(getent passwd "$NEW_USER" | cut -d: -f7)" != "$(command -v zsh)" ]; then
  chsh -s "$(command -v zsh)" "$NEW_USER"
  echo "Zsh set as default shell for '$NEW_USER'."
else
  echo "Zsh is already the default shell for '$NEW_USER'."
fi

# =============================================================================
# Step 7: Clone dotfiles and stow packages
# =============================================================================
echo ""
echo "--- Dotfiles Setup for '$NEW_USER' ---"

if ! [ -d "$USER_HOME/dotfiles" ]; then
  echo "Cloning dotfiles..."
  su - "$NEW_USER" -c 'git clone --depth=1 https://github.com/christopher-kapic/dotfiles.git "$HOME/dotfiles"'
else
  echo "dotfiles already cloned."
fi

# Ensure ~/.local/bin exists as a real directory so stow symlinks individual
# scripts, and ~/.cache/zsh exists for the zsh history file
su - "$NEW_USER" -c 'mkdir -p "$HOME/.local/bin" "$HOME/.cache/zsh"'

# Stow relevant packages for server use (skip alacritty, bettermouse, nvchad, fonts)
STOW_PACKAGES="git shell zsh lvim scripts tmux"
for pkg in $STOW_PACKAGES; do
  if [ -d "$USER_HOME/dotfiles/$pkg" ]; then
    echo "Stowing $pkg..."
    su - "$NEW_USER" -c "cd \$HOME/dotfiles && stow --restow --target=\$HOME $pkg"
  fi
done

# Generate git user config if it doesn't already exist
if ! [ -f "$USER_HOME/.config/git/config.local" ]; then
  echo ""
  echo "--- Git User Setup ---"
  read -rp "Enter full name for git commits: " GIT_NAME
  read -rp "Enter email for git commits: " GIT_EMAIL
  mkdir -p "$USER_HOME/.config/git"
  cat > "$USER_HOME/.config/git/config.local" << EOF
[user]
	name = $GIT_NAME
	email = $GIT_EMAIL
EOF
  chown -R "$NEW_USER:$NEW_USER" "$USER_HOME/.config/git"
  echo "Git user config written to ~/.config/git/config.local"
fi

# Copy zshrc template if ~/.zshrc doesn't exist
if ! [ -f "$USER_HOME/.zshrc" ]; then
  echo "Copying zshrc template to ~/.zshrc..."
  cp "$USER_HOME/dotfiles/templates/zshrc" "$USER_HOME/.zshrc"
  chown "$NEW_USER:$NEW_USER" "$USER_HOME/.zshrc"
fi

# =============================================================================
# Step 8: Install fnm, Node.js, and Rust for the new user
# These are prerequisites for LunaVim. We run them as the new user so
# they're installed in the user's home directory, not system-wide.
# =============================================================================
echo ""
echo "--- Installing fnm, Node.js, and Rust for '$NEW_USER' ---"

# fnm-update installs the latest release binary to ~/.local/bin/fnm (a no-op
# if already up to date); re-run it later to upgrade.
su - "$NEW_USER" -c '"$HOME/dotfiles/scripts/.local/bin/fnm-update"'

# fnm install is a no-op (with a warning) if the version is already installed
su - "$NEW_USER" -c 'export PATH="$HOME/.local/bin:$PATH" && eval "$(fnm env --shell bash)" && fnm install 25 && fnm default 25'

if [ -x "$USER_HOME/.cargo/bin/rustc" ]; then
  echo "Rust already installed for '$NEW_USER'."
else
  su - "$NEW_USER" -c 'curl --proto "=https" --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y'
fi

# =============================================================================
# Step 9: Install LunaVim for the new user
# LunaVim (https://github.com/christopher-kapic/LunaVim) is a Neovim
# distribution descended from LunarVim. The executable is still `lvim` and the
# config still lives in ~/.config/lvim.
# =============================================================================
echo ""
echo "--- Neovim and LunaVim Setup ---"

# Neovim comes from the latest GitHub release rather than apt (which lags
# behind): nvim-update installs it to ~/.nvim and links ~/.local/bin/nvim.
# Re-running it later upgrades in place.
su - "$NEW_USER" -c '"$HOME/dotfiles/scripts/.local/bin/nvim-update"'
LUNAVIM_INSTALLER_URL="https://raw.githubusercontent.com/christopher-kapic/LunaVim/master/scripts/install.sh"

if [ -d "$USER_HOME/.local/share/lunavim/.git" ]; then
  echo "LunaVim already installed for '$NEW_USER'."
else
  # LunaVim's installer refuses to overwrite a LunarVim/CKLunarVim launcher
  # unless --force is given, so detect a prior install and migrate it.
  LUNAVIM_ARGS=
  if [ -e "$USER_HOME/.local/share/lunarvim" ] || [ -e "$USER_HOME/.local/bin/lvim" ]; then
    echo "Existing LunarVim/CKLunarVim install detected for '$NEW_USER' - replacing the lvim launcher with LunaVim."
    echo "The old ~/.local/share/lunarvim directory is left on disk; remove it once you're happy."
    LUNAVIM_ARGS="--force"
  fi
  su - "$NEW_USER" -c "export PATH=\"\$HOME/.local/bin:\$PATH\"; eval \"\$(fnm env --shell bash)\"; export PATH=\"\$HOME/.nvim/bin:\$HOME/.cargo/bin:\$PATH\"; curl -sL '$LUNAVIM_INSTALLER_URL' | bash -s -- $LUNAVIM_ARGS"
  echo "LunaVim installed for '$NEW_USER'."
fi

# =============================================================================
# Step 10: Workstation CLI tools (optional, --workstation flag)
# apt/binary tools are installed system-wide; opencode and claude-code are
# per-user installs into the new user's home directory.
# =============================================================================
if $WORKSTATION; then
  echo ""
  echo "--- Installing workstation CLI tools ---"

  apt-get install -y tmux htop jq

  # GitHub CLI from its official apt repo
  if ! command -v gh &> /dev/null; then
    echo "Installing GitHub CLI..."
    mkdir -p -m 755 /etc/apt/keyrings
    wget -qO- https://cli.github.com/packages/githubcli-archive-keyring.gpg | tee /etc/apt/keyrings/githubcli-archive-keyring.gpg > /dev/null
    chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | tee /etc/apt/sources.list.d/github-cli.list > /dev/null
    apt-get update -qq
    apt-get install -y gh
  else
    echo "gh already installed."
  fi

  # lazygit from GitHub releases
  if ! command -v lazygit &> /dev/null; then
    echo "Installing lazygit..."
    LAZYGIT_VERSION=$(curl -s "https://api.github.com/repos/jesseduffield/lazygit/releases/latest" | grep -Po '"tag_name": "v\K[^"]*')
    curl -Lo /tmp/lazygit.tar.gz "https://github.com/jesseduffield/lazygit/releases/latest/download/lazygit_${LAZYGIT_VERSION}_Linux_${ARCH}.tar.gz"
    tar xf /tmp/lazygit.tar.gz -C /tmp lazygit
    install /tmp/lazygit /usr/local/bin
    rm -f /tmp/lazygit /tmp/lazygit.tar.gz
  else
    echo "lazygit already installed."
  fi

  # Check the install locations directly: `su -` starts a non-interactive zsh
  # login shell, which doesn't read ~/.zshrc, so these aren't on its PATH.
  if [ -x "$USER_HOME/.opencode/bin/opencode" ]; then
    echo "OpenCode already installed for '$NEW_USER'."
  else
    echo "Installing OpenCode for '$NEW_USER'..."
    su - "$NEW_USER" -c 'curl -fsSL https://opencode.ai/install | bash'
  fi

  if [ -x "$USER_HOME/.local/bin/claude" ]; then
    echo "Claude Code already installed for '$NEW_USER'."
  else
    echo "Installing Claude Code for '$NEW_USER'..."
    su - "$NEW_USER" -c 'curl -fsSL https://claude.ai/install.sh | bash'
  fi
fi

# =============================================================================
# Step 11: Disable sleep (optional, for laptops used as servers)
# logind ignores the lid switch and the sleep targets are masked, so the
# machine stays reachable with the lid closed.
# =============================================================================
NO_SLEEP_CONF=/etc/systemd/logind.conf.d/00-dotfiles-no-sleep.conf
echo ""
echo "--- Sleep / Lid Setup ---"
if [ -f "$NO_SLEEP_CONF" ]; then
  echo "Sleep and lid-close suspend already disabled."
else
  read -rp "Is this a laptop? Disable sleep and ignore lid close? [y/N] " DISABLE_SLEEP
  if [[ "$DISABLE_SLEEP" =~ ^[Yy] ]]; then
    mkdir -p /etc/systemd/logind.conf.d
    cat > "$NO_SLEEP_CONF" << 'EOF'
[Login]
HandleLidSwitch=ignore
HandleLidSwitchExternalPower=ignore
HandleLidSwitchDocked=ignore
EOF
    systemctl mask sleep.target suspend.target hibernate.target hybrid-sleep.target
    echo "Sleep disabled. The lid-switch setting takes effect after a reboot."
  fi
fi

# =============================================================================
# Step 12: NetBird (optional)
# The installer adds NetBird's apt repo and installs the netbird service.
# =============================================================================
echo ""
echo "--- NetBird Setup ---"
if command -v netbird &> /dev/null; then
  echo "NetBird already installed."
else
  read -rp "Install NetBird? [y/N] " INSTALL_NETBIRD
  if [[ "$INSTALL_NETBIRD" =~ ^[Yy] ]]; then
    curl -fsSL https://pkgs.netbird.io/install.sh | sh
  fi
fi

if command -v netbird &> /dev/null; then
  if netbird status 2>/dev/null | grep -q "^Management: Connected"; then
    echo "NetBird already connected."
  else
    echo "Enter a NetBird setup key to connect now, or press Enter to skip:"
    read -rsp "> " NB_SETUP_KEY
    echo ""
    if [ -n "$NB_SETUP_KEY" ]; then
      read -rp "Management URL (press Enter for NetBird cloud): " NB_MANAGEMENT_URL
      NB_ARGS=(up --setup-key "$NB_SETUP_KEY")
      [ -n "$NB_MANAGEMENT_URL" ] && NB_ARGS+=(--management-url "$NB_MANAGEMENT_URL")
      netbird "${NB_ARGS[@]}"
    else
      echo "Run 'netbird up' later to connect (add --management-url <url> if self-hosted)."
    fi
  fi
fi

# =============================================================================
# Done!
# =============================================================================
echo ""
echo "============================================"
echo "  Setup complete!"
echo "============================================"
echo ""
echo "Summary:"
echo "  - User '$NEW_USER' with sudo access"
echo "  - SSH: key-based auth only, root login disabled"
echo "  - UFW: firewall enabled (check 'ufw status' for open ports)"
echo "  - fail2ban: 24h ban after 5 failed SSH attempts"
echo "  - Dotfiles: cloned, stowed ($STOW_PACKAGES)"
echo "  - Starship: installed via apt"
echo "  - Neovim: latest release in ~/.nvim (run nvim-update to upgrade)"
echo "  - LunaVim: installed for '$NEW_USER'"
echo "  - Zsh: default shell for '$NEW_USER'"
if command -v netbird &> /dev/null; then
  echo "  - NetBird: installed"
fi
if $WORKSTATION; then
  echo "  - Workstation tools: tmux, htop, jq, gh, lazygit, opencode, claude-code"
fi
echo ""
echo "IMPORTANT: Before closing this session, verify you can SSH in as '$NEW_USER'"
echo "in a separate terminal. If you can't, you may lock yourself out!"
echo ""
echo "To add another user, re-run this script. System-level setup will be"
echo "skipped; only per-user setup will run for the new user."

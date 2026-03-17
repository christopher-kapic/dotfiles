#!/bin/bash
set -e

# =============================================================================
# Ubuntu Server 24.04 Setup Script
# Christopher Kapic's dotfiles
#
# This script should be run as root on a fresh Ubuntu Server 24.04 installation.
# It will:
#   1. Create a new user with sudo access
#   2. Configure SSH (key-based auth only, no root login)
#   3. Set up UFW firewall
#   4. Set up fail2ban for SSH brute-force protection
#   5. Install Neovim (latest from GitHub releases)
#   6. Install CKLunarVim for the new user
#   7. Set zsh as the default shell for the new user
# =============================================================================

# --- Ensure the script is run as root ---
if [ "$(id -u)" -ne 0 ]; then
  echo "Error: This script must be run as root."
  exit 1
fi

echo "============================================"
echo "  Ubuntu Server 24.04 Setup"
echo "  Christopher Kapic's dotfiles"
echo "============================================"
echo ""

# =============================================================================
# Step 1: Create a new user with sudo access
# =============================================================================
read -rp "Enter the username for the new user: " NEW_USER

if id "$NEW_USER" &>/dev/null; then
  echo "User '$NEW_USER' already exists, skipping creation."
else
  echo "Creating user '$NEW_USER'..."
  adduser --gecos "" "$NEW_USER"
  usermod -aG sudo "$NEW_USER"
  echo "User '$NEW_USER' created and added to the sudo group."
fi

# =============================================================================
# Step 2: Set up SSH key-based authentication
# Disables password authentication and root login for security.
# =============================================================================
echo ""
echo "--- SSH Key Setup ---"
echo "Paste the SSH public key for '$NEW_USER' (one line, then press Enter):"
read -rp "> " SSH_PUBLIC_KEY

if [ -z "$SSH_PUBLIC_KEY" ]; then
  echo "Error: No SSH key provided. Key-based authentication is required."
  exit 1
fi

# Create .ssh directory for the new user and install the authorized key
USER_HOME=$(eval echo "~$NEW_USER")
mkdir -p "$USER_HOME/.ssh"
echo "$SSH_PUBLIC_KEY" >> "$USER_HOME/.ssh/authorized_keys"
chmod 700 "$USER_HOME/.ssh"
chmod 600 "$USER_HOME/.ssh/authorized_keys"
chown -R "$NEW_USER:$NEW_USER" "$USER_HOME/.ssh"
echo "SSH public key installed for '$NEW_USER'."

# Harden the SSH daemon configuration:
# - Disable root login entirely
# - Disable password authentication (key-based only)
# - Disable challenge-response authentication
echo "Configuring SSH daemon..."
sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config
sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
sed -i 's/^#\?ChallengeResponseAuthentication.*/ChallengeResponseAuthentication no/' /etc/ssh/sshd_config
sed -i 's/^#\?KbdInteractiveAuthentication.*/KbdInteractiveAuthentication no/' /etc/ssh/sshd_config
sed -i 's/^#\?UsePAM.*/UsePAM yes/' /etc/ssh/sshd_config

# Restart SSH to apply changes
systemctl restart sshd
echo "SSH configured: root login disabled, password authentication disabled."

# =============================================================================
# Step 3: Ask about server purpose and configure UFW firewall
# UFW (Uncomplicated Firewall) blocks all incoming traffic except explicitly
# allowed ports. SSH (port 22) is always allowed.
# =============================================================================
echo ""
echo "--- Firewall (UFW) Setup ---"
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
    # Allow standard web traffic ports
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
        # Trim whitespace
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

# =============================================================================
# Step 4: Set up fail2ban for SSH brute-force protection
# fail2ban monitors auth logs and bans IPs that have too many failed login
# attempts. We configure a 24-hour ban time for SSH.
# =============================================================================
echo ""
echo "--- fail2ban Setup ---"
apt-get update -qq
apt-get install -y fail2ban

# Create a local jail config (overrides defaults without modifying the
# upstream jail.conf, so our settings survive package upgrades)
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

# =============================================================================
# Step 5: Install zsh and set it as default shell for the new user
# =============================================================================
echo ""
echo "--- Zsh Setup ---"
apt-get install -y zsh
chsh -s "$(which zsh)" "$NEW_USER"
echo "Zsh set as default shell for '$NEW_USER'."

# =============================================================================
# Step 6: Install dependencies needed for Neovim and CKLunarVim
# =============================================================================
echo ""
echo "--- Installing dependencies ---"
apt-get install -y git curl wget build-essential unzip

# =============================================================================
# Step 7: Install latest Neovim from GitHub releases
# The apt repository typically has outdated versions, so we pull the latest
# release directly from the Neovim GitHub project.
# =============================================================================
echo ""
echo "--- Neovim Setup ---"

# Query the GitHub API for the latest release tag
NVIM_LATEST=$(curl -s https://api.github.com/repos/neovim/neovim/releases/latest | grep '"tag_name"' | sed -E 's/.*"([^"]+)".*/\1/')
echo "Latest Neovim release: $NVIM_LATEST"

# Download and extract the pre-built Linux binary
NVIM_URL="https://github.com/neovim/neovim/releases/download/${NVIM_LATEST}/nvim-linux-x86_64.tar.gz"
echo "Downloading Neovim from $NVIM_URL..."
curl -Lo /tmp/nvim.tar.gz "$NVIM_URL"
tar -xzf /tmp/nvim.tar.gz -C /opt/
rm -f /tmp/nvim.tar.gz

# Symlink nvim into /usr/local/bin so it's on everyone's PATH
ln -sf /opt/nvim-linux-x86_64/bin/nvim /usr/local/bin/nvim
echo "Neovim $(nvim --version | head -1) installed to /usr/local/bin/nvim."

# =============================================================================
# Step 8: Install nvm, Node.js, and Rust for the new user
# These are prerequisites for CKLunarVim. We run them as the new user so
# they're installed in the user's home directory, not system-wide.
# =============================================================================
echo ""
echo "--- Installing nvm, Node.js, and Rust for '$NEW_USER' ---"

# Install nvm and Node.js as the new user
su - "$NEW_USER" -c 'curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.4/install.sh | bash'
su - "$NEW_USER" -c 'export NVM_DIR="$HOME/.nvm" && [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh" && nvm install 25'

# Install Rust toolchain as the new user (non-interactive via -y flag)
su - "$NEW_USER" -c 'curl --proto "=https" --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y'

# =============================================================================
# Step 9: Install CKLunarVim for the new user
# CKLunarVim is a custom LunarVim distribution. We install it as the new user
# so the configuration lands in their home directory.
# =============================================================================
echo ""
echo "--- CKLunarVim Setup ---"
su - "$NEW_USER" -c 'export NVM_DIR="$HOME/.nvm" && [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh" && export PATH="$HOME/.cargo/bin:$PATH" && bash <(curl -s https://raw.githubusercontent.com/christopher-kapic/CKLunarVim/master/utils/installer/install.sh)'
echo "CKLunarVim installed for '$NEW_USER'."

# =============================================================================
# Done!
# =============================================================================
echo ""
echo "============================================"
echo "  Setup complete!"
echo "============================================"
echo ""
echo "Summary:"
echo "  - User '$NEW_USER' created with sudo access"
echo "  - SSH: key-based auth only, root login disabled"
echo "  - UFW: firewall enabled (check 'ufw status' for open ports)"
echo "  - fail2ban: 24h ban after 5 failed SSH attempts"
echo "  - Neovim: latest version installed"
echo "  - CKLunarVim: installed for '$NEW_USER'"
echo "  - Zsh: default shell for '$NEW_USER'"
echo ""
echo "IMPORTANT: Before closing this session, verify you can SSH in as '$NEW_USER'"
echo "in a separate terminal. If you can't, you may lock yourself out!"

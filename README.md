# Christopher Kapic's Dotfiles

### MacOS Install

```
bash <(curl -s https://raw.githubusercontent.com/christopher-kapic/dotfiles/master/install-macos.sh)
```


### Ubuntu Install (for servers)

Note: This script is likely broken as of now. I recently switched to using [GNU stow](https://www.gnu.org/software/stow/) to manage my dotfiles, and I haven't updated the server installation script yet.

#### Add user (if `$USER` is `root`)

```
useradd <user> -m -G sudo -s /usr/bin/bash # will be zsh after script
passwd <user>
su <user>
```

#### Install script

```
bash <(curl -s https://raw.githubusercontent.com/christopher-kapic/dotfiles/master/server-install.sh)
```

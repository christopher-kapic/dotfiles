# Christopher Kapic's Dotfiles

### MacOS Install

```
bash <(curl -s https://raw.githubusercontent.com/christopher-kapic/dotfiles/master/install.sh)
```


### Ubuntu Install (for servers)

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


# Christopher Kapic's Dotfiles

### MacOS Install

```
bash <(curl -s https://raw.githubusercontent.com/christopher-kapic/dotfiles/master/install.sh)
```


### Ubuntu Install (for servers)

#### Install ZSH

```
sudo apt install zsh
```

#### Add user (if $USER is `root`)

```
useradd <user> -m -G sudo -s /usr/bin/zsh
passwd <user>
su <user>
```

#### Install script

```
bash <(curl -s https://raw.githubusercontent.com/christopher-kapic/dotfiles/master/server-install.sh)
```


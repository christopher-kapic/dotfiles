# Disable mouse reporting when not inside tmux (prevents escape codes from leaking)
if [[ -z "$TMUX" ]]; then
  printf '\e[?1000l\e[?1002l\e[?1003l\e[?1006l'
fi

# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

autoload -U colors && colors
HISTSIZE=10000 # 000
SAVEHIST=10000 # 000
HISTFILE=~/.cache/zsh/history

autoload -Uz compinit
zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'
zmodload zsh/complist
if [[ -n $ZDOTDIR/.zcompdump(#qNmh+24) ]]; then
  compinit
else
  compinit -C
fi
_comp_options+=(globdots)

set -o vi
export KEYTIMEOUT=1

bindkey -M menuselect 'h' vi-backward-char
bindkey -M menuselect 'k' vi-up-line-or-history
bindkey -M menuselect 'l' vi-forward-char
bindkey -M menuselect 'j' vi-down-line-or-history
bindkey -v '^?' backward-delete-char

#### FROM LUKE SMITH ####
# Change cursor shape for different vi modes.
function zle-keymap-select {
  if [[ ${KEYMAP} == vicmd ]] ||
     [[ $1 = 'block' ]]; then
    echo -ne '\e[1 q'
  elif [[ ${KEYMAP} == main ]] ||
       [[ ${KEYMAP} == viins ]] ||
       [[ ${KEYMAP} = '' ]] ||
       [[ $1 = 'beam' ]]; then
    echo -ne '\e[5 q'
  fi
}
zle -N zle-keymap-select
zle-line-init() {
    echo -ne "\e[5 q"
}
zle -N zle-line-init
preexec() { echo -ne '\e[5 q' ;}

bindkey '^r' history-incremental-search-backward

autoload -Uz select-bracketed select-quoted
zle -N select-bracketed
zle -N select-quoted
for km in viopp visual; do
  for c in {a,i}${(s..)^:-'()[]{}<>bB'}; do
    bindkey -M $km $c select-bracketed
  done
  for c in {a,i}{\',\",\`}; do
    bindkey -M $km $c select-quoted
  done
done

source $HOME/.config/shell/path
source $HOME/.config/shell/alias
source $HOME/.config/shell/env


[[ ! -f $HOME/.powerlevel10k/powerlevel10k.zsh-theme ]] || source $HOME/.powerlevel10k/powerlevel10k.zsh-theme

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f $HOME/.p10k.zsh ]] || source $HOME/.p10k.zsh

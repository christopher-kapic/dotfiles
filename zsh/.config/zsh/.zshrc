# Disable mouse reporting when not inside tmux (prevents escape codes from leaking)
if [[ -z "$TMUX" ]]; then
  printf '\e[?1000l\e[?1002l\e[?1003l\e[?1006l'
fi

# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
# if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  # source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
# fi

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


# Starship prompt. Must be initialized AFTER the vi-mode `zle-keymap-select`
# widget defined above so Starship wraps it (keeps the cursor-shape switching
# and enables the vi-mode prompt indicator). To customize, edit
# ~/.config/starship.toml (stowed from the `starship` package).
if command -v starship >/dev/null; then
  eval "$(starship init zsh)"

  # --- p10k-style "show on command" -----------------------------------------
  # Starship draws the prompt once per redraw, so to mimic p10k's
  # SHOW_ON_COMMAND we export $STARSHIP_CMD = the first word of the command
  # being typed and force a redraw. The [custom.*] modules in starship.toml
  # decide which segment (if any) to show for that command. This is generic:
  # adding a new show-on-command segment only needs a new [custom.*] block in
  # starship.toml -- no changes here. (Only the first word is used, so segments
  # do not react to commands after a pipe.)
  _starship_show_on_command() {
    local -a words
    words=(${(z)BUFFER})
    local cmd=${words[1]}
    [[ $cmd == sudo ]] && cmd=${words[2]}
    if [[ $cmd != ${STARSHIP_CMD:-} ]]; then
      [[ -n $cmd ]] && export STARSHIP_CMD=$cmd || unset STARSHIP_CMD
      zle reset-prompt
    fi
  }
  autoload -Uz add-zle-hook-widget add-zsh-hook
  add-zle-hook-widget line-pre-redraw _starship_show_on_command
  # Clear the flag as soon as a command is submitted so a stale segment does
  # not linger on the next prompt (the scrollback line keeps whatever showed
  # while you were typing).
  _starship_clear_show_on_command() { unset STARSHIP_CMD }
  add-zsh-hook preexec _starship_clear_show_on_command

  # Cache the git status once per command (precmd), not on every redraw, so the
  # per-second clock refresh stays cheap even in large repositories. The git
  # custom modules in starship.toml just read these exported values.
  _starship_git_cache() {
    local text
    text=$(sh "$HOME/.config/starship/git-status.sh" 2>/dev/null)
    case $? in
      0) export STARSHIP_GIT_TEXT=$text; unset STARSHIP_GIT_DIRTY ;;
      2) export STARSHIP_GIT_TEXT=$text; export STARSHIP_GIT_DIRTY=1 ;;
      *) unset STARSHIP_GIT_TEXT STARSHIP_GIT_DIRTY ;;
    esac
  }
  add-zsh-hook precmd _starship_git_cache

  # --- Refresh the prompt every second -------------------------------------
  # Keeps the displayed clock current while you sit at the prompt, so the time
  # frozen into your scrollback reflects when you actually ran the command.
  # (Side effect: TMOUT also applies to interactive `read`/`select` waits.)
  TMOUT=1
  TRAPALRM() { zle && zle reset-prompt }
fi

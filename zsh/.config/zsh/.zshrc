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

  # Default state for the very first prompt draw of a new shell (before any
  # precmd/keypress hook below has had a chance to run).
  export STARSHIP_NO_PILL=1

  # --- p10k-style "show on command" -----------------------------------------
  # Starship draws the prompt once per redraw (every second, via TMOUT below),
  # and previously every [custom.*] module forked a fresh `sh` just to test its
  # `when` clause on every one of those redraws -- expensive and, under load,
  # occasionally slow enough to hit Starship's command_timeout. To avoid that,
  # this hook does the classification (and, for kube/azure, the one real
  # subprocess call) *once*, only when the active command word actually
  # changes, and exports plain text into env vars. The [env_var.*] modules in
  # starship.toml then just read those vars directly inside Starship's own
  # process -- zero forks per redraw. (Only the first word is used, so
  # segments do not react to commands after a pipe.)
  typeset -g _starship_cmd_group=
  _starship_show_on_command() {
    local -a words
    words=(${(z)BUFFER})
    local cmd=${words[1]}
    [[ $cmd == sudo ]] && cmd=${words[2]}
    local group=
    case $cmd in
      kubectl|helm|kubens|kubectx|oc|istioctl|kogito|k9s|helmfile|flux|fluxctl|stern|kubeseal|skaffold) group=kube ;;
      az|terraform|terragrunt|pulumi) group=azure ;;
    esac
    [[ $group == $_starship_cmd_group ]] && return
    _starship_cmd_group=$group
    case $group in
      kube)
        export STARSHIP_KUBE_TEXT=$(sh "$HOME/.config/starship/kube-context.sh" 2>/dev/null)
        unset STARSHIP_AZURE_TEXT
        ;;
      azure)
        export STARSHIP_AZURE_TEXT=$(sh "$HOME/.config/starship/azure-sub.sh" 2>/dev/null)
        unset STARSHIP_KUBE_TEXT
        ;;
      *) unset STARSHIP_KUBE_TEXT STARSHIP_AZURE_TEXT ;;
    esac
    [[ -n $group ]] && unset STARSHIP_NO_PILL || export STARSHIP_NO_PILL=1
    zle reset-prompt
  }
  autoload -Uz add-zle-hook-widget add-zsh-hook
  add-zle-hook-widget line-pre-redraw _starship_show_on_command
  # Clear the flags as soon as a command is submitted so a stale segment does
  # not linger on the next prompt (the scrollback line keeps whatever showed
  # while you were typing).
  _starship_clear_show_on_command() {
    _starship_cmd_group=
    unset STARSHIP_KUBE_TEXT STARSHIP_AZURE_TEXT
    export STARSHIP_NO_PILL=1
  }
  add-zsh-hook preexec _starship_clear_show_on_command

  # Cache the git status once per command (precmd), not on every redraw, so the
  # per-second clock refresh stays cheap even in large repositories. The
  # [env_var.*] git modules in starship.toml just read these exported values
  # directly (no forked shell per redraw).
  _starship_git_cache() {
    local text
    text=$(sh "$HOME/.config/starship/git-status.sh" 2>/dev/null)
    case $? in
      0) export STARSHIP_GIT_CLEAN_TEXT=$text; unset STARSHIP_GIT_DIRTY_TEXT STARSHIP_NO_GIT ;;
      2) export STARSHIP_GIT_DIRTY_TEXT=$text; unset STARSHIP_GIT_CLEAN_TEXT STARSHIP_NO_GIT ;;
      *) unset STARSHIP_GIT_CLEAN_TEXT STARSHIP_GIT_DIRTY_TEXT; export STARSHIP_NO_GIT=1 ;;
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

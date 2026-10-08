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

# fnm (Node version manager): ~/.local/bin/fnm on Linux (fnm-update), Homebrew
# on macOS. --use-on-cd switches node when entering a directory with .nvmrc /
# .node-version.
if (( $+commands[fnm] )); then
  eval "$(fnm env --use-on-cd --shell zsh)"
fi

# Starship prompt. Must be initialized AFTER the vi-mode `zle-keymap-select`
# widget defined above so Starship wraps it (keeps the cursor-shape switching
# and enables the vi-mode prompt indicator). To customize, edit
# ~/.config/starship.toml (stowed from the `starship` package).
if command -v starship >/dev/null; then
  eval "$(starship init zsh)"
  autoload -Uz add-zle-hook-widget add-zsh-hook

  # Every right-side pill in starship.toml is an [env_var.*] module that shows
  # while its $STARSHIP_*_TEXT variable is set. The hooks below compute those
  # texts once per command (precmd) or once per change of the typed command
  # word (show-on-command), never on the per-second redraw, so redraws fork
  # nothing. Prefer pure zsh in precmd hooks: they run before every prompt.

  # Set or clear a pill: _starship_pill NAME TEXT (empty TEXT hides it).
  _starship_pill() {
    if [[ -n $2 ]]; then export STARSHIP_$1_TEXT=$2; else unset STARSHIP_$1_TEXT; fi
  }

  # --- user@host (only over SSH or as root, like p10k's context) -----------
  # Fixed for the life of the shell, so computed once here.
  if (( EUID == 0 )); then
    _starship_pill CONTEXT_ROOT "${(%):-%n@%m}"; _starship_pill CONTEXT ''
  elif [[ -n $SSH_CONNECTION || -n $SSH_CLIENT || -n $SSH_TTY ]]; then
    _starship_pill CONTEXT "${(%):-%n@%m}"; _starship_pill CONTEXT_ROOT ''
  else
    _starship_pill CONTEXT ''; _starship_pill CONTEXT_ROOT ''
  fi

  # --- p10k-style "show on command" -----------------------------------------
  # Classifies the first word of the command being typed and, only when that
  # changes, runs the (subprocess-backed) lookups and exports their text. One
  # command can enable several segments (terraform shows azure + its own
  # version, as p10k did). To add a show-on-command segment, add a flag here
  # and set its pill in the block below. (Only the first word is used, so
  # segments do not react to commands after a pipe.)
  typeset -g _starship_cmd_group= _starship_tf_version= _starship_tf_version_shown= _starship_tf_workspace=
  _starship_show_on_command() {
    local -a words
    words=(${(z)BUFFER})
    local cmd=${words[1]}
    [[ $cmd == sudo ]] && cmd=${words[2]}
    local kube= azure= tf=
    case $cmd in
      kubectl|helm|kubens|kubectx|oc|istioctl|kogito|k9s|helmfile|flux|fluxctl|stern|kubeseal|skaffold) kube=1 ;;
      az) azure=1 ;;
      terraform|tf) azure=1 tf=1 ;;
      terragrunt|pulumi) azure=1 ;;
    esac
    local group=$kube:$azure:$tf
    [[ $group == $_starship_cmd_group ]] && return
    _starship_cmd_group=$group
    _starship_pill KUBE "${kube:+$(sh "$HOME/.config/starship/kube-context.sh" 2>/dev/null)}"
    _starship_pill AZURE "${azure:+$(sh "$HOME/.config/starship/azure-sub.sh" 2>/dev/null)}"
    if [[ -n $tf && -z $_starship_tf_version ]]; then
      # `terraform version` is slow-ish; run it once per shell.
      local out=$(command terraform version 2>/dev/null)
      out=${${(f)out}[1]}            # "Terraform v1.9.5"
      _starship_tf_version=${out##* }
    fi
    _starship_tf_version_shown=${tf:+$_starship_tf_version}
    _starship_terraform_export
    zle reset-prompt
  }
  add-zle-hook-widget line-pre-redraw _starship_show_on_command
  # Clear show-on-command segments as soon as a command is submitted so they
  # do not linger on the next prompt (the scrollback line keeps whatever
  # showed while you were typing).
  _starship_clear_show_on_command() {
    _starship_cmd_group= _starship_tf_version_shown=
    _starship_pill KUBE ''
    _starship_pill AZURE ''
    _starship_terraform_export
  }
  add-zsh-hook preexec _starship_clear_show_on_command

  # --- git (once per command) -----------------------------------------------
  # Cached in precmd, not on every redraw, so the per-second clock refresh
  # stays cheap even in large repositories.
  _starship_git_cache() {
    local text
    text=$(sh "$HOME/.config/starship/git-status.sh" 2>/dev/null)
    case $? in
      0) export STARSHIP_GIT_CLEAN_TEXT=$text; unset STARSHIP_GIT_DIRTY_TEXT STARSHIP_NO_GIT ;;
      2) export STARSHIP_GIT_DIRTY_TEXT=$text; unset STARSHIP_GIT_CLEAN_TEXT STARSHIP_NO_GIT ;;
      3) ;; # in a repo but status momentarily failed: keep the last-known segment
      *) unset STARSHIP_GIT_CLEAN_TEXT STARSHIP_GIT_DIRTY_TEXT; export STARSHIP_NO_GIT=1 ;;
    esac
  }
  add-zsh-hook precmd _starship_git_cache

  # --- Background jobs (once per command) -----------------------------------
  _starship_jobs() {
    (( ${#jobstates} )) && _starship_pill JOBS ${#jobstates} || _starship_pill JOBS ''
  }
  add-zsh-hook precmd _starship_jobs

  # --- Python venv (once per command) ---------------------------------------
  # Like p10k, a generic env dir name is replaced by its parent directory's
  # name: ~/ziggy/env shows "ziggy". Starship shows the venv itself, so stop
  # `source env/bin/activate` from also prepending "(env) " to the prompt.
  export VIRTUAL_ENV_DISABLE_PROMPT=1
  _starship_venv() {
    local name=
    if [[ -n $VIRTUAL_ENV ]]; then
      name=${VIRTUAL_ENV:t}
      case $name in
        env|venv|.venv|virtualenv) name=${VIRTUAL_ENV:h:t} ;;
      esac
    fi
    _starship_pill VENV "$name"
  }
  add-zsh-hook precmd _starship_venv

  # --- pyenv version (once per command) -------------------------------------
  # Like p10k with PYENV_PROMPT_ALWAYS_SHOW=false: shown only when the version
  # chosen by $PYENV_VERSION or the nearest .python-version differs from the
  # global one. Reads the files directly (no `pyenv` call).
  _starship_pyenv() {
    local v= g=system d=$PWD
    if (( $+commands[pyenv] )); then
      if [[ -n $PYENV_VERSION ]]; then
        v=$PYENV_VERSION
      else
        while :; do
          if [[ -r $d/.python-version ]]; then read -r v < $d/.python-version; break; fi
          [[ $d == / ]] && break
          d=${d:h}
        done
      fi
      [[ -r ${PYENV_ROOT:-$HOME/.pyenv}/version ]] && read -r g < ${PYENV_ROOT:-$HOME/.pyenv}/version
    fi
    [[ $v == $g ]] && v=
    _starship_pill PYENV "$v"
  }
  add-zsh-hook precmd _starship_pyenv

  # --- Node version via fnm (once per command) ------------------------------
  # Shown only when the active node differs from `fnm default`, like p10k's
  # nvm segment. Both are symlinks into $FNM_DIR/node-versions, so resolving
  # them in pure zsh is enough (no fnm call).
  _starship_node() {
    local cur= def=
    if [[ -n $FNM_MULTISHELL_PATH && -n $FNM_DIR ]]; then
      cur=${FNM_MULTISHELL_PATH:A}   # .../node-versions/v25.9.0/installation
      def=$FNM_DIR/aliases/default
      [[ -e $def ]] && def=${def:A}
      if [[ $cur == $def ]]; then cur=; else cur=${cur:h:t}; fi
    fi
    _starship_pill NODE "${cur#v}"
  }
  add-zsh-hook precmd _starship_node

  # --- Terraform (workspace once per command + version on command) ----------
  # The workspace is shown whenever it is not "default" ($TF_WORKSPACE, else
  # .terraform/environment in the current directory); the version is added
  # while typing a terraform command.
  _starship_terraform_export() {
    local text=$_starship_tf_workspace
    [[ -n $_starship_tf_version_shown ]] && text="${text:+$text }$_starship_tf_version_shown"
    _starship_pill TERRAFORM "$text"
  }
  _starship_terraform() {
    local ws=$TF_WORKSPACE
    [[ -z $ws && -r ${TF_DATA_DIR:-.terraform}/environment ]] && read -r ws < ${TF_DATA_DIR:-.terraform}/environment
    [[ $ws == default ]] && ws=
    _starship_tf_workspace=$ws
    _starship_terraform_export
  }
  add-zsh-hook precmd _starship_terraform

  # --- Refresh the prompt every second -------------------------------------
  # Keeps the displayed clock current while you sit at the prompt, so the time
  # frozen into your scrollback reflects when you actually ran the command.
  # (Side effect: TMOUT also applies to interactive `read`/`select` waits.)
  TMOUT=1
  TRAPALRM() { zle && zle reset-prompt }
fi

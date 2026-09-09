#!/bin/sh
# Print a p10k-style git segment: "<branch> +staged !modified ?untracked
# ✘deleted »renamed ~conflicted *stashed ⇡ahead ⇣behind".
# Empty output + exit 1 when not inside a work tree. Used by the
# [custom.git_clean] / [custom.git_dirty] Starship modules.
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || exit 1
porc=$(git status --porcelain --branch 2>/dev/null) || exit 1

branchline=$(printf '%s
' "$porc" | head -1)
rest=$(printf '%s
' "$porc" | tail -n +2)

hdr=${branchline#\#\# }
ahead=0; behind=0
case "$hdr" in
  *"(no branch)"*)   branch=$(git rev-parse --short HEAD 2>/dev/null) ;;
  "No commits yet on "*) branch=${hdr#No commits yet on } ;;
  *)
    branch=${hdr%%...*}
    branch=${branch%% *}
    case "$hdr" in *"ahead "*)  a=${hdr#*ahead };  ahead=${a%%[,\]]*} ;; esac
    case "$hdr" in *"behind "*) b=${hdr#*behind }; behind=${b%%[,\]]*} ;; esac ;;
esac

staged=0; modified=0; untracked=0; deleted=0; renamed=0; conflicted=0
oldIFS=$IFS
IFS='
'
for line in $rest; do
  [ -n "$line" ] || continue
  xy=$(printf '%s' "$line" | cut -c1-2)
  x=$(printf '%s' "$xy" | cut -c1)
  y=$(printf '%s' "$xy" | cut -c2)
  case "$xy" in
    '??') untracked=$((untracked+1)); continue ;;
    'DD'|'AU'|'UD'|'UA'|'DU'|'AA'|'UU') conflicted=$((conflicted+1)); continue ;;
  esac
  case "$x" in
    'R') renamed=$((renamed+1)) ;;
    'A'|'M'|'T'|'C') staged=$((staged+1)) ;;
    'D') deleted=$((deleted+1)) ;;
  esac
  case "$y" in
    'M'|'T') modified=$((modified+1)) ;;
    'D') deleted=$((deleted+1)) ;;
  esac
done
IFS=$oldIFS

stashed=$(git stash list 2>/dev/null | wc -l | tr -d ' ')

out=$branch
[ "${staged:-0}"     -gt 0 ] && out="$out +$staged"
[ "${modified:-0}"   -gt 0 ] && out="$out !$modified"
[ "${renamed:-0}"    -gt 0 ] && out="$out »$renamed"
[ "${deleted:-0}"    -gt 0 ] && out="$out ✘$deleted"
[ "${untracked:-0}"  -gt 0 ] && out="$out ?$untracked"
[ "${conflicted:-0}" -gt 0 ] && out="$out ~$conflicted"
[ "${stashed:-0}"    -gt 0 ] && out="$out *$stashed"
[ "${ahead:-0}"      -gt 0 ] && out="$out ⇡$ahead"
[ "${behind:-0}"     -gt 0 ] && out="$out ⇣$behind"
printf '%s' "$out"

# Signal dirtiness via exit code so the prompt can be cached: 0 = clean or
# untracked-only (green), 2 = dirty i.e. staged/unstaged tracked changes
# (yellow). Untracked files and stashes do not count as dirty, matching p10k's
# VCS_UNTRACKED_BACKGROUND. (exit 1 above = not a work tree.)
if [ "${staged:-0}" -gt 0 ] || [ "${modified:-0}" -gt 0 ] ||
   [ "${deleted:-0}" -gt 0 ] || [ "${renamed:-0}" -gt 0 ] ||
   [ "${conflicted:-0}" -gt 0 ]; then
  exit 2
fi
exit 0

# vim:ft=zsh ts=2 sw=2 sts=2
#
# agnoster's Theme - https://gist.github.com/3712874
# A Powerline-inspired theme for ZSH
#
# # README
#
# In order for this theme to render correctly, you will need a
# [NerdFont](https://www.nerdfonts.com/font-downloads).
# I used the RobotoMono Nerd Font.
#
# In addition, I recommend the
# [Solarized theme](https://github.com/altercation/solarized/) and, if you're
# using it on Mac OS X, [iTerm 2](https://iterm2.com/) over Terminal.app -
# it has significantly better color fidelity.
#
# If using with "light" variant of the Solarized color schema, set
# SOLARIZED_THEME variable to "light". If you don't specify, we'll assume
# you're using the "dark" variant.
#
# # Goals
#
# The aim of this theme is to only show you *relevant* information. Like most
# prompts, it will only show git information when in a git working directory.
# However, it goes a step further: everything from the current user and
# hostname to whether the last call exited with an error to whether background
# jobs are running in this shell will all be displayed automatically when
# appropriate.

### Segment drawing
# A few utility functions to make it easy and re-usable to draw segmented prompts

CURRENT_BG='NONE'

case ${SOLARIZED_THEME:-dark} in
    light) CURRENT_FG='white';;
    *)     CURRENT_FG='black';;
esac

# Special Powerline characters

() {
  local LC_ALL="" LC_CTYPE="en_US.UTF-8"
  # NOTE: This segment separator character is correct.  In 2012, Powerline changed
  # the code points they use for their special characters. This is the new code point.
  # If this is not working for you, you probably have an old version of the
  # Powerline-patched fonts installed. Download and install the new version.
  # Do not submit PRs to change this unless you have reviewed the Powerline code point
  # history and have new information.
  # This is defined using a Unicode escape sequence so it is unambiguously readable, regardless of
  # what font the user is viewing this source code in. Do not replace the
  # escape sequence with a single literal character.
  # Do not change this! Do not make it '\u2b80'; that is the old, wrong code point.
  SEGMENT_SEPARATOR=$'\ue0b0'

  PROMPT_CHAR="\uf179" # 

  # Link: https://github.com/robwierzbowski/charged-zsh-theme/blob/master/charged.zsh-theme
  # More symbols to choose from:
  # ☀ ✹ ☄ ♆ ♀ ♁ ♐ ♇ ♈ ♉ ♚ ♛ ♜ ♝ ♞ ♟ ♠ ♣ ⚢ ⚲ ⚳ ⚴ ⚥ ⚤ ⚦ ⚒ ⚑ ⚐ ♺ ♻ ⚡
  # ♼ ☰ ☱ ☲ ☳ ☴ ☵ ☶ ☷ ✡ ✔ ✖ ✚ ✱ ✤ ✦ ❤ ➜ ➟ ➼ ✂ ✎ ✐ ⨀ ⨁ ⨂ ⨍ ⨎ ⨏ ⨷ ⩚
  # ⩛ ⩡ ⩱ ⩲ ⩵  ⩶ ⨠ ⬅ ⬆ ⬇ ⬈ ⬉ ⬊ ⬋ ⬒ ⬓ ⬔ ⬕ ⬖ ⬗ ⬘ ⬙ ⬟  ⬤ 〒 ǀ ǁ ǂ ĭ Ť Ŧ
}

# Begin a segment
# Takes two arguments, background and foreground. Both can be omitted,
# rendering default background/foreground.
prompt_segment() {
  local bg fg
  [[ -n $1 ]] && bg="%K{$1}" || bg="%k"
  [[ -n $2 ]] && fg="%F{$2}" || fg="%f"
  if [[ $CURRENT_BG != 'NONE' && $1 != $CURRENT_BG ]]; then
    echo -n " %{$bg%F{$CURRENT_BG}%}$SEGMENT_SEPARATOR%{$fg%} "
  else
    echo -n "%{$bg%}%{$fg%} "
  fi
  CURRENT_BG=$1
  [[ -n $3 ]] && echo -n $3
}

# End the prompt, closing any open segments
prompt_end() {
  if [[ -n $CURRENT_BG ]]; then
    echo -n " %{%k%F{$CURRENT_BG}%}$PROMPT_CHAR"
  else
    echo -n "%{%k%}"
  fi
  echo -n "%{%f%}"
  CURRENT_BG=''
}

### Prompt components
# Each component will draw itself, and hide itself if no information needs to be shown

# Context: user@hostname (who am I and where am I)
prompt_context() {
  if [[ "$USERNAME" != "$DEFAULT_USER" || -n "$SSH_CLIENT" ]]; then
    prompt_segment cyan black "%(!.%{%F{yellow}%}.)%n@%m"
  fi
}

# Time: Show the time formated
# Other formats:
#   %D{%H:%M}: 24-hour, no seconds
#   %D{%I:%M %p}: 12-hour with AM/PM, like 03:45 PM
#   %D{%a %H:%M}: with the weekday, like Sat 15:45
prompt_time() {
  prompt_segment cyan black "%D{%a %H:%M}"
}

# Git: Info about current branch and state
prompt_git() {
  (( $+commands[git] )) || return
  [[ "$(git config --get oh-my-zsh.hide-status 2>/dev/null)" = 1 ]] && return

  # One git call for everything (stops here if not in a repo)
  local out
  out=$(__git_prompt_git status --porcelain=v2 --branch --show-stash 2>/dev/null) || return

  local line branch oid ab
  local ahead=0 behind=0 staged=0 changed=0 conflicts=0 untracked=0 stashed=0
  for line in ${(f)out}; do
    case $line in
      "# branch.oid "*)  oid=${line#\# branch.oid } ;;
      "# branch.head "*) branch=${line#\# branch.head } ;;
      "# branch.ab "*)   ab=(${=line#\# branch.ab }); ahead=${ab[1]#+}; behind=${ab[2]#-} ;;
      "# stash "*)       stashed=${line#\# stash } ;;
      [12]" "*)          [[ ${line[3]} != . ]] && (( staged++ ))
                         [[ ${line[4]} != . ]] && (( changed++ )) ;;
      "u "*)             (( conflicts++ )) ;;
      "? "*)             (( untracked++ )) ;;
    esac
  done
  [[ $branch == "(detached)" ]] && branch="➦ ${oid[1,7]}"

  # Merge / rebase / bisect markers
  local mode repo_path=$(git rev-parse --git-dir 2>/dev/null)
  if [[ -e "$repo_path/BISECT_LOG" ]]; then mode=" <B>"
  elif [[ -e "$repo_path/MERGE_HEAD" ]]; then mode=" >M<"
  elif [[ -e "$repo_path/rebase-merge" || -e "$repo_path/rebase-apply" ]]; then mode=" >R>"
  fi

  # Build the details
  local details=""
  (( ahead ))     && details+=" $ahead\uf062" # Up arrow icon
  (( behind ))    && details+=" $behind\uf063" # Down arrow icon
  (( staged ))    && details+=" $staged\uf067" # Plus icon
  (( conflicts )) && details+=" $conflicts\uf12a" # Exclamation mark Icon
  (( changed ))   && details+=" $changed\uf040" # Pencil icon
  (( untracked )) && details+=" $untracked\uf128" # Question mark icon
  (( stashed ))   && details+=" $stashed\uf187" # Archive icon

  if (( staged + changed + conflicts + untracked )); then
    prompt_segment yellow black
  else
    prompt_segment green $CURRENT_FG
    details+=" ✔"
  fi

  echo -n $'\ue0a0'" ${branch//\%/%%}${details}${mode}"
}

prompt_bzr() {
  (( $+commands[bzr] )) || return

  # Test if bzr repository in directory hierarchy
  local dir="$PWD"
  while [[ ! -d "$dir/.bzr" ]]; do
    [[ "$dir" = "/" ]] && return
    dir="${dir:h}"
  done

  local bzr_status status_mod status_all revision
  if bzr_status=$(bzr status 2>&1); then
    status_mod=$(echo -n "$bzr_status" | head -n1 | grep "modified" | wc -m)
    status_all=$(echo -n "$bzr_status" | head -n1 | wc -m)
    revision=${$(bzr log -r-1 --log-format line | cut -d: -f1):gs/%/%%}
    if [[ $status_mod -gt 0 ]] ; then
      prompt_segment yellow black "bzr@$revision ✚"
    else
      if [[ $status_all -gt 0 ]] ; then
        prompt_segment yellow black "bzr@$revision"
      else
        prompt_segment green black "bzr@$revision"
      fi
    fi
  fi
}

prompt_hg() {
  (( $+commands[hg] )) || return
  local rev st branch
  if $(hg id >/dev/null 2>&1); then
    if $(hg prompt >/dev/null 2>&1); then
      if [[ $(hg prompt "{status|unknown}") = "?" ]]; then
        # if files are not added
        prompt_segment red white
        st='±'
      elif [[ -n $(hg prompt "{status|modified}") ]]; then
        # if any modification
        prompt_segment yellow black
        st='±'
      else
        # if working copy is clean
        prompt_segment green $CURRENT_FG
      fi
      echo -n ${$(hg prompt "☿ {rev}@{branch}"):gs/%/%%} $st
    else
      st=""
      rev=$(hg id -n 2>/dev/null | sed 's/[^-0-9]//g')
      branch=$(hg id -b 2>/dev/null)
      if `hg st | grep -q "^\?"`; then
        prompt_segment red black
        st='±'
      elif `hg st | grep -q "^[MA]"`; then
        prompt_segment yellow black
        st='±'
      else
        prompt_segment green $CURRENT_FG
      fi
      echo -n "☿ ${rev:gs/%/%%}@${branch:gs/%/%%}" $st
    fi
  fi
}

# Dir: current working directory
prompt_dir() {
  prompt_segment blue $CURRENT_FG '%~'
}

# Virtualenv: current working virtualenv
prompt_virtualenv() {
  if [[ -n "$VIRTUAL_ENV" && -n "$VIRTUAL_ENV_DISABLE_PROMPT" ]]; then
    prompt_segment green black "(${VIRTUAL_ENV:t:gs/%/%%})"
  fi
}

# Status:
# - was there an error
# - am I root
# - are there background jobs?
prompt_status() {
  [[ $RETVAL -ne 0 ]] && prompt_segment red 231 "✘"
  [[ $UID -eq 0 ]] && prompt_segment yellow black "⚡"
  (( ${#jobstates} )) && prompt_segment 239 231 "\udb84\udfab" # Timer / old: ⚙
}

# AWS Profile:
# - display current AWS_PROFILE name
# - displays yellow on red if profile name contains 'production' or
#   ends in '-prod'
# - displays black on green otherwise
prompt_aws() {
  [[ -z "$AWS_PROFILE" || "$SHOW_AWS_PROMPT" = false ]] && return
  case "$AWS_PROFILE" in
    *-prod|*production*) prompt_segment red yellow  "AWS: ${AWS_PROFILE:gs/%/%%}" ;;
    *) prompt_segment green black "AWS: ${AWS_PROFILE:gs/%/%%}" ;;
  esac
}

# Newline:
prompt_newline() {
  prompt_segment none none "\n"
}

## Main prompt
build_prompt() {
  RETVAL=$?
  prompt_status
  prompt_virtualenv
  prompt_aws
  prompt_time
  # prompt_context
  prompt_dir
  prompt_git
  prompt_bzr
  prompt_hg
  prompt_newline
  prompt_end
}

PROMPT='%{%f%b%k%}$(build_prompt) '

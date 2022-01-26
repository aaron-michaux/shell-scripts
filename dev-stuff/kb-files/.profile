

# ----------------------------------------------------------------------- Prompt

function local_bashrc_make_ps1()
{
    local CUT0=1
    local CUT1=2
    local TOT_CUT="$(expr $CUT0 + $CUT1)"
    local FULL="$([ -d "$1" ] && echo "$(cd "$1" ; pwd)" || echo "$(cd "$(dirname "$1")" ; pwd)")"
    local SMALL="$([[ "$FULL" =~ $HOME ]] && echo "~/${FULL:$(expr ${#HOME} + 1)}" || echo "$FULL")"
    local PARTS="$(echo "$SMALL" | tr '/' '\n')"
    local LEN="$(echo "$PARTS" | wc -l)"    
    local N_DOTS="$([ "$LEN" -gt "$TOT_CUT" ] && expr $LEN - $CUT0 - $CUT1 || echo "0")"
    if [ "$N_DOTS" -gt "0" ] ; then
        local DOTS="..(${N_DOTS}).."
        local DOTS="..."
        local START="$(echo "$PARTS" | sed $(expr $CUT0 + 1),\$d | tr '\n' '/' | sed 's,/$,,')"
        local FINISH="$(echo "$PARTS" | sed 1,$(expr $LEN - $CUT1)d | tr '\n' '/' | sed 's,/$,,')"
        local FINAL="$START/$DOTS/$FINISH"
    else
        local FINAL="$(echo "$SMALL" | sed 's,/$,,')"
    fi
    if [ "$2" = "0" ]  ; then
        local EXIT_CODE="\e[0m"
    else
        local EXIT_CODE="\e[31m(exit-code: $2)\e[0m"
    fi
    echo "$EXIT_CODE\n\u@\h $FINAL > "    
}

function local_bashrc_encode_dir_b()
{
    [ "${#1}" -gt "4" ] \
        && printf '\[\033[37m\]%s\xE2\x80\xA6\[\033[0m\]\n' "${1:0:4}" \
            || echo "$1"
}

function local_bashrc_make_ps1_b()
{
    local FULL="$([ -d "$1" ] && echo "$(cd "$1" ; pwd)" || echo "$(cd "$(dirname "$1")" ; pwd)")"
    local SMALL="$([[ "$FULL" =~ $HOME ]] && echo "~/${FULL:$(expr ${#HOME} + 1)}" || echo "$FULL")"
    local PARTS="$(echo "$SMALL" | tr '/' '\n')"
    local LEN="$(echo "$PARTS" | wc -l)"
    if [ "$LEN" -gt "1" ] ; then
        local I=1
        local FINAL="$(echo "$PARTS" | while read L ; do [ "$I" -lt "$LEN" ] && local_bashrc_encode_dir_b "$L" || echo "$L" ; ((I++)) ; done | tr '\n' '/' | sed 's,/$,,')"
    else
        local FINAL="$([ "$SMALL" = "/" ] && echo "$SMALL" || echo "$SMALL" | sed 's,/$,,')"
    fi
    if [ "$2" = "0" ]  ; then
        local EXIT_CODE="\[\033[0m\]"
    else
        local EXIT_CODE="\[\033[31m\](exit-code: $2)\[\033[0m\]"
    fi
    local UNAME="$USER"
    local HNAME="$(hostname)"
    if [ "$USER" = "" ] ; then
        UNAME="build"
        HNAME="kb-shell"
    fi
    
    echo "$EXIT_CODE\n$USER@$HNAME $FINAL > "    
}

function prompt_command {
    local EXITCODE="$?"
    export PS1="$(local_bashrc_make_ps1_b "$(pwd)" "$EXITCODE")"
}

export PROMPT_COMMAND="prompt_command ; history -a"

export CLICOLOR=1

# ----------------------------------------------------------------- Bash history
# Make Bash append rather than overwrite the history on disk:
shopt -s histappend

# Multiline commands stored as 1 line in history
shopt -s cmdhist

# Ignore these commands in history
HISTIGNORE='ls:bg:fg:history:cd'

# A new shell gets the history lines from all previous shells
#PROMPT_COMMAND="history -a"
# Any command starting with a space is ignored in history. 
# Also ignores dup commands
HISTCONTROL="ignoreboth"
HISTSIZE=16000
HISTFILESIZE=32000

# ------------------------------------------------------------------------- Bash 
# check the window size after each command and, if necessary,
# update the values of LINES and COLUMNS.
shopt -s checkwinsize

# make less more friendly for non-text input files, see lesspipe(1)
[ -x /usr/bin/lesspipe ] && eval "$(SHELL=/bin/sh lesspipe)"

# -------------------------------------------------------------------- Git Setup

export GIT_EDITOR vi
export GIT_PAGER cat

# -------------------------------------------------------------------- Colourize
# enable color support of ls and also add handy aliases
export LSCOLORS=ExFxCxDxBxegedabagacad
if [ -x /usr/bin/dircolors ]; then
    alias ls="ls --color=auto"
    alias grep='grep --color=auto'
    alias fgrep='fgrep --color=auto'
    alias egrep='egrep --color=auto'
fi

# ---------------------------------------------------------------------- Aliases
# ls aliases
alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'
alias sudo="sudo -H"

# --------------------------------------------------------------------- Perforce

export P4CONFIG=.p4config
export P4USER=am894222
export P4DIFF="meld p4 diff"

# ---------------------------------------------------------- Setting up the path

[ "$MANPATH" = "" ] && export MANPATH=/opt/local/share/man

prefix_to_path()
{
    for ARG in "$@" ; do
        if [ ! -d "$ARG" ] ; then
            return 0 
        fi
        echo "$PATH" | tr ':' '\n' | grep -q "$ARG" && return 0
        export PATH="${ARG}${PATH+:$PATH}"
    done
}

prefix_to_path "$HOME/.local/bin" "$HOME/bin" "$HOME/Bin" "$HOME/Projects/shell-scripts/bin" "/opt/perforce"

export REMOTE_KESTREL_GIT_DIR="$HOME/sync/SWG_NGP_kestrel"

true
